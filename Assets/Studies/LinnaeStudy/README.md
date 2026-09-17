# 琳奈泳装 · 鸣潮风格渲染学习

打开 `Scenes/LinnaeShowcase.unity`，进入 Play 后左上角可旋转主光、调亮度和身体阴影软硬，切换颜色贴图、明暗分区、法线、高光、刘海阴影视图。新增 SDF / 刘海投脸阴影 / 角色描边三个独立开关。选中 `Linnae Camera` 可以在 Inspector 调相同参数；各材质独立保留皮肤、头发、眼睛、金属与透明度参数。

## 交付与来源

- `Models/LinnaeSwimsuit.fbx`：由运行中的 Blender 5.0 经 Blender MCP 调用 mmd_tools 导入原 PMX，再导出 FBX。包含 508 根骨骼、112 个表情 BlendShape、45 个材质槽。原 PMX 77,144 顶点 / 102,516 三角形；Unity 导入因法线/UV/材质边界分裂为 79,174 顶点。Blender 的第 113 个形态键为 Basis，不属于 Unity 表情。
- `Linnae.prefab`：已绑定材质、校准朝向与落地位置的角色。
- `Shaders/LinnaeWuthering.shadergraph`：Unity Skills 创建模板、查询结构与节点白名单、重导入验证。使用安装包的 Lit Full 主堆栈，49 个节点、37 条连接。Custom Function 不在当前 Skills 的 29 节点写入白名单中，因此由项目内序列化工具创建普通节点与连线；主堆栈结构保持模板原样。
- `Shaders/LinnaeLighting.hlsl`：独立编写的 Shader Graph Custom Function，处理 SDF 脸部阴影、刘海阴影采样、柔和明暗分区、冷暖阴影、UV 导数推导发丝方向的高光、金属高光、皮肤暖色补偿、轮廓光、主光阴影与附加灯光补光。
- `Textures/LinnaeFaceSDF.png`：1024² RGBA 重建 SDF。四通道分别为 0° / 45° / 90° / 135° 的真实欧氏有符号距离场，180° 为全暗；按光线与头部正面的夹角插值。编码为 `0.5 + 有符号投影距离 × 2`，正值是亮区。独立鼻口 UV 改用同一头骨投影坐标，因此不会在 UV 岛边界出现脸部阴影断层。头骨参考方向在安装时校准，头部转动后阴影跟随。
- `Rendering/LinnaeURP.asset` 与 `LinnaeRenderer.asset`：复制当前 URP 配置后加入角色专用 Renderer Feature；`LinnaeCharacterPipeline` 在场景启用时切换 Quality 管线，停用时恢复此前管线。保持 URP 17 原生 RenderGraph。
- `LinnaeCharacterRenderFeature.cs`：不透明渲染前绘制 1024² 独立头发灯光深度图，脸部采用 3×3 PCF 比较，并以面部高度渐隐下沿；不透明渲染后绘制按像素控制宽度的反向壳描边。头发壳深度偏移抑制内部细碎线。当前 2 个头发投影槽、11 个描边槽。
- 原贴图继续引用 `Assets/琳奈_泳装`，没有覆盖原 PMX、贴图或其他角色学习场景。

## 参考与推断边界

1. [库洛在 Unreal Engine 的技术访谈，2024-05-21](https://www.unrealengine.com/developer-interviews/exploring-the-post-apocalyptic-charm-of-asg-open-worlds-in-wuthering-waves)：访谈说明当时基于 UE4.26 并移植部分 UE5 功能，强调角色渐变、TOD、独立角色光照和调色。本项目参考这些方向，但没有移植其延迟渲染管线。
2. [鸣潮官网琳奈薄荷糖服饰展示](https://wutheringwaves.kurogames.com/es/main/news/detail/4965)：官网宣传图保存在 `Tools/LinnaeReferences/official_mint_candy.jpg`。用于核对薄荷色发梢、浅金发色、虹彩外套和饰品色彩。该图是宣传插画，不能作为逐像素实机渲染基准。
3. [官方服饰展示 Peppermint & Peach Parfait](https://www.youtube.com/watch?v=x8CxdC4xfaw)：本轮通过浏览器实际查看视频 0:38 的琳奈背面发梢、0:42 的琳奈正面日光镜头；0:26 的千咲近景仅作为同片光照参考，不混作琳奈材质。观察依据是浅金头发、薄荷发梢、暖皮肤阴影、细轮廓和较柔和的日光过渡。不是同姿态、同相机、同场景的定量匹配，不能声称与实机逐像素相同。

这是基于现有 PMX 与公开参考的视觉重建，**不是逆向取得的库洛原始 Shader 或 SDF 数据**。原包缺少脸部 SDF、法线与 PBR mask；本轮已重建 SDF、专用刘海投影与描边。没有把 MMD sphere map 冒充粗糙度图，也没有借用其他角色的 SDF。金属与粗糙度按材质槽设定。仍未复刻游戏的独立角色 GBuffer、SSR/GTAO、沙滩环境光、外套真实虹彩 BRDF、物理骨骼和动画；FBX 不保留 MMD 物理与完整 IK 约束语义。这些差异使当前结果不能标注为实机完全一致。

## 验证与复现

- `Tools/linnae_export.json`：Blender 导出计数、形态键和贴图映射。
- `Tools/build_linnae_graph.py`：基于本项目已验证的模板序列化工具构造图；先由 Unity Skills 创建 Lit Full 图，再运行脚本，随后重导入。
- `Tools/linnae_initial_structure.json` / `linnae_final_structure.json`：Unity Skills 实际读回的图结构。
- `Tools/LinnaePreviews/`：全身、正脸、侧光、三分之四视角与调试通道截图，以及 `validation.txt` 和 `shader_info.txt`。
- Unity 菜单 `Tools > Linnae Study > Capture Comparison` 可重新生成截图。`Repair Bindings` 恢复研究默认材质参数，注意它会覆盖手动调整的参数。`Calibrate Presentation` 恢复正面朝向并按蒙皮网格实际顶点校准落地。
- `Install Character Pipeline` 安装或重新绑定专用管线与头骨参考方向；请在头部默认姿态下执行。`Validate Character Pipeline` 输出 8 方向光照、头部转动和逐项禁用效果截图，结束后恢复场景参数。`Tools/bake_linnae_sdf.py` 可重建距离场，`Tools/linnae_visual_report.py` 生成光照对照图与开关差异数据。
- 已删除 SDF 单通道中间图及备份；生成脚本仅输出实际使用的合并 SDF。
- `Build Showcase` 只在展示场景不存在时运行，避免覆盖已有场景。已有场景直接打开使用。

截图使用 URP SingleCameraRequest，不使用不适合当前管线的 Camera.Render。同步编译截图后恢复原设置。请以最终实际画面和运行报告为准，ShaderHasError=False 单独不能证明所有运行变体可用。

第二轮验证：三个 Shader 均受当前设备支持且没有编译错误；材质 45 槽均使用研究 Shader。5 秒 Play 观察完成，0 个运行错误，报告 `Tools/LinnaePreviews/play_validation_v2.json`。`pipeline_validation.txt` 记录专用管线、头骨与 Pass 状态。`ablation_metrics.json` 证明禁用 SDF、刘海阴影、描边均实际改变渲染像素；它不是对鸣潮实机的相似度分数。`sdf_light_sweep.jpg` 是 8 方向光照对照，`v1/` 保留第一轮画面。未验证其他图形 API、移动端与长时间动画运行。
