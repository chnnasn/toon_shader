# Daiyan · 黛烟分层材质与穿搭展示

以亮暗基底和颜色遮罩构建角色表面，结合服装显隐、蒙皮描边与灯光控制，展示材质层次和部件组织。

## 展示入口

打开场景并进入 Play，右侧面板可切换旗袍、内衣、丝袜与内裤、鞋子和耳饰，也可旋转模型、调整主光方位与俯仰。丝袜与内裤共用网格，使用同一个开关。[DaiyanShowcase 场景](Scenes/DaiyanShowcase.unity)

## 技术实现

- 材质分别构建亮面和暗面的颜色层，通过权重遮罩、材质颜色与 Toon 阈值组合出最终表面。
- 身体 Shader 在颈部 UV 区域渐变调整亮面和暗面色彩，衔接脸部与身体。
- 使用相同网格、骨骼与表情数据建立外扩描边层，并按法线朝向筛选轮廓。脸部、身体、头发和衣物使用不同宽度。
- `DaiyanOutlineSync` 同步部件可见性和 BlendShape，服装切换后表面与轮廓保持一致。
- `DaiyanPipelineScope` 管理专用 URP 配置的启用与恢复，交互面板由 UGUI 与 Input System 驱动。

## 核心文件

| 文件 | 职责 |
| --- | --- |
| [Daiyan.prefab](Prefabs/Daiyan.prefab) | 完整展示角色 |
| [DaiyanBody.prefab](Prefabs/DaiyanBody.prefab) | 身体、头发和骨架 |
| [KKBP_01.hlsl](SourceArt/Character/Shaders/KKBP_01.hlsl) | 亮暗颜色层与颈部校色 |
| [DaiyanOutline.shader](Shaders/DaiyanOutline.shader) | 外扩描边与 Alpha 裁切 |
| [DaiyanOutlineSync.cs](Scripts/DaiyanOutlineSync.cs) | 描边显隐与表情同步 |
| [DaiyanWardrobeUI.cs](Scripts/DaiyanWardrobeUI.cs) | 穿搭面板、转台和灯光交互 |

角色模型、表面材质和纹理集中于 `SourceArt/Character`。描边材质位于 `Materials/Outline`，场景管线资产位于 `Rendering`。

## 当前展示范围

此 Study 聚焦静态穿搭、分层材质和轮廓表现。服装开关遵循模型现有的网格分组，可通过 Inspector 调整部件绑定、材质颜色和描边宽度。
