#ifndef LINNAE_RAIN_LIGHTING
#define LINNAE_RAIN_LIGHTING
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif
#include "Assets/Studies/LiinoStudy/Shaders/LiinoRain.hlsl"

// Per-renderer weather, shared by the character's opaque and transparent passes.
float4 _LinnaeWeather; // x = surface saturation, y = rainfall
float3 _LinnaeRootWS;
float3 _LinnaeRightWS;

float3 LinnaeDiffuseRamp(float nl, float band, float visibility, float3 shadowTint, float skin, float face)
{
    float wrapped = saturate(nl * .5 + .5);
    float turning = smoothstep(.13, .90, wrapped);
    float light = lerp(.40 * band + .60 * turning, band, face * .85);
    float deep = (1 - smoothstep(.02, .43, wrapped)) * (1 - .85 * face);
    float3 shade = lerp(shadowTint * float3(.69, .69, .84), 1, light * visibility);
    shade *= lerp(1, float3(.68, .74, .91), deep);
    float blush = 4 * turning * (1 - turning) * skin * (1 - .65 * face);
    return shade * lerp(1, float3(1.07, .97, .92), blush);
}

void LinnaeRainFinish(float3 positionWS, float3 N, float3 V, float3 L, float3 radiance,
    float visibility, float skin, float hair, float face, float eye, float metal, float transmission,
    inout float3 color, inout float alpha, inout float3 specular, out float2 drops)
{
    float wet = saturate(_LinnaeWeather.x);
    float rain = saturate(_LinnaeWeather.y);
    float cloth = (1 - skin) * (1 - hair) * (1 - metal);
    float3 H = SafeNormalize(L + V);
    // Open sky cools the shadow side. Surfaces facing the key still receive warm light.
    float keyFacing = smoothstep(-.30,.70,dot(N,L)) * lerp(.45,1,visibility);
    float3 stormLight = lerp(float3(.64,.69,.81),float3(.94,.86,.78),keyFacing);
    color *= lerp(1, stormLight, rain);
    float soak = wet * (1 - eye);
    color *= 1 - soak * (.09 + hair * .13 + cloth * .17);

    float bead = 0, trail = 0;
    float3 slope = 0;
    if (rain > .001 && eye < .5)
    {
        LiinoRainSurfaceRelative(positionWS - _LinnaeRootWS, N, _LinnaeRightWS,
            rain, hair, cloth, bead, trail, slope);
    }
    float shelter = (1 - face * .78) * (1 - eye);
    drops = float2(bead, trail) * shelter;
    float water = saturate(drops.x + drops.y * .76);
    float3 coatN = normalize(N + slope * shelter * 1.05);
    float3 R = reflect(-V,coatN);
    float grazing = pow(1 - saturate(dot(coatN,V)), 4);
    float sky = smoothstep(-.22,.68,R.y);
    float3 skyColor = lerp(float3(.045,.064,.12),float3(.38,.53,.78),sky);
    float3 reflected = skyColor;
#ifndef SHADERGRAPH_PREVIEW
    // ComputeScreenPos handles the projection flip for offscreen cameras.
    float4 clipScreen = ComputeScreenPos(TransformWorldToHClip(positionWS));
    float2 screenUV = clipScreen.xy / max(clipScreen.w, .0001);
    if (soak + water > .001)
        reflected += .36 * GlossyEnvironmentReflection(R,positionWS,lerp(.24,.07,water),1,screenUV);
#endif
    float broad = pow(saturate(dot(N,H)),lerp(22,54,hair));
    float glint = pow(saturate(dot(coatN,H)),lerp(95,54,water));
    float3 film = reflected * (.047 + .50 * grazing) + radiance * visibility * (.11*broad + .56*glint);
    float3 cap = reflected * (.27 + .62*grazing) + radiance * (1.35*glint*visibility + .09*sky);
    float3 shine = soak * shelter * film + water * cap;
    color = color * (1 - water * .33) + shine;
    specular += shine;

    // The transparent outer shirt reveals the swimsuit, retaining its silhouette at grazing angles.
    alpha *= 1 - transmission * soak * (1 - .44 * grazing);
}

#include "Assets/Studies/LinnaeStudy/Shaders/LinnaeLighting.hlsl"
#endif
