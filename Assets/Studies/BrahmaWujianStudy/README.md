# 三相·梵天「无间玩伴」渲染研究

本目录是基于本机《深空之眼》发布资源制作的 Unity 6 / URP 17 学习场景。两个资源形态均已隔离导入：

- `102003`：浅蓝 T 恤、猫耳耳机、长袜形态。
- `605603`：白色针织衫、眼镜/头饰、黑白非对称袜与武器附件形态。

## 主要入口

- 场景：`Scenes/BrahmaWujianShowcase.unity`
- 两个清理后的研究 Prefab：`Prefabs/Brahma_Wujian_102003.prefab`、`Prefabs/Brahma_Wujian_605603.prefab`
- WuchangStudy 风格自包含源资源：`SourceArt/102003`、`SourceArt/605603`
- 教学 Shader Graph：`Shaders/BrahmaSurface.shadergraph`。它由 89 个普通节点、100 条连线和 7 个有序分组组成，0 个 Custom Function；可以从 Base/Mask 一路读到 Toon、Rim、Specular、Hair、Stocking、Face SDF 和最终合成。
- `Shaders/BrahmaCharacter.shader` 是唯一的角色运行时 Multipass Shader，实现原角色八个基础 Pass，并增加 FurShell 毛绒层。
- `Shaders/BrahmaCharacterCommon.hlsl` 仅承载 Shader Graph 无法表达的原 SRP 固定 Pass、Stencil 与运行时光照函数，不再被伪装成一个巨型 Graph 节点。
- Studio Floor / Sky 已移到 `Rendering`，不与角色 Shader 混在同一目录。
- URP 17 RenderGraph Feature：`Scripts/BrahmaWujianRenderFeature.cs`
- 场景级 Pass 收集与头部/反射矩阵：`Scripts/BrahmaWujianPipeline.cs`
- 可重复构建器：`Editor/BrahmaWujianStudyBuilder.cs`
- 预览：`Tools/AetherGazerResearch/BrahmaWujianPreview.png`

Unity 菜单：

1. `Tools/Studies/Brahma Wujian/Build Two-Form Study`
2. `Tools/Studies/Brahma Wujian/Render Preview`
3. `Tools/Studies/Brahma Wujian/Apply Screenshot Calibration` 将参考灯光、环境反射和材质参数应用到当前展示场景并保存。
4. `Tools/Studies/Brahma Wujian/Render Reference Views` 输出两套形态的正面、侧面、背面、三分之四视角、上半身与腿部近景，保存在 `Rendering/Brahma_Wujian_<ID>_*.png`。
5. `Tools/Studies/Brahma Wujian/Validate Rendering` 编译材质 Pass，并在 `.tmp` 中生成反射和补光开关对照。

## 发布 Shader 状态记录

发布包中可恢复的是序列化 Shader、材质属性、关键字和 Pass 状态，不是开发期可编辑 Shader 源码。原始 AssetRipper 导出、输入包、Shader TypeTree、日志与导入清单已按用户要求从项目删除；下面是删除前已落实到实现中的 Pass 状态摘要，不再附带原始证据包。

恢复到的角色 Uber Shader 有 155 个属性和以下八个 Pass。机器可读状态契约位于 `OriginalShader/CharacterPBRUber.PassContract.json`：

| 顺序 | Pass | 本研究对应实现 |
|---:|---|---|
| 0 | ForwardBase | URP `UniversalForward`，材质 Stencil 写入 |
| 1 | Outline | `Blend SrcAlpha OneMinusSrcAlpha`、`ZTest Less`、`ZWrite On`、`Cull Front` |
| 2 | CharHairShadow | `ColorMask 0`、`ZWrite Off`、Equal、IncrSat |
| 3 | CharFaceShadow | `ZWrite Off`、Equal、DecrWrap |
| 4 | CharHairTransE | 刘海透射混合 |
| 5 | ShadowCaster | URP 阴影投射 |
| 6 | Reflection | `ZWrite On`、`ZTest LEqual`、`Cull Front`，独立反射 RT |
| 7 | PreDepth | `ColorMask 0`、`ZWrite On`、`ZTest LEqual` |

Stencil 循环按原状态复现：脸部 Forward 写 `200`，刘海阴影在 Equal 200 时执行 IncrSat 到 `201`，脸部接收 Pass 在 Equal 201 时着色并 DecrWrap 回 `200`。102003 刘海偏移采用原材质记录的 `X=0.0037`、`Y=0.00778`。Opaque 材质队列与原包一致为 `Geometry+10`。

