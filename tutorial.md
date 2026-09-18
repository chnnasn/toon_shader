# 角色渲染学习项目课程大纲

## 项目用途与学习目标

本仓库用多个角色 Study 对比不同的二次元角色渲染路线。学习目标不是记住某个角色的参数，而是理解一张角色最终画面如何从「贴图数据 → 法线与光照 → NPR/PBR 材质响应 → 角色专用阴影与描边 → URP 输出」逐步形成，并能判断每个 Study 解决了哪一层问题。

## 源码版本与工作区状态

- Unity：`6000.4.7f1`。
- Universal Render Pipeline / Shader Graph：`17.4.0`。
- 本次阅读时 Git 工作区没有已列出的文件改动；本文件是新增学习材料。
- 结论以当前 `Assets/Studies` 实现为准。各 README 中已经明确标出的“独立重建”“研究假设”和“未恢复部分”，不能表述成原游戏的确定实现。

## 前置基础

- 向量点积、Half-Lambert、`smoothstep` 阈值分层。
- 法线贴图、切线空间、`ddx/ddy` 导数重建切线基。
- Blinn-Phong/Kajiya-Kay 与微表面 BRDF（GGX、Smith、Schlick Fresnel）。
- URP 主光、附加光、球谐环境光、反射探针和阴影坐标。
- Shader Graph Custom Function、Scriptable Renderer Feature、RenderGraph。

## 覆盖范围与未覆盖模块

覆盖 Anke、Clukay、Daiyan、Liino、Linnae、Encore 六组 Study 的核心着色路径，以及 Linnae 的头发投脸阴影和描边通道。暂不展开模型导入、换装 UI、动画/蒙皮修复、编辑器构建脚本、截图工具与资源清理流程；这些内容不改变本次渲染原理结论。

---

## 第 1 课：所有 Study 共用的 NPR 基线是什么？（大纲）

读完能回答：二次元角色为什么仍然受真实灯光影响，却能得到清晰、可控的明暗块？

主链：场景 Directional Light → URP 获取主光与阴影 → `N·L`/Half-Lambert → `smoothstep` 形成软阈值色阶 → 明暗色插值 → 高光、环境光和边缘光补充 → Shader Graph 通过 Emission 输出自定义光照。

1. 必读 `Assets/Studies/ClukayStudy/Shaders/ClukayLighting.hlsl` 的 `ClukayLighting_float`：输入颜色、法线、RMO 与世界空间数据；下一步计算主光与 Half-Lambert；输出基础 NPR 颜色和 Alpha。
2. 必读 `Assets/Studies/LinnaeStudy/Shaders/LinnaeLighting.hlsl` 的 `LinnaeLighting_float`：输入材质分类开关；下一步在同一函数中选择脸、发、皮肤、眼睛分支；输出统一的角色颜色。
3. 选读各 `.shadergraph`：确认纹理和材质参数如何送进 Custom Function，以及自定义结果如何接到 Master Stack。

重要分支：脸部会弱化几何阴影；头发会把普通高光替换成发丝亮带；金属减少漫反射；眼睛更接近稳定的贴图色。

暂缓：微表面 BRDF 由第 3 课负责，脸部 SDF 和专用 Pass 由第 4、5 课负责。

---

## 第 2 课：Daiyan 与 Anke 如何用“预绘制明暗底色”保留原材质设计？（大纲）

读完能回答：为什么这两组工程不是单纯拿 Base Map 乘一条光照曲线？

主链：LightBase/DarkBase → 多张颜色权重遮罩叠加可编辑色层 → 主光阈值选择亮/暗结果 → 局部颈部校色 → Alpha 裁切/混合 → 表面与描边分别绘制。

1. 必读 `Assets/Studies/DaiyanStudy/SourceArt/Character/Shaders/KKBP_01.hlsl` 的 `KKBPColor_float`：输入亮暗基底、十张权重图和颜色参数；下一步先分别合成亮面与暗面；输出 Toon 阈值选择后的颜色。
2. 必读同文件的 `neckJoin` 分支：输入身体 UV；下一步只在颈部上缘生成渐变权重；输出局部亮/暗校正，避免改坏肩部和身体其他区域。
3. 必读 `Assets/Studies/AnkeStudy/Shaders/AnkeLinnae.shader` 的 Forward Pass：输入与 Daiyan 相同的分层颜色；下一步用局部校色构造 `shadowTint`，再调用 `LinnaeLighting_float`；输出“原始分层配色 + Linnae 风格光照”。
4. 选读 `Assets/Studies/DaiyanStudy/Shaders/DaiyanOutline.shader`：验证按法线外扩、只保留背向观察者片元、按源 Alpha 裁切的轮廓方式。

