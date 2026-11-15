using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

// Restores the original custom-SRP pass contract on URP 17 RenderGraph.
public sealed class WuchangCharacterRenderFeature : ScriptableRendererFeature
{
    PreDepthPass preDepthPass;
    ReflectionPass reflectionPass;
    StencilShadowPass stencilShadowPass;

    public override void Create()
    {
        reflectionPass = new ReflectionPass();
        preDepthPass = new PreDepthPass();
        stencilShadowPass = new StencilShadowPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        WuchangCharacterPipeline pipeline = Object.FindAnyObjectByType<WuchangCharacterPipeline>();
        if (!pipeline || !pipeline.isActiveAndEnabled)
            return;
        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType != CameraType.Game && cameraType != CameraType.SceneView)
            return;
        pipeline.Prepare();
        reflectionPass.pipeline = pipeline;
        preDepthPass.pipeline = pipeline;
        stencilShadowPass.pipeline = pipeline;
        if (pipeline.reflection)
            renderer.EnqueuePass(reflectionPass);
        if (pipeline.preDepth)
            renderer.EnqueuePass(preDepthPass);
        if (pipeline.stencilHairShadow)
            renderer.EnqueuePass(stencilShadowPass);
    }

    static bool IsVisible(Renderer renderer) => renderer && renderer.enabled &&
        renderer.gameObject.activeInHierarchy && !renderer.forceRenderingOff;

    sealed class PassData
    {
        public WuchangCharacterPipeline pipeline;
    }

    sealed class ReflectionPass : ScriptableRenderPass
    {
        public WuchangCharacterPipeline pipeline;

        public ReflectionPass() => renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            WuchangCharacterPipeline current = pipeline;
            if (!current || current.reflectionDraws.Count == 0)
                return;

            TextureHandle color = renderGraph.CreateTexture(new TextureDesc(1024, 1024)
            {
                name = "Wuchang Planar Character Reflection",
                colorFormat = GraphicsFormat.R16G16B16A16_SFloat,
                clearBuffer = true,
                clearColor = Color.clear,
                filterMode = FilterMode.Bilinear
            });
            TextureHandle depth = renderGraph.CreateTexture(new TextureDesc(1024, 1024)
            {
                name = "Wuchang Planar Character Reflection Depth",
                depthBufferBits = DepthBits.Depth32,
                clearBuffer = true
            });

            using IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<PassData>(
                "Wuchang / Reflection", out PassData passData);
            passData.pipeline = current;
            builder.SetRenderAttachment(color, 0, AccessFlags.Write);
            builder.SetRenderAttachmentDepth(depth, AccessFlags.Write);
            builder.AllowPassCulling(false);
            builder.AllowGlobalStateModification(true);
            builder.SetGlobalTextureAfterPass(color, Shader.PropertyToID("_WuchangReflectionTexture"));
            builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
            {
                context.cmd.SetGlobalMatrix("_WuchangReflectionVP", data.pipeline.ReflectionViewProjection);
                foreach (WuchangCharacterPipeline.Draw draw in data.pipeline.reflectionDraws)
                    if (IsVisible(draw.renderer))
                        context.cmd.DrawRenderer(draw.renderer, draw.material, draw.slot, draw.pass);
            });
        }
    }

    sealed class PreDepthPass : ScriptableRenderPass
    {
        public WuchangCharacterPipeline pipeline;

        public PreDepthPass() => renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            WuchangCharacterPipeline current = pipeline;
            if (!current || current.preDepthDraws.Count == 0)
                return;
            UniversalResourceData resources = frameData.Get<UniversalResourceData>();
            using IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<PassData>(
                "Wuchang / PreDepth", out PassData passData);
            passData.pipeline = current;
            builder.SetRenderAttachmentDepth(resources.activeDepthTexture, AccessFlags.ReadWrite);
            builder.AllowPassCulling(false);
            builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
            {
                foreach (WuchangCharacterPipeline.Draw draw in data.pipeline.preDepthDraws)
                    if (IsVisible(draw.renderer))
                        context.cmd.DrawRenderer(draw.renderer, draw.material, draw.slot, draw.pass);
            });
        }
    }

    sealed class StencilShadowPass : ScriptableRenderPass
    {
        public WuchangCharacterPipeline pipeline;

        public StencilShadowPass() => renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            WuchangCharacterPipeline current = pipeline;
            if (!current || current.hairShadowDraws.Count == 0 || current.faceShadowDraws.Count == 0)
                return;
            UniversalResourceData resources = frameData.Get<UniversalResourceData>();
            using IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<PassData>(
                "Wuchang / Stencil Hair and Face Shadow", out PassData passData);
            passData.pipeline = current;
            builder.SetRenderAttachment(resources.activeColorTexture, 0, AccessFlags.ReadWrite);
            builder.SetRenderAttachmentDepth(resources.activeDepthTexture, AccessFlags.ReadWrite);
            builder.AllowPassCulling(false);
            builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
            {
                // 200 -> IncrSat -> 201, then shade receiver and DecrWrap -> 200.
                foreach (WuchangCharacterPipeline.Draw draw in data.pipeline.hairShadowDraws)
                    if (IsVisible(draw.renderer))
                        context.cmd.DrawRenderer(draw.renderer, draw.material, draw.slot, draw.pass);
                foreach (WuchangCharacterPipeline.Draw draw in data.pipeline.faceShadowDraws)
                    if (IsVisible(draw.renderer))
                        context.cmd.DrawRenderer(draw.renderer, draw.material, draw.slot, draw.pass);
            });
        }
    }
}
