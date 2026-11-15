# Clukay · 可露凯「无瑕侍礼」渲染与换装

将 NPR / PBR 混合光照、透明服装、头发高光和部件换装组合为交互式角色展示。上衣、下装、腿部各提供三种选择，共 27 种搭配，并支持 Summer416 道具显示。

## 展示入口

打开场景并进入 Play，右侧面板提供部件切换、模型转台、主光旋转、枪械显隐、搭配保存与读取，以及十种渲染查看模式。[ClukayShowcase 场景](Scenes/ClukayShowcase.unity)

![可露凯场景预览](../../../Tools/Clukay/ClukayPreview.png)

## 技术实现

- Toon 漫反射结合 GGX 高光、环境反射、皮肤包裹光和布料 sheen，分别控制皮肤、布料、金属与头发。
- RMO 采用 `R = Roughness`、`G = Metallic`、`B = AO`。头发通过遮罩和 UV 导数方向构建各向异性高光。
- 薄纱与蕾丝采用显式透明队列，细节层在主体薄纱之后绘制。Opaque、Cutout 和 Transparent 材质独立设置混合、深度与投影状态。
- 脸部使用几何明暗柔化与包裹漫反射，配合独立参数调整面部阴影。
- 眼部加色与乘色使用专用 Shader。Summer416 采用独立材质响应，分别处理枪身和透明部件。
- 调试视图覆盖底色、法线、RMO、主光、高光、环境反射、环境漫反射、透明度与完整着色。

## 核心文件

| 文件 | 职责 |
| --- | --- |
| [ClukaySurface.shadergraph](Shaders/ClukaySurface.shadergraph) | 89 个普通节点、100 条连线、七个有序分组的教学 Graph |
| [ClukayCharacter.shader](Shaders/ClukayCharacter.shader) | ForwardBase、Outline、ShadowCaster、DepthOnly、DepthNormalsOnly |
| [ClukayCharacterCommon.hlsl](Shaders/ClukayCharacterCommon.hlsl) | 光照函数、顶点处理与公共 Pass 实现 |
| [RecoveredEyeBlend.shader](Shaders/RecoveredEyeBlend.shader) | 眼部加色和乘色混合 |
| [ClukayGun.shader](Shaders/ClukayGun.shader) | Summer416 材质 |
| [ClukayRenderFeature.cs](Scripts/ClukayRenderFeature.cs) | 私有 Outline Pass 调度 |
| [ClukayWardrobe.cs](Scripts/ClukayWardrobe.cs) | 换装、转台、灯光和调试界面 |

教学 Graph 按纹理与 Alpha、Toon Ramp、Rim、RMO 与高光、头发、丝袜与薄纱、脸部柔化的顺序展示表面计算。运行时材质使用 Multipass Shader，Renderer Feature 负责描边调度。`OriginalShader` 保存 BRDF 对照实现，便于阅读不同的材质响应。

正式材质位于 `Materials`，模型、换装网格与纹理位于 `SourceArt`，枪械预制体位于 `Prefabs`。环境反射、Volume 和界面图片位于 `Rendering`。

## 编辑器工具

在 `Tools > Studies > Clukay` 中可使用以下菜单。

| 菜单 | 功能 |
| --- | --- |
| `Open Showcase` | 打开展示场景 |
| `Render Preview` | 生成场景预览 |
| `Render Summer416 Close-up` | 生成枪械近景 |
| `Render P3 Skirt Close-up` | 生成第三套下装近景 |
| `Repair Transparent Wardrobe Materials` | 恢复薄纱和蕾丝的透明状态 |
| `Validate Study Contract` | 检查 Shader、Graph、材质、Renderer Feature 和目录约定 |

截图菜单输出到项目根目录 `.tmp`。README 预览保存在 `Tools/Clukay`。教学 Graph 的生成脚本位于 `Tools/ShaderGraphs/build_clukay_teaching_graph.py`，执行会重新生成 Graph 内容。

## 当前展示范围

角色以固定姿态呈现换装组合，面部使用柔化光照。透明衣料的层次由网格分组、材质覆盖率与绘制队列共同控制。
