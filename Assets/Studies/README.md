# 角色渲染 Study 索引

每个 Study 集中保存一个角色或专题的着色器、材质与展示入口。建议先打开场景观察效果，再结合调试视图阅读 Shader 和渲染脚本。

## 展示入口

| Study | 场景或着色器入口 | 说明 |
| --- | --- | --- |
| [Anke](AnkeStudy/README.md) | [AnkeShowcase](AnkeStudy/Scenes/AnkeShowcase.unity) | 两套服装、分层颜色、共享骨架 |
| [Brahma Wujian](BrahmaWujianStudy/README.md) | [BrahmaWujianShowcase](BrahmaWujianStudy/Scenes/BrahmaWujianShowcase.unity) | 双形态、毛绒、Stencil 阴影与反射 |
| [Clukay](ClukayStudy/README.md) | [ClukayShowcase](ClukayStudy/Scenes/ClukayShowcase.unity) | 27 种搭配、混合光照与透明衣料 |
| [Daiyan](DaiyanStudy/README.md) | [DaiyanShowcase](DaiyanStudy/Scenes/DaiyanShowcase.unity) | 穿搭交互、亮暗基底与蒙皮描边 |
| [Liino](LiinoStudy/README.md) | [LiinoShowcase](LiinoStudy/Scenes/LiinoShowcase.unity) | 湿润、雨滴、世界高度浸水 |
| [Linnae](LinnaeStudy/README.md) | [LinnaeShowcase](LinnaeStudy/Scenes/LinnaeShowcase.unity) | SDF、头发深度与描边对照 |
| [Wuchang](WuchangStudy/README.md) | [WuchangShowcase](WuchangStudy/Scenes/WuchangShowcase.unity) | 八 Pass 角色渲染与材质对照 |
| [Encore](EncoreStudy/README.md) | [EncoreWuthering](EncoreStudy/Shaders/EncoreWuthering.shadergraph) | 身体颜色分层 Shader 专题 |

## 目录职责

| 目录 | 内容 |
| --- | --- |
| `Scenes` | 可直接打开的展示场景 |
| `Shaders` | 表面 Shader Graph、运行时 Shader 与 HLSL |
| `Scripts` | 交互控制、场景参数和 Renderer Feature |
| `Editor` | 材质修复、构建、校准与验证工具 |
| `Materials` | 展示材质及专用描边材质 |
| `Prefabs` | 角色和道具预制体 |
| `Models` / `Textures` / `SourceArt` | 模型、网格、纹理与材质输入数据 |
| `Rendering` | URP 资产、Renderer、Volume、环境贴图和摄影棚材质 |

## 阅读顺序

1. 从 Linnae 的光照开关和 Liino 的湿润控制观察单个参数对画面的影响。
2. 阅读 Anke、Daiyan 的颜色层、透明度与描边同步，理解模型分件和渲染状态的配合。
3. 对照 Clukay、Wuchang、Brahma 的教学 Graph，跟踪纹理到最终表面的数据流。
4. 进入对应 Multipass Shader、Renderer Feature 与 Pipeline 组件，查看 Pass 顺序、Stencil、深度和反射纹理的使用。

Anke 依赖 LinnaeStudy 的共享光照和角色管线。Wuchang、Brahma 与 Clukay 的 Renderer Feature 配置位于项目共用的 `Assets/Settings/PC_Renderer.asset`。Liino、Linnae、Anke 与 Daiyan 通过场景组件使用相应的专用管线配置。
