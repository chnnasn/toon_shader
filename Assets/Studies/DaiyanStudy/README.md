# 黛烟展示场景

唯一场景：`DaiyanShowcase.unity`。

使用用户认可的 `黛烟_20260917_214911_182513/黛烟_20260917_214911_182513.fbx`，材质、纹理与 Shader Graph 均使用同一导出包内的资源。未重新转换或改写该 FBX。

`Prefabs/Daiyan.prefab` 为当前展示角色；`Prefabs/DaiyanBody.prefab` 保留该 FBX 的身体、头发和骨架。

穿脱界面按源模型实际网格组织：外衣·旗袍、内衣、丝袜与内裤、鞋子、耳饰。源 FBX 将丝袜与内裤放在同一网格，故使用一个开关；身体与头发始终保留。

旧的 Models、Materials、Textures、Shaders 中不再被引用的资源及旧转换脚本已直接删除。依赖审计结果：`Tools/Daiyan/approved_deleted_assets.txt`。新导出包及其他场景依赖保持完整。

保留原展示环境、相机和旋转/灯光控制。更换验证菜单位于 Tools/Daiyan Study；编辑器辅助脚本为 Editor/DaiyanApproved.cs。

描边已恢复：Outline 目录保存专用描边 Shader 和材质，参考可露凯的外扩背面轮廓方式，复用认可 FBX 的网格、骨骼和形态键。脸部 0.2mm、身体 0.3mm、头发/衣物 0.45mm；眼球与面部细节不额外描边。DaiyanOutlineSync 同步穿脱可见性和表情，原始表面材质不变。

颈部接缝：KKBP_01.hlsl 在身体 UV 顶部颈部区域渐变校准亮面/暗面颜色，以匹配脸部接缝采样值，不改动 FBX 或其他部位。描边按法线朝向筛选背面，避免混合面绕序导致黑块。
