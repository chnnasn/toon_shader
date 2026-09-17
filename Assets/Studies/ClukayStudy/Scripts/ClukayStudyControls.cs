using UnityEngine;

public class ClukayStudyControls : MonoBehaviour
{
    public Transform character;
    public Light keyLight;
    public Material[] materials;
    public bool turntable;
    float lightAngle=-32;
    int debugMode;
    readonly string[] modes={"Shaded","Albedo","Normals","RMO","Light / shadow","Specular"};
    void Update(){if(turntable&&character)character.Rotate(0,Time.deltaTime*18,0,Space.World);}
    void OnGUI()
    {
        GUILayout.BeginArea(new Rect(18,18,250,240),GUI.skin.box);
        GUILayout.Label("CLUKAY / MATERIAL STUDY");
        turntable=GUILayout.Toggle(turntable,"Turntable");
        GUILayout.Label("Light azimuth");
        float angle=GUILayout.HorizontalSlider(lightAngle,-180,180);
        if(angle!=lightAngle&&keyLight){lightAngle=angle;keyLight.transform.rotation=Quaternion.Euler(38,lightAngle,0);}
        GUILayout.Label("View");
        int next=GUILayout.SelectionGrid(debugMode,modes,2);
        if(next!=debugMode){debugMode=next;foreach(var m in materials)if(m)m.SetFloat("_DebugMode",debugMode);}
        if(GUILayout.Button("Reset pose / view")){character.rotation=Quaternion.Euler(0,180,0);turntable=false;}
        GUILayout.EndArea();
    }
    void OnDisable(){if(materials!=null)foreach(var m in materials)if(m)m.SetFloat("_DebugMode",0);}
}
