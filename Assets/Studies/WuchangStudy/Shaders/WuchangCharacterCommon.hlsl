#ifndef WUCHANG_CHARACTER_COMMON_INCLUDED
#define WUCHANG_CHARACTER_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

TEXTURE2D(_BaseMap);              SAMPLER(sampler_BaseMap);
TEXTURE2D(_RampMap);              SAMPLER(sampler_RampMap);
TEXTURE2D(_BumpMap);              SAMPLER(sampler_BumpMap);
TEXTURE2D(_HairMaskMap);          SAMPLER(sampler_HairMaskMap);
TEXTURE2D(_StockingNormalMap);    SAMPLER(sampler_StockingNormalMap);
TEXTURE2D(_FaceSDFMap);           SAMPLER(sampler_FaceSDFMap);
TEXTURE2D(_RMKMap);               SAMPLER(sampler_RMKMap);

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseColor;
float4 _ShadowColor;
float4 _ShadowRange;
float4 _FaceShadowTint;
float4 _StockingCenterColor;
float4 _StockingFalloffColor;
float4 _StockingAbsorptionColor;
float4 _StockingTiling;
float4 _ReflectionTint;
float4 _OutlineColor;
float _RampStrength;
float _RampRow;
float _SpecStrength;
float _SpecPower;
float _RimStrength;
float _RimPower;
float _Opacity;
float _AlphaClip;
float _Cutoff;
float _HairMaskStrength;
float _StockingStrength;
float _StockingPatternStrength;
float _StockingInt;
float _StockingNormalIntensity;
float _StockingBaseLift;
float _FaceSDFStrength;
float _FaceSDFSoftness;
float _RMKOcclusionStrength;
float _ReflectionStrength;
float _UseFringeShadowCaster;
float _UseFringeShadowReceiver;
float _HairShadowOffsetX;
float _HairShadowOffsetY;
float _HairShadowDepthBias;
float _HairTransmissionStrength;
float _OutlineWidth;
float _OutlineIntensity;
float _OutlineZBias;
CBUFFER_END

float4 _WuchangHeadForwardWS;
float4 _WuchangHeadRightWS;
float4x4 _WuchangReflectionVP;

struct WuchangAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
};

struct WuchangVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 normalWS : TEXCOORD2;
    half3 tangentWS : TEXCOORD3;
    half3 bitangentWS : TEXCOORD4;
    half fogFactor : TEXCOORD5;
};

inline void WuchangAlphaClip(half alpha)
{
    if (_AlphaClip > 0.5)
        clip(alpha - _Cutoff);
}

WuchangVaryings WuchangVert(WuchangAttributes input)
{
    WuchangVaryings output;
    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.positionCS = positionInputs.positionCS;
    output.positionWS = positionInputs.positionWS;
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = normalInputs.tangentWS;
    output.bitangentWS = normalInputs.bitangentWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
    return output;
}

WuchangVaryings WuchangHairShadowVert(WuchangAttributes input)
{
    WuchangVaryings output = WuchangVert(input);
    // Original values are authored as clip-space fringe offsets.
    output.positionCS.xy += float2(_HairShadowOffsetX, _HairShadowOffsetY) * output.positionCS.w;
    output.positionCS.z += _HairShadowDepthBias * output.positionCS.w;
    return output;
}

WuchangVaryings WuchangOutlineVert(WuchangAttributes input)
{
    WuchangVaryings output = WuchangVert(input);
    float3 normalVS = TransformWorldToViewDir(output.normalWS, true);
    float2 projectedNormal = normalize(normalVS.xy + 1e-5);
    output.positionCS.xy += projectedNormal * (2.0 / _ScaledScreenParams.xy) *
        _OutlineWidth * _OutlineIntensity * output.positionCS.w;
    #if UNITY_REVERSED_Z
        output.positionCS.z -= _OutlineZBias * output.positionCS.w;
    #else
        output.positionCS.z += _OutlineZBias * output.positionCS.w;
    #endif
    return output;
}

WuchangVaryings WuchangReflectionVert(WuchangAttributes input)
{
    WuchangVaryings output = WuchangVert(input);
    output.positionCS = mul(_WuchangReflectionVP, float4(output.positionWS, 1.0));
    return output;
}

