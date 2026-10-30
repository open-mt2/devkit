## Parent

https://github.com/open-mt2/devkit/issues/23

## What to build

`IRenderBackend`, `RenderState`, `RenderHandle`, `RenderCaps`, `DrawCall`; move the 240 GL calls / 58 symbols into `eterbase/src/backends/gl/`. Pure pass-through, **no Vulkan code**.

## Acceptance criteria

- [ ] `grep -rn "gl[A-Z]" eterbase/src` matches only `backends/gl/**`; Linux screenshots byte-identical.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.4 (#60), D11

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:23 -->
