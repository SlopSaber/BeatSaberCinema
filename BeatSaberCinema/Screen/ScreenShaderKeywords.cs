using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.XR;

namespace BeatSaberCinema
{
	internal static class ScreenShaderKeywords
	{
		internal static void Enable() => RenderPipelineManager.beginCameraRendering += BeginCameraRendering;

		internal static void Disable()
		{
			RenderPipelineManager.beginCameraRendering -= BeginCameraRendering;
			SetKeywords(false, false, false);
		}

		private static void BeginCameraRendering(ScriptableRenderContext context, Camera camera)
		{
			var stereo = camera.stereoEnabled;
			var mode = XRSettings.stereoRenderingMode;
			SetKeywords(stereo && mode == XRSettings.StereoRenderingMode.SinglePassInstanced,
				stereo && mode == XRSettings.StereoRenderingMode.SinglePassMultiview,
				stereo && mode == XRSettings.StereoRenderingMode.SinglePass);
		}

		private static void SetKeywords(bool instanced, bool multiview, bool doubleWide)
		{
			SetKeyword("CINEMA_STEREO_INSTANCING", instanced);
			SetKeyword("CINEMA_STEREO_MULTIVIEW", multiview);
			SetKeyword("CINEMA_STEREO_DOUBLE_WIDE", doubleWide);
		}

		private static void SetKeyword(string keyword, bool enabled)
		{
			if (enabled) Shader.EnableKeyword(keyword);
			else Shader.DisableKeyword(keyword);
		}
	}
}
