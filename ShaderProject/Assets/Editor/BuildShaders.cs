using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering;

public static class BuildShaders
{
    public static void Build()
    {
        var paths = new[] { "Assets/VideoShader.shader", "Assets/ScreenBody.shader" };
        var settings = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset")[0]);
        var included = settings.FindProperty("m_AlwaysIncludedShaders");
        included.arraySize = paths.Length;
        for (var i = 0; i < paths.Length; i++)
            included.GetArrayElementAtIndex(i).objectReferenceValue = AssetDatabase.LoadAssetAtPath<Shader>(paths[i]);
        settings.ApplyModifiedPropertiesWithoutUndo();
        AssetDatabase.SaveAssets();
        var output = Path.GetFullPath("Build");
        Directory.CreateDirectory(output);
        var manifest = BuildPipeline.BuildAssetBundles(output, new[]
        {
            new AssetBundleBuild
            {
                assetBundleName = "bscinema.bundle",
                assetNames = paths
            }
        }, BuildAssetBundleOptions.ForceRebuildAssetBundle | BuildAssetBundleOptions.ChunkBasedCompression,
           BuildTarget.StandaloneWindows64);
        if (manifest == null) throw new InvalidOperationException("Cinema shader bundle build failed.");
        foreach (var path in paths)
        {
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(path);
            foreach (var message in ShaderUtil.GetShaderMessages(shader))
            {
                if (message.severity == ShaderCompilerMessageSeverity.Error)
                    throw new InvalidOperationException(message.message);
            }
        }
        File.Copy(Path.Combine(output, "bscinema.bundle"), Path.GetFullPath("../BeatSaberCinema/Resources/bscinema.bundle"), true);
        Debug.Log("Cinema shader bundle built successfully.");
    }
}


public sealed class CinemaShaderBuildLog : IPreprocessShaders
{
    public int callbackOrder => int.MaxValue;
    public void OnProcessShader(Shader shader, ShaderSnippetData snippet, System.Collections.Generic.IList<ShaderCompilerData> data)
    {
        if (shader.name != "VideoShader" && shader.name != "Cinema/ScreenBody") return;
        foreach (var variant in data)
            Debug.Log("Cinema shader variant: " + shader.name + " / " + snippet.passName + " / " + snippet.shaderType + " / " +
                string.Join(" ", variant.shaderKeywordSet.GetShaderKeywords().Select(keyword => keyword.name)));
    }
}
