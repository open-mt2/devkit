## Parent

https://github.com/open-mt2/devkit/issues/27

## What to build

SDL2, zlib, lzo2, libzip (optional jpeg) via ExternalProject/vcpkg overlay; pinned; baked into the image.

## Acceptance criteria

- [ ] toolchain file resolves everything without host libraries.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

T0.2 (#55)

This child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.

<!-- to-tickets-review-parent:27 -->
