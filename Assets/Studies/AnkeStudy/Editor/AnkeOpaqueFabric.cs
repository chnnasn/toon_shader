using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class AnkeOpaqueFabric
{
    private static readonly string[] HosieryMaterials =
    {
        "Assets/Studies/AnkeStudy/Materials/m020_KK_cf_m_panst_01_9564.mat",
        "Assets/Studies/AnkeStudy/Materials/Outfit2/m023_KK_ztoki_socks_02_00_ma_9296.mat"
    };

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
        foreach (var pipeline in Object.FindObjectsByType<LinnaeCharacterPipeline>(FindObjectsInactive.Exclude)) pipeline.Rebuild();
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

    [MenuItem("Tools/Anke Study/Repair Hosiery Transparency")]
    public static void RepairHosieryTransparency()
    {
        Directory.CreateDirectory("Tools/AnkeHosieryTransparency/Backup");

        foreach (var path in HosieryMaterials)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material) throw new FileNotFoundException("Hosiery material is missing", path);

            var backup = "Tools/AnkeHosieryTransparency/Backup/" + Path.GetFileName(path);
            if (!File.Exists(backup)) File.Copy(path, backup);

            Undo.RecordObject(material, "Repair hosiery transparency");
            var uniformHosiery = path.Contains("m023_KK_ztoki_socks");
            material.EnableKeyword("_ALPHAMODE_BLEND");
            material.SetFloat("_AlphaMode", 1);
            material.SetFloat("_BaseAlpha", uniformHosiery ? .32f : 1f);
            material.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
            material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
            material.SetFloat("_ZTest", (float)CompareFunction.LessEqual);
            material.SetFloat("_ZWrite", 0);
            material.SetFloat("_Cull", (float)CullMode.Back);
            material.SetFloat("_Ink", 0);
            if (uniformHosiery)
            {
                // The generated m023 maps do not match this mesh's UV islands and
                // create large triangle-shaped opacity/color blocks. Shader defaults
                // are white, so null maps produce a stable, evenly tinted sheer layer.
                material.SetTexture("_LightBase", null);
                material.SetTexture("_DarkBase", null);
                material.SetTexture("_Opacity", null);
                material.SetColor("_Tint", new Color(.86f, .84f, .92f, 1f));
                material.SetColor("_SkinTint", Color.white);
                material.SetColor("_ShadowTint", new Color(.88f, .86f, .94f, 1f));
                material.SetFloat("_Roughness", .72f);
                material.SetFloat("_SpecularStrength", .12f);
            }
            material.SetOverrideTag("RenderType", "Transparent");
            material.renderQueue = (int)RenderQueue.Transparent;
            EditorUtility.SetDirty(material);
        }

        AssetDatabase.SaveAssets();
        SceneView.RepaintAll();
        File.WriteAllText(
            "Tools/AnkeHosieryTransparency/report.txt",
            "Updated hosiery materials: " + HosieryMaterials.Length +
            "\nAlpha blend, back-face culling, no depth write or ink; m023 uses uniform sheer shading because its generated maps do not match the mesh UVs.\n");
    }

    [MenuItem("Tools/Anke Study/Validate Hosiery Transparency")]
    public static void ValidateHosieryTransparency()
    {
        foreach (var path in HosieryMaterials)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material) throw new FileNotFoundException("Hosiery material is missing", path);
            if (!material.IsKeywordEnabled("_ALPHAMODE_BLEND") ||
                material.GetFloat("_AlphaMode") != 1 ||
                !Mathf.Approximately(material.GetFloat("_BaseAlpha"), path.Contains("m023_KK_ztoki_socks") ? .32f : 1f) ||
                material.GetFloat("_SrcBlend") != (float)BlendMode.SrcAlpha ||
                material.GetFloat("_DstBlend") != (float)BlendMode.OneMinusSrcAlpha ||
                material.GetFloat("_ZWrite") != 0 ||
                material.GetFloat("_Cull") != (float)CullMode.Back ||
                material.GetFloat("_Ink") != 0 ||
                (path.Contains("m023_KK_ztoki_socks") &&
                 (material.GetTexture("_LightBase") || material.GetTexture("_DarkBase") || material.GetTexture("_Opacity"))) ||
                material.renderQueue != (int)RenderQueue.Transparent)
                throw new System.Exception("Invalid hosiery transparency settings: " + path);
        }

        Debug.Log("Anke hosiery transparency validation passed for " + HosieryMaterials.Length + " materials.");
    }
}

