# Liino · 莉诺湿润材质研究

将 NPR 明暗与微表面高光结合，通过湿润、雨滴和浸水参数观察角色材质在不同状态下的响应。

## 展示入口

场景默认展示雨中的半身近景。进入 Play 后，可用 `Full`、`Hair`、`Stockings` 切换全身、头部和丝袜特写。`DRY / SOAKED` 在当前机位切换干湿，`Wetness`、`Rain droplets` 和 `Water level` 分别控制表面湿度、雨量和浸水高度。编辑状态可在相机的 `LiinoWetnessControls` 上调整相同参数。[LiinoShowcase 场景](Scenes/LiinoShowcase.unity)

## 技术实现

- 脸、耳、颈胸和四肢共用暖肤色与受光过渡。脸部用 SDF 控制转面，虹膜保留贴图中的星形亮部。刘海上的弧形高光由发束贴图打散。
- 衣料保留染色底色，湿度轻微调整粗糙度和吸光。丝袜保留深色基底，沿腿形出现随视角和灯光变化的宽反射带。
- 在随角色平移和水平转动的坐标中生成水珠。朝上的表面蓄珠，侧面上较大的水珠沿重力方向滑动，身后留下一段逐渐变细的水痕。水珠法线单独参与反射。
- 按世界空间高度构造水位边界，与全局湿润、朝向和材质可湿润权重组合。
- SDF 采样结合光线方向生成脸部明暗，再与角色整体光照融合。
- Beauty 加十种分项输出，覆盖底色、法线、材质通道、主光、高光、反射、环境漫反射、湿润遮罩、粗糙度和雨滴。

## 核心文件

| 文件 | 职责 |
| --- | --- |
| [LiinoEndfield.shadergraph](Shaders/LiinoEndfield.shadergraph) | 纹理、材质分支与光照函数的连接 |
| [LiinoLighting.hlsl](Shaders/LiinoLighting.hlsl) | 光照、湿润、雨滴与水位计算 |
| [LiinoRain.hlsl](Shaders/LiinoRain.hlsl) | 水珠生长、向下滑动的水滴与水痕法线 |
| [LiinoWetnessControls.cs](Scripts/LiinoWetnessControls.cs) | 参数更新、管线切换和运行时面板 |
| [Liino.prefab](Prefabs/Liino.prefab) | 角色预制体 |
| [LiinoPipeline.asset](Rendering/LiinoPipeline.asset) | 专用 Forward 管线配置 |

## 材质参数

衣服 P 贴图按 `R = Metallic`、`A = Smoothness`、`B = AO` 接入，脸部与头发保留独立参数。`_UseRMO`、`_UseRamp`、粗糙度与金属度缩放控制各材质的响应。此通道配置属于当前实现的材质约定。

`Rendering/StudioReflection.asset` 提供摄影棚环境反射，`StudioVolume.asset` 保存后处理配置。场景启用时由控制组件切换到 Liino 管线，停用时恢复其记录的管线配置。

## 当前展示范围

角色使用静态姿态。进入 Play 可观察水珠随时间变化。调试视图 8 显示湿润遮罩，视图 10 的红、绿通道分别显示水珠和拖尾。
