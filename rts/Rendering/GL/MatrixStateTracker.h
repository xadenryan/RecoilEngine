/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#ifndef GL_MATRIX_STATE_TRACKER_H
#define GL_MATRIX_STATE_TRACKER_H

#include <string>
#include <utility>
#include <vector>

#include "Rendering/GL/myGL.h"
#include "System/Log/ILog.h"

struct SMatrixStateData {
	SMatrixStateData(): mode(GL_MODELVIEW), 
						modelView(0), 
						projection(0),
						texture(0) {}
	int mode;
	int modelView;
	int projection;
	int texture;
	std::string modelViewSource;
	std::string projectionSource;
	std::string textureSource;
};

struct SMatrixTraceData {
	std::vector<std::string> modelView;
	std::vector<std::string> projection;
	std::vector<std::string> texture;
};

struct SMatrixTrackerStateData {
	SMatrixStateData matrixState;
	SMatrixTraceData traceState;
	bool listMode = false;
};

struct GLMatrixStateTracker {
public:
	SMatrixStateData matrixData; // [>0] = stack depth for mode, [0] = matrix mode
	SMatrixTraceData traceData;
	bool listMode; // if creating display list

public:
	GLMatrixStateTracker() : listMode(false) {}

	SMatrixTrackerStateData PushState() {
		return PushState(listMode);
	}

	SMatrixTrackerStateData PushState(bool lm) {
		SMatrixTrackerStateData state;

		std::swap(matrixData, state.matrixState);
		std::swap(traceData, state.traceState);
		state.listMode = listMode;
		listMode = lm;

		return state;
	}

	void PopState(SMatrixTrackerStateData& state) {
		std::swap(matrixData, state.matrixState);
		std::swap(traceData, state.traceState);
		listMode = state.listMode;
	}

	unsigned int GetMode() const {
		return matrixData.mode;
	}

	int& GetDepth(unsigned int mode) {
		switch (mode) {
			case GL_MODELVIEW: return matrixData.modelView;
			case GL_PROJECTION: return matrixData.projection;
			case GL_TEXTURE: return matrixData.texture;
			default:
				LOG_L(L_ERROR, "unknown matrix mode = %u", mode);
				abort();
				break;
		}
	}

	bool PushMatrix() {
		return PushMatrix("");
	}

	bool PushMatrix(const std::string& source) {
		unsigned int mode = GetMode();
		int& depth = GetDepth(mode);

		if (!listMode && depth >= 255)
			return false;

		depth += 1;

		if (depth > 0)
			GetTraceStack(mode).push_back(source);

		UpdateTraceSource(mode);
		return true;
	}

	bool PopMatrix() {
		unsigned int mode = GetMode();
		int& depth = GetDepth(mode);

		if (listMode) {
			if (depth > 0) {
				auto& traceStack = GetTraceStack(mode);

				if (!traceStack.empty())
					traceStack.pop_back();
			}

			depth -= 1;
			UpdateTraceSource(mode);
			return true;
		}
		if (depth == 0)
			return false;

		auto& traceStack = GetTraceStack(mode);

		if (!traceStack.empty())
			traceStack.pop_back();

		depth -= 1;
		UpdateTraceSource(mode);
		return true;
	}

	bool SetMatrixMode(int mode) {
		if (mode == GL_MODELVIEW || mode == GL_PROJECTION || mode == GL_TEXTURE) {
			matrixData.mode = mode;
			return true;
		}
		return false;
	}


	int ApplyMatrixState(SMatrixStateData& m) {
		// validate
#define VALIDATE(modeName) \
		{ \
			int newDepth = m.modeName + matrixData.modeName; \
			if (newDepth < 0) \
				return -1; \
			if (newDepth >= 255) \
				return 1; \
		}

		VALIDATE(modelView)
		VALIDATE(projection)
		VALIDATE(texture)

#undef VALIDATE

		// apply
		matrixData.mode = m.mode;
		ApplyDepthDelta(matrixData.modelView, traceData.modelView, matrixData.modelViewSource, m.modelView, m.modelViewSource);
		ApplyDepthDelta(matrixData.projection, traceData.projection, matrixData.projectionSource, m.projection, m.projectionSource);
		ApplyDepthDelta(matrixData.texture, traceData.texture, matrixData.textureSource, m.texture, m.textureSource);

		return 0;
	}

