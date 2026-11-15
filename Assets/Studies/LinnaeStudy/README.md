# Linnae · 琳奈角色光照与专用阴影

围绕面部 SDF、刘海投脸阴影和细轮廓构建角色渲染流程，通过独立开关观察各效果对最终画面的贡献。

## 展示入口

打开场景并进入 Play，左上角可调整主光方向、强度与阴影柔和度，切换底色、明暗分区、法线、高光和刘海阴影输出。`Face SDF`、`Hair to face shadow`、`Character outlines` 控制三个主要效果。[LinnaeShowcase 场景](Scenes/LinnaeShowcase.unity)

编辑状态可在相机的 `LinnaeStudyControls` 和 `LinnaeCharacterPipeline` 上调整相同参数。

## 技术实现

- 1024² RGBA 面部距离场对应 0°、45°、90°、135° 光照角度，并在头部空间按光向插值。鼻口与脸部使用统一的头部投影坐标，减少 UV 岛边界造成的阴影断层。
- Renderer Feature 在不透明绘制前生成 1024² 头发光空间深度，脸部通过 3×3 PCF 接收刘海阴影，并对下沿进行高度渐隐。
- 在不透明绘制后绘制反向壳轮廓，通过屏幕空间宽度控制和头发深度偏移减少细碎内部线条。
- HLSL Custom Function 组合柔和 Toon 明暗、冷暖阴影、UV 导数方向的发丝高光、皮肤暖色补偿、金属高光和环境光。
- 运行时传递头部朝向与位置，使 SDF 和头发阴影随角色头部姿态更新。

## 核心文件

| 文件 | 职责 |
| --- | --- |
| [LinnaeWuthering.shadergraph](Shaders/LinnaeWuthering.shadergraph) | 纹理与光照参数连接，49 个节点、37 条连线 |
| [LinnaeLighting.hlsl](Shaders/LinnaeLighting.hlsl) | 表面光照、SDF 与头发阴影采样 |
| [LinnaeHairDepth.shader](Shaders/LinnaeHairDepth.shader) | 头发光空间深度 |
| [LinnaeInk.shader](Shaders/LinnaeInk.shader) | 屏幕空间宽度的描边 |
| [LinnaeCharacterRenderFeature.cs](Scripts/LinnaeCharacterRenderFeature.cs) | RenderGraph 通道调度 |
| [LinnaeCharacterPipeline.cs](Scripts/LinnaeCharacterPipeline.cs) | 绘制列表、矩阵、效果开关与管线管理 |
| [LinnaeFaceSDF.png](Textures/LinnaeFaceSDF.png) | 四通道面部距离场 |
| [Linnae.prefab](Prefabs/Linnae.prefab) | 角色预制体 |

## 管线与复用

`Rendering/LinnaeURP.asset` 与 `LinnaeRenderer.asset` 保存专用 URP 配置。场景组件启用时设置 Quality 管线，停用时恢复此前配置。自定义绘制检查 Renderer 的显隐状态，支持服装部件动态隐藏。

AnkeStudy 复用本 Study 的光照、SDF、控制脚本与 Renderer Feature，可对照两种材质输入如何接入同一套角色光照。

## 当前展示范围

角色以静态姿态提供光照与材质观察，保留骨骼和表情 BlendShape。SDF 使用项目构建的距离场，金属度和粗糙度按材质槽调校。
