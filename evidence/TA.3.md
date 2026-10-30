# TA.3 — Binary formats, fixtures, fuzzing

- agent: agent-01
- date: 2026-10-30
- command: `ctest -R "pack|gr2|treecache|packet"` and `scripts/fuzz-smoke.sh --seconds 60`
- before: 30/30 CTest pass after TA.2. No synthetic binary fixtures, no fuzz targets. Pack coverage was one happy-path ZIP; the GR2 test silently skipped when game assets were absent; treecache had no reader test; packets only had a size smoke check.
- after: 34/34 CTest pass. Targeted filter 5/5. Three libFuzzer targets build under clang + ASan and each survived a 60 s run.
- notes: no game assets are committed. EIX/EPK are not implemented in this tree (see below).

## Slices

| Package | PR | Result |
|---|---|---|
| `pkg_eterpack` | [#2](https://github.com/open-mt2/pkg_eterpack/pull/2) | ZIP/FOLDER round-trip, overlay/search mode, malformed archives, filename folding; `fuzz_pack` |
| `pkg_speedtreelib` | [#2](https://github.com/open-mt2/pkg_speedtreelib/pull/2) | synthetic treecache generator, round-trip + rejection, preflight validation; `fuzz_treecache` |
| `pkg_etergrnlib` | [#2](https://github.com/open-mt2/pkg_etergrnlib/pull/2) | synthetic GR2 generator, truncation/corruption tests, bounded reader + decompressor; `fuzz_gr2` |
| `pkg_userinterface` | [#2](https://github.com/open-mt2/pkg_userinterface/pull/2) | packet sizes, offsets, encode/decode, header map |

## Bugs found and fixed

1. **Treecache partial load.** `LoadBakedGeometry` wrote the bbox and collision list before validating the rest of the record. A rejected cache still left the cache bbox behind while the caller fell back to generated geometry. A side-effect-free `ValidateBakedGeometry` preflight now checks every count against the remaining bytes before parsing; it also refuses counts that cannot fit, so hostile inputs cannot trigger oversized allocations.
2. **Treecache unbounded counts.** Collision, indexed-part and leaf counts were trusted directly. All are now bounded (`collisionCount * 28`, `indexCount * 2 + vertexCount * 44`, `leafCount * 114`), with sane caps for vertex/index/leaf counts.
3. **GR2 section arithmetic overflow.** `numSec * 44` and `numReloc * 12` were computed in 32 bits, so huge counts wrapped past the bounds check and then drove `resize()`/loops. Checks now use `size_t`; sections are capped at 4096 and 256 MiB, and record counts at 200 000.
4. **GR2 Oodle decompressor had no buffer ends.** `Decode()` read past the compressed buffer; back-references could point before the output buffer and write past `decompressed_size`. The decoder now carries `stream_end`, validates `step1 <= step2 <= decompressed_size`, rejects `backref_offset > decoded_size` and any output overrun, and returns `0`; `Gr2Reader` rejects the file instead of using a partially decoded section.
5. **GR2 string fixups** returned pointers into a section without requiring a NUL terminator. `ResolveString` now bounded-scans and returns `""` for corrupt names.
6. **EterPack standalone build** defined `timeGetTime` even though `Platform.h` already provides it, so the standalone CI build (and every compile without `EterBase/Debug.h`) failed with a redefinition. The fallback is gone.
7. **Clang portability in `Gr2Reader`**: the `parseCurve` lambda captured a C++17 structured binding, which GCC accepts and clang rejects. Replaced with plain locals.

## Fixtures

Committed as code, never as assets:

- `EterPack/tests/support/PackFixtures.h` — libzip-generated archives (nested paths, empty/binary/NUL payloads).
- `EterGrnLib/tests/support/Gr2Fixture.h` — one-section GR2 with a relocation table, `granny_file_info` type tree, model array and one named model.
- `SpeedTreeLib/tests/support/TreeCacheFixture.h` — `MT2T` cache with bbox, cylinder collision, one branch strip, inactive fronds/leaves/billboards, plus a huge-count variant.

## Fuzzing

`scripts/fuzz-smoke.sh` configures `build-fuzz/` with clang + ASan, builds the three targets and runs them for `--seconds` each (default 10; the task run used 60).

| Target | 60 s executions | Result |
|---|---:|---|
| `fuzz_gr2` | 95 317 | no crash, no leak |
| `fuzz_treecache` | 682 932 | no crash, no leak |
| `fuzz_pack` | 941 397 | no crash, no leak |

The image needed one new package for this: `libclang-rt-14-dev` (Debian's `clang` does not pull compiler-rt, so `-fsanitize=fuzzer,address` failed at link time).

## Deviations / follow-ups

- **EIX/EPK are absent.** The client VFS in this tree only implements ZIP and FOLDER; `EPKModes` in `Packet.h` is unrelated. Reproducing EIX/EPK would require importing the server-side pack code, which is out of scope for a test-only wave. Coverage follows the code that ships.
- Packet "deserialisation" is exercised as wire-layout + `memcpy` round-trip plus the header map. There is no standalone packet parser outside `CPythonNetworkStream` (socket + Python), so no parser fuzz target is provided.
- `fuzz_pack` measures harness/ZIP-provider coverage; libzip itself is only linked, not instrumented.
