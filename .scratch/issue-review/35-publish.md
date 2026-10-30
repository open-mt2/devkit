## Parent

https://github.com/open-mt2/devkit/issues/35

## What to build

swapchain + clear + one textured quad behind `IRenderBackend`, `OPENMT2_RENDERER=vulkan`; throw the spike away afterwards.

## Acceptance criteria

- [ ] quad renders; GL build untouched.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T1.7 (#61)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:35 -->
