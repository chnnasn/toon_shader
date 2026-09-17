# 仍有引用的兼容资源

这里仅保留被项目资源或编辑工具引用的历史材质，不是当前场景的第二套正式材质。当前场景的正式材质位于 `Wardrobe/Materials`。

已清理 59 个闲置历史材质、旧嘴部法线备份和静态枪备份；没有新建备份。删除清单和引用审计见项目根目录 `Tools/Previews/ClukayFolderCleanup/audit.json`。

唯一入口：`Assets/Studies/ClukayStudy/Scenes/ClukayShowcase.unity`。枪入口：`Assets/Studies/ClukayStudy/Weapons/Summer416.prefab`。

后续清理又移除了两套废弃角色预制体及其 70 个闲置 Hybrid 材质。清单见 `Tools/Previews/ClukayAssetsCleanup/audit.json`。

剩余资源不能仅凭目录名删除：黛烟构建工具动态读取初版材质预设，换装修复工具使用旧头发材质。原始模型也保留用于法线、蒙皮和换装几何校验。
