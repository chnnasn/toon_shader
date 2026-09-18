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
 [MenuItem("Tools/Anke Study/Restore Original Sock Mesh")]
 public static void RestoreOriginal(){
  const string backup="Tools/AnkeSockFit/original_vertices.json";
  if(!File.Exists(backup))throw new FileNotFoundException("Original sock vertex backup is missing",backup);
  var c=UnityEngine.Object.FindAnyObjectByType<LinnaeStudyControls>();
  var r=c.character.GetComponentsInChildren<SkinnedMeshRenderer>(true).Single(x=>x.sharedMaterials.Any(m=>m&&m.name.Contains("ztoki_socks")));
  var mesh=r.sharedMesh;var vertices=JsonUtility.FromJson<Original>(File.ReadAllText(backup)).vertices;
  if(vertices.Length!=mesh.vertexCount)throw new Exception("Sock topology changed; cannot restore the vertex backup");
  Undo.RecordObject(mesh,"Restore original sock mesh");mesh.vertices=vertices;mesh.RecalculateBounds();EditorUtility.SetDirty(mesh);AssetDatabase.SaveAssets();
  File.WriteAllText("Tools/AnkeSockFit/report.txt","Restored the original sock mesh; the clearance experiment did not address the UV material artifact.\nVertices="+mesh.vertexCount+"\n");
  SceneView.RepaintAll();
 }
 [MenuItem("Tools/Anke Study/Repair Sock Clearance")]
 public static void Repair(){
  if(EditorApplication.isPlaying)throw new Exception("Exit Play mode before saving mesh changes");
  if(EditorSceneManager.GetActiveScene().path!="Assets/Studies/AnkeStudy/Scenes/AnkeShowcase.unity")throw new Exception("Open AnkeShowcase first");
  var c=UnityEngine.Object.FindAnyObjectByType<LinnaeStudyControls>();var r=c.character.GetComponentsInChildren<SkinnedMeshRenderer>(true).Single(x=>x.sharedMaterials.Any(m=>m&&m.name.Contains("ztoki_socks")));var mesh=r.sharedMesh;
  Directory.CreateDirectory("Tools/AnkeSockFit");string backup="Tools/AnkeSockFit/original_vertices.json";
  if(!File.Exists(backup)){File.WriteAllText(backup,JsonUtility.ToJson(new Original{vertices=mesh.vertices}));File.Copy(AssetDatabase.GetAssetPath(mesh),"Tools/AnkeSockFit/original_mesh.asset",true);}
  var vertices=JsonUtility.FromJson<Original>(File.ReadAllText(backup)).vertices;
  if(vertices.Length!=mesh.vertexCount)throw new Exception("Sock topology changed; inspect backup before refitting");
  var normals=mesh.normals;var weights=mesh.boneWeights;var matrices=r.bones.Select((b,i)=>b.localToWorldMatrix*mesh.bindposes[i]).ToArray();
  var worldPositions=new Vector3[vertices.Length];var worldNormals=new Vector3[vertices.Length];
  Vector3 leftCenter=Vector3.zero,rightCenter=Vector3.zero;int leftCount=0,rightCount=0;float split=c.character.position.x;
  for(int i=0;i<vertices.Length;i++){
   var w=weights[i];var n=normals[i].normalized;
   worldPositions[i]=matrices[w.boneIndex0].MultiplyPoint3x4(vertices[i])*w.weight0+matrices[w.boneIndex1].MultiplyPoint3x4(vertices[i])*w.weight1+matrices[w.boneIndex2].MultiplyPoint3x4(vertices[i])*w.weight2+matrices[w.boneIndex3].MultiplyPoint3x4(vertices[i])*w.weight3;
   worldNormals[i]=matrices[w.boneIndex0].MultiplyVector(n)*w.weight0+matrices[w.boneIndex1].MultiplyVector(n)*w.weight1+matrices[w.boneIndex2].MultiplyVector(n)*w.weight2+matrices[w.boneIndex3].MultiplyVector(n)*w.weight3;
   if(worldPositions[i].x<split){leftCenter+=worldPositions[i];leftCount++;}else{rightCenter+=worldPositions[i];rightCount++;}
  }
  leftCenter/=Mathf.Max(leftCount,1);rightCenter/=Mathf.Max(rightCount,1);int flipped=0;
  for(int i=0;i<vertices.Length;i++){
   var n=normals[i].normalized;var worldDelta=worldNormals[i];var center=worldPositions[i].x<split?leftCenter:rightCenter;
   var radial=worldPositions[i]-new Vector3(center.x,worldPositions[i].y,center.z);
   if(radial.sqrMagnitude>.0000001f&&Vector3.Dot(worldDelta,radial)<0){n=-n;worldDelta=-worldDelta;flipped++;}
   float clearance=Mathf.Lerp(.009f,.006f,Mathf.SmoothStep(0,1,Mathf.InverseLerp(.10f,.32f,worldPositions[i].y)));
   vertices[i]+=n*(clearance/Mathf.Max(worldDelta.magnitude,.00001f));
  }
  Undo.RecordObject(mesh,"Fit socks outside skin");mesh.vertices=vertices;mesh.RecalculateBounds();EditorUtility.SetDirty(mesh);AssetDatabase.SaveAssets();
  File.WriteAllText("Tools/AnkeSockFit/report.txt","Normal clearance: 6 mm on the leg, smoothly increasing to 9 mm at ankle in skinned world space; outward-oriented normals v2\nVertices="+mesh.vertexCount+"; flipped inward displacement directions="+flipped+"; UVs, triangles, normals and weights unchanged\n");Capture();
 }
 [MenuItem("Tools/Anke Study/Capture Sock Fit")]
 public static void Capture(){
  var c=UnityEngine.Object.FindAnyObjectByType<LinnaeStudyControls>();var cam=c.GetComponent<Camera>();var pos=cam.transform.position;var rot=cam.transform.rotation;var previous=RenderTexture.active;bool async=ShaderUtil.allowAsyncCompilation;Directory.CreateDirectory("Tools/AnkeSockFit");
  try{ShaderUtil.allowAsyncCompilation=false;foreach(float angle in new[]{0f,60f,120f,180f}){float a=angle*Mathf.Deg2Rad;var center=new Vector3(0,.45f,0);cam.transform.position=center+new Vector3(Mathf.Sin(a)*1.15f,.02f,-Mathf.Cos(a)*1.15f);cam.transform.LookAt(center);c.Apply();c.GetComponent<LinnaeCharacterPipeline>().Prepare();var rt=RenderTexture.GetTemporary(900,1000,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);var tex=new Texture2D(900,1000,TextureFormat.RGB24,false);try{RenderPipeline.SubmitRenderRequest(cam,new UniversalRenderPipeline.SingleCameraRequest{destination=rt});RenderTexture.active=rt;tex.ReadPixels(new Rect(0,0,900,1000),0,0);tex.Apply();File.WriteAllBytes("Tools/AnkeSockFit/view_"+angle+".png",tex.EncodeToPNG());}finally{UnityEngine.Object.DestroyImmediate(tex);RenderTexture.ReleaseTemporary(rt);}}}
  finally{cam.transform.SetPositionAndRotation(pos,rot);RenderTexture.active=previous;ShaderUtil.allowAsyncCompilation=async;c.Apply();}
 }
}



