using System;
using UnityEngine;

[ExecuteAlways]
public sealed class AnkeWardrobe : MonoBehaviour
{
 [Serializable] public class Part {public string label;public GameObject mesh;public bool visible=true;}
 public GameObject outfit1,outfit2;
 public Part[] firstParts=Array.Empty<Part>(),secondParts=Array.Empty<Part>();
 [Range(0,1)] public int selectedOutfit=1;
 public bool showUI=true;
 Font font;
 void OnEnable()=>Apply();
 void OnValidate()=>Apply();
 public void SelectOutfit(int index){selectedOutfit=Mathf.Clamp(index,0,1);Apply();}
 public void SetPart(int index,bool visible){var parts=selectedOutfit==0?firstParts:secondParts;if(index<0||index>=parts.Length)return;parts[index].visible=visible;Apply();}
 public void Apply(){if(outfit1)outfit1.SetActive(selectedOutfit==0);if(outfit2)outfit2.SetActive(selectedOutfit==1);foreach(var p in firstParts)if(p.mesh)p.mesh.SetActive(p.visible);foreach(var p in secondParts)if(p.mesh)p.mesh.SetActive(p.visible);}
 void OnGUI(){
  if(!showUI||!Application.isPlaying)return;
  if(!font)font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","SimHei","Arial"},16);
  var oldFont=GUI.skin.font;var oldMatrix=GUI.matrix;GUI.skin.font=font;float scale=Mathf.Clamp(Screen.height/900f,.65f,1.5f);GUI.matrix=Matrix4x4.Scale(Vector3.one*scale);
  GUILayout.BeginArea(new Rect(18,18,245,480),GUI.skin.box);GUILayout.Label("安可 · 换装");
  int next=GUILayout.SelectionGrid(selectedOutfit,new[]{"第一套","第二套"},2,GUILayout.Height(36));if(next!=selectedOutfit)SelectOutfit(next);
  GUILayout.Space(10);var parts=selectedOutfit==0?firstParts:secondParts;
  for(int i=0;i<parts.Length;i++){bool v=GUILayout.Toggle(parts[i].visible,parts[i].label);if(v!=parts[i].visible)SetPart(i,v);}
  if(GUILayout.Button("显示本套全部服装")){foreach(var p in parts)p.visible=true;Apply();}
  GUILayout.EndArea();GUI.skin.font=oldFont;GUI.matrix=oldMatrix;
 }
 void OnDestroy(){if(font){if(Application.isPlaying)Destroy(font);else DestroyImmediate(font);}}
}
