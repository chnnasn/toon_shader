using System;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
public sealed class DaiyanWardrobeUI:MonoBehaviour
{
 [Serializable]public class Part{public string label;public Renderer[] renderers;public bool worn=true;}
 public Transform character,bodyRoot,outfitRoot;public Light keyLight;public Renderer[] debugRenderers;public Part[] parts;
 public Button[] partButtons;public ScrollRect scroll;public bool turntable,rotateLight;public float yaw,lightYaw,lightPitch;public int debugMode;
 Font font;Transform content;float initialYaw,initialPitch;MaterialPropertyBlock block;readonly Color orange=new Color(1,.48f,.12f),dark=new Color(.18f,.23f,.26f);
 public void SetPart(int index,bool worn){parts[index].worn=worn;foreach(var r in parts[index].renderers)r.enabled=worn;foreach(var sync in character.GetComponentsInChildren<DaiyanOutlineSync>(true))sync.Sync();Refresh();}
 public void AllOn(){for(int i=0;i<parts.Length;i++)SetPart(i,true);}
 public void ResetView(){yaw=0;lightYaw=initialYaw;lightPitch=initialPitch;turntable=rotateLight=false;SetDebug(0);}
 public void SetDebug(int mode){debugMode=mode;block??=new MaterialPropertyBlock();foreach(var r in debugRenderers){r.GetPropertyBlock(block);block.SetFloat("_DebugMode",mode);r.SetPropertyBlock(block);}}
 void Awake(){initialYaw=lightYaw;initialPitch=lightPitch;BuildUI();AllOn();}
 void Update(){if(turntable)yaw=Mathf.Repeat(yaw+180+18*Time.deltaTime,360)-180;if(rotateLight)lightYaw=Mathf.Repeat(lightYaw+180+20*Time.deltaTime,360)-180;character.localRotation=Quaternion.Euler(0,180+yaw,0);keyLight.transform.rotation=Quaternion.Euler(lightPitch,lightYaw,0);}
 RectTransform Node(string name,Transform parent){var go=new GameObject(name,typeof(RectTransform));go.transform.SetParent(parent,false);return (RectTransform)go.transform;}
 void Stretch(RectTransform r){r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=r.offsetMax=Vector2.zero;}
 Text Label(Transform parent,string text,int size=20){var r=Node(text,parent);var t=r.gameObject.AddComponent<Text>();t.font=font;t.text=text;t.fontSize=size;t.color=new Color(.9f,.93f,.95f);t.raycastTarget=false;t.alignment=TextAnchor.MiddleLeft;r.gameObject.AddComponent<LayoutElement>().preferredHeight=size+15;return t;}
 Button Button(string text,Action action){var r=Node(text,content);var img=r.gameObject.AddComponent<Image>();img.color=dark;var b=r.gameObject.AddComponent<Button>();b.targetGraphic=img;r.gameObject.AddComponent<LayoutElement>().preferredHeight=42;var t=Label(r,text,19);Stretch(t.rectTransform);t.alignment=TextAnchor.MiddleCenter;b.onClick.AddListener(()=>action());return b;}
 void Slider(string title,float min,float max,float value,Action<float> action){var t=Label(content,title);var r=Node(title,content);r.gameObject.AddComponent<LayoutElement>().preferredHeight=25;r.gameObject.AddComponent<Image>().color=dark;var h=Node("Handle",r);h.sizeDelta=new Vector2(18,25);h.gameObject.AddComponent<Image>().color=orange;var s=r.gameObject.AddComponent<Slider>();s.handleRect=h;s.targetGraphic=h.GetComponent<Image>();s.minValue=min;s.maxValue=max;s.value=value;s.onValueChanged.AddListener(v=>{action(v);t.text=title+" "+v.ToString("F0");});}
 void Section(string name){Label(content,name,24).color=orange;}
 void Refresh(){if(partButtons==null)return;for(int i=0;i<parts.Length;i++){partButtons[i].GetComponent<Image>().color=parts[i].worn?orange:dark;partButtons[i].GetComponentInChildren<Text>().text=parts[i].label+(parts[i].worn?"   已穿 · 点击脱下":"   已脱 · 点击穿上");}}
 void BuildUI(){
 font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","SimHei","Arial"},20);
 var root=Node("Daiyan UGUI",transform);var canvas=root.gameObject.AddComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;canvas.sortingOrder=20;var scaler=root.gameObject.AddComponent<CanvasScaler>();scaler.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;scaler.referenceResolution=new Vector2(1600,900);scaler.matchWidthOrHeight=1;root.gameObject.AddComponent<GraphicRaycaster>();
 if(!FindAnyObjectByType<EventSystem>()){var es=new GameObject("Daiyan EventSystem",typeof(EventSystem),typeof(InputSystemUIInputModule));es.transform.SetParent(root,false);}
 var panel=Node("Wardrobe Panel",root);panel.anchorMin=new Vector2(1,0);panel.anchorMax=Vector2.one;panel.offsetMin=new Vector2(-440,20);panel.offsetMax=new Vector2(-20,-20);panel.gameObject.AddComponent<Image>().color=new Color(.055f,.075f,.095f,.96f);
 var title=Label(panel,"黛烟 · 穿搭预览",27);title.rectTransform.anchorMin=new Vector2(0,1);title.rectTransform.anchorMax=Vector2.one;title.rectTransform.offsetMin=new Vector2(18,-60);title.rectTransform.offsetMax=new Vector2(-18,-12);
 var view=Node("Scroll View",panel);Stretch(view);view.offsetMin=new Vector2(14,14);view.offsetMax=new Vector2(-22,-65);view.gameObject.AddComponent<Image>().color=new Color(0,0,0,.01f);view.gameObject.AddComponent<RectMask2D>();scroll=view.gameObject.AddComponent<ScrollRect>();scroll.horizontal=false;scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=35;scroll.viewport=view;
 var ct=Node("Content",view);ct.anchorMin=new Vector2(0,1);ct.anchorMax=Vector2.one;ct.pivot=new Vector2(.5f,1);ct.sizeDelta=Vector2.zero;content=ct;var layout=ct.gameObject.AddComponent<VerticalLayoutGroup>();layout.spacing=8;layout.padding=new RectOffset(4,10,0,15);layout.childControlHeight=true;layout.childForceExpandHeight=false;ct.gameObject.AddComponent<ContentSizeFitter>().verticalFit=ContentSizeFitter.FitMode.PreferredSize;scroll.content=ct;
 var track=Node("Scrollbar",panel);track.anchorMin=new Vector2(1,0);track.anchorMax=Vector2.one;track.offsetMin=new Vector2(-12,14);track.offsetMax=new Vector2(-5,-65);track.gameObject.AddComponent<Image>().color=dark;var handle=Node("Handle",track);Stretch(handle);handle.gameObject.AddComponent<Image>().color=orange;var bar=track.gameObject.AddComponent<Scrollbar>();bar.direction=Scrollbar.Direction.BottomToTop;bar.handleRect=handle;bar.targetGraphic=handle.GetComponent<Image>();scroll.verticalScrollbar=bar;
 Label(content,"素体包含身体与头发 · 滚轮查看更多",16);Section("部位穿脱");partButtons=new Button[parts.Length];for(int i=0;i<parts.Length;i++){int index=i;partButtons[i]=Button(parts[i].label,()=>SetPart(index,!parts[index].worn));}Button("恢复全部穿着",AllOn);
 if(debugRenderers.Any(r=>r.sharedMaterials.Any(m=>m&&m.HasProperty("_DebugMode")))){Section("渲染查看");string[] names={"正常着色","底色","法线","粗糙/金属/AO","主光阴影","直接高光","环境反射","间接漫反射","透明遮罩"};for(int i=0;i<names.Length;i++){int mode=i;Button(names[i],()=>SetDebug(mode));}}
 Section("模型旋转");Slider("角度",-180,180,yaw,v=>yaw=v);Button("模型自动旋转 / 停止",()=>turntable=!turntable);Section("主灯光");Slider("方位",-180,180,lightYaw,v=>lightYaw=v);Slider("俯仰",-85,85,lightPitch,v=>lightPitch=v);Button("灯光自动旋转 / 停止",()=>rotateLight=!rotateLight);Button("重置视角与灯光",ResetView);Canvas.ForceUpdateCanvases();scroll.verticalNormalizedPosition=1;
 }
 void OnDestroy(){if(font)Destroy(font);}
}
