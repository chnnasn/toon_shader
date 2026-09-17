# 可露凯·无瑕侍礼：NPR + PBR 渲染学习工程

## 状态与边界

2026-09-16 实机参考校准已应用：默认外裙改为不透明、写深度并恢复投影；头发采用冷蓝银色调；减弱脸部和白袜的硬明暗及高光。参考来自用户手机「无瑕侍礼」默认部件旋转观察，未解包。下文旧版的“透明外裙”描述为历史近似，现已被实机证据纠正。对比见 `Tools/Previews/PhoneCalibration/Comparison.html`，旧材质备份在同目录 `BeforeMaterials`。可使用菜单 `Apply Phone Reference Calibration` 重施本轮参数；旧 `Calibrate Hybrid Materials` 会恢复旧预设，不应当作本轮参数。

这是基于现有 PMX/贴图和公开实机观察的独立混合渲染实现，不是提取的原版 Shader，也没有达到“完整、一比一还原少女前线 2”。没有解包游戏客户端。原版渲染算法、材质常量、脸部阴影控制数据、场景环境光和后处理参数仍未取得。

原模型已通过 Blender MCP 导出 FBX：`Assets/Studies/ClukayStudy/Models/ClukayMaid.fbx`。本轮复用该结果，没有重复导出。Unity 实测 78,521 顶点、597 骨骼、61 blendshape、35 材质槽。

## 打开与比较

- 新场景：`Assets/Studies/ClukayStudy/Hybrid/ClukayHybridShowcase.unity`。
- 可复用角色：`Assets/Studies/ClukayStudy/Hybrid/ClukayHybrid.prefab`。使用时还需场景灯光、反射探针和后处理；Prefab 本身不包含摄影棚。
- 主图：`Assets/Studies/ClukayStudy/Hybrid/Shaders/ClukayHybrid.shadergraph`，56 节点、44 连线、30 属性。
- 光照实现：同目录 `ClukayHybridLighting.hlsl`。
- 本地比较页：`Tools/Previews/Hybrid/Comparison.html`。
- 原场景、原材质、原图保留在 `Assets/Studies/ClukayStudy` 对应目录。创建分支前保存了原场景已有未保存改动。

运行新场景，左上角可旋转角色、改变主光方向，并切换基础色、法线、R/M/AO、主光阴影、直接高光、环境反射、漫反射环境光、透明覆盖率。运行时控件使用材质实例，不把诊断模式写回资源。

## 本轮实现

| 部分 | 实现 | 非原版等同声明 |
|---|---|---|
| 服装/金属 | GGX 分布、相关 Smith 可见项、Schlick Fresnel、金属区域减少漫反射，粗糙度与法线细节 | 数学模型是独立选择，不声称原作使用相同公式/参数 |
| 环境 | Unity 烘焙 HDR 探针，256 分辨率、9 级 mip、Specular convolution；URP 环境 BRDF | 摄影棚软箱与背景是本工程构建，不是原场景 IBL |
| 光源 | 主光阴影；URP Forward / Forward+ 附加逐像素灯循环 | 当前项目 PC 渲染设置下验证，未验证全部平台/变体 |
| 脸/皮肤 | NPR 漫反射权重、柔化明暗过渡、面部阴影减弱、包裹漫反射近似散射 | 没有原版脸部阴影控制图；SkinScatter 不是屏幕空间或体积 SSS |
| 头发 | 现有 hair_spc 遮罩，UV 导数方向的双瓣移位各向异性高光 | 不是原版发丝切线/专用高光算法；镜像 UV 与发梢仍可能出现方向差异 |
| 白袜/围裙 | 独立粗糙度、环境强度、掠射 sheen | 白袜没有实现纤维微结构与多层透射 BRDF |
| 外裙 | 独立透明混合、视角相关覆盖率、关闭自身投影与外扩描边 | 现有颜色图不提供所需完整透明控制；0.58 opacity 是视觉近似。共用 skinned mesh 的透明排序仍有局限 |
| 轮廓/后期 | 复用细描边，SMAA、Neutral tonemapping、低强度 Bloom | 未还原原作屏幕空间边缘光、完整后处理栈 |

