using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace BrahmaWujianStudy.Editor
{
    internal static class BrahmaOriginalShaderContractValidator
    {
        const string Root = "Assets/Studies/BrahmaWujianStudy";
        const string ShaderPath = Root + "/Shaders/BrahmaCharacter.shader";
        const string ContractPath = Root + "/OriginalShader/CharacterPBRUber.PassContract.json";
        const string RendererPath = "Assets/Settings/PC_Renderer.asset";

        static readonly string[] OriginalPasses =
        {
            "ForwardBase", "Outline", "CharHairShadow", "CharFaceShadow",
            "CharHairTransE", "ShadowCaster", "Reflection", "PreDepth"
        };

        const string TeachingGraphPath = Root + "/Shaders/BrahmaSurface.shadergraph";

        [Serializable]
        sealed class Contract
        {
            public string sourceShader;
            public int propertyCount;
            public string queue;
            public PassContract[] passes;
        }

        [Serializable]
        sealed class PassContract
        {
            public int index;
            public string name;
        }

        [MenuItem("Tools/Studies/Brahma Wujian/Validate Original Shader Contract")]
        public static void ValidateMenu()
        {
            List<string> errors = Validate();
            if (errors.Count > 0)
                throw new InvalidOperationException("Brahma original shader contract failed:\n- " +
                    string.Join("\n- ", errors));
            Debug.Log("Brahma original shader contract: PASS — 8 recovered passes, readable 0-Custom-Function " +
                "teaching graph, stencil 200→201→200, Reflection/PreDepth scheduling, and URP feature verified.");
        }

        internal static List<string> Validate()
        {
            var errors = new List<string>();
            ValidateEvidence(errors);
            ValidateRuntimeShader(errors);
            ValidateGraphs(errors);
            ValidateRendererFeature(errors);
            ValidateMaterials(errors);
            return errors;
        }

        static void ValidateEvidence(List<string> errors)
        {
            TextAsset json = AssetDatabase.LoadAssetAtPath<TextAsset>(ContractPath);
            if (!json)
            {
                errors.Add("Missing pass contract: " + ContractPath);
                return;
            }
            Contract contract = JsonUtility.FromJson<Contract>(json.text);
            if (contract == null || contract.sourceShader != "SimPipeline/Character/PBR/Uber")
                errors.Add("Pass contract source shader is not SimPipeline/Character/PBR/Uber.");
            if (contract == null || contract.propertyCount != 155)
                errors.Add("Recovered property count must remain 155.");
            if (contract == null || contract.queue != "Geometry+10")
                errors.Add("Recovered queue must remain Geometry+10.");
            if (contract?.passes == null || contract.passes.Length != OriginalPasses.Length)
            {
                errors.Add("Pass contract must contain exactly eight recovered passes.");
                return;
            }
            for (int i = 0; i < OriginalPasses.Length; i++)
                if (contract.passes[i].index != i || contract.passes[i].name != OriginalPasses[i])
                    errors.Add($"Pass contract index {i} must be {OriginalPasses[i]}.");
        }

        static void ValidateRuntimeShader(List<string> errors)
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(ShaderPath);
            if (!shader)
            {
                errors.Add("Missing reconstructed multipass shader.");
                return;
            }
            if (!shader.isSupported)
                errors.Add("Reconstructed multipass shader is unsupported on the current graphics API.");
            var material = new Material(shader);
            try
            {
                for (int i = 0; i < OriginalPasses.Length; i++)
                {
                    if (i >= material.passCount || material.GetPassName(i) != OriginalPasses[i])
                        errors.Add($"Runtime shader pass {i} must be {OriginalPasses[i]}.");
                    else if (!material.SetPass(i))
                        errors.Add($"Runtime shader pass {i} ({OriginalPasses[i]}) failed Material.SetPass.");
                }
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(material);
            }

            string compact = Compact(File.ReadAllText(ShaderPath));
            Require(compact, "\"Queue\"=\"Geometry+10\"", "SubShader queue is not Geometry+10.", errors);
            Require(compact,
                "Name\"Outline\"Tags{\"LightMode\"=\"BrahmaOutline\"}BlendSrcAlphaOneMinusSrcAlpha,[_BlendAlphaSrc][_BlendAlphaDst]CullFrontZWriteOnZTestLess",
                "Outline fixed state or URP-private scheduling tag is invalid.", errors);
            Require(compact,
                "Name\"CharHairShadow\"Tags{\"LightMode\"=\"BrahmaHairShadow\"}ColorMask0ZWriteOffZTestLEqualCull[_Cull]Stencil{Ref[_StencilRefShadowCaster]ReadMask255WriteMask255CompEqualPassIncrSat}",
                "CharHairShadow state or URP-private scheduling tag is invalid.", errors);
            Require(compact,
                "Name\"CharFaceShadow\"Tags{\"LightMode\"=\"BrahmaFaceShadow\"}BlendOneZeroZWriteOffZTestLEqualCull[_Cull]Stencil{Ref[_StencilRefShadowReceiver]ReadMask255WriteMask255CompEqualPassDecrWrap}",
                "CharFaceShadow state or URP-private scheduling tag is invalid.", errors);
            Require(compact,
                "Name\"Reflection\"Tags{\"LightMode\"=\"BrahmaReflection\"}Blend[_SrcBlend][_DstBlend],[_BlendAlphaSrc][_BlendAlphaDst]ZWriteOnZTestLEqualCullFront",
                "Reflection state or URP-private scheduling tag is invalid.", errors);
            Require(compact,
                "Name\"PreDepth\"Tags{\"LightMode\"=\"BrahmaPreDepth\"}ColorMask0ZWriteOnZTestLEqualCull[_Cull]",
                "PreDepth state or URP-private scheduling tag is invalid.", errors);
        }

        static void ValidateGraphs(List<string> errors)
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(TeachingGraphPath);
            if (!shader)
                errors.Add("Teaching Shader Graph did not import as a Shader: " + TeachingGraphPath);
            else if (!shader.isSupported)
                errors.Add("Teaching Shader Graph is unsupported on this platform: " + TeachingGraphPath);

            string source = File.ReadAllText(TeachingGraphPath);
            if (source.Contains("CustomFunctionNode", StringComparison.Ordinal))
                errors.Add("Teaching graph must expose its data flow and contain no Custom Function node.");
            string[] requiredGroups =
            {
                "01 Base Texture & Alpha", "02 Toon Diffuse & Ramp", "03 Rim / View Edge",
                "04 Specular & RMO", "05 Hair Anisotropy", "06 Stocking Layer",
                "07 Face SDF & Final Combine"
            };
            foreach (string group in requiredGroups)
                if (!source.Contains("\"m_Title\": \"" + group + "\"", StringComparison.Ordinal))
                    errors.Add("Teaching graph is missing group: " + group);
        }

        static void ValidateRendererFeature(List<string> errors)
        {
            UniversalRendererData renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
            if (!renderer)
            {
                errors.Add("Missing URP renderer data: " + RendererPath);
                return;
            }
            BrahmaWujianRenderFeature[] features = renderer.rendererFeatures
                .OfType<BrahmaWujianRenderFeature>().ToArray();
            if (features.Length != 1)
                errors.Add($"Expected one BrahmaWujianRenderFeature, found {features.Length}.");
            else if (!features[0].isActive)
                errors.Add("BrahmaWujianRenderFeature is disabled.");
        }

        static void ValidateMaterials(List<string> errors)
        {
            Material face = FindMaterial("face01");
            if (!face)
                errors.Add("No generated face01 material was found.");
            else
            {
                ExpectFloat(face, "_StencilRefC", 200, errors);
                ExpectFloat(face, "_StencilOp", (float)StencilOp.Replace, errors);
                ExpectFloat(face, "_UseFringeShadowReceiver", 1, errors);
                if (!face.GetShaderPassEnabled("CharFaceShadow"))
                    errors.Add(face.name + " must enable CharFaceShadow.");
            }

            Material bangs = FindMaterial("hair01_bangs");
            if (!bangs)
                errors.Add("No generated hair01_bangs material was found.");
            else
            {
                ExpectFloat(bangs, "_StencilRefShadowCaster", 200, errors);
                ExpectFloat(bangs, "_StencilRefShadowReceiver", 201, errors);
                ExpectFloat(bangs, "_UseFringeShadowCaster", 1, errors);
                if (!bangs.GetShaderPassEnabled("CharHairShadow"))
                    errors.Add(bangs.name + " must enable CharHairShadow.");
            }
        }

        static Material FindMaterial(string fileName)
        {
            return AssetDatabase.FindAssets("t:Material", new[] { Root + "/Materials" })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Where(path => string.Equals(Path.GetFileNameWithoutExtension(path), fileName,
                    StringComparison.OrdinalIgnoreCase))
                .Select(AssetDatabase.LoadAssetAtPath<Material>)
                .FirstOrDefault(material => material);
        }

        static void ExpectFloat(Material material, string property, float expected, List<string> errors)
        {
            if (!material.HasProperty(property) || !Mathf.Approximately(material.GetFloat(property), expected))
                errors.Add($"{material.name}.{property} must be {expected}.");
        }

        static string Compact(string value)
        {
            var builder = new StringBuilder(value.Length);
            foreach (char character in value)
                if (!char.IsWhiteSpace(character)) builder.Append(character);
            return builder.ToString();
        }

        static void Require(string source, string token, string message, List<string> errors)
        {
            if (!source.Contains(token, StringComparison.Ordinal)) errors.Add(message);
        }
    }
}
