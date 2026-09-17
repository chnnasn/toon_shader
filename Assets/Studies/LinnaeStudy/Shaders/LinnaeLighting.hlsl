#ifndef LINNAE_LIGHTING
#define LINNAE_LIGHTING
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
TEXTURE2D(_LinnaeHairDepth); SAMPLER(sampler_LinnaeHairDepth);
float4x4 _LinnaeHairWorldToClip;
float _LinnaeHairShadowActive;
#endif
// Independent visual reconstruction. PMX has color textures, no original SDF or PBR masks.
void LinnaeLighting_float(float4 Albedo,float3 PositionWS,float3 NormalWS,float3 ViewWS,float2 UV,
 float4 Tint,float4 ShadowTint,float Threshold,float Softness,float Roughness,float Metallic,
 float SpecularStrength,float RimStrength,float Hair,float Face,float Skin,float Opacity,float UseAlpha,
 float DebugMode,float EnvironmentStrength,float Eye,float4 HeadForward,float4 HeadRight,
 UnityTexture2D FaceSDF,float UseFaceSDF,float HairShadowStrength,float4 HeadOrigin,float4 HeadUp,
 out float3 Color,out float Alpha)
{
 float3 N=normalize(NormalWS),V=normalize(ViewWS),base=Albedo.rgb*Tint.rgb;
 float3 L=normalize(float3(-.5,.7,-.6)),radiance=1,ambient=.22;
 float shadow=1;
#ifndef SHADERGRAPH_PREVIEW
 float4 sc=TransformWorldToShadowCoord(PositionWS);
 #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
 sc=ComputeScreenPos(TransformWorldToHClip(PositionWS));
 #endif
 Light ml=GetMainLight(sc,PositionWS,half4(1,1,1,1));
 L=ml.direction;radiance=ml.color;shadow=ml.shadowAttenuation;
 ambient=max(SampleSH(N),.03);
#endif
 float nl=dot(N,L),nv=saturate(dot(N,V));
 float band=smoothstep(Threshold-max(Softness,.005),Threshold+max(Softness,.005),nl*.5+.5);
 float3 headF=normalize(HeadForward.xyz),headR=normalize(HeadRight.xyz);
 float2 localL=normalize(float2(dot(L,headR),dot(L,headF))+1e-5);
 float faceLight=localL.y;
 float side=localL.x;
 float faceBand=smoothstep(-.32,.2,faceLight+dot(N,normalize(HeadRight.xyz))*side*.32);
 // Shared head-space projection avoids the PMX mouth/nose overlay's unrelated UV islands.
 float3 headDelta=(PositionWS-HeadOrigin.xyz)/max(HeadOrigin.w,.001);
 float2 faceUV=float2(dot(headDelta,headR)/.15+.5,dot(headDelta,normalize(HeadUp.xyz))*4.7+.505);
 float2 sdfUV=faceUV;sdfUV.x=side>0?1-faceUV.x:faceUV.x;
 float4 distances=SAMPLE_TEXTURE2D(FaceSDF.tex,FaceSDF.samplerstate,sdfUV);
 float angle=acos(clamp(faceLight,-1,1))*1.273239545;
 float sd=angle<1?lerp(distances.r,distances.g,angle):angle<2?lerp(distances.g,distances.b,angle-1):angle<3?lerp(distances.b,distances.a,angle-2):lerp(distances.a,0,angle-3);
 float sdfBand=smoothstep(.5-.014,.5+.014,sd);
 faceBand=lerp(faceBand,sdfBand,UseFaceSDF);
 band=lerp(band,faceBand,Face);
 float hairOcclusion=0;
#ifndef SHADERGRAPH_PREVIEW
 if(Face>.5 && _LinnaeHairShadowActive>.5){
 float4 hp=mul(_LinnaeHairWorldToClip,float4(PositionWS,1));
 float3 hc=hp.xyz/max(hp.w,1e-5);float2 huv=hc.xy*.5+.5;
 #if UNITY_UV_STARTS_AT_TOP
 huv.y=1-huv.y;
 #endif
 float receiver=hc.z;
 #if UNITY_REVERSED_Z
 receiver=1-receiver;
 #endif
 float valid=step(0,huv.x)*step(huv.x,1)*step(0,huv.y)*step(huv.y,1);
 for(int sy=-1;sy<=1;sy++)for(int sx=-1;sx<=1;sx++){
 float caster=SAMPLE_TEXTURE2D(_LinnaeHairDepth,sampler_LinnaeHairDepth,huv+float2(sx,sy)/1024).r;
 hairOcclusion+=step(caster+.0012,receiver)/9;
 }
 hairOcclusion*=valid*_LinnaeHairShadowActive*smoothstep(.62,.76,faceUV.y);
 }
#endif
 float vis=lerp(shadow,1,Face*.85);
 float shade=band*lerp(.3,1,vis)*(1-hairOcclusion*HairShadowStrength*Face);
 float3 diffuse=base*lerp(ShadowTint.rgb*.72,1.0.xxx,shade)*(1-Metallic*.85);
 float3 H=normalize(L+V+1e-5);
 float rough=clamp(Roughness,.16,.95),a2=pow(rough,4);
 float nh=saturate(dot(N,H)),d=nh*nh*(a2-1)+1;
 float3 fres=lerp(.04.xxx,base,Metallic)+(1-lerp(.04.xxx,base,Metallic))*pow(1-saturate(dot(V,H)),5);
 float3 spec=a2/(3.14159265*d*d+1e-4)*fres*saturate(nl)*SpecularStrength;
 float3 dp1=ddx(PositionWS),dp2=ddy(PositionWS);float2 du1=ddx(UV),du2=ddy(UV);
 float3 strand=cross(dp2,N)*du1.y+cross(N,dp1)*du2.y;
 strand=normalize(strand+N*.00001+float3(0,.00001,0));
 float th=dot(normalize(strand+N*.13),H);
 float hairSpec=pow(sqrt(saturate(1-th*th)),60)*smoothstep(-.15,.5,nl);
 spec=lerp(spec,hairSpec*lerp(.5.xxx,base,.5)*SpecularStrength,Hair)*(1-Face)*vis;
 float3 rim=pow(1-nv,4)*RimStrength*smoothstep(-.3,.7,nl)*lerp(.8.xxx,base,.4);
 float scatter=Skin*max(saturate((nl+.45)/1.45)-saturate(nl),0);
 Color=diffuse*radiance+base*ambient*EnvironmentStrength+spec*radiance+rim+base*float3(.16,.045,.025)*scatter;
 Color=lerp(Color,base*(.85+.15*radiance),Eye);
 // Additional lighting intentionally remains a gentle fill so the cel ramp stays legible.
#ifndef SHADERGRAPH_PREVIEW
 InputData inputData=(InputData)0;
 inputData.positionWS=PositionWS;
 float4 screenPosition=ComputeScreenPos(TransformWorldToHClip(PositionWS));
 inputData.normalizedScreenSpaceUV=screenPosition.xy/max(screenPosition.w,1e-5);
 inputData.viewDirectionWS=V;
 uint count=GetAdditionalLightsCount();
 LIGHT_LOOP_BEGIN(count)
  Light l=GetAdditionalLight(lightIndex,PositionWS,half4(1,1,1,1));
  Color+=base*l.color*l.distanceAttenuation*l.shadowAttenuation*saturate(dot(N,l.direction))*.25;
 LIGHT_LOOP_END
#endif
 Alpha=lerp(1,Albedo.a,UseAlpha)*Opacity;
 if(DebugMode>.5 && DebugMode<1.5)Color=base;
 if(DebugMode>1.5 && DebugMode<2.5)Color=band.xxx;
 if(DebugMode>2.5 && DebugMode<3.5)Color=N*.5+.5;
 if(DebugMode>3.5 && DebugMode<4.5)Color=spec;
 if(DebugMode>4.5 && DebugMode<5.5)Color=hairOcclusion.xxx;
}
#endif
