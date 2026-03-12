/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#pragma once

#include "Rendering/GL/myGL.h"

#include <array>
#include <cctype>
#include <string>

namespace Shader::LegacyGlslCompat {
	struct Usage {
		bool usesLegacySurface = false;
		bool usesAttributeKeyword = false;
		bool usesVaryingKeyword = false;
		bool usesVertex = false;
		bool usesNormal = false;
		bool usesColor = false;
		bool usesSecondaryColor = false;
		bool usesFrontColor = false;
		bool usesFogCoord = false;
		bool usesFogFragCoord = false;
		bool usesTexCoord = false;
		bool usesClipVertex = false;
		bool usesFragColor = false;
		bool usesModelViewMatrix = false;
		bool usesProjectionMatrix = false;
		bool usesModelViewProjectionMatrix = false;
		bool usesModelViewMatrixInverse = false;
		bool usesProjectionMatrixInverse = false;
		bool usesModelViewProjectionMatrixInverse = false;
		bool usesNormalMatrix = false;
		bool usesFog = false;
		bool usesTexture2D = false;
		bool usesTextureCube = false;
		bool usesShadow2DProj = false;

		std::array<bool, 8> usesMultiTexCoord = {};
	};

	static constexpr const char* MODELVIEW_MATRIX_UNIFORM = "recoil_LegacyModelViewMatrix";
	static constexpr const char* PROJECTION_MATRIX_UNIFORM = "recoil_LegacyProjectionMatrix";
	static constexpr const char* MODELVIEWPROJECTION_MATRIX_UNIFORM = "recoil_LegacyModelViewProjectionMatrix";
	static constexpr const char* MODELVIEW_MATRIX_INVERSE_UNIFORM = "recoil_LegacyModelViewMatrixInverse";
	static constexpr const char* PROJECTION_MATRIX_INVERSE_UNIFORM = "recoil_LegacyProjectionMatrixInverse";
	static constexpr const char* MODELVIEWPROJECTION_MATRIX_INVERSE_UNIFORM = "recoil_LegacyModelViewProjectionMatrixInverse";
	static constexpr const char* NORMAL_MATRIX_UNIFORM = "recoil_LegacyNormalMatrix";
	static constexpr const char* FRONT_COLOR_VARYING = "recoil_LegacyFrontColor";
	static constexpr const char* FOG_FRAGCOORD_VARYING = "recoil_LegacyFogFragCoord";
	static constexpr const char* TEXCOORD_VARYING = "recoil_LegacyTexCoord";
	static constexpr const char* FRAGCOLOR_OUTPUT = "recoil_LegacyFragColor";

	inline bool ContainsText(const std::string& source, const std::string& token)
	{
		return (source.find(token) != std::string::npos);
	}

	inline bool IsIdentifierChar(const char c)
	{
		return std::isalnum(static_cast<unsigned char>(c)) || (c == '_');
	}

	inline void ReplaceWholeToken(std::string* source, const std::string& from, const std::string& to)
	{
		for (size_t pos = source->find(from); pos != std::string::npos; pos = source->find(from, pos + to.size())) {
			const bool leftOk = (pos == 0) || !IsIdentifierChar((*source)[pos - 1]);
			const bool rightOk = ((pos + from.size()) >= source->size()) || !IsIdentifierChar((*source)[pos + from.size()]);

			if (!leftOk || !rightOk)
				continue;

			source->replace(pos, from.size(), to);
		}
	}

	inline void ReplaceAll(std::string* source, const std::string& from, const std::string& to)
	{
		for (size_t pos = source->find(from); pos != std::string::npos; pos = source->find(from, pos + to.size()))
			source->replace(pos, from.size(), to);
	}

	inline void RemoveLinesContaining(std::string* source, const std::string& pattern)
	{
		for (size_t pos = source->find(pattern); pos != std::string::npos; pos = source->find(pattern, pos)) {
			const size_t lineStart = source->rfind('\n', pos);
			const size_t eraseBegin = (lineStart == std::string::npos) ? 0 : (lineStart + 1);
			const size_t lineEnd = source->find('\n', pos);

			if (lineEnd == std::string::npos) {
				source->erase(eraseBegin);
				break;
			}

			source->erase(eraseBegin, lineEnd - eraseBegin + 1);
			pos = eraseBegin;
		}
	}

