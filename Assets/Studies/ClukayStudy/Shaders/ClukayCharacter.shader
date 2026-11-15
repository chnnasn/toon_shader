Shader "Clukay Study/Character"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Normal] _NormalMap("Normal", 2D) = "bump" {}
        _RMO("Roughness / Metallic / Occlusion", 2D) = "white" {}
        _HairMask("Hair highlight mask", 2D) = "white" {}
        _SourceRamp("Source four-row Ramp", 2D) = "white" {}
        [MainColor] _Tint("Tint", Color) = (1, 1, 1, 1)
        _ShadowTint("Shadow tint", Color) = (0.58, 0.48, 0.62, 1)
        _Threshold("Toon threshold", Range(0, 1)) = 0.52
        _Softness("Toon softness", Range(0.001, 0.5)) = 0.06
        _NormalStrength("Normal strength", Range(0, 2)) = 0.6
        _UseRMO("RMO texture weight", Range(0, 1)) = 1
        _Roughness("Fallback roughness", Range(0, 1)) = 0.6
        _Metallic("Fallback metallic", Range(0, 1)) = 0
        _RoughnessScale("Roughness scale", Float) = 1
        _MetallicScale("Metallic scale", Range(0, 1)) = 1
        _OcclusionStrength("Occlusion strength", Range(0, 1)) = 0.5
        _SpecularStrength("Specular strength", Float) = 0.6
        _SpecularAA("Specular antialiasing", Range(0, 1)) = 0.5
        _RimStrength("Rim strength", Float) = 0.12
        _NPRWeight("Toon diffuse weight", Range(0, 1)) = 0.35
        _EnvironmentStrength("Environment strength", Float) = 1
        _UseSourceRamp("Source Ramp weight", Range(0, 1)) = 0
        _Hair("Hair anisotropy weight", Range(0, 1)) = 0
        _HairShift("Hair highlight shift", Float) = 0.12
        _Face("Face softening weight", Range(0, 1)) = 0
        _SkinScatter("Wrapped skin diffuse", Float) = 0
        _Sheen("Stocking / fabric sheen", Float) = 0
        _Opacity("Opacity", Range(0, 1)) = 1
        _AlphaFresnel("Grazing coverage", Range(0, 1)) = 0
        _OutlineWidth("Outline width in object space", Float) = 0.0007
        [Toggle] _OutlineOnly("Outline renderer material", Float) = 0
        [HideInInspector] _LegacyLighting("Archived Toon lighting", Float) = 0
        [Enum(Shaded,0,Albedo,1,Normal,2,RMO,3,Shadow,4,Specular,5,Environment,6,Indirect,7,Alpha,8,Clay,9)] _DebugMode("Diagnostic view", Float) = 0
        [Toggle] _AlphaClip("Alpha clipping", Float) = 0
        _Cutoff("Alpha clip threshold", Range(0, 1)) = 0.33
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [Toggle] _ZWrite("Depth write", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Depth test", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination blend", Float) = 0
        [HideInInspector] _SrcBlendAlpha("Source alpha blend", Float) = 1
        [HideInInspector] _DstBlendAlpha("Destination alpha blend", Float) = 0
        [HideInInspector] _Surface("Surface", Float) = 0
        [HideInInspector] _AlphaToMask("Alpha to coverage", Float) = 0
        [Toggle] _CastShadows("Cast shadows", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }
        HLSLINCLUDE
        #pragma target 4.5
        #pragma multi_compile_instancing
        #include "ClukayCharacterCommon.hlsl"
        ENDHLSL

        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode" = "UniversalForwardOnly" }
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Blend [_SrcBlend] [_DstBlend], [_SrcBlendAlpha] [_DstBlendAlpha]
            AlphaToMask [_AlphaToMask]
            HLSLPROGRAM
            #pragma vertex ClukayVertex
            #pragma fragment ClukayForwardFragment
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fog
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _RECEIVE_SHADOWS_OFF
            ENDHLSL
        }
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "ClukayOutline" }
            Cull Front
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Blend [_SrcBlend] [_DstBlend], [_SrcBlendAlpha] [_DstBlendAlpha]
            AlphaToMask [_AlphaToMask]
            HLSLPROGRAM
            #pragma vertex ClukayVertex
            #pragma fragment ClukayOutlineFragment
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
            #pragma vertex ClukayShadowVertex
            #pragma fragment ClukayShadowFragment
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
            #pragma vertex ClukayVertex
            #pragma fragment ClukayDepthFragment
            ENDHLSL
        }
        Pass
        {
            Name "DepthNormalsOnly"
            Tags { "LightMode" = "DepthNormalsOnly" }
            Cull [_Cull]
            ZWrite On
            HLSLPROGRAM
            #pragma vertex ClukayVertex
            #pragma fragment ClukayDepthNormalsFragment
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            ENDHLSL
        }
    }
    Fallback Off
}
