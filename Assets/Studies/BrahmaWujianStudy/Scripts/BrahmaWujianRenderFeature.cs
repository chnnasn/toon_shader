using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

// Replays the original eight-pass state contract recovered from the serialized
// character Uber shader.  Surface lighting remains a behavioral reconstruction.
public sealed class BrahmaWujianRenderFeature : ScriptableRendererFeature
{
    ReflectionPass reflectionPass;
    PreDepthPass preDepthPass;
    AuxiliaryPass outlinePass;
    AuxiliaryPass stencilShadowPass;
    AuxiliaryPass transmissionPass;
    AuxiliaryPass furPass;

    public override void Create()
    {
        reflectionPass = new ReflectionPass();
        preDepthPass = new PreDepthPass();
        outlinePass = new AuxiliaryPass(AuxiliaryKind.Outline, "Brahma Wujian / Outline");
        stencilShadowPass = new AuxiliaryPass(AuxiliaryKind.StencilHairFace,
            "Brahma Wujian / Stencil Hair then Face Shadow");
        transmissionPass = new AuxiliaryPass(AuxiliaryKind.HairTransmission,
            "Brahma Wujian / Hair Transmission");
        furPass = new AuxiliaryPass(AuxiliaryKind.FurShell, "Brahma Wujian / Fur Shells");
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        BrahmaWujianPipeline pipeline = Object.FindAnyObjectByType<BrahmaWujianPipeline>();
        if (!pipeline || !pipeline.isActiveAndEnabled) return;
        CameraType type = renderingData.cameraData.cameraType;
        if (type != CameraType.Game && type != CameraType.SceneView) return;
        pipeline.Prepare(renderingData.cameraData.camera);
        Shader.SetGlobalFloat("_BrahmaReflectionEnabled", pipeline.reflection ? 1 : 0);
        reflectionPass.pipeline = preDepthPass.pipeline = pipeline;
        outlinePass.pipeline = stencilShadowPass.pipeline = transmissionPass.pipeline = furPass.pipeline = pipeline;
        if (pipeline.reflection) renderer.EnqueuePass(reflectionPass);
        if (pipeline.preDepth) renderer.EnqueuePass(preDepthPass);
        if (pipeline.outline && pipeline.outlineDraws.Count > 0)
            renderer.EnqueuePass(outlinePass);
        if (pipeline.stencilHairFaceShadow && pipeline.hairShadowDraws.Count > 0 && pipeline.faceShadowDraws.Count > 0)
            renderer.EnqueuePass(stencilShadowPass);
        if (pipeline.hairTransmission && pipeline.hairTransmissionDraws.Count > 0)
            renderer.EnqueuePass(transmissionPass);
        if (pipeline.furDraws.Count > 0)
            renderer.EnqueuePass(furPass);
    }

    static bool Visible(Renderer renderer) => renderer && renderer.enabled &&
        renderer.gameObject.activeInHierarchy && !renderer.forceRenderingOff;

    sealed class PassData
    {
        public BrahmaWujianPipeline pipeline;
        public Matrix4x4 reflectionVP;
        public AuxiliaryKind kind;
    }

