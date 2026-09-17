#ifndef GF2_SOURCE_BRDF_INCLUDED
#define GF2_SOURCE_BRDF_INCLUDED
// Port of uber/0_12.named.glsl, not the entire game's renderer.
// Keep these arithmetic functions independent of URP light/probe acquisition.
float GF2Distribution(float nh, float rough)
{
    float a=rough*rough;
    float denominator=(nh*a)*(nh*a)+(1-nh*nh);
    float d=a/max(denominator,1e-12); // finite guard at roughness=0 (adapter deviation)
    return min(d*d,2048);
}
float GF2Visibility(float nv, float nl, float rough)
{
    float a=rough*rough, k=1-a;
    return min(0.5/max(nl*(nv*k+a)+nv*(nl*k+a),0.0001),1);
}
float GF2FresnelFactor(float vh, float3 f0)
{
    return 1+(saturate(50*f0.g)-1)*pow(max(1-vh,0.001),5);
}
float2 GF2EnvironmentAB(float rough,float nv)
{
    float4 r=rough*float4(-1,-0.0275,-0.572,0.022)+float4(1,0.0425,1.04,-0.04);
    float a004=min(r.x*r.x,exp2(-9.28*nv))*r.x+r.y;
    return a004*float2(-1.04,1.04)+r.zw;
}
float3 GF2FlattenGI(float3 directionalSH,float3 constantSH)
{
    const float3 luminance=float3(0.2126729,0.7151522,0.072175);
    float3 c=max(directionalSH,0.001);
    return c/dot(c,luminance)*dot(constantSH,luminance);
}
float3 GF2Normal(float2 encoded,float3 normal,float3 tangent,float3 bitangent)
{
    // Original does not reconstruct sqrt(1-x*x-y*y), and flips green.
    float2 xy=encoded*float2(2,-2)+float2(-1,1);
    return normalize(normal+tangent*xy.x+bitangent*xy.y);
}
// Caller supplies the source texture/sampler so the library also works from a
// Shader Graph Custom Function. Row centres are source-verified, not artistic.
float3 GF2DiffuseRamp(TEXTURE2D_PARAM(ramp,rampSampler),float nl,float row,bool enabled,bool mainLight)
{
    nl=max(nl,0);
    if(!enabled)return nl.xxx;
    float x=max(nl*0.9999,0.00006103515625);
    float3 c=SAMPLE_TEXTURE2D_LOD(ramp,rampSampler,float2(x,row),0).rgb;
    // Main light keeps the first texel at N.L=0; additional lights do not.
    return mainLight && x<=0.00006103515625 ? c : c*min(nl/x,1);
}
float3 GF2MainBRDF(TEXTURE2D_PARAM(ramp,rampSampler),bool useRamp,
    float3 baseColor,float rough,float metal,float3 N,float3 V,float3 L,out float3 specular)
{
    float3 H=normalize(V+L+1e-12);
    float nh=max(dot(N,H),0),nl=max(dot(N,L),0),vh=max(dot(V,H),0);
    float nv=min(max(dot(N,V),0)+0.00001,1);
    float3 f0=baseColor*metal+0.04*(1-metal);
    float D=GF2Distribution(nh,rough),vis=GF2Visibility(nv,nl,rough);
    float fresnel=GF2FresnelFactor(vh,f0);
    float3 lobe=(D*vis*fresnel).xxx;
    if(useRamp)
    {
        float peakD=GF2Distribution(1,rough);
        float peakV=GF2Visibility(vh,max(dot(L,H),0),rough);
        float x=saturate(D*vis/max(peakD*peakV,1e-12));
        lobe=SAMPLE_TEXTURE2D_LOD(ramp,rampSampler,float2(x,0.375),0).rgb*peakD*peakV*fresnel;
    }
    float3 diffuseRamp=GF2DiffuseRamp(TEXTURE2D_ARGS(ramp,rampSampler),nl,0.125,useRamp,true);
    specular=f0*clamp(lobe,0,10)*diffuseRamp;
    return baseColor*(1-metal)*diffuseRamp+specular;
}
float3 GF2EnvironmentBRDF(TEXTURE2D_PARAM(ramp,rampSampler),bool useRamp,
    float3 f0,float rough,float3 N,float3 V,float3 L,float3 cameraRight)
{
    float2 ab=GF2EnvironmentAB(rough,max(dot(N,V),0));
    float b=ab.y;
    if(useRamp)
    {
        // A deterministic zero-light-side guard replaces normalize(0) only.
        float side=dot(cameraRight,L);float3 oriented=side==0?0:normalize(cameraRight)*sign(side);
        b=SAMPLE_TEXTURE2D_LOD(ramp,rampSampler,float2(ab.y*saturate(dot(N,oriented)),0.625),0).r;
    }
    return f0*ab.x+b;
}
#endif
