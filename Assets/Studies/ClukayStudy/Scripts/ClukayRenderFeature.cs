using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public sealed class ClukayRenderFeature : ScriptableRendererFeature
{
    OutlinePass outlinePass;

    public override void Create()
    {
        outlinePass = new OutlinePass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        CameraType type = renderingData.cameraData.cameraType;
        if (type == CameraType.Game || type == CameraType.SceneView)
            renderer.EnqueuePass(outlinePass);
    }

    sealed class OutlinePass : ScriptableRenderPass
    {
        static readonly ShaderTagId OutlineTag = new ShaderTagId("ClukayOutline");

        sealed class PassData
        {
            public RendererListHandle rendererList;
        }

        public OutlinePass()
        {
            renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var resources = frameData.Get<UniversalResourceData>();
            var rendering = frameData.Get<UniversalRenderingData>();
            var camera = frameData.Get<UniversalCameraData>();
            var lights = frameData.Get<UniversalLightData>();
            DrawingSettings drawing = RenderingUtils.CreateDrawingSettings(
                OutlineTag, rendering, camera, lights, SortingCriteria.CommonOpaque);
            var filtering = new FilteringSettings(RenderQueueRange.all);
            var parameters = new RendererListParams(rendering.cullResults, drawing, filtering);
            using var builder = renderGraph.AddRasterRenderPass<PassData>("Clukay / Outline", out var data);
            data.rendererList = renderGraph.CreateRendererList(parameters);
            builder.UseRendererList(data.rendererList);
            builder.SetRenderAttachment(resources.activeColorTexture, 0, AccessFlags.ReadWrite);
            builder.SetRenderAttachmentDepth(resources.activeDepthTexture, AccessFlags.ReadWrite);
            builder.SetRenderFunc((PassData pass, RasterGraphContext context) =>
                context.cmd.DrawRendererList(pass.rendererList));
        }
    }
}
