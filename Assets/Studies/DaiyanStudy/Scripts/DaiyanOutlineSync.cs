using UnityEngine;
[ExecuteAlways,DisallowMultipleComponent,RequireComponent(typeof(SkinnedMeshRenderer))]
public sealed class DaiyanOutlineSync:MonoBehaviour
{
 public SkinnedMeshRenderer source;
 SkinnedMeshRenderer target;
 void OnEnable(){target=GetComponent<SkinnedMeshRenderer>();Sync();}
 public void Sync(){if(!target)target=GetComponent<SkinnedMeshRenderer>();if(!source||!source.sharedMesh||!target)return;target.enabled=source.enabled;target.forceRenderingOff=source.forceRenderingOff;target.localBounds=source.localBounds;for(int i=0;i<source.sharedMesh.blendShapeCount;i++)target.SetBlendShapeWeight(i,source.GetBlendShapeWeight(i));}
 void LateUpdate(){Sync();}
}