图的 Lit Master Stack 用来生成 URP Pass；常规 BaseColor / Specular 为零，自定义光照通过 Emission 输出，避免叠加一次标准 Lit 光照。它并不意味着模型是“不受光的贴图”；六项消融测试验证了真实灯光响应。

Unity Skills 的节点编辑白名单不足以生成完整 Custom Function 光照。本工程通过已有生成脚本补齐普通节点序列化，并由 Unity Skills 读取真实图结构、触发导入、执行构建/测试。没有声称所有节点都由 Skills 的节点写入 API 创建。

生成：`python Tools/build_clukay_graph.py --hybrid`。这会重建本工程生成的 Hybrid 图；手动改图后不要随意运行。原版生成命令不带参数，勿在保留原版对照时误运行。

## 公开参考及实际观察

1. [游戏葡萄采访美术团队的转载](https://game.xiaomi.com/viewpoint/1392697565_1644457607820_11)：支持 NPR 与 PBR 结合的方向，不提供可直接照抄的完整实现。
2. [米拉修雷德：HK416 可露凯·无瑕侍礼游戏实录](https://www.bilibili.com/video/BV1Ujg964Een/)：实机参考，非官方技术文档。实际在浏览器观察约 01:10 战斗画面、02:22–02:29 腿部/白袜、04:02–04:09 上身/脸/发丝。普通清晰度可查看，高清需要登录。未下载或重新分发整段视频。
3. [官方版本公告](https://gf2exilium.sunborngame.com/NewsInfo?id=393&typeId=3)：确认同款英文名 Immaculate Service，不能用来证明渲染技术。
4. [Unity BakeReflectionProbe API](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Lightmapping.BakeReflectionProbe.html)：本工程探针烘焙 API。

观察结果：参考脸部更平整，鼻/嘴处几何阴影更弱；发丝有集中的亮带；黑色服装具有连续高光但不整体变成金属；白袜有细腻、连续的明暗变化。重做版据此减弱脸部阴影、降低黑布和白袜的环境响应，并保留金边的独立金属遮罩。

仍有差异：头发亮带形状、面部明暗控制、白袜层次、半透明裙子的排序及覆盖率、原场景的光照/色调。参考视频角色有动画和不同镜头，本工程是 A pose 摄影棚；不能把两者像素差当作还原度，也没有给出虚构的相似度百分比。

## 可复验测试

菜单 `Tools/Clukay Study`：

- `Bake Hybrid Reflection`：在新场景重新烘焙探针，不更改全局质量档位。
- `Capture Hybrid Tests`：全身、3/4、侧光、面部及分项输出；临时修改相机/材质后在 finally 恢复。
- `Validate Hybrid Lighting Responses`：六项消融，输出 `lighting_response_validation.json`。阈值表示画面有实质变化，不表示还原度。
- `Validate Hybrid Inspectors`：实际 MaterialEditor Layout/Repaint 检查，防止此前 LitGUI NullReference 回归。
- `Calibrate Hybrid Materials`：把本轮预设重新应用到新材质，会覆盖手工调参；按需使用。

`Build Hybrid Study` 只用于首次从原场景创建分支，成功后拒绝覆盖已有 Hybrid 场景。

RMO 通道当前按 R=roughness、G=metallic、B=AO 解释，空间分布与金边/布料相符但未获原材质定义证实。`UseRMO`、`RoughnessScale`、`MetallicScale` 和诊断视图用于检查该假设。环境、散射、sheen 等参数包含艺术调整，不宣称严格能量守恒。

进一步匹配原作优先需要：同角色同皮肤固定镜头高清参考、原始材质参数和贴图通道定义、脸部/头发控制资源、原场景光照信息。当前不需要先下载整个客户端；仅有客户端也不保证能恢复源码或原始 Shader Graph。
