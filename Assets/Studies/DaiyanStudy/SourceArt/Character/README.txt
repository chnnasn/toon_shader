Blender → Unity URP (Linear)

把此整个文件夹复制进 Unity 的 Assets。务必保留所有 .meta 文件。
等待原生导入完成后，将 黛烟_20260917_214911_182513.fbx 拖入场景；材质会自动关联。
打开 Materials 中的身体材质，直接调整 Nipple base / base 2 / shine / rim 等颜色。
Light 为亮面，Dark 为阴影面。不需要任何 Unity 导入插件或 C# 脚本。
不要只复制 FBX，也不要删除 .meta，否则自动材质关联会丢失。
支持 URP，当前验证 Unity 6000.4。其他管线不适用。
不包含法线贴图、描边、物理和动画片段。重叠 UV 须具有相同材质结果。
