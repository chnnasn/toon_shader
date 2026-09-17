using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class LiinoWetnessControls : MonoBehaviour
{
    [Range(0,1)] public float wetness;
    [Range(0,1)] public float rain;
    [Range(-1,2.2f)] public float waterHeight=-1;
    [Range(0,10)] public int debugMode;
    public Transform character;
    public Light keyLight;
    public Renderer[] surfaces;
    public bool showControls=true;
    public bool turntable;
    public bool showEquipment;
    public GameObject[] equipment;
    [HideInInspector] public RenderPipelineAsset studyPipeline,previousPipeline;
    MaterialPropertyBlock block;
    void OnEnable(){if(studyPipeline)QualitySettings.renderPipeline=studyPipeline;Apply();}
    void OnDisable(){if(studyPipeline&&QualitySettings.renderPipeline==studyPipeline)QualitySettings.renderPipeline=previousPipeline;}
    void Update(){if(Application.isPlaying&&turntable&&character)character.Rotate(0,Time.deltaTime*12,0);Apply();}
    public void Apply()
    {
        if(surfaces==null)return;
        if(block==null)block=new MaterialPropertyBlock();
        foreach(var r in surfaces)
        {
            if(!r)continue;r.GetPropertyBlock(block);
            block.SetFloat("_Wetness",wetness);block.SetFloat("_Rain",rain);block.SetFloat("_WaterHeight",waterHeight);block.SetFloat("_DebugMode",debugMode);
            if(character){block.SetVector("_HeadForward",character.forward);block.SetVector("_HeadRight",-character.right);}
            r.SetPropertyBlock(block);
        }
        if(equipment!=null)foreach(var g in equipment)if(g&&g.activeSelf!=showEquipment)g.SetActive(showEquipment);
    }
    void OnGUI()
    {
        if(!showControls)return;
        GUILayout.BeginArea(new Rect(20,20,260,405),GUI.skin.box);
        GUILayout.Label("LIINO  /  MATERIAL LAB");
        GUILayout.Label("Endfield rendering study");
        GUILayout.Space(10);GUILayout.Label("Wetness  "+wetness.ToString("0.00"));wetness=GUILayout.HorizontalSlider(wetness,0,1);
        GUILayout.Label("Rain droplets  "+rain.ToString("0.00"));rain=GUILayout.HorizontalSlider(rain,0,1);
        GUILayout.Label("Water level  "+waterHeight.ToString("0.00")+" m");waterHeight=GUILayout.HorizontalSlider(waterHeight,-1,2.2f);
        GUILayout.BeginHorizontal();if(GUILayout.Button("DRY")){wetness=rain=0;waterHeight=-1;}if(GUILayout.Button("SOAKED")){wetness=1;rain=.7f;waterHeight=-1;}GUILayout.EndHorizontal();
        turntable=GUILayout.Toggle(turntable,"Turntable");
        showEquipment=GUILayout.Toggle(showEquipment,"Skill equipment");
        if(GUILayout.Button("Rotate light")&&keyLight)keyLight.transform.Rotate(0,35,0,Space.World);
        if(GUILayout.Button("Debug: "+debugMode))debugMode=(debugMode+1)%11;
        GUILayout.Label("0 Beauty  1 Albedo  2 Normal\n3 R/M/AO  4 Light  5 Specular\n6 Reflection  7 Ambient\n8 Wet mask  9 Roughness  10 Drops");
        GUILayout.EndArea();
    }
}