inline half WuchangFaceSDF(float2 uv, half3 lightDirWS)
{
    half3 forwardWS = SafeNormalize(_WuchangHeadForwardWS.xyz);
    half3 rightWS = SafeNormalize(_WuchangHeadRightWS.xyz);
    half3 planarLight = SafeNormalize(lightDirWS - dot(lightDirWS, half3(0, 1, 0)) * half3(0, 1, 0));
    half side = dot(planarLight, rightWS);
    float2 sdfUV = uv;
    if (side < 0)
        sdfUV.x = 1.0 - sdfUV.x;
    half sdf = SAMPLE_TEXTURE2D(_FaceSDFMap, sampler_FaceSDFMap, sdfUV).r;
    half front = dot(planarLight, forwardWS) * 0.5h + 0.5h;
    half threshold = 1.0h - front;
    half softness = max(_FaceSDFSoftness, 0.001h);
    return smoothstep(threshold - softness, threshold + softness, sdf);
}

inline half3 WuchangEvaluateColor(WuchangVaryings input, bool forceFaceShadow)
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    WuchangAlphaClip(baseSample.a);

    half3 normalWS = SafeNormalize(input.normalWS);
    half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord);
    half3 lightDirWS = SafeNormalize(mainLight.direction);
    half ndl = dot(normalWS, lightDirWS);
    half halfLambert = ndl * 0.5h + 0.5h;
    half toon = smoothstep(_ShadowRange.x, max(_ShadowRange.y, _ShadowRange.x + 0.001), halfLambert);

    half ramp = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(saturate(halfLambert), _RampRow)).r;
    half3 rampLighting = lerp(_ShadowColor.rgb, half3(1, 1, 1), toon);
    rampLighting = lerp(rampLighting, rampLighting * lerp(_ShadowColor.rgb, half3(1, 1, 1), ramp), saturate(_RampStrength));

    if (_FaceSDFStrength > 0.001)
    {
        half faceLit = WuchangFaceSDF(input.uv, lightDirWS);
        half3 faceLighting = lerp(_FaceShadowTint.rgb, half3(1, 1, 1), faceLit);
        rampLighting = lerp(rampLighting, faceLighting, saturate(_FaceSDFStrength));
    }
    if (forceFaceShadow)
        rampLighting = _FaceShadowTint.rgb;

    half4 rmk = SAMPLE_TEXTURE2D(_RMKMap, sampler_RMKMap, input.uv);
    half ao = lerp(1.0h, rmk.b, saturate(_RMKOcclusionStrength));
    half3 color = baseSample.rgb * rampLighting * ao;
    half3 directLight = mainLight.color * lerp(1.0h,
        mainLight.shadowAttenuation * mainLight.distanceAttenuation, 0.36h);
    half3 ambientLight = SampleSH(normalWS);
    color *= min(directLight + ambientLight * 0.28h, 1.20h);

    half3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
    half hairMask = SAMPLE_TEXTURE2D(_HairMaskMap, sampler_HairMaskMap, input.uv).r;
    half genericSpec = pow(saturate(dot(normalWS, halfDir)), max(_SpecPower, 1.0));
    half tangentHalf = dot(SafeNormalize(input.tangentWS), halfDir);
    half anisotropic = pow(saturate(sqrt(max(0.0h, 1.0h - tangentHalf * tangentHalf))), max(_SpecPower * 0.5h, 1.0h));
    half specular = lerp(genericSpec, anisotropic * hairMask, saturate(_HairMaskStrength));
    color += specular * _SpecStrength * mainLight.color * mainLight.shadowAttenuation;

    half rim = pow(saturate(1.0h - dot(normalWS, viewDirWS)), max(_RimPower, 1.0));
    color += rim * _RimStrength * lerp(baseSample.rgb, half3(1, 1, 1), 0.5h);

    if (_StockingStrength > 0.001)
    {
        float2 stockingUV = input.uv * _StockingTiling.xy;
        half3 stockingNormalTS = SAMPLE_TEXTURE2D(
            _StockingNormalMap, sampler_StockingNormalMap, stockingUV).xyz * 2.0h - 1.0h;
        stockingNormalTS.xy *= _StockingNormalIntensity;
        stockingNormalTS.z = sqrt(saturate(1.0h - dot(stockingNormalTS.xy, stockingNormalTS.xy)));
        half3x3 tangentToWorld = half3x3(
            SafeNormalize(input.tangentWS), SafeNormalize(input.bitangentWS), normalWS);
        half3 stockingNormalWS = SafeNormalize(mul(stockingNormalTS, tangentToWorld));

        // Reconstructed from the original material contract: the base texture remains
        // visible while NdotV moves between the authored falloff and center colours.
        half stockingNdotV = saturate(dot(stockingNormalWS, viewDirWS));
        half centerWeight = pow(stockingNdotV, 1.65h);
        half3 stockingTint = lerp(
            _StockingFalloffColor.rgb, _StockingCenterColor.rgb, centerWeight);
        // _StockingInt is also the source material's optical intensity: 0.49 for
        // the dark pair and 2.89 for the white pair. Clamp only the high end so
        // white fabric remains high-key while the dark fabric retains density.
        half opticalIntensity = saturate(_StockingInt);
        half3 stockingColor = color * stockingTint * opticalIntensity *
            _StockingAbsorptionColor.rgb;
        half3 liftedFabricTint = lerp(stockingTint, half3(1, 1, 1),
            saturate(_StockingBaseLift * 0.65h));
        half3 fabricLitColor = liftedFabricTint *
            min(directLight + ambientLight * 0.20h, 1.08h);
        stockingColor = lerp(stockingColor, fabricLitColor,
            saturate(_StockingBaseLift));

        half3 stockingHalf = SafeNormalize(lightDirWS + viewDirWS);
        half broadSheen = pow(saturate(dot(stockingNormalWS, stockingHalf)), 46.0h);
        half grazingSheen = pow(saturate(1.0h - stockingNdotV), 4.0h);
        half weave = SAMPLE_TEXTURE2D(
            _StockingNormalMap, sampler_StockingNormalMap, stockingUV).r;
        half microVariation = lerp(1.0h, lerp(0.96h, 1.04h, weave),
            saturate(_StockingPatternStrength));
        stockingColor *= microVariation;
        stockingColor += (broadSheen * 0.13h + grazingSheen * 0.018h) *
            mainLight.color * mainLight.shadowAttenuation;
        color = lerp(color, stockingColor, saturate(_StockingStrength));
    }

    return color;
}

