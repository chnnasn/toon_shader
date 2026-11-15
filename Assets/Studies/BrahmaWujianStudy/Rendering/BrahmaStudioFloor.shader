Shader "AetherGazer/Brahma Wujian/Studio Floor"
{
    Properties
    {
        _BaseColor("Floor", Color) = (.31,.37,.45,1)
        _HorizonColor("Horizon", Color) = (.82,.85,.86,1)
        _ReflectionStrength("Reflection Strength", Range(0,1)) = .12
        _ReflectionBlur("Reflection Blur (Pixels)", Range(0,12)) = 5
        _DotSpacing("Dot Spacing (Metres)", Float) = .045
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass
        {
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_BrahmaReflectionTexture); SAMPLER(sampler_BrahmaReflectionTexture);
            float4x4 _BrahmaReflectionVP;
            float4 _BrahmaReflectionTexelSize;
            float _BrahmaReflectionEnabled;
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor, _HorizonColor;
            float _ReflectionStrength, _ReflectionBlur, _DotSpacing;
            CBUFFER_END
            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 positionWS : TEXCOORD0; };
            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                half shadow = GetMainLight(TransformWorldToShadowCoord(input.positionWS)).shadowAttenuation;
                float distanceToCamera = distance(input.positionWS, _WorldSpaceCameraPos);
                half3 color = lerp(_BaseColor.rgb, _HorizonColor.rgb, smoothstep(5, 22, distanceToCamera));
                color *= lerp(.69h, 1, shadow);
                float2 grid = input.positionWS.xz / max(.001, _DotSpacing);
                float radius = length(frac(grid - .5) - .5);
                float aa = max(.01, length(fwidth(grid)));
                half dots = 1 - smoothstep(.045 - aa * .5, .045 + aa * .5, radius);
                color += dots * .05h * saturate(.12 / aa) * (1 - smoothstep(5, 14, distanceToCamera));
                float4 reflected = mul(_BrahmaReflectionVP, float4(input.positionWS, 1));
                float2 uv = reflected.xy / reflected.w * .5 + .5;
                #if UNITY_UV_STARTS_AT_TOP
                    uv.y = 1 - uv.y;
                #endif
                half4 reflection = 0;
                [unroll] for (int y = -1; y <= 1; y++)
                [unroll] for (int x = -1; x <= 1; x++)
                {
                    float2 sampleUV = uv + float2(x, y) * _BrahmaReflectionTexelSize.xy * _ReflectionBlur;
                    half4 sampleColor = SAMPLE_TEXTURE2D(_BrahmaReflectionTexture, sampler_BrahmaReflectionTexture, sampleUV);
                    reflection += half4(sampleColor.rgb * sampleColor.a, sampleColor.a) / 9;
                }
                half inBounds = step(0, uv.x) * step(uv.x, 1) * step(0, uv.y) * step(uv.y, 1) * _BrahmaReflectionEnabled;
                color = color * (1 - reflection.a * _ReflectionStrength * inBounds) + reflection.rgb * _ReflectionStrength * inBounds;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
