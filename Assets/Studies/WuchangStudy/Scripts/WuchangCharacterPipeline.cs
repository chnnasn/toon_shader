using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public sealed class WuchangCharacterPipeline : MonoBehaviour
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
    public Light keyLight;
    public Camera studyCamera;
    public Transform headReference;
    public float reflectionPlaneY;
    public bool preDepth = true;
    public bool outline = true;
    public bool stencilHairShadow = true;
    public bool reflection = true;
    [Range(0f, 1f)] public float reflectionStrength = 0.08f;
    [Range(-0.02f, 0.02f)] public float globalHairShadowOffsetX;
    [Range(-0.02f, 0.02f)] public float globalHairShadowOffsetY;

    public readonly List<Draw> preDepthDraws = new();
    public readonly List<Draw> outlineDraws = new();
    public readonly List<Draw> hairShadowDraws = new();
    public readonly List<Draw> faceShadowDraws = new();
    public readonly List<Draw> reflectionDraws = new();

    public Matrix4x4 ReflectionView { get; private set; }
    public Matrix4x4 ReflectionProjection { get; private set; }
    public Matrix4x4 ReflectionViewProjection { get; private set; }
    public Matrix4x4 CameraView { get; private set; }
    public Matrix4x4 CameraProjection { get; private set; }

    void OnEnable() => Rebuild();
    void OnValidate() => Rebuild();
    void LateUpdate() => Prepare();

    public void Rebuild()
    {
        preDepthDraws.Clear();
        outlineDraws.Clear();
        hairShadowDraws.Clear();
        faceShadowDraws.Clear();
        reflectionDraws.Clear();
        if (surfaces == null)
            return;

        foreach (Renderer renderer in surfaces)
        {
            if (!renderer)
                continue;
            Material[] materials = renderer.sharedMaterials;
            for (int slot = 0; slot < materials.Length; slot++)
            {
                Material material = materials[slot];
                if (!material || material.shader.name != "AetherGazer/Wuchang Character Reconstructed")
                    continue;
                AddIfEnabled(preDepthDraws, renderer, material, slot, "PreDepth");
                AddIfEnabled(outlineDraws, renderer, material, slot, "Outline");
                AddIfEnabled(hairShadowDraws, renderer, material, slot, "CharHairShadow");
                AddIfEnabled(faceShadowDraws, renderer, material, slot, "CharFaceShadow");
                AddIfEnabled(reflectionDraws, renderer, material, slot, "Reflection");
            }
        }
        Prepare();
    }

    static void AddIfEnabled(List<Draw> draws, Renderer renderer, Material material, int slot, string passName)
    {
        int pass = material.FindPass(passName);
        if (pass >= 0 && material.GetShaderPassEnabled(passName))
            draws.Add(new Draw { renderer = renderer, material = material, slot = slot, pass = pass });
    }

    public void Prepare()
    {
        if (!studyCamera)
            studyCamera = Camera.main;
        Vector3 forward = headReference ? headReference.forward : Vector3.back;
        Vector3 right = headReference ? headReference.right : Vector3.right;
        Shader.SetGlobalVector("_WuchangHeadForwardWS", new Vector4(forward.x, forward.y, forward.z, 0));
        Shader.SetGlobalVector("_WuchangHeadRightWS", new Vector4(right.x, right.y, right.z, 0));

        foreach (Draw draw in hairShadowDraws)
        {
            string materialName = draw.material.name;
            float x = materialName.Contains("614801") ? 0.010f : -0.010f;
            float y = materialName.Contains("614801") ? 0.0070f : 0.00574f;
            draw.material.SetFloat("_HairShadowOffsetX", x + globalHairShadowOffsetX);
            draw.material.SetFloat("_HairShadowOffsetY", y + globalHairShadowOffsetY);
        }
        foreach (Draw draw in reflectionDraws)
            draw.material.SetFloat("_ReflectionStrength", reflectionStrength);

        if (!studyCamera)
            return;
        Transform cameraTransform = studyCamera.transform;
        Vector3 reflectedPosition = cameraTransform.position;
        reflectedPosition.y = reflectionPlaneY * 2f - reflectedPosition.y;
        Vector3 reflectedForward = cameraTransform.forward;
        reflectedForward.y = -reflectedForward.y;
        Vector3 reflectedUp = cameraTransform.up;
        reflectedUp.y = -reflectedUp.y;
        Quaternion reflectedRotation = Quaternion.LookRotation(reflectedForward, reflectedUp);
        ReflectionView = Matrix4x4.Scale(new Vector3(1, 1, -1)) *
            Matrix4x4.TRS(reflectedPosition, reflectedRotation, Vector3.one).inverse;
        ReflectionProjection = GL.GetGPUProjectionMatrix(studyCamera.projectionMatrix, true);
        ReflectionViewProjection = ReflectionProjection * ReflectionView;
        CameraView = studyCamera.worldToCameraMatrix;
        CameraProjection = GL.GetGPUProjectionMatrix(studyCamera.projectionMatrix, false);
    }
}
