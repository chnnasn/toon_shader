using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace WuchangStudy.Editor
{
    public static class WuchangStudyBuilder
    {
        private const string Root = "Assets/Studies/WuchangStudy";
        private const string ScenePath = Root + "/Scenes/WuchangShowcase.unity";

        [MenuItem("Tools/Studies/Wuchang/Build Showcase")]
        public static void Build()
        {
            Scene current = SceneManager.GetActiveScene();
            if (current.isDirty)
                throw new InvalidOperationException("Save the current scene before building the study.");

            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(Root + "/Shaders/WuchangSurface.shadergraph");
            if (!shader || ShaderUtil.ShaderHasError(shader))
                throw new InvalidOperationException("The character Shader Graph must compile before building.");

            foreach (string folder in new[] { "Scenes", "Materials", "Prefabs", "Rendering" })
                Directory.CreateDirectory(Root + "/" + folder);
            ConfigureTextures();
            AssetDatabase.Refresh();

            JArray manifest = JArray.Parse(File.ReadAllText("Tools/AetherGazer/material_bindings.json"));
            Dictionary<string, Material> materials = CreateMaterials(shader, manifest);
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(.72f, .77f, .84f);
            RenderSettings.fog = true;
            RenderSettings.fogColor = new Color(.64f, .70f, .77f);
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogStartDistance = 5.0f;
            RenderSettings.fogEndDistance = 12.0f;

            var report = new JObject();
            var roots = new List<GameObject>();
            roots.Add(CreateCharacter("105401", -.62f, materials, report));
            roots.Add(CreateCharacter("614801", .62f, materials, report));

            GameObject lightObject = new GameObject("Study Key Light");
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.05f;
            light.color = new Color(1f, .93f, .90f);
            light.shadows = LightShadows.Soft;
            light.shadowStrength = .32f;
            light.shadowBias = .035f;
            light.transform.rotation = Quaternion.Euler(34, -32, 0);

            GameObject cameraObject = new GameObject("Study Camera");
            Camera camera = cameraObject.AddComponent<Camera>();
            cameraObject.tag = "MainCamera";
            camera.transform.position = new Vector3(0, .94f, -4.5f);
            camera.transform.LookAt(new Vector3(0, .84f, 0));
            camera.fieldOfView = 29;
            camera.nearClipPlane = .03f;
            camera.farClipPlane = 50;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(.64f, .70f, .77f);
            camera.allowHDR = true;
            cameraObject.AddComponent<AudioListener>();
            var cameraData = cameraObject.AddComponent<UniversalAdditionalCameraData>();
            cameraData.renderPostProcessing = false;
            cameraData.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;

            string floorMaterialPath = Root + "/Rendering/WuchangFloor.mat";
            Material floorMaterial = AssetDatabase.LoadAssetAtPath<Material>(floorMaterialPath);
            if (!floorMaterial)
            {
                floorMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(floorMaterial, floorMaterialPath);
            }
            floorMaterial.SetColor("_BaseColor", new Color(.52f, .58f, .65f));
            floorMaterial.SetFloat("_Smoothness", .08f);
            floorMaterial.SetFloat("_Metallic", 0);
            EditorUtility.SetDirty(floorMaterial);
            GameObject floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
            floor.name = "Study Floor";
            floor.transform.position = new Vector3(0, -.012f, 0);
            floor.transform.localScale = new Vector3(2.2f, 1, 2.2f);
            Renderer floorRenderer = floor.GetComponent<Renderer>();
            floorRenderer.sharedMaterial = floorMaterial;
            floorRenderer.shadowCastingMode = ShadowCastingMode.Off;
            floorRenderer.receiveShadows = true;

            var rig = new GameObject("Study Lighting").AddComponent<WuchangLighting>();
            rig.keyLight = light;
            rig.studyCamera = camera;
            rig.surfaces = roots.SelectMany(r => r.GetComponentsInChildren<Renderer>(true)).ToArray();

            foreach (GameObject root in roots)
                PrefabUtility.SaveAsPrefabAsset(root, Root + "/Prefabs/" + root.name + ".prefab");
            AssetDatabase.SaveAssets();
            EditorSceneManager.SaveScene(scene, ScenePath);
            if (SceneView.lastActiveSceneView)
                SceneView.lastActiveSceneView.LookAt(new Vector3(0, .85f, 0), camera.transform.rotation, 2.4f);
            Selection.activeGameObject = rig.gameObject;
            report["scene"] = ScenePath;
            report["materials"] = materials.Count;
            report["shaderErrors"] = JArray.FromObject(ShaderUtil.GetShaderMessages(shader).Select(m => m.message));
            File.WriteAllText("Tools/AetherGazer/unity_verification.json", report.ToString());
            Debug.Log("Wuchang study built and saved. " + report.ToString(Newtonsoft.Json.Formatting.None));
        }

        private static void ConfigureTextures()
        {
            foreach (string file in Directory.GetFiles(Root + "/SourceArt", "*.png", SearchOption.AllDirectories))
            {
                var importer = (TextureImporter)AssetImporter.GetAtPath(file);
                string name = Path.GetFileNameWithoutExtension(file);
                importer.textureCompression = TextureImporterCompression.Uncompressed;
                importer.maxTextureSize = 4096;
                importer.sRGBTexture = name.Contains("Base") || name.Contains("Ramp") || name.Contains("MatCap");
                importer.mipmapEnabled = !name.Contains("Ramp");
                importer.alphaSource = TextureImporterAlphaSource.FromInput;
                importer.wrapMode = name.Contains("Ramp") ? TextureWrapMode.Clamp : TextureWrapMode.Repeat;
                importer.SaveAndReimport();
            }
        }

        private static Dictionary<string, Material> CreateMaterials(Shader shader, JArray manifest)
        {
            var materials = new Dictionary<string, Material>();
            foreach (JObject entry in manifest)
            {
                string character = (string)entry["character"];
                string name = (string)entry["name"];
                string folder = Root + "/Materials/" + character;
                Directory.CreateDirectory(folder);
                string path = folder + "/" + name + ".mat";
                Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (!material)
                {
                    material = new Material(shader) { name = character + "_" + name };
                    AssetDatabase.CreateAsset(material, path);
                }
                material.shader = shader;
                string basePath = (string)entry["baseTexture"];
                string rampPath = (string)entry["rampTexture"];
                material.SetTexture("_BaseMap", string.IsNullOrEmpty(basePath)
                    ? Texture2D.whiteTexture : AssetDatabase.LoadAssetAtPath<Texture2D>(basePath));
                material.SetTexture("_RampMap", string.IsNullOrEmpty(rampPath)
                    ? Texture2D.whiteTexture : AssetDatabase.LoadAssetAtPath<Texture2D>(rampPath));
                material.SetColor("_BaseColor", Color.white);
                material.SetColor("_ShadowColor", new Color(.68f, .57f, .63f));
                material.SetVector("_ShadowRange", new Vector4(.24f, .62f, 0, 0));
                material.SetFloat("_RampStrength", string.IsNullOrEmpty(rampPath) ? 0 : .10f);
                material.SetFloat("_RampRow", .95f);
                material.SetFloat("_SpecStrength", name.StartsWith("hair") ? .10f : .025f);
                material.SetFloat("_RimStrength", .035f);
                material.SetFloat("_Opacity", 1);
                material.SetColor("_StockingCenterColor", Color.white);
                material.SetColor("_StockingFalloffColor", Color.white);
                material.SetFloat("_StockingStrength", 0);

                // Reconstructed directly from the original character Uber Shader bindings.
                string sourceFolder = Root + "/SourceArt/" + character + "/";
                Texture2D neutral = Texture2D.whiteTexture;
                Texture2D hairMask = AssetDatabase.LoadAssetAtPath<Texture2D>(sourceFolder + "hair01_Mask.png");
                Texture2D stockingNormal = AssetDatabase.LoadAssetAtPath<Texture2D>(
                    Root + "/SourceArt/Shared/siwa_normal_-1239529226200203676.png");
                Texture2D faceSdf = AssetDatabase.LoadAssetAtPath<Texture2D>(
                    Root + "/SourceArt/Shared/SDF_04_shaonv_2031671160802195033.png");
                Texture2D rmk = AssetDatabase.LoadAssetAtPath<Texture2D>(sourceFolder + name + "_RMK.png");
                material.SetTexture("_HairMaskMap", hairMask ? hairMask : neutral);
                material.SetFloat("_HairMaskStrength", name.StartsWith("hair") ? 1f : 0f);
                material.SetTexture("_StockingNormalMap", stockingNormal ? stockingNormal : neutral);
                material.SetFloat("_StockingPatternStrength",
                    name == "body02" || name == "body03" ? .20f : 0f);
                material.SetVector("_StockingTiling", new Vector4(10f, 620.16f, 0f, 0f));
                material.SetTexture("_FaceSDFMap", faceSdf ? faceSdf : neutral);
                material.SetFloat("_FaceSDFStrength", name == "face01" ? .08f : 0f);
                material.SetColor("_FaceShadowTint", new Color(.90f, .82f, .84f, 1f));
                material.SetTexture("_RMKMap", rmk ? rmk : neutral);
                material.SetFloat("_RMKOcclusionStrength", rmk ? .18f : 0f);

                bool transparent = (int)entry["surface"] == 2;
                if (name == "body01")
                {
                    material.SetColor("_ShadowColor", new Color(.89f, .80f, .82f));
                    material.SetVector("_ShadowRange", new Vector4(.12f, .60f, 0, 0));
                    material.SetFloat("_RampStrength", string.IsNullOrEmpty(rampPath) ? 0 : .14f);
                    material.SetFloat("_SpecStrength", .022f);
                    material.SetFloat("_RimStrength", .018f);
                }
                if (name.StartsWith("hair"))
                {
                    bool darkHair = character == "105401";
                    material.SetColor("_ShadowColor", darkHair
                        ? new Color(.34f, .29f, .39f) : new Color(.72f, .74f, .83f));
                    material.SetVector("_ShadowRange", new Vector4(.16f, .58f, 0, 0));
                    material.SetFloat("_RampStrength", string.IsNullOrEmpty(rampPath) ? 0 : .22f);
                    material.SetFloat("_SpecStrength", darkHair ? .15f : .18f);
                    material.SetFloat("_RimStrength", darkHair ? .028f : .038f);
                }
                if (name == "body02")
                {
                    bool darkStocking = character == "105401";
                    transparent = false;
                    material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(basePath));
                    material.SetColor("_BaseColor", Color.white);
                    material.SetColor("_ShadowColor", darkStocking
                        ? new Color(.73f, .66f, .69f) : new Color(.92f, .87f, .89f));
                    material.SetVector("_ShadowRange", new Vector4(.12f, .58f, 0, 0));
                    material.SetFloat("_RampStrength", 0);
                    material.SetFloat("_Opacity", 1f);
                    material.SetColor("_StockingCenterColor", darkStocking
                        ? new Color(.49f, .42f, .43f) : new Color(1.05f, .98f, .99f));
                    material.SetColor("_StockingFalloffColor", darkStocking
                        ? new Color(.20f, .142f, .142f) : Color.white);
                    material.SetFloat("_StockingStrength", 1f);
                    material.SetFloat("_SpecStrength", darkStocking ? .12f : .05f);
                    material.SetFloat("_RimStrength", darkStocking ? .025f : .018f);
                }
                if (name == "body03")
                {
                    bool darkStocking = character == "105401";
                    transparent = false;
                    material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(basePath));
                    material.SetColor("_BaseColor", Color.white);
                    material.SetColor("_ShadowColor", darkStocking
                        ? new Color(.73f, .66f, .69f) : new Color(.92f, .87f, .89f));
                    material.SetVector("_ShadowRange", new Vector4(.12f, .58f, 0, 0));
                    material.SetFloat("_RampStrength", 0);
                    material.SetFloat("_Opacity", 1f);
                    material.SetColor("_StockingCenterColor", darkStocking
                        ? new Color(.49f, .42f, .43f) : new Color(1.05f, .98f, .99f));
                    material.SetColor("_StockingFalloffColor", darkStocking
                        ? new Color(.20f, .142f, .142f) : Color.white);
                    material.SetFloat("_StockingStrength", 1f);
                    material.SetFloat("_SpecStrength", darkStocking ? .10f : .04f);
                    material.SetFloat("_RimStrength", darkStocking ? .022f : .015f);
                }
                if (name == "clothes01")
                {
                    material.SetColor("_ShadowColor", new Color(.76f, .79f, .86f));
                    material.SetVector("_ShadowRange", new Vector4(.20f, .60f, 0, 0));
                    material.SetFloat("_SpecStrength", .08f);
                    material.SetFloat("_RimStrength", .04f);
                }
                if (name.Contains("face") || name.Contains("pupil") || name.Contains("eyebrow"))
                {
                    bool authoredFaceSdf = name == "face01";
                    material.SetColor("_ShadowColor", authoredFaceSdf
                        ? new Color(.975f, .94f, .945f)
                        : new Color(.90f, .81f, .81f));
                    if (authoredFaceSdf)
                        material.SetVector("_ShadowRange", new Vector4(-1f, -.05f, 0, 0));
                    material.SetFloat("_SpecStrength", 0);
                    material.SetFloat("_RimStrength", 0);
                    material.SetFloat("_RampStrength", 0);
                }
                if (name.Contains("pupil"))
                {
                    material.SetColor("_ShadowColor", Color.white);
                    material.SetVector("_ShadowRange", new Vector4(-1f, 0f, 0, 0));
                    material.SetFloat("_RampStrength", 0);
                    material.SetFloat("_SpecStrength", 0);
                    material.SetFloat("_RimStrength", 0);
                }
                if (name == "clothes02")
                {
                    material.SetColor("_ShadowColor", new Color(.82f, .82f, .88f));
                    material.SetFloat("_Opacity", .22f);
                    material.SetFloat("_SpecStrength", .24f);
                    material.SetFloat("_RimStrength", .035f);
                }
                if (name == "Pupil_highlight01")
                {
                    transparent = true;
                    material.SetFloat("_Opacity", 0f);
                    material.SetFloat("_RampStrength", 0);
                }
                material.SetFloat("_Surface", transparent ? 1 : 0);
                material.SetFloat("_Blend", 0);
                material.SetFloat("_SrcBlend", transparent ? (float)BlendMode.SrcAlpha : (float)BlendMode.One);
                material.SetFloat("_DstBlend", transparent ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
                material.SetFloat("_SrcBlendAlpha", 1);
                material.SetFloat("_DstBlendAlpha", transparent ? (float)BlendMode.OneMinusSrcAlpha : 0);
                material.SetFloat("_ZWrite", transparent ? 0 : 1);
                material.SetFloat("_Cull", (int)entry["cull"]);
                material.SetFloat("_AlphaClip", 0);
                if (transparent) material.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
                else material.DisableKeyword("_SURFACE_TYPE_TRANSPARENT");
                material.renderQueue = transparent ? 3000 : 2000;
                material.SetOverrideTag("RenderType", transparent ? "Transparent" : "Opaque");
                EditorUtility.SetDirty(material);
                materials.Add(character + "/" + name, material);
            }
            return materials;
        }

        private static GameObject CreateCharacter(string character, float x,
            Dictionary<string, Material> materials, JObject report)
        {
            string modelPath = Root + "/SourceArt/" + character + "/" + character + "ui_tpose.fbx";
            var importer = (ModelImporter)AssetImporter.GetAtPath(modelPath);
            importer.importAnimation = false;
            importer.isReadable = true;
            importer.importNormals = ModelImporterNormals.Import;
            importer.SaveAndReimport();
            GameObject model = AssetDatabase.LoadAssetAtPath<GameObject>(modelPath);
            GameObject root = (GameObject)PrefabUtility.InstantiatePrefab(model);
            root.name = "Wuchang_" + character;
            root.transform.rotation = Quaternion.Euler(0, 180, 0);
            var records = new JArray();
            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true);
            foreach (Renderer renderer in renderers)
            {
                Material[] slots = renderer.sharedMaterials;
                for (int slot = 0; slot < slots.Length; slot++)
                {
                    string original = slots[slot] ? slots[slot].name : "";
                    string key = character + "/" + original.Split('#')[0].Trim();
                    if (!materials.TryGetValue(key, out Material replacement))
                        throw new InvalidOperationException("Unmapped material " + original + " on " + renderer.name);
                    slots[slot] = replacement;
                }
                renderer.sharedMaterials = slots;
                renderer.gameObject.SetActive(renderer.name != "body02" && renderer.name != "Texiao_Aixin");
                renderer.shadowCastingMode = ShadowCastingMode.On;
                records.Add(new JObject { ["mesh"] = renderer.name,
                    ["materials"] = JArray.FromObject(slots.Select(m => m.name)) });
            }
            Bounds bounds = renderers[0].bounds;
            foreach (Renderer renderer in renderers) bounds.Encapsulate(renderer.bounds);
            float sourceHeight = bounds.size.y;
            root.transform.localScale *= 1.62f / sourceHeight;
            bounds = renderers[0].bounds;
            foreach (Renderer renderer in renderers) bounds.Encapsulate(renderer.bounds);
            root.transform.position += new Vector3(x - bounds.center.x, -bounds.min.y, -bounds.center.z);
            foreach (Animator animator in root.GetComponentsInChildren<Animator>()) animator.enabled = false;
            report[character] = new JObject { ["sourceHeight"] = sourceHeight,
                ["scale"] = root.transform.localScale.x, ["renderers"] = records,
                ["skinnedMeshes"] = root.GetComponentsInChildren<SkinnedMeshRenderer>(true).Length };
            return root;
        }

        [MenuItem("Tools/Studies/Wuchang/Render Preview")]
        public static void RenderPreview()
        {
            Camera camera = GameObject.Find("Study Camera").GetComponent<Camera>();
            var target = new RenderTexture(1600, 1200, 24, RenderTextureFormat.ARGB32);
            var image = new Texture2D(1600, 1200, TextureFormat.RGB24, false);
            RenderTexture previous = RenderTexture.active;
            RenderTexture oldTarget = camera.targetTexture;
            try
            {
                camera.targetTexture = target;
                camera.Render();
                RenderTexture.active = target;
                image.ReadPixels(new Rect(0, 0, 1600, 1200), 0, 0);
                image.Apply();
                File.WriteAllBytes("Tools/AetherGazer/WuchangPreview.png", image.EncodeToPNG());
            }
            finally
            {
                camera.targetTexture = oldTarget;
                RenderTexture.active = previous;
                UnityEngine.Object.DestroyImmediate(image);
                UnityEngine.Object.DestroyImmediate(target);
            }
        }

        [MenuItem("Tools/Studies/Wuchang/Install Original-Style Outline")]
        public static void InstallOriginalStyleOutline()
        {
            // Kept as a compatibility menu item. Outline is now a real pass of the
            // runtime multipass shader and is scheduled by the Renderer Feature.
            WuchangCustomPipelineInstaller.Install();
        }
    }
}
