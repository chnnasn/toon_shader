using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class LinnaeStudyControls : MonoBehaviour
{
    public Transform character, head;
    public Light keyLight;
    public Renderer[] surfaces;
    [Range(0,360)] public float lightYaw=325;
    [Range(10,80)] public float lightElevation=40;
    [Range(0,6)] public int debugMode;
    [Range(0,1)] public float shadowSoftness=.09f;
    [Range(0,4)] public float exposure=1;
    public bool showPanel=true;
    public Vector3 headLocalForward=Vector3.forward,headLocalRight=Vector3.right;
    public Vector3 headLocalUp=Vector3.up;

    [Header("Linnae showcase weather")]
    public Shader rainShader, skyShader;
    [Range(0,1)] public float wetness;
    [Range(0,1)] public float rain;

    MaterialPropertyBlock block;
    LinnaeRainField rainField;
    Skybox skybox;
    Material skyMaterial, previousSky;
    bool panelExpanded = true;
    static readonly string[] Views = { "Shaded","Albedo","Ramp","Normals","Specular","Hair shadow" };
    static readonly string[] RainViews = { "Shaded","Albedo","Ramp","Normals","Specular","Hair shadow","Drops" };

    void OnEnable() => Apply();
    void Update()
    {
        if (rainShader && rainField == null)
            rainField = new LinnaeRainField(rainShader, transform);
        if (skyShader && !skyMaterial && TryGetComponent(out skybox))
        {
            previousSky = skybox.material;
            skyMaterial = CoreUtils.CreateEngineMaterial(skyShader);
            skybox.material = skyMaterial;
        }
        Apply();
    }

    void OnDisable()
    {
        rainField?.Release();
        rainField = null;
        if (skybox && skybox.material == skyMaterial) skybox.material = previousSky;
        CoreUtils.Destroy(skyMaterial);
    }

    public void Apply()
    {
        if (keyLight)
        {
            keyLight.transform.rotation = Quaternion.Euler(lightElevation,lightYaw,0);
            keyLight.intensity = exposure;
        }
        var root = character ? character.position : Vector3.zero;
        rainField?.Apply(root, rain);
        if (skyMaterial) skyMaterial.SetFloat("_RainAmount",rain);
        if (surfaces == null) return;
        block ??= new MaterialPropertyBlock();
        var forward = head ? head.TransformDirection(headLocalForward) : character ? character.forward : Vector3.back;
        var right = head ? head.TransformDirection(headLocalRight) : character ? character.right : Vector3.right;
        foreach (var surface in surfaces)
        {
            if (!surface) continue;
            surface.GetPropertyBlock(block);
            block.SetFloat("_DebugMode", debugMode);
            block.SetFloat("_Softness", shadowSoftness);
            block.SetVector("_HeadForward", forward);
            block.SetVector("_HeadRight", right);
            if (head)
            {
                var o = head.position;
                block.SetVector("_HeadOrigin", new Vector4(o.x,o.y,o.z,character ? character.lossyScale.x : 1));
                block.SetVector("_HeadUp",head.TransformDirection(headLocalUp));
            }
            if (rainShader)
            {
                block.SetVector("_LinnaeWeather", new Vector4(wetness,rain,0,0));
                block.SetVector("_LinnaeRootWS",root);
                block.SetVector("_LinnaeRightWS",character ? character.right : Vector3.right);
            }
            surface.SetPropertyBlock(block);
        }
    }

    void Frame(bool close)
    {
        if (!character || !head) return;
        var target = close ? head.position + Vector3.down*.13f : character.position + Vector3.up*.86f;
        var offset = close ? new Vector3(.39f,.04f,-1.18f) : new Vector3(0,.14f,-3.45f);
        transform.position = target + offset;
        transform.LookAt(target);
    }

    void OnGUI()
    {
        if (!showPanel) return;
        GUILayout.BeginArea(new Rect(18,18,248,panelExpanded ? (rainShader ? 435 : 350) : 34),GUI.skin.box);
        if (GUILayout.Button(panelExpanded ? "Linnae   /   Hide controls" : "Linnae   /   Show controls"))
            panelExpanded = !panelExpanded;
        if (!panelExpanded) { GUILayout.EndArea(); return; }
        if (rainShader)
        {
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Dry")) { wetness=0; rain=0; }
            if (GUILayout.Button("Rain")) { wetness=.88f; rain=.78f; }
            if (GUILayout.Button("Close")) Frame(true);
            if (GUILayout.Button("Full")) Frame(false);
            GUILayout.EndHorizontal();
            GUILayout.Label("Surface wetness   "+wetness.ToString("0.00"));
            wetness=GUILayout.HorizontalSlider(wetness,0,1);
            GUILayout.Label("Rainfall   "+rain.ToString("0.00"));
            rain=GUILayout.HorizontalSlider(rain,0,1);
        }
        GUILayout.Label("Light direction"); lightYaw=GUILayout.HorizontalSlider(lightYaw,0,360);
        GUILayout.Label("Light intensity"); exposure=GUILayout.HorizontalSlider(exposure,.2f,rainShader ? 4f : 1.8f);
        GUILayout.Label("Shadow softness"); shadowSoftness=GUILayout.HorizontalSlider(shadowSoftness,.01f,.25f);
        debugMode=GUILayout.SelectionGrid(debugMode,rainShader ? RainViews : Views,3);
        var pipeline=GetComponent<LinnaeCharacterPipeline>();
        if (pipeline)
        {
            pipeline.useSDF=GUILayout.Toggle(pipeline.useSDF,"Face SDF");
            pipeline.hairShadows=GUILayout.Toggle(pipeline.hairShadows,"Hair to face shadow");
            pipeline.outlines=GUILayout.Toggle(pipeline.outlines,"Character outlines");
        }
        if (GUILayout.Button("Turn character 30 degrees") && character) character.Rotate(0,30,0);
        GUILayout.EndArea();
    }
}
