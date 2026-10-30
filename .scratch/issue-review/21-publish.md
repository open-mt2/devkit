## Parent

https://github.com/open-mt2/devkit/issues/21

## What to build

flip the file-level gate on `Direct3DDevice9Compat.cpp`; drop `<d3dx9.h>`/`<dinput.h>` from `DirectXMathCompat.h:23`; link `opengl32`.

## Acceptance criteria

- [ ] Windows links the GL renderer without the DirectX SDK.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.4 (#60), T1.7 (#61), D1

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:21 -->
