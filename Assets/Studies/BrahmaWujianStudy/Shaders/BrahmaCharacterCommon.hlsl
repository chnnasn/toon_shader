#ifndef BRAHMA_WUJIAN_CHARACTER_COMMON_INCLUDED
#define BRAHMA_WUJIAN_CHARACTER_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
TEXTURE2D(_RMOTex); SAMPLER(sampler_RMOTex);
TEXTURE2D(_RampMap); SAMPLER(sampler_RampMap);
TEXTURE2D(_RampMask); SAMPLER(sampler_RampMask);
TEXTURE2D(_BlendTex); SAMPLER(sampler_BlendTex);
TEXTURE2D(_HairMaskTex); SAMPLER(sampler_HairMaskTex);
TEXTURE2D(_StockingBumpMap); SAMPLER(sampler_StockingBumpMap);
TEXTURE2D(_NoiseMap); SAMPLER(sampler_NoiseMap);
TEXTURE2D(_SparkleMap); SAMPLER(sampler_SparkleMap);
TEXTURE2D(_EffectMask); SAMPLER(sampler_EffectMask);

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseColor;
float4 _HairAnisotropyColor;
float4 _StockingCenterColor;
float4 _StockingFalloffColor;
float4 _EmissiveColor;
float4 _RimLightTintColor;
float4 _StudyShadowTint;
float4 _StudyHairTint;
float4 _StudyEdgeTint;
float4 _RampMaskChannel;
float4 _Tiling;
float4 _RoughnessRemap;
float4 _MetallicRemap;
float4 _OcclusionRemap;
float4 _EffectMask_ST;
float _FaceMode, _HairMode, _EyeMode, _FurMode, _EffectMode;
float _NormalScale, _UseAlphaTest, _Cutoff, _Roughness, _Metallic, _Occlusion;
float _UseRampMap, _RampCount, _Anisotropy, _AnisotropyPow, _AnisotropyShift;
float _UseStockingFalloff, _StockingInt, _StockingNormalIntensity;
float _EmissiveIntensity, _UseRimLight, _RimLightIntensity, _RimMidPoint, _RimWidth;
float _RimColorMixAlbedo, _StudyRampWeight, _StudySpecularWeight, _StudyRimWeight;
float _StudyLightFloor, _StudyShadowStrength, _StudySparkle, _StudyNormalWeight, _StudyOpacity;
float _StudyProceduralSparkle, _StudyHairSaturation, _StudyHairTipBoost, _StudyEdgeStrength, _StudySkinLift;
float _UseFringeShadowCaster, _UseFringeShadowReceiver, _UseHairTranE;
float _HairShadowX, _HairShadowY, _HairTranEAlpha;
float _OutlineWidth, _OutlineIntensity, _OutlineZBias;
float _StudyEnvironmentWeight, _LensMode, _FurLength, _EyeHighlightMode;
float _FabricMode, _FurDensity, _FurBend, _BodyAtlasMode;
CBUFFER_END

float4 _BrahmaHeadForwardWS;
float4 _BrahmaHeadRightWS;
float4x4 _BrahmaReflectionVP;
float _BrahmaFurLayer;
float3 _LightDirection;
float3 _LightPosition;

struct BrahmaAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

struct BrahmaVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 normalWS : TEXCOORD2;
    half3 tangentWS : TEXCOORD3;
    half3 bitangentWS : TEXCOORD4;
    half fogFactor : TEXCOORD5;
    half4 color : COLOR;
};

inline void BrahmaAlphaClip(half alpha)
{
    if (_UseAlphaTest > 0.5) clip(alpha - _Cutoff);
}

BrahmaVaryings BrahmaVert(BrahmaAttributes input)
{
    BrahmaVaryings output;
    VertexPositionInputs p = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs n = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.positionCS = p.positionCS;
    output.positionWS = p.positionWS;
    output.normalWS = n.normalWS;
    output.tangentWS = n.tangentWS;
    output.bitangentWS = n.bitangentWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.color = input.color;
    output.fogFactor = ComputeFogFactor(p.positionCS.z);
    return output;
}

BrahmaVaryings BrahmaHairShadowVert(BrahmaAttributes input)
{
    BrahmaVaryings output = BrahmaVert(input);
    output.positionCS.xy += float2(_HairShadowX, _HairShadowY) * output.positionCS.w;
    return output;
}

