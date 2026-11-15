Shader "AetherGazer/Wuchang Character Reconstructed"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _RampMap("Ramp Map", 2D) = "white" {}
        _RampStrength("Ramp Strength", Range(0,1)) = 0.15
        _RampRow("Ramp Row", Range(0,1)) = 0.95
        _ShadowColor("Shadow Color", Color) = (0.72,0.64,0.70,1)
        _ShadowRange("Shadow Range", Vector) = (0.18,0.60,0,0)
        _BumpMap("Normal Map", 2D) = "bump" {}
        _HairMaskMap("Hair Mask", 2D) = "white" {}
        _HairMaskStrength("Hair Anisotropy", Range(0,1)) = 0
        _StockingNormalMap("Stocking Normal", 2D) = "gray" {}
        _StockingCenterColor("Stocking Center", Color) = (1,1,1,1)
        _StockingFalloffColor("Stocking Falloff", Color) = (1,1,1,1)
        _StockingAbsorptionColor("Stocking Absorption", Color) = (1,1,1,1)
        _StockingStrength("Stocking Strength", Range(0,1)) = 0
        _StockingPatternStrength("Stocking Pattern", Range(0,1)) = 0.2
        _StockingInt("Stocking View Exponent", Range(0.01,4)) = 1
        _StockingNormalIntensity("Stocking Normal Intensity", Range(0,1)) = 0.2
        _StockingBaseLift("Stocking Base Lift", Range(0,1)) = 0
        _StockingTiling("Stocking Tiling", Vector) = (10,620.16,0,0)
        _FaceSDFMap("Face SDF", 2D) = "white" {}
        _FaceSDFStrength("Face SDF Strength", Range(0,1)) = 0
        _FaceSDFSoftness("Face SDF Softness", Range(0.001,0.2)) = 0.025
        _FaceShadowTint("Face Shadow Tint", Color) = (0.90,0.82,0.84,1)
        _RMKMap("RMK (R metallic, G emissive, B AO, A roughness)", 2D) = "white" {}
        _RMKOcclusionStrength("RMK AO", Range(0,1)) = 0.18
        _SpecStrength("Specular Strength", Range(0,2)) = 0.08
        _SpecPower("Specular Power", Range(1,256)) = 64
        _RimStrength("Rim Strength", Range(0,1)) = 0.03
        _RimPower("Rim Power", Range(1,16)) = 4
        _Opacity("Opacity", Range(0,1)) = 1
        _AlphaClip("Alpha Clip", Float) = 0
        _Cutoff("Cutoff", Range(0,1)) = 0.5
        _ReflectionTint("Reflection Tint", Color) = (0.72,0.78,0.9,1)
        _ReflectionStrength("Reflection Strength", Range(0,1)) = 0.08
        _HairTransmissionStrength("Hair Transmission", Range(0,1)) = 0.08
        _OutlineColor("Outline Color", Color) = (0.10,0.085,0.13,1)
        _OutlineWidth("Outline Width (Pixels)", Range(0,4)) = 1.15
        _OutlineIntensity("Outline Intensity", Range(0,1)) = 1
        _OutlineZBias("Outline Z Bias", Range(0,0.01)) = 0.001

        [HideInInspector] _UseFringeShadowCaster("Fringe Shadow Caster", Float) = 0
        [HideInInspector] _UseFringeShadowReceiver("Fringe Shadow Receiver", Float) = 0
        [HideInInspector] _HairShadowOffsetX("Hair Shadow Offset X", Float) = -0.00232
        [HideInInspector] _HairShadowOffsetY("Hair Shadow Offset Y", Float) = 0.00508
        [HideInInspector] _HairShadowDepthBias("Hair Shadow Depth Bias", Float) = 0
        [HideInInspector] _StencilComp("Stencil Comparison", Float) = 8
        [HideInInspector] _StencilOp("Stencil Operation", Float) = 0
        [HideInInspector] _StencilRefC("Character Stencil Ref", Float) = 206
        [HideInInspector] _WriteMask("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilRefShadowCaster("Stencil Shadow Caster", Float) = 200
        [HideInInspector] _StencilRefShadowReceiver("Stencil Shadow Receiver", Float) = 201
        [HideInInspector] _Cull("Cull", Float) = 2
        [HideInInspector] _ZWrite("ZWrite", Float) = 1
        [HideInInspector] _SrcBlend("Src Blend", Float) = 1
        [HideInInspector] _DstBlend("Dst Blend", Float) = 0
        [HideInInspector] _BlendAlphaSrc("Src Blend Alpha", Float) = 1
        [HideInInspector] _BlendAlphaDst("Dst Blend Alpha", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" "RenderType"="Opaque" }

        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend], [_BlendAlphaSrc] [_BlendAlphaDst]
            ZWrite [_ZWrite]
            ZTest LEqual
            Cull [_Cull]
            Stencil
            {
                Ref [_StencilRefC]
                ReadMask 255
                WriteMask [_WriteMask]
                Comp [_StencilComp]
                Pass [_StencilOp]
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangVert
            #pragma fragment WuchangFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }

        Pass
        {
            // Renderer Feature schedules this private pass after the main opaque
            // surface. It is fixed-function multipass work, not a second surface graph.
            Name "Outline"
            Tags { "LightMode"="WuchangOutline" }
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Front
            ZWrite On
            ZTest Less
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangOutlineVert
            #pragma fragment WuchangOutlineFrag
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "CharHairShadow"
            Tags { "LightMode"="WuchangHairShadow" }
            ColorMask 0
            ZWrite Off
            ZTest LEqual
            Cull [_Cull]
            Stencil
            {
                Ref [_StencilRefShadowCaster]
                ReadMask 255
                WriteMask 255
                Comp Equal
                Pass IncrSat
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangHairShadowVert
            #pragma fragment WuchangHairShadowFrag
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "CharFaceShadow"
            Tags { "LightMode"="WuchangFaceShadow" }
            Blend One Zero
            ZWrite Off
            ZTest LEqual
            Cull [_Cull]
            Stencil
            {
                Ref [_StencilRefShadowReceiver]
                ReadMask 255
                WriteMask 255
                Comp Equal
                Pass DecrWrap
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangVert
            #pragma fragment WuchangFaceShadowFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "CharHairTransE"
            Tags { "LightMode"="WuchangHairTransE" }
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite [_ZWrite]
            ZTest LEqual
            Cull [_Cull]
            Stencil
            {
                Ref [_StencilRefC]
                ReadMask 255
                WriteMask 255
                Comp Equal
                Pass Keep
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangVert
            #pragma fragment WuchangHairTransmissionFrag
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ColorMask 0
            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangVert
            #pragma fragment WuchangDepthOnlyFrag
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Reflection"
            Tags { "LightMode"="WuchangReflection" }
            Blend [_SrcBlend] [_DstBlend], [_BlendAlphaSrc] [_BlendAlphaDst]
            ZWrite On
            ZTest LEqual
            Cull Front
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangReflectionVert
            #pragma fragment WuchangReflectionFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "PreDepth"
            Tags { "LightMode"="WuchangPreDepth" }
            ColorMask 0
            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WuchangVert
            #pragma fragment WuchangDepthOnlyFrag
            #include "WuchangCharacterCommon.hlsl"
            ENDHLSL
        }
    }
    FallBack Off
}
