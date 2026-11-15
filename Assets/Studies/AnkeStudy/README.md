# Anke · 安可换装与分层着色

围绕同一角色骨架组织两套服装，将亮暗颜色层、角色光照、透明丝袜与换装显隐整合到可交互展示场景中。

## 展示入口

打开场景并进入 Play，左上角选择「第一套 / 第二套」，随后可独立切换服装部件。默认显示第二套。编辑状态可在 `AnkeWardrobe` 中调整 `Selected Outfit` 和部件的 `Visible`。[AnkeShowcase 场景](Scenes/AnkeShowcase.unity)

相机上的 `LinnaeStudyControls` 提供主光方向、强度、阴影柔和度和调试视图。`LinnaeCharacterPipeline` 提供面部 SDF、头发投影与描边开关。

## 技术实现

- 亮面与暗面基底叠加颜色权重、UV 变换和透明遮罩，再接入 `LinnaeLighting.hlsl` 的 Toon 光照、头发高光与环境响应。
- 两套服装使用同一素体骨架。第二套服装的重绑定网格位于 `Models/Outfit2`，保留绑定矩阵以适配服装与身体的骨骼姿态差异。
- 身体材质提供 `Neck Light/Dark Correction`，在头部坐标系的上颈部渐变校色。脸部 SDF 在下颌附近与法线光照平滑融合。
- 丝袜采用 Alpha Blend、关闭 ZWrite，并由 Opacity 贴图控制覆盖率。蕾丝和鞋等部件使用 Alpha Cutout 保留镂空边缘。
- 换装隐藏的 Renderer 同步退出头发深度与描边绘制，避免隐藏部件留下轮廓。

## 核心文件

| 文件 | 职责 |
| --- | --- |
| [Anke.prefab](Prefabs/Anke.prefab) | 素体、骨架与两套服装 |
| [AnkeLinnae.shader](Shaders/AnkeLinnae.shader) | 分层表面、透明裁切、投影和深度 Pass |
| [AnkeWardrobe.cs](Scripts/AnkeWardrobe.cs) | 套装切换与部件显隐 |
| [LinnaeLighting.hlsl](../LinnaeStudy/Shaders/LinnaeLighting.hlsl) | 共享角色光照 |
| [LinnaeCharacterRenderFeature.cs](../LinnaeStudy/Scripts/LinnaeCharacterRenderFeature.cs) | 共享头发深度与描边通道 |

## 编辑器工具

`Tools > Anke Study > Repair Hosiery Transparency` 恢复两套丝袜的透明状态，`Validate Hosiery Transparency` 检查 Blend、深度与队列设置。`Capture Sock Fit` 输出袜子局部多角度视图。

`Repair Sock Clearance` 与 `Restore Original Sock Mesh` 分别调整和恢复袜子网格顶点，使用项目根目录 `Tools/AnkeSockFit` 中的恢复数据。

## 当前展示范围

角色以静态姿态展示，保留表情 BlendShape。面部光照使用 LinnaeStudy 的头部空间 SDF，换装重点为部件组织、蒙皮绑定和材质显示。