BrahmaVaryings BrahmaOutlineVert(BrahmaAttributes input)
{
    BrahmaVaryings output = BrahmaVert(input);
    float3 normalVS = TransformWorldToViewDir(output.normalWS, true);
    float2 projected = normalize(normalVS.xy + 1e-5);
    output.positionCS.xy += projected * (2.0 / _ScaledScreenParams.xy) *
        _OutlineWidth * _OutlineIntensity * output.positionCS.w;
    // Push the hull away from the camera under either depth convention.
    #if UNITY_REVERSED_Z
        output.positionCS.z -= _OutlineZBias * output.positionCS.w;
    #else
        output.positionCS.z += _OutlineZBias * output.positionCS.w;
    #endif
    return output;
}

BrahmaVaryings BrahmaShadowVert(BrahmaAttributes input)
{
    BrahmaVaryings output = BrahmaVert(input);
    float3 direction = _LightDirection;
    #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
        direction = normalize(_LightPosition - output.positionWS);
    #endif
    output.positionCS = TransformWorldToHClip(ApplyShadowBias(output.positionWS, output.normalWS, direction));
    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE * output.positionCS.w);
    #else
        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE * output.positionCS.w);
    #endif
    return output;
}

BrahmaVaryings BrahmaFurVert(BrahmaAttributes input)
{
    BrahmaVaryings output = BrahmaVert(input);
    float layer = _BrahmaFurLayer;
    float3 normal = normalize(output.normalWS);
    float3 gravity = float3(0, -1, 0);
    float3 bend = gravity - normal * dot(gravity, normal);
    output.positionWS += _FurLength * (normal * layer + bend * layer * layer * _FurBend);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    return output;
}

BrahmaVaryings BrahmaReflectionVert(BrahmaAttributes input)
{
    BrahmaVaryings output = BrahmaVert(input);
    output.positionCS = mul(_BrahmaReflectionVP, float4(output.positionWS, 1));
    return output;
}

inline half3 BrahmaNormalWS(BrahmaVaryings input)
{
    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv), _NormalScale);
    half3 mapped = normalize(input.tangentWS * normalTS.x + input.bitangentWS * normalTS.y + input.normalWS * normalTS.z);
    return normalize(lerp(input.normalWS, mapped, saturate(_StudyNormalWeight)));
}

inline half BrahmaFaceSDF(float2 uv, half3 lightDirWS)
{
    half3 forwardWS = SafeNormalize(_BrahmaHeadForwardWS.xyz);
    half3 rightWS = SafeNormalize(_BrahmaHeadRightWS.xyz);
    half3 flatLight = SafeNormalize(lightDirWS - half3(0, 1, 0) * lightDirWS.y);
    half side = dot(flatLight, rightWS);
    float2 sdfUV = float2(side < 0 ? 1 - uv.x : uv.x, uv.y);
    half sdf = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, sdfUV).r;
    half threshold = 1 - (dot(flatLight, forwardWS) * 0.5h + 0.5h);
    return smoothstep(threshold - 0.035h, threshold + 0.035h, sdf);
}