	const SMatrixStateData& GetMatrixState() const {
		return matrixData;
	}

	bool HasMatrixStateError() const {
		return matrixData.mode != GL_MODELVIEW ||
			matrixData.modelView != 0 ||
			matrixData.projection != 0 ||
			matrixData.texture != 0;
	}

	void HandleMatrixStateError(int error, const char* errsrc) {
		unsigned int mode = GetMode();

		// dont complain about stack/mode issues if some other error occurred
		// check if the lua code did not restore the matrix mode
		if (error == 0 && mode != GL_MODELVIEW)
			LOG_L(L_ERROR, "%s: OpenGL state check error, matrix mode = %d, please restore mode to GL.MODELVIEW before end", errsrc, mode);


#define CHECK_MODE(modeName, glMode) \
		assert(matrixData.modeName >= 0); \
		if (matrixData.modeName != 0) {\
			if (error == 0){ \
				if (!matrixData.modeName##Source.empty()) { \
					LOG_L(L_ERROR, "%s: OpenGL stack check error, matrix mode = %s, depth = %d, most recent unpopped push from %s", errsrc, #glMode, matrixData.modeName, matrixData.modeName##Source.c_str()); \
				} else { \
					LOG_L(L_ERROR, "%s: OpenGL stack check error, matrix mode = %s, depth = %d, please make sure to pop all matrices before end", errsrc, #glMode, matrixData.modeName); \
				} \
			} \
			glMatrixMode(glMode); \
			for (int p = 0; p < matrixData.modeName; ++p) { \
				glPopMatrix(); \
			} \
			matrixData.modeName = 0;\
			matrixData.modeName##Source.clear(); \
			traceData.modeName.clear(); \
		}

		CHECK_MODE(modelView, GL_MODELVIEW)
		CHECK_MODE(projection, GL_PROJECTION)
		CHECK_MODE(texture, GL_TEXTURE)

#undef CHECK_MODE

		glMatrixMode(GL_MODELVIEW);
	}

private:
	std::vector<std::string>& GetTraceStack(unsigned int mode) {
		switch (mode) {
			case GL_MODELVIEW: return traceData.modelView;
			case GL_PROJECTION: return traceData.projection;
			case GL_TEXTURE: return traceData.texture;
			default:
				LOG_L(L_ERROR, "unknown matrix mode = %u", mode);
				abort();
				break;
		}
	}

	std::string& GetTraceSource(unsigned int mode) {
		switch (mode) {
			case GL_MODELVIEW: return matrixData.modelViewSource;
			case GL_PROJECTION: return matrixData.projectionSource;
			case GL_TEXTURE: return matrixData.textureSource;
			default:
				LOG_L(L_ERROR, "unknown matrix mode = %u", mode);
				abort();
				break;
		}
	}

	void UpdateTraceSource(unsigned int mode) {
		auto& traceStack = GetTraceStack(mode);
		auto& traceSource = GetTraceSource(mode);

		if (traceStack.empty()) {
			traceSource.clear();
			return;
		}

		traceSource = traceStack.back();
	}

	static void ApplyDepthDelta(
		int& depth,
		std::vector<std::string>& traceStack,
		std::string& traceSource,
		int delta,
		const std::string& source
	) {
		if (delta > 0) {
			for (int i = 0; i < delta; ++i) {
				depth += 1;

				if (depth > 0)
					traceStack.push_back(source);
			}
		} else if (delta < 0) {
			for (int i = 0; i < -delta; ++i) {
				if (depth > 0 && !traceStack.empty())
					traceStack.pop_back();

				depth -= 1;
			}
		}

		if (traceStack.empty()) {
			traceSource.clear();
			return;
		}

		traceSource = traceStack.back();
	}
};

#endif
