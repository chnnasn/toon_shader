#ifndef CLUKAY_HYBRID_LIGHTING
#define CLUKAY_HYBRID_LIGHTING
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif

// Independent NPR + PBR reconstruction, NOT recovered original shader code.
// R/G/B = roughness/metallic/occlusion, confirmed by recovered uber shader metadata.
// GGX/Trowbridge-Reitz distribution, correlated Smith visibility, Schlick Fresnel.
float3 ClukayFresnel(float3 f0, float vh)
{
    float f = pow(1-saturate(vh),5);
    return f0+(1-f0)*f;
}
float3 ClukayHybridLight(float3 base, float3 N, float3 V, float3 strand,
    float3 L, float3 radiance, float visibility, float rough, float metal,
    float npr, float3 shadowTint, float threshold, float softness,
    float specStrength, float hair, float hairMask, float shift,
    float skin, float sheen, UnityTexture2D sourceRamp, float useSourceRamp, out float3 specular)
{
    float nl=dot(N,L), nv=max(saturate(dot(N,V)),0.001);
    float3 H=normalize(L+V+1e-6);
    float nh=saturate(dot(N,H)), vh=saturate(dot(V,H));
    float a=rough*rough, a2=a*a;
    float d=nh*nh*(a2-1)+1;
    float D=a2/max(3.14159265*d*d,1e-6);
    float sl=saturate(nl);
    float vis=0.5/max(sl*sqrt(nv*nv*(1-a2)+a2)+nv*sqrt(sl*sl*(1-a2)+a2),0.001);
    float3 F=ClukayFresnel(lerp(0.04.xxx,base,metal),vh);
    float3 ggx=D*vis*F*sl;
    // UV-derived strand frame; shifted two-lobe Kajiya-Kay artistic hair model.
    float3 t1=normalize(strand+N*shift),t2=normalize(strand+N*(shift-0.27));
    float th1=dot(t1,H),th2=dot(t2,H);
    float h1=pow(sqrt(saturate(1-th1*th1)),lerp(160,25,rough));
    float h2=pow(sqrt(saturate(1-th2*th2)),24);
    float3 hairSpec=(h1*0.65+h2*0.16)*hairMask*lerp(0.7.xxx,base,0.3)*smoothstep(-0.2,0.6,nl);
    specular=lerp(ggx,hairSpec,hair)*specStrength*radiance*visibility;
    float band=smoothstep(threshold-softness,threshold+softness,nl*0.5+0.5);
    // NPR affects diffuse only. Metallic regions retain zero diffuse energy.
    float3 stylized=lerp(shadowTint*0.18,1.0.xxx,band);
    // Raw four-row game ramp data. Row interpretation is source-anchored;
    // the NL coordinate and combination remain an independent reconstruction.
    float3 recoveredRamp=SAMPLE_TEXTURE2D_LOD(sourceRamp.tex,sourceRamp.samplerstate,float2(saturate(nl*0.5+0.5),0.125),0).rgb;
    stylized=lerp(stylized,recoveredRamp,saturate(useSourceRamp));
    float wrapped=saturate((nl+0.35)/1.35);
    float3 diffuse=base*(1-metal)*(1-F)*lerp(sl.xxx,stylized,npr);
    diffuse+=base*(1-metal)*skin*float3(1,0.36,0.22)*max(wrapped-sl,0)*0.35;
    float grazing=pow(1-nv,4)*sheen*sl*(1-metal);
    return (diffuse+grazing*lerp(1.0.xxx,base,0.5))*radiance*visibility+specular;
}

