/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#pragma once

#include <cctype>
#include <cstring>
#include <set>
#include <string>

namespace Shader::Preprocessor {
	inline std::string StripComments(const std::string& source)
	{
		std::string stripped;
		stripped.reserve(source.size());

		bool inLineComment = false;
		bool inBlockComment = false;

		for (size_t i = 0; i < source.size(); ++i) {
			const char c = source[i];
			const char next = ((i + 1) < source.size()) ? source[i + 1] : '\0';

			if (inLineComment) {
				if (c == '\n') {
					stripped.push_back(c);
					inLineComment = false;
				}

				continue;
			}

			if (inBlockComment) {
				if ((c == '*') && (next == '/')) {
					inBlockComment = false;
					++i;
					continue;
				}

				if (c == '\n')
					stripped.push_back(c);

				continue;
			}

			if ((c == '/') && (next == '/')) {
				inLineComment = true;
				++i;
				continue;
			}

			if ((c == '/') && (next == '*')) {
				inBlockComment = true;
				++i;
				continue;
			}

			stripped.push_back(c);
		}

		return stripped;
	}

	inline bool StartsWithDirective(const std::string& line, const char* directive)
	{
		size_t pos = 0;
		while (pos < line.size() && std::isspace(static_cast<unsigned char>(line[pos])))
			++pos;

		const size_t directiveLen = std::strlen(directive);
		if (line.compare(pos, directiveLen, directive) != 0)
			return false;

		const size_t nextPos = pos + directiveLen;
		return (nextPos >= line.size()) || !(std::isalnum(static_cast<unsigned char>(line[nextPos])) || line[nextPos] == '_');
	}

	inline std::set<std::string> CollectDefinedMacros(const std::string& source)
	{
		std::set<std::string> macros;
		const std::string strippedSource = StripComments(source);

		size_t lineStart = 0;
		while (lineStart <= strippedSource.size()) {
			const size_t lineEnd = strippedSource.find('\n', lineStart);
			const std::string line = strippedSource.substr(lineStart, (lineEnd == std::string::npos) ? std::string::npos : (lineEnd - lineStart));

			if (StartsWithDirective(line, "#define")) {
				size_t pos = line.find("#define");
				pos += std::strlen("#define");
				while (pos < line.size() && std::isspace(static_cast<unsigned char>(line[pos])))
					++pos;

				const size_t macroStart = pos;
				while (pos < line.size() && (std::isalnum(static_cast<unsigned char>(line[pos])) || line[pos] == '_'))
					++pos;

				if (macroStart < pos)
					macros.emplace(line.substr(macroStart, pos - macroStart));
			}

			if (lineEnd == std::string::npos)
				break;
			lineStart = lineEnd + 1;
		}

		return macros;
	}

	inline std::set<std::string> CollectConditionalMacros(const std::string& source)
	{
		std::set<std::string> macros;
		const std::string strippedSource = StripComments(source);

		size_t lineStart = 0;
		while (lineStart <= strippedSource.size()) {
			const size_t lineEnd = strippedSource.find('\n', lineStart);
			const std::string line = strippedSource.substr(lineStart, (lineEnd == std::string::npos) ? std::string::npos : (lineEnd - lineStart));

			if (StartsWithDirective(line, "#if") || StartsWithDirective(line, "#elif")) {
				const char* directive = StartsWithDirective(line, "#elif") ? "#elif" : "#if";
				size_t pos = line.find(directive);
				pos = (pos == std::string::npos) ? 0 : (pos + std::strlen(directive));
				bool skipDefinedOperand = false;

				for (; pos < line.size(); ++pos) {
					if (!(std::isalpha(static_cast<unsigned char>(line[pos])) || line[pos] == '_'))
						continue;

					const size_t macroStart = pos;
					while (pos < line.size() && (std::isalnum(static_cast<unsigned char>(line[pos])) || line[pos] == '_'))
						++pos;

					const std::string macro = line.substr(macroStart, pos - macroStart);
					if (macro == "defined") {
						skipDefinedOperand = true;
						continue;
					}

					if (skipDefinedOperand) {
						skipDefinedOperand = false;
						continue;
					}

					macros.emplace(macro);
				}
			}

			if (lineEnd == std::string::npos)
				break;
			lineStart = lineEnd + 1;
		}

		return macros;
	}

	inline void AppendConditionalMacroDefaults(std::string* definitions, const std::string& source)
	{
		std::set<std::string> macros = CollectDefinedMacros(*definitions);
		const std::set<std::string> sourceMacros = CollectDefinedMacros(source);

		for (const std::string& macro: CollectConditionalMacros(source)) {
			if (macro.rfind("GL_", 0) == 0)
				continue;

			if (macros.find(macro) != macros.end() || sourceMacros.find(macro) != sourceMacros.end())
				continue;

			if (!definitions->empty() && definitions->back() != '\n')
				definitions->push_back('\n');

			definitions->append("#ifndef " + macro + "\n");
			definitions->append("#define " + macro + " 0\n");
			definitions->append("#endif\n");
			macros.emplace(macro);
		}
	}
}
