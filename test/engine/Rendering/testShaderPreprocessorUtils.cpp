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

	REQUIRE(macros.find("ENABLE_SHARPEN") == macros.end());
	REQUIRE(macros.find("SUPPORT_CAS") != macros.end());
	REQUIRE(macros.find("comment") == macros.end());

	std::string definitions;
	Shader::Preprocessor::AppendConditionalMacroDefaults(&definitions, source);

	REQUIRE(definitions.find("#define ENABLE_SHARPEN 0") == std::string::npos);
	REQUIRE(definitions.find("#define SUPPORT_CAS 0") != std::string::npos);
}

TEST_CASE("Shader preprocessor preserves defined() semantics for engine flags", "[shader-preprocessor]")
{
	const std::string source =
		"#if !defined(DEFERRED_MODE) && defined(SMF_ADV_SHADING) && SUPPORT_SPLAT\n"
		"fragColor = vec4(1.0);\n"
		"#endif\n"
		"#elif defined HAVE_SHADOWS && EXTRA_FEATURE\n"
		"fragColor = vec4(0.0);\n"
		"#endif\n";

	const auto macros = Shader::Preprocessor::CollectConditionalMacros(source);

	REQUIRE(macros.find("DEFERRED_MODE") == macros.end());
	REQUIRE(macros.find("SMF_ADV_SHADING") == macros.end());
	REQUIRE(macros.find("HAVE_SHADOWS") == macros.end());
	REQUIRE(macros.find("SUPPORT_SPLAT") != macros.end());
	REQUIRE(macros.find("EXTRA_FEATURE") != macros.end());

	std::string definitions;
	Shader::Preprocessor::AppendConditionalMacroDefaults(&definitions, source);

	REQUIRE(definitions.find("#define DEFERRED_MODE 0") == std::string::npos);
	REQUIRE(definitions.find("#define SMF_ADV_SHADING 0") == std::string::npos);
	REQUIRE(definitions.find("#define HAVE_SHADOWS 0") == std::string::npos);
	REQUIRE(definitions.find("#define SUPPORT_SPLAT 0") != std::string::npos);
	REQUIRE(definitions.find("#define EXTRA_FEATURE 0") != std::string::npos);
}
