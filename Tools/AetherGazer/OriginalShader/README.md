# Aether Gazer character shader extraction and Shader Graph reconstruction

## Extracted source asset

- Game bundle: `AetherGazer_Data/StreamingAssets/Windows` → `shader.ys`
- Unity Shader PathID: `-5491446236744966977`
- Serialized shader name: `SimPipeline/Character/PBR/Uber`
- Unity player version used to decode assets: `2022.3.62f1`
- Parsed property count: **155**
- Parsed pass count: **8**
- Full serialized result: `Packages/com.p08.render/RenderPipeline/SimPipeline/Shader/Character/PBR/Shader #51 @-5491446236744966977.json`

The shipping player contains compiled shader variants rather than the author's editable HLSL/Shader Graph source. The JSON above is the complete readable Unity `Shader` typetree: properties, render states, passes, keyword tables, program metadata and compiled blob fields. It is the evidence used for the reconstruction; it is not presented as the original authoring source.

## Original passes

| Index | Pass state name | Function reconstructed in this project |
|---:|---|---|
| 0 | `ForwardBase` | `WuchangSurface.shadergraph`: base texture, toon threshold, original ramp, rim, specular and material controls |
| 1 | `Outline` | `WuchangOutline.shadergraph`: separate inverted-hull Shader Graph |
| 2 | `CharHairShadow` | Not reproducible exactly without the original custom SRP stencil/renderer feature; approximated by authored hair mask and face SDF |
| 3 | `CharFaceShadow` | Conservative face-only SDF tint reconstruction |
| 4 | `CharHairTransE` | Hair highlight/transmission appearance approximated by the original `hair01_Mask` |
| 5 | `ShadowCaster` | Supplied by generated URP Shader Graph passes / scene renderer settings |
| 6 | `Reflection` | RMK/RMO material information retained; custom SimPipeline reflection pass is not duplicated |
| 7 | `PreDepth` | Supplied by generated URP depth passes where applicable |

## Confirmed original feature switches

- `FACE_MODE` with `_SDFType = 1` on `face01`
- `_ANISOTROPIC_SPECULAR` on `hair01` and `hair01_bangs`
- `_USE_STOCKING` on `body02` and `body03`
- `_RMOTex`: R metallic, G emissive, B AO, A roughness (from the original property description)
- Multi-row ramp and ramp mask controls
- Skin/SSS, rim, anisotropic hair, stocking normal/falloff, reflection and stencil shadow controls
- Outline widths: body/clothing `3.0`, face/hair `2.3` in the original custom screen-space convention

Relevant original global keywords include `FACE_MODE`, `_USE_STOCKING`, `_ANISOTROPIC_SPECULAR`, `_ANISOTROPIC_SPECULAR_GGX`, `TRANSPARENT_MODE`, `_ALPHATEST_ON`, `PLUS_LIGHTING`, `SIM_DIRECTIONAL_SHADOW`, `SIM_DISSOLVE`, `SIM_DITHERING`, `SIM_SLICE` and `SIM_INTERFERENCE`.

## Material-specific values preserved

| Material | Character | Important original values used |
|---|---|---|
| dark stocking (`body02/body03`) | 105401 | `_StockingInt=0.49`, normal intensity `0.2`, center `(1,.9817,.98)`, falloff `(.2,.1418,.1418)`, tiling `(10,620.16,500,500)` |
| white stocking (`body02/body03`) | 614801 | `_StockingInt=2.89`, normal intensity `0.2`, center `(1,.872,.872)`, falloff white |
| face (`face01`) | both | `FACE_MODE`, `_SDFType=1`, rim disabled |
| hair | both | anisotropic keyword, original hair highlight mask, per-character specular/rim values |

## Reconstruction files

- Surface Shader Graph: `Assets/Studies/WuchangStudy/Shaders/WuchangSurface.shadergraph`
- Outline Shader Graph: `Assets/Studies/WuchangStudy/Shaders/WuchangOutline.shadergraph`
- Rebuild and verification code: `Assets/Studies/WuchangStudy/Editor/WuchangStudyBuilder.cs`
- Showcase scene: `Assets/Studies/WuchangStudy/Scenes/WuchangShowcase.unity`
- Original shared maps: `Assets/Studies/WuchangStudy/SourceArt/Shared/`
- Render preview: `Tools/AetherGazer/WuchangPreview.png`

The surface graph uses the extracted base/ramp maps plus the authored `hair01_Mask`, `siwa_normal`, face SDF blend map and RMK blue-channel AO. Exact parity for the original `CharHairShadow`, `CharFaceShadow`, reflection and pre-depth passes would require custom HLSL plus matching SimPipeline renderer features; pure URP Shader Graph cannot reproduce those custom stencil and pipeline passes byte-for-byte.
