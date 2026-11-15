#ifndef CLUKAY_CHARACTER_COMMON_INCLUDED
#define CLUKAY_CHARACTER_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
TEXTURE2D(_RMO); SAMPLER(sampler_RMO);
TEXTURE2D(_HairMask); SAMPLER(sampler_HairMask);
TEXTURE2D(_SourceRamp); SAMPLER(sampler_SourceRamp);

CBUFFER_START(UnityPerMaterial)
float4 _Tint, _ShadowTint;
float _Threshold, _Softness, _NormalStrength, _UseRMO;
float _Roughness, _Metallic, _OcclusionStrength, _SpecularStrength;
float _RimStrength, _Hair, _Face, _Opacity, _DebugMode;
float _NPRWeight, _EnvironmentStrength, _RoughnessScale, _MetallicScale;
float _Sheen, _SkinScatter, _HairShift, _AlphaFresnel, _SpecularAA, _UseSourceRamp;
float _OutlineWidth, _OutlineOnly, _LegacyLighting;
float _AlphaClip, _Cutoff, _Surface, _CastShadows;
float _Cull, _ZWrite, _ZTest, _SrcBlend, _DstBlend, _SrcBlendAlpha, _DstBlendAlpha, _AlphaToMask;
CBUFFER_END

float3 _LightDirection;
float3 _LightPosition;

struct ClukayAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct ClukayVaryings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
    float fogFactor : TEXCOORD3;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

ClukayVaryings ClukayVertex(ClukayAttributes input)
{
    ClukayVaryings output = (ClukayVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    // The retained outline renderer shares the source mesh and blend shapes.
    float3 positionOS = input.positionOS.xyz + normalize(input.normalOS) * _OutlineWidth * _OutlineOnly;
    VertexPositionInputs position = GetVertexPositionInputs(positionOS);
    output.positionCS = position.positionCS;
    output.positionWS = position.positionWS;
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    // Existing Shader Graph materials sample UV0 directly, including lace meshes
    // whose detail UVs have already been copied into their dedicated mesh assets.
    output.uv = input.uv;
    output.fogFactor = ComputeFogFactor(position.positionCS.z);
    return output;
}

ClukayVaryings ClukayShadowVertex(ClukayAttributes input)
{
    ClukayVaryings output = ClukayVertex(input);
    float3 lightDirection = _LightDirection;
    #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
        lightDirection = normalize(_LightPosition - output.positionWS);
    #endif
    output.positionCS = TransformWorldToHClip(ApplyShadowBias(output.positionWS, output.normalWS, lightDirection));
    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE * output.positionCS.w);
    #else
        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE * output.positionCS.w);
    #endif
    return output;
}

float ClukayCoverage(ClukayVaryings input)
{
    float coverage = saturate(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _Opacity);
    if (_OutlineOnly < 0.5)
    {
        coverage = saturate(coverage * _Tint.a);
        float nv = saturate(dot(normalize(input.normalWS), GetWorldSpaceNormalizeViewDir(input.positionWS)));
        coverage = saturate(coverage + (1 - coverage) * pow(1 - nv, 3) * _AlphaFresnel);
        coverage *= step(0.001, _Opacity);
    }
    return coverage;
}

void ClukayAlphaClip(float alpha)
{
    if (_AlphaClip > 0.5) clip(alpha - _Cutoff);
}

