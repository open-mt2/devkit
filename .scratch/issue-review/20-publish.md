## Parent

https://github.com/open-mt2/devkit/issues/20

## What to build

runtime proc loading (`SDL_GL_GetProcAddress` or vendored glad) for `glActiveTexture`, `glGenFramebuffers`, `glCompressedTexImage2D`, `glClipControl`, …; request GL 3.0+.

## Acceptance criteria

- [ ] renderer initialises on Windows; no unresolved `gl*`.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.2 (#58)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:20 -->
