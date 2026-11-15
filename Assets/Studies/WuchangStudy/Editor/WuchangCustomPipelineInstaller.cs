using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace WuchangStudy.Editor
{
    public static class WuchangCustomPipelineInstaller
    {
        const string Root = "Assets/Studies/WuchangStudy";
        const string ShaderPath = Root + "/Shaders/WuchangCharacter.shader";
        const string RendererPath = "Assets/Settings/PC_Renderer.asset";

        [MenuItem("Tools/Studies/Wuchang/Install Original Pass Pipeline")]
        public static void Install()
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(ShaderPath);
            if (!shader || ShaderUtil.ShaderHasError(shader))
                throw new InvalidOperationException("WuchangCharacter.shader must compile before installation.");

            ConfigureMaterials(shader);
            InstallRendererFeature();
            InstallController();
            AssetDatabase.SaveAssets();
            EditorSceneManager.SaveScene(SceneManager.GetActiveScene());
            Debug.Log("Wuchang original-style multi-pass pipeline installed: PreDepth, reversible stencil hair/face shadow, and planar Reflection.");
        }

        static void ConfigureMaterials(Shader shader)
        {
            foreach (string character in new[] { "105401", "614801" })
            {
                string folder = Root + "/Materials/" + character;
                foreach (string guid in AssetDatabase.FindAssets("t:Material", new[] { folder }))
                {
                    string path = AssetDatabase.GUIDToAssetPath(guid);
                    Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                    string name = Path.GetFileNameWithoutExtension(path);
                    material.shader = shader;
                    bool face = name == "face01";
                    bool mainHair = name == "hair01";
                    bool bangs = name == "hair01_bangs";
                    bool hair = mainHair || bangs;
                    bool eye = name.Contains("pupil", StringComparison.OrdinalIgnoreCase) || name == "eyebrow01";
                    bool stocking = name == "body02" || name == "body03";
                    bool transparent = name == "clothes02" || name == "Pupil_highlight01";

                    material.SetFloat("_StencilComp", (float)CompareFunction.Always);
                    material.SetFloat("_StencilOp", (float)StencilOp.Keep);
                    material.SetFloat("_StencilRefC", 206f);
                    material.SetFloat("_WriteMask", 255f);
                    material.SetFloat("_UseFringeShadowCaster", bangs ? 1f : 0f);
                    material.SetFloat("_UseFringeShadowReceiver", face ? 1f : 0f);
                    material.SetFloat("_StencilRefShadowCaster", 200f);
                    material.SetFloat("_StencilRefShadowReceiver", 201f);
                    material.SetFloat("_AlphaClip", hair || eye ? 1f : 0f);
                    material.SetFloat("_Cutoff", hair ? 0.08f : 0.01f);

                    if (face)
                    {
                        material.SetFloat("_StencilRefC", 200f);
                        material.SetFloat("_StencilOp", (float)StencilOp.Replace);
                        material.SetFloat("_Cull", (float)CullMode.Back);
                        material.SetFloat("_FaceSDFStrength", 0.20f);
                        material.SetFloat("_FaceSDFSoftness", 0.045f);
                        material.SetColor("_FaceShadowTint", new Color(0.98f, 0.94f, 0.95f, 1f));
                    }
                    else if (mainHair)
                    {
                        material.SetFloat("_StencilRefC", 203f);
                        material.SetFloat("_StencilOp", (float)StencilOp.Replace);
                        material.SetFloat("_Cull", (float)CullMode.Off);
                    }
                    else if (bangs)
                    {
                        material.SetFloat("_StencilRefC", 204f);
                        material.SetFloat("_StencilComp", (float)CompareFunction.NotEqual);
                        material.SetFloat("_StencilOp", (float)StencilOp.Replace);
                        material.SetFloat("_WriteMask", 248f);
                        material.SetFloat("_Cull", (float)CullMode.Off);
                        material.SetFloat("_HairShadowOffsetX", character == "614801" ? 0.010f : -0.010f);
                        material.SetFloat("_HairShadowOffsetY", character == "614801" ? 0.0070f : 0.00574f);
                    }
                    else if (eye)
                    {
                        material.SetFloat("_StencilRefC", 204f);
                        material.SetFloat("_StencilOp", (float)StencilOp.Replace);
                        material.SetFloat("_Cull", (float)CullMode.Back);
                    }
                    else if (stocking)
                    {
                        material.SetFloat("_StencilRefC", 200f);
                        material.SetFloat("_StencilOp", (float)StencilOp.Replace);
                        material.SetFloat("_Cull", (float)CullMode.Back);
                        material.SetFloat("_Opacity", 1f);
                        bool darkStocking = character == "105401";
                        material.SetColor("_StockingCenterColor", darkStocking
                            ? new Color(1f, 0.9816667f, 0.98f, 1f)
                            : new Color(1f, 0.872f, 0.872f, 1f));
                        material.SetColor("_StockingFalloffColor", darkStocking
                            ? new Color(0.2f, 0.1418f, 0.1418f, 1f)
                            : Color.white);
                        material.SetFloat("_StockingStrength", 1f);
                        material.SetFloat("_StockingInt", darkStocking ? 0.49f : 2.89f);
                        material.SetFloat("_StockingNormalIntensity", 0.2f);
                        material.SetColor("_StockingAbsorptionColor", darkStocking
                            ? new Color(0.72f, 0.56f, 0.58f, 1f)
                            : Color.white);
                        material.SetFloat("_StockingBaseLift", darkStocking ? 0f : 0.72f);
                    }

                    material.SetShaderPassEnabled("CharHairShadow", bangs);
                    material.SetShaderPassEnabled("CharFaceShadow", face);
                    material.SetShaderPassEnabled("CharHairTransE", bangs);
                    material.SetShaderPassEnabled("PreDepth", !transparent);
                    material.SetShaderPassEnabled("Reflection", !transparent);

                    material.SetFloat("_SrcBlend", transparent ? (float)BlendMode.SrcAlpha : (float)BlendMode.One);
                    material.SetFloat("_DstBlend", transparent ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
                    material.SetFloat("_BlendAlphaSrc", (float)BlendMode.One);
                    material.SetFloat("_BlendAlphaDst", transparent ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
                    material.SetFloat("_ZWrite", transparent ? 0f : 1f);
                    material.renderQueue = transparent ? (int)RenderQueue.Transparent : (int)RenderQueue.Geometry;
                    material.SetOverrideTag("RenderType", transparent ? "Transparent" : "Opaque");
                    EditorUtility.SetDirty(material);
                }
            }
        }

        static void InstallRendererFeature()
        {
            UniversalRendererData rendererData = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
            if (!rendererData)
                throw new InvalidOperationException("URP renderer data not found at " + RendererPath);
            WuchangCharacterRenderFeature feature = rendererData.rendererFeatures
                .OfType<WuchangCharacterRenderFeature>().FirstOrDefault();
            if (!feature)
            {
                feature = ScriptableObject.CreateInstance<WuchangCharacterRenderFeature>();
                feature.name = "Wuchang Original Character Passes";
                AssetDatabase.AddObjectToAsset(feature, rendererData);
                rendererData.rendererFeatures.Add(feature);
            }
            feature.SetActive(true);
            feature.Create();
            EditorUtility.SetDirty(feature);
            EditorUtility.SetDirty(rendererData);
        }

        static void InstallController()
        {
            GameObject owner = GameObject.Find("Wuchang Custom Pipeline");
            if (!owner)
                owner = new GameObject("Wuchang Custom Pipeline");
            WuchangCharacterPipeline pipeline = owner.GetComponent<WuchangCharacterPipeline>();
            if (!pipeline)
                pipeline = owner.AddComponent<WuchangCharacterPipeline>();
            WuchangLighting lighting = UnityEngine.Object.FindAnyObjectByType<WuchangLighting>();
            pipeline.surfaces = lighting ? lighting.surfaces : UnityEngine.Object.FindObjectsByType<Renderer>(FindObjectsSortMode.None);
            pipeline.keyLight = lighting ? lighting.keyLight : UnityEngine.Object.FindAnyObjectByType<Light>();
            pipeline.studyCamera = lighting ? lighting.studyCamera : Camera.main;
            GameObject head = GameObject.Find("Wuchang_105401");
            pipeline.headReference = head ? head.transform : null;
            pipeline.reflectionPlaneY = 0f;
            pipeline.preDepth = true;
            pipeline.stencilHairShadow = true;
            pipeline.reflection = true;
            pipeline.reflectionStrength = 0.08f;
            pipeline.Rebuild();
            EditorUtility.SetDirty(pipeline);
        }
    }
}
