Shader "Daiyan/Approved Outline"
{
 Properties {
  _Opacity("Source opacity",2D)="white"{}
  _BridgeUV("Source UV transform",Vector)=(1,1,0,0)
  _OutlineWidth("Outline width (world metres)",Range(0,0.003))=0.00045
  _OutlineColor("Outline color",Color)=(0.015,0.012,0.018,1)
  _Cutoff("Alpha cutoff",Range(0,1))=0.5
  _OutlineEnabled("Enabled",Float)=1
 }
 SubShader {
  Tags {"RenderPipeline"="UniversalPipeline" "Queue"="AlphaTest-1" "RenderType"="TransparentCutout"}
  Pass {
   Name "Outline"
   Tags {"LightMode"="SRPDefaultUnlit"}
   Cull Off ZWrite On ZTest LEqual
   HLSLPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   TEXTURE2D(_Opacity);SAMPLER(sampler_Opacity);
   CBUFFER_START(UnityPerMaterial)
   float4 _BridgeUV,_OutlineColor;float _OutlineWidth,_Cutoff,_OutlineEnabled;
   CBUFFER_END
   struct A {float4 positionOS:POSITION;float3 normalOS:NORMAL;float2 uv:TEXCOORD0;};
   struct V {float4 positionCS:SV_POSITION;float2 uv:TEXCOORD0;float3 positionWS:TEXCOORD1;float3 normalWS:TEXCOORD2;};
   V vert(A i){V o;float3 pos=TransformObjectToWorld(i.positionOS.xyz);pos+=TransformObjectToWorldNormal(i.normalOS)*_OutlineWidth;o.positionWS=pos;o.normalWS=TransformObjectToWorldNormal(i.normalOS);o.positionCS=TransformWorldToHClip(pos);o.uv=i.uv*_BridgeUV.xy+_BridgeUV.zw;return o;}
   half4 frag(V i):SV_Target{clip(_OutlineEnabled-.5);clip(-dot(normalize(i.normalWS),GetWorldSpaceNormalizeViewDir(i.positionWS)));clip(SAMPLE_TEXTURE2D(_Opacity,sampler_Opacity,i.uv).r-_Cutoff);return _OutlineColor;}
   ENDHLSL
  }
 }
}
