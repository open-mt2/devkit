## Parent

https://github.com/open-mt2/devkit/issues/12

## What to build

keep include roots (`<EterBase/...>`) and target aliases (`EterBase::EterBase` → `Neoeter::Platform`); replace `packages.map` + `fetch-packages.sh` with `fetch-sources.sh` (3 repos).

## Acceptance criteria

- [ ] `build.sh` and the image work unchanged against the new layout.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

TB.1, TB.2