重要分支：Anke 的 Cutout 会写深度并投影；透明薄纱 Blend 分支不写深度，也不投射实体剪影阴影。

暂缓：Anke 复用的 SDF、头发深度和屏幕恒定描边由第 4、5 课解释。

---

## 第 3 课：Clukay 与 Liino 如何混合 NPR 和 PBR？（大纲）

读完能回答：卡通明暗、金属反射、布料光泽和头发亮带为什么可以共存，而不会互相重复计光？

主链：法线/RMO → 导数切线基重建法线 → NPR 漫反射色阶 → GGX 直接高光 → 发丝双瓣高光/布料 sheen → 球谐间接漫反射与反射探针 → Rim → Emission 输出。

1. 必读 `Assets/Studies/ClukayStudy/Hybrid/Shaders/ClukayHybridLighting.hlsl` 的 `ClukayHybridLight`：输入一盏灯及材质参数；下一步分别算 GGX、高光、卡通漫反射、皮肤包裹光和 sheen；输出单灯贡献。
2. 必读同文件的 `ClukayLighting_float`：输入主光、附加光、环境数据；下一步累加各灯并调用 URP 环境 BRDF；输出完整混合光照。
3. 对照 `Assets/Studies/ClukayStudy/Shaders/ClukayLighting.hlsl`：观察较早版本如何使用简化高光、柔化脸部几何阴影，以及为什么它不应被称为脸部 SDF。
4. 进阶读 `Assets/Studies/ClukayStudy/Wardrobe/Shaders/GF2SourceBRDF.hlsl` 的 `GF2MainBRDF`、`GF2DiffuseRamp`、`GF2EnvironmentBRDF`：观察 Ramp 如何分别塑造漫反射、高光和环境响应。
5. 必读 `Assets/Studies/LiinoStudy/Shaders/LiinoLighting.hlsl` 的 `LiinoHybridLight` 与 `LiinoLighting_float`：它继承混合框架，再加入 SDF、湿润、雨滴、浸水和丝袜颜色变化。

重要分支：金属区令漫反射趋零；头发以 UV 导出的发丝方向取代各向同性 GGX；透明覆盖率加入 Fresnel，但仍受透明排序约束。

暂缓：Liino 的动态湿润细节归第 6 课。

---

## 第 4 课：Linnae 与 Encore 的脸部 SDF 为什么比直接使用面法线稳定？（大纲）

读完能回答：角色转头或光线绕头旋转时，脸部阴影如何保持美术设计的形状？

主链：头部 Forward/Right/Up → 把主光转换到头部局部方向 → 根据左右侧镜像采样 → 按光照角度在四个 SDF 通道间插值 → 以 0.5 阈值生成脸部亮暗区域 → 与身体法线光照按材质权重融合。

1. 必读 `Assets/Studies/LinnaeStudy/Shaders/LinnaeLighting.hlsl` 的 `faceUV`、`distances`、`angle`、`sdfBand` 段：输入世界位置、头部基向量与四通道 SDF；下一步在统一头骨投影中查表；输出脸部明暗权重。
2. 对照 `Assets/Studies/LiinoStudy/Shaders/LiinoLighting.hlsl` 的 `faceBand`：理解单通道 SDF + 左右镜像 + 光向阈值的较简实现。
3. 必读 `Assets/Studies/EncoreStudy/Shaders/EncoreLighting.hlsl` 的 `EncoreLighting_float`：其主体继承 Linnae 路线，但在光照前加入 ColorMask/LineMask/DetailMask 的身体分层颜色合成。
4. 选读 `Assets/Studies/LinnaeStudy/Textures/LinnaeFaceSDF.png`：结合 README 理解 RGBA 分别代表多个光照角度，而不是普通颜色贴图。

重要分支：没有真实 SDF 的 Study 只做脸部软化，不能等价为 SDF；Linnae 的 SDF 是本项目重建数据，不是原游戏资源。

暂缓：刘海投脸阴影是另一张动态深度图，不属于 SDF 本身，由第 5 课负责。

---