inline half3 BrahmaEvaluate(BrahmaVaryings input, bool forceFaceShadow)
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    BrahmaAlphaClip(baseSample.a);
    half4 propertyMask = SAMPLE_TEXTURE2D(_RampMask, sampler_RampMask, input.uv);
    // The sweater atlas stores region IDs in alpha. Its white net and knit share
    // one material, but need different normal and sheen responses.
    half whiteNet = _BodyAtlasMode * smoothstep(.38h, .42h, propertyMask.a) *
        (1 - smoothstep(.49h, .52h, propertyMask.a));
    if (_HairMode > 0.5)
    {
        half luminance = dot(baseSample.rgb, half3(.299h, .587h, .114h));
        baseSample.rgb = lerp(luminance.xxx, baseSample.rgb, _StudyHairSaturation) * _StudyHairTint.rgb;
        half blueChroma = smoothstep(.35h, .65h, (baseSample.b - baseSample.r) / max(.001h, baseSample.b));
        baseSample.rgb *= lerp(1.0h.xxx, half3(.90h, 1.04h, 1.15h), blueChroma * _StudyHairTipBoost);
    }
    half skinHue = smoothstep(.018h, .10h, baseSample.r - baseSample.b) *
                   smoothstep(-.015h, .065h, baseSample.r - baseSample.g);
    half skin = skinHue * step(.001h, _StudySkinLift);
    if (_StudySkinLift > .001)
    {
        half3 porcelain = baseSample.rgb * half3(1.10h, 1.22h, 1.20h) + half3(.028h, .060h, .040h);
        baseSample.rgb = lerp(baseSample.rgb, porcelain, skinHue * _StudySkinLift);
    }
    half3 normalWS = BrahmaNormalWS(input);
    half3 geometricNormal = normalize(input.normalWS);
    normalWS = normalize(lerp(normalWS, geometricNormal, max(skin * .75h, whiteNet * .94h)));
    half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
    Light light = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
    half3 lightDirWS = SafeNormalize(light.direction);
    half halfLambert = dot(normalWS, lightDirWS) * 0.5h + 0.5h;
    half band = smoothstep(.42h, .56h, halfLambert);
    half rampRow = saturate(dot(propertyMask, _RampMaskChannel));
    half3 authoredRamp = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(saturate(halfLambert), rampRow)).rgb;
    half3 shadowTint = lerp(_StudyShadowTint.rgb, half3(.78h, .56h, .58h), skin);
    half3 ramp = lerp(shadowTint, 1.0h.xxx, band);
    half wrappedLight = saturate((dot(normalWS, lightDirWS) + .35h) / 1.35h);
    half3 skinDiffuse = lerp(shadowTint, 1.0h.xxx, smoothstep(.10h, .55h, wrappedLight));
    skinDiffuse *= lerp(.94h, 1.035h, wrappedLight);
    ramp = lerp(ramp, skinDiffuse, skin * (1 - _FaceMode));
    ramp = lerp(ramp, authoredRamp, saturate(_UseRampMap * _StudyRampWeight));
    if (_FaceMode > 0.5)
        ramp = lerp(shadowTint, 1.0h.xxx, BrahmaFaceSDF(input.uv, lightDirWS));
    if (forceFaceShadow) ramp = shadowTint;

    half4 rmo = SAMPLE_TEXTURE2D(_RMOTex, sampler_RMOTex, input.uv);
    half ao = lerp(_OcclusionRemap.x, _OcclusionRemap.y, rmo.b) * _Occlusion;
    half roughness = saturate(lerp(_RoughnessRemap.x, _RoughnessRemap.y, rmo.a) * _Roughness);
    half metallic = saturate(lerp(_MetallicRemap.x, _MetallicRemap.y, rmo.r) * _Metallic);
    half castShadow = (1 - light.shadowAttenuation) * saturate(_StudyShadowStrength);
    ramp *= lerp(1.0h.xxx, shadowTint, castShadow);
    half3 ambient = max(_StudyLightFloor.xxx * .25h, SampleSH(normalWS));
    half3 direct = light.color * light.distanceAttenuation;
    half fabric = _FabricMode * (1 - skinHue) * smoothstep(.22h, .6h, min(baseSample.r, min(baseSample.g, baseSample.b)));
    fabric *= smoothstep(.12h, .20h, propertyMask.a) * (1 - smoothstep(.34h, .40h, propertyMask.a));
    half normalRelief = dot(normalWS - geometricNormal, lightDirWS);
    half cavity = lerp(lerp(.75h, 1, saturate(ao)), lerp(.62h, 1, saturate(ao)), fabric);
    half3 color = baseSample.rgb * (ramp * direct * .81h + ambient * .26h) * cavity;
    color *= 1 + normalRelief * fabric * .24h;
    // Both Forward and Forward+ directional/cluster lights contribute to the material.
    #if defined(_ADDITIONAL_LIGHTS)
        InputData inputData = (InputData)0;
        inputData.positionWS = input.positionWS;
        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
        #if USE_CLUSTER_LIGHT_LOOP
            UNITY_LOOP for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
            {
                Light fill = GetAdditionalLight(lightIndex, input.positionWS, half4(1,1,1,1));
                color += baseSample.rgb * fill.color * saturate(dot(normalWS, fill.direction)) *
                    fill.distanceAttenuation * fill.shadowAttenuation * .38h;
            }
        #endif
        uint lightCount = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(lightCount)
            Light fill = GetAdditionalLight(lightIndex, input.positionWS, half4(1,1,1,1));
            color += baseSample.rgb * fill.color * saturate(dot(normalWS, fill.direction)) *
                fill.distanceAttenuation * fill.shadowAttenuation * .38h;
        LIGHT_LOOP_END
    #endif

    half3 halfDir = SafeNormalize(viewDirWS + lightDirWS);
    half specular;
    if (_HairMode > 0.5)
    {
        half3 strand = SafeNormalize(input.bitangentWS + normalWS * _AnisotropyShift);
        half tangentHalf = dot(strand, halfDir);
        half broadLobe = pow(saturate(1 - tangentHalf * tangentHalf), 10);
        half fineLobe = pow(saturate(1 - tangentHalf * tangentHalf), max(1, _AnisotropyPow));
        half facing = smoothstep(-.1h, .5h, dot(normalWS, lightDirWS));
        half paintedGlint = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, input.uv).r;
        half strandVariation = saturate(dot(normalWS, geometricNormal));
        specular = (broadLobe * .24h + fineLobe * .76h) * facing * strandVariation;
        color += (specular + paintedGlint * .8h) * _HairAnisotropyColor.rgb * _StudySpecularWeight * direct;
    }
    else
    {
        specular = pow(saturate(dot(normalWS, halfDir)), exp2(lerp(3, 10, 1 - roughness)));
        color += specular * lerp(0.16h.xxx, baseSample.rgb, metallic) * _StudySpecularWeight * direct * (1 - fabric * .7h) * (1 - skin);
        half skinHighlight = pow(saturate(dot(normalWS, halfDir)), 18);
        color += skinHighlight * skin * direct * half3(.022h, .020h, .018h);
        half velvet = pow(1 - saturate(dot(normalWS, viewDirWS)), 3) * saturate(dot(normalWS, lightDirWS) * .5h + .5h);
        color += velvet * fabric * half3(.035h, .042h, .055h);
    }

    if (_UseStockingFalloff > 0.5)
    {
        float2 suv = input.uv * _Tiling.xy + _Tiling.zw;
        half3 sn = UnpackNormalScale(SAMPLE_TEXTURE2D(_StockingBumpMap, sampler_StockingBumpMap, suv), _StockingNormalIntensity);
        half3 swn = normalize(input.tangentWS * sn.x + input.bitangentWS * sn.y + normalWS * sn.z);
        half ndv = saturate(dot(swn, viewDirWS));
        half3 tint = lerp(_StockingFalloffColor.rgb, _StockingCenterColor.rgb, pow(ndv, max(0.05, _StockingInt)));
        color *= tint;
        // A broad yarn highlight follows the leg's curved surface. The high-frequency
        // weave fades with derivatives before it can alias at a distance.
        float weavePhase = input.uv.y * 5200;
        half weave = sin(weavePhase) * saturate(1 - fwidth(weavePhase) * .3);
        half silk = pow(saturate(dot(swn, halfDir)), 12) * smoothstep(.0h, .7h, ndv);
        color += silk * half3(.16h, .135h, .13h) * _StudySpecularWeight * (1 + weave * .12h);
    }

    half fresnel = pow(1 - saturate(dot(normalWS, viewDirWS)), 5);
    half3 environment = GlossyEnvironmentReflection(reflect(-viewDirWS, normalWS), roughness, 1);
    color += environment * lerp(.04h.xxx, baseSample.rgb, metallic) *
        (1 + fresnel * 3) * _StudyEnvironmentWeight;

    half rim = smoothstep(_RimMidPoint, min(1, _RimMidPoint + max(0.001, _RimWidth)), 1 - saturate(dot(normalWS, viewDirWS)));
    color += rim * lerp(_RimLightTintColor.rgb, baseSample.rgb, saturate(_RimColorMixAlbedo)) * _RimLightIntensity * _StudyRimWeight * saturate(_UseRimLight);
    color += _EmissiveColor.rgb * rmo.g * _EmissiveIntensity;
    half sparkle = SAMPLE_TEXTURE2D(_SparkleMap, sampler_SparkleMap, input.uv).r;
    if (_HairMode > .5 && _StudyProceduralSparkle > .001)
    {
        float2 grid = input.uv * float2(190, 150);
        float2 cell = floor(grid);
        float random = frac(sin(dot(cell, float2(12.9898, 78.233))) * 43758.5453);
        float2 offset = frac(float2(random * 17.13, random * 41.7)) * .64 + .18;
        float2 local = frac(grid) - offset;
        float radius = lerp(.055, .18, step(.985, random));
        float footprint = max(.012, length(fwidth(grid)) * .5);
        float starPoint = 1 - smoothstep(radius - footprint, radius + footprint, length(local * float2(.75, 1.5)));
        half tip = smoothstep(.10h, .22h, baseSample.b - baseSample.r);
        sparkle += step(.87, random) * starPoint * _StudyProceduralSparkle * tip;
    }
    color += sparkle * _StudySparkle * (0.72h + 0.28h * sin(_Time.y * 3 + input.uv.y * 90));
    if (_EffectMode > 0.5) color = baseSample.rgb;
    if (_FurMode > 0.5) color = baseSample.rgb * (.75h + .30h * halfLambert);
    color *= 1 - whiteNet * .08h;
    if (_EyeMode > 0.5) color += pow(saturate(dot(reflect(-lightDirWS, normalWS), viewDirWS)), 24) * 0.3h;
    if (_StudyEdgeStrength > .001)
    {
        half silhouette = pow(1 - saturate(dot(normalWS, viewDirWS)), 5);
        color = lerp(color, _StudyEdgeTint.rgb, silhouette * _StudyEdgeStrength);
    }
    return color;
}

