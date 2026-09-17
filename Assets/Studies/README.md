# 渲染学习项目

每个角色的资源集中在对应 Study 目录；从 `Scenes` 中打开学习场景。

| 学习目录 | 场景入口 |
| --- | --- |
| AnkeStudy | Scenes/AnkeShowcase.unity |
| ClukayStudy | Scenes/ClukayShowcase.unity |
| DaiyanStudy | Scenes/DaiyanShowcase.unity |
| LiinoStudy | Scenes/LiinoShowcase.unity |
| LinnaeStudy | Scenes/LinnaeShowcase.unity |
| EncoreStudy | Shaders，仅着色器学习资源 |

## 目录约定

- `Scenes`：学习场景。
- `Scripts`：运行控制和渲染脚本；类名及文件名保持对应。
- `Editor`：仍保留的编辑器辅助工具。
- `Prefabs`：角色预制体。
- `Models` / `Materials` / `Textures` / `Shaders`：学习使用的模型、材质、贴图和着色器源码。
- `Rendering`：渲染管线、Renderer、Volume 与环境反射配置。
- `SourceArt`：已导入的原始模型与依赖；材质和贴图保留源名称，便于对照原始材质槽。

可露凯的 `Hybrid`、`Recovered`、`Wardrobe`、`Weapons`、`Archive` 保留专题划分；专题内同样按资源用途归类。黛烟的描边 Shader 位于 `Shaders`，描边材质位于 `Materials/Outline`。

`Assets/Settings` 是项目共用的渲染配置。部分角色共享 LinnaeStudy 的渲染脚本与着色器代码，这是实际依赖，不要重复复制或单独删除。

原有角色 README 中的构建菜单、已删除的导出脚本等描述可能属于历史制作流程；当前学习入口以本文件和现有场景为准。整理移动记录与验证结果保存在项目根目录 `Tools/StudyOrganization`。
