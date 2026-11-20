Shader "Linnae Study/Overcast Sky"
{
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off ZWrite Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            float _RainAmount;
            struct Varyings { float4 positionCS : SV_POSITION; float3 direction : TEXCOORD0; };
            Varyings Vert(float3 positionOS : POSITION)
            {
                Varyings o; o.positionCS=TransformObjectToHClip(positionOS); o.direction=positionOS; return o;
            }
            float Noise(float3 p)
            {
                float3 cell=floor(p), f=frac(p);
                f=f*f*(3-2*f);
                float index=dot(cell,float3(1,57,113));
                float4 corners=index+float4(0,57,113,170);
                float4 a=frac(sin(corners)*43758.54);
                float4 b=frac(sin(corners+1)*43758.54);
                float4 x=lerp(a,b,f.x);
                return lerp(lerp(x.x,x.y,f.y),lerp(x.z,x.w,f.y),f.z);
            }
            half4 Frag(Varyings i) : SV_Target
            {
                float3 d=normalize(i.direction);
                float3 p=d*float3(3.0,8,3.0)+float3(_Time.y*.009,1.4,1.8);
                float cloud=Noise(p)*.58+Noise(p*2.05+6)*.29+Noise(p*4.2)*.13;
                float up=smoothstep(-.09,.75,d.y);
                float3 clear=lerp(float3(.73,.74,.59),float3(.19,.39,.56),up);
                float3 storm=lerp(float3(.016,.022,.042),float3(.12,.15,.23),smoothstep(.26,.76,cloud));
                float horizon=1-smoothstep(-.18,.035,d.y);
                float stormCover=smoothstep(.02,.82,_RainAmount);
                float3 sky=lerp(clear,storm,stormCover);
                return half4(lerp(sky,lerp(float3(.28,.34,.26),float3(.033,.043,.071),stormCover),horizon),1);
            }
            ENDHLSL
        }
    }
}
