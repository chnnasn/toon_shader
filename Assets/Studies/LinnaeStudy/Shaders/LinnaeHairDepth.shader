Shader "Hidden/Linnae/HairDepth"
{
 Properties{_BaseMap("Base",2D)="white"{}}
 SubShader {Tags{"RenderPipeline"="UniversalPipeline"}
 Pass {Cull Off ZWrite On ZTest LEqual
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);float4x4 _LinnaeHairWorldToClip;
 struct A{float4 p:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;float depth:TEXCOORD1;};
 V vert(A a){V o;float4 p=mul(_LinnaeHairWorldToClip,float4(TransformObjectToWorld(a.p.xyz),1));o.p=p;o.uv=a.uv;o.depth=p.z/p.w;
 #if UNITY_REVERSED_Z
 o.depth=1-o.depth;
 #endif
 return o;}
 float frag(V i):SV_Target{clip(SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv).a-.3);return i.depth;}
 ENDHLSL
 }}
}