void ClukayLighting_float(float4 Albedo, float4 NormalMap, float4 RMO,
    float4 HairMask, float3 PositionWS, float3 NormalWS, float3 ViewWS, float2 UV,
    float4 Tint, float4 ShadowTint, float Threshold, float Softness,
    float NormalStrength, float UseRMO, float Roughness, float Metallic,
    float OcclusionStrength, float SpecularStrength, float RimStrength,
    float Hair, float Face, float Opacity, float DebugMode,
    float NPRWeight, float EnvironmentStrength, float RoughnessScale,
    float Sheen, float SkinScatter, float HairShift, float AlphaFresnel, float SpecularAA, float MetallicScale,
    UnityTexture2D SourceRamp, float UseSourceRamp,
    out float3 Color, out float Alpha)
{
    float3 N=normalize(NormalWS), V=normalize(ViewWS);
    float3 dp1=ddx(PositionWS),dp2=ddy(PositionWS);
    float2 du1=ddx(UV),du2=ddy(UV);
    float3 p2=cross(dp2,N),p1=cross(N,dp1);
    float3 T=p2*du1.x+p1*du2.x,B=p2*du1.y+p1*du2.y;
    float inv=rsqrt(max(max(dot(T,T),dot(B,B)),1e-12));
    float3 ts=NormalMap.xyz*2-1;
#ifndef SHADERGRAPH_PREVIEW
    ts=UnpackNormal(NormalMap);
#endif
    ts.xy*=NormalStrength; ts=normalize(ts);
    N=normalize(T*inv*ts.x+B*inv*ts.y+N*ts.z);
    float3 strand=normalize(B+float3(0,1e-5,0));
    float rough=clamp(lerp(Roughness,RMO.r,saturate(UseRMO))*RoughnessScale,0.10,0.97);
    float variance=dot(ddx(N),ddx(N))+dot(ddy(N),ddy(N));
    rough=sqrt(saturate(rough*rough+min(variance*SpecularAA,0.15)));
    float metal=saturate(lerp(Metallic,RMO.g,saturate(UseRMO)))*saturate(MetallicScale);
    float ao=lerp(1,RMO.b,saturate(UseRMO*OcclusionStrength));
    float3 base=Albedo.rgb*Tint.rgb;
    // Diagnostic clay view: neutral diffuse material; keep alpha cutouts and normals.
    // Mode zero is unchanged and no material asset is edited by the UI.
    if(DebugMode>8.5){base=0.7.xxx;rough=0.85;metal=0;ao=1;Hair=0;NPRWeight=0;SkinScatter=0;Sheen=0;RimStrength=0;SpecularStrength=0.15;}
    float3 L=normalize(float3(-0.4,0.6,-0.6)),radiance=1,ambient=0.15;
    float visibility=1;
    float2 screenUV=0;
#ifndef SHADERGRAPH_PREVIEW
    float4 shadowCoord=TransformWorldToShadowCoord(PositionWS);
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
        shadowCoord=ComputeScreenPos(TransformWorldToHClip(PositionWS));
    #endif
    Light main=GetMainLight(shadowCoord,PositionWS,half4(1,1,1,1));
    L=main.direction; radiance=main.color*main.distanceAttenuation;
    visibility=main.shadowAttenuation;
    ambient=max(SampleSH(N),0);
    float4 screenPos=ComputeScreenPos(TransformWorldToHClip(PositionWS));
    screenUV=screenPos.xy/max(screenPos.w,1e-5);
#endif
    // No source face SDF is present. Face receives a softened ramp, not fake SDF claims.
    float npr=saturate(NPRWeight), soft=max(Softness,lerp(0.005,0.12,Face));
    float3 directSpec;
    // Artistic face shadow attenuation; this is not the game's face-shadow algorithm.
    float faceVisibility=lerp(visibility,lerp(0.55,1,visibility),Face);
    float3 direct=ClukayHybridLight(base,N,V,strand,L,radiance,faceVisibility,rough,metal,npr,
        ShadowTint.rgb,Threshold,soft,SpecularStrength,Hair,HairMask.r,HairShift,SkinScatter,Sheen,SourceRamp,UseSourceRamp,directSpec);
#ifndef SHADERGRAPH_PREVIEW
    #if defined(_ADDITIONAL_LIGHTS)
    InputData inputData=(InputData)0;
    inputData.positionWS=PositionWS;inputData.normalizedScreenSpaceUV=screenUV;
    uint count=GetAdditionalLightsCount();
    #if USE_CLUSTER_LIGHT_LOOP
    [loop] for(uint lightIndex=0;lightIndex<min(URP_FP_DIRECTIONAL_LIGHTS_COUNT,MAX_VISIBLE_LIGHTS);lightIndex++)
    {
        CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
        Light light=GetAdditionalLight(lightIndex,PositionWS,half4(1,1,1,1));
        float3 sp;
        direct+=ClukayHybridLight(base,N,V,strand,light.direction,light.color*light.distanceAttenuation,
            light.shadowAttenuation,rough,metal,npr,ShadowTint.rgb,Threshold,soft,SpecularStrength,
            Hair,HairMask.r,HairShift,SkinScatter,Sheen,SourceRamp,UseSourceRamp,sp); directSpec+=sp;
    }
    #endif
    LIGHT_LOOP_BEGIN(count)
        Light light=GetAdditionalLight(lightIndex,PositionWS,half4(1,1,1,1));
        float3 sp;
        direct+=ClukayHybridLight(base,N,V,strand,light.direction,light.color*light.distanceAttenuation,
            light.shadowAttenuation,rough,metal,npr,ShadowTint.rgb,Threshold,soft,SpecularStrength,
            Hair,HairMask.r,HairShift,SkinScatter,Sheen,SourceRamp,UseSourceRamp,sp); directSpec+=sp;
    LIGHT_LOOP_END
    #endif
#endif
    float nv=saturate(dot(N,V));
    float3 indirectDiffuse=ambient*base*(1-metal)*ao;
    float3 indirectSpec=0;
#ifndef SHADERGRAPH_PREVIEW
    // Use URP's prefiltered reflection probes and environment BRDF, not a fixed rim.
    half alphaForBRDF=1;
    BRDFData brdf;
    half3 f0=lerp(half3(0.04,0.04,0.04),base,metal);
    half reflectivity=max(max(f0.r,f0.g),f0.b);
    InitializeBRDFDataDirect(base,base*(1-metal)*0.96,f0,reflectivity,1-reflectivity,1-rough,alphaForBRDF,brdf);
    half3 env=GlossyEnvironmentReflection(reflect(-V,N),PositionWS,rough,ao,screenUV);
    indirectSpec=EnvironmentBRDFSpecular(brdf,pow(1-nv,4))*env*EnvironmentStrength*SpecularStrength;
    indirectSpec*=lerp(1,0.3,Hair);
#endif
    float rim=pow(1-nv,4)*smoothstep(-0.3,0.8,dot(N,L))*RimStrength;
    Color=max(direct+indirectDiffuse+indirectSpec+rim*radiance,0);
    float coverage=saturate(Albedo.a*Tint.a*Opacity);
    Alpha=saturate(coverage+(1-coverage)*pow(1-nv,3)*AlphaFresnel)*step(0.001,Opacity);
    if(DebugMode>0.5&&DebugMode<1.5) Color=base;
    if(DebugMode>1.5&&DebugMode<2.5) Color=N*0.5+0.5;
    if(DebugMode>2.5&&DebugMode<3.5) Color=float3(rough,metal,ao);
    if(DebugMode>3.5&&DebugMode<4.5) Color=visibility*saturate(dot(N,L));
    if(DebugMode>4.5&&DebugMode<5.5) Color=directSpec;
    if(DebugMode>5.5&&DebugMode<6.5) Color=indirectSpec;
    if(DebugMode>6.5&&DebugMode<7.5) Color=indirectDiffuse;
    if(DebugMode>7.5&&DebugMode<8.5) Color=Alpha;
}
#endif
