# 原始资源恢复版（2026-09-17）

打开 `ClukayRecoveredShowcase.unity`。原始场景及 Hybrid 版本未覆盖。

## 已落地

- 通过 ADB 从用户手机读取游戏 APK 和筛选后的公开外部资源。原始文件及 SHA-256 在 `Tools/ExtractedGF2/provenance.json`：共 1,421 个文件，5,154,950,398 字节（4.801 GiB），不是完整手机/游戏数据备份。
- 首轮读取 9,780 个资源包的 128 KiB 前缀，匹配 1,328 个，3 个前缀解析失败；加上其他查询取得的候选包，保留 1,375 个 Candidates 和 42 个 Bundles。前缀匹配可能漏掉后部对象，不能称为全量扫描解包。
- 夏日枪 `cw_AR_SSR_Set010`：原始颜色、法线、RMO、2 个材质配置、LOD0/LOD1 网格已导出。Blender MCP 导出静态和带骨骼 FBX；场景使用带骨骼版。
- `Summer416Rigged.prefab`：9,530 顶点、10,086 三角面、5 骨骼（Weapon/clip01/trigger/bullet/bolt02）、2 材质分区。单骨骼索引的 Unity 刚性蒙皮按隐含权重 1 恢复；弹匣旋转测试位移 0.02373122，测试后恢复原姿态。
- 角色原始服装/头发/脸/眼睛贴图，以及半浮点 Ramp 已导出。恢复版替换能按名字对应的贴图，头发、围裙、丝袜接入原始 RGBAHalf 漫反射 Ramp；原有材质和场景仍可比较。
- `ClukayRecovered.shadergraph`：58 节点、46 连线、32 属性，Custom Function 实现 NPR 漫反射与 GGX/反射探针混合光照。RMO 通道顺序由原始 shader 属性元数据确认。
- 修复眼睛叠加贴图遮黑虹膜和头发描边点状干扰。对照在 `Tools/Previews/Recovered/Comparison.html`。

## 原始来源

|资源|保留的原始包（Tools/ExtractedGF2/Candidates）|
|---|---|
|夏日枪网格、蒙皮、材质和贴图|e48e6a76b9102f2542731a671e1ca589.bundle|
|服装纹理及 Ramp|d8f78c2fa8457ca6c538d35a657c5813.bundle|
|发、脸、眼睛及发 Ramp|e46676ead235eff3cf728f0424122b34.bundle|
|原版服装 LOD0 网格|f62273a310ff82b06e6fd63882dba5b3.bundle|

原始 shader 元数据在 `Tools/ExtractedGF2/ShaderEvidence`；原始 bundle 在 `Bundles/ed19937c31c594b01705236904a4a139.bundle`。Vulkan 程序的 UnityPy 文本导出不是可编译 Shader，不能当作源码。

## 不能声称已恢复的部分

- 完整原版混合渲染管线、GPU 算法、面部 SDF、头发专用阴影、屏幕空间处理和原游戏后处理。
- 枪所引用的共享 Ramp（CAB-3c6a0c6760ac3d3c1c3792719b21596c / PathID -5077301135546018961）。已补查手机顶层 bundle 目录但未定位，枪暂使用重建光照参数。
- 服装的完整原始材质设置尚未定位；Ramp 的光照采样坐标和混合公式是重建，不是反编译的原函数。当前只接入漫反射行，其他三条曲线仍保留在原数据中。
- 原版持枪姿势和动画未移植。当前角色仍用先前的 PMX 转 FBX；导出的高模和动画原包留作后续恢复。
- 手机与 PC 摄像机、曝光、环境不一致，没有可成立的“100%”或像素相似度评分。

## 复现与验证

最终检查：72 个材质 Inspector 全部通过，所有恢复材质的 Shader 无编译错误，反射贴图存在；运行观察 8 秒，0 个运行错误。记录分别在 `Tools/Previews/Recovered/material_inspector_validation.json`、`validation.txt`、`runtime_validation.json`，蒙皮测试在 `rig_validation.txt`。

Unity 菜单 `Tools/Clukay Study/Capture Recovered Tests` 重新截图；`Refine Recovered Materials` 应用眼睛和描边修正。Build / Install 菜单有重复执行保护，勿当刷新按钮反复运行。

提取脚本：`Tools/gf2_extract.py`、`gf2_fast_scan.py`、`gf2_export_candidates.py`、`gf2_export_gun_rig.py`。`gf2_fast_scan.py` 会重新扫描并覆盖扫描日志，不要仅为查看结果运行。所需依赖在 `Tools/extract-env`，不改变系统 Python。

读取与解码仅针对游戏渲染资源，未 root，未复制聊天/账号日志。期间发现已安装的 Blender MCP 开启遥测，日志显示曾发送操作记录、场景预览；已调用关闭并确认后续不再收集提示词、代码、截图和场景数据。已发送部分无法通过本地工具撤回；匿名工具计数仍由插件保留。

工具资料：[UnityPy](https://github.com/K0lb3/UnityPy)、[AddressablesToolsPy](https://github.com/anosu/AddressablesToolsPy)。游戏资源仅保留于本地学习项目，未创建公开下载链接。
