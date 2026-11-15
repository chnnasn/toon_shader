# Liino · 莉诺湿润材质研究

将 NPR 明暗与微表面高光结合，通过湿润、雨滴和浸水参数观察角色材质在不同状态下的响应。

## 展示入口

打开场景并进入 Play，左上角面板可调 `Wetness`、`Rain droplets` 和 `Water level`。`DRY / SOAKED` 切换干湿预设，其他控件用于转台、灯光旋转、技能装备显示和调试视图。编辑状态可在相机的 `LiinoWetnessControls` 上调整相同参数。[LiinoShowcase 场景](Scenes/LiinoShowcase.unity)

## 技术实现

- 柔化 Toon 明暗、GGX 高光、头发双高光、布料纤维高光和环境反射共同描述皮肤、头发、金属与衣料。
- 湿润遮罩使布料颜色加深、粗糙度下降、微表面法线减弱，并驱动丝袜的干湿颜色过渡。
- 基于 UV 生成附着雨滴图案，调整局部法线与高光。`Rain` 控制雨滴强度和湿润贡献。
- 按世界空间高度构造水位边界，与全局湿润、朝向和材质可湿润权重组合。
- SDF 采样结合光线方向生成脸部明暗，再与角色整体光照融合。
- Beauty 加十种分项输出，覆盖底色、法线、材质通道、主光、高光、反射、环境漫反射、湿润遮罩、粗糙度和雨滴。

## 核心文件

| 文件 | 职责 |
| --- | --- |
| [LiinoEndfield.shadergraph](Shaders/LiinoEndfield.shadergraph) | 纹理与参数连接，74 个节点、62 条连线 |
| [LiinoLighting.hlsl](Shaders/LiinoLighting.hlsl) | 光照、湿润、雨滴与水位计算 |
| [LiinoWetnessControls.cs](Scripts/LiinoWetnessControls.cs) | 参数更新、管线切换和运行时面板 |
| [Liino.prefab](Prefabs/Liino.prefab) | 角色预制体 |
| [LiinoPipeline.asset](Rendering/LiinoPipeline.asset) | 专用 Forward 管线配置 |

## 材质参数

衣服 P 贴图按 `R = Metallic`、`A = Smoothness`、`B = AO` 接入，脸部与头发保留独立参数。`_UseRMO`、`_UseRamp`、粗糙度与金属度缩放控制各材质的响应。此通道配置属于当前实现的材质约定。

`Rendering/StudioReflection.asset` 提供摄影棚环境反射，`StudioVolume.asset` 保存后处理配置。场景启用时由控制组件切换到 Liino 管线，停用时恢复其记录的管线配置。

## 当前展示范围

雨滴采用静态附着图案，水位采用世界高度遮罩。展示重点为材质参数联动、局部浸水边界与干湿光照差异，角色使用静态姿态。
