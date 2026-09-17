using System;
using UnityEngine;

public class ClukayWardrobe : MonoBehaviour
{
    public GameObject[] tops,skirts,legs;
    public Transform pivot;
    public Camera viewCamera;
    public int top,skirt,leg;
    public bool showUI=true;
    public GameObject weapon;
    public Renderer[] debugRenderers=Array.Empty<Renderer>();
    public Light keyLight;
    public bool turntable,rotateLight;
    public float rotationSpeed=18,lightSpeed=20;
    public Vector2 scrollPosition;
    [HideInInspector] public int materialLayoutVersion;
    public Texture2D[] thumbnails=new Texture2D[9];
    Font font;
    float angle=180;
    float lightYaw,lightPitch=38;
    Quaternion initialLightRotation;
    bool lightInitialized;
    int debugMode;
    readonly string[] viewNames={"正常着色","底色","法线","粗糙/金属/AO","主光阴影","直接高光","环境反射","间接漫反射","透明遮罩","白模"};
    string message="本地预览 · 不修改手机穿戴";
    void Awake(){font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","SimHei","Arial"},20);angle=pivot?pivot.localEulerAngles.y:180;InitializeLight();Apply(top,skirt,leg);}
    public void InitializeLight()
    {
        if(!keyLight)
        {
            if(RenderSettings.sun&&RenderSettings.sun.gameObject.scene==gameObject.scene)keyLight=RenderSettings.sun;
            else foreach(var root in gameObject.scene.GetRootGameObjects())foreach(var light in root.GetComponentsInChildren<Light>())if(light.type==LightType.Directional){keyLight=light;break;}
        }
        if(keyLight&&!lightInitialized){initialLightRotation=keyLight.transform.rotation;lightYaw=keyLight.transform.eulerAngles.y;lightPitch=Mathf.DeltaAngle(0,keyLight.transform.eulerAngles.x);lightInitialized=true;}
    }
    public void SetLightAngles(float yaw,float pitch){InitializeLight();lightYaw=Mathf.Repeat(yaw,360);lightPitch=Mathf.Clamp(pitch,-85,85);if(keyLight)keyLight.transform.rotation=Quaternion.Euler(lightPitch,lightYaw,0);}
    public void AdvanceRotation(float seconds){if(turntable)SetYaw(angle+rotationSpeed*seconds);if(rotateLight)SetLightAngles(lightYaw+lightSpeed*seconds,lightPitch);}
    void Update(){AdvanceRotation(Time.deltaTime);}
    public void ResetView(){turntable=false;rotateLight=false;SetYaw(180);SetDebugMode(0);InitializeLight();if(keyLight){keyLight.transform.rotation=initialLightRotation;lightYaw=keyLight.transform.eulerAngles.y;lightPitch=Mathf.DeltaAngle(0,keyLight.transform.eulerAngles.x);}}
    public void SetYaw(float degrees){angle=Mathf.Repeat(degrees,360);if(pivot)pivot.localRotation=Quaternion.Euler(0,angle,0);}
    public void SetDebugMode(int mode)
    {
        debugMode=Mathf.Clamp(mode,0,9);
        var block=new MaterialPropertyBlock();
        foreach(var r in debugRenderers)if(r){var mats=r.sharedMaterials;for(int i=0;i<mats.Length;i++)if(mats[i]&&mats[i].HasProperty("_DebugMode")){block.Clear();r.GetPropertyBlock(block,i);block.SetFloat("_DebugMode",debugMode);r.SetPropertyBlock(block,i);}}
    }
    public void Apply(int t,int s,int l)
    {
        top=Mathf.Clamp(t,0,2);skirt=Mathf.Clamp(s,0,2);leg=Mathf.Clamp(l,0,2);
        for(int i=0;i<3;i++){tops[i].SetActive(i==top);skirts[i].SetActive(i==skirt);legs[i].SetActive(i==leg);}
    }
    void OnGUI()
    {
        if(!showUI)return;
        var oldMatrix=GUI.matrix;var oldFont=GUI.skin.font;GUI.matrix=Matrix4x4.Scale(new Vector3(Screen.width/1600f,Screen.height/900f,1));
        if(font)GUI.skin.font=font;
        var oldSize=GUI.skin.label.fontSize;GUI.skin.label.fontSize=18;
        GUILayout.BeginArea(new Rect(1150,20,415,860),GUI.skin.box);
        GUILayout.Label("可露凯 · 无瑕侍礼");GUILayout.Label("右侧滚动条 / 鼠标滚轮上下查看");
        scrollPosition=GUILayout.BeginScrollView(scrollPosition,false,true);
        GUILayout.Label("渲染查看");
        int nextMode=GUILayout.SelectionGrid(debugMode,viewNames,2,GUILayout.Height(155));if(nextMode!=debugMode)SetDebugMode(nextMode);
        GUILayout.Space(12);GUILayout.Label("模型水平旋转："+angle.ToString("F0")+"°");
        float nextAngle=GUILayout.HorizontalSlider(angle,0,360);if(nextAngle!=angle)SetYaw(nextAngle);
        turntable=GUILayout.Toggle(turntable,"模型自动旋转");
        GUILayout.Label("模型转速："+rotationSpeed.ToString("F0")+"°/秒");rotationSpeed=GUILayout.HorizontalSlider(rotationSpeed,-60,60);
        if(weapon)weapon.SetActive(GUILayout.Toggle(weapon.activeSelf,"显示枪模型"));
        GUILayout.Space(18);GUILayout.Label("部件换装");
        int t=Choice("上衣",top,0),s=Choice("下装",skirt,3),l=Choice("腿部",leg,6);
        if(t!=top||s!=skirt||l!=leg){Apply(t,s,l);message="预览搭配尚未保存";}
        GUILayout.Space(18);GUILayout.Label("主灯光旋转");
        GUILayout.Label("方位："+lightYaw.ToString("F0")+"°");float yaw=GUILayout.HorizontalSlider(lightYaw,0,360);
        GUILayout.Label("俯仰："+lightPitch.ToString("F0")+"°");float pitch=GUILayout.HorizontalSlider(lightPitch,-85,85);
        if(yaw!=lightYaw||pitch!=lightPitch)SetLightAngles(yaw,pitch);
        rotateLight=GUILayout.Toggle(rotateLight,"灯光自动旋转");
        GUILayout.Label("灯光转速："+lightSpeed.ToString("F0")+"°/秒");lightSpeed=GUILayout.HorizontalSlider(lightSpeed,-60,60);
        if(!keyLight)GUILayout.Label("当前场景未找到方向光");
        if(GUILayout.Button("重置模型视角与灯光",GUILayout.Height(38)))ResetView();
        if(GUILayout.Button("恢复默认搭配",GUILayout.Height(44))){Apply(0,0,0);ResetView();message="已恢复默认";}
        if(GUILayout.Button("保存本地搭配",GUILayout.Height(44)))
        {PlayerPrefs.SetInt("ClukayWardrobe.Top",top);PlayerPrefs.SetInt("ClukayWardrobe.Skirt",skirt);PlayerPrefs.SetInt("ClukayWardrobe.Leg",leg);PlayerPrefs.Save();message="已保存到本机（非手机存档）";}
        if(GUILayout.Button("读取本地搭配",GUILayout.Height(38)))Apply(PlayerPrefs.GetInt("ClukayWardrobe.Top"),PlayerPrefs.GetInt("ClukayWardrobe.Skirt"),PlayerPrefs.GetInt("ClukayWardrobe.Leg"));
        GUILayout.Label(message);GUILayout.Label("原始替换网格 / 重建组合与光照");GUILayout.Space(12);GUILayout.EndScrollView();GUILayout.EndArea();
        GUI.skin.label.fontSize=oldSize;GUI.skin.font=oldFont;GUI.matrix=oldMatrix;
    }
    int Choice(string title,int value,int offset)
    {
        GUILayout.Label(title);GUILayout.BeginHorizontal();int next=value;
        for(int i=0;i<3;i++)
        {
            var color=GUI.backgroundColor;GUI.backgroundColor=i==value?new Color(1,.48f,.12f):new Color(.34f,.43f,.46f);
            var content=thumbnails!=null&&thumbnails.Length>offset+i&&thumbnails[offset+i]?new GUIContent(thumbnails[offset+i],"款式 "+(i+1)):new GUIContent("款式 "+(i+1));
            if(GUILayout.Button(content,GUILayout.Width(117),GUILayout.Height(75)))next=i;GUI.backgroundColor=color;
        }
        GUILayout.EndHorizontal();GUILayout.Space(12);return next;
    }
    void OnDestroy(){if(font)Destroy(font);}
}
