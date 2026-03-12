#define textureS3o1 diffuseTex
#define textureS3o2 shadingTex
	uniform sampler2D textureS3o1;
	uniform sampler2D textureS3o2;
	uniform samplerCube specularTex;
	uniform samplerCube reflectTex;

	uniform vec3 sunDir;
	uniform vec3 sunDiffuse;
	uniform vec3 sunAmbient;
	uniform vec3 sunSpecular;
#if (USE_SHADOWS == 1)
	uniform sampler2DShadow shadowTex;
	uniform sampler2D shadowColorTex;
	uniform float shadowDensity;
#endif

// in opaque passes tc.a is always 1.0 [all objects], and alphaPass is 0.0
// in alpha passes tc.a is either one of alphaValues.xyzw [for units] *or*
// contains a distance fading factor [for features], and alphaPass is 1.0
// texture alpha-masking is done in both passes
uniform vec4 teamColor;
uniform vec4 nanoColor;

#if defined(RECOIL_CORE_PROFILE_MODEL)
in vec4 vertexWorldPos;
in vec3 cameraDir;
in float fogFactor;
in vec3 normalv;
in vec2 modelUV;
uniform vec4 recoilFogColor;

out vec4 fragColor;
out vec4 fragDataNorm;
out vec4 fragDataDiff;
out vec4 fragDataSpec;
out vec4 fragDataEmit;
out vec4 fragDataMisc;
#else
varying vec4 vertexWorldPos;
varying vec3 cameraDir;
varying float fogFactor;
varying vec3 normalv;
#endif

#if defined(RECOIL_CORE_PROFILE_MODEL)
	#if (USE_SHADOWS == 1)
	in vec4 shadowVertexPos;
	#endif
#else
	#if (USE_SHADOWS == 1)
	varying vec4 shadowVertexPos;
	#endif
#endif

#if defined(RECOIL_CORE_PROFILE_MODEL)
	#define SAMPLE_TEX2D(tex, uv) texture(tex, uv)
	#define SAMPLE_TEXCUBE(tex, dir) texture(tex, dir)
#else
	#define SAMPLE_TEX2D(tex, uv) texture2D(tex, uv)
	#define SAMPLE_TEXCUBE(tex, dir) textureCube(tex, dir)
#endif

vec3 GetShadowMult(float NdotL) {
	#if (USE_SHADOWS == 1)
		vec3 shadowCoord = shadowVertexPos.xyz / shadowVertexPos.w;
		#if defined(RECOIL_CORE_PROFILE_MODEL)
		float sh = min(textureProj(shadowTex, shadowVertexPos), smoothstep(0.0, 0.35, NdotL));
		vec3 shColor = texture(shadowColorTex, shadowCoord.xy).rgb;
		#else
		float sh = min(shadow2DProj(shadowTex, shadowVertexPos).r, smoothstep(0.0, 0.35, NdotL));
		vec3 shColor = texture2D(shadowColorTex, shadowCoord.xy).rgb;
		#endif
		return mix(1.0, sh, shadowDensity) * shColor;
	#else
		return vec3(1.0);
	#endif
}

#if (MAX_DYNAMIC_MODEL_LIGHTS > 0)
#if !defined(RECOIL_CORE_PROFILE_MODEL)
vec3 DynamicLighting(vec3 normal, vec3 diffuse, vec3 specular) {
	vec3 rgb = vec3(0.0);

	for (int i = 0; i < MAX_DYNAMIC_MODEL_LIGHTS; i++) {
		vec3 lightVec = gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].position.xyz - vertexWorldPos.xyz;
		vec3 halfVec = gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].halfVector.xyz;

		float lightRadius   = gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].constantAttenuation;
		float lightDistance = length(lightVec);
		float lightScale    = float(lightDistance <= lightRadius);

		float lightCosAngDiff = clamp(dot(normal, lightVec / lightDistance), 0.0, 1.0);
		float lightCosAngSpec = clamp(dot(normal, normalize(halfVec)), 0.0, 1.0);
		#ifdef OGL_SPEC_ATTENUATION
		float lightAttenuation =
			(gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].constantAttenuation) +
			(gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].linearAttenuation * lightDistance) +
			(gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].quadraticAttenuation * lightDistance * lightDistance);

		lightAttenuation = 1.0 / max(lightAttenuation, 1.0);
		#else
		float lightAttenuation = 1.0 - min(1.0, ((lightDistance * lightDistance) / (lightRadius * lightRadius)));
		#endif

		float vectorDot = dot((-lightVec / lightDistance), gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].spotDirection);
		float cutoffDot = gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].spotCosCutoff;

		lightScale *= float(vectorDot >= cutoffDot);

		rgb += (lightScale *                                    gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].ambient.rgb);
		rgb += (lightScale * lightAttenuation * (diffuse.rgb  * gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].diffuse.rgb * lightCosAngDiff));
		rgb += (lightScale * lightAttenuation * (specular.rgb * gl_LightSource[BASE_DYNAMIC_MODEL_LIGHT + i].specular.rgb * pow(lightCosAngSpec, 4.0)));
	}

	return rgb;
}
#else
vec3 DynamicLighting(vec3 normal, vec3 diffuse, vec3 specular) {
	return vec3(0.0);
}
#endif
#endif