half4 BrahmaFrag(BrahmaVaryings input) : SV_Target
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    BrahmaAlphaClip(baseSample.a);
    half alpha = baseSample.a * _StudyOpacity;
    if (_EyeHighlightMode > .5)
        alpha *= SAMPLE_TEXTURE2D(_EffectMask, sampler_EffectMask, input.uv).r;
    if (_EffectMode > .5)
    {
        half mask = SAMPLE_TEXTURE2D(_EffectMask, sampler_EffectMask, input.uv * _EffectMask_ST.xy + _EffectMask_ST.zw).r;
        alpha *= mask * input.color.a;
        if (_EffectMode > 1.5)
            alpha *= max(baseSample.r, max(baseSample.g, baseSample.b));
    }
    half3 color = BrahmaEvaluate(input, false);
    if (_LensMode > .5)
    {
        half3 normal = normalize(input.normalWS);
        half3 view = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
        half fresnel = pow(1 - saturate(dot(normal, view)), 4);
        color = _BaseColor.rgb * .75h + GlossyEnvironmentReflection(reflect(-view, normal), .12h, 1) * (.16h + fresnel * .45h);
    }
    return half4(MixFog(color, input.fogFactor), alpha);
}

half4 BrahmaOutlineFrag(BrahmaVaryings input) : SV_Target
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    BrahmaAlphaClip(baseSample.a);
    clip(_OutlineIntensity - .01);
    return half4(lerp(_StudyEdgeTint.rgb, baseSample.rgb * .25h, .5h), 1);
}

