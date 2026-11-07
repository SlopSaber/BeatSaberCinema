Shader "VideoShader"
{
    Properties
    {
        _MainTex ("Video", 2D) = "black" {}
        _Color ("Color", Color) = (1,1,1,0)
        _Hue ("Hue", Float) = 0
        _Brightness ("Brightness", Float) = 1
        _Contrast ("Contrast", Float) = 1
        _Saturation ("Saturation", Float) = 1
        _Exposure ("Exposure", Float) = 1
        _Gamma ("Gamma", Float) = 1
        _VignetteRadius ("Vignette radius", Float) = 1
        _VignetteSoftness ("Vignette softness", Float) = 0.005
        _VignetteOval ("Elliptical vignette", Float) = 0
        _SrcColor ("Source color blend", Float) = 1
        _DestColor ("Destination color blend", Float) = 0
        _SrcAlpha ("Source alpha blend", Float) = 0
        _DestAlpha ("Destination alpha blend", Float) = 1
        _BloomStrength ("Bloom strength", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
        Cull Back
        ZWrite Off

        HLSLINCLUDE
        // Explicit variants keep XR paths in standalone shader AssetBundles.
        #if defined(CINEMA_STEREO_INSTANCING)
            #define STEREO_INSTANCING_ON
        #elif defined(CINEMA_STEREO_MULTIVIEW)
            #define STEREO_MULTIVIEW_ON
        #elif defined(CINEMA_STEREO_DOUBLE_WIDE)
            #define UNITY_SINGLE_PASS_STEREO
        #endif
        #include "UnityCG.cginc"
        sampler2D _CinemaVideoTexture;
        float4 _MainTex_ST, _Color;
        float _Hue, _Brightness, _Contrast, _Saturation, _Exposure, _Gamma;
        float _VignetteRadius, _VignetteSoftness, _VignetteOval, _BloomStrength;

        struct Attributes
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };
        struct Varyings
        {
            float4 vertex : SV_POSITION;
            float2 uv : TEXCOORD0;
            UNITY_VERTEX_OUTPUT_STEREO
        };
        Varyings Vert(Attributes input)
        {
            Varyings output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_OUTPUT(Varyings, output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            output.vertex = UnityObjectToClipPos(input.vertex);
            output.uv = TRANSFORM_TEX(input.uv, _MainTex);
            return output;
        }
        float4 VideoColor(float2 uv)
        {
            float3 color = tex2D(_CinemaVideoTexture, uv).rgb;
            float angle = radians(_Hue);
            float3 axis = normalize(float3(1,1,1));
            color = color * cos(angle) + cross(axis, color) * sin(angle) + axis * dot(axis, color) * (1 - cos(angle));
            float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
            color = lerp(luminance.xxx, color, _Saturation);
            color = (color - 0.5) * _Contrast + 0.5;
            color = pow(max(0, color * _Brightness * _Exposure), rcp(max(0.001, _Gamma)));
            float2 position = abs(uv * 2 - 1);
            float edge = _VignetteOval > 0.5 ? length(position) : max(position.x, position.y);
            float mask = 1 - smoothstep(_VignetteRadius, _VignetteRadius + max(0.0001, _VignetteSoftness), edge);
            return float4(color * _Color.rgb * mask, _Color.a * mask);
        }
        float4 Frag(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            return VideoColor(input.uv);
        }
        float4 FragBloom(Varyings input) : SV_Target
        {
            return float4(VideoColor(input.uv).rgb * _BloomStrength, 0);
        }
        ENDHLSL

        Pass
        {
            Name "Video"
            Tags { "LightMode"="SRPDefaultUnlit" }
            Blend [_SrcColor] [_DestColor], [_SrcAlpha] [_DestAlpha]
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ CINEMA_STEREO_INSTANCING CINEMA_STEREO_MULTIVIEW CINEMA_STEREO_DOUBLE_WIDE
            ENDHLSL
        }
        Pass
        {
            Name "Bloom"
            Tags { "LightMode"="CinemaBloom" }
            Blend One One
            ZTest Always
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment FragBloom
            ENDHLSL
        }
    }
}
