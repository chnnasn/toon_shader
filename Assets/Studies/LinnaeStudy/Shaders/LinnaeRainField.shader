Shader "Linnae Study/Rain Field"
{
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent+20" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _RainAmount;
            struct Attributes { float3 landing : POSITION; float2 corner : TEXCOORD0; float4 seed : TEXCOORD1; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; float visibility : TEXCOORD1; float ring : TEXCOORD2; };
            Varyings Vert(Attributes v)
            {
                Varyings o;
                float phase = frac(_Time.y * lerp(.82,1.37,v.seed.x) + v.seed.y);
                float height = (1 - phase) * 3.8;
                float3 p = v.landing;
                float2 uv = v.corner;
                float enabled = smoothstep(v.seed.z-.035,v.seed.z+.035,_RainAmount) * saturate(_RainAmount*12);
                if (v.seed.w < .5)
                {
                    float3 right = UNITY_MATRIX_I_V._m00_m10_m20;
                    p += height * float3(-.075,1,-.025);
                    p += right * (uv.x * lerp(.0018,.0036,v.seed.x));
                    p += float3(-.075,1,-.025) * uv.y * lerp(.035,.083,v.seed.y);
                    o.visibility = enabled * lerp(.09,.22,v.seed.y) * smoothstep(0,.12,height);
                }
                else
                {
                    // The ring begins at the landing point just as its streak wraps.
                    float age = saturate(phase * 4);
                    p.xz += uv * lerp(.007,.047,age);
                    p.y += .002;
                    o.visibility = enabled * (1 - age) * .47;
                }
                o.positionCS = TransformObjectToHClip(p);
                o.uv = uv;
                o.ring = v.seed.w;
                return o;
            }
            half4 Frag(Varyings i) : SV_Target
            {
                float2 uv = i.uv;
                float streak = (1 - uv.x * uv.x) * saturate(1 - abs(uv.y));
                float radius = length(uv);
                float aa = clamp(fwidth(radius),.045,.35);
                float ring = 1 - smoothstep(.035,.035+aa,abs(radius-.72));
                return half4(.59,.76,1,lerp(streak,ring,i.ring)*i.visibility);
            }
            ENDHLSL
        }
    }
}
