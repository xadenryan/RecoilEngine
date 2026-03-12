/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#include "Screenshot.h"

#include <algorithm>
#include <chrono>
#include <cctype>
#include <deque>
#include <future>
#include <optional>
#include <vector>

#include "Rendering/GL/myGL.h"
#include "Rendering/GlobalRendering.h"
#include "Rendering/Textures/Bitmap.h"
#include "System/StringUtil.h"
#include "System/Config/ConfigHandler.h"
#include "System/Log/ILog.h"
#include "System/FileSystem/FileSystem.h"
#include "System/FileSystem/FileHandler.h"
#include "System/Threading/ThreadPool.h"
#include "System/TimeUtil.h"

#undef CreateDirectory

CONFIG(int, ScreenshotCounter).description("Deprecated, does nothing, but not marked as such to keep compatibility with older engine versions").defaultValue(0);
CONFIG(bool, ValidationPresentCapture).defaultValue(false).headlessValue(false).description("For automated validation only: capture a short frame sequence from the final pre-swap window backbuffer.");
CONFIG(int, ValidationPresentCaptureStartFrame).defaultValue(1).minimumValue(1).description("For automated validation only: the first draw frame eligible for final-present backbuffer capture.");
CONFIG(int, ValidationPresentCaptureFrameCount).defaultValue(0).minimumValue(0).description("For automated validation only: number of final-present frames to capture before the sequence stops.");
CONFIG(int, ValidationPresentCaptureQuality).defaultValue(90).minimumValue(1).maximumValue(100).description("For automated validation only: image quality for final-present frame capture writes.");
CONFIG(std::string, ValidationPresentCapturePrefix).defaultValue("validation_present").description("For automated validation only: filename prefix used for final-present frame capture writes in screenshots/.");

namespace {

struct FunctionArgs
{
	std::vector<uint8_t> pixelbuf;
	std::string filename;
	unsigned quality;
	int x;
	int y;
};

struct ValidationPresentCaptureState
{
	bool initialized = false;
	bool enabled = false;
	bool completionLogged = false;
	unsigned startFrame = 1;
	unsigned totalFrames = 0;
	unsigned remainingFrames = 0;
	unsigned quality = 90;
	std::string prefix = "validation_present";
	std::optional<unsigned int> lastSequenceFrame = std::nullopt;
};

enum class CaptureReadBufferMode {
	Current,
	DefaultBack,
	DefaultFront,
};

struct ScopedReadbackState
{
	ScopedReadbackState()
	{
		glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &readFramebuffer);
		glGetIntegerv(GL_READ_BUFFER, &readBuffer);
		glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &pixelPackBuffer);
		glGetIntegerv(GL_PACK_ALIGNMENT, &packAlignment);
		glGetIntegerv(GL_PACK_ROW_LENGTH, &packRowLength);
		glGetIntegerv(GL_PACK_SKIP_ROWS, &packSkipRows);
		glGetIntegerv(GL_PACK_SKIP_PIXELS, &packSkipPixels);
		glGetIntegerv(GL_PACK_IMAGE_HEIGHT, &packImageHeight);
		glGetIntegerv(GL_PACK_SKIP_IMAGES, &packSkipImages);
	}

	~ScopedReadbackState()
	{
		glBindBuffer(GL_PIXEL_PACK_BUFFER, pixelPackBuffer);
		glPixelStorei(GL_PACK_ALIGNMENT, packAlignment);
		glPixelStorei(GL_PACK_ROW_LENGTH, packRowLength);
		glPixelStorei(GL_PACK_SKIP_ROWS, packSkipRows);
		glPixelStorei(GL_PACK_SKIP_PIXELS, packSkipPixels);
		glPixelStorei(GL_PACK_IMAGE_HEIGHT, packImageHeight);
		glPixelStorei(GL_PACK_SKIP_IMAGES, packSkipImages);
		glBindFramebuffer(GL_READ_FRAMEBUFFER_EXT, readFramebuffer);
		glReadBuffer(readBuffer);
	}

	void Prepare(CaptureReadBufferMode mode) const
	{
		glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
		glPixelStorei(GL_PACK_ALIGNMENT, 1);
		glPixelStorei(GL_PACK_ROW_LENGTH, 0);
		glPixelStorei(GL_PACK_SKIP_ROWS, 0);
		glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
		glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
		glPixelStorei(GL_PACK_SKIP_IMAGES, 0);

		if (mode == CaptureReadBufferMode::Current)
			return;

		glBindFramebuffer(GL_READ_FRAMEBUFFER_EXT, 0);
		glReadBuffer((mode == CaptureReadBufferMode::DefaultFront) ? GL_FRONT : GL_BACK);
	}

	GLint readFramebuffer = 0;
	GLint readBuffer = GL_BACK;
	GLint pixelPackBuffer = 0;
	GLint packAlignment = 4;
	GLint packRowLength = 0;
	GLint packSkipRows = 0;
	GLint packSkipPixels = 0;
	GLint packImageHeight = 0;
	GLint packSkipImages = 0;
};

