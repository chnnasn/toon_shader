using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

// Character-only passes. Native URP 17 RenderGraph; no compatibility-mode fallback.
public sealed class LinnaeCharacterRenderFeature : ScriptableRendererFeature
{
    public static bool IsVisible(Renderer renderer)=>renderer&&renderer.enabled&&renderer.gameObject.activeInHierarchy&&!renderer.forceRenderingOff;
    HairPass hairPass; OutlinePass outlinePass;
    public override void Create(){hairPass=new HairPass();outlinePass=new OutlinePass();}
    public override void AddRenderPasses(ScriptableRenderer renderer,ref RenderingData data)
    {
        var c=Object.FindAnyObjectByType<LinnaeCharacterPipeline>();
        if(!c||!c.isActiveAndEnabled||!c.controls)return;
        if(data.cameraData.cameraType!=CameraType.Game&&data.cameraData.cameraType!=CameraType.SceneView)return;
        hairPass.character=c;outlinePass.character=c;
        renderer.EnqueuePass(hairPass);renderer.EnqueuePass(outlinePass);
    }
    sealed class DrawData {public LinnaeCharacterPipeline character;public Matrix4x4 lightMatrix;public bool hair;}
    sealed class HairPass:ScriptableRenderPass
    {
        public LinnaeCharacterPipeline character;
        public HairPass(){renderPassEvent=RenderPassEvent.BeforeRenderingOpaques;}
        public override void RecordRenderGraph(RenderGraph graph,ContextContainer frameData)
        {
            var c=character;if(!c)return;c.Prepare();
            var tex=graph.CreateTexture(new TextureDesc(1024,1024){name="Linnae Hair Light Depth",colorFormat=GraphicsFormat.R32_SFloat,clearBuffer=true,clearColor=Color.white,filterMode=FilterMode.Bilinear});
            var depth=graph.CreateTexture(new TextureDesc(1024,1024){name="Linnae Hair Z",depthBufferBits=DepthBits.Depth32,clearBuffer=true});
            using(var b=graph.AddRasterRenderPass<DrawData>("Linnae / Hair to face shadow",out var d))
            {
                d.character=c;d.lightMatrix=c.LightMatrix;
                b.SetRenderAttachment(tex,0,AccessFlags.Write);b.SetRenderAttachmentDepth(depth,AccessFlags.Write);
                b.AllowPassCulling(false);b.AllowGlobalStateModification(true);
                b.SetGlobalTextureAfterPass(tex,Shader.PropertyToID("_LinnaeHairDepth"));
                b.SetRenderFunc((DrawData p,RasterGraphContext ctx)=>{
                    ctx.cmd.SetGlobalMatrix("_LinnaeHairWorldToClip",p.lightMatrix);
                    ctx.cmd.SetGlobalFloat("_LinnaeHairShadowActive",p.character.hairShadows?1:0);
                    if(p.character.hairShadows)foreach(var draw in p.character.hairDraws)if(IsVisible(draw.renderer))ctx.cmd.DrawRenderer(draw.renderer,draw.material,draw.slot,0);
                });
            }
        }
    }
    sealed class OutlinePass:ScriptableRenderPass
    {
        public LinnaeCharacterPipeline character;
        public OutlinePass(){renderPassEvent=RenderPassEvent.AfterRenderingOpaques;}
        public override void RecordRenderGraph(RenderGraph graph,ContextContainer frameData)
        {
            var c=character;if(!c||!c.outlines)return;
            var res=frameData.Get<UniversalResourceData>();
            using(var b=graph.AddRasterRenderPass<DrawData>("Linnae / distance controlled ink",out var d))
            {
                d.character=c;b.SetRenderAttachment(res.activeColorTexture,0,AccessFlags.ReadWrite);b.SetRenderAttachmentDepth(res.activeDepthTexture,AccessFlags.ReadWrite);
                b.AllowPassCulling(false);
                b.SetRenderFunc((DrawData p,RasterGraphContext ctx)=>{foreach(var draw in p.character.outlineDraws)if(IsVisible(draw.renderer))ctx.cmd.DrawRenderer(draw.renderer,draw.material,draw.slot,0);});
            }
        }
    }
}
