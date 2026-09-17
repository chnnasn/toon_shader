#ifndef KKBP_COLOR_586f30fda7e5440089ebae4830dc832b
#define KKBP_COLOR_586f30fda7e5440089ebae4830dc832b
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif
void KKBPColor_float(float3 PositionWS, float3 NormalWS, float3 ViewWS, float2 UV, float4 BridgeUV, float4 Tint, float4 SkinTint, float Threshold, float Softness, float BridgePreview, UnityTexture2D Opacity, UnityTexture2D LightBase, UnityTexture2D DarkBase, out float3 Color, out float Alpha){
float2 uv=BridgePreview>.5?UV:UV*BridgeUV.xy+BridgeUV.zw;
Alpha=SAMPLE_TEXTURE2D(Opacity.tex,Opacity.samplerstate,uv).r;
float3 LightResult=SAMPLE_TEXTURE2D(LightBase.tex,LightBase.samplerstate,uv).rgb*SkinTint.rgb;
float3 DarkResult=SAMPLE_TEXTURE2D(DarkBase.tex,DarkBase.samplerstate,uv).rgb*SkinTint.rgb;
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
