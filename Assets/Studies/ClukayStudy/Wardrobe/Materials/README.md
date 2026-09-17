# 正式换装材质

此目录是唯一场景 `Assets/Studies/ClukayStudy/Scenes/ClukayShowcase.unity` 的正式材质集合，包含角色、换装、恢复的枪、底座和灯箱材质。这是当前可用重建效果，不代表原版渲染已完全恢复。

- 保留脸、头发、眼球、眼部加色/乘色、口腔、描边、身体、服装、丝袜与透明蕾丝等用途差异。
- 换装选项共享 skin 和相同服装材质；同一不透明静态网格的重复材质槽已合并。
- 不按颜色或材质名称推断可合并性；没有将不同 Shader、透明状态、模板或参数的材质强行合并。
- 当前集合通过 GUID 搬移整理，没有重写材质着色参数。历史场景可能仍共享其中部分 GUID；修改正式材质也可能影响这些历史场景，不应将归档视为不可变快照。

历史和测试材质位于 `Assets/Studies/ClukayStudy/Archive/Materials`，不应重新绑定到正式场景。迁移对应表是 `Assets/Studies/ClukayStudy/Editor/MaterialRelocations.json`。

验证与恢复记录：`Tools/Previews/MaterialCleanup/README.md`。
