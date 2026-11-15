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
| 2 | `CharHairShadow` | `WuchangCharacter.shader` + `WuchangCharacterRenderFeature`: clip-space fringe offset, `Stencil==200`, `IncrSat` to 201, `ColorMask 0` |
| 3 | `CharFaceShadow` | Receiver redraw only at `Stencil==201`, then `DecrWrap` back to 200 |
| 4 | `CharHairTransE` | Hair highlight/transmission appearance approximated by the original `hair01_Mask` |
| 5 | `ShadowCaster` | Supplied by generated URP Shader Graph passes / scene renderer settings |
| 6 | `Reflection` | Dedicated mirrored-view render target and front-face-cull shader pass; published as `_WuchangReflectionTexture` |
| 7 | `PreDepth` | Dedicated `ColorMask 0`, `ZWrite On`, `ZTest LEqual` pass scheduled before opaques |

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

- Multi-pass ShaderLab shader: `Assets/Studies/WuchangStudy/Shaders/WuchangCharacter.shader`
- Shared HLSL implementation: `Assets/Studies/WuchangStudy/Shaders/WuchangCharacterCommon.hlsl`
- URP 17 RenderGraph scheduler: `Assets/Studies/WuchangStudy/Scripts/WuchangCharacterRenderFeature.cs`
- Renderer/material pass collector: `Assets/Studies/WuchangStudy/Scripts/WuchangCharacterPipeline.cs`
- Idempotent installer: `Assets/Studies/WuchangStudy/Editor/WuchangCustomPipelineInstaller.cs`
- Surface Shader Graph: `Assets/Studies/WuchangStudy/Shaders/WuchangSurface.shadergraph`
- Outline Shader Graph: `Assets/Studies/WuchangStudy/Shaders/WuchangOutline.shadergraph`
- Rebuild and verification code: `Assets/Studies/WuchangStudy/Editor/WuchangStudyBuilder.cs`
- Showcase scene: `Assets/Studies/WuchangStudy/Scenes/WuchangShowcase.unity`
- Original shared maps: `Assets/Studies/WuchangStudy/SourceArt/Shared/`
- Render preview: `Tools/AetherGazer/WuchangPreview.png`

The active reconstruction now uses custom HLSL and a URP 17 Renderer Feature for the custom pass contract. The important serialized render states are reproduced directly: face ForwardBase writes stencil 200; the displaced bangs pass tests 200 and increments it to 201; the face receiver pass tests 201, shades only that region, and decrements it back to 200. Reflection and PreDepth are separately scheduled rather than folded into the forward surface pass.

This is a behavioral reconstruction from the shipping player's serialized shader, compiled program metadata, material values and screenshots. The player does not contain the author's editable HLSL or complete SimPipeline C# source, so the implementation must not be described as byte-for-byte original source. State parity is directly verifiable; instruction-level lighting parity remains an approximation.
