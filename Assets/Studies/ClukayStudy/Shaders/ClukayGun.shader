Shader "Clukay Study/Summer416"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Normal] _NormalMap("Normal", 2D) = "bump" {}
        _RMO("Roughness / Metallic / Occlusion", 2D) = "white" {}
        [MainColor] _Tint("Tint", Color) = (1, 1, 1, 1)
        _NormalStrength("Normal strength", Range(0, 2)) = 1
        _UseRMO("RMO texture weight", Range(0, 1)) = 1
        _RoughnessScale("Roughness scale", Float) = 1
        _MetallicScale("Metallic scale", Range(0, 1)) = 1
        _OcclusionStrength("Occlusion strength", Range(0, 1)) = 0.65
        _SpecularStrength("Specular strength", Range(0, 2)) = 0.35
        _AmbientStrength("Readable color floor", Range(0, 1.5)) = 1.05
        _DirectStrength("Directional modelling", Range(0, 2)) = 0.45
        _ShadowFloor("Shadow floor", Range(0, 1)) = 0.75
        _EnvironmentStrength("Reflection strength", Range(0, 1)) = 0.12
        _Opacity("Opacity", Range(0, 1)) = 1
        [Enum(Shaded,0,Albedo,1,Normal,2,RMO,3,Shadow,4,Specular,5,Alpha,6)] _DebugMode("Diagnostic view", Float) = 0
        [Toggle] _AlphaClip("Alpha clipping", Float) = 0
        _Cutoff("Alpha clip threshold", Range(0, 1)) = 0.33
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [Toggle] _ZWrite("Depth write", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Depth test", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination blend", Float) = 0
        [HideInInspector] _SrcBlendAlpha("Source alpha blend", Float) = 1
        [HideInInspector] _DstBlendAlpha("Destination alpha blend", Float) = 0
        [Toggle] _CastShadows("Cast shadows", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }

        HLSLINCLUDE
        #pragma target 4.5
        #pragma multi_compile_instancing
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
        TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
        TEXTURE2D(_RMO); SAMPLER(sampler_RMO);

        CBUFFER_START(UnityPerMaterial)
        float4 _Tint;
        float _NormalStrength, _UseRMO, _RoughnessScale, _MetallicScale;
        float _OcclusionStrength, _SpecularStrength, _AmbientStrength, _DirectStrength;
        float _ShadowFloor, _EnvironmentStrength, _Opacity, _DebugMode;
        float _AlphaClip, _Cutoff, _Cull, _ZWrite, _ZTest;
        float _SrcBlend, _DstBlend, _SrcBlendAlpha, _DstBlendAlpha, _CastShadows;
        CBUFFER_END

        float3 _LightDirection;
        float3 _LightPosition;

        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 uv : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float4 tangentWS : TEXCOORD2;
            float2 uv : TEXCOORD3;
            float fogFactor : TEXCOORD4;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        Varyings GunVertex(Attributes input)
        {
            Varyings output = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_TRANSFER_INSTANCE_ID(input, output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            VertexPositionInputs position = GetVertexPositionInputs(input.positionOS.xyz);
            VertexNormalInputs frame = GetVertexNormalInputs(input.normalOS, input.tangentOS);
            output.positionCS = position.positionCS;
            output.positionWS = position.positionWS;
            output.normalWS = frame.normalWS;
            output.tangentWS = float4(frame.tangentWS, input.tangentOS.w * GetOddNegativeScale());
            output.uv = input.uv;
            output.fogFactor = ComputeFogFactor(position.positionCS.z);
            return output;
        }

        float4 GunSurface(Varyings input, out float3 normalWS, out float4 rmo)
        {
            float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _Tint;
            float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalStrength);
            float3 bitangentWS = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
            normalWS = normalize(TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS)));
            rmo = SAMPLE_TEXTURE2D(_RMO, sampler_RMO, input.uv);
            if (_AlphaClip > 0.5) clip(albedo.a * _Opacity - _Cutoff);
            return albedo;
        }

        float4 GunForwardFragment(Varyings input) : SV_Target
        {
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            float3 N;
            float4 rmo;
            float4 albedo = GunSurface(input, N, rmo);
            float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
            float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
            Light main = GetMainLight(shadowCoord, input.positionWS, half4(1,1,1,1));
            float3 L = main.direction;
            float visibility = lerp(_ShadowFloor, 1, main.shadowAttenuation);
            float halfLambert = saturate(dot(N, L) * 0.5 + 0.5);
            float modelling = smoothstep(0.08, 0.92, halfLambert);
            float ao = lerp(1, rmo.b, saturate(_UseRMO * _OcclusionStrength));
            float roughness = clamp(lerp(0.6, rmo.r, _UseRMO) * _RoughnessScale, 0.08, 0.98);
            float metallic = saturate(rmo.g * _UseRMO * _MetallicScale);

            // The supplied atlas already carries the toy-like art direction. Keep its
            // yellow/green/cyan palette readable, then use light only for form modelling.
            float3 sh = max(SampleSH(N), 0);
            float3 color = albedo.rgb * (_AmbientStrength + sh * 0.18);
            color += albedo.rgb * main.color * modelling * visibility * _DirectStrength;
            color *= lerp(0.82, 1, ao);

            float3 H = normalize(L + V);
            float specPower = lerp(190, 7, roughness * roughness);
            float spec = pow(saturate(dot(N, H)), specPower) * visibility;
            float3 f0 = lerp(0.04.xxx, albedo.rgb, metallic);
            float3 specular = spec * f0 * main.color * _SpecularStrength;
            color += specular;

            float nv = saturate(dot(N, V));
            half3 environment = GlossyEnvironmentReflection(reflect(-V, N), input.positionWS, roughness, ao, 0);
            color += environment * lerp(0.04.xxx, albedo.rgb, metallic) * _EnvironmentStrength * pow(1 - nv, 2);

            float alpha = saturate(albedo.a * _Opacity);
            if (_DebugMode > 0.5 && _DebugMode < 1.5) color = albedo.rgb;
            if (_DebugMode > 1.5 && _DebugMode < 2.5) color = N * 0.5 + 0.5;
            if (_DebugMode > 2.5 && _DebugMode < 3.5) color = float3(roughness, metallic, ao);
            if (_DebugMode > 3.5 && _DebugMode < 4.5) color = modelling * visibility;
            if (_DebugMode > 4.5 && _DebugMode < 5.5) color = specular;
            if (_DebugMode > 5.5) color = alpha.xxx;
            return float4(MixFog(max(color, 0), input.fogFactor), alpha);
        }

        Varyings GunShadowVertex(Attributes input)
        {
            Varyings output = GunVertex(input);
            float3 lightDirection = _LightDirection;
            #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                lightDirection = normalize(_LightPosition - output.positionWS);
            #endif
            output.positionCS = TransformWorldToHClip(ApplyShadowBias(output.positionWS, output.normalWS, lightDirection));
            #if UNITY_REVERSED_Z
                output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE * output.positionCS.w);
            #else
                output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE * output.positionCS.w);
            #endif
            return output;
        }

        float4 GunDepthFragment(Varyings input) : SV_Target
        {
            float alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _Tint.a * _Opacity;
            if (_AlphaClip > 0.5) clip(alpha - _Cutoff);
            return 0;
        }

        float4 GunShadowFragment(Varyings input) : SV_Target
        {
            clip(_CastShadows - 0.5);
            return GunDepthFragment(input);
        }
        ENDHLSL

        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode" = "UniversalForwardOnly" }
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Blend [_SrcBlend] [_DstBlend], [_SrcBlendAlpha] [_DstBlendAlpha]
            HLSLPROGRAM
            #pragma vertex GunVertex
            #pragma fragment GunForwardFragment
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fog
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            Cull [_Cull]
            ZWrite On
            ZTest LEqual
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex GunShadowVertex
            #pragma fragment GunShadowFragment
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            Cull [_Cull]
            ZWrite On
            ColorMask R
            HLSLPROGRAM
            #pragma vertex GunVertex
            #pragma fragment GunDepthFragment
            ENDHLSL
        }
    }
    Fallback Off
}
