# runtime-dist — self-contained Linux `dist/`

- agent: opencode / DeepSeek V4.1 Flash
- date: 2026-10-31
- command: `docker run ... openmt2/client shell /bin/bash -c '/workspace/scripts/build.sh -t --skip-pack'`
- before: `ldd dist/metin2client` on a host reported
  `libzip.so.4 => not found` and `libpython2.7.so.1.0 => not found`; running
  `./metin2client` stopped at
  `error while loading shared libraries: libzip.so.4`. Supplying the libraries
  manually exposed two more blockers: `No module named posixpath` (the shipped
  `bin/lib` is an incomplete, Windows-oriented stdlib subset) and missing pack
  assets because `bin/pack/Index` names `ETC` while the case-sensitive checkout
  also contains `etc/`.
- after:
  - `readelf -d dist/metin2client` shows
    `RUNPATH [$ORIGIN/runtime:/usr/local/lib]`.
  - `ldd dist/metin2client` resolves
    `libzip.so.4 => dist/runtime/libzip.so.4` and
    `libpython2.7.so.1.0 => dist/runtime/libpython2.7.so.1.0`.
  - `dist/lib` contains the full CPython 2.7.18 stdlib (`posixpath.pyc`,
    current `locale.pyc`, flattened `lib-dynload` extensions).
  - `pack-assets.sh` produces `dist/pack/ETC.zip` (merged `ETC/` + `etc/`,
    1,314 entries including `ymir work/ui/cursor/cursor_hvsize.sub` and
    `ymir work/ui/pattern/board_corner_lefttop.tga`) and 102 archives total.
  - `cd dist && ./metin2client` (no `LD_LIBRARY_PATH`, host Arch Linux,
    Wayland) reaches `NEW LOGIN WINDOW` / `CLOSE LOGO WINDOW`; `log.txt`
    contains no `SYSERR` lines and no `ErrorLog.txt` is written.
  - `ctest --test-dir build --output-on-failure`: 47/47 passed.
  - `python3 tests/test_pack_assets.py`: 6/6 passed.
- notes: The pack helper is `scripts/pack-assets.sh`; the RPATH is set in
  `docker/root/CMakeLists.txt`. Bundled libraries are controlled by
  `BUNDLED_RUNTIME_LIBS` (default `libzip.so.4 libpython2.7.so.1.0`).
  Follow-up: `Py_Finalize()` can still raise `Fatal Signal: 11` on shutdown
  after a failed `RunMain`; that is independent of library resolution and was
  observed in the pre-fix `ErrorLog.txt`.
