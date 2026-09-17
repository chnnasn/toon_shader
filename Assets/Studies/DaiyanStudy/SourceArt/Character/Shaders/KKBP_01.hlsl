#ifndef KKBP_COLOR_69c5c98973e84ee7ad1e26bd194e2ad6
#define KKBP_COLOR_69c5c98973e84ee7ad1e26bd194e2ad6
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif
void KKBPColor_float(float3 PositionWS, float3 NormalWS, float3 ViewWS, float2 UV, float4 BridgeUV, float4 Tint, float4 SkinTint, float Threshold, float Softness, float BridgePreview, UnityTexture2D Opacity, UnityTexture2D LightBase, UnityTexture2D DarkBase, UnityTexture2D LightWeight0, UnityTexture2D LightWeight1, UnityTexture2D LightWeight2, UnityTexture2D LightWeight3, UnityTexture2D LightWeight4, UnityTexture2D DarkWeight0, UnityTexture2D DarkWeight1, UnityTexture2D DarkWeight2, UnityTexture2D DarkWeight3, UnityTexture2D DarkWeight4, float4 BridgeLightColor0, float4 BridgeLightColor1, float4 BridgeLightColor2, float4 BridgeLightColor3, float4 BridgeLightColor4, float4 BridgeDarkColor0, float4 BridgeDarkColor1, float4 BridgeDarkColor2, float4 BridgeDarkColor3, float4 BridgeDarkColor4, out float3 Color, out float Alpha){
float2 uv=BridgePreview>.5?UV:UV*BridgeUV.xy+BridgeUV.zw;
Alpha=SAMPLE_TEXTURE2D(Opacity.tex,Opacity.samplerstate,uv).r;
float3 LightResult=SAMPLE_TEXTURE2D(LightBase.tex,LightBase.samplerstate,uv).rgb*SkinTint.rgb;
LightResult+=SAMPLE_TEXTURE2D(LightWeight0.tex,LightBase.samplerstate,uv).rgb*BridgeLightColor0.rgb;
LightResult+=SAMPLE_TEXTURE2D(LightWeight1.tex,LightBase.samplerstate,uv).rgb*BridgeLightColor1.rgb;
LightResult+=SAMPLE_TEXTURE2D(LightWeight2.tex,LightBase.samplerstate,uv).rgb*BridgeLightColor2.rgb;
LightResult+=SAMPLE_TEXTURE2D(LightWeight3.tex,LightBase.samplerstate,uv).rgb*BridgeLightColor3.rgb;
LightResult+=SAMPLE_TEXTURE2D(LightWeight4.tex,LightBase.samplerstate,uv).rgb*BridgeLightColor4.rgb;
float3 DarkResult=SAMPLE_TEXTURE2D(DarkBase.tex,DarkBase.samplerstate,uv).rgb*SkinTint.rgb;
DarkResult+=SAMPLE_TEXTURE2D(DarkWeight0.tex,LightBase.samplerstate,uv).rgb*BridgeDarkColor0.rgb;
DarkResult+=SAMPLE_TEXTURE2D(DarkWeight1.tex,LightBase.samplerstate,uv).rgb*BridgeDarkColor1.rgb;
DarkResult+=SAMPLE_TEXTURE2D(DarkWeight2.tex,LightBase.samplerstate,uv).rgb*BridgeDarkColor2.rgb;
DarkResult+=SAMPLE_TEXTURE2D(DarkWeight3.tex,LightBase.samplerstate,uv).rgb*BridgeDarkColor3.rgb;
DarkResult+=SAMPLE_TEXTURE2D(DarkWeight4.tex,LightBase.samplerstate,uv).rgb*BridgeDarkColor4.rgb;
// Neck seam calibration from 27 coincident face/body vertices (normals agree).
// UV-local fade preserves the approved skin color outside the neck and all editable layers.
float neckJoin = smoothstep(0.965, 0.994, uv.y) * smoothstep(0.11, 0.123, uv.x) * (1.0 - smoothstep(0.489, 0.505, uv.x));
LightResult *= lerp(float3(1,1,1), float3(1.111776,1.191278,1.126345), neckJoin);
DarkResult *= lerp(float3(1,1,1), float3(1.117851,1.307736,1.291777), neckJoin);
if(BridgePreview>.5){Color=BridgePreview>1.5?DarkResult:LightResult;return;}
#ifdef SHADERGRAPH_PREVIEW
Color=LightResult*Tint.rgb;
#else
Light mainLight=GetMainLight();
float band=smoothstep(Threshold-Softness,Threshold+Softness,dot(normalize(NormalWS),mainLight.direction));
Color=max(0,lerp(DarkResult,LightResult,band))*Tint.rgb*max(mainLight.color,SampleSH(normalize(NormalWS)));
#endif
}
#endif