half4 BrahmaFurFrag(BrahmaVaryings input) : SV_Target
{
    clip(_FurMode - .5);
    float layer = _BrahmaFurLayer;
    float2 flow = SAMPLE_TEXTURE2D_LOD(_NoiseMap, sampler_NoiseMap, input.uv * 13, 0).rg - .5;
    float2 grid = input.uv * _FurDensity + flow * layer * .2;
    float2 cell = floor(grid);
    float random = frac(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
    float2 center = .2 + .6 * frac(float2(random * 17.7, random * 31.3));
    float strandDistance = length(frac(grid) - center);
    float radius = lerp(.33, .06, layer) * lerp(.65, 1.2, random);
    clip(radius - strandDistance);
    clip(lerp(.45, 1, random) - layer);
    half3 color = BrahmaEvaluate(input, false);
    color *= lerp(.70h, 1.08h, layer) * lerp(.88h, 1.12h, random);
    return half4(color, 1);
}

half4 BrahmaFaceShadowFrag(BrahmaVaryings input) : SV_Target
{
    clip(_UseFringeShadowReceiver - 0.5);
    return half4(BrahmaEvaluate(input, true), 1);
}

half4 BrahmaDepthFrag(BrahmaVaryings input) : SV_Target
{
    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
    BrahmaAlphaClip(alpha);
    return 0;
}

half4 BrahmaHairShadowFrag(BrahmaVaryings input) : SV_Target
{
    clip(_UseFringeShadowCaster - 0.5);
    return BrahmaDepthFrag(input);
}

half4 BrahmaHairTransmissionFrag(BrahmaVaryings input) : SV_Target
{
    clip(_UseHairTranE - 0.5);
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    BrahmaAlphaClip(baseSample.a);
    half mask = SAMPLE_TEXTURE2D(_HairMaskTex, sampler_HairMaskTex, input.uv).g;
    half fresnel = pow(1 - saturate(dot(normalize(input.normalWS), SafeNormalize(GetWorldSpaceViewDir(input.positionWS)))), 3);
    return half4(baseSample.rgb, mask * fresnel * _HairTranEAlpha);
}

half4 BrahmaReflectionFrag(BrahmaVaryings input) : SV_Target
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    BrahmaAlphaClip(baseSample.a);
    return half4(BrahmaEvaluate(input, false), 1);
}

#endif