// Independent NPR + PBR reconstruction, NOT recovered original shader code.
// R/G/B = roughness/metallic/occlusion, confirmed by recovered uber shader metadata.
// GGX/Trowbridge-Reitz distribution, correlated Smith visibility, Schlick Fresnel.
float3 ClukayFresnel(float3 f0, float vh)
{
    float f = pow(1-saturate(vh),5);
    return f0+(1-f0)*f;
}
float3 ClukayHybridLight(float3 base, float3 N, float3 V, float3 strand,
    float3 L, float3 radiance, float visibility, float rough, float metal,
    float npr, float3 shadowTint, float threshold, float softness,
    float specStrength, float hair, float hairMask, float shift,
    float skin, float sheen, float useSourceRamp, out float3 specular)
{
    float nl=dot(N,L), nv=max(saturate(dot(N,V)),0.001);
    float3 H=normalize(L+V+1e-6);
    float nh=saturate(dot(N,H)), vh=saturate(dot(V,H));
    float a=rough*rough, a2=a*a;
    float d=nh*nh*(a2-1)+1;
    float D=a2/max(3.14159265*d*d,1e-6);
    float sl=saturate(nl);
    float vis=0.5/max(sl*sqrt(nv*nv*(1-a2)+a2)+nv*sqrt(sl*sl*(1-a2)+a2),0.001);
    float3 F=ClukayFresnel(lerp(0.04.xxx,base,metal),vh);
    float3 ggx=D*vis*F*sl;
    // UV-derived strand frame; shifted two-lobe Kajiya-Kay artistic hair model.
    float3 t1=normalize(strand+N*shift),t2=normalize(strand+N*(shift-0.27));
    float th1=dot(t1,H),th2=dot(t2,H);
    float h1=pow(sqrt(saturate(1-th1*th1)),lerp(160,25,rough));
    float h2=pow(sqrt(saturate(1-th2*th2)),24);
    float3 hairSpec=(h1*0.65+h2*0.16)*hairMask*lerp(0.7.xxx,base,0.3)*smoothstep(-0.2,0.6,nl);
    specular=lerp(ggx,hairSpec,hair)*specStrength*radiance*visibility;
    float band=smoothstep(threshold-softness,threshold+softness,nl*0.5+0.5);
    // NPR affects diffuse only. Metallic regions retain zero diffuse energy.
    float3 stylized=lerp(shadowTint*0.18,1.0.xxx,band);
    // Raw four-row game ramp data. Row interpretation is source-anchored;
    // the NL coordinate and combination remain an independent reconstruction.
    float3 recoveredRamp=SAMPLE_TEXTURE2D_LOD(_SourceRamp,sampler_SourceRamp,float2(saturate(nl*0.5+0.5),0.125),0).rgb;
    stylized=lerp(stylized,recoveredRamp,saturate(useSourceRamp));
    float wrapped=saturate((nl+0.35)/1.35);
    float3 diffuse=base*(1-metal)*(1-F)*lerp(sl.xxx,stylized,npr);
    diffuse+=base*(1-metal)*skin*float3(1,0.36,0.22)*max(wrapped-sl,0)*0.35;
    float grazing=pow(1-nv,4)*sheen*sl*(1-metal);
    return (diffuse+grazing*lerp(1.0.xxx,base,0.5))*radiance*visibility+specular;
}

