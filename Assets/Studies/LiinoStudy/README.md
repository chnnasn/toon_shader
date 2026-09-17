# Liino / Endfield 材质研究

入口：`Scenes/LiinoShowcase.unity`。进入 Play，左上角可调 Wetness、Rain、Water level，切换 DRY / SOAKED、转台、灯光和技能装备。编辑状态也可选中 Liino Camera 修改 LiinoWetnessControls，实时观察。

## 已实现

- Blender MCP 从 `Liino_RawGame.blend` 追加独立场景并导出 `Models/Liino.fbx`，保留骨骼、23 个网格和原始材质分件。原 Blender 场景和源 blend 未覆盖。
- Unity Skills 创建并重新导入 `Shaders/LiinoEndfield.shadergraph`，读取图结构验证。图有 74 节点、62 条连接，使用 Shader Graph 的纹理/属性节点和 HLSL Custom Function，保留安装包 Lit Full 的 Master Stack。不是纯可视化数学节点实现。
- 15 个角色材质：布料、金属饰件、丝袜、头发、皮肤、脸、眼睛和技能装备。采用原始 Smoothness/Metallic/Anisotropy/SilkStockings 参数，头发的专用参数不直接当作金属度。
- 柔化 NPR 明暗、GGX 高光、头发双高光、布料纤维高光、面部 SDF、实时主光/附加光、反射探针。
- 湿润使布料颜色变深、粗糙度下降、微表面法线减弱；Rain 增加附着于 UV 的程序雨滴；Water level 根据世界高度产生局部浸水边界。丝袜使用源材质记录的干/湿颜色。
- 10 种调试输出；`Tools/Liino Study/Capture Comparison` 生成全身、近景、三分之四视角、浸水与遮罩截图。

## 证据与推断

直接证据位于 `Assets/Liino/materials/*.json`、`textures/`、`Tools/liino_export.json`、`Tools/liino_material_config.json`。源材质确有 `_WetEffectIntensity`、`_WetEffectWorldSpaceHeight`、`_RainEffectIntensity`、`_DisableRainEffectOnMaterial` 和丝袜专用字段。

源数据不包含可验证的完整原版着色器。因此 GGX/NPR 混合、SDF 阈值、雨滴分布、湿润深色比例和粗糙度过渡是独立重建，并非原版 shader 的反编译结果。SDF 绿色通道是根据贴图和近景画面对照选定；侧光算法仍有近似。

衣服 P 贴图采用 R=金属度、A=光滑度、B=AO 的研究假设，9 个衣服材质开启 `_UseRMO=1`。依据是本地通道图与公开社区实现的相互印证，不是原版 shader 证明；G 暂不解释。脸、头发和其他材质保持独立参数。原始 DiffRamp 已绑定，但默认 `_UseRamp=0`；完整 Shadow LUT、SpecRamp、HN 解码及原版后处理未恢复。眼影/发影投影分件及 VFX 网格默认隐藏，未复刻原版专用投影/特效 pass。

## 对比资料

- 本地 `Assets/Studies/LiinoStudy/SourceArt/Textures/poster_chr_0035_liino.png`：游戏资源包中的角色立绘，用于色彩、分件与材质分区对照；绘画不能作为逐像素实机基准。
- 本地 `Assets/Liino/preview.png`：下载包作者的 Blender 预览，不是官方实机。
- [官方莉诺战斗演示](https://www.youtube.com/watch?v=kTHEqpvUnzA)：本轮已在官方认证频道播放器中实际查看约 5、9、14、19 秒画面。开场有失焦、舞台彩光，战斗有运动模糊和技能光；仅作外观参考，不能据此计算还原百分比或确认湿润算法。
- [社区角色渲染实现](https://github.com/congyuxiaoyoudao/Endfield_Character_Rendering)：`Assets/Shaders/Library/EndfieldLitInput.hlsl` 的衣服分支提供 P 贴图通道解释。相关源码和 MIT 许可证保存于 `Tools/LiinoResearch/`，供研究核对；项目着色器仍是独立实现。
- [Liino 官方角色故事预告的公开视频索引](https://www.youtube.com/watch?v=n7ZDJaSosDA)：检索到了索引，但本次未能获取视频帧，不把它写成已完成逐帧对比。
- [雨水材质实机截图报道](https://www.mustplay.in.th/content/page/691a05e308c382371dc82a59)：用于检索雨滴和水痕的视觉参考，不作为着色器算法证据。
- [官方研发通讯](https://endfield.hypergryph.com/news/7235)：研发与表现优化背景，不提供具体雨水着色公式。

## 验证与使用边界

截图和验证输出：`Tools/LiinoPreviews/`。`dry.png` 和 `wet.png` 使用同一相机与灯光；`portrait_dry.png` 与 `portrait_wet.png` 对比近景。`validation.txt` 记录 ShaderUtil 编译结果；运行时通过 Unity Skills 进入/退出 Play 并检查 Console。

FBX 的源骨架带 0.01 缩放，当前 prefab 根缩放 100，已以普通 URP Lit 和蒙皮包围盒对照确认米制外观。未烘焙动画，未加入布料物理。

本研究创建 `LiinoPipeline.asset` / `LiinoRenderer.asset`，控制组件启用时将当前 Quality 的管线覆盖切换为独立 Forward 渲染器，禁用/关闭场景时恢复原覆盖，避开此次离屏截图中原 Forward+ 的 ReflectionProbeManager 错误。原管线资产不修改；原覆盖路径记录于 `Tools/LiinoPreviews/previous_pipeline.txt`，本项目原值为 `Assets/Settings/PC_RPAsset.asset`。

Unity Skills 的同步 `scene_screenshot(returnImage=true)` 在此 Unity 版本触发了 RenderPass 错误，因此最终交付截图使用独立 RenderRequest，以及异步保存成功的 `Assets/Screenshots/LiinoRuntime.png`。这是截图调用的兼容性问题，未写入着色器或运行时控制逻辑；不要用该同步调用作为当前版本的截图入口。

雨滴是程序化静态附着图案，尚无流动、蒸发和碰撞积水模拟。效果属于有来源参数支撑的可交互学习复刻，尚不能称为与游戏完全一致。

## 重建

1. 通过 Blender MCP 执行 `Tools/export_liino.py`。
2. 通过 Unity Skills `shadergraph_create_graph` 创建 Lit Full 图；执行 `python Tools/build_liino_lighting.py`、`python Tools/build_liino_study.py`，再通过 Skills reimport / get_structure 验证。序列化辅助复用本项目已有 `Tools/build_clukay_graph.py` 的基础节点构造，不引用其角色素材。
3. 新建场景时执行 `Tools/Liino Study/Build Showcase`，然后 `Calibrate Import`、`Use Study Renderer`、`Polish Lighting`。构建器遇到已存在的展示场景会停止，防止覆盖后续编辑。
4. `Capture Comparison` 可重复执行；对比截图仅写入 Tools 目录。
5. `Apply Researched Cloth Channels` 更新衣服通道；`Refresh Reflections` 为展示场景建立持久的程序化摄影棚环境贴图，避免重新打开场景后金属失去反射。此环境不是游戏场景。必须先打开 LiinoShowcase，再调用截图菜单；菜单返回成功不等于内部截图成功，应核对文件时间与 Console 的全部日志（异常可能不出现在 Error 过滤结果中）。
