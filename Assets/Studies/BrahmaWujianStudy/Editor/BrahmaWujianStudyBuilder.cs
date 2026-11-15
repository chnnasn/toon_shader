using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace BrahmaWujianStudy.Editor
{
    public static class BrahmaWujianStudyBuilder
    {
        const string Root = "Assets/Studies/BrahmaWujianStudy";
        const string ShaderPath = Root + "/Shaders/BrahmaCharacter.shader";
        const string GraphPath = Root + "/Shaders/BrahmaSurface.shadergraph";
        const string ScenePath = Root + "/Scenes/BrahmaWujianShowcase.unity";
        const string RendererPath = "Assets/Settings/PC_Renderer.asset";
        static readonly HashSet<string> GeneratedMaterialPaths = new(StringComparer.OrdinalIgnoreCase);

        static readonly Dictionary<string, string> SourcePrefabs = new()
        {
            ["102003"] = Root + "/SourceArt/102003/102003ui_tpose.prefab",
            ["605603"] = Root + "/SourceArt/605603/605603ui_tpose.prefab"
        };

        [MenuItem("Tools/Studies/Brahma Wujian/Build Two-Form Study")]
        public static void Build()
        {
            GeneratedMaterialPaths.Clear();
            Shader graph = AssetDatabase.LoadAssetAtPath<Shader>(GraphPath);
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(ShaderPath);
            if (!graph || ShaderUtil.ShaderHasError(graph))
                throw new InvalidOperationException("BrahmaSurface.shadergraph must compile before building.");
            if (!shader || ShaderUtil.ShaderHasError(shader))
                throw new InvalidOperationException("BrahmaCharacter.shader must compile before building.");

            EnsureFolders();
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(.70f, .76f, .84f);
            RenderSettings.fog = true;
            RenderSettings.fogColor = new Color(.72f, .77f, .83f);
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogStartDistance = 6;
            RenderSettings.fogEndDistance = 14;

            GameObject casual = CreateForm("102003", -1.0f, shader);
            GameObject companion = CreateForm("605603", 1.0f, shader);
            GameObject[] forms = { casual, companion };

            Light key = CreateDirectional("Key Light", new Color(1f, .94f, .91f), 1.18f, new Vector3(32, -34, 0));
            CreateDirectional("Fill Light", new Color(.64f, .81f, 1f), .34f, new Vector3(18, 142, 0)).shadows = LightShadows.None;

            GameObject cameraObject = new("Study Camera");
            Camera camera = cameraObject.AddComponent<Camera>();
            cameraObject.tag = "MainCamera";
            camera.transform.position = new Vector3(0, 1.02f, -6.15f);
            camera.transform.LookAt(new Vector3(0, .92f, 0));
            camera.fieldOfView = 27;
            camera.nearClipPlane = .03f;
            camera.farClipPlane = 60;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(.72f, .77f, .83f);
            camera.allowHDR = true;
            cameraObject.AddComponent<AudioListener>();
            UniversalAdditionalCameraData cameraData = cameraObject.AddComponent<UniversalAdditionalCameraData>();
            cameraData.renderPostProcessing = false;
            cameraData.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;

            Shader lit = Shader.Find("Universal Render Pipeline/Lit");
            string floorPath = Root + "/Rendering/BrahmaStudyFloor.mat";
            Material floorMaterial = AssetDatabase.LoadAssetAtPath<Material>(floorPath);
            if (!floorMaterial)
            {
                floorMaterial = new Material(lit) { name = "Brahma Study Floor" };
                AssetDatabase.CreateAsset(floorMaterial, floorPath);
            }
            floorMaterial.SetColor("_BaseColor", new Color(.56f, .63f, .71f));
            floorMaterial.SetFloat("_Smoothness", .12f);
            GameObject floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
            floor.name = "Study Floor";
            floor.transform.position = new Vector3(0, -.012f, 0);
            floor.transform.localScale = new Vector3(2.8f, 1, 2.4f);
            floor.GetComponent<Renderer>().sharedMaterial = floorMaterial;

            GameObject pipelineObject = new("Brahma Wujian Custom Pipeline");
            BrahmaWujianPipeline pipeline = pipelineObject.AddComponent<BrahmaWujianPipeline>();
            pipeline.surfaces = forms.SelectMany(f => f.GetComponentsInChildren<Renderer>(true)).ToArray();
            pipeline.studyCamera = camera;
            pipeline.headReference = FindHead(casual.transform) ?? casual.transform;
            pipeline.reflectionPlaneY = 0;
            pipeline.preDepth = pipeline.stencilHairFaceShadow = pipeline.reflection = true;
            // Keep the recovered Outline pass available, but default it off: the
            // shipped meshes contain two-sided/concave pieces that need per-mesh
            // hull-width tuning before an inverted hull is visually trustworthy.
            pipeline.outline = false;
            pipeline.hairTransmission = true;
            pipeline.Rebuild();

            InstallRendererFeature();
            BrahmaReferenceCalibration.ApplyToScene();
            foreach (GameObject form in forms)
                PrefabUtility.SaveAsPrefabAsset(form, Root + "/Prefabs/" + form.name + ".prefab");
            CleanupUnusedGeneratedMaterials();
            AssetDatabase.SaveAssets();
            EditorSceneManager.SaveScene(scene, ScenePath);
            Selection.activeGameObject = pipelineObject;
            if (SceneView.lastActiveSceneView)
                SceneView.lastActiveSceneView.LookAt(new Vector3(0, .95f, 0), camera.transform.rotation, 3.2f);
            Debug.Log($"Brahma Wujian study built: {ScenePath}; forms=2; renderers={pipeline.surfaces.Length}; " +
                      $"graph={graph.name}; multipass={shader.name}; key={key.name}");
        }

        static GameObject CreateForm(string character, float x, Shader shader)
        {
            string sourcePath = SourcePrefabs[character];
            GameObject source = AssetDatabase.LoadAssetAtPath<GameObject>(sourcePath);
            if (!source) throw new InvalidOperationException("Missing source prefab: " + sourcePath);
            GameObject root = (GameObject)PrefabUtility.InstantiatePrefab(source);
            root.name = "Brahma_Wujian_" + character;
            root.transform.rotation = Quaternion.Euler(0, 180, 0);
            if (PrefabUtility.IsPartOfPrefabInstance(root))
                PrefabUtility.UnpackPrefabInstance(root, PrefabUnpackMode.Completely, InteractionMode.AutomatedAction);

            // AssetRipper can preserve references to game-only MonoBehaviours whose
            // managed assemblies are not distributed with this study.  Strip only
            // those unresolved components from the instantiated research copy so
            // Unity can save a clean Prefab; SourceArt remains untouched.
            int strippedMissingScripts = 0;
            foreach (Transform child in root.GetComponentsInChildren<Transform>(true))
            {
                strippedMissingScripts += GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(child.gameObject);
                GameObjectUtility.RemoveMonoBehavioursWithMissingScript(child.gameObject);
            }
            if (strippedMissingScripts > 0)
                Debug.Log($"{character}: removed {strippedMissingScripts} unresolved game-only components from study copy.");
            RemoveWeaponAndUiObjects(root);
            RelinkMeshesToCleanSource(root, character);

            Dictionary<Material, Material> replacements = new();
            foreach (Renderer renderer in root.GetComponentsInChildren<Renderer>(true))
            {
                Material[] slots = renderer.sharedMaterials;
                for (int i = 0; i < slots.Length; i++)
                {
                    Material sourceMaterial = slots[i];
                    if (!sourceMaterial) continue;
                    if (!replacements.TryGetValue(sourceMaterial, out Material replacement))
                    {
                        replacement = CloneMaterial(character, sourceMaterial, shader, replacements.Count);
                        replacements[sourceMaterial] = replacement;
                    }
                    slots[i] = replacement;
                }
                renderer.sharedMaterials = slots;
                renderer.shadowCastingMode = ShadowCastingMode.On;
                renderer.receiveShadows = true;
            }

            // WuchangStudy-style clean source layer.  It contains only character
            // skeleton/meshes/textures and can survive removal of AssetRipper data.
            string cleanPrefabPath = $"{Root}/SourceArt/{character}/{character}ui_tpose.prefab";
            PrefabUtility.SaveAsPrefabAsset(root, cleanPrefabPath);

            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true).Where(r => r.enabled && r.gameObject.activeInHierarchy && r is not ParticleSystemRenderer).ToArray();
            if (renderers.Length == 0) throw new InvalidOperationException("No renderers in " + character);
            Bounds bounds = renderers[0].bounds;
            foreach (Renderer renderer in renderers.Skip(1)) bounds.Encapsulate(renderer.bounds);
            root.transform.localScale *= 1.72f / Math.Max(.001f, bounds.size.y);
            bounds = renderers[0].bounds;
            foreach (Renderer renderer in renderers.Skip(1)) bounds.Encapsulate(renderer.bounds);
            root.transform.position += new Vector3(x - bounds.center.x, -bounds.min.y, -bounds.center.z);
            foreach (Animator animator in root.GetComponentsInChildren<Animator>(true)) animator.enabled = false;
            return root;
        }

        static void RemoveWeaponAndUiObjects(GameObject root)
        {
            Transform[] nodes = root.GetComponentsInChildren<Transform>(true);
            for (int i = nodes.Length - 1; i >= 0; i--)
            {
                Transform node = nodes[i];
                if (node == root.transform) continue;
                string lower = node.name.ToLowerInvariant();
                bool weapon = lower.Contains("weapon");
                bool uiAnchor = lower.StartsWith("auto_") || lower.StartsWith("ui_") ||
                                lower == "canvas" || lower.Contains("ui_anchor");
                if (weapon || uiAnchor)
                    UnityEngine.Object.DestroyImmediate(node.gameObject);
            }
        }

        static void RelinkMeshesToCleanSource(GameObject root, string character)
        {
            string meshFolder = $"{Root}/SourceArt/{character}/Meshes";
            int ordinal = 0;
            foreach (SkinnedMeshRenderer renderer in root.GetComponentsInChildren<SkinnedMeshRenderer>(true))
                renderer.sharedMesh = DuplicateMesh(renderer.sharedMesh, meshFolder, renderer.name, ordinal++);
            foreach (MeshFilter filter in root.GetComponentsInChildren<MeshFilter>(true))
                filter.sharedMesh = DuplicateMesh(filter.sharedMesh, meshFolder, filter.name, ordinal++);
        }

        static Mesh DuplicateMesh(Mesh source, string folder, string ownerName, int ordinal)
        {
            if (!source) return null;
            string sourcePath = AssetDatabase.GetAssetPath(source);
            if (sourcePath.StartsWith(folder, StringComparison.OrdinalIgnoreCase)) return source;
            string safe = SanitizeFileName(ownerName);
            string path = $"{folder}/{ordinal:00}_{safe}.asset";
            Mesh copy = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (!copy)
            {
                copy = new Mesh { name = source.name };
                EditorUtility.CopySerialized(source, copy);
                copy.name = source.name;
                AssetDatabase.CreateAsset(copy, path);
            }
            else
            {
                EditorUtility.CopySerialized(source, copy);
                copy.name = source.name;
                EditorUtility.SetDirty(copy);
            }
            return copy;
        }

        static Material CloneMaterial(string character, Material source, Shader shader, int ordinal)
        {
            string folder = Root + "/Materials/" + character;
            string canonicalName = CanonicalMaterialName(source.name, character);
            string path = $"{folder}/{SanitizeFileName(canonicalName)}.mat";
            GeneratedMaterialPaths.Add(path);
            Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                material = new Material(source) { name = character + "_" + canonicalName };
                AssetDatabase.CreateAsset(material, path);
            }
            else if (material != source)
            {
                EditorUtility.CopySerialized(source, material);
                material.name = character + "_" + canonicalName;
            }
            material.shader = shader;
            RelinkTexturesToCleanSource(material, character);
            ConfigureMaterial(material, canonicalName, character);
            EditorUtility.SetDirty(material);
            return material;
        }

        static string CanonicalMaterialName(string value, string character)
        {
            string result = value;
            if (result.StartsWith(character + "_", StringComparison.OrdinalIgnoreCase))
                result = result[(character.Length + 1)..];
            while (true)
            {
                int underscore = result.IndexOf('_');
                if (underscore <= 0 || !result[..underscore].All(char.IsDigit)) break;
                result = result[(underscore + 1)..];
            }
            return result;
        }

        static void CleanupUnusedGeneratedMaterials()
        {
            foreach (string character in SourcePrefabs.Keys)
            {
                string folder = Root + "/Materials/" + character;
                foreach (string guid in AssetDatabase.FindAssets("t:Material", new[] { folder }))
                {
                    string path = AssetDatabase.GUIDToAssetPath(guid);
                    if (!GeneratedMaterialPaths.Contains(path)) AssetDatabase.DeleteAsset(path);
                }
            }
        }

        static void RelinkTexturesToCleanSource(Material material, string character)
        {
            string folder = $"{Root}/SourceArt/{character}";
            foreach (string property in material.GetTexturePropertyNames())
            {
                Texture source = material.GetTexture(property);
                if (!source) continue;
                string sourcePath = AssetDatabase.GetAssetPath(source);
                if (string.IsNullOrEmpty(sourcePath) || sourcePath.StartsWith(folder, StringComparison.OrdinalIgnoreCase))
                    continue;
                if (!sourcePath.StartsWith(Root + "/SourceArt/AssetBundles", StringComparison.OrdinalIgnoreCase))
                    continue;
                string extension = Path.GetExtension(sourcePath);
                string guid = AssetDatabase.AssetPathToGUID(sourcePath);
                string shortGuid = guid.Length >= 8 ? guid[..8] : guid;
                string destination = $"{folder}/{SanitizeFileName(source.name)}_{shortGuid}{extension}";
                if (!AssetDatabase.LoadAssetAtPath<Texture>(destination) && !AssetDatabase.CopyAsset(sourcePath, destination))
                    throw new InvalidOperationException("Failed to copy texture to clean SourceArt: " + sourcePath);
                Texture copy = AssetDatabase.LoadAssetAtPath<Texture>(destination);
                material.SetTexture(property, copy);
            }
        }

        static string SanitizeFileName(string value) =>
            string.Concat(value.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));

        internal static void ConfigureMaterial(Material material, string sourceName, string character)
        {
            string name = sourceName.ToLowerInvariant();
            bool face = name == "face01" || name.StartsWith("face01#");
            bool bangs = name.Contains("hair01_bangs");
            bool hair = name.Contains("hair01") || name == "hair" || bangs;
            bool eye = name.Contains("pupil") || name.Contains("eyes") || name.Contains("eyebrow");
            bool stocking = name.Contains("siwa") || name.Contains("stocking");
            bool darkStocking = name.Contains("black");
            bool effect = name.StartsWith("fx_") || name.Contains("texiao");
            bool fur = name.Contains("fur") || (character == "605603" && (name == "clothes02" || name == "clothes03")) ||
                (character == "102003" && (name == "body03" || name == "body04"));
            bool lens = character == "605603" && name == "clothes01";
            bool bodySurface = name.StartsWith("body", StringComparison.Ordinal);
            // These mesh effects are translucent in the game shader.  Looking up
            // _CharacterSurface after replacing that shader always returned false,
            // causing opaque white cards to cover the authored blue hair gradient.
            bool highlight = name.Contains("highlight");
            bool transparent = effect || lens || highlight;
            if (name == "pupil01" && material.GetTexture("_MainTex"))
                material.SetTexture("_BaseMap", material.GetTexture("_MainTex"));
            if (highlight)
                material.SetTexture("_EffectMask", material.GetTexture("_MaskTex"));
            material.SetFloat("_EyeHighlightMode", highlight ? 1 : 0);

            if (effect)
            {
                Texture primary = material.GetTexture("_MainTex");
                if (!primary) primary = material.GetTexture("_Tex");
                if (!primary) primary = material.GetTexture("_MainPlusTex");
                if (primary) material.SetTexture("_BaseMap", primary);

                Color authored = material.GetColor("_Color");
                float peak = Mathf.Max(authored.r, Mathf.Max(authored.g, authored.b));
                if (peak > .001f)
                {
                    Color hue = authored / peak;
                    hue.a = authored.a > .001f ? authored.a : 1f;
                    material.SetColor("_BaseColor", Color.Lerp(Color.white, hue, .7f));
                }
            }

            material.SetColor("_StudyShadowTint", face ? new Color(.81f, .66f, .69f, 1) :
                hair ? new Color(.55f, .70f, .79f, 1) : new Color(.64f, .67f, .75f, 1));
            material.SetColor("_StudyHairTint", hair ?
                new Color(1.025f, 1.035f, 1.035f, 1) : Color.white);
            material.SetColor("_HairAnisotropyColor", new Color(.83f, .96f, 1, 1));
            material.SetColor("_StudyEdgeTint", hair ? new Color(.18f, .30f, .67f, 1) : new Color(.32f, .28f, .34f, 1));
            material.SetFloat("_FaceMode", face ? 1 : 0);
            material.SetFloat("_HairMode", hair ? 1 : 0);
            material.SetFloat("_EyeMode", eye ? 1 : 0);
            material.SetFloat("_FurMode", fur ? 1 : 0);
            material.SetFloat("_EffectMode", name.Contains("hair_texiao1") ? 2 : effect ? 1 : 0);
            material.SetFloat("_UseStockingFalloff", stocking ? 1 : 0);
            material.SetFloat("_UseAlphaTest", hair || eye || effect || face ? 1 : 0);
            material.SetFloat("_Cutoff", hair ? .035f : effect ? .004f : .02f);
            material.SetFloat("_StudyRampWeight", face || eye ? 0 : hair ? .025f : .06f);
            material.SetFloat("_StudySpecularWeight", face ? .025f : hair ? .34f : stocking ? .65f : .16f);
            material.SetFloat("_StudyRimWeight", hair ? .055f : .025f);
            material.SetFloat("_StudyLightFloor", .62f);
            material.SetFloat("_StudyShadowStrength", face ? .15f : .75f);
            material.SetFloat("_StudyNormalWeight", face ? 0 : hair ? .70f : .85f);
            material.SetFloat("_StudyOpacity", lens ? .48f : effect ? .3f : 1f);
            material.SetFloat("_StudySparkle", hair ? 1.2f : 0f);
            material.SetFloat("_StudyProceduralSparkle", hair ? 1f : 0f);
            material.SetFloat("_StudyHairSaturation", hair ? 1.06f : 1f);
            material.SetFloat("_StudyHairTipBoost", hair ? .65f : 0f);
            material.SetFloat("_StudyEdgeStrength", fur ? 0 : hair ? .10f : .025f);
            material.SetFloat("_StudySkinLift", face ? .12f : bodySurface && !stocking ? 1f : 0f);
            material.SetFloat("_StudyEnvironmentWeight", lens ? .5f : stocking ? .32f : hair ? .08f : .18f);
            material.SetFloat("_LensMode", lens ? 1 : 0);
            material.SetFloat("_FurLength", character == "605603" && name == "clothes03" ? .012f : .009f);
            material.SetFloat("_FurDensity", character == "605603" && name == "clothes03" ? 850 : 1200);
            material.SetFloat("_FurBend", .4f);
            material.SetFloat("_FabricMode", character == "605603" && bodySurface && !stocking ? 1 : 0);
            material.SetFloat("_BodyAtlasMode", character == "605603" && bodySurface ? 1 : 0);
            material.SetFloat("_RampCount", 3);
            if (character == "605603" && (name == "body01" || name.StartsWith("clothes")))
                material.SetFloat("_NormalScale", 1f);
            if (character == "605603" && name == "body01")
                material.SetColor("_BaseColor", new Color(1.02f, 1.02f, 1.025f, 1f));
            if (!effect) material.SetColor("_BaseColor", Color.white);
            if (lens)
                material.SetColor("_BaseColor", new Color(.08f, .78f, .72f, 1f));
            if (hair || face || bodySurface) material.SetColor("_BaseColor", Color.white);
            if (character == "102003" && name == "body01")
            {
                material.SetColor("_EmissiveColor", new Color(.04f, .82f, .88f, 1));
                material.SetFloat("_EmissiveIntensity", .24f);
            }
            material.SetFloat("_OutlineWidth", hair ? .65f : .75f);
            material.SetFloat("_OutlineIntensity", eye || effect || fur ? 0f : 1f);
            material.SetFloat("_OutlineZBias", .00001f);
            material.SetVector("_Tiling", stocking ? new Vector4(10, 620.16f, 0, 0) : new Vector4(1, 1, 0, 0));
            if (stocking)
            {
                material.SetColor("_StockingCenterColor", darkStocking ? new Color(.74f, .68f, .70f, 1) : new Color(1.05f, .98f, 1f, 1));
                material.SetColor("_StockingFalloffColor", darkStocking ? new Color(.08f, .065f, .075f, 1) : new Color(.92f, .80f, .83f, 1));
                material.SetFloat("_StockingInt", darkStocking ? 1.6f : 2.89f);
                material.SetFloat("_StockingNormalIntensity", .2f);
            }

            material.SetFloat("_StencilComp", (float)CompareFunction.Always);
            material.SetFloat("_StencilOp", (float)StencilOp.Keep);
            material.SetFloat("_StencilRefC", 206);
            material.SetFloat("_WriteMask", 255);
            material.SetFloat("_StencilRefShadowCaster", 200);
            material.SetFloat("_StencilRefShadowReceiver", 201);
            material.SetFloat("_UseFringeShadowCaster", bangs ? 1 : 0);
            material.SetFloat("_UseFringeShadowReceiver", face ? 1 : 0);
            material.SetFloat("_UseHairTranE", bangs ? 1 : 0);
            material.SetFloat("_HairTranEAlpha", bangs ? .35f : 0);
            material.SetFloat("_HairShadowX", bangs ? .0037f : 0);
            material.SetFloat("_HairShadowY", bangs ? .00778f : 0);
            material.SetFloat("_Cull", hair ? (float)CullMode.Off : (float)CullMode.Back);

            if (face || stocking)
            {
                material.SetFloat("_StencilRefC", 200);
                material.SetFloat("_StencilOp", (float)StencilOp.Replace);
            }
            else if (bangs)
            {
                material.SetFloat("_StencilRefC", 204);
                material.SetFloat("_StencilComp", (float)CompareFunction.NotEqual);
                material.SetFloat("_StencilOp", (float)StencilOp.Replace);
                material.SetFloat("_WriteMask", 248);
            }
            else if (hair)
            {
                material.SetFloat("_StencilRefC", 203);
                material.SetFloat("_StencilOp", (float)StencilOp.Replace);
            }
            else if (eye)
            {
                material.SetFloat("_StencilRefC", 204);
                material.SetFloat("_StencilOp", (float)StencilOp.Replace);
            }

            material.SetShaderPassEnabled("Outline", !eye && !effect && !transparent && !hair && !fur);
            material.SetShaderPassEnabled("CharHairShadow", bangs);
            material.SetShaderPassEnabled("CharFaceShadow", face);
            material.SetShaderPassEnabled("CharHairTransE", bangs);
            material.SetShaderPassEnabled("PreDepth", !transparent && !bangs);
            material.SetShaderPassEnabled("Reflection", !transparent && !effect);
            material.SetShaderPassEnabled("ShadowCaster", !transparent && !eye);
            material.SetShaderPassEnabled("FurShell", fur);
            material.SetFloat("_SrcBlend", transparent ? (float)BlendMode.SrcAlpha : (float)BlendMode.One);
            material.SetFloat("_DstBlend", transparent ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
            material.SetFloat("_BlendAlphaSrc", (float)BlendMode.One);
            material.SetFloat("_BlendAlphaDst", transparent ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
            material.SetFloat("_ZWrite", transparent ? 0 : 1);
            material.renderQueue = transparent ? (int)RenderQueue.Transparent : (int)RenderQueue.Geometry;
            material.SetOverrideTag("RenderType", transparent ? "Transparent" : "Opaque");
        }

        static void InstallRendererFeature()
        {
            UniversalRendererData data = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
            if (!data) throw new InvalidOperationException("URP renderer data not found: " + RendererPath);
            BrahmaWujianRenderFeature feature = data.rendererFeatures.OfType<BrahmaWujianRenderFeature>().FirstOrDefault();
            if (!feature)
            {
                feature = ScriptableObject.CreateInstance<BrahmaWujianRenderFeature>();
                feature.name = "Brahma Wujian Original Character Passes";
                AssetDatabase.AddObjectToAsset(feature, data);
                data.rendererFeatures.Add(feature);
            }
            feature.SetActive(true);
            feature.Create();
            EditorUtility.SetDirty(feature);
            EditorUtility.SetDirty(data);
        }

        static Transform FindHead(Transform root)
        {
            foreach (Transform child in root.GetComponentsInChildren<Transform>(true))
                if (child.name.Equals("Bip001 Head", StringComparison.OrdinalIgnoreCase)) return child;
            return null;
        }

        static Light CreateDirectional(string name, Color color, float intensity, Vector3 euler)
        {
            Light light = new GameObject(name).AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = color;
            light.intensity = intensity;
            light.shadows = LightShadows.Soft;
            light.shadowStrength = .34f;
            light.shadowBias = .035f;
            light.transform.rotation = Quaternion.Euler(euler);
            return light;
        }

        static void EnsureFolders()
        {
            EnsureFolder(Root, "Scenes"); EnsureFolder(Root, "Materials");
            EnsureFolder(Root, "Prefabs"); EnsureFolder(Root, "Rendering");
            EnsureFolder(Root + "/Materials", "102003"); EnsureFolder(Root + "/Materials", "605603");
            EnsureFolder(Root + "/SourceArt", "102003"); EnsureFolder(Root + "/SourceArt", "605603");
            EnsureFolder(Root + "/SourceArt/102003", "Meshes"); EnsureFolder(Root + "/SourceArt/605603", "Meshes");
        }

        static void EnsureFolder(string parent, string name)
        {
            string path = parent + "/" + name;
            if (!AssetDatabase.IsValidFolder(path)) AssetDatabase.CreateFolder(parent, name);
        }

        [MenuItem("Tools/Studies/Brahma Wujian/Render Preview")]
        public static void RenderPreview()
        {
            Camera camera = GameObject.Find("Study Camera")?.GetComponent<Camera>();
            if (!camera) throw new InvalidOperationException("Build or open the Brahma study scene first.");
            BrahmaReferenceCalibration.Capture(camera, "Tools/AetherGazerResearch/BrahmaWujianPreview.png", 1800, 1200);
            AssetDatabase.Refresh();
            Debug.Log("Brahma Wujian preview written to Tools/AetherGazerResearch/BrahmaWujianPreview.png");
        }

        [MenuItem("Tools/Studies/Brahma Wujian/Render Material Closeups")]
        public static void RenderMaterialCloseups()
        {
            Camera camera = GameObject.Find("Study Camera")?.GetComponent<Camera>();
            GameObject casual = GameObject.Find("Brahma_Wujian_102003");
            GameObject companion = GameObject.Find("Brahma_Wujian_605603");
            if (!camera || !casual || !companion)
                throw new InvalidOperationException("Build or open the Brahma study scene first.");

            Vector3 oldPosition = camera.transform.position;
            Quaternion oldRotation = camera.transform.rotation;
            float oldFov = camera.fieldOfView;
            bool casualActive = casual.activeSelf;
            bool companionActive = companion.activeSelf;
            try
            {
                casual.SetActive(true); companion.SetActive(false);
                RenderFramed(camera, casual, "102003_FullMaterial.png", false);
                RenderFramed(camera, casual, "102003_UpperCloseup.png", true);
                casual.SetActive(false); companion.SetActive(true);
                RenderFramed(camera, companion, "605603_FullMaterial.png", false);
                RenderFramed(camera, companion, "605603_UpperCloseup.png", true);
            }
            finally
            {
                casual.SetActive(casualActive); companion.SetActive(companionActive);
                camera.transform.SetPositionAndRotation(oldPosition, oldRotation);
                camera.fieldOfView = oldFov;
            }
            AssetDatabase.Refresh();
            Debug.Log("Brahma material closeups written to " + Root + "/Rendering");
        }

        static void RenderFramed(Camera camera, GameObject root, string fileName, bool upperBody)
        {
            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true).Where(r => r.enabled && r.gameObject.activeInHierarchy && r is not ParticleSystemRenderer).ToArray();
            Bounds bounds = renderers[0].bounds;
            foreach (Renderer renderer in renderers.Skip(1)) bounds.Encapsulate(renderer.bounds);
            camera.fieldOfView = 27f;
            float visibleHeight = upperBody ? bounds.size.y * .68f : bounds.size.y * 1.06f;
            float targetY = upperBody ? bounds.max.y - visibleHeight * .5f : bounds.center.y;
            float distance = visibleHeight * .5f / Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * .5f);
            Vector3 target = new(bounds.center.x, targetY, bounds.center.z);
            camera.transform.position = target + Vector3.back * distance;
            camera.transform.LookAt(target);

            BrahmaReferenceCalibration.Capture(camera, $"{Root}/Rendering/{fileName}", 1200, 1500);
        }
    }
}
