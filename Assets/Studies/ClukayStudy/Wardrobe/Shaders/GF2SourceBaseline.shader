Shader "Clukay Study/Source Uber Baseline Adapter"
{
    Properties
    {
        _BaseMap("Source Base Map",2D)="white"{}
        _BaseColor("Source Base Color (unverified instance)",Color)=(1,1,1,1)
        _BumpMap("Source Normal RG - RAW linear, NOT Unity normal import",2D)="bump"{}
        _RMOTex("Source Roughness/Metal/Occlusion/Emissive",2D)="white"{}
        _RampMap("Source four-row Ramp",2D)="white"{}
        [Toggle] _UseRampMap("Source Use Ramp (unverified instance)",Float)=0
        [Toggle] _UseGIFlatten("Source Flatten GI (unverified instance)",Float)=0
        _EmissiveIntensity("Source Emissive Intensity",Float)=0
        _FinalTint("Source Final Tint",Color)=(1,1,1,1)
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull",Float)=2
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Source Stencil Comparison (instance unknown)",Float)=0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilOp("Source Stencil Operation (instance unknown)",Float)=0
        _StencilRefC("Source Character Stencil Reference",Float)=206
        _DebugView("Adapter debug: 1 albedo 2 normal 3 RMO 4 direct 5 GI 6 env",Float)=0
    }
    SubShader
    {
        Tags {"RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry+10"}
        Pass
        {
            // Original is GFCharForward. This is explicitly a compatibility route.
            Name "SourceUberURPAdapter"
            Tags {"LightMode"="UniversalForwardOnly"}
            Cull [_Cull] ZWrite On ZTest LEqual
            Stencil { Ref [_StencilRefC] Comp [_StencilComp] Pass [_StencilOp] }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            // Experimental source attachment contract only. No renderer enables this
            // until a matching second attachment and its consumer are verified.
            #pragma multi_compile_local _ GF2_SOURCE_MRT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "GF2SourceBRDF.hlsl"
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);SAMPLER(sampler_BumpMap);
            TEXTURE2D(_RMOTex);SAMPLER(sampler_RMOTex);
            TEXTURE2D(_RampMap);SAMPLER(sampler_RampMap);
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST,_BumpMap_ST,_RMOTex_ST,_BaseColor,_FinalTint;
            float _UseRampMap,_UseGIFlatten,_EmissiveIntensity,_Cull,_DebugView;
            float _StencilComp,_StencilOp,_StencilRefC;
            CBUFFER_END
            struct Attributes {float4 positionOS:POSITION;float3 normalOS:NORMAL;float4 tangentOS:TANGENT;float2 uv:TEXCOORD0;};
            struct Varyings {float4 positionCS:SV_POSITION;float3 positionWS:TEXCOORD0;float3 normalWS:TEXCOORD1;float3 tangentWS:TEXCOORD2;float3 bitangentWS:TEXCOORD3;float2 uv:TEXCOORD4;};
            Varyings Vert(Attributes i)
            {
                Varyings o;VertexPositionInputs p=GetVertexPositionInputs(i.positionOS.xyz);
                VertexNormalInputs n=GetVertexNormalInputs(i.normalOS,i.tangentOS);
                o.positionCS=p.positionCS;o.positionWS=p.positionWS;o.normalWS=n.normalWS;
                o.tangentWS=n.tangentWS;o.bitangentWS=n.bitangentWS;o.uv=i.uv;return o;
            }
            struct Outputs
            {
                float4 color:SV_Target0;
                #if defined(GF2_SOURCE_MRT)
                float auxiliaryDepth:SV_Target1;
                #endif
            };
            Outputs Frag(Varyings i,FRONT_FACE_TYPE face:FRONT_FACE_SEMANTIC)
            {
                float3 rawNormal=IS_FRONT_VFACE(face,i.normalWS,-i.normalWS);
                float3 baseColor=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,TRANSFORM_TEX(i.uv,_BaseMap)).rgb*_BaseColor.rgb;
                float4 rmo=SAMPLE_TEXTURE2D(_RMOTex,sampler_RMOTex,TRANSFORM_TEX(i.uv,_RMOTex));
                float2 encoded=SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap,TRANSFORM_TEX(i.uv,_BumpMap)).rg;
                float3 N=GF2Normal(encoded,rawNormal,i.tangentWS,i.bitangentWS),V=GetWorldSpaceNormalizeViewDir(i.positionWS);
                Light light=GetMainLight();bool ramp=_UseRampMap>0;
                float3 spec;float3 direct=GF2MainBRDF(TEXTURE2D_ARGS(_RampMap,sampler_RampMap),ramp,baseColor,rmo.r,rmo.g,N,V,light.direction,spec)*light.color*light.distanceAttenuation;
                // Source baseline uses only SH L0/L1, not URP SampleSH's L2.
                float4 n4=float4(N,1);
                float3 sh=float3(dot(unity_SHAr,n4),dot(unity_SHAg,n4),dot(unity_SHAb,n4));
                float3 gi=(_UseGIFlatten>0?GF2FlattenGI(sh,float3(unity_SHAr.w,unity_SHAg.w,unity_SHAb.w)):max(sh,0))*baseColor*(1-rmo.g)*rmo.b;
                #if defined(_ADDITIONAL_LIGHTS)
                InputData inputData=(InputData)0;inputData.positionWS=i.positionWS;
                inputData.normalizedScreenSpaceUV=GetNormalizedScreenSpaceUV(i.positionCS);
                uint count=GetAdditionalLightsCount();
                LIGHT_LOOP_BEGIN(count)
                    Light a=GetAdditionalLight(lightIndex,i.positionWS+rawNormal*0.005);
                    direct+=baseColor*(1-rmo.g)*GF2DiffuseRamp(TEXTURE2D_ARGS(_RampMap,sampler_RampMap),dot(N,a.direction),0.875,ramp,false)*a.color*a.distanceAttenuation;
                LIGHT_LOOP_END
                #endif
                float3 f0=baseColor*rmo.g+0.04*(1-rmo.g);
                float4 probe=SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0,reflect(-V,N),rmo.r*6);
                float3 environment=DecodeHDREnvironment(probe,unity_SpecCube0_HDR)*GF2EnvironmentBRDF(TEXTURE2D_ARGS(_RampMap,sampler_RampMap),ramp,f0,rmo.r,N,V,light.direction,UNITY_MATRIX_I_V._m00_m10_m20);
                float3 color=(direct+gi+environment+baseColor*_EmissiveIntensity*rmo.a)*_FinalTint.rgb;
                if(_DebugView==1)color=baseColor;if(_DebugView==2)color=N*0.5+0.5;if(_DebugView==3)color=rmo.rgb;
                if(_DebugView==4)color=direct;if(_DebugView==5)color=gi;if(_DebugView==6)color=environment;
                // Original fog and selection/scene tint are not fabricated.
                Outputs o;o.color=float4(color,1);
                #if defined(GF2_SOURCE_MRT)
                // uber/108_12 SPIR-V: location 1 = gl_FragCoord.z.
                o.auxiliaryDepth=i.positionCS.z;
                #endif
                return o;
            }
            ENDHLSL
        }
    }
}
