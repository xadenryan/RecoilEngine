#version 120

#if defined(RECOIL_CORE_PROFILE_MODEL)
uniform vec3 cameraPos;
uniform mat4 recoilModelViewMatrix;
uniform mat4 recoilProjectionMatrix;
uniform vec4 recoilFogParams;

in vec3 vertexPos;
in vec3 vertexNormal;
in vec4 vertexUV;

out vec4 vertexWorldPos;
out vec3 cameraDir;
out float fogFactor;
out vec3 normalv;
out vec2 modelUV;

	#if (USE_SHADOWS == 1)
	uniform mat4 shadowMatrix;
	out vec4 shadowVertexPos;
	#endif

void main(void)
{
	mat3 normalMatrix = transpose(inverse(mat3(recoilModelViewMatrix)));

	normalv = normalMatrix * vertexNormal;

	vertexWorldPos = recoilModelViewMatrix * vec4(vertexPos, 1.0);
	gl_Position = recoilProjectionMatrix * vertexWorldPos;

	cameraDir = vertexWorldPos.xyz - cameraPos.xyz;
	modelUV = vertexUV.st;

	#if (USE_SHADOWS == 1)
	shadowVertexPos = shadowMatrix * vertexWorldPos;
	shadowVertexPos.xy += vec2(0.5);
	#endif

	#if (DEFERRED_MODE == 0)
	float fogCoord = length(cameraDir.xyz);
	fogFactor = (recoilFogParams.y - fogCoord) * recoilFogParams.z;
	fogFactor = clamp(fogFactor, 0.0, 1.0);
	#else
	fogFactor = 1.0;
	#endif
}
#else
// note: gl_ModelViewMatrix actually only contains the
// model matrix, view matrix is on the projection stack

varying vec4 vertexWorldPos;
varying vec3 cameraDir;
varying float fogFactor;
varying vec3 normalv;

#if (USE_SHADOWS == 1)
	uniform mat4 shadowMatrix;
	varying vec4 shadowVertexPos;
#endif

void main(void)
{
	normalv = gl_NormalMatrix * gl_Normal;

	gl_ClipVertex  = gl_ModelViewMatrix * gl_Vertex; // M (!)
	gl_Position    = gl_ProjectionMatrix * gl_ClipVertex;

	vertexWorldPos = gl_ClipVertex;

	vec4 cameraPos = gl_ProjectionMatrixInverse * vec4(0, 0, 0, 1); cameraPos.xyz /= cameraPos.w;

	cameraDir      = vertexWorldPos.xyz - cameraPos.xyz;

#if (USE_SHADOWS == 1)
	shadowVertexPos = shadowMatrix * vertexWorldPos;
	shadowVertexPos.xy += vec2(0.5);
#endif

	gl_TexCoord[0].st = gl_MultiTexCoord0.st;

#if (DEFERRED_MODE == 0)
	float fogCoord = length(cameraDir.xyz);
	fogFactor = (gl_Fog.end - fogCoord) * gl_Fog.scale; //gl_Fog.scale := 1.0 / (gl_Fog.end - gl_Fog.start)
	fogFactor = clamp(fogFactor, 0.0, 1.0);
#endif
}
#endif
