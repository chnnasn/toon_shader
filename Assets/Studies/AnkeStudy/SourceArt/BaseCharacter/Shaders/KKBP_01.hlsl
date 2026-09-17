#ifndef KKBP_COLOR_156a64759547480395527da6366e0b8d
#define KKBP_COLOR_156a64759547480395527da6366e0b8d
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
