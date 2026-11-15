Shader "AetherGazer/Brahma Wujian/Studio Sky"
{
    Properties
    {
        _Top("Top", Color) = (.43,.49,.56,1)
        _Horizon("Horizon", Color) = (.65,.69,.71,1)
        _Bottom("Bottom", Color) = (.28,.34,.43,1)
    }
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
            CBUFFER_START(UnityPerMaterial)
            half4 _Top, _Horizon, _Bottom;
            CBUFFER_END
            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 direction : TEXCOORD0; };
            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.direction = input.positionOS.xyz;
                return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                float elevation = normalize(input.direction).y;
                half3 color = lerp(_Horizon.rgb, _Top.rgb, smoothstep(0, .48, elevation));
                color = lerp(color, _Bottom.rgb, smoothstep(0, .3, -elevation));
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
