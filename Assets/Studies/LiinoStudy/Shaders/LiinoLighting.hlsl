#ifndef LIINO_LIGHTING
#define LIINO_LIGHTING
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif

// Independent NPR + PBR reconstruction, NOT recovered original shader code.
// Cloth packed interpretation: R metal, A smoothness, B AO. G remains undecoded.
// Community implementation + local channel atlas support this hypothesis.
// UseRMO is enabled only on cloth; face/hair retain independent material models.
// GGX/Trowbridge-Reitz distribution, correlated Smith visibility, Schlick Fresnel.
float3 LiinoFresnel(float3 f0, float vh)
{
    float f = pow(1-saturate(vh),5);
    return f0+(1-f0)*f;
}
float3 LiinoHybridLight(float3 base, float3 N, float3 V, float3 strand,
    float3 L, float3 radiance, float visibility, float rough, float metal,
    float npr, float3 shadowTint, float threshold, float softness,
    float specStrength, float hair, float hairMask, float shift,
    float skin, float sheen, out float3 specular)
{
    float nl=dot(N,L), nv=max(saturate(dot(N,V)),0.001);
    float3 H=normalize(L+V+1e-6);
    float nh=saturate(dot(N,H)), vh=saturate(dot(V,H));
    float a=rough*rough, a2=a*a;
    float d=nh*nh*(a2-1)+1;
    float D=a2/max(3.14159265*d*d,1e-6);
    float sl=saturate(nl);
    float vis=0.5/max(sl*sqrt(nv*nv*(1-a2)+a2)+nv*sqrt(sl*sl*(1-a2)+a2),0.001);
    float3 F=LiinoFresnel(lerp(0.04.xxx,base,metal),vh);
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
    float wrapped=saturate((nl+0.35)/1.35);
    float3 diffuse=base*(1-metal)*(1-F)*lerp(sl.xxx,stylized,npr);
    diffuse+=base*(1-metal)*skin*float3(1,0.36,0.22)*max(wrapped-sl,0)*0.35;
    float grazing=pow(1-nv,4)*sheen*sl*(1-metal);
    return (diffuse+grazing*lerp(1.0.xxx,base,0.5))*radiance*visibility+specular;
}

