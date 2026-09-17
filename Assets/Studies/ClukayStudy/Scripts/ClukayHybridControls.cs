using UnityEngine;

public class ClukayHybridControls : MonoBehaviour
{
    public Transform character;
    public Light keyLight;
    public Material[] materials;
    public bool turntable;
    float angle=-30;int debug;
    Material[] runtimeMaterials;
    readonly string[] modes={"Hybrid","Albedo","Normals","R / M / AO","Main shadow","Direct specular","Probe reflection","Diffuse GI","Coverage"};
    void Awake()
    {
        // Runtime diagnostics never write persistent material assets.
        runtimeMaterials=new Material[materials.Length];
        for(int i=0;i<materials.Length;i++)runtimeMaterials[i]=new Material(materials[i]);
        foreach(var renderer in character.GetComponentsInChildren<SkinnedMeshRenderer>())
            if(renderer.name!="Fine Outline")renderer.sharedMaterials=runtimeMaterials;
    }
    void Update(){if(turntable&&character)character.Rotate(0,18*Time.deltaTime,0,Space.World);}
    void OnGUI()
    {
        GUILayout.BeginArea(new Rect(16,16,260,310),GUI.skin.box);
        GUILayout.Label("CLUKAY / NPR + PBR STUDY");
        turntable=GUILayout.Toggle(turntable,"Turntable");
        GUILayout.Label("Main light azimuth");float next=GUILayout.HorizontalSlider(angle,-180,180);
        if(next!=angle){angle=next;keyLight.transform.rotation=Quaternion.Euler(35,angle,0);}
        int mode=GUILayout.SelectionGrid(debug,modes,2);
        if(mode!=debug){debug=mode;foreach(var m in runtimeMaterials)m.SetFloat("_DebugMode",debug);}
        GUILayout.Label("Independent reconstruction; not original shader.");
        GUILayout.EndArea();
    }
    void OnDestroy(){if(runtimeMaterials!=null)foreach(var m in runtimeMaterials)if(m)Destroy(m);}
}
