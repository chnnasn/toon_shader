# 黛烟角色材质输入

此目录集中保存角色 FBX、表面 Shader Graph、HLSL、材质与纹理，供 DaiyanStudy 的展示预制体使用。

项目采用 Unity 6000.4 与 URP，色彩空间为 Linear。Materials 中的 Light / Dark 参数控制亮面与阴影面，颜色权重与透明遮罩保留在各材质中。

移动资源时同时保留对应 .meta 文件，以维持模型、材质与纹理的 GUID 关联。

完整展示入口位于 ../../Scenes/DaiyanShowcase.unity，交互和描边说明见 ../../README.md。
