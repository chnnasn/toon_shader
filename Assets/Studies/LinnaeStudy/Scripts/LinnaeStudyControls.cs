using UnityEngine;
[ExecuteAlways]
public class LinnaeStudyControls : MonoBehaviour
{
    public Transform character, head;
    public Light keyLight;
    public Renderer[] surfaces;
    [Range(0,360)] public float lightYaw=325;
    [Range(10,80)] public float lightElevation=40;
    [Range(0,5)] public int debugMode;
    [Range(0,1)] public float shadowSoftness=.09f;
    [Range(0,2)] public float exposure=1;
    public bool showPanel=true;
    MaterialPropertyBlock block;
    public Vector3 headLocalForward=Vector3.forward,headLocalRight=Vector3.right;
    public Vector3 headLocalUp=Vector3.up;
    void OnEnable()=>Apply();
    void OnValidate()=>Apply();
    void Update()=>Apply();
    public void Apply()
    {
        if(keyLight){keyLight.transform.rotation=Quaternion.Euler(lightElevation,lightYaw,0);keyLight.intensity=exposure;}
        if(surfaces==null)return;
        block??=new MaterialPropertyBlock();
        var forward=character? character.forward:Vector3.back;
        var right=character? character.right:Vector3.right;
        if(head){forward=head.TransformDirection(headLocalForward);right=head.TransformDirection(headLocalRight);}
        foreach(var r in surfaces)if(r){r.GetPropertyBlock(block);block.SetFloat("_DebugMode",debugMode);block.SetFloat("_Softness",shadowSoftness);block.SetVector("_HeadForward",forward);block.SetVector("_HeadRight",right);if(head){var o=head.position;block.SetVector("_HeadOrigin",new Vector4(o.x,o.y,o.z,character.lossyScale.x));block.SetVector("_HeadUp",head.TransformDirection(headLocalUp));}r.SetPropertyBlock(block);}
    }
    void OnGUI()
    {
        if(!showPanel)return;
        GUILayout.BeginArea(new Rect(18,18,260,365),GUI.skin.box);
        GUILayout.Label("LYNAE / WUTHERING STUDY");
        GUILayout.Label("Light direction");lightYaw=GUILayout.HorizontalSlider(lightYaw,0,360);
        GUILayout.Label("Light intensity");exposure=GUILayout.HorizontalSlider(exposure,.2f,1.8f);
        GUILayout.Label("Shadow softness");shadowSoftness=GUILayout.HorizontalSlider(shadowSoftness,.01f,.25f);
        debugMode=GUILayout.SelectionGrid(debugMode,new[]{"Shaded","Albedo","Ramp","Normals","Specular","Hair shadow"},3);
        var pipeline=GetComponent<LinnaeCharacterPipeline>();
        if(pipeline){pipeline.useSDF=GUILayout.Toggle(pipeline.useSDF,"Face SDF");pipeline.hairShadows=GUILayout.Toggle(pipeline.hairShadows,"Hair to face shadow");pipeline.outlines=GUILayout.Toggle(pipeline.outlines,"Character outlines");}
        if(GUILayout.Button("Turn character 30 degrees")&&character)character.Rotate(0,30,0);
        GUILayout.EndArea();
    }
}
