// Baseline fragment formulas and blend states recovered from the Android GPU programs.
// URP pass routing is an adapter, not the original GFCharForward scheduler.
Shader "Clukay Study/Source Eye Blend"
{
 Properties
 {
  _MainTex("Source mask",2D)="white"{}
  _MainColor("Main Color",Color)=(1,1,1,0.85)
  _SpecularIntensity("Intensity",Range(0,2))=1
  [Toggle] _Multiply("Multiply channel",Float)=0
  [HideInInspector] _DebugMode("Diagnostic view",Float)=0
  [HideInInspector] _SrcBlend("Source blend",Float)=1
  [HideInInspector] _DstBlend("Destination blend",Float)=1
 }
 SubShader
 {
  Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry+458" "RenderType"="Opaque" }
  Pass
  {
   Name "SourceEyeBlendAdapter"
   Tags { "LightMode"="UniversalForwardOnly" }
   Blend [_SrcBlend] [_DstBlend]
   ZWrite Off ZTest LEqual Cull Back ColorMask RGB
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #pragma multi_compile_local _ GF2_SOURCE_MRT
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
   CBUFFER_START(UnityPerMaterial)
   float4 _MainTex_ST,_MainColor;
   float _SpecularIntensity,_Multiply,_DebugMode;
   CBUFFER_END
   struct Attributes { float4 positionOS:POSITION;float3 normalOS:NORMAL;float2 uv:TEXCOORD0; };
   struct Varyings { float4 positionCS:SV_POSITION;float3 normalWS:TEXCOORD0;float2 uv:TEXCOORD1; };
   Varyings vert(Attributes v)
   {
    Varyings o;o.positionCS=TransformObjectToHClip(v.positionOS.xyz);
    o.normalWS=TransformObjectToWorldNormal(v.normalOS);o.uv=TRANSFORM_TEX(v.uv,_MainTex);return o;
   }
   struct Outputs
   {
    float4 color:SV_Target0;
    #if defined(GF2_SOURCE_MRT)
    float auxiliaryDepth:SV_Target1;
    #endif
   };
   float4 EyeColor(Varyings i)
   {
    // Diagnostic views show the underlying eye mesh without additive/multiply tint.
    if(_DebugMode>.5)return _Multiply>.5?float4(1,1,1,1):float4(0,0,0,0);
    float4 sampled=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv)*_MainColor;
    // ShaderPrograms/eyeblend_multiply/0_12.glsl: 1 + intensity*(mask*color - 1).
    if(_Multiply>.5)return float4(1+_SpecularIntensity*(sampled.rgb-1),1);
    // ShaderPrograms/eyeblend_add/0_12.glsl: no PBR/ambient/extra specular on this layer.
    // The source does not renormalize the interpolated normal here.
    float directional=.2+.8*saturate(dot(i.normalWS,GetMainLight().direction));
    return float4(directional*sampled.rgb*_SpecularIntensity,sampled.a);
   }
   Outputs frag(Varyings i)
   {
    Outputs o;o.color=EyeColor(i);
    #if defined(GF2_SOURCE_MRT)
    // Both source eye blend MRT variants output this constant. Disabled until
    // the original attachment format/blending/consumer have been established.
    o.auxiliaryDepth=0.49900001287460327;
    #endif
    return o;
   }
   ENDHLSL
  }
 }
}
