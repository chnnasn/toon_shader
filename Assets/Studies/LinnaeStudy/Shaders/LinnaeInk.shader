Shader "Hidden/Linnae/Ink"
{
 Properties{_BaseMap("Base",2D)="white"{} _Width("Pixel width",Float)=.65 _Ink("Ink",Color)=(.15,.09,.12,1) _Face("Face",Float)=0 _Hair("Hair",Float)=0}
 SubShader{Tags{"RenderPipeline"="UniversalPipeline"}
 Pass{Cull Front ZWrite Off ZTest LEqual
 HLSLPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
 CBUFFER_START(UnityPerMaterial)
 float4 _Ink;float _Width;float _Face;float _Hair;
 CBUFFER_END
 struct A{float4 p:POSITION;float3 n:NORMAL;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
 V vert(A a){V o;float3 ws=TransformObjectToWorld(a.p.xyz);float3 n=TransformObjectToWorldNormal(a.n);float4 p=TransformWorldToHClip(ws);float3 vn=mul((float3x3)UNITY_MATRIX_V,n);float2 d=normalize(vn.xy+1e-5);float distanceFade=saturate(2.5/max(p.w,.01));p.xy+=d*(_Width*lerp(1,.55,_Face)*distanceFade)*2/_ScreenParams.xy*p.w;
 #if UNITY_REVERSED_Z
 p.z-=lerp(.00012,.0012,_Hair)*p.w;
 #else
 p.z+=lerp(.00012,.0012,_Hair)*p.w;
 #endif
 o.p=p;o.uv=a.uv;return o;}
 half4 frag(V i):SV_Target{half4 t=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);clip(t.a-.3);return half4(lerp(_Ink.rgb,t.rgb*.24,.3),1);}
 ENDHLSL
 }}
}
