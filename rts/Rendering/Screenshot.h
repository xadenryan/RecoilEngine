/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#pragma once

#include <optional>
#include <string>

void TakeScreenshot(std::string type, unsigned quality);
void TakeScreenshotWithPath(const std::string& filename, unsigned quality);
void CaptureValidationPresentFrameSequence(unsigned int drawFrame, bool captureFrontBuffer, bool useCurrentReadBuffer = false, std::optional<unsigned int> sequenceFrameOverride = std::nullopt);
void WaitForPendingScreenshotWrites();
