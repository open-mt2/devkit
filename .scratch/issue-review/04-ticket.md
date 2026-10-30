## Parent

https://github.com/open-mt2/devkit/issues/4

## What to build

pack (`EIX`/`EPK`/zip), `.gr2` reader, `treecache` reader, network packet (de)serialisation; synthetic fixture generator committed as code; libFuzzer targets.

## Acceptance criteria

- [ ] round-trip + malformed-input tests; fuzz targets build and survive a 60 s run; **no game assets committed**.
- [ ] Record the parent task’s required verification and before/after evidence.

## Blocked by

TA.1
