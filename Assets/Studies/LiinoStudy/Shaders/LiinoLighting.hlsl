#ifndef LIINO_LIGHTING
#define LIINO_LIGHTING
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#endif
#include "LiinoRain.hlsl"

// Position and vertical radius of the face renderer, used by the hair envelope.
float4 _LiinoFaceBounds;

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
    float h1=pow(saturate(1-th1*th1),lerp(85,38,rough));
    float h2=pow(saturate(1-th2*th2),12);
    float3 hairSpec=(h1*.58*float3(1,.63,.38)+h2*.19*float3(1,.46,.26))
        * hairMask * smoothstep(-.25,.5,nl);
    specular=lerp(ggx,hairSpec,hair)*specStrength*radiance*visibility;
    float halfLight=saturate(nl*.5+.5);
    float turning=smoothstep(threshold-.32-softness,threshold+.20+softness,halfLight);
    float terminator=smoothstep(threshold-softness,threshold+softness,halfLight);
    float3 stylized=lerp(shadowTint*.26, lerp(shadowTint*.78,1.0.xxx,turning),
                         .18+.60*turning+.22*terminator);
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
    float Anisotropy, float UseAlpha, UnityTexture2D DiffRamp, UnityTexture2D FaceSDF, float Iris,
    out float3 Color, out float Alpha)
{
    float3 N=normalize(NormalWS), V=normalize(ViewWS);
    float3 geometryNormal=N;
    float patch=.5+.28*sin(UV.x*37+sin(UV.y*23))+.22*sin(UV.y*57+UV.x*12);
    float water=1-smoothstep(WaterHeight-.012,WaterHeight+.012+.016*patch,PositionWS.y);
    float drop=0,trail=0;
    float3 waterSlope=0;
    if (Rain>0 && Wettable>0 && DropletStrength>0)
    {
        LiinoRainSurface(PositionWS,N,HeadRight.xyz,Rain,Hair,Silk,drop,trail,waterSlope);
        float strength=saturate(DropletStrength*Wettable)*(1-water);
        drop*=strength; trail*=strength; waterSlope*=strength;
    }
    float exposure=lerp(.32,1,saturate(N.y*.55+.45));
    float wet=Wettable*saturate(max(water,max(Wetness,Rain*exposure*lerp(.46,1,patch))));
    float liquid=saturate(max(drop,trail));
    float3 dp1=ddx(PositionWS),dp2=ddy(PositionWS);
    float2 du1=ddx(UV),du2=ddy(UV);
    float3 p2=cross(dp2,N),p1=cross(N,dp1);
    float3 T=p2*du1.x+p1*du2.x,B=p2*du1.y+p1*du2.y;
    float inv=rsqrt(max(max(dot(T,T),dot(B,B)),1e-12));
    float3 ts=NormalMap.xyz*2-1;
#ifndef SHADERGRAPH_PREVIEW
    ts=UnpackNormal(NormalMap);
#endif
    ts.xy*=NormalStrength*lerp(1,.80,wet);
    ts=normalize(ts);
    N=normalize(T*inv*ts.x+B*inv*ts.y+N*ts.z);
    float3 strand=normalize(B+float3(0,1e-5,0));
    strand*=strand.y<0?-1:1;
    float rough=clamp(lerp(Roughness,1-RMO.a,saturate(UseRMO)*.75)*RoughnessScale,.17,.95);
    rough=lerp(rough,min(rough,max(.17,WetRoughness)),wet*lerp(.18,.38,Silk));
    float variance=dot(ddx(N),ddx(N))+dot(ddy(N),ddy(N));
    rough=sqrt(saturate(rough*rough+min(variance*SpecularAA,0.15)));
    float metal=saturate(lerp(Metallic,RMO.r,saturate(UseRMO)))*saturate(MetallicScale);
    float ao=lerp(1,RMO.b,saturate(UseRMO*OcclusionStrength));
    float3 base=Albedo.rgb*Tint.rgb;
    // Both skin atlases use the same complexion. Preserve the painted variation
    // on the cheeks, hands and joints before the common skin lighting is applied.
    float skin=saturate(SkinScatter);
    float skinWarmth=smoothstep(.075,.22,Albedo.r-Albedo.g);
    float3 skinBase=base*float3(1.15,.965,.88)
                    *lerp(1.0.xxx,float3(1.08,.88,.86),skinWarmth);
    float2 nose=(UV-float2(.50,.49))/float2(.025,.029);
    float2 lip=(UV-float2(.50,.367))/float2(.046,.012);
    float flush=Face*max(exp2(-dot(nose,nose)),exp2(-dot(lip,lip)));
    skinBase*=lerp(1.0.xxx,float3(1.025,.83,.77),flush);
    base=lerp(base,skinBase,skin);
    float blueDye=smoothstep(.16,.66,(base.b-max(base.r,base.g))/max(base.b,.01));
    float peak=max(base.r,max(base.g,base.b));
    float neutral=1-smoothstep(.13,.42,(peak-min(base.r,min(base.g,base.b)))/max(peak,.001));
    float silverCloth=UseRMO*(1-Silk)*neutral*smoothstep(.12,.48,peak);
    float silkValue=dot(base,float3(.2126,.7152,.0722));
    base=lerp(base,silkValue*lerp(SilkDryColor.rgb,SilkWetColor.rgb,wet),Silk);
    base*=1-WetDarkening*wet;
    Sheen*=1-wet*.64;

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
    float sdf=SAMPLE_TEXTURE2D(FaceSDF.tex,FaceSDF.samplerstate,faceUV).b;
    float2 lightXZ=L.xz/max(length(L.xz),.001);
    float faceTurn=acos(clamp(dot(lightXZ,forward.xz),-.999,.999))*.31831;
    float faceBand=smoothstep(faceTurn-.085,faceTurn+.085,sdf);
    float halfLambert=dot(N,L)*.5+.5;
    base*=lerp(1,lerp(.49,.89,smoothstep(.33,.91,halfLambert)),silverCloth);
    float3 sourceRamp=SAMPLE_TEXTURE2D(DiffRamp.tex,DiffRamp.samplerstate,float2(saturate(halfLambert),.5)).rgb;
    float npr=saturate(NPRWeight), soft=max(Softness,lerp(0.005,0.12,Face));
    float3 directSpec;
    // Artistic face shadow attenuation; this is not the game's face-shadow algorithm.
    float faceVisibility=lerp(visibility,lerp(0.55,1,visibility),Face);
    float strandMask=HairMask.r*lerp(.24,1,RMO.g);
    float3 direct=LiinoHybridLight(base,N,V,strand,L,radiance,faceVisibility,rough,metal,npr,
        ShadowTint.rgb,Threshold,soft,SpecularStrength,Hair,strandMask,HairShift,SkinScatter,Sheen,directSpec);
    direct=directSpec+(direct-directSpec)*lerp(1.0.xxx,.68+.40*sourceRamp,UseRamp*(1-Face));
    float rounded=smoothstep(.11,.88,halfLambert);
    float skinLight=lerp(rounded,faceBand,Face*UseFaceSDF);
    float3 skinTone=lerp(float3(.63,.42,.39),1.0.xxx,.24+.76*skinLight);
    float3 skinDirect=base*skinTone*(.81+.19*rounded)*radiance*lerp(.67,1,visibility);
    direct=lerp(direct,skinDirect+directSpec*.18,skin);
    float3 H=normalize(V+L+1e-6);
    if (Hair>.01 && _LiinoFaceBounds.w>.001)
    {
        // Curve a broad ribbon over the fringe, then break its core with the strand map.
        float headHeight=(PositionWS.y-_LiinoFaceBounds.y)/_LiinoFaceBounds.w;
        float bandHeight=.30+.68*H.y-.16*dot(geometryNormal.xz,H.xz)+.07*(RMO.g-.5);
        float distanceToBand=abs(headHeight-bandHeight);
        float band=exp2(-70*distanceToBand*distanceToBand);
        float core=exp2(-550*distanceToBand*distanceToBand);
        float facing=smoothstep(-.16,.78,dot(geometryNormal,L))*lerp(.45,1,visibility);
        float3 ribbon=(float3(.31,.12,.041)*band+float3(.76,.50,.32)*core)*strandMask;
        float3 hairLight=ribbon*radiance*facing*Hair*SpecularStrength;
        direct+=hairLight; directSpec+=hairLight;
    }
    float fiber=pow(saturate(1-pow(abs(dot(strand,H)),2)),18)*saturate(dot(N,L)*.7+.3);
    direct+=fiber*Anisotropy*.20*lerp(base,.35.xxx,.40)*radiance*visibility*(1-wet*.4);
    // Tall studio reflection on nylon; its width follows the film roughness.
    float2 panelDir=normalize(H.xz+float2(.0001,0));
    float2 panelSide=float2(-panelDir.y,panelDir.x);
    float across=dot(N.xz,panelSide);
    float panel=exp2(-across*across*lerp(11,25,wet))*smoothstep(.08,.70,dot(N.xz,panelDir));
    float3 textileSpec=panel*Silk*lerp(.060,.085,wet)*float3(.70,.84,1.0);
    float fold=pow(saturate(dot(N,H)),14);
    textileSpec+=fold*(silverCloth*float3(.23,.31,.46)+Anisotropy*.18*base);
    textileSpec*=radiance*lerp(.42,1,visibility);
    direct+=textileSpec; directSpec+=textileSpec;
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
            Hair,strandMask,HairShift,SkinScatter,Sheen,sp); directSpec+=sp;
    }
    #endif
    LIGHT_LOOP_BEGIN(count)
        Light light=GetAdditionalLight(lightIndex,PositionWS,half4(1,1,1,1));
        float3 sp;
        direct+=LiinoHybridLight(base,N,V,strand,light.direction,light.color*light.distanceAttenuation,
            light.shadowAttenuation,rough,metal,npr,ShadowTint.rgb,Threshold,soft,SpecularStrength,
            Hair,strandMask,HairShift,SkinScatter,Sheen,sp); directSpec+=sp;
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
    float3 substrate=direct+indirectDiffuse+indirectSpec+rim*radiance;
    substrate*=lerp(1.0.xxx,float3(.15,.42,1.68),blueDye*UseRMO*(1-metal));
    // Keep the painted pupil and star legible under the fringe.
    float3 eyeInk=lerp(dot(base,float3(.2126,.7152,.0722)).xxx,base,1.24);
    substrate=lerp(substrate,max(eyeInk,0)*lerp(.79,1.20,faceVisibility)
                   +saturate((base-.55)*1.8)*.42,Iris);
    // The continuous wet film follows the large form; only the water has the cap normal.
    float3 coatN=normalize(lerp(N,geometryNormal,.5)+waterSlope);
    float3 refl=reflect(-V,coatN);
    float coatNV=saturate(dot(coatN,V));
    float fresnel=.022+.978*pow(1-coatNV,5);
    float3 coatEnv=0;
#ifndef SHADERGRAPH_PREVIEW
    if (wet+liquid>0)
        coatEnv=GlossyEnvironmentReflection(refl,PositionWS,lerp(.24,.08,liquid),1,screenUV);
#endif
    float coat=wet*lerp(.085,.21,Silk);
    float waterGlint=pow(saturate(dot(coatN,H)),lerp(125,65,liquid));
    float glancingSky=smoothstep(-.14,.78,refl.y);
    float3 reflected=coatEnv*(fresnel+.055)+float3(.24,.35,.48)*glancingSky;
    float3 transmitted=lerp(1.0.xxx,base/max(peak,.045),.60);
    float3 beadLight=reflected*transmitted+waterGlint*float3(1,.92,.78)*radiance*1.3*lerp(.45,1,visibility);
    beadLight*=lerp(1, .16+.68*panel, Silk);
    float3 coatLight=coat*(fresnel*coatEnv+.48*waterGlint*radiance*visibility);
    Color=max(substrate*(1-lerp(.28,.46,Silk)*liquid)+coatLight+liquid*beadLight,0);
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
    if(DebugMode>9.5) Color=float3(drop,trail,wet*.35);
}
#endif
