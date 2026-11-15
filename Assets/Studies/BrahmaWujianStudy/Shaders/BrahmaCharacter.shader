Shader "AetherGazer/Brahma Wujian/Reconstructed Multipass"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _BumpMap("Normal Map", 2D) = "bump" {}
        _RMOTex("RMO", 2D) = "white" {}
        _RampMap("Ramp", 2D) = "white" {}
        _RampMask("Ramp Mask", 2D) = "white" {}
        _BlendTex("Face SDF / Blend", 2D) = "white" {}
        _HairMaskTex("Hair Mask", 2D) = "white" {}
        _StockingBumpMap("Stocking Normal", 2D) = "bump" {}
        _NoiseMap("Noise", 2D) = "black" {}
        _SparkleMap("Sparkle", 2D) = "black" {}
        [HideInInspector] _MainTex("Legacy Effect Main", 2D) = "white" {}
        [HideInInspector] _MainPlusTex("Legacy Effect Plus", 2D) = "black" {}
        [HideInInspector] _Tex("Legacy Effect Texture", 2D) = "white" {}
        [HideInInspector] _Tex_Mask("Legacy Effect Mask", 2D) = "white" {}
        [HideInInspector] _MaskTex("Legacy Effect Mask 2", 2D) = "white" {}
        [HideInInspector] _Color("Legacy Effect Color", Color) = (1,1,1,1)
        [HideInInspector] _ColorPlus("Legacy Effect Plus Color", Color) = (1,1,1,1)
        _HairAnisotropyColor("Hair Anisotropy", Color) = (1,1,1,1)
        _StockingCenterColor("Stocking Center", Color) = (1,1,1,1)
        _StockingFalloffColor("Stocking Falloff", Color) = (.2,.2,.2,1)
        _EmissiveColor("Emission", Color) = (1,1,1,1)
        _RimLightTintColor("Rim", Color) = (1,1,1,1)
        _StudyShadowTint("Study Shadow", Color) = (.69,.59,.64,1)
        _StudyHairTint("Hair Tint", Color) = (1,1,1,1)
        _StudyEdgeTint("Edge Tint", Color) = (.18,.25,.45,1)
        _ReflectionTint("Reflection Tint", Color) = (.72,.78,.9,1)
        _ReflectionStrength("Reflection Strength", Range(0,1)) = .08
        [HideInInspector] _BrahmaHairShadowOffsetOS("Hair Shadow Graph Offset", Vector) = (0,0,0,0)
        _RampMaskChannel("Ramp Channel", Vector) = (0,0,0,1)
        _Tiling("Stocking Tiling", Vector) = (1,1,0,0)
        _RoughnessRemap("Roughness Remap", Vector) = (0,1,1,0)
        _MetallicRemap("Metallic Remap", Vector) = (0,1,1,0)
        _OcclusionRemap("Occlusion Remap", Vector) = (0,1,1,0)
        _FaceMode("Face", Float) = 0
        _HairMode("Hair", Float) = 0
        _EyeMode("Eye", Float) = 0
        _FurMode("Fur", Float) = 0
        _EffectMode("Effect", Float) = 0
        _NormalScale("Normal Scale", Float) = 1
        _UseAlphaTest("Alpha Test", Float) = 0
        _Cutoff("Cutoff", Range(0,1)) = .5
        _Roughness("Roughness", Float) = 1
        _Metallic("Metallic", Float) = 1
        _Occlusion("Occlusion", Float) = 1
        _UseRampMap("Use Ramp", Float) = 1
        _RampCount("Ramp Count", Float) = 10
        _Anisotropy("Anisotropy", Float) = 1
        _AnisotropyPow("Anisotropy Pow", Float) = 72
        _AnisotropyShift("Anisotropy Shift", Float) = .05
        _UseStockingFalloff("Stocking", Float) = 0
        _StockingInt("Stocking Intensity", Float) = .55
        _StockingNormalIntensity("Stocking Normal", Float) = .2
        _EmissiveIntensity("Emission Intensity", Float) = 0
        _UseRimLight("Use Rim", Float) = 1
        _RimLightIntensity("Rim Intensity", Float) = 1
        _RimMidPoint("Rim Mid", Float) = .65
        _RimWidth("Rim Width", Float) = .18
        _RimColorMixAlbedo("Rim Albedo Mix", Float) = .5
        _StudyRampWeight("Ramp Calibration", Range(0,1)) = .22
        _StudySpecularWeight("Spec Calibration", Range(0,1)) = .12
        _StudyRimWeight("Rim Calibration", Range(0,1)) = .045
        _StudyLightFloor("Light Floor", Range(0,1)) = .85
        _StudyShadowStrength("Shadow Strength", Range(0,1)) = .65
        _StudySparkle("Sparkle", Range(0,2)) = 0
        _StudyProceduralSparkle("Procedural Sparkle", Range(0,2)) = 0
        _StudyHairSaturation("Hair Saturation", Range(.5,2)) = 1
        _StudyHairTipBoost("Hair Tip Boost", Range(0,2)) = 0
        _StudyEdgeStrength("Edge Strength", Range(0,1)) = 0
        _StudySkinLift("Skin Lift", Range(0,1)) = 0
        _StudyEnvironmentWeight("Environment Reflection", Range(0,1)) = .15
        _LensMode("Transparent Lens", Float) = 0
        _EyeHighlightMode("Eye Highlight Mask", Float) = 0
        _FurLength("Fur Length (World Metres)", Range(0,.02)) = .006
        _FurDensity("Fur Strands Per UV", Float) = 1600
        _FurBend("Fur Gravity Bend", Range(0,1)) = .3
        _FabricMode("Knit Fabric", Float) = 0
        _BodyAtlasMode("Sweater Atlas Regions", Float) = 0
        _EffectMask("Effect Mask", 2D) = "white" {}
        _EffectMask_ST("Effect Mask Tiling", Vector) = (1,1,0,0)
        _StudyNormalWeight("Normal Weight", Range(0,1)) = 1
        _StudyOpacity("Opacity", Range(0,1)) = 1
        _OutlineWidth("Outline Width", Float) = 2
        _OutlineIntensity("Outline Intensity", Float) = 1
        _OutlineZBias("Outline Z Bias", Float) = .001
        [HideInInspector] _UseFringeShadowCaster("Fringe Caster", Float) = 0
        [HideInInspector] _UseFringeShadowReceiver("Fringe Receiver", Float) = 0
        [HideInInspector] _UseHairTranE("Hair Transmission", Float) = 0
        [HideInInspector] _HairShadowX("Hair Shadow X", Float) = .0037
        [HideInInspector] _HairShadowY("Hair Shadow Y", Float) = .00778
        [HideInInspector] _HairTranEAlpha("Hair Transmission Alpha", Float) = .35
        [HideInInspector] _StencilComp("Stencil Comp", Float) = 8
        [HideInInspector] _StencilOp("Stencil Op", Float) = 0
        [HideInInspector] _StencilRefC("Stencil Ref", Float) = 206
        [HideInInspector] _WriteMask("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilRefShadowCaster("Caster Ref", Float) = 200
        [HideInInspector] _StencilRefShadowReceiver("Receiver Ref", Float) = 201
        [HideInInspector] _Cull("Cull", Float) = 2
        [HideInInspector] _ZWrite("ZWrite", Float) = 1
        [HideInInspector] _SrcBlend("Src Blend", Float) = 1
        [HideInInspector] _DstBlend("Dst Blend", Float) = 0
        [HideInInspector] _BlendAlphaSrc("Alpha Src", Float) = 1
        [HideInInspector] _BlendAlphaDst("Alpha Dst", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry+10" "RenderType"="Opaque" "IgnoreProjector"="True" }
        Pass
        {
            Name "ForwardBase" Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend], [_BlendAlphaSrc] [_BlendAlphaDst]
            ZWrite [_ZWrite] ZTest LEqual Cull [_Cull]
            Stencil { Ref [_StencilRefC] ReadMask 255 WriteMask [_WriteMask] Comp [_StencilComp] Pass [_StencilOp] }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaVert
            #pragma fragment BrahmaFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            // The original custom SRP labels this pass "Always".  URP treats
            // LightMode as a scheduling contract, so keep the original state
            // but give manually scheduled auxiliary passes private tags.
            Name "Outline" Tags { "LightMode"="BrahmaOutline" }
            Blend SrcAlpha OneMinusSrcAlpha, [_BlendAlphaSrc] [_BlendAlphaDst]
            Cull Front ZWrite On ZTest Less
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaOutlineVert
            #pragma fragment BrahmaOutlineFrag
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "CharHairShadow" Tags { "LightMode"="BrahmaHairShadow" }
            ColorMask 0 ZWrite Off ZTest LEqual Cull [_Cull]
            Stencil { Ref [_StencilRefShadowCaster] ReadMask 255 WriteMask 255 Comp Equal Pass IncrSat }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaHairShadowVert
            #pragma fragment BrahmaHairShadowFrag
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "CharFaceShadow" Tags { "LightMode"="BrahmaFaceShadow" }
            Blend One Zero ZWrite Off ZTest LEqual Cull [_Cull]
            Stencil { Ref [_StencilRefShadowReceiver] ReadMask 255 WriteMask 255 Comp Equal Pass DecrWrap }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaVert
            #pragma fragment BrahmaFaceShadowFrag
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "CharHairTransE" Tags { "LightMode"="BrahmaHairTransE" }
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite [_ZWrite] ZTest LEqual Cull [_Cull]
            Stencil { Ref [_StencilRefC] ReadMask 255 WriteMask 255 Comp Equal Pass Keep }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaVert
            #pragma fragment BrahmaHairTransmissionFrag
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster" Tags { "LightMode"="ShadowCaster" }
            ColorMask 0 ZWrite On ZTest LEqual Cull [_Cull]
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaShadowVert
            #pragma fragment BrahmaDepthFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "Reflection" Tags { "LightMode"="BrahmaReflection" }
            Blend [_SrcBlend] [_DstBlend], [_BlendAlphaSrc] [_BlendAlphaDst]
            ZWrite On ZTest LEqual Cull Front
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaReflectionVert
            #pragma fragment BrahmaReflectionFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "PreDepth" Tags { "LightMode"="BrahmaPreDepth" }
            ColorMask 0 ZWrite On ZTest LEqual Cull [_Cull]
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaVert
            #pragma fragment BrahmaDepthFrag
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "FurShell" Tags { "LightMode"="BrahmaFurShell" }
            Cull Back ZWrite On ZTest LEqual
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex BrahmaFurVert
            #pragma fragment BrahmaFurFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #include "BrahmaCharacterCommon.hlsl"
            ENDHLSL
        }
    }
    FallBack Off
}
