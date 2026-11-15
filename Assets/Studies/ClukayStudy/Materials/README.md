# 可露凯展示材质

此目录保存 ClukayShowcase 的角色、服装、眼部、Summer416 与摄影棚材质。[展示场景](../Scenes/ClukayShowcase.unity)

## 材质组织

- 脸部、身体、头发、眼球、眼部加色与乘色保留各自的材质参数。
- 换装选项按部位绑定材质，同类皮肤和相同服装部件共享材质。
- 薄纱、蕾丝和透明枪械部件单独配置渲染队列、混合与深度状态。
- 主角色使用 `ClukayCharacter.shader`，眼部叠加使用 `RecoveredEyeBlend.shader`，枪械使用 `ClukayGun.shader`。

`Tools > Studies > Clukay > Repair Transparent Wardrobe Materials` 可恢复透明衣料设置。`Validate Study Contract` 检查正式材质与 Shader、Renderer Feature 的配置。
