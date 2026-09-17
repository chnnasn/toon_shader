using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class AnkeOpaqueFabric
{
    [MenuItem("Tools/Anke Study/Apply Opaque Fabric")]
    public static void Apply()
    {
        const string folder = "Assets/Studies/AnkeStudy/Materials/Outfit2";
        Directory.CreateDirectory("Tools/AnkeOpaqueFabric/Backup");
        int count = 0;
        foreach (var guid in AssetDatabase.FindAssets("t:Material", new[] { folder }))
        {
            var path = AssetDatabase.GUIDToAssetPath(guid);
            if (!path.Contains("Babydoll")) continue;
            var backup = "Tools/AnkeOpaqueFabric/Backup/" + Path.GetFileName(path);
            if (!File.Exists(backup)) File.Copy(path, backup);
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            Undo.RecordObject(material, "Restore opaque fabric shading");
            material.DisableKeyword("_ALPHAMODE_BLEND");
            material.SetFloat("_AlphaMode", 0);
            material.SetFloat("_BaseAlpha", 1);
            material.SetFloat("_SrcBlend", (float)BlendMode.One);
            material.SetFloat("_DstBlend", (float)BlendMode.Zero);
            material.SetFloat("_ZWrite", 1);
            material.SetFloat("_Ink", 0);
            material.SetFloat("_Roughness", .8f);
            material.SetFloat("_SpecularStrength", .12f);
            material.SetColor("_Tint", new Color(1.7f, 1.6f, 1.65f, 1));
            material.SetOverrideTag("RenderType", "TransparentCutout");
            material.renderQueue = (int)RenderQueue.AlphaTest;
            EditorUtility.SetDirty(material);
            count++;
        }
        AssetDatabase.SaveAssets();
        foreach (var pipeline in Object.FindObjectsByType<LinnaeCharacterPipeline>(FindObjectsSortMode.None)) pipeline.Rebuild();
        SceneView.RepaintAll();
        File.WriteAllText("Tools/AnkeOpaqueFabric/report.txt", "Updated fabric materials: " + count + "\nOpaque blend, depth writing on, ink off; original lace masks retained.\n");
        var controls = Object.FindAnyObjectByType<LinnaeStudyControls>();
        if (!controls) return;
        var camera = controls.GetComponent<Camera>();
        var previous = RenderTexture.active;
        var rt = RenderTexture.GetTemporary(1000, 1000, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        var image = new Texture2D(1000, 1000, TextureFormat.RGB24, false);
        try
        {
            RenderPipeline.SubmitRenderRequest(camera, new UniversalRenderPipeline.SingleCameraRequest { destination = rt });
            RenderTexture.active = rt;
            image.ReadPixels(new Rect(0, 0, 1000, 1000), 0, 0);
            image.Apply();
            File.WriteAllBytes("Tools/AnkeOpaqueFabric/result.png", image.EncodeToPNG());
        }
        finally { RenderTexture.active = previous; RenderTexture.ReleaseTemporary(rt); Object.DestroyImmediate(image); }
    }
}