void LiinoLighting_float(float4 Albedo, float4 NormalMap, float4 RMO,
    float4 HairMask, float3 PositionWS, float3 NormalWS, float3 ViewWS, float2 UV,
    float4 Tint, float4 ShadowTint, float Threshold, float Softness,
    float NormalStrength, float UseRMO, float Roughness, float Metallic,
    float OcclusionStrength, float SpecularStrength, float RimStrength,
    float Hair, float Face, float Opacity, float DebugMode,
    float NPRWeight, float EnvironmentStrength, float RoughnessScale,
    float Sheen, float SkinScatter, float HairShift, float AlphaFresnel, float SpecularAA, float MetallicScale,
    float Wetness, float Rain, float WaterHeight, float Wettable, float WetDarkening,
    float WetRoughness, float DropletStrength, float Silk, float UseRamp, float UseFaceSDF,
    float4 HeadForward, float4 HeadRight, float4 SilkDryColor, float4 SilkWetColor,
    float Anisotropy, float UseAlpha, UnityTexture2D DiffRamp, UnityTexture2D FaceSDF,
    out float3 Color, out float Alpha)
{
    float3 N=normalize(NormalWS), V=normalize(ViewWS);
    // Deterministic UV pattern sticks to cloth under skeletal deformation.
    float2 cell=floor(UV*95);
    float hash=frac(sin(dot(cell,float2(127.1,311.7)))*43758.5453);
    float2 q=frac(UV*95)-float2(.25+.5*hash,.5);
    q.y*=1.5;
    float drop=(1-smoothstep(.07,.19,length(q)))*step(.65,hash);
    float patch=.5+.25*sin(UV.x*71+sin(UV.y*41))+.25*sin(UV.y*93);
    float water=1-smoothstep(WaterHeight-.025,WaterHeight+.025+.025*patch,PositionWS.y);
    float wet=saturate(max(Wetness,max(water,Rain*(.55+.45*saturate(N.y)))))*Wettable;
    wet*=lerp(smoothstep(.12,.8,patch),1,saturate(wet*1.4));
    float3 dp1=ddx(PositionWS),dp2=ddy(PositionWS);
    float2 du1=ddx(UV),du2=ddy(UV);
    float3 p2=cross(dp2,N),p1=cross(N,dp1);
    float3 T=p2*du1.x+p1*du2.x,B=p2*du1.y+p1*du2.y;
    float inv=rsqrt(max(max(dot(T,T),dot(B,B)),1e-12));
    float3 ts=NormalMap.xyz*2-1;
#ifndef SHADERGRAPH_PREVIEW
    ts=UnpackNormal(NormalMap);
#endif
    ts.xy*=NormalStrength*lerp(1,.7,wet);
    ts.xy+=q*drop*Rain*DropletStrength*Wettable*(1-Hair)*3;
    ts=normalize(ts);
    N=normalize(T*inv*ts.x+B*inv*ts.y+N*ts.z);
    float3 strand=normalize(B+float3(0,1e-5,0));
    float rough=clamp(lerp(Roughness,1-RMO.a,saturate(UseRMO))*RoughnessScale,0.10,0.97);
    rough=lerp(rough,min(rough,max(.1,WetRoughness)),wet);
    float variance=dot(ddx(N),ddx(N))+dot(ddy(N),ddy(N));
    rough=sqrt(saturate(rough*rough+min(variance*SpecularAA,0.15)));
    float metal=saturate(lerp(Metallic,RMO.r,saturate(UseRMO)))*saturate(MetallicScale);
    float ao=lerp(1,RMO.b,saturate(UseRMO*OcclusionStrength));
    float3 base=Albedo.rgb*Tint.rgb;
    base*=lerp(1,1-WetDarkening,wet);
    base*=lerp(1.0.xxx,lerp(SilkDryColor.rgb,SilkWetColor.rgb,wet),Silk);
    SpecularStrength*=lerp(1,1.65,wet);
    Sheen*=1-wet;
    float fiber=pow(saturate(1-dot(strand,normalize(V+float3(.3,.7,-.4)))*dot(strand,normalize(V+float3(.3,.7,-.4)))),24);

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
    // The source SDF is present; sampling axis/channel remains an explicit reconstruction.
    float3 forward=normalize(HeadForward.xyz+float3(0,0,-.00001));
    float3 right=normalize(HeadRight.xyz+float3(.00001,0,0));
    float2 faceUV=UV;faceUV.x=dot(L,right)<0?1-UV.x:UV.x;
    float sdf=SAMPLE_TEXTURE2D(FaceSDF.tex,FaceSDF.samplerstate,faceUV).g;
    float faceBand=smoothstep(1-saturate(dot(L,forward)*.5+.5)-.04,1-saturate(dot(L,forward)*.5+.5)+.04,sdf);
    float halfLambert=dot(N,L)*.5+.5;
    float3 sourceRamp=SAMPLE_TEXTURE2D(DiffRamp.tex,DiffRamp.samplerstate,float2(saturate(halfLambert),.5)).rgb;
    float npr=saturate(NPRWeight), soft=max(Softness,lerp(0.005,0.12,Face));
    float3 directSpec;
    // Artistic face shadow attenuation; this is not the game's face-shadow algorithm.
    float faceVisibility=lerp(visibility,lerp(0.55,1,visibility),Face);
    float3 direct=LiinoHybridLight(base,N,V,strand,L,radiance,faceVisibility,rough,metal,npr,
        ShadowTint.rgb,Threshold,soft,SpecularStrength,Hair,HairMask.r,HairShift,SkinScatter,Sheen,directSpec);
    direct=lerp(direct,base*(.18+.82*sourceRamp)*radiance*lerp(.45,1,visibility)+directSpec,UseRamp*(1-Face));
    direct=lerp(direct,base*lerp(ShadowTint.rgb*.48,1.0.xxx,faceBand)*radiance,Face*UseFaceSDF);
    direct+=fiber*Anisotropy*.13*base*radiance*visibility*(1-wet*.6);
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
        direct+=LiinoHybridLight(base,N,V,strand,light.direction,light.color*light.distanceAttenuation,
            light.shadowAttenuation,rough,metal,npr,ShadowTint.rgb,Threshold,soft,SpecularStrength,
            Hair,HairMask.r,HairShift,SkinScatter,Sheen,sp); directSpec+=sp;
    }
    #endif
    LIGHT_LOOP_BEGIN(count)
        Light light=GetAdditionalLight(lightIndex,PositionWS,half4(1,1,1,1));
        float3 sp;
        direct+=LiinoHybridLight(base,N,V,strand,light.direction,light.color*light.distanceAttenuation,
            light.shadowAttenuation,rough,metal,npr,ShadowTint.rgb,Threshold,soft,SpecularStrength,
            Hair,HairMask.r,HairShift,SkinScatter,Sheen,sp); directSpec+=sp;
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
    float coverage=saturate(lerp(1,Albedo.a,UseAlpha)*Tint.a*Opacity);
    Alpha=saturate(coverage+(1-coverage)*pow(1-nv,3)*AlphaFresnel)*step(0.001,Opacity);
    if(DebugMode>0.5&&DebugMode<1.5) Color=base;
    if(DebugMode>1.5&&DebugMode<2.5) Color=N*0.5+0.5;
    if(DebugMode>2.5&&DebugMode<3.5) Color=float3(rough,metal,ao);
    if(DebugMode>3.5&&DebugMode<4.5) Color=visibility*saturate(dot(N,L));
    if(DebugMode>4.5&&DebugMode<5.5) Color=directSpec;
    if(DebugMode>5.5&&DebugMode<6.5) Color=indirectSpec;
    if(DebugMode>6.5&&DebugMode<7.5) Color=indirectDiffuse;
    if(DebugMode>7.5&&DebugMode<8.5) Color=wet.xxx;
    if(DebugMode>8.5&&DebugMode<9.5) Color=rough.xxx;
    if(DebugMode>9.5) Color=float3(drop,patch,wet);
}
#endif
