# #115 — Make the packaged client self-contained

- agent: agent-06 (DeepSeek V4.1 Flash)
- date: 2026-10-31
- command: `scripts/build.sh` in `openmt2/client:winx64-wine64` + `python3 tests/test_pack_assets.py` + `ldd dist/metin2client` + Xvfb run
- before: running `dist/metin2client` outside the build image failed with
  `error while loading shared libraries: libzip.so.4`; resolving that exposed
  `No module named posixpath` from the game-side `dist/lib` subset, and packing
  every `bin/pack/` directory produced `ETC.zip` with 6 files plus an orphan
  `etc.zip` (the real cursor/UI textures), so the login screen missed images.
- after: `dist/runtime/` ships `libzip.so.4` and `libpython2.7.so.1.0`;
  RUNPATH is `$ORIGIN/runtime:/usr/local/lib`; the full CPython 2.7 stdlib is
  overlaid into `dist/lib` (with `lib-dynload` flattened); archives are built
  from `pack/Index` (102 archives, case variants merged, unindexed directories
  ignored). With both system libraries hidden, `ldd` resolves them from
  `dist/runtime`; the client stays alive for 30 s at 61 FPS with an empty
  `syserr.txt`.
- notes:
  - `scripts/pack-assets.sh` is the single packer now used by `build.sh`;
    T3.1 reuses it for the Windows dist.
  - `tests/test_pack_assets.py` — 7 tests (index-only packing, case merge,
    index casing, metadata copy, missing directory, relative entries, `--help`).
  - The archive list comes from `pack/Index`; `ETC`/`etc` merge into
    `ETC.zip` (1 230 file entries, including `ymir work/ui/cursor/cursor_hvsize.sub`
    and `ymir work/ui/pattern/board_corner_lefttop.tga`).
  - Knobs: `OPENMT2_DIST_DIR` (dist location), `BUNDLED_RUNTIME_LIBS`,
    `PYTHON27_BIN`, `PACK_ARCHIVER`.
  - Verification: `ctest` **48/48**; `python3 tests/test_pack_assets.py`
    **7/7**; `scripts/golden-check.sh` unchanged (checked in T3.1).
  - Follow-up: `Py_Finalize()` can still raise `Fatal Signal: 11` after a
    failed `RunMain`; independent of library resolution.