void EvaluateClukaySurface(float4 Albedo, float4 NormalMap, float4 RMO,
    float4 HairMask, float3 PositionWS, float3 NormalWS, float3 ViewWS, float2 UV,
    float4 Tint, float4 ShadowTint, float Threshold, float Softness,
    float NormalStrength, float UseRMO, float Roughness, float Metallic,
    float OcclusionStrength, float SpecularStrength, float RimStrength,
    float Hair, float Face, float Opacity, float DebugMode,
    float NPRWeight, float EnvironmentStrength, float RoughnessScale,
    float Sheen, float SkinScatter, float HairShift, float AlphaFresnel, float SpecularAA, float MetallicScale,
    float UseSourceRamp,
    out float3 Color, out float Alpha)
{
    float3 N=normalize(NormalWS), V=normalize(ViewWS);
    float3 dp1=ddx(PositionWS),dp2=ddy(PositionWS);
    float2 du1=ddx(UV),du2=ddy(UV);
    float3 p2=cross(dp2,N),p1=cross(N,dp1);
    float3 T=p2*du1.x+p1*du2.x,B=p2*du1.y+p1*du2.y;
    float inv=rsqrt(max(max(dot(T,T),dot(B,B)),1e-12));
    float3 ts=NormalMap.xyz*2-1;
#ifndef SHADERGRAPH_PREVIEW
    ts=UnpackNormal(NormalMap);
#endif
    ts.xy*=NormalStrength; ts=normalize(ts);
    N=normalize(T*inv*ts.x+B*inv*ts.y+N*ts.z);
    float3 strand=normalize(B+float3(0,1e-5,0));
    float rough=clamp(lerp(Roughness,RMO.r,saturate(UseRMO))*RoughnessScale,0.10,0.97);
    float variance=dot(ddx(N),ddx(N))+dot(ddy(N),ddy(N));
    rough=sqrt(saturate(rough*rough+min(variance*SpecularAA,0.15)));
    float metal=saturate(lerp(Metallic,RMO.g,saturate(UseRMO)))*saturate(MetallicScale);
    float ao=lerp(1,RMO.b,saturate(UseRMO*OcclusionStrength));
    float3 base=Albedo.rgb*Tint.rgb;
    // Diagnostic clay view: neutral diffuse material; keep alpha cutouts and normals.
    // Mode zero is unchanged and no material asset is edited by the UI.
    if(DebugMode>8.5){base=0.7.xxx;rough=0.85;metal=0;ao=1;Hair=0;NPRWeight=0;SkinScatter=0;Sheen=0;RimStrength=0;SpecularStrength=0.15;}
    float3 L=normalize(float3(-0.4,0.6,-0.6)),radiance=1,ambient=0.15;
    float visibility=1;
    float2 screenUV=0;
#ifndef SHADERGRAPH_PREVIEW
    float4 shadowCoord=TransformWorldToShadowCoord(PositionWS);
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
        shadowCoord=ComputeScreenPos(TransformWorldToHClip(PositionWS));
    #endif
    Light main=GetMainLight(shadowCoord,PositionWS,half4(1,1,1,1));
    // The URP ForwardOnly pass already selects the scene's directional main light.
    // Its distance attenuation can be zero in the deferred renderer's explicit
    // ForwardOnly route, while direction, color and shadow data remain valid.
    L=main.direction; radiance=main.color;
    visibility=main.shadowAttenuation;
    ambient=max(SampleSH(N),0);
    float4 screenPos=ComputeScreenPos(TransformWorldToHClip(PositionWS));
    screenUV=screenPos.xy/max(screenPos.w,1e-5);
#endif
    // No source face SDF is present. Face receives a softened ramp, not fake SDF claims.
    float npr=saturate(NPRWeight), soft=max(Softness,lerp(0.005,0.12,Face));
    float3 directSpec;
    // Artistic face shadow attenuation; this is not the game's face-shadow algorithm.
    float faceVisibility=lerp(visibility,lerp(0.55,1,visibility),Face);
    float3 direct=ClukayHybridLight(base,N,V,strand,L,radiance,faceVisibility,rough,metal,npr,
        ShadowTint.rgb,Threshold,soft,SpecularStrength,Hair,HairMask.r,HairShift,SkinScatter,Sheen,UseSourceRamp,directSpec);
#ifndef SHADERGRAPH_PREVIEW
    #if defined(_ADDITIONAL_LIGHTS)
    InputData inputData=(InputData)0;
    inputData.positionWS=PositionWS;inputData.normalizedScreenSpaceUV=screenUV;
    uint count=GetAdditionalLightsCount();
    #if USE_CLUSTER_LIGHT_LOOP
    [loop] for(uint lightIndex=0;lightIndex<min(URP_FP_DIRECTIONAL_LIGHTS_COUNT,MAX_VISIBLE_LIGHTS);lightIndex++)
    {
        CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
        Light light=GetAdditionalLight(lightIndex,PositionWS,half4(1,1,1,1));
        float3 sp;
        direct+=ClukayHybridLight(base,N,V,strand,light.direction,light.color*light.distanceAttenuation,
            light.shadowAttenuation,rough,metal,npr,ShadowTint.rgb,Threshold,soft,SpecularStrength,
            Hair,HairMask.r,HairShift,SkinScatter,Sheen,UseSourceRamp,sp); directSpec+=sp;
    }
    #endif
    LIGHT_LOOP_BEGIN(count)
        Light light=GetAdditionalLight(lightIndex,PositionWS,half4(1,1,1,1));
        float3 sp;
        direct+=ClukayHybridLight(base,N,V,strand,light.direction,light.color*light.distanceAttenuation,
            light.shadowAttenuation,rough,metal,npr,ShadowTint.rgb,Threshold,soft,SpecularStrength,
            Hair,HairMask.r,HairShift,SkinScatter,Sheen,UseSourceRamp,sp); directSpec+=sp;
    LIGHT_LOOP_END
    #endif
#endif
    float nv=saturate(dot(N,V));
    float3 indirectDiffuse=ambient*base*(1-metal)*ao;
    float3 indirectSpec=0;
#ifndef SHADERGRAPH_PREVIEW
    // Use URP's prefiltered reflection probes and environment BRDF, not a fixed rim.
    half alphaForBRDF=1;
    BRDFData brdf;
    half3 f0=lerp(half3(0.04,0.04,0.04),base,metal);
    half reflectivity=max(max(f0.r,f0.g),f0.b);
    InitializeBRDFDataDirect(base,base*(1-metal)*0.96,f0,reflectivity,1-reflectivity,1-rough,alphaForBRDF,brdf);
    half3 env=GlossyEnvironmentReflection(reflect(-V,N),PositionWS,rough,ao,screenUV);
    indirectSpec=EnvironmentBRDFSpecular(brdf,pow(1-nv,4))*env*EnvironmentStrength*SpecularStrength;
    indirectSpec*=lerp(1,0.3,Hair);
#endif
    float rim=pow(1-nv,4)*smoothstep(-0.3,0.8,dot(N,L))*RimStrength;
    Color=max(direct+indirectDiffuse+indirectSpec+rim*radiance,0);
    float coverage=saturate(Albedo.a*Tint.a*Opacity);
    Alpha=saturate(coverage+(1-coverage)*pow(1-nv,3)*AlphaFresnel)*step(0.001,Opacity);
    if(DebugMode>0.5&&DebugMode<1.5) Color=base;
    if(DebugMode>1.5&&DebugMode<2.5) Color=N*0.5+0.5;
    if(DebugMode>2.5&&DebugMode<3.5) Color=float3(rough,metal,ao);
    if(DebugMode>3.5&&DebugMode<4.5) Color=visibility*saturate(dot(N,L));
    if(DebugMode>4.5&&DebugMode<5.5) Color=directSpec;
    if(DebugMode>5.5&&DebugMode<6.5) Color=indirectSpec;
    if(DebugMode>6.5&&DebugMode<7.5) Color=indirectDiffuse;
    if(DebugMode>7.5&&DebugMode<8.5) Color=Alpha;
}