void main(void)
{
	vec3 normal = normalize(normalv);

	float NdotLu = dot(normal, sunDir);
	float NdotL = max(NdotLu, 1e-3);
	vec3 light = NdotL * sunDiffuse + sunAmbient;

	#if defined(RECOIL_CORE_PROFILE_MODEL)
	vec4 diffuse     = SAMPLE_TEX2D(textureS3o1, modelUV);
	vec4 extraColor  = SAMPLE_TEX2D(textureS3o2, modelUV);
	#else
	vec4 diffuse     = SAMPLE_TEX2D(textureS3o1, gl_TexCoord[0].st);
	vec4 extraColor  = SAMPLE_TEX2D(textureS3o2, gl_TexCoord[0].st);
	#endif

	vec3 reflectDir = reflect(cameraDir, normal);
	vec3 specular   = SAMPLE_TEXCUBE(specularTex, reflectDir).rgb * sunSpecular;
	vec3 reflection = SAMPLE_TEXCUBE(reflectTex,  reflectDir).rgb;

	vec3 shadowMult = GetShadowMult(NdotL);
	float alpha = teamColor.a * extraColor.a; // apply one-bit mask

	specular *= (extraColor.g * 4.0);
	// no highlights if in shadowMult; decrease light to ambient level
	specular *= shadowMult;
	light = mix(sunAmbient, light, shadowMult);


	reflection  = mix(light, reflection, extraColor.g); // reflection
	reflection += extraColor.rrr; // self-illum

#if (DEFERRED_MODE == 0)
	#if defined(RECOIL_CORE_PROFILE_MODEL)
	fragColor     = diffuse;
	fragColor.rgb = mix(fragColor.rgb, teamColor.rgb, fragColor.a); // teamcolor
	fragColor.rgb = fragColor.rgb * reflection + specular;
	#else
	gl_FragColor     = diffuse;
	gl_FragColor.rgb = mix(gl_FragColor.rgb, teamColor.rgb, gl_FragColor.a); // teamcolor
	gl_FragColor.rgb = gl_FragColor.rgb * reflection + specular;
	#endif
#endif

#if (DEFERRED_MODE == 0 && MAX_DYNAMIC_MODEL_LIGHTS > 0)
	#if defined(RECOIL_CORE_PROFILE_MODEL)
	fragColor.rgb += DynamicLighting(normal, diffuse.rgb, specular);
	#else
	gl_FragColor.rgb += DynamicLighting(normal, diffuse.rgb, specular);
	#endif
#endif

#if (DEFERRED_MODE == 1)
	#if defined(RECOIL_CORE_PROFILE_MODEL)
	fragDataNorm = vec4((normal + vec3(1.0, 1.0, 1.0)) * 0.5, 1.0);
	fragDataDiff = vec4(mix(diffuse.rgb, teamColor.rgb, diffuse.a), alpha);
	fragDataDiff = vec4(mix(fragDataDiff.rgb, nanoColor.rgb, nanoColor.a), alpha);
	fragDataSpec = vec4(extraColor.rgb, alpha);
	fragDataEmit = vec4(0.0, 0.0, 0.0, 0.0);
	fragDataMisc = vec4(0.0, 0.0, 0.0, 0.0);
	#else
	gl_FragData[GBUFFER_NORMTEX_IDX] = vec4((normal + vec3(1.0, 1.0, 1.0)) * 0.5, 1.0);
	gl_FragData[GBUFFER_DIFFTEX_IDX] = vec4(mix(                         diffuse.rgb, teamColor.rgb,   diffuse.a), alpha);
	gl_FragData[GBUFFER_DIFFTEX_IDX] = vec4(mix(gl_FragData[GBUFFER_DIFFTEX_IDX].rgb, nanoColor.rgb, nanoColor.a), alpha);
	// do not premultiply reflection, leave it to the deferred lighting pass
	// gl_FragData[GBUFFER_DIFFTEX_IDX] = vec4(mix(diffuse.rgb, teamColor.rgb, diffuse.a) * reflection, alpha);
	// allows standard-lighting reconstruction by lazy LuaMaterials using us
	gl_FragData[GBUFFER_SPECTEX_IDX] = vec4(extraColor.rgb, alpha);
	gl_FragData[GBUFFER_EMITTEX_IDX] = vec4(0.0, 0.0, 0.0, 0.0);
	gl_FragData[GBUFFER_MISCTEX_IDX] = vec4(0.0, 0.0, 0.0, 0.0);
	#endif
#else
	#if defined(RECOIL_CORE_PROFILE_MODEL)
	fragColor.rgb = mix(recoilFogColor.rgb, fragColor.rgb, fogFactor); // fog
	fragColor.rgb = mix(fragColor.rgb, nanoColor.rgb, nanoColor.a); // wireframe or polygon color
	fragColor.a   = alpha;
	#else
	gl_FragColor.rgb = mix(gl_Fog.color.rgb, gl_FragColor.rgb, fogFactor); // fog
	gl_FragColor.rgb = mix(gl_FragColor.rgb, nanoColor.rgb, nanoColor.a); // wireframe or polygon color
	gl_FragColor.a   = alpha;
	#endif
#endif
}
