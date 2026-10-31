# Fixed-function feature matrix

> **Generated — do not edit by hand.** `scripts/feature-matrix.sh --write`;
> verify with `scripts/feature-matrix.sh --check` (also run by `ctest`/CI).
>
> Source: `src/**/*.{cpp,c,h,hpp,inl}` with comments and string literals
> removed, excluding `tests/` and the renderer/platform implementation
> (`include/Neoeter/Platform/Base/`, `src/neoeter/src/platform/base/`). Those directories
> consume the state; this file lists what the game and engine *ask for*.

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
| `D3DRS_ALPHABLENDENABLE` | 12 | `src/client/src/game/Area.cpp`<br>`src/client/src/game/MapOutdoorWater.cpp`<br>`src/client/src/game/SnowEnvironment.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/effect/EffectMeshInstance.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_ALPHAFUNC` | 3 | `src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_ALPHAREF` | 6 | `src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_ALPHATESTENABLE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_AMBIENT` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_AMBIENTMATERIALSOURCE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_BLENDOP` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_CLIPPING` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_CLIPPLANEENABLE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_COLORVERTEX` | 6 | `src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_COLORWRITEENABLE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_CULLMODE` | 8 | `src/neoeter/src/model/grn/Material.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpExpandedImageInstance.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_DESTBLEND` | 10 | `src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/SnowEnvironment.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/effect/EffectMeshInstance.cpp`<br>`src/neoeter/src/effect/ParticleSystemInstance.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_DIFFUSEMATERIALSOURCE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_DITHERENABLE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_EMISSIVEMATERIALSOURCE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FILLMODE` | 8 | `src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/ui/PythonApplication.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FOGCOLOR` | 8 | `src/client/src/game/MapManager.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FOGDENSITY` | 2 | `src/client/src/game/MapManager.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FOGENABLE` | 20 | `src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/ui/InstanceBase.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FOGEND` | 2 | `src/client/src/game/MapManager.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FOGSTART` | 2 | `src/client/src/game/MapManager.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FOGTABLEMODE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_FOGVERTEXMODE` | 4 | `src/client/src/game/MapManager.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_INDEXEDVERTEXBLENDENABLE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_LASTPIXEL` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_LIGHTING` | 32 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/FlyTrace.cpp`<br>`src/client/src/game/MapOutdoorCharacterShadow.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/WeaponTrace.cpp`<br>`src/client/src/ui/InstanceBase.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_LOCALVIEWER` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_MULTISAMPLEANTIALIAS` | 2 | `src/neoeter/src/render/GrpDevice.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_MULTISAMPLEMASK` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_NORMALIZENORMALS` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_RANGEFOGENABLE` | 2 | `src/client/src/game/MapManager.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_SHADEMODE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_SPECULARENABLE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_SPECULARMATERIALSOURCE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_SRCBLEND` | 10 | `src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/SnowEnvironment.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/effect/EffectMeshInstance.cpp`<br>`src/neoeter/src/effect/ParticleSystemInstance.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_STENCILENABLE` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_STENCILWRITEMASK` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_TEXTUREFACTOR` | 38 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/DungeonBlock.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/ui/PythonMiniMap.cpp`<br>`src/neoeter/src/effect/EffectMeshInstance.cpp`<br>`src/neoeter/src/effect/ParticleInstance.cpp`<br>`src/neoeter/src/model/grn/Material.cpp`<br>`src/neoeter/src/render/CollisionData.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp` |
| `D3DRS_VERTEXBLEND` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP0` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP1` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP2` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP3` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP4` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP5` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP6` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_WRAP7` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_ZENABLE` | 3 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_ZFUNC` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DRS_ZWRITEENABLE` | 3 | `src/client/src/game/Area.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |

## Texture-stage states (`D3DTSS_*`)

| State | Sites | Files |
|---|---:|---|
| `D3DTSS_ALPHAARG1` | 57 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/FlyTrace.cpp`<br>`src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/MapOutdoorWater.cpp`<br>`src/client/src/game/SnowEnvironment.cpp`<br>`src/client/src/game/TerrainDecal.cpp`<br>`src/client/src/game/WeaponTrace.cpp`<br>`src/client/src/ui/PythonCharacterManager.cpp`<br>`src/neoeter/src/effect/EffectInstance.cpp`<br>`src/neoeter/src/model/grn/Material.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/SkyBox.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTSS_ALPHAARG2` | 32 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/FlyTrace.cpp`<br>`src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/WeaponTrace.cpp`<br>`src/neoeter/src/effect/EffectInstance.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTSS_ALPHAOP` | 99 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/FlyTrace.cpp`<br>`src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorCharacterShadow.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/MapOutdoorWater.cpp`<br>`src/client/src/game/SnowEnvironment.cpp`<br>`src/client/src/game/TerrainDecal.cpp`<br>`src/client/src/game/WeaponTrace.cpp`<br>`src/client/src/ui/InstanceBase.cpp`<br>`src/client/src/ui/PythonCharacterManager.cpp`<br>`src/neoeter/src/effect/EffectInstance.cpp`<br>`src/neoeter/src/model/grn/Material.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/SkyBox.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTSS_COLORARG1` | 80 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/FlyTrace.cpp`<br>`src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorCharacterShadow.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/MapOutdoorWater.cpp`<br>`src/client/src/game/SnowEnvironment.cpp`<br>`src/client/src/game/TerrainDecal.cpp`<br>`src/client/src/game/WeaponTrace.cpp`<br>`src/client/src/ui/InstanceBase.cpp`<br>`src/client/src/ui/PythonCharacterManager.cpp`<br>`src/client/src/ui/PythonMiniMap.cpp`<br>`src/neoeter/src/effect/EffectInstance.cpp`<br>`src/neoeter/src/model/grn/Material.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/SkyBox.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTSS_COLORARG2` | 52 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/FlyTrace.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/WeaponTrace.cpp`<br>`src/client/src/ui/PythonCharacterManager.cpp`<br>`src/neoeter/src/effect/EffectInstance.cpp`<br>`src/neoeter/src/model/grn/Material.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/SkyBox.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTSS_COLOROP` | 103 | `src/client/src/game/ActorInstanceRender.cpp`<br>`src/client/src/game/Area.cpp`<br>`src/client/src/game/FlyTrace.cpp`<br>`src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorCharacterShadow.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/MapOutdoorWater.cpp`<br>`src/client/src/game/SnowEnvironment.cpp`<br>`src/client/src/game/TerrainDecal.cpp`<br>`src/client/src/game/WeaponTrace.cpp`<br>`src/client/src/ui/InstanceBase.cpp`<br>`src/client/src/ui/PythonCharacterManager.cpp`<br>`src/neoeter/src/effect/EffectInstance.cpp`<br>`src/neoeter/src/effect/EffectMeshInstance.cpp`<br>`src/neoeter/src/effect/ParticleSystemInstance.cpp`<br>`src/neoeter/src/model/grn/Material.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/SkyBox.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTSS_TCI_CAMERASPACEPOSITION` | 1 | `src/client/src/game/MapOutdoor.cpp` |
| `D3DTSS_TEXCOORDINDEX` | 10 | `src/client/src/game/MapOutdoor.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTSS_TEXTURETRANSFORMFLAGS` | 5 | `src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |

## Sampler states (`D3DSAMP_*`)

| State | Sites | Files |
|---|---:|---|
| `D3DSAMP_ADDRESSU` | 16 | `src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DSAMP_ADDRESSV` | 16 | `src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DSAMP_MAGFILTER` | 12 | `src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/ui/PythonApplicationLogo.cpp`<br>`src/client/src/ui/PythonMiniMap.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DSAMP_MAXANISOTROPY` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DSAMP_MINFILTER` | 12 | `src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/ui/PythonApplicationLogo.cpp`<br>`src/client/src/ui/PythonMiniMap.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DSAMP_MIPFILTER` | 9 | `src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |

## Transforms (`D3DTS_*`)

| Transform | Sites | Files |
|---|---:|---|
| `D3DTS_PROJECTION` | 4 | `src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/render/GrpBase.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTS_TEXTURE0` | 6 | `src/client/src/game/MapOutdoorRenderHTP.cpp` |
| `D3DTS_TEXTURE1` | 6 | `src/client/src/game/MapOutdoor.cpp`<br>`src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/ui/PythonMiniMap.cpp`<br>`src/neoeter/src/model/grn/Material.cpp` |
| `D3DTS_VIEW` | 4 | `src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/render/GrpBase.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `D3DTS_WORLD` | 29 | `src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp`<br>`src/client/src/game/MapOutdoorRenderSTP.cpp`<br>`src/client/src/game/MapOutdoorWater.cpp`<br>`src/client/src/ui/PythonBackground.cpp`<br>`src/client/src/ui/PythonMiniMap.cpp`<br>`src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/effect/EffectMeshInstance.cpp`<br>`src/neoeter/src/model/grn/ModelInstanceRender.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/Decal.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/ScreenFilter.cpp`<br>`src/neoeter/src/render/SkyBox.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |

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
| `D3DFVF_SPEEDTREE_BILLBOARD_VERTEX` | `0x142` | 3 | `src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp` |
| `D3DFVF_SPEEDTREE_BRANCH_VERTEX` | `0x50242` | 3 | `src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp` |
| `D3DFVF_SPEEDTREE_LEAF_VERTEX` | `0x150142` | 3 | `src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp` |
| `D3DFVF_XYZ` | `0x002` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `D3DFVF_XYZ | D3DFVF_DIFFUSE | D3DFVF_TEX1` | `0x142` | 19 | `src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/render/Decal.cpp`<br>`src/neoeter/src/render/GrpExpandedImageInstance.cpp`<br>`src/neoeter/src/render/GrpImageInstance.cpp`<br>`src/neoeter/src/render/GrpMarkInstance.cpp`<br>`src/neoeter/src/render/GrpScreen.cpp`<br>`src/neoeter/src/render/GrpTextInstance.cpp`<br>`src/neoeter/src/render/LensFlare.cpp`<br>`src/neoeter/src/render/SkyBox.cpp` |
| `D3DFVF_XYZ | D3DFVF_NORMAL` | `0x012` | 2 | `src/client/src/game/MapOutdoorRender.cpp`<br>`src/client/src/game/MapOutdoorRenderHTP.cpp` |
| `D3DFVF_XYZ | D3DFVF_TEX1` | `0x102` | 4 | `src/client/src/game/SnowEnvironment.cpp`<br>`src/client/src/ui/PythonMiniMap.cpp`<br>`src/neoeter/src/effect/EffectInstance.cpp`<br>`src/neoeter/src/effect/EffectMeshInstance.cpp` |
| `D3DFVF_XYZ | D3DFVF_TEX1 | D3DFVF_DIFFUSE` | `0x142` | 1 | `src/neoeter/src/render/BlockTexture.cpp` |
| `D3DFVF_XYZRHW` | `0x004` | 1 | `src/client/src/game/MapOutdoorRenderSTP.cpp` |
| `D3DFVF_XYZRHW | D3DFVF_DIFFUSE | D3DFVF_SPECULAR | D3DFVF_TEX2` | `0x2C4` | 1 | `src/client/src/game/MapOutdoorRenderSTP.cpp` |
| `D3DFVF_XYZRHW | D3DFVF_DIFFUSE | D3DFVF_TEX1` | `0x144` | 1 | `src/client/src/game/SnowEnvironment.cpp` |
| `dwFVF` | `—` | 2 | `src/neoeter/src/render/StateManager.cpp` |
| `lpMesh->GetFVF()` | `—` | 1 | `src/neoeter/src/render/GrpScreen.cpp` |
| `m_CopyState.m_dwFVF` | `—` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `m_dwVS` | `—` | 1 | `src/neoeter/src/render/GrpScreen.cpp` |
| `ms_pnt2VS` | `—` | 2 | `src/client/src/game/DungeonBlock.cpp` |
| `ms_pntVS` | `—` | 6 | `src/neoeter-python/src/bindings/PythonGraphic.cpp`<br>`src/neoeter/src/model/grn/ModelInstanceRender.cpp` |

## Lights and materials

| File | `SetLight` | `SetMaterial` |
|---|---:|---:|
| `src/client/src/game/ActorInstanceRender.cpp` | 0 | 2 |
| `src/client/src/game/MapManager.cpp` | 0 | 1 |
| `src/client/src/game/MapOutdoor.cpp` | 1 | 0 |
| `src/client/src/game/MapOutdoorRender.cpp` | 1 | 0 |
| `src/client/src/ui/PythonBackground.cpp` | 2 | 0 |
| `src/neoeter-python/src/bindings/PythonGraphic.cpp` | 2 | 1 |
| `src/neoeter/include/Neoeter/Model/SpeedTree/SpeedTreeMaterial.h` | 0 | 1 |
| `src/neoeter/src/render/GrpLightManager.cpp` | 1 | 0 |
| `src/neoeter/src/render/StateManager.cpp` | 1 | 4 |

## Shader no-op delta (D13)

`CreateVertexShader`/`CreatePixelShader` return dummy objects on the GL
path, `SetVertexShader*`/`SetPixelShader*` discard their arguments, and
`D3DXAssembleShaderFromFile*` returns an empty buffer. The calls below are
therefore inert today; T5.2 has to make them real or prove the effect is
fixed-function equivalent.

| Call | Sites | Files |
|---|---:|---|
| `CreatePixelShader` | 1 | `src/neoeter/src/render/GrpPixelShader.cpp` |
| `CreateVertexShader` | 1 | `src/neoeter/src/render/GrpVertexShader.cpp` |
| `D3DXAssembleShaderFromFile` | 1 | `src/neoeter/src/render/GrpVertexShader.cpp` |
| `D3DXAssembleShaderFromFileA` | 1 | `src/neoeter/src/render/GrpPixelShader.cpp` |
| `SetPixelShader` | 5 | `src/neoeter/src/render/GrpPixelShader.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `SetPixelShaderConstant` | 3 | `src/neoeter/src/render/StateManager.cpp` |
| `SetPixelShaderConstantF` | 1 | `src/neoeter/src/render/StateManager.cpp` |
| `SetVertexShader` | 13 | `src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/GrpVertexShader.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `SetVertexShaderConstant` | 10 | `src/neoeter/src/model/speedtree/CSpeedTreeDirectX.cpp`<br>`src/neoeter/src/model/speedtree/SpeedTreeWrapper.cpp`<br>`src/neoeter/src/render/StateManager.cpp` |
| `SetVertexShaderConstantF` | 1 | `src/neoeter/src/render/StateManager.cpp` |

Runtime counters are exposed by `CShaderStats` (`EterLib`): shader files
created, shader binds and constant uploads, so the delta can be measured
in a real frame instead of only counted statically.