	inline void StripCompatibilityProfileSuffix(std::string* version)
	{
		if (version->empty())
			return;

		const size_t compatibilityPos = version->find(" compatibility");
		if (compatibilityPos != std::string::npos)
			version->erase(compatibilityPos);
	}

	inline void StripDesktopPrecisionQualifiers(std::string* source)
	{
		ReplaceAll(source, "#if (GL_FRAGMENT_PRECISION_HIGH == 1)", "#if 0");
		ReplaceAll(source, "#if(GL_FRAGMENT_PRECISION_HIGH==1)", "#if 0");
		RemoveLinesContaining(source, "precision highp ");
		RemoveLinesContaining(source, "precision mediump ");
		RemoveLinesContaining(source, "precision lowp ");
	}

	inline Usage Analyze(const std::string& source)
	{
		Usage usage;

		usage.usesAttributeKeyword = ContainsText(source, "attribute ");
		usage.usesVaryingKeyword = ContainsText(source, "varying ");
		usage.usesVertex = ContainsText(source, "gl_Vertex");
		usage.usesNormal = ContainsText(source, "gl_Normal");
		usage.usesColor = ContainsText(source, "gl_Color");
		usage.usesSecondaryColor = ContainsText(source, "gl_SecondaryColor");
		usage.usesFrontColor = ContainsText(source, "gl_FrontColor");
		usage.usesFogCoord = ContainsText(source, "gl_FogCoord");
		usage.usesFogFragCoord = ContainsText(source, "gl_FogFragCoord");
		usage.usesTexCoord = ContainsText(source, "gl_TexCoord");
		usage.usesClipVertex = ContainsText(source, "gl_ClipVertex");
		usage.usesFragColor = ContainsText(source, "gl_FragColor");
		usage.usesModelViewMatrix = ContainsText(source, "gl_ModelViewMatrix");
		usage.usesProjectionMatrix = ContainsText(source, "gl_ProjectionMatrix");
		usage.usesModelViewProjectionMatrix = ContainsText(source, "gl_ModelViewProjectionMatrix");
		usage.usesModelViewMatrixInverse = ContainsText(source, "gl_ModelViewMatrixInverse");
		usage.usesProjectionMatrixInverse = ContainsText(source, "gl_ProjectionMatrixInverse");
		usage.usesModelViewProjectionMatrixInverse = ContainsText(source, "gl_ModelViewProjectionMatrixInverse");
		usage.usesNormalMatrix = ContainsText(source, "gl_NormalMatrix");
		usage.usesFog = ContainsText(source, "gl_Fog");
		usage.usesTexture2D = ContainsText(source, "texture2D(");
		usage.usesTextureCube = ContainsText(source, "textureCube(");
		usage.usesShadow2DProj = ContainsText(source, "shadow2DProj(");

		for (uint32_t texUnit = 0; texUnit < usage.usesMultiTexCoord.size(); ++texUnit)
			usage.usesMultiTexCoord[texUnit] = ContainsText(source, "gl_MultiTexCoord" + std::to_string(texUnit));

		usage.usesLegacySurface =
			usage.usesAttributeKeyword ||
			usage.usesVaryingKeyword ||
			usage.usesVertex ||
			usage.usesNormal ||
			usage.usesColor ||
			usage.usesSecondaryColor ||
			usage.usesFrontColor ||
			usage.usesFogCoord ||
			usage.usesFogFragCoord ||
			usage.usesTexCoord ||
			usage.usesClipVertex ||
			usage.usesFragColor ||
			usage.usesModelViewMatrix ||
			usage.usesProjectionMatrix ||
			usage.usesModelViewProjectionMatrix ||
			usage.usesModelViewMatrixInverse ||
			usage.usesProjectionMatrixInverse ||
			usage.usesModelViewProjectionMatrixInverse ||
			usage.usesNormalMatrix ||
			usage.usesFog ||
			usage.usesTexture2D ||
			usage.usesTextureCube ||
			usage.usesShadow2DProj;

		for (bool usesTexCoord : usage.usesMultiTexCoord)
			usage.usesLegacySurface = usage.usesLegacySurface || usesTexCoord;

		return usage;
	}

