## Parent

https://github.com/open-mt2/devkit/issues/5

## What to build

scripted offscreen scenes under llvmpipe/OSMesa; PNG hashes committed; `glReadPixels` based now, `Readback()` formalises it in T1.7; image-diff tool reused by T3.2/T5.4.

## Acceptance criteria

- [ ] ≥10 scenes pinned; diff tool reports per-scene similarity; runs headless in CI.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

TA.1 (#2)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:5 -->