URP 17 Renderer Feature 把 `Reflection`、`PreDepth`、`Outline`、Stencil 头发/脸部阴影、Hair Transmission 和 Fur Shell 拆成独立 RenderGraph Pass。Reflection 在 `BeforeRenderingPrePasses`，PreDepth 在 `BeforeRenderingOpaques`；Stencil Pass 严格先画刘海再画脸部接收面。菜单 `Tools/Studies/Brahma Wujian/Validate Original Shader Contract` 会检查八个原 Pass 的顺序、固定状态、教学 Graph 不含 Custom Function、七个教学分组、材质 Stencil 值以及 Renderer Feature 是否唯一启用。

原始自定义 SRP 的 `LightMode` 名称只记录在 `OriginalShader/CharacterPBRUber.PassContract.json` 中；URP 运行时包装器对所有手动调度的辅助 Pass 使用 `Brahma*` 私有标签。不能直接把原版 `Always` / `Reflection` / `PreDepth` 标签照搬进 URP，否则 URP 会把它们纳入自己的 pass 选择并产生错误材质（洋红）。Pass 名、顺序、Blend / ZTest / ZWrite / Cull / Stencil 固定状态仍按原版契约保留。

## 截图标定内容

用户提供的正面、侧面、背面及腿部近景用于校准以下视觉特征：

- 发丝从浅灰蓝到高饱和蓝紫的渐变、星点与各向异性高光。
- 浅色皮肤的低对比 Toon 阴影和脸部 SDF 光向切换。
- 白色针织纹理、毛绒边缘、青色服装与饰件。
- 白色网袜和黑色丝袜的非对称配置及视角衰减。
- 中性主光、冷色补光、三色环境光与柔光箱 Cubemap 反射。
- 灰蓝渐变背景、细点地面、软阴影，以及强度 0.12 的模糊平面反射。
- 瞳孔读取原 `_MainTex`，眼部高光读取蒙版。605603 的 `clothes01` 对应透明镜片，`clothes02`、`clothes03` 对应毛绒部件。
- 每个角色独立传入头部朝向，导出骨骼的局部 +Y 对应面向，+Z 对应右侧。

`Editor/BrahmaReferenceCalibration.cs` 保存上述校准入口。灯光参数为主光强度 1.08、欧拉角 (42, -24, 0)，补光强度 0.36、欧拉角 (15, 135, 0)。参考预览使用双倍分辨率渲染后缩采样。当前灯光数值由截图标定，未恢复到游戏展示场景的原始灯光配置。

`BrahmaSurface.shadergraph` 只保留 25 个真正参与教学数据流的参数，不再把 80 个属性连到一个 63 端口 Custom Function。Graph 分为七段：`Base Texture & Alpha → Toon Diffuse & Ramp → Rim → Specular & RMO → Hair Anisotropy → Stocking → Face SDF & Final Combine`。原游戏的 Outline、Stencil、Reflection、PreDepth 是 Pass/管线行为，不属于 Surface 数学，因此只在 `BrahmaCharacter.shader`、`BrahmaCharacterCommon.hlsl` 与 Renderer Feature 中各保留一份实现，不再创建四个重复 Shader Graph。

## 一致性边界

- Pass 名称、顺序、固定功能状态、关键材质 Stencil 值和发布材质纹理绑定有序列化证据，可以逐项核验。
- 光照函数是根据发布材质参数、纹理通道和参考截图制作的行为重建；由于发布包不含开发期 HLSL/Shader Graph 源码，不能声称指令级完全相同。
- 原 Prefab 中无法解析的游戏专用 MonoBehaviour 已从研究副本移除。
- 武器节点和 `auto_*` UI 锚点已从 `SourceArt/<ID>` 与最终 Prefab/场景中移除。
- `SourceArt/AssetBundles` 与 Brahma 专属 AssetRipper 证据包已删除；当前模型、Mesh、Texture 和材质引用均指向自包含的 `SourceArt/102003`、`SourceArt/605603`。
- 倒壳 Outline 在身体和衣服上启用，头发采用着色器边缘染色。毛绒以 24 层 FurShell 模拟，可通过 `BrahmaWujianPipeline.furLayers` 调整。

本项目用于个人渲染技术学习与研究；请勿重新分发游戏资源或将其用于商业用途。