	inline std::string BuildPreamble(const Usage& usage, GLenum type)
	{
		std::string preamble;

		if (type == GL_VERTEX_SHADER) {
			if (usage.usesVertex)
				preamble += "in vec4 recoil_LegacyVertex;\n#define gl_Vertex recoil_LegacyVertex\n";
			if (usage.usesNormal)
				preamble += "in vec3 recoil_LegacyNormal;\n#define gl_Normal recoil_LegacyNormal\n";
			if (usage.usesColor)
				preamble += "in vec4 recoil_LegacyColorAttrib;\n#define gl_Color recoil_LegacyColorAttrib\n";
			if (usage.usesSecondaryColor)
				preamble += "in vec4 recoil_LegacySecondaryColorAttrib;\n#define gl_SecondaryColor recoil_LegacySecondaryColorAttrib\n";
			if (usage.usesFogCoord)
				preamble += "in float recoil_LegacyFogCoordAttrib;\n#define gl_FogCoord recoil_LegacyFogCoordAttrib\n";
			if (usage.usesFrontColor)
				preamble += "out vec4 recoil_LegacyFrontColor;\n#define gl_FrontColor recoil_LegacyFrontColor\n";
			if (usage.usesFogFragCoord)
				preamble += "out float recoil_LegacyFogFragCoord;\n#define gl_FogFragCoord recoil_LegacyFogFragCoord\n";
			if (usage.usesClipVertex)
				preamble += "vec4 recoil_LegacyClipVertex;\n#define gl_ClipVertex recoil_LegacyClipVertex\n";

			for (uint32_t texUnit = 0; texUnit < usage.usesMultiTexCoord.size(); ++texUnit) {
				if (!usage.usesMultiTexCoord[texUnit])
					continue;

				preamble += "in vec4 recoil_LegacyMultiTexCoord" + std::to_string(texUnit) + ";\n";
				preamble += "#define gl_MultiTexCoord" + std::to_string(texUnit) + " recoil_LegacyMultiTexCoord" + std::to_string(texUnit) + "\n";
			}

			if (usage.usesTexCoord)
				preamble += "out vec4 recoil_LegacyTexCoord[8];\n#define gl_TexCoord recoil_LegacyTexCoord\n";
		}

		if (type == GL_FRAGMENT_SHADER) {
			if (usage.usesTexCoord)
				preamble += "in vec4 recoil_LegacyTexCoord[8];\n#define gl_TexCoord recoil_LegacyTexCoord\n";
			if (usage.usesColor)
				preamble += "in vec4 recoil_LegacyFrontColor;\n#define gl_Color recoil_LegacyFrontColor\n";
			if (usage.usesFogFragCoord)
				preamble += "in float recoil_LegacyFogFragCoord;\n#define gl_FogFragCoord recoil_LegacyFogFragCoord\n";
			if (usage.usesFragColor)
				preamble += "out vec4 recoil_LegacyFragColor;\n#define gl_FragColor recoil_LegacyFragColor\n";
		}

		if (usage.usesModelViewMatrix)
			preamble += std::string("uniform mat4 ") + MODELVIEW_MATRIX_UNIFORM + ";\n#define gl_ModelViewMatrix " + MODELVIEW_MATRIX_UNIFORM + "\n";
		if (usage.usesProjectionMatrix)
			preamble += std::string("uniform mat4 ") + PROJECTION_MATRIX_UNIFORM + ";\n#define gl_ProjectionMatrix " + PROJECTION_MATRIX_UNIFORM + "\n";
		if (usage.usesModelViewProjectionMatrix)
			preamble += std::string("uniform mat4 ") + MODELVIEWPROJECTION_MATRIX_UNIFORM + ";\n#define gl_ModelViewProjectionMatrix " + MODELVIEWPROJECTION_MATRIX_UNIFORM + "\n";
		if (usage.usesModelViewMatrixInverse)
			preamble += std::string("uniform mat4 ") + MODELVIEW_MATRIX_INVERSE_UNIFORM + ";\n#define gl_ModelViewMatrixInverse " + MODELVIEW_MATRIX_INVERSE_UNIFORM + "\n";
		if (usage.usesProjectionMatrixInverse)
			preamble += std::string("uniform mat4 ") + PROJECTION_MATRIX_INVERSE_UNIFORM + ";\n#define gl_ProjectionMatrixInverse " + PROJECTION_MATRIX_INVERSE_UNIFORM + "\n";
		if (usage.usesModelViewProjectionMatrixInverse)
			preamble += std::string("uniform mat4 ") + MODELVIEWPROJECTION_MATRIX_INVERSE_UNIFORM + ";\n#define gl_ModelViewProjectionMatrixInverse " + MODELVIEWPROJECTION_MATRIX_INVERSE_UNIFORM + "\n";
		if (usage.usesNormalMatrix)
			preamble += std::string("uniform mat3 ") + NORMAL_MATRIX_UNIFORM + ";\n#define gl_NormalMatrix " + NORMAL_MATRIX_UNIFORM + "\n";
		if (usage.usesFog) {
			preamble += "struct recoil_LegacyFogStruct {\n";
			preamble += "\tvec4 color;\n";
			preamble += "\tfloat density;\n";
			preamble += "\tfloat start;\n";
			preamble += "\tfloat end;\n";
			preamble += "\tfloat scale;\n";
			preamble += "};\n";
			preamble += "uniform recoil_LegacyFogStruct recoil_LegacyFog;\n#define gl_Fog recoil_LegacyFog\n";
		}
		if (usage.usesTexture2D)
			preamble += "#define texture2D texture\n";
		if (usage.usesTextureCube)
			preamble += "#define textureCube texture\n";
		if (usage.usesShadow2DProj)
			preamble += "#define shadow2DProj(tex, coord) vec4(textureProj(tex, coord))\n";

		return preamble;
	}

