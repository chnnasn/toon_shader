using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(SkinnedMeshRenderer))]
public class ClukayOutlineSync : MonoBehaviour
{
    public SkinnedMeshRenderer source;
    SkinnedMeshRenderer target;
    void OnEnable(){target=GetComponent<SkinnedMeshRenderer>();}
    void LateUpdate()
    {
        if(!source||!target||!source.sharedMesh)return;
        for(int i=0;i<source.sharedMesh.blendShapeCount;i++)
            target.SetBlendShapeWeight(i,source.GetBlendShapeWeight(i));
    }
}