    sealed class ReflectionPass : ScriptableRenderPass
    {
        public BrahmaWujianPipeline pipeline;
        public ReflectionPass() => renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            BrahmaWujianPipeline current = pipeline;
            if (!current || current.reflectionDraws.Count == 0) return;
            var cameraData = frameData.Get<UniversalCameraData>();
            int width = Mathf.Min(1536, cameraData.cameraTargetDescriptor.width);
            int height = Mathf.Max(1, Mathf.RoundToInt(width / cameraData.camera.aspect));
            TextureHandle color = renderGraph.CreateTexture(new TextureDesc(width, height)
            {
                name = "Brahma Wujian Character Reflection",
                colorFormat = GraphicsFormat.R16G16B16A16_SFloat,
                clearBuffer = true, clearColor = Color.clear, filterMode = FilterMode.Bilinear
            });
            TextureHandle depth = renderGraph.CreateTexture(new TextureDesc(width, height)
            {
                name = "Brahma Wujian Reflection Depth", depthBufferBits = DepthBits.Depth32, clearBuffer = true
            });
            using IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<PassData>(
                "Brahma Wujian / Reflection", out PassData data);
            data.pipeline = current;
            data.reflectionVP = current.ReflectionViewProjection;
            builder.SetRenderAttachment(color, 0, AccessFlags.Write);
            builder.SetRenderAttachmentDepth(depth, AccessFlags.Write);
            builder.AllowPassCulling(false);
            builder.AllowGlobalStateModification(true);
            builder.SetGlobalTextureAfterPass(color, Shader.PropertyToID("_BrahmaReflectionTexture"));
            builder.SetRenderFunc((PassData pass, RasterGraphContext context) =>
            {
                context.cmd.SetGlobalMatrix("_BrahmaReflectionVP", pass.reflectionVP);
                context.cmd.SetGlobalVector("_BrahmaReflectionTexelSize", new Vector4(1f / width, 1f / height, width, height));
                foreach (BrahmaWujianPipeline.Draw draw in pass.pipeline.reflectionDraws)
                    if (Visible(draw.renderer)) context.cmd.DrawRenderer(draw.renderer, draw.material, draw.slot, draw.pass);
            });
        }
    }

    sealed class PreDepthPass : ScriptableRenderPass
    {
        public BrahmaWujianPipeline pipeline;
        public PreDepthPass() => renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            BrahmaWujianPipeline current = pipeline;
            if (!current || current.preDepthDraws.Count == 0) return;
            UniversalResourceData resources = frameData.Get<UniversalResourceData>();
            using IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<PassData>(
                "Brahma Wujian / PreDepth", out PassData data);
            data.pipeline = current;
            builder.SetRenderAttachmentDepth(resources.activeDepthTexture, AccessFlags.ReadWrite);
            builder.AllowPassCulling(false);
            builder.AllowGlobalStateModification(true);
            builder.SetRenderFunc((PassData pass, RasterGraphContext context) =>
            {
                foreach (BrahmaWujianPipeline.Draw draw in pass.pipeline.preDepthDraws)
                    if (Visible(draw.renderer)) context.cmd.DrawRenderer(draw.renderer, draw.material, draw.slot, draw.pass);
            });
        }
    }

    enum AuxiliaryKind
    {
        Outline,
        StencilHairFace,
        HairTransmission,
        FurShell
    }

    sealed class AuxiliaryPass : ScriptableRenderPass
    {
        public BrahmaWujianPipeline pipeline;
        readonly AuxiliaryKind kind;
        readonly string profilerName;

        public AuxiliaryPass(AuxiliaryKind kind, string profilerName)
        {
            this.kind = kind;
            this.profilerName = profilerName;
            renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            BrahmaWujianPipeline current = pipeline;
            if (!current) return;
            UniversalResourceData resources = frameData.Get<UniversalResourceData>();
            using IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<PassData>(
                profilerName, out PassData data);
            data.pipeline = current;
            data.kind = kind;
            builder.SetRenderAttachment(resources.activeColorTexture, 0, AccessFlags.ReadWrite);
            builder.SetRenderAttachmentDepth(resources.activeDepthTexture, AccessFlags.ReadWrite);
            builder.AllowPassCulling(false);
            builder.AllowGlobalStateModification(true);
            builder.SetRenderFunc((PassData pass, RasterGraphContext context) =>
            {
                switch (pass.kind)
                {
                    case AuxiliaryKind.Outline:
                        Draw(context, pass.pipeline.outlineDraws);
                        break;
                    case AuxiliaryKind.StencilHairFace:
                        // Recovered custom-SRP contract: ForwardBase writes 200 on the face;
                        // bangs test 200 and IncrSat to 201, then face tests 201, shades and
                        // DecrWraps to 200. The two lists must remain in this exact order.
                        Draw(context, pass.pipeline.hairShadowDraws);
                        Draw(context, pass.pipeline.faceShadowDraws);
                        break;
                    case AuxiliaryKind.HairTransmission:
                        Draw(context, pass.pipeline.hairTransmissionDraws);
                        break;
                    case AuxiliaryKind.FurShell:
                        for (int layer = 1; layer <= pass.pipeline.furLayers; layer++)
                        {
                            context.cmd.SetGlobalFloat("_BrahmaFurLayer", layer / (float)pass.pipeline.furLayers);
                            Draw(context, pass.pipeline.furDraws);
                        }
                        break;
                }
            });
        }

        static void Draw(RasterGraphContext context, System.Collections.Generic.List<BrahmaWujianPipeline.Draw> draws)
        {
            foreach (BrahmaWujianPipeline.Draw draw in draws)
                if (Visible(draw.renderer)) context.cmd.DrawRenderer(draw.renderer, draw.material, draw.slot, draw.pass);
        }
    }
}
