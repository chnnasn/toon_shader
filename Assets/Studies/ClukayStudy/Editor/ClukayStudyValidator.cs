using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace ClukayStudy.Editor
{
    internal static class ClukayStudyValidator
    {
        const string Root = ClukayStudyBuilder.Root;
        const string RendererPath = "Assets/Settings/PC_Renderer.asset";
        static readonly string[] RuntimePasses =
        {
            "ForwardBase", "Outline", "ShadowCaster", "DepthOnly", "DepthNormalsOnly"
        };

        [MenuItem("Tools/Studies/Clukay/Validate Study Contract")]
        public static void ValidateMenu()
        {
            List<string> errors = Validate();
            if (errors.Count > 0)
                throw new InvalidOperationException("ClukayStudy contract failed:\n- " + string.Join("\n- ", errors));
            Debug.Log("ClukayStudy contract: PASS — readable teaching Graph, runtime Multipass Shader/HLSL, " +
                      "dedicated eye/source shaders, Renderer Feature, materials, and folder layout verified.");
        }

        internal static List<string> Validate()
        {
            var errors = new List<string>();
            ValidateRuntimeShader(errors);
            ValidateGunShader(errors);
            ValidateTeachingGraph(errors);
            ValidateRendererFeature(errors);
            ValidateMaterials(errors);
            ValidateSourceModel(errors);
            ValidateLayout(errors);
            return errors;
        }

        static void ValidateGunShader(List<string> errors)
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(ClukayStudyBuilder.GunShaderPath);
            if (!shader) { errors.Add("Dedicated Summer416 shader is missing."); return; }
            if (!shader.isSupported || ShaderUtil.ShaderHasError(shader))
                errors.Add("Dedicated Summer416 shader has import or compile errors.");
            Material opaque = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/Summer416_Opaque.mat");
            Material transparent = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/Summer416_Transparent.mat");
            if (!opaque || opaque.shader != shader) errors.Add("Summer416 opaque material does not use the gun shader.");
            if (!transparent || transparent.shader != shader) errors.Add("Summer416 transparent material does not use the gun shader.");
            if (opaque && opaque.renderQueue != (int)UnityEngine.Rendering.RenderQueue.Geometry)
                errors.Add("Summer416 opaque material is not in the Geometry queue.");
            if (transparent && transparent.renderQueue != (int)UnityEngine.Rendering.RenderQueue.Transparent)
                errors.Add("Summer416 transparent material is not in the Transparent queue.");
            if (transparent && transparent.GetTag("RenderType", false) != "Transparent")
                errors.Add("Summer416 transparent material is missing its RenderType tag.");
        }

        static void ValidateRuntimeShader(List<string> errors)
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(ClukayStudyBuilder.RuntimeShaderPath);
            if (!shader) { errors.Add("Runtime character shader is missing."); return; }
            if (!shader.isSupported) errors.Add("Runtime character shader is unsupported.");
            using var material = new DisposableMaterial(shader);
            for (int i = 0; i < RuntimePasses.Length; i++)
            {
                if (i >= material.Value.passCount || material.Value.GetPassName(i) != RuntimePasses[i])
                    errors.Add($"Runtime pass {i} must be {RuntimePasses[i]}.");
                else if (!material.Value.SetPass(i))
                    errors.Add($"Runtime pass {RuntimePasses[i]} failed Material.SetPass.");
            }
            if (!File.Exists(Root + "/Shaders/ClukayCharacterCommon.hlsl"))
                errors.Add("Runtime HLSL include is missing.");
        }

        static void ValidateTeachingGraph(List<string> errors)
        {
            string path = ClukayStudyBuilder.TeachingGraphPath;
            Shader graph = AssetDatabase.LoadAssetAtPath<Shader>(path);
            if (!graph) { errors.Add("Teaching Graph failed to import as a Shader."); return; }
            string source = File.ReadAllText(path);
            if (source.Contains("CustomFunctionNode", StringComparison.Ordinal))
                errors.Add("Teaching Graph contains a Custom Function node.");
            string[] groups =
            {
                "01 Texture Sampling, Normal & Alpha", "02 Toon Diffuse & Source Ramp",
                "03 Rim / View Edge", "04 Specular & RMO Masks", "05 Hair Anisotropy",
                "06 Stocking / Sheer Fabric", "07 Face Softening & Final Combine",
            };
            foreach (string group in groups)
                if (!source.Contains("\"m_Title\": \"" + group + "\"", StringComparison.Ordinal))
                    errors.Add("Teaching Graph is missing group: " + group);
            if (!source.Contains("Face data boundary", StringComparison.Ordinal) ||
                !source.Contains("Multipass boundary", StringComparison.Ordinal))
                errors.Add("Teaching Graph is missing explanatory sticky notes.");
            string[] graphs = Directory.GetFiles(Root, "*.shadergraph", SearchOption.AllDirectories);
            if (graphs.Length != 1 || graphs[0].Replace('\\', '/') != path)
                errors.Add("ClukayStudy must expose exactly one Shader Graph teaching entry.");
        }

        static void ValidateRendererFeature(List<string> errors)
        {
            UniversalRendererData data = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
            ClukayRenderFeature[] features = data ? data.rendererFeatures.OfType<ClukayRenderFeature>().ToArray() : Array.Empty<ClukayRenderFeature>();
            if (features.Length != 1) errors.Add($"Expected one ClukayRenderFeature, found {features.Length}.");
            else if (!features[0].isActive) errors.Add("ClukayRenderFeature is disabled.");
        }

        static void ValidateMaterials(List<string> errors)
        {
            Shader runtime = AssetDatabase.LoadAssetAtPath<Shader>(ClukayStudyBuilder.RuntimeShaderPath);
            foreach (string guid in AssetDatabase.FindAssets("t:Material", new[] { Root + "/Materials" }))
            {
                string materialPath = AssetDatabase.GUIDToAssetPath(guid).Replace('\\', '/');
                Material material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
                if (!material || !material.shader) { errors.Add("Missing shader on material " + materialPath); continue; }
                string shaderPath = AssetDatabase.GetAssetPath(material.shader).Replace('\\', '/');
                if (shaderPath.StartsWith(Root, StringComparison.Ordinal) && shaderPath.EndsWith(".shadergraph", StringComparison.OrdinalIgnoreCase))
                    errors.Add("Runtime material still references a Shader Graph: " + material.name);
                if (material.shader == runtime && ShaderUtil.ShaderHasError(material.shader))
                    errors.Add("Runtime shader has errors on material: " + material.name);
                if (materialPath.StartsWith(Root + "/Materials/", StringComparison.Ordinal) &&
                    material.HasProperty("_Surface") && material.GetFloat("_Surface") > .5f)
                {
                    if (material.renderQueue < (int)UnityEngine.Rendering.RenderQueue.Transparent)
                        errors.Add("Transparent material is outside the Transparent queue: " + material.name);
                    if (material.GetTag("RenderType", false) != "Transparent")
                        errors.Add("Transparent material is missing its RenderType tag: " + material.name);
                    if (material.GetFloat("_ZWrite") > .5f)
                        errors.Add("Transparent material writes depth: " + material.name);
                }
            }
        }

        static void ValidateSourceModel(List<string> errors)
        {
            const string sourcePath = Root + "/SourceArt/ClukayMaid.fbx";
            ModelImporter importer = AssetImporter.GetAtPath(sourcePath) as ModelImporter;
            if (!importer) { errors.Add("Clukay source FBX importer is missing."); return; }
            if (importer.materialImportMode != ModelImporterMaterialImportMode.None)
                errors.Add("Clukay source FBX still imports legacy materials.");
            foreach (var pair in importer.GetExternalObjectMap())
            {
                string targetPath = pair.Value ? AssetDatabase.GetAssetPath(pair.Value).Replace('\\', '/') : string.Empty;
                if (targetPath.StartsWith(Root + "/Archive/", StringComparison.Ordinal))
                    errors.Add("Clukay source FBX still remaps a material into Archive: " + pair.Key.name);
            }
        }

        static void ValidateLayout(List<string> errors)
        {
            string[] required = { "Editor", "Materials", "OriginalShader", "Prefabs", "Rendering", "Scenes", "Scripts", "Shaders", "SourceArt" };
            foreach (string folder in required)
                if (!AssetDatabase.IsValidFolder(Root + "/" + folder)) errors.Add("Missing study folder: " + folder);
            string[] obsolete = { "Hybrid", "Recovered", "Wardrobe", "Models", "Weapons" };
            foreach (string folder in obsolete)
                if (AssetDatabase.IsValidFolder(Root + "/" + folder)) errors.Add("Obsolete root folder remains: " + folder);
            if (!AssetDatabase.LoadAssetAtPath<Shader>(Root + "/Shaders/RecoveredEyeBlend.shader"))
                errors.Add("Dedicated eye blend shader is missing.");
            if (!AssetDatabase.LoadAssetAtPath<Shader>(Root + "/OriginalShader/GF2SourceBaseline.shader"))
                errors.Add("Source baseline adapter is missing from OriginalShader.");
        }

        sealed class DisposableMaterial : IDisposable
        {
            internal readonly Material Value;
            internal DisposableMaterial(Shader shader) => Value = new Material(shader);
            public void Dispose() => UnityEngine.Object.DestroyImmediate(Value);
        }
    }
}
