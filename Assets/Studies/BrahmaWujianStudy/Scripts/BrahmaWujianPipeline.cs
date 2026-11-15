using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public sealed class BrahmaWujianPipeline : MonoBehaviour
{
    [System.Serializable]
    public struct Draw
    {
        public Renderer renderer;
        public Material material;
        public int slot;
        public int pass;
    }

    public Renderer[] surfaces;
    public Camera studyCamera;
    public Transform headReference;
    public float reflectionPlaneY;
    public bool preDepth = true;
    public bool stencilHairFaceShadow = true;
    public bool reflection = true;
    public bool outline = true;
    public bool hairTransmission = true;
    [Range(4, 32)] public int furLayers = 24;

    public readonly List<Draw> preDepthDraws = new();
    public readonly List<Draw> reflectionDraws = new();
    public readonly List<Draw> outlineDraws = new();
    public readonly List<Draw> hairShadowDraws = new();
    public readonly List<Draw> faceShadowDraws = new();
    public readonly List<Draw> hairTransmissionDraws = new();
    public readonly List<Draw> furDraws = new();
    readonly Dictionary<Renderer, Transform> heads = new();
    MaterialPropertyBlock properties;

    public Matrix4x4 ReflectionViewProjection { get; private set; }

    void OnEnable() => Rebuild();
    void OnValidate() => Rebuild();
    void LateUpdate() => Prepare();

    public void Rebuild()
    {
        preDepthDraws.Clear(); reflectionDraws.Clear(); outlineDraws.Clear();
        hairShadowDraws.Clear(); faceShadowDraws.Clear(); hairTransmissionDraws.Clear();
        furDraws.Clear(); heads.Clear();
        if (surfaces == null) return;
        foreach (Renderer renderer in surfaces)
        {
            if (!renderer) continue;
            Transform character = renderer.transform;
            while (character.parent) character = character.parent;
            Transform head = System.Array.Find(character.GetComponentsInChildren<Transform>(true),
                bone => bone.name == "Bip001 Head");
            heads[renderer] = head;
            Material[] materials = renderer.sharedMaterials;
            for (int slot = 0; slot < materials.Length; slot++)
            {
                Material material = materials[slot];
                if (!material || material.shader.name != "AetherGazer/Brahma Wujian/Reconstructed Multipass") continue;
                Add(preDepthDraws, renderer, material, slot, "PreDepth");
                Add(reflectionDraws, renderer, material, slot, "Reflection");
                Add(outlineDraws, renderer, material, slot, "Outline");
                Add(hairShadowDraws, renderer, material, slot, "CharHairShadow");
                Add(faceShadowDraws, renderer, material, slot, "CharFaceShadow");
                Add(hairTransmissionDraws, renderer, material, slot, "CharHairTransE");
                if (material.GetFloat("_FurMode") > .5f)
                    Add(furDraws, renderer, material, slot, "FurShell");
            }
        }
        Prepare();
    }

    static void Add(List<Draw> draws, Renderer renderer, Material material, int slot, string passName)
    {
        int pass = material.FindPass(passName);
        if (pass >= 0 && material.GetShaderPassEnabled(passName))
            draws.Add(new Draw { renderer = renderer, material = material, slot = slot, pass = pass });
    }

    public void Prepare() => Prepare(studyCamera ? studyCamera : Camera.main);

    public void Prepare(Camera camera)
    {
        properties ??= new MaterialPropertyBlock();
        foreach (var pair in heads)
        {
            if (!pair.Key) continue;
            Transform head = pair.Value ? pair.Value : headReference;
            // The exported Bip001 rig looks along local +Y, with +Z toward its right.
            Vector3 forward = head ? head.up : Vector3.back;
            Vector3 right = head ? head.forward : Vector3.right;
            pair.Key.GetPropertyBlock(properties);
            properties.SetVector("_BrahmaHeadForwardWS", forward);
            properties.SetVector("_BrahmaHeadRightWS", right);
            pair.Key.SetPropertyBlock(properties);
        }
        if (!camera) return;
        Matrix4x4 mirror = Matrix4x4.identity;
        mirror.m11 = -1;
        mirror.m13 = 2 * reflectionPlaneY;
        ReflectionViewProjection = GL.GetGPUProjectionMatrix(camera.projectionMatrix, true) *
            camera.worldToCameraMatrix * mirror;
    }
}
