# Fixed-function feature matrix

> **Generated — do not edit by hand.** `scripts/feature-matrix.sh --write`;
> verify with `scripts/feature-matrix.sh --check` (also run by `ctest`/CI).
>
> Source: `src/**/*.{cpp,c,h,hpp,inl}` with comments and string literals
> removed, excluding `tests/` and the renderer/platform implementation
> (`src/EterBase/include/`, `src/EterBase/src/`). Those directories consume
> the state; this file lists what the game and engine *ask for*.

This is the contract the renderer backend must satisfy (plan §4.4): the GL
backend passes it through to OpenGL 2.1, and a Vulkan backend has to
synthesise programs from it (D11/D12, T5.2).

## Summary

| Item | Distinct | Call sites |
|---|---:|---:|
| Render states (`D3DRS_*`) | 51 | 212 |
| Texture-stage states (`D3DTSS_*`) | 9 | 439 |
| Sampler states (`D3DSAMP_*`) | 6 | 66 |
| Transform states (`D3DTS_*`) | 5 | 49 |
| FVF layouts | 17 | 52 |
| Shader calls (no-op on GL, D13) | 10 | 37 |
| **Total fixed-function state** | **71** | **766** |

## Render states (`D3DRS_*`)

| State | Sites | Files |
|---|---:|---|
| `D3DRS_ALPHABLENDENABLE` | 12 | `src/EffectLib/src/EffectMeshInstance.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/MapOutdoorWater.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DRS_ALPHAFUNC` | 3 | `src/EterLib/src/StateManager.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp` |
| `D3DRS_ALPHAREF` | 6 | `src/EterLib/src/StateManager.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DRS_ALPHATESTENABLE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_AMBIENT` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_AMBIENTMATERIALSOURCE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_BLENDOP` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_CLIPPING` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_CLIPPLANEENABLE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_COLORVERTEX` | 6 | `src/EterLib/src/StateManager.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DRS_COLORWRITEENABLE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_CULLMODE` | 8 | `src/EterGrnLib/src/Material.cpp`<br>`src/EterLib/src/GrpExpandedImageInstance.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DRS_DESTBLEND` | 10 | `src/EffectLib/src/EffectMeshInstance.cpp`<br>`src/EffectLib/src/ParticleSystemInstance.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp` |
| `D3DRS_DIFFUSEMATERIALSOURCE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_DITHERENABLE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_EMISSIVEMATERIALSOURCE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_FILLMODE` | 8 | `src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/UserInterface/src/PythonApplication.cpp` |
| `D3DRS_FOGCOLOR` | 8 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapManager.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp` |
| `D3DRS_FOGDENSITY` | 2 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapManager.cpp` |
| `D3DRS_FOGENABLE` | 20 | `src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/InstanceBase.cpp` |
| `D3DRS_FOGEND` | 2 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapManager.cpp` |
| `D3DRS_FOGSTART` | 2 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapManager.cpp` |
| `D3DRS_FOGTABLEMODE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_FOGVERTEXMODE` | 4 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapManager.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp` |
| `D3DRS_INDEXEDVERTEXBLENDENABLE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_LASTPIXEL` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_LIGHTING` | 32 | `src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/FlyTrace.cpp`<br>`src/GameLib/src/MapOutdoorCharacterShadow.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/WeaponTrace.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/InstanceBase.cpp` |
| `D3DRS_LOCALVIEWER` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_MULTISAMPLEANTIALIAS` | 2 | `src/EterLib/src/GrpDevice.cpp`<br>`src/EterLib/src/StateManager.cpp` |
| `D3DRS_MULTISAMPLEMASK` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_NORMALIZENORMALS` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_RANGEFOGENABLE` | 2 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapManager.cpp` |
| `D3DRS_SHADEMODE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_SPECULARENABLE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_SPECULARMATERIALSOURCE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_SRCBLEND` | 10 | `src/EffectLib/src/EffectMeshInstance.cpp`<br>`src/EffectLib/src/ParticleSystemInstance.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp` |
| `D3DRS_STENCILENABLE` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_STENCILWRITEMASK` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_TEXTUREFACTOR` | 38 | `src/EffectLib/src/EffectMeshInstance.cpp`<br>`src/EffectLib/src/ParticleInstance.cpp`<br>`src/EterGrnLib/src/Material.cpp`<br>`src/EterLib/src/CollisionData.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/DungeonBlock.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/UserInterface/src/PythonMiniMap.cpp` |
| `D3DRS_VERTEXBLEND` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP0` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP1` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP2` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP3` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP4` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP5` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP6` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_WRAP7` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_ZENABLE` | 3 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp` |
| `D3DRS_ZFUNC` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DRS_ZWRITEENABLE` | 3 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/Area.cpp` |

## Texture-stage states (`D3DTSS_*`)

| State | Sites | Files |
|---|---:|---|
| `D3DTSS_ALPHAARG1` | 57 | `src/EffectLib/src/EffectInstance.cpp`<br>`src/EterGrnLib/src/Material.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/SkyBox.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/FlyTrace.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/MapOutdoorWater.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp`<br>`src/GameLib/src/TerrainDecal.cpp`<br>`src/GameLib/src/WeaponTrace.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/PythonCharacterManager.cpp` |
| `D3DTSS_ALPHAARG2` | 32 | `src/EffectLib/src/EffectInstance.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/FlyTrace.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/WeaponTrace.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DTSS_ALPHAOP` | 99 | `src/EffectLib/src/EffectInstance.cpp`<br>`src/EterGrnLib/src/Material.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/SkyBox.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/FlyTrace.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorCharacterShadow.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/MapOutdoorWater.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp`<br>`src/GameLib/src/TerrainDecal.cpp`<br>`src/GameLib/src/WeaponTrace.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/InstanceBase.cpp`<br>`src/UserInterface/src/PythonCharacterManager.cpp` |
| `D3DTSS_COLORARG1` | 80 | `src/EffectLib/src/EffectInstance.cpp`<br>`src/EterGrnLib/src/Material.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/SkyBox.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/FlyTrace.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorCharacterShadow.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/MapOutdoorWater.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp`<br>`src/GameLib/src/TerrainDecal.cpp`<br>`src/GameLib/src/WeaponTrace.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/InstanceBase.cpp`<br>`src/UserInterface/src/PythonCharacterManager.cpp`<br>`src/UserInterface/src/PythonMiniMap.cpp` |
| `D3DTSS_COLORARG2` | 52 | `src/EffectLib/src/EffectInstance.cpp`<br>`src/EterGrnLib/src/Material.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/SkyBox.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/FlyTrace.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/WeaponTrace.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/PythonCharacterManager.cpp` |
| `D3DTSS_COLOROP` | 103 | `src/EffectLib/src/EffectInstance.cpp`<br>`src/EffectLib/src/EffectMeshInstance.cpp`<br>`src/EffectLib/src/ParticleSystemInstance.cpp`<br>`src/EterGrnLib/src/Material.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/SkyBox.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/ActorInstanceRender.cpp`<br>`src/GameLib/src/Area.cpp`<br>`src/GameLib/src/FlyTrace.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorCharacterShadow.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/MapOutdoorWater.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp`<br>`src/GameLib/src/TerrainDecal.cpp`<br>`src/GameLib/src/WeaponTrace.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/InstanceBase.cpp`<br>`src/UserInterface/src/PythonCharacterManager.cpp` |
| `D3DTSS_TCI_CAMERASPACEPOSITION` | 1 | `src/GameLib/src/MapOutdoor.cpp` |
| `D3DTSS_TEXCOORDINDEX` | 10 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapOutdoor.cpp` |
| `D3DTSS_TEXTURETRANSFORMFLAGS` | 5 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp` |

## Sampler states (`D3DSAMP_*`)

| State | Sites | Files |
|---|---:|---|
| `D3DSAMP_ADDRESSU` | 16 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DSAMP_ADDRESSV` | 16 | `src/EterLib/src/StateManager.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DSAMP_MAGFILTER` | 12 | `src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/UserInterface/src/PythonApplicationLogo.cpp`<br>`src/UserInterface/src/PythonMiniMap.cpp` |
| `D3DSAMP_MAXANISOTROPY` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DSAMP_MINFILTER` | 12 | `src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/UserInterface/src/PythonApplicationLogo.cpp`<br>`src/UserInterface/src/PythonMiniMap.cpp` |
| `D3DSAMP_MIPFILTER` | 9 | `src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp` |

## Transforms (`D3DTS_*`)

| Transform | Sites | Files |
|---|---:|---|
| `D3DTS_PROJECTION` | 4 | `src/EterLib/src/GrpBase.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp` |
| `D3DTS_TEXTURE0` | 6 | `src/GameLib/src/MapOutdoorRenderHTP.cpp` |
| `D3DTS_TEXTURE1` | 6 | `src/EterGrnLib/src/Material.cpp`<br>`src/GameLib/src/MapOutdoor.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/UserInterface/src/PythonMiniMap.cpp` |
| `D3DTS_VIEW` | 4 | `src/EterLib/src/GrpBase.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp` |
| `D3DTS_WORLD` | 29 | `src/EffectLib/src/EffectMeshInstance.cpp`<br>`src/EterGrnLib/src/ModelInstanceRender.cpp`<br>`src/EterLib/src/Decal.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/ScreenFilter.cpp`<br>`src/EterLib/src/SkyBox.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp`<br>`src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp`<br>`src/GameLib/src/MapOutdoorRenderSTP.cpp`<br>`src/GameLib/src/MapOutdoorWater.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp`<br>`src/UserInterface/src/PythonBackground.cpp`<br>`src/UserInterface/src/PythonMiniMap.cpp` |

## Texture stages

| Stage argument | `SetTextureStageState` | `SetSamplerState` |
|---|---:|---:|
| `0` | 234 | 35 |
| `1` | 161 | 22 |
| `2` | 7 | 0 |
| `3` | 7 | 0 |
| `4` | 7 | 0 |
| `5` | 7 | 0 |
| `6` | 7 | 0 |
| `7` | 7 | 0 |
| `dwStage` | 3 | 6 |
| `i` | 2 | 7 |

## FVF layouts

Literal `SetFVF` expressions are expanded to their `D3DFVF_*` value; rows
without a value are dynamic (`SetFVF(variable)`), and the backend must track
them through the stream declarations instead.

| FVF expression | Value | Sites | Files |
|---|---|---:|---|
| `D3DFVF_SPEEDTREE_BILLBOARD_VERTEX` | `0x142` | 3 | `src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DFVF_SPEEDTREE_BRANCH_VERTEX` | `0x50242` | 3 | `src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DFVF_SPEEDTREE_LEAF_VERTEX` | `0x150142` | 3 | `src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `D3DFVF_XYZ` | `0x002` | 1 | `src/EterLib/src/StateManager.cpp` |
| `D3DFVF_XYZ | D3DFVF_DIFFUSE | D3DFVF_TEX1` | `0x142` | 19 | `src/EterLib/src/Decal.cpp`<br>`src/EterLib/src/GrpExpandedImageInstance.cpp`<br>`src/EterLib/src/GrpImageInstance.cpp`<br>`src/EterLib/src/GrpMarkInstance.cpp`<br>`src/EterLib/src/GrpScreen.cpp`<br>`src/EterLib/src/GrpTextInstance.cpp`<br>`src/EterLib/src/LensFlare.cpp`<br>`src/EterLib/src/SkyBox.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp` |
| `D3DFVF_XYZ | D3DFVF_NORMAL` | `0x012` | 2 | `src/GameLib/src/MapOutdoorRender.cpp`<br>`src/GameLib/src/MapOutdoorRenderHTP.cpp` |
| `D3DFVF_XYZ | D3DFVF_TEX1` | `0x102` | 4 | `src/EffectLib/src/EffectInstance.cpp`<br>`src/EffectLib/src/EffectMeshInstance.cpp`<br>`src/GameLib/src/SnowEnvironment.cpp`<br>`src/UserInterface/src/PythonMiniMap.cpp` |
| `D3DFVF_XYZ | D3DFVF_TEX1 | D3DFVF_DIFFUSE` | `0x142` | 1 | `src/EterLib/src/BlockTexture.cpp` |
| `D3DFVF_XYZRHW` | `0x004` | 1 | `src/GameLib/src/MapOutdoorRenderSTP.cpp` |
| `D3DFVF_XYZRHW | D3DFVF_DIFFUSE | D3DFVF_SPECULAR | D3DFVF_TEX2` | `0x2C4` | 1 | `src/GameLib/src/MapOutdoorRenderSTP.cpp` |
| `D3DFVF_XYZRHW | D3DFVF_DIFFUSE | D3DFVF_TEX1` | `0x144` | 1 | `src/GameLib/src/SnowEnvironment.cpp` |
| `dwFVF` | `—` | 2 | `src/EterLib/src/StateManager.cpp` |
| `lpMesh->GetFVF()` | `—` | 1 | `src/EterLib/src/GrpScreen.cpp` |
| `m_CopyState.m_dwFVF` | `—` | 1 | `src/EterLib/src/StateManager.cpp` |
| `m_dwVS` | `—` | 1 | `src/EterLib/src/GrpScreen.cpp` |
| `ms_pnt2VS` | `—` | 2 | `src/GameLib/src/DungeonBlock.cpp` |
| `ms_pntVS` | `—` | 6 | `src/EterGrnLib/src/ModelInstanceRender.cpp`<br>`src/EterPythonLib/src/PythonGraphic.cpp` |

