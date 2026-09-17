#ifndef CLUKAY_STUDY_LIGHTING
#define CLUKAY_STUDY_LIGHTING
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif

// A reconstruction for this asset set, not extracted game shader code.
// RMO = R roughness, G metallic, B occlusion is an inspectable hypothesis.
void ClukayLighting_float(float4 Albedo, float4 NormalMap, float4 RMO,
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
    lightColor = light.color * light.distanceAttenuation;
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
#endif
