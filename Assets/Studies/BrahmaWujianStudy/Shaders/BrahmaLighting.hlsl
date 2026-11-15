#ifndef BRAHMA_WUJIAN_LIGHTING_INCLUDED
#define BRAHMA_WUJIAN_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

void BrahmaSurface_float(
    float4 UV,
    float3 PositionWS,
    float3 NormalWS,
    float3 TangentWS,
    UnityTexture2D BaseMap,
    UnityTexture2D BumpMap,
    UnityTexture2D RMOTex,
    UnityTexture2D RampMap,
    UnityTexture2D RampMask,
    UnityTexture2D BlendTex,
    UnityTexture2D HairMaskTex,
    UnityTexture2D StockingBumpMap,
    UnityTexture2D NoiseMap,
    UnityTexture2D SparkleMap,
    float4 BaseColor,
    float4 HairAnisotropyColor,
    float4 StockingCenterColor,
    float4 StockingFalloffColor,
    float4 EmissiveColor,
    float4 RimLightTintColor,
    float4 StudyShadowTint,
    float4 RampMaskChannel,
    float4 Tiling,
    float4 RoughnessRemap,
    float4 MetallicRemap,
    float4 OcclusionRemap,
    float4 HeadForward,
    float4 HeadRight,
    float FaceMode,
    float HairMode,
    float EyeMode,
    float FurMode,
    float EffectMode,
    float NormalScale,
    float UseAlphaTest,
    float Cutoff,
    float Roughness,
    float Metallic,
    float Occlusion,
    float UseRampMap,
    float RampCount,
    float Anisotropy,
    float AnisotropyPow,
    float AnisotropyShift,
    float UseStockingFalloff,
    float StockingInt,
    float StockingNormalIntensity,
    float EmissiveIntensity,
    float UseRimLight,
    float RimLightIntensity,
    float RimMidPoint,
    float RimWidth,
    float RimColorMixAlbedo,
    float StudyRampWeight,
    float StudySpecularWeight,
    float StudyRimWeight,
    float StudyLightFloor,
    float StudyShadowStrength,
    float StudySparkle,
    float StudyNormalWeight,
    float StudyOpacity,
    out float3 Color,
    out float Alpha)
{
    float2 uv = UV.xy;
    float4 baseSample = SAMPLE_TEXTURE2D(BaseMap.tex, BaseMap.samplerstate, uv) * BaseColor;
    Alpha = saturate(baseSample.a * StudyOpacity);
    if (UseAlphaTest > 0.5)
        clip(Alpha - Cutoff);

    float3 normalWS = SafeNormalize(NormalWS);
    float3 tangentWS = SafeNormalize(TangentWS);
    float3 bitangentWS = SafeNormalize(cross(normalWS, tangentWS));
    float3 normalTS = UnpackNormalScale(
        SAMPLE_TEXTURE2D(BumpMap.tex, BumpMap.samplerstate, uv), NormalScale);
    float3 mappedNormalWS = SafeNormalize(
        tangentWS * normalTS.x + bitangentWS * normalTS.y + normalWS * normalTS.z);
    normalWS = SafeNormalize(lerp(normalWS, mappedNormalWS, saturate(StudyNormalWeight)));

    float3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(PositionWS));
    float4 shadowCoord = TransformWorldToShadowCoord(PositionWS);
    Light light = GetMainLight(shadowCoord);
    float3 lightDirWS = SafeNormalize(light.direction);
    float halfLambert = dot(normalWS, lightDirWS) * 0.5 + 0.5;

    float rampCount = max(1.0, RampCount);
    float banded = floor(saturate(halfLambert) * rampCount) / rampCount;
    float rampRow = saturate(dot(
        SAMPLE_TEXTURE2D(RampMask.tex, RampMask.samplerstate, uv), RampMaskChannel));
    float3 ramp = SAMPLE_TEXTURE2D(
        RampMap.tex, RampMap.samplerstate, float2(saturate(halfLambert), rampRow)).rgb;
    float3 analyticRamp = lerp(StudyShadowTint.rgb, 1.0.xxx, banded);
    float3 diffuseRamp = lerp(analyticRamp, ramp, saturate(UseRampMap * StudyRampWeight));

    if (FaceMode > 0.5)
    {
        float3 forwardWS = SafeNormalize(HeadForward.xyz);
        float3 rightWS = SafeNormalize(HeadRight.xyz);
        float3 flatLight = SafeNormalize(lightDirWS - float3(0, 1, 0) * lightDirWS.y);
        float side = dot(flatLight, rightWS);
        float2 sdfUV = float2(side < 0.0 ? 1.0 - uv.x : uv.x, uv.y);
        float sdf = SAMPLE_TEXTURE2D(BlendTex.tex, BlendTex.samplerstate, sdfUV).r;
        float threshold = 1.0 - (dot(flatLight, forwardWS) * 0.5 + 0.5);
        float faceLit = smoothstep(threshold - 0.035, threshold + 0.035, sdf);
        diffuseRamp = lerp(StudyShadowTint.rgb, 1.0.xxx, faceLit);
    }

    float4 rmo = SAMPLE_TEXTURE2D(RMOTex.tex, RMOTex.samplerstate, uv);
    float ao = lerp(OcclusionRemap.x, OcclusionRemap.y, rmo.b) * Occlusion;
    float metallic = lerp(MetallicRemap.x, MetallicRemap.y, rmo.r) * Metallic;
    float roughness = saturate(lerp(RoughnessRemap.x, RoughnessRemap.y, rmo.a) * Roughness);
    float attenuation = lerp(1.0, light.shadowAttenuation * light.distanceAttenuation,
        saturate(StudyShadowStrength));
    float3 direct = max(StudyLightFloor.xxx, light.color * attenuation);
    float3 color = baseSample.rgb * diffuseRamp * direct * max(0.2, ao);

    float3 halfDirWS = SafeNormalize(viewDirWS + lightDirWS);
    float ndh = saturate(dot(normalWS, halfDirWS));
    float specPower = exp2(lerp(3.0, 10.0, 1.0 - roughness));
    float specular = pow(ndh, specPower);
    if (HairMode > 0.5)
    {
        float hairMask = SAMPLE_TEXTURE2D(HairMaskTex.tex, HairMaskTex.samplerstate, uv).r;
        float tangentHalf = dot(tangentWS, halfDirWS) + AnisotropyShift;
        float aniso = pow(saturate(sqrt(max(0.0, 1.0 - tangentHalf * tangentHalf))),
            max(1.0, AnisotropyPow / max(1.0, Anisotropy)));
        specular = aniso * hairMask;
        color += specular * HairAnisotropyColor.rgb * StudySpecularWeight;
    }
    else
    {
        color += specular * lerp(0.04.xxx, baseSample.rgb, metallic) * StudySpecularWeight;
    }

    if (UseStockingFalloff > 0.5)
    {
        float2 stockingUV = uv * Tiling.xy + Tiling.zw;
        float3 stockingNormalTS = UnpackNormalScale(
            SAMPLE_TEXTURE2D(StockingBumpMap.tex, StockingBumpMap.samplerstate, stockingUV),
            StockingNormalIntensity);
        float3 stockingNormalWS = SafeNormalize(
            tangentWS * stockingNormalTS.x + bitangentWS * stockingNormalTS.y + normalWS * stockingNormalTS.z);
        float ndv = saturate(dot(stockingNormalWS, viewDirWS));
        float center = pow(ndv, max(0.05, StockingInt));
        float3 stockingTint = lerp(StockingFalloffColor.rgb, StockingCenterColor.rgb, center);
        color *= stockingTint;
        color += pow(1.0 - ndv, 4.0) * 0.035;
    }

    float rim = smoothstep(RimMidPoint, min(1.0, RimMidPoint + max(0.001, RimWidth)),
        1.0 - saturate(dot(normalWS, viewDirWS)));
    float3 rimTint = lerp(RimLightTintColor.rgb, baseSample.rgb, saturate(RimColorMixAlbedo));
    color += rim * rimTint * RimLightIntensity * StudyRimWeight * saturate(UseRimLight);

    float emissiveMask = rmo.g;
    color += EmissiveColor.rgb * emissiveMask * EmissiveIntensity;
    float sparkle = SAMPLE_TEXTURE2D(SparkleMap.tex, SparkleMap.samplerstate, uv).r;
    color += sparkle * StudySparkle * (0.65 + 0.35 * sin(_Time.y * 3.0 + uv.y * 90.0));
    if (EffectMode > 0.5)
        color += SAMPLE_TEXTURE2D(NoiseMap.tex, NoiseMap.samplerstate, uv).rgb * EffectMode;
    if (FurMode > 0.5)
        color = lerp(color, color * 1.08, saturate(FurMode));
    if (EyeMode > 0.5)
        color += pow(saturate(dot(reflect(-lightDirWS, normalWS), viewDirWS)), 24.0) * 0.3;

    Color = color;
}

#endif