// A reconstruction for this asset set, not extracted game shader code.
// RMO = R roughness, G metallic, B occlusion is an inspectable hypothesis.
void EvaluateLegacyClukaySurface(float4 Albedo, float4 NormalMap, float4 RMO,
    float4 HairMask, float3 PositionWS, float3 NormalWS, float3 ViewWS, float2 UV,
    float4 Tint, float4 ShadowTint, float Threshold, float Softness,
    float NormalStrength, float UseRMO, float Roughness, float Metallic,
    float OcclusionStrength, float SpecularStrength, float RimStrength,
    float Hair, float Face, float Opacity, float DebugMode,
    out float3 Color, out float Alpha)
{
    float3 N = normalize(NormalWS);
    float3 V = normalize(ViewWS);
    float3 L = normalize(float3(-0.45,0.65,-0.6));
    float3 lightColor = 1;
    float shadow = 1;
    float3 ambient = float3(0.13,0.15,0.20);
#ifndef SHADERGRAPH_PREVIEW
    float4 shadowCoord = TransformWorldToShadowCoord(PositionWS);
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
        shadowCoord = ComputeScreenPos(TransformWorldToHClip(PositionWS));
    #endif
    Light light = GetMainLight(shadowCoord, PositionWS, half4(1,1,1,1));
    L = light.direction;
    lightColor = light.color;
    shadow = light.shadowAttenuation;
    ambient = max(SampleSH(N),0.035);
#endif
    float3 normalTS = NormalMap.xyz * 2 - 1;
#ifndef SHADERGRAPH_PREVIEW
    normalTS = UnpackNormal(NormalMap);
#endif
    normalTS.xy *= NormalStrength;
    normalTS = normalize(normalTS);
    // Derivative cotangent frame handles imported UV seams and mirrored islands.
    float3 dp1 = ddx(PositionWS), dp2 = ddy(PositionWS);
    float2 duv1 = ddx(UV), duv2 = ddy(UV);
    float3 p2 = cross(dp2,N), p1 = cross(N,dp1);
    float3 T = p2*duv1.x + p1*duv2.x;
    float3 B = p2*duv1.y + p1*duv2.y;
    float inv = rsqrt(max(max(dot(T,T),dot(B,B)),1e-12));
    float3 mappedN = normalize(T*inv*normalTS.x+B*inv*normalTS.y+N*normalTS.z);
    N = normalize(lerp(N,mappedN,saturate(NormalStrength)));

    float rough = clamp(lerp(Roughness,RMO.r,UseRMO),0.08,0.98);
    float metal = saturate(lerp(Metallic,RMO.g,UseRMO));
    float ao = lerp(1,RMO.b,saturate(UseRMO*OcclusionStrength));
    float3 base = Albedo.rgb*Tint.rgb;
    float ndl = dot(N,L);
    // Face mode softens geometry shadowing. No face SDF was supplied.
    float halfLambert = ndl * 0.5 + 0.5;
    float band = smoothstep(Threshold-Softness,Threshold+Softness,halfLambert);
    band = lerp(band,smoothstep(0.18,0.7,halfLambert),Face);
    float visibility = lerp(shadow,1,Face*0.40);
    float3 diffuse = base * lerp(ShadowTint.rgb,1,band*visibility);
    diffuse *= (ambient*0.50 + lightColor*0.82)*lerp(0.65,1,ao);
    float3 H = normalize(L+V);
    float spec = pow(saturate(dot(N,H)),lerp(170,8,rough*rough));
    spec = lerp(spec,smoothstep(0.35,0.70,spec),0.45);
    // A masked stretched highlight for the provided hair specular map.
    float hairBand = pow(saturate(1-abs(dot(N,H)-0.78)*4),3);
    spec = lerp(spec,hairBand*HairMask.r,Hair);
    float3 specColor = lerp(float3(0.12,0.12,0.12),base,metal);
    float3 highlight = spec * specColor * SpecularStrength * lightColor * visibility;
    float rim = pow(1-saturate(dot(N,V)),4) * smoothstep(-0.3,0.8,ndl);
    Color = max(diffuse+highlight+rim*RimStrength*float3(0.63,0.74,0.92),0);
    Alpha = saturate(Albedo.a*Tint.a*Opacity);
    if(DebugMode>0.5 && DebugMode<1.5) Color=base;
    if(DebugMode>1.5 && DebugMode<2.5) Color=N*0.5+0.5;
    if(DebugMode>2.5 && DebugMode<3.5) Color=RMO.rgb;
    if(DebugMode>3.5 && DebugMode<4.5) Color=band*visibility;
    if(DebugMode>4.5) Color=highlight;
}