half4 WuchangFrag(WuchangVaryings input) : SV_Target
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    WuchangAlphaClip(baseSample.a);
    half3 color = WuchangEvaluateColor(input, false);
    color = MixFog(color, input.fogFactor);
    return half4(color, baseSample.a * _Opacity);
}

half4 WuchangFaceShadowFrag(WuchangVaryings input) : SV_Target
{
    clip(_UseFringeShadowReceiver - 0.5);
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    WuchangAlphaClip(baseSample.a);
    return half4(WuchangEvaluateColor(input, true), baseSample.a * _Opacity);
}

half4 WuchangDepthOnlyFrag(WuchangVaryings input) : SV_Target
{
    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
    WuchangAlphaClip(alpha);
    return 0;
}

half4 WuchangHairShadowFrag(WuchangVaryings input) : SV_Target
{
    clip(_UseFringeShadowCaster - 0.5);
    return WuchangDepthOnlyFrag(input);
}

half4 WuchangHairTransmissionFrag(WuchangVaryings input) : SV_Target
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    WuchangAlphaClip(baseSample.a);
    half mask = SAMPLE_TEXTURE2D(_HairMaskMap, sampler_HairMaskMap, input.uv).g;
    half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
    half fresnel = pow(saturate(1.0h - dot(SafeNormalize(input.normalWS), viewDirWS)), 3.0h);
    return half4(baseSample.rgb, mask * fresnel * _HairTransmissionStrength);
}

half4 WuchangOutlineFrag(WuchangVaryings input) : SV_Target
{
    clip(_OutlineIntensity - 0.01);
    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
    WuchangAlphaClip(alpha);
    return half4(_OutlineColor.rgb, _OutlineColor.a * alpha);
}

half4 WuchangReflectionFrag(WuchangVaryings input) : SV_Target
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    WuchangAlphaClip(baseSample.a);
    half3 color = WuchangEvaluateColor(input, false) * _ReflectionTint.rgb;
    return half4(color, baseSample.a * _Opacity * _ReflectionStrength);
}

#endif
