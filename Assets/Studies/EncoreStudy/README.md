# Encore · 身体颜色分层 Shader 专题

通过 Shader Graph 与 HLSL Custom Function，将身体颜色遮罩、细节层与角色光照组合在一条可阅读的数据流中。

## 阅读入口

双击 Graph 查看纹理输入和材质参数，再进入同目录 HLSL 阅读颜色合成与光照计算。[EncoreWuthering.shadergraph](Shaders/EncoreWuthering.shadergraph)

当前专题提供一张 Graph 与一个 HLSL 文件，适合结合 Anke、Daiyan 和 Linnae 的场景阅读。

## 技术实现

- 通过 `ColorMask`、`LineMask`、`DetailMask` 组合基础肤色、线条颜色、细节颜色与局部光泽。
- `BodyLayers` 控制颜色层启用，颜色、遮罩强度和细节权重作为独立材质参数暴露。
- 颜色层接入 Toon 明暗、面部 SDF、头发高光、皮肤补偿和环境响应。
- 保留头部空间参数与 Linnae 头发深度纹理接口，供配置了相应角色管线的场景使用。

## 核心文件

| 文件 | 职责 |
| --- | --- |
| [EncoreWuthering.shadergraph](Shaders/EncoreWuthering.shadergraph) | 61 个节点、49 条连线、38 个属性 |
| [EncoreLighting.hlsl](Shaders/EncoreLighting.hlsl) | 颜色遮罩合成与角色光照函数 |

运行时换装可从 Anke 入手，亮暗基底与颜色层可对照 Daiyan，专用阴影与描边可对照 Linnae。[Anke](../AnkeStudy/README.md) · [Daiyan](../DaiyanStudy/README.md) · [Linnae](../LinnaeStudy/README.md)