## 第 5 课：角色专用 Renderer Feature 如何补足单个材质做不到的效果？（大纲）

读完能回答：为什么刘海投脸阴影和稳定像素宽描边需要额外渲染 Pass？

主链：`LinnaeCharacterPipeline` 切换专用 URP 资产 → `LinnaeCharacterRenderFeature` 注册 Pass → 不透明物体前从光源方向绘制头发深度 → 脸部以 3×3 PCF 比较接收阴影 → 不透明物体后重绘反向壳 → 得到刘海阴影和近似恒定像素宽描边。

1. 必读 `Assets/Studies/LinnaeStudy/Scripts/LinnaeCharacterPipeline.cs`：输入场景启停；下一步替换/恢复 Quality Render Pipeline；输出带专用 Renderer Feature 的场景作用域。
2. 必读 `Assets/Studies/LinnaeStudy/Scripts/LinnaeCharacterRenderFeature.cs` 的 `HairPass`：输入登记的头发 Renderer；下一步创建 1024² R32 深度纹理并设置全局矩阵/纹理；输出脸部可采样的光源空间头发深度。
3. 必读 `Assets/Studies/LinnaeStudy/Shaders/LinnaeHairDepth.shader`：输入头发位置和 Alpha；下一步 Alpha Clip；输出光源空间深度。
4. 回到 `LinnaeLighting_float` 的 3×3 循环：输入接收点深度；下一步 PCF 比较并在脸部下沿渐隐；输出 `hairOcclusion`。
5. 必读 `LinnaeCharacterRenderFeature.cs` 的 `OutlinePass` 与 `Assets/Studies/LinnaeStudy/Shaders/LinnaeInk.shader`：输入角色 Renderer；下一步剔除正面、在裁剪空间沿投影法线偏移；输出随距离修正的细轮廓。

重要分支：隐藏或禁用的 Renderer 不参加自定义通道，避免换装后残留描边；头发描边有深度偏移，用来减少内部碎线。

暂缓：传统世界空间外扩描边已在第 2 课以 Daiyan 为对照。

---

## 第 6 课：Liino 的湿润、雨滴与浸水如何改变材质而不只是叠一层颜色？（大纲）

读完能回答：湿材质为什么同时变暗、变光滑、法线变平，并且只在特定高度或雨淋区域生效？

主链：全局 Wetness/Rain/WaterHeight → UV 哈希雨滴 + 世界高度浸水遮罩 → 合并为 wet 权重 → Base Color 变暗、粗糙度降低、法线强度减弱、高光增强、sheen 减弱 → 丝袜在干湿颜色间插值 → 输出可调试的动态材质状态。

1. 必读 `Assets/Studies/LiinoStudy/Scripts/LiinoWetnessControls.cs`：输入运行时 UI/Inspector 参数；下一步写入角色材质实例；输出可交互湿润状态。
2. 必读 `Assets/Studies/LiinoStudy/Shaders/LiinoLighting.hlsl` 中 `drop`、`water`、`wet` 的计算：输入 UV、世界高度和表面朝上程度；下一步合成局部遮罩；输出湿润权重。
3. 继续读同文件的法线、`rough`、`base`、`SpecularStrength`、`Sheen` 分支：输入湿润权重；下一步联动多个材质维度；输出比“颜色覆盖层”更可信的湿表面响应。
4. 选读 `Assets/Studies/LiinoStudy/README.md` 的证据与推断边界：确认哪些参数名来自源材质，哪些算法属于独立重建。

重要分支：雨滴是黏附 UV 的静态程序图案，不包含流动、蒸发、碰撞积水；WaterHeight 使用世界空间，因此能产生统一水位线。

暂缓：完整 Shadow LUT、SpecRamp、HN 解码和原版后处理当前没有可验证实现。

---

## 推荐总阅读顺序

`ClukayLighting.hlsl`（最小 NPR 基线） → `ClukayHybridLighting.hlsl`（NPR+PBR） → `LiinoLighting.hlsl`（动态湿润扩展） → `LinnaeLighting.hlsl`（角色专用脸部/头发） → `LinnaeCharacterRenderFeature.cs`（跨物体渲染通道） → `KKBP_01.hlsl` 与 `AnkeLinnae.shader`（美术分层颜色的保留和复用）。

这条顺序先建立光照模型，再看角色特化，最后看不同资产生产方式如何接入同一套渲染框架。
