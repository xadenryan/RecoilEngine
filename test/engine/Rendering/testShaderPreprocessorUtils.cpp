/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#include <catch_amalgamated.hpp>

#include "Rendering/Shaders/ShaderPreprocessorUtils.h"

#include <string>

TEST_CASE("Shader preprocessor ignores comment text in conditional macros", "[shader-preprocessor]")
{
	const std::string source =
		"#if 0 // in case AMD drivers refuse to compile this path\n"
		"in vec2 viewPos;\n"
		"#endif\n";

	const auto macros = Shader::Preprocessor::CollectConditionalMacros(source);

	REQUIRE(macros.empty());

	std::string definitions;
	Shader::Preprocessor::AppendConditionalMacroDefaults(&definitions, source);

	REQUIRE(definitions.find("#define in 0") == std::string::npos);
	REQUIRE(definitions.find("#define case 0") == std::string::npos);
	REQUIRE(definitions.find("#define AMD 0") == std::string::npos);
}

TEST_CASE("Shader preprocessor still defaults real conditional macros", "[shader-preprocessor]")
{
	const std::string source =
		"#if defined(ENABLE_SHARPEN) && SUPPORT_CAS /* comment should be ignored */\n"
		"fragColor = texture(tex, uv);\n"
		"#endif\n";

	const auto macros = Shader::Preprocessor::CollectConditionalMacros(source);

	REQUIRE(macros.find("ENABLE_SHARPEN") != macros.end());
	REQUIRE(macros.find("SUPPORT_CAS") != macros.end());
	REQUIRE(macros.find("comment") == macros.end());

	std::string definitions;
	Shader::Preprocessor::AppendConditionalMacroDefaults(&definitions, source);

	REQUIRE(definitions.find("#define ENABLE_SHARPEN 0") != std::string::npos);
	REQUIRE(definitions.find("#define SUPPORT_CAS 0") != std::string::npos);
}
