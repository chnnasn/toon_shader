using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public sealed class LinnaeCharacterPipeline : MonoBehaviour
{
    public LinnaeStudyControls controls;
    public RenderPipelineAsset studyPipeline;
    [SerializeField] RenderPipelineAsset previousPipeline;
    public Shader hairDepthShader,outlineShader;
    public bool hairShadows=true,outlines=true,useSDF=true;
    [Range(0,1)] public float hairShadowStrength=.32f;
    [Range(.2f,2)] public float outlinePixels=.65f;
    public Color outlineColor=new Color(.15f,.09f,.12f,1);
    [HideInInspector] public Vector3 headLocalForward,headLocalRight;
    public struct Draw {public Renderer renderer;public Material material;public int slot;}
    public readonly List<Draw> hairDraws=new();
    public readonly List<Draw> outlineDraws=new();
    public Matrix4x4 LightMatrix{get;private set;}
    MaterialPropertyBlock block;
    void OnEnable(){if(studyPipeline&&QualitySettings.renderPipeline!=studyPipeline){previousPipeline=QualitySettings.renderPipeline;QualitySettings.renderPipeline=studyPipeline;}Rebuild();}
    void OnDisable(){if(studyPipeline&&QualitySettings.renderPipeline==studyPipeline)QualitySettings.renderPipeline=previousPipeline;Shader.SetGlobalFloat("_LinnaeHairShadowActive",0);Release();}
    void Release(){foreach(var d in hairDraws)CoreUtils.Destroy(d.material);foreach(var d in outlineDraws)CoreUtils.Destroy(d.material);hairDraws.Clear();outlineDraws.Clear();}
    public void Rebuild()
    {
        Release();if(!controls||controls.surfaces==null||!hairDepthShader||!outlineShader)return;
        foreach(var r in controls.surfaces)if(r)
        {
            var mats=r.sharedMaterials;
            for(int i=0;i<mats.Length;i++)
            {
                var source=mats[i];if(!source)continue;
                bool hair=source.HasProperty("_Hair")&&source.GetFloat("_Hair")>.5f;
                if(hair){var m=CoreUtils.CreateEngineMaterial(hairDepthShader);m.SetTexture("_BaseMap",source.GetTexture("_BaseMap"));hairDraws.Add(new Draw{renderer=r,material=m,slot=i});}
                // Skip overlays, eyes and transparent accessories: only solid exterior silhouette gets ink.
                string n=source.name;
                bool ink=source.HasProperty("_Ink")?source.GetFloat("_Ink")>.5f:n=="Face_"||hair||n.Contains("Skin")||n=="Up_"||n=="Down_"||n=="Cloth"||n.Contains("Pants")||n=="Down_Shoe";
                if(ink){var m=CoreUtils.CreateEngineMaterial(outlineShader);m.SetTexture("_BaseMap",source.GetTexture("_BaseMap"));m.SetFloat("_Face",n=="Face_"?1:0);m.SetFloat("_Hair",hair?1:0);outlineDraws.Add(new Draw{renderer=r,material=m,slot=i});}
            }
        }
    }
    void LateUpdate()=>Prepare();
    public void Prepare()
    {
        if(!controls||!controls.keyLight)return;
        if(hairDraws.Count==0)Rebuild();
        var center=controls.head?controls.head.position+controls.character.up*.075f:controls.character.position+Vector3.up*1.48f;
        var lightRot=controls.keyLight.transform.rotation;
        // Unity camera view convention is right-handed, with -Z forward.
        var view=Matrix4x4.Scale(new Vector3(1,1,-1))*Matrix4x4.TRS(center-controls.keyLight.transform.forward*1.5f,lightRot,Vector3.one).inverse;
        LightMatrix=GL.GetGPUProjectionMatrix(Matrix4x4.Ortho(-.3f,.3f,-.3f,.3f,.1f,3),true)*view;
        foreach(var d in outlineDraws){d.material.SetFloat("_Width",outlinePixels);d.material.SetColor("_Ink",outlineColor);}
        block??=new MaterialPropertyBlock();
        foreach(var r in controls.surfaces)if(r){r.GetPropertyBlock(block);block.SetFloat("_UseFaceSDF",useSDF?1:0);block.SetFloat("_HairShadowStrength",hairShadowStrength);r.SetPropertyBlock(block);}
    }
}