float4 ClukayForwardFragment(ClukayVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    clip(0.5 - _OutlineOnly);
    float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
    float4 rmo = SAMPLE_TEXTURE2D(_RMO, sampler_RMO, input.uv);
    float4 hairMask = SAMPLE_TEXTURE2D(_HairMask, sampler_HairMask, input.uv);
    float3 color;
    float alpha;
    float3 normalWS = normalize(input.normalWS);
    float3 viewWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    if (_LegacyLighting > 0.5)
    {
        EvaluateLegacyClukaySurface(albedo, normalMap, rmo, hairMask,
            input.positionWS, normalWS, viewWS, input.uv, _Tint, _ShadowTint,
            _Threshold, _Softness, _NormalStrength, _UseRMO, _Roughness, _Metallic,
            _OcclusionStrength, _SpecularStrength, _RimStrength, _Hair, _Face,
            _Opacity, _DebugMode, color, alpha);
    }
    else
    {
        EvaluateClukaySurface(albedo, normalMap, rmo, hairMask,
            input.positionWS, normalWS, viewWS, input.uv, _Tint, _ShadowTint,
            _Threshold, _Softness, _NormalStrength, _UseRMO, _Roughness, _Metallic,
            _OcclusionStrength, _SpecularStrength, _RimStrength, _Hair, _Face,
            _Opacity, _DebugMode, _NPRWeight, _EnvironmentStrength, _RoughnessScale,
            _Sheen, _SkinScatter, _HairShift, _AlphaFresnel, _SpecularAA, _MetallicScale,
            _UseSourceRamp, color, alpha);
    }
    ClukayAlphaClip(alpha);
    return float4(MixFog(color, input.fogFactor), alpha);
}

float4 ClukayOutlineFragment(ClukayVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    clip(_OutlineOnly - 0.5);
    float alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _Opacity;
    ClukayAlphaClip(alpha);
    return float4(MixFog(float3(0.016, 0.012, 0.024), input.fogFactor), alpha);
}

float4 ClukayDepthFragment(ClukayVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    ClukayAlphaClip(ClukayCoverage(input));
    return 0;
}

float4 ClukayShadowFragment(ClukayVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    clip(_CastShadows - 0.5);
    ClukayAlphaClip(ClukayCoverage(input));
    return 0;
}

float4 ClukayDepthNormalsFragment(ClukayVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    ClukayAlphaClip(ClukayCoverage(input));
    // The previous graph's NormalTS block used its default geometric normal.
    float3 normalWS = normalize(input.normalWS);
    #if defined(_GBUFFER_NORMALS_OCT)
        float2 octNormal = PackNormalOctQuadEncode(normalWS);
        return float4(PackFloat2To888(saturate(octNormal * 0.5 + 0.5)), 0);
    #else
        return float4(normalWS, 0);
    #endif
}
#endif
