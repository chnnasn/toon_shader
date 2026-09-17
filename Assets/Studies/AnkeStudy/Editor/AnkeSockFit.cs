using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class AnkeSockFit
{
 [Serializable] public class Original {public Vector3[] vertices;}
 [MenuItem("Tools/Anke Study/Repair Sock Clearance")]
 public static void Repair(){
  if(EditorApplication.isPlaying)throw new Exception("Exit Play mode before saving mesh changes");
  if(EditorSceneManager.GetActiveScene().path!="Assets/Studies/AnkeStudy/Scenes/AnkeShowcase.unity")throw new Exception("Open AnkeShowcase first");
  var c=UnityEngine.Object.FindAnyObjectByType<LinnaeStudyControls>();var r=c.character.GetComponentsInChildren<SkinnedMeshRenderer>(true).Single(x=>x.sharedMaterials.Any(m=>m&&m.name.Contains("ztoki_socks")));var mesh=r.sharedMesh;
  Directory.CreateDirectory("Tools/AnkeSockFit");string backup="Tools/AnkeSockFit/original_vertices.json";
  if(!File.Exists(backup)){File.WriteAllText(backup,JsonUtility.ToJson(new Original{vertices=mesh.vertices}));File.Copy(AssetDatabase.GetAssetPath(mesh),"Tools/AnkeSockFit/original_mesh.asset",true);}
  var vertices=JsonUtility.FromJson<Original>(File.ReadAllText(backup)).vertices;if(vertices.Length!=mesh.vertexCount)throw new Exception("Sock topology changed; inspect backup before refitting");var normals=mesh.normals;var weights=mesh.boneWeights;var matrices=r.bones.Select((b,i)=>b.localToWorldMatrix*mesh.bindposes[i]).ToArray();
  
  for(int i=0;i<vertices.Length;i++){var w=weights[i];var n=normals[i].normalized;var worldDelta=matrices[w.boneIndex0].MultiplyVector(n)*w.weight0+matrices[w.boneIndex1].MultiplyVector(n)*w.weight1+matrices[w.boneIndex2].MultiplyVector(n)*w.weight2+matrices[w.boneIndex3].MultiplyVector(n)*w.weight3;var worldPosition=matrices[w.boneIndex0].MultiplyPoint3x4(vertices[i])*w.weight0+matrices[w.boneIndex1].MultiplyPoint3x4(vertices[i])*w.weight1+matrices[w.boneIndex2].MultiplyPoint3x4(vertices[i])*w.weight2+matrices[w.boneIndex3].MultiplyPoint3x4(vertices[i])*w.weight3;float clearance=Mathf.Lerp(.009f,.0015f,Mathf.SmoothStep(0,1,Mathf.InverseLerp(.10f,.32f,worldPosition.y)));vertices[i]+=n*(clearance/Mathf.Max(worldDelta.magnitude,.00001f));}
  Undo.RecordObject(mesh,"Fit socks outside skin");mesh.vertices=vertices;mesh.RecalculateBounds();EditorUtility.SetDirty(mesh);AssetDatabase.SaveAssets();EditorSceneManager.SaveScene(c.gameObject.scene);
  File.WriteAllText("Tools/AnkeSockFit/report.txt","Normal clearance: 1.5 mm on calf, smoothly increasing to 9 mm at ankle in skinned world space\nVertices="+mesh.vertexCount+"; UVs, triangles, normals and weights unchanged\n");Capture();
 }
 [MenuItem("Tools/Anke Study/Capture Sock Fit")]
 public static void Capture(){
  var c=UnityEngine.Object.FindAnyObjectByType<LinnaeStudyControls>();var cam=c.GetComponent<Camera>();var pos=cam.transform.position;var rot=cam.transform.rotation;var previous=RenderTexture.active;bool async=ShaderUtil.allowAsyncCompilation;Directory.CreateDirectory("Tools/AnkeSockFit");
  try{ShaderUtil.allowAsyncCompilation=false;foreach(float angle in new[]{0f,60f,120f,180f}){float a=angle*Mathf.Deg2Rad;var center=new Vector3(0,.45f,0);cam.transform.position=center+new Vector3(Mathf.Sin(a)*1.15f,.02f,-Mathf.Cos(a)*1.15f);cam.transform.LookAt(center);c.Apply();c.GetComponent<LinnaeCharacterPipeline>().Prepare();var rt=RenderTexture.GetTemporary(900,1000,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);var tex=new Texture2D(900,1000,TextureFormat.RGB24,false);try{RenderPipeline.SubmitRenderRequest(cam,new UniversalRenderPipeline.SingleCameraRequest{destination=rt});RenderTexture.active=rt;tex.ReadPixels(new Rect(0,0,900,1000),0,0);tex.Apply();File.WriteAllBytes("Tools/AnkeSockFit/view_"+angle+".png",tex.EncodeToPNG());}finally{UnityEngine.Object.DestroyImmediate(tex);RenderTexture.ReleaseTemporary(rt);}}}
  finally{cam.transform.SetPositionAndRotation(pos,rot);RenderTexture.active=previous;ShaderUtil.allowAsyncCompilation=async;c.Apply();}
 }
}



