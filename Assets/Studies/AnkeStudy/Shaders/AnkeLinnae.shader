Shader "Anke/Linnae Layered"
{
Properties{
_NeckLightCorrection("Neck light seam correction",Vector)=(1,1,1,1)
_NeckDarkCorrection("Neck dark seam correction",Vector)=(1,1,1,1)
_LightBase("Light base",2D)="white"{}
_DarkBase("Dark base",2D)="white"{}
_Opacity("Opacity mask",2D)="white"{}
_BaseMap("Outline albedo",2D)="white"{}
_FaceSDF("Face SDF",2D)="white"{}
_Tint("Tint",Color)=(1,1,1,1)
_SkinTint("Skin tint",Color)=(1,1,1,1)
_ShadowTint("Shadow tint",Color)=(.79,.62,.63,1)
_BridgeUV("UV transform",Vector)=(1,1,0,0)
_HeadForward("Head forward",Vector)=(0,0,-1,0)
_HeadRight("Head right",Vector)=(1,0,0,0)
_HeadOrigin("Head origin",Vector)=(0,1.4,0,1)
_HeadUp("Head up",Vector)=(0,1,0,0)
_Threshold("Threshold",Float)=0.48
_Softness("Softness",Float)=0.09
_Roughness("Roughness",Float)=0.48
_Metallic("Metallic",Float)=0
_SpecularStrength("SpecularStrength",Float)=0.3
_RimStrength("RimStrength",Float)=0.04
_Hair("Hair",Float)=0
_Face("Face",Float)=0
_Skin("Skin",Float)=0
_Eye("Eye",Float)=0
_DebugMode("DebugMode",Float)=0
_EnvironmentStrength("EnvironmentStrength",Float)=0.65
_UseFaceSDF("UseFaceSDF",Float)=1
_HairShadowStrength("HairShadowStrength",Float)=0.32
_Cutoff("Cutoff",Float)=0.3
[KeywordEnum(Cutout, Blend)] _AlphaMode("Alpha mode", Float) = 0
[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src blend", Float) = 1
[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst blend", Float) = 0
[Enum(Off,0,On,1)] _ZWrite("ZWrite", Float) = 1
_BaseAlpha("Base alpha (blend mode)",Range(0,1))=1
_Cull("Cull",Float)=0
_BridgePreview("BridgePreview",Float)=0
_Ink("Ink",Float)=1
_LightWeight0("Light weight 0",2D)="black"{}
_BridgeLightColor0("Light layer 0",Color)=(0,0,0,1)
_LightWeight1("Light weight 1",2D)="black"{}
_BridgeLightColor1("Light layer 1",Color)=(0,0,0,1)
_LightWeight2("Light weight 2",2D)="black"{}
_BridgeLightColor2("Light layer 2",Color)=(0,0,0,1)
_LightWeight3("Light weight 3",2D)="black"{}
_BridgeLightColor3("Light layer 3",Color)=(0,0,0,1)
_LightWeight4("Light weight 4",2D)="black"{}
_BridgeLightColor4("Light layer 4",Color)=(0,0,0,1)
_DarkWeight0("Dark weight 0",2D)="black"{}
_BridgeDarkColor0("Dark layer 0",Color)=(0,0,0,1)
_DarkWeight1("Dark weight 1",2D)="black"{}
_BridgeDarkColor1("Dark layer 1",Color)=(0,0,0,1)
_DarkWeight2("Dark weight 2",2D)="black"{}
_BridgeDarkColor2("Dark layer 2",Color)=(0,0,0,1)
_DarkWeight3("Dark weight 3",2D)="black"{}
_BridgeDarkColor3("Dark layer 3",Color)=(0,0,0,1)
_DarkWeight4("Dark weight 4",2D)="black"{}
_BridgeDarkColor4("Dark layer 4",Color)=(0,0,0,1)
}
SubShader{Tags{"RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True"}
Pass{ Name "Forward" Tags{"LightMode"="UniversalForward"} Cull [_Cull]
Blend [_SrcBlend] [_DstBlend]
ZWrite [_ZWrite]
HLSLPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma shader_feature_local _ALPHAMODE_BLEND
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
#pragma multi_compile _ _ADDITIONAL_LIGHTS
#pragma multi_compile _ _SHADOWS_SOFT
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Assets/Studies/LinnaeStudy/Shaders/LinnaeLighting.hlsl"
TEXTURE2D(_LightBase); SAMPLER(sampler_LightBase);
TEXTURE2D(_DarkBase); SAMPLER(sampler_DarkBase);
TEXTURE2D(_Opacity); SAMPLER(sampler_Opacity);
TEXTURE2D(_FaceSDF); SAMPLER(sampler_FaceSDF);
TEXTURE2D(_LightWeight0); SAMPLER(sampler_LightWeight0);
TEXTURE2D(_LightWeight1); SAMPLER(sampler_LightWeight1);
TEXTURE2D(_LightWeight2); SAMPLER(sampler_LightWeight2);
TEXTURE2D(_LightWeight3); SAMPLER(sampler_LightWeight3);
TEXTURE2D(_LightWeight4); SAMPLER(sampler_LightWeight4);
TEXTURE2D(_DarkWeight0); SAMPLER(sampler_DarkWeight0);
TEXTURE2D(_DarkWeight1); SAMPLER(sampler_DarkWeight1);
TEXTURE2D(_DarkWeight2); SAMPLER(sampler_DarkWeight2);
TEXTURE2D(_DarkWeight3); SAMPLER(sampler_DarkWeight3);
TEXTURE2D(_DarkWeight4); SAMPLER(sampler_DarkWeight4);
CBUFFER_START(UnityPerMaterial)
float4 _NeckLightCorrection;
float4 _NeckDarkCorrection;
float4 _Tint;
float4 _SkinTint;
float4 _ShadowTint;
float4 _BridgeUV;
float4 _HeadForward;
float4 _HeadRight;
float4 _HeadOrigin;
float4 _HeadUp;
float4 _BridgeLightColor0;
float4 _BridgeLightColor1;
float4 _BridgeLightColor2;
float4 _BridgeLightColor3;
float4 _BridgeLightColor4;
float4 _BridgeDarkColor0;
float4 _BridgeDarkColor1;
float4 _BridgeDarkColor2;
float4 _BridgeDarkColor3;
float4 _BridgeDarkColor4;
float _Threshold;
float _Softness;
float _Roughness;
float _Metallic;
float _SpecularStrength;
float _RimStrength;
float _Hair;
float _Face;
float _Skin;
float _Eye;
float _DebugMode;
float _EnvironmentStrength;
float _UseFaceSDF;
float _HairShadowStrength;
float _Cutoff;
float _AlphaMode;
float _SrcBlend;
float _DstBlend;
float _ZWrite;
float _BaseAlpha;
float _Cull;
float _BridgePreview;
float _Ink;
CBUFFER_END
struct A{float4 p:POSITION;float3 n:NORMAL;float2 uv:TEXCOORD0;};
struct V{float4 p:SV_POSITION;float3 ws:TEXCOORD0;float3 n:TEXCOORD1;float2 uv:TEXCOORD2;};
V vert(A a){V o;o.ws=TransformObjectToWorld(a.p.xyz);o.p=TransformWorldToHClip(o.ws);o.n=TransformObjectToWorldNormal(a.n);o.uv=a.uv;return o;}
half4 frag(V i):SV_Target{
float2 uv=i.uv*_BridgeUV.xy+_BridgeUV.zw;
float alpha=SAMPLE_TEXTURE2D(_Opacity,sampler_Opacity,uv).r;
#ifndef _ALPHAMODE_BLEND
// Cutout: keep lace holes hard-edged, alpha is binarised and depth is written.
clip(alpha-_Cutoff);
#endif
float3 light=SAMPLE_TEXTURE2D(_LightBase,sampler_LightBase,uv).rgb*_SkinTint.rgb;
float3 dark=SAMPLE_TEXTURE2D(_DarkBase,sampler_DarkBase,uv).rgb*_SkinTint.rgb;
light+=SAMPLE_TEXTURE2D(_LightWeight0,sampler_LightWeight0,uv).rgb*_BridgeLightColor0.rgb;
light+=SAMPLE_TEXTURE2D(_LightWeight1,sampler_LightWeight1,uv).rgb*_BridgeLightColor1.rgb;
light+=SAMPLE_TEXTURE2D(_LightWeight2,sampler_LightWeight2,uv).rgb*_BridgeLightColor2.rgb;
light+=SAMPLE_TEXTURE2D(_LightWeight3,sampler_LightWeight3,uv).rgb*_BridgeLightColor3.rgb;
light+=SAMPLE_TEXTURE2D(_LightWeight4,sampler_LightWeight4,uv).rgb*_BridgeLightColor4.rgb;
dark+=SAMPLE_TEXTURE2D(_DarkWeight0,sampler_DarkWeight0,uv).rgb*_BridgeDarkColor0.rgb;
dark+=SAMPLE_TEXTURE2D(_DarkWeight1,sampler_DarkWeight1,uv).rgb*_BridgeDarkColor1.rgb;
dark+=SAMPLE_TEXTURE2D(_DarkWeight2,sampler_DarkWeight2,uv).rgb*_BridgeDarkColor2.rgb;
dark+=SAMPLE_TEXTURE2D(_DarkWeight3,sampler_DarkWeight3,uv).rgb*_BridgeDarkColor3.rgb;
dark+=SAMPLE_TEXTURE2D(_DarkWeight4,sampler_DarkWeight4,uv).rgb*_BridgeDarkColor4.rgb;
float3 col;float outAlpha;
// Use the same normal-based lighting on both sides of the neck seam.
// Face SDF fades in above the jaw; source body tones are corrected locally only.
float headHeight=dot(i.ws-_HeadOrigin.xyz,normalize(_HeadUp.xyz))/max(_HeadOrigin.w,.001);
float neckBlend=_Skin*(1-_Face)*smoothstep(-.10,-.020,headHeight);
light*=lerp(1.0.xxx,_NeckLightCorrection.rgb,neckBlend);
dark*=lerp(1.0.xxx,_NeckDarkCorrection.rgb,neckBlend);
float faceWeight=_Face*smoothstep(.012,.055,headHeight);
float3 shadowTint=clamp(dark/max(light,.025),.15,1.3)*_ShadowTint.rgb;
LinnaeLighting_float(float4(light,alpha),i.ws,normalize(i.n),GetWorldSpaceNormalizeViewDir(i.ws),uv,_Tint,float4(shadowTint,1),_Threshold,_Softness,_Roughness,_Metallic,_SpecularStrength,_RimStrength,_Hair,faceWeight,_Skin,1,1,_DebugMode,_EnvironmentStrength,_Eye,_HeadForward,_HeadRight,UnityBuildTexture2DStructNoScaleNoTexelSize(_FaceSDF),_UseFaceSDF,_HairShadowStrength,_HeadOrigin,_HeadUp,col,outAlpha);
if(_BridgePreview>.5)col=(_BridgePreview>1.5?dark:light)*_Tint.rgb;
#ifdef _ALPHAMODE_BLEND
// Gauze: the per-material alpha supplies the continuous translucency that the
// single _Opacity mask (built for lace cutout) cannot express on its own.
// Keep the mask's white lace opaque while lifting its black fabric region to
// the configured gauze alpha instead of multiplying that region back to zero.
outAlpha=max(outAlpha,saturate(_BaseAlpha));
#endif
return half4(col,outAlpha);
}
ENDHLSL
}
Pass {Name "ShadowCaster" Tags{"LightMode"="ShadowCaster"} Cull [_Cull] ZWrite On ZTest LEqual ColorMask 0
HLSLPROGRAM
#pragma vertex ShadowVert
#pragma fragment ShadowFrag
#pragma shader_feature_local _ALPHAMODE_BLEND
#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
TEXTURE2D(_Opacity);SAMPLER(sampler_Opacity);
float4 _BridgeUV;float _Cutoff;float3 _LightDirection;float3 _LightPosition;
struct A{float4 p:POSITION;float3 n:NORMAL;float2 uv:TEXCOORD0;};
struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
V ShadowVert(A a){V o;float3 ws=TransformObjectToWorld(a.p.xyz);float3 n=TransformObjectToWorldNormal(a.n);
#if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
float3 l=normalize(_LightPosition-ws);
#else
float3 l=_LightDirection;
#endif
o.p=TransformWorldToHClip(ApplyShadowBias(ws,n,l));
#if UNITY_REVERSED_Z
o.p.z=min(o.p.z,UNITY_NEAR_CLIP_VALUE*o.p.w);
#else
o.p.z=max(o.p.z,UNITY_NEAR_CLIP_VALUE*o.p.w);
#endif
o.uv=a.uv*_BridgeUV.xy+_BridgeUV.zw;return o;}
half4 ShadowFrag(V i):SV_Target{
#ifdef _ALPHAMODE_BLEND
// Blend (gauze): do not cast a solid silhouette shadow.
clip(-1);
#else
clip(SAMPLE_TEXTURE2D(_Opacity,sampler_Opacity,i.uv).r-_Cutoff);
#endif
return 0;}
ENDHLSL
}
Pass {Name "DepthOnly" Tags{"LightMode"="DepthOnly"} Cull [_Cull] ZWrite On ColorMask R
HLSLPROGRAM
#pragma vertex DepthVert
#pragma fragment DepthFrag
#pragma shader_feature_local _ALPHAMODE_BLEND
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
TEXTURE2D(_Opacity);SAMPLER(sampler_Opacity);float4 _BridgeUV;float _Cutoff;
struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
V DepthVert(A a){V o;o.p=TransformObjectToHClip(a.p.xyz);o.uv=a.uv*_BridgeUV.xy+_BridgeUV.zw;return o;}
half4 DepthFrag(V i):SV_Target{
#ifdef _ALPHAMODE_BLEND
// Blend (gauze): transparent surface must not write depth.
clip(-1);
#else
clip(SAMPLE_TEXTURE2D(_Opacity,sampler_Opacity,i.uv).r-_Cutoff);
#endif
return i.p.z;}
ENDHLSL
}
}
}
