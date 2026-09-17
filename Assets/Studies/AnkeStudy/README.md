# 安可展示

打开 `AnkeShowcase.unity`。此角色只有一个展示场景，Build Settings 也只启用该场景。DaiyanStudy、LinnaeStudy 等参考资源保留。

现在两套服装同时保存在该场景/预制体中，共享唯一素体和骨架。运行后使用左上角“第一套 / 第二套”切换；下方开关可单独隐藏服装。编辑模式可调整 Anke 对象上的 AnkeWardrobe 的 Selected Outfit 和各 Part 的 Visible。默认第二套全套显示。

已修复隐藏网格的描边残影：LinnaeCharacterRenderFeature 在绘制头发深度和描边前检查 Renderer.enabled、activeInHierarchy 和 forceRenderingOff。切换套装或关闭外裙时，自定义通道也会停止绘制该网格。

脸颈色差：`Calibrate Neck Seam` 从原有脸/身体贴图的 27 个对应接缝位置计算亮面与暗面校正，写入身体材质的 Neck Light/Dark Correction。校正只在头部坐标系中的上颈部生效，向肩部渐退；脸部 SDF 在下颌附近平滑过渡到与颈部一致的法线光照。更改原始肤色后可重新运行校准，`Validate Neck Lighting` 输出多方向光照验证图。

素体和头发来源：`Assets/Studies/AnkeStudy/SourceArt/BaseCharacter/AnkeBaseCharacter.fbx`；当前服装来源：`Assets/Studies/AnkeStudy/SourceArt/Outfit2/_2.fbx`。`Anke.prefab` 保留原有身体和头发的 15 个材质，服装使用 `Materials/Outfit2` 下的 10 个独立材质。源 FBX、导出材质和 EXR 贴图保持原位，亮/暗基底、身体颜色权重层、UV 变换和透明遮罩均保留。

8 个服装/饰品网格位于 `Outfit 2 - Clothing and Accessories`，共用现有素体骨骼，附加 8 个饰品节点，不引入第二套身体或整套骨架。保留服装原始 inverse bind matrices，以适配两次导出之间的骨骼姿态差异。重绑定网格保存在 `Models/Outfit2`。

`Anke/Linnae Layered` 在分层颜色合成后直接调用 `LinnaeLighting.hlsl`；场景复用 LinnaeURP、RenderGraph 头发投影和屏幕描边。Shader 包含透明裁切、ShadowCaster、DepthOnly。脸部绑定 DEF-Head，使用 Linnae 的头部空间 SDF；这是复用参考风格，不是安可原作的专用脸部 SDF。

保持 FBX 的 T Pose 和 132 个表情 BlendShape，未生成动画。相机上的 LinnaeStudyControls 可调光照和调试模式；LinnaeCharacterPipeline 可切换脸部 SDF、头发投影和描边。

菜单 `Tools/Anke Study/Validate and Capture` 检查材质、Shader 和骨骼，并将预览和报告输出到 `Tools/AnkePreviews`。`Build Showcase` 会重建生成材质、角色预制体和场景中的角色，覆盖这些生成对象上的手工修改。

`Apply Outfit 2` 在当前素体上重建第二套服装；`Verify Outfit 2`、`Compare Outfit Binding` 和 `Test Outfit Deformation` 分别验证骨骼归属、原始 FBX 蒙皮一致性及关节变形/复位。换装前备份位于 `SourceArchive/AnkeBeforeOutfit2`，不在 Assets 内，不增加可加载展示场景。

`Install Two Outfits` 安装/刷新两套换装控制；`Verify Two Outfits` 验证互斥显示以及隐藏外裙时自定义绘制的排除逻辑，并输出两套截图和回归截图。安装操作会将单件开关恢复为全显示。