static std::deque<std::shared_future<void>> pendingWrites;
static ValidationPresentCaptureState validationPresentCaptureState;

static std::string SanitizeCapturePrefix(std::string prefix)
{
	if (prefix.empty())
		return "validation_present";

	for (char& c: prefix) {
		if (!(std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-'))
			c = '_';
	}

	return prefix;
}

static void PrunePendingScreenshotWrites(const bool waitAll)
{
	while (!pendingWrites.empty()) {
		if (!waitAll) {
			const auto status = pendingWrites.front().wait_for(std::chrono::seconds(0));

			if (status != std::future_status::ready)
				break;
		}

		pendingWrites.front().get();
		pendingWrites.pop_front();
	}
}

static std::string BuildDefaultScreenshotFilename(const std::string& type)
{
	const std::string curTime = CTimeUtil::GetCurrentTimeStr(true);
	return ("screenshots/screen_" + curTime + "." + type);
}

static std::string BuildValidationPresentCaptureFilename(const unsigned int drawFrame, const unsigned int captureIndex)
{
	return (
		"screenshots/" +
		validationPresentCaptureState.prefix +
		"_df" + IntToString(drawFrame, "%06i") +
		"_f" + IntToString(captureIndex, "%03i") +
		".png"
	);
}

static FunctionArgs CaptureDefaultFramebufferPixels(const std::string& filename, const unsigned quality, const CaptureReadBufferMode readBufferMode)
{
	ScopedReadbackState readbackState;
	FunctionArgs args;
	args.x  = globalRendering->winSizeX;
	args.y  = globalRendering->winSizeY;
	args.x += ((4 - (args.x % 4)) * int((args.x % 4) != 0));
	args.filename = filename;
	args.quality = quality;
	args.pixelbuf.resize(args.x * args.y * 4);

	readbackState.Prepare(readBufferMode);
	glReadPixels(0, 0, args.x, args.y, GL_RGBA, GL_UNSIGNED_BYTE, args.pixelbuf.data());
	return args;
}

static FunctionArgs CaptureScreenshotPixels(const std::string& filename, const unsigned quality)
{
	ScopedReadbackState readbackState;
	FunctionArgs args;
	args.x  = globalRendering->winSizeX;
	args.y  = globalRendering->winSizeY;
	args.x += ((4 - (args.x % 4)) * int((args.x % 4) != 0));
	args.filename = filename;
	args.quality = quality;
	args.pixelbuf.resize(args.x * args.y * 4);

	readbackState.Prepare(CaptureReadBufferMode::Current);
	glReadPixels(0, 0, args.x, args.y, GL_RGBA, GL_UNSIGNED_BYTE, args.pixelbuf.data());
	return args;
}

static void EnqueueScreenshotWrite(const FunctionArgs& args)
{
	pendingWrites.emplace_back(ThreadPool::Enqueue([](const FunctionArgs& args) {
		CBitmap bmp(args.pixelbuf.data(), args.x, args.y);
		bmp.ReverseYAxis();
		bmp.Save(args.filename, true, true, args.quality);
	}, args));
}

static void InitValidationPresentCaptureState()
{
	if (validationPresentCaptureState.initialized)
		return;

	validationPresentCaptureState.initialized = true;
	validationPresentCaptureState.enabled = configHandler->GetBool("ValidationPresentCapture");
	validationPresentCaptureState.startFrame = std::max(1, configHandler->GetInt("ValidationPresentCaptureStartFrame"));
	validationPresentCaptureState.totalFrames = std::max(0, configHandler->GetInt("ValidationPresentCaptureFrameCount"));
	validationPresentCaptureState.remainingFrames = validationPresentCaptureState.totalFrames;
	validationPresentCaptureState.quality = std::max(1, configHandler->GetInt("ValidationPresentCaptureQuality"));
	validationPresentCaptureState.prefix = SanitizeCapturePrefix(configHandler->GetString("ValidationPresentCapturePrefix"));
	validationPresentCaptureState.enabled = validationPresentCaptureState.enabled && (validationPresentCaptureState.totalFrames > 0);

	if (!validationPresentCaptureState.enabled)
		return;

	LOG_L(L_INFO,
		"[Screenshot::%s] enabled final-present capture startDrawFrame=%u frameCount=%u prefix=%s quality=%u",
		__func__,
		validationPresentCaptureState.startFrame,
		validationPresentCaptureState.totalFrames,
		validationPresentCaptureState.prefix.c_str(),
		validationPresentCaptureState.quality
	);
}

}

void TakeScreenshot(std::string type, unsigned quality)
{
	if (type.empty())
		type = "png";

	TakeScreenshotWithPath(BuildDefaultScreenshotFilename(type), quality);
}

void TakeScreenshotWithPath(const std::string& filename, unsigned quality)
{
	if (!FileSystem::CreateDirectory("screenshots"))
		return;

	PrunePendingScreenshotWrites(false);
	EnqueueScreenshotWrite(CaptureScreenshotPixels(filename, quality));
}

void CaptureValidationPresentFrameSequence(unsigned int drawFrame, bool captureFrontBuffer, bool useCurrentReadBuffer, std::optional<unsigned int> sequenceFrameOverride)
{
	InitValidationPresentCaptureState();

	if (!validationPresentCaptureState.enabled || (validationPresentCaptureState.remainingFrames == 0))
		return;

	const unsigned int sequenceFrame = sequenceFrameOverride.value_or(drawFrame);

	if (sequenceFrame < validationPresentCaptureState.startFrame)
		return;

	if (validationPresentCaptureState.lastSequenceFrame == sequenceFrame)
		return;

	const unsigned int captureIndex = (validationPresentCaptureState.totalFrames - validationPresentCaptureState.remainingFrames);
	const std::string filename = BuildValidationPresentCaptureFilename(drawFrame, captureIndex);

	if (!FileSystem::CreateDirectory("screenshots"))
		return;

	PrunePendingScreenshotWrites(false);
	EnqueueScreenshotWrite(CaptureDefaultFramebufferPixels(
		filename,
		validationPresentCaptureState.quality,
		useCurrentReadBuffer
			? CaptureReadBufferMode::Current
			: (captureFrontBuffer ? CaptureReadBufferMode::DefaultFront : CaptureReadBufferMode::DefaultBack)
	));
	LOG_L(L_INFO, "[Screenshot::%s] captured final-present frame drawFrame=%u sequenceFrame=%u index=%u path=%s", __func__, drawFrame, sequenceFrame, captureIndex, filename.c_str());

	validationPresentCaptureState.lastSequenceFrame = sequenceFrame;
	validationPresentCaptureState.remainingFrames--;

	if ((validationPresentCaptureState.remainingFrames == 0) && !validationPresentCaptureState.completionLogged) {
		validationPresentCaptureState.completionLogged = true;
		LOG_L(L_INFO, "[Screenshot::%s] final-present capture sequence completed totalFrames=%u", __func__, validationPresentCaptureState.totalFrames);
	}
}

void WaitForPendingScreenshotWrites()
{
	PrunePendingScreenshotWrites(true);
}