## Lights and materials

| File | `SetLight` | `SetMaterial` |
|---|---:|---:|
| `src/EterLib/src/GrpLightManager.cpp` | 1 | 0 |
| `src/EterLib/src/StateManager.cpp` | 1 | 4 |
| `src/EterPythonLib/src/PythonGraphic.cpp` | 2 | 1 |
| `src/GameLib/src/ActorInstanceRender.cpp` | 0 | 2 |
| `src/GameLib/src/MapManager.cpp` | 0 | 1 |
| `src/GameLib/src/MapOutdoor.cpp` | 1 | 0 |
| `src/GameLib/src/MapOutdoorRender.cpp` | 1 | 0 |
| `src/SpeedTreeLib/include/SpeedTreeLib/SpeedTreeMaterial.h` | 0 | 1 |
| `src/UserInterface/src/PythonBackground.cpp` | 2 | 0 |

## Shader no-op delta (D13)

`CreateVertexShader`/`CreatePixelShader` return dummy objects on the GL
path, `SetVertexShader*`/`SetPixelShader*` discard their arguments, and
`D3DXAssembleShaderFromFile*` returns an empty buffer. The calls below are
therefore inert today; T5.2 has to make them real or prove the effect is
fixed-function equivalent.

| Call | Sites | Files |
|---|---:|---|
| `CreatePixelShader` | 1 | `src/EterLib/src/GrpPixelShader.cpp` |
| `CreateVertexShader` | 1 | `src/EterLib/src/GrpVertexShader.cpp` |
| `D3DXAssembleShaderFromFile` | 1 | `src/EterLib/src/GrpVertexShader.cpp` |
| `D3DXAssembleShaderFromFileA` | 1 | `src/EterLib/src/GrpPixelShader.cpp` |
| `SetPixelShader` | 5 | `src/EterLib/src/GrpPixelShader.cpp`<br>`src/EterLib/src/StateManager.cpp` |
| `SetPixelShaderConstant` | 3 | `src/EterLib/src/StateManager.cpp` |
| `SetPixelShaderConstantF` | 1 | `src/EterLib/src/StateManager.cpp` |
| `SetVertexShader` | 13 | `src/EterLib/src/GrpVertexShader.cpp`<br>`src/EterLib/src/StateManager.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `SetVertexShaderConstant` | 10 | `src/EterLib/src/StateManager.cpp`<br>`src/SpeedTreeLib/src/CSpeedTreeDirectX.cpp`<br>`src/SpeedTreeLib/src/SpeedTreeWrapper.cpp` |
| `SetVertexShaderConstantF` | 1 | `src/EterLib/src/StateManager.cpp` |

Runtime counters are exposed by `CShaderStats` (`EterLib`): shader files
created, shader binds and constant uploads, so the delta can be measured
in a real frame instead of only counted statically.
