using UnityEngine;
using UnityEngine.Rendering;

namespace BeatSaberCinema
{
	internal class CustomBloomPrePass : BloomPrePassNonLightPass
	{
		private Renderer _renderer = null!;
		private Mesh _mesh = null!;
		private readonly MaterialPropertyBlock _properties = new MaterialPropertyBlock();
		private static readonly int BloomStrength = Shader.PropertyToID("_BloomStrength");
		private float? _bloomIntensityConfigSetting;
		private Vector2 _screenDimensions = Vector2.one;

		private void Awake()
		{
			_executionTimeType = ExecutionTimeType.BeforeBlur;
			_renderer = GetComponent<Renderer>();
			UpdateMesh();
		}

		public void UpdateMesh() => _mesh = GetComponent<MeshFilter>().sharedMesh;
		public void UpdateScreenDimensions(float width, float height) => _screenDimensions = new Vector2(width, height);
		public void SetBloomIntensityConfigSetting(float? bloomIntensity) => _bloomIntensityConfigSetting = bloomIntensity;

		public override void Render(CommandBuffer cmd, RTHandle dest, Matrix4x4 viewMatrix, Matrix4x4 projectionMatrix)
		{
			var intensity = Mathf.Clamp(_bloomIntensityConfigSetting ?? SettingsStore.Instance.BloomIntensity / 100f, 0f, 2f);
			if (intensity == 0 || _renderer == null || !_renderer.enabled || _mesh == null || _renderer.sharedMaterial == null) return;
			var cameraPosition = viewMatrix.inverse.MultiplyPoint(Vector3.zero);
			var distance = Vector3.Distance(transform.position, cameraPosition);
			var area = Mathf.Max(0.001f, _screenDimensions.x * _screenDimensions.y);
			var boost = 0.045f * Mathf.Sqrt(Mathf.Max(0.001f, distance) / Mathf.Sqrt(area)) * Mathf.Sqrt(intensity);
			_renderer.GetPropertyBlock(_properties);
			_properties.SetFloat(BloomStrength, boost);
			CoreUtils.SetRenderTarget(cmd, dest);
			cmd.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
			cmd.DrawMesh(_mesh, transform.localToWorldMatrix, _renderer.sharedMaterial, 0, 1, _properties);
		}
	}
}