	inline Usage AdaptSource(std::string* source, GLenum type)
	{
		const Usage usage = Analyze(*source);

		if (!usage.usesLegacySurface)
			return usage;

		if (usage.usesAttributeKeyword)
			ReplaceWholeToken(source, "attribute", "in");

		if (usage.usesVaryingKeyword) {
			if (type == GL_VERTEX_SHADER)
				ReplaceWholeToken(source, "varying", "out");
			if (type == GL_FRAGMENT_SHADER)
				ReplaceWholeToken(source, "varying", "in");
		}

		const std::string preamble = BuildPreamble(usage, type);
		if (!preamble.empty())
			source->insert(0, preamble);

		return usage;
	}

	inline void BindAttribLocations(GLuint prog, const Usage& usage)
	{
		if (usage.usesVertex)
			glBindAttribLocation(prog, 0, "recoil_LegacyVertex");
		if (usage.usesNormal)
			glBindAttribLocation(prog, 2, "recoil_LegacyNormal");
		if (usage.usesColor)
			glBindAttribLocation(prog, 3, "recoil_LegacyColorAttrib");
		if (usage.usesSecondaryColor)
			glBindAttribLocation(prog, 4, "recoil_LegacySecondaryColorAttrib");
		if (usage.usesFogCoord)
			glBindAttribLocation(prog, 5, "recoil_LegacyFogCoordAttrib");

		for (uint32_t texUnit = 0; texUnit < usage.usesMultiTexCoord.size(); ++texUnit) {
			if (!usage.usesMultiTexCoord[texUnit])
				continue;

			glBindAttribLocation(prog, 8 + texUnit, ("recoil_LegacyMultiTexCoord" + std::to_string(texUnit)).c_str());
		}
	}

	inline void BindFragmentOutputs(GLuint prog, const Usage& usage)
	{
		if (usage.usesFragColor)
			glBindFragDataLocation(prog, 0, FRAGCOLOR_OUTPUT);
	}
}
