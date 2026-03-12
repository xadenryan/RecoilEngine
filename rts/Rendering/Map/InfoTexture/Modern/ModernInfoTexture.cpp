/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#include "ModernInfoTexture.h"
#include "Rendering/Shaders/Shader.h"
#include "Rendering/GlobalRendering.h"
#include "Rendering/GlobalRenderingInfo.h"


CModernInfoTexture::CModernInfoTexture(const std::string& _name)
	: CInfoTexture(_name, {}, int2(0, 0))
{}

std::string CModernInfoTexture::GetShaderVersionDirective()
{
	// Apple core-profile contexts reject GLSL 1.30 even when the shader body is
	// otherwise core-safe, so promote this localized fullscreen/info-texture path
	// to 1.50 only for core contexts that already advertise it.
	if (globalRenderingInfo.glContextIsCore && globalRenderingInfo.glslVersionNum >= 150)
		return "#version 150\n";

	return "#version 130\n";
}

std::string CModernInfoTexture::GetFullscreenTriangleVertexShaderSource()
{
	return GetShaderVersionDirective() + R"(

out vec2 uv;

void main()
{
	uv = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
	gl_Position = vec4(uv * 2.0f - 1.0f, 0.0f, 1.0f);
}
)";
}

bool CModernInfoTexture::CreateFBO(const char* fboName)
{
	if (!FBO::IsSupported())
		return false;

	fbo.Bind();
	fbo.AttachTexture(texture.GetId());
	bool status = fbo.CheckStatus(fboName);
	FBO::Unbind();

	return status;
}

void CModernInfoTexture::RunFullScreenPass()
{
	fbo.Bind();
	glViewport(0, 0, texSize.x, texSize.y);
	shader->Enable();
	vao.Bind();
	glDrawArrays(GL_TRIANGLES, 0, 3); // full screen triangle
	vao.Unbind();
	shader->Disable();
	FBO::Unbind();
	globalRendering->LoadViewport();
}

void CModernInfoTexture::ValidateShaderProgram()
{
	if (shader == nullptr)
		return;

	vao.Bind();
	shader->Validate();
	vao.Unbind();
}
