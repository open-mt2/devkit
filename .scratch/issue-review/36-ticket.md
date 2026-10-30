## Parent

https://github.com/open-mt2/devkit/issues/36

## What to build

fixed-function → GLSL/SPIR-V generator (uber-shader keyed by `RenderState`); D3D9 bytecode → SPIR-V (`vkd3d-shader` evaluation); closes the GL shader no-op.

## Acceptance criteria

- [ ] feature matrix and all shader effects render on both backends.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.8, T5.1, D12
