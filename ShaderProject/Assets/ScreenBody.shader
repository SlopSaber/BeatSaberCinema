Shader "Cinema/ScreenBody"
{
    Properties { _Color ("Color", Color) = (0,0,0,1) }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass
        {
            Tags { "LightMode"="SRPDefaultUnlit" }
            Cull Back
            ZWrite On
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ CINEMA_STEREO_INSTANCING CINEMA_STEREO_MULTIVIEW CINEMA_STEREO_DOUBLE_WIDE
            #if defined(CINEMA_STEREO_INSTANCING)
                #define STEREO_INSTANCING_ON
            #elif defined(CINEMA_STEREO_MULTIVIEW)
                #define STEREO_MULTIVIEW_ON
            #elif defined(CINEMA_STEREO_DOUBLE_WIDE)
                #define UNITY_SINGLE_PASS_STEREO
            #endif
            #include "UnityCG.cginc"
            float4 _Color;
            struct Attributes { float4 vertex : POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 vertex : SV_POSITION; UNITY_VERTEX_OUTPUT_STEREO };
            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_OUTPUT(Varyings, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.vertex = UnityObjectToClipPos(input.vertex);
                return output;
            }
            float4 Frag(Varyings input) : SV_Target { return float4(_Color.rgb, 1); }
            ENDHLSL
        }
    }
}
