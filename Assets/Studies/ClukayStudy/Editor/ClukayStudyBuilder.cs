using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ClukayStudy.Editor
{
    internal static class ClukayStudyBuilder
    {
        internal const string Root = "Assets/Studies/ClukayStudy";
        internal const string ScenePath = Root + "/Scenes/ClukayShowcase.unity";
        internal const string RuntimeShaderPath = Root + "/Shaders/ClukayCharacter.shader";
        internal const string GunShaderPath = Root + "/Shaders/ClukayGun.shader";
        internal const string TeachingGraphPath = Root + "/Shaders/ClukaySurface.shadergraph";
        const string RendererPath = "Assets/Settings/PC_Renderer.asset";
        const string SourceModelPath = Root + "/SourceArt/ClukayMaid.fbx";

        [MenuItem("Tools/Studies/Clukay/Apply Brahma-style Study Layout")]
        public static void ApplyStudyLayout()
        {
            Shader runtimeShader = AssetDatabase.LoadAssetAtPath<Shader>(RuntimeShaderPath);
            if (!runtimeShader) throw new InvalidOperationException("Runtime shader is missing: " + RuntimeShaderPath);
            if (!AssetDatabase.LoadAssetAtPath<Shader>(TeachingGraphPath))
                throw new InvalidOperationException("Teaching graph is missing or failed to import: " + TeachingGraphPath);

            MigrateMaterials(runtimeShader);
            InstallRendererFeature();
            MoveStudyAssets();
            ConfigureTransparentMaterials();
            ConfigureGunMaterials();
            ArchiveSupersededShaders();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("ClukayStudy layout applied: one teaching graph, one runtime character Multipass Shader, " +
                      "one runtime HLSL include, dedicated eye/source shaders, and Brahma-style folders.");
        }

        [MenuItem("Tools/Studies/Clukay/Open Showcase")]
        public static void OpenShowcase()
        {
            if (EditorSceneManager.GetActiveScene().path == ScenePath) return;
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            EditorSceneManager.OpenScene(ScenePath);
        }

        [MenuItem("Tools/Studies/Clukay/Render Preview")]
        public static void RenderPreview()
        {
            Capture(".tmp/ClukayPreview.png");
        }

        [MenuItem("Tools/Studies/Clukay/Apply Summer416 Materials")]
        public static void ApplySummer416Materials()
        {
            ConfigureGunMaterials();
            AssetDatabase.SaveAssets();
            Debug.Log("Summer416 materials calibrated: dedicated gun shading plus explicit opaque/transparent render states.");
        }

        [MenuItem("Tools/Studies/Clukay/Repair Transparent Wardrobe Materials")]
        public static void RepairTransparentWardrobeMaterials()
        {
            ConfigureTransparentMaterials();
            AssetDatabase.SaveAssets();
            Debug.Log("Clukay transparent wardrobe materials repaired: Transparent queue, blend, depth and pass states applied.");
        }

        [MenuItem("Tools/Studies/Clukay/Detach Source FBX Legacy Materials")]
        public static void DetachSourceFbxLegacyMaterials()
        {
            ModelImporter importer = AssetImporter.GetAtPath(SourceModelPath) as ModelImporter;
            if (!importer) throw new InvalidOperationException("Clukay source FBX importer is missing: " + SourceModelPath);

            int removed = 0;
            foreach (var pair in importer.GetExternalObjectMap().ToArray())
            {
                string targetPath = pair.Value ? AssetDatabase.GetAssetPath(pair.Value).Replace('\\', '/') : string.Empty;
                if (!targetPath.StartsWith(Root + "/Archive/", StringComparison.Ordinal)) continue;
                importer.RemoveRemap(pair.Key);
                removed++;
            }
            importer.materialImportMode = ModelImporterMaterialImportMode.None;
            importer.SaveAndReimport();
            Debug.Log($"Clukay source FBX detached from {removed} legacy material remaps; material import is disabled.");
        }

        [MenuItem("Tools/Studies/Clukay/Render Summer416 Close-up")]
        public static void RenderSummer416Closeup()
        {
            OpenShowcase();
            if (EditorSceneManager.GetActiveScene().path != ScenePath) return;
            var wardrobe = UnityEngine.Object.FindAnyObjectByType<ClukayWardrobe>();
            if (!wardrobe || !wardrobe.viewCamera || !wardrobe.weapon)
                throw new InvalidOperationException("Clukay showcase weapon or camera is missing.");

            Camera camera = wardrobe.viewCamera;
            bool wasActive = wardrobe.weapon.activeSelf;
            Vector3 position = camera.transform.position;
            Quaternion rotation = camera.transform.rotation;
            float fieldOfView = camera.fieldOfView;
            wardrobe.weapon.SetActive(true);
            Renderer[] renderers = wardrobe.weapon.GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0) throw new InvalidOperationException("Summer416 has no renderers.");
            Bounds bounds = renderers[0].bounds;
            foreach (Renderer renderer in renderers.Skip(1)) bounds.Encapsulate(renderer.bounds);
            try
            {
                camera.fieldOfView = 24;
                float vertical = bounds.size.y / (2 * Mathf.Tan(camera.fieldOfView * .5f * Mathf.Deg2Rad));
                float horizontalFov = 2 * Mathf.Atan(Mathf.Tan(camera.fieldOfView * .5f * Mathf.Deg2Rad) * (16f / 9f));
                float horizontal = bounds.size.x / (2 * Mathf.Tan(horizontalFov * .5f));
                Vector3 forward = camera.transform.forward;
                camera.transform.SetPositionAndRotation(bounds.center - forward * Mathf.Max(vertical, horizontal) * 1.12f,
                    Quaternion.LookRotation(forward, Vector3.up));
                Capture(".tmp/ClukayGunPreview.png");
            }
            finally
            {
                camera.transform.SetPositionAndRotation(position, rotation);
                camera.fieldOfView = fieldOfView;
                wardrobe.weapon.SetActive(wasActive);
            }
        }

        [MenuItem("Tools/Studies/Clukay/Render P3 Skirt Close-up")]
        public static void RenderP3SkirtCloseup()
        {
            OpenShowcase();
            if (EditorSceneManager.GetActiveScene().path != ScenePath) return;
            var wardrobe = UnityEngine.Object.FindAnyObjectByType<ClukayWardrobe>();
            if (!wardrobe || !wardrobe.viewCamera || wardrobe.skirts == null || wardrobe.skirts.Length < 3)
                throw new InvalidOperationException("Clukay P3 skirt or camera is missing.");

            Camera camera = wardrobe.viewCamera;
            int oldTop = wardrobe.top, oldSkirt = wardrobe.skirt, oldLeg = wardrobe.leg;
            float oldYaw = wardrobe.pivot ? wardrobe.pivot.localEulerAngles.y : 180;
            Vector3 position = camera.transform.position;
            Quaternion rotation = camera.transform.rotation;
            float fieldOfView = camera.fieldOfView;
            wardrobe.Apply(oldTop, 2, oldLeg);
            wardrobe.SetYaw(0);
            Renderer[] renderers = wardrobe.skirts[2].GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0) throw new InvalidOperationException("Clukay P3 skirt has no renderers.");
            Bounds bounds = renderers[0].bounds;
            foreach (Renderer renderer in renderers.Skip(1)) bounds.Encapsulate(renderer.bounds);
            try
            {
                camera.fieldOfView = 28;
                float vertical = bounds.size.y / (2 * Mathf.Tan(camera.fieldOfView * .5f * Mathf.Deg2Rad));
                float horizontalFov = 2 * Mathf.Atan(Mathf.Tan(camera.fieldOfView * .5f * Mathf.Deg2Rad) * (16f / 9f));
                float horizontal = bounds.size.x / (2 * Mathf.Tan(horizontalFov * .5f));
                Vector3 forward = camera.transform.forward;
                camera.transform.SetPositionAndRotation(bounds.center - forward * Mathf.Max(vertical, horizontal) * 1.45f,
                    Quaternion.LookRotation(forward, Vector3.up));
                Capture(".tmp/ClukayP3SkirtPreview.png");
            }
            finally
            {
                camera.transform.SetPositionAndRotation(position, rotation);
                camera.fieldOfView = fieldOfView;
                wardrobe.Apply(oldTop, oldSkirt, oldLeg);
                wardrobe.SetYaw(oldYaw);
            }
        }

        static void Capture(string path)
        {
            OpenShowcase();
            if (EditorSceneManager.GetActiveScene().path != ScenePath) return;
            var wardrobe = UnityEngine.Object.FindAnyObjectByType<ClukayWardrobe>();
            if (!wardrobe || !wardrobe.viewCamera)
                throw new InvalidOperationException("Clukay showcase camera is missing.");
            Camera camera = wardrobe.viewCamera;
            RenderTexture previousTarget = camera.targetTexture;
            RenderTexture previousActive = RenderTexture.active;
            float previousAspect = camera.aspect;
            var target = new RenderTexture(1600, 900, 24, RenderTextureFormat.ARGBHalf);
            var image = new Texture2D(1600, 900, TextureFormat.RGB24, false);
            try
            {
                camera.targetTexture = target;
                camera.aspect = 1600f / 900f;
                camera.Render();
                RenderTexture.active = target;
                image.ReadPixels(new Rect(0, 0, 1600, 900), 0, 0);
                image.Apply();
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                File.WriteAllBytes(path, image.EncodeToPNG());
            }
            finally
            {
                camera.targetTexture = previousTarget;
                camera.aspect = previousAspect;
                RenderTexture.active = previousActive;
                UnityEngine.Object.DestroyImmediate(image);
                target.Release();
                UnityEngine.Object.DestroyImmediate(target);
            }
            Debug.Log("Clukay preview saved to " + Path.GetFullPath(path));
        }

        static void MigrateMaterials(Shader runtimeShader)
        {
            foreach (string guid in AssetDatabase.FindAssets("t:Material", new[] { Root }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (!material || !material.shader) continue;
                string shaderPath = AssetDatabase.GetAssetPath(material.shader).Replace('\\', '/');
                if (!shaderPath.StartsWith(Root, StringComparison.Ordinal) ||
                    !shaderPath.EndsWith(".shadergraph", StringComparison.OrdinalIgnoreCase)) continue;

                bool outline = shaderPath.EndsWith("ClukayOutline.shadergraph", StringComparison.OrdinalIgnoreCase);
                bool legacy = shaderPath.EndsWith("ClukayToon.shadergraph", StringComparison.OrdinalIgnoreCase);
                material.shader = runtimeShader;
                material.SetFloat("_OutlineOnly", outline ? 1 : 0);
                material.SetFloat("_LegacyLighting", legacy ? 1 : 0);
                if (material.GetFloat("_Cutoff") <= 0) material.SetFloat("_Cutoff", .33f);
                EditorUtility.SetDirty(material);
            }
        }

        static void ConfigureGunMaterials()
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(GunShaderPath);
            if (!shader) throw new InvalidOperationException("Summer416 shader is missing: " + GunShaderPath);
            Material opaque = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/Summer416_Opaque.mat");
            Material transparent = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/Summer416_Transparent.mat");
            if (!opaque || !transparent) throw new InvalidOperationException("Summer416 materials are missing from Materials.");

            ConfigureGunMaterial(opaque, shader, false);
            ConfigureGunMaterial(transparent, shader, true);
        }

        static void ConfigureTransparentMaterials()
        {
            foreach (string guid in AssetDatabase.FindAssets("t:Material", new[] { Root + "/Materials" }))
            {
                Material material = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid));
                if (!material || !material.HasProperty("_Surface") || material.GetFloat("_Surface") < .5f) continue;
                material.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
                material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
                material.SetFloat("_SrcBlendAlpha", (float)BlendMode.One);
                material.SetFloat("_DstBlendAlpha", (float)BlendMode.OneMinusSrcAlpha);
                material.SetFloat("_ZWrite", 0);
                material.SetFloat("_CastShadows", 0);
                material.renderQueue = (int)RenderQueue.Transparent +
                    (material.name.EndsWith("_dt_trans", StringComparison.OrdinalIgnoreCase) ? 1 : 0);
                material.SetOverrideTag("RenderType", "Transparent");
                material.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
                material.SetShaderPassEnabled("ShadowCaster", false);
                material.SetShaderPassEnabled("DepthOnly", false);
                material.SetShaderPassEnabled("DepthNormalsOnly", false);
                EditorUtility.SetDirty(material);
            }
        }

        static void ConfigureGunMaterial(Material material, Shader shader, bool transparent)
        {
            material.shader = shader;
            material.SetColor("_Tint", Color.white);
            material.SetFloat("_NormalStrength", 1);
            material.SetFloat("_UseRMO", 1);
            material.SetFloat("_RoughnessScale", 1);
            material.SetFloat("_MetallicScale", 1);
            material.SetFloat("_OcclusionStrength", .65f);
            material.SetFloat("_SpecularStrength", .35f);
            material.SetFloat("_AmbientStrength", 1.05f);
            material.SetFloat("_DirectStrength", .45f);
            material.SetFloat("_ShadowFloor", .75f);
            material.SetFloat("_EnvironmentStrength", .12f);
            // The recovered atlas stores the water-toy shell in a translucent submesh.
            // Keeping it at full material opacity hides the dark receiver visible in the reference.
            material.SetFloat("_Opacity", transparent ? .24f : 1f);
            material.SetFloat("_AlphaClip", 0);
            material.SetFloat("_Cull", (float)CullMode.Back);
            material.SetFloat("_ZTest", (float)CompareFunction.LessEqual);
            material.SetFloat("_SrcBlendAlpha", (float)BlendMode.One);
            material.SetFloat("_DstBlendAlpha", transparent ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
            material.SetFloat("_CastShadows", transparent ? 0 : 1);
            material.DisableKeyword("_SURFACE_TYPE_TRANSPARENT");
            if (transparent)
            {
                material.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
                material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
                material.SetFloat("_ZWrite", 0);
                material.renderQueue = (int)RenderQueue.Transparent;
                material.SetOverrideTag("RenderType", "Transparent");
                material.SetShaderPassEnabled("ShadowCaster", false);
                material.SetShaderPassEnabled("DepthOnly", false);
            }
            else
            {
                material.SetFloat("_SrcBlend", (float)BlendMode.One);
                material.SetFloat("_DstBlend", (float)BlendMode.Zero);
                material.SetFloat("_ZWrite", 1);
                material.renderQueue = -1;
                material.SetOverrideTag("RenderType", "Opaque");
                material.SetShaderPassEnabled("ShadowCaster", true);
                material.SetShaderPassEnabled("DepthOnly", true);
            }
            EditorUtility.SetDirty(material);
        }

        static void InstallRendererFeature()
        {
            UniversalRendererData data = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
            if (!data) throw new InvalidOperationException("URP renderer data is missing: " + RendererPath);
            ClukayRenderFeature feature = data.rendererFeatures.OfType<ClukayRenderFeature>().FirstOrDefault();
            if (!feature)
            {
                feature = ScriptableObject.CreateInstance<ClukayRenderFeature>();
                feature.name = "Clukay Character Outline";
                AssetDatabase.AddObjectToAsset(feature, data);
                data.rendererFeatures.Add(feature);
            }
            feature.SetActive(true);
            feature.Create();
            EditorUtility.SetDirty(feature);
            EditorUtility.SetDirty(data);
        }

        static void MoveStudyAssets()
        {
            Move(Root + "/Wardrobe/Materials", Root + "/Materials");
            EnsureFolder(Root + "/SourceArt/Wardrobe");
            Move(Root + "/Wardrobe/Meshes", Root + "/SourceArt/Wardrobe/Meshes");
            EnsureFolder(Root + "/OriginalShader");
            Move(Root + "/Wardrobe/SourceBaseline", Root + "/OriginalShader/SourceBaseline");
            Move(Root + "/Wardrobe/Shaders/GF2SourceBaseline.shader", Root + "/OriginalShader/GF2SourceBaseline.shader");
            Move(Root + "/Wardrobe/Shaders/GF2SourceBRDF.hlsl", Root + "/OriginalShader/GF2SourceBRDF.hlsl");
            Move(Root + "/Wardrobe/Shaders/RecoveredEyeBlend.shader", Root + "/Shaders/RecoveredEyeBlend.shader");
            Move(Root + "/Wardrobe/UI", Root + "/Rendering/UI");
            Move(Root + "/Models/ClukayMaid.fbx", Root + "/SourceArt/ClukayMaid.fbx");
            EnsureFolder(Root + "/Prefabs");
            Move(Root + "/Weapons/Summer416.prefab", Root + "/Prefabs/Summer416.prefab");
            EnsureFolder(Root + "/SourceArt/Recovered");
            Move(Root + "/Recovered/Models", Root + "/SourceArt/Recovered/Models");
            Move(Root + "/Recovered/Textures", Root + "/SourceArt/Recovered/Textures");
            Move(Root + "/Recovered/Prefabs", Root + "/Prefabs/Recovered");
            Move(Root + "/Hybrid/Rendering/HybridVolume.asset", Root + "/Rendering/HybridVolume.asset");
            Move(Root + "/Hybrid/Rendering/StudioReflection.exr", Root + "/Rendering/StudioReflection.exr");
        }

        static void ArchiveSupersededShaders()
        {
            (string source, string destination)[] sources =
            {
                (Root + "/Shaders/ClukayToon.shadergraph", Root + "/Archive/DeprecatedShaderSources/ClukayToon.shadergraph.txt"),
                (Root + "/Shaders/ClukayOutline.shadergraph", Root + "/Archive/DeprecatedShaderSources/ClukayOutline.shadergraph.txt"),
                (Root + "/Shaders/ClukayLighting.hlsl", Root + "/Archive/DeprecatedShaderSources/ClukayLighting.hlsl.txt"),
                (Root + "/Hybrid/Shaders/ClukayHybrid.shadergraph", Root + "/Hybrid/Shaders/ClukayHybrid.shadergraph.txt"),
                (Root + "/Hybrid/Shaders/ClukayHybridLighting.hlsl", Root + "/Hybrid/Shaders/ClukayHybridLighting.hlsl.txt"),
                (Root + "/Recovered/Shaders/ClukayRecovered.shadergraph", Root + "/Recovered/Shaders/ClukayRecovered.shadergraph.txt"),
                (Root + "/Recovered/Shaders/ClukayHybridLighting.hlsl", Root + "/Recovered/Shaders/ClukayHybridLighting.hlsl.txt"),
            };
            foreach ((string source, string destination) in sources)
                Move(source, destination);

            (string source, string destination)[] folders =
            {
                (Root + "/Hybrid", Root + "/Archive/LegacyHybrid"),
                (Root + "/Recovered", Root + "/Archive/LegacyRecovered"),
                (Root + "/Wardrobe", Root + "/Archive/LegacyWardrobe"),
                (Root + "/Models", Root + "/Archive/LegacyModels"),
                (Root + "/Weapons", Root + "/Archive/LegacyWeapons"),
            };
            foreach ((string source, string destination) in folders)
                Move(source, destination);
        }

        static void Move(string source, string destination)
        {
            if (!AssetDatabase.LoadMainAssetAtPath(source) || AssetDatabase.LoadMainAssetAtPath(destination)) return;
            EnsureFolder(destination[..destination.LastIndexOf('/')]);
            string error = AssetDatabase.MoveAsset(source, destination);
            if (!string.IsNullOrEmpty(error)) throw new InvalidOperationException(error);
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            int slash = path.LastIndexOf('/');
            string parent = path[..slash];
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, path[(slash + 1)..]);
        }
    }
}
