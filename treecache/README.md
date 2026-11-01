# Tree geometry cache

This directory holds the baked SpeedTree geometry cache used by the client at
runtime. It is generated from the original `bin/pack/**/*.spt` assets and is
keyed by the FNV-1a hash of each `.spt` file:

```
bin/pack/**/foo.spt  ->  treecache/<fnv1a32(foo.spt)>.tree
```

The client looks for `<hash>.tree` in `treecache/`, `../treecache/` and
`dist/treecache/` (see `CSpeedTreeRT::LoadBakedGeometry`). `scripts/build.sh`
copies this directory into `dist/treecache/` when assembling the package.

## Why it is versioned here

The cache is derived content: it carries the geometry produced by the
proprietary SpeedTreeRT SDK from the original client assets. It is kept in the
devkit so that building a client no longer needs the SpeedTree source tree,
`clang`/`lld`, Wine or the 32-bit Windows import libraries.

The public release image therefore contains `treecache/`. The other
proprietary inputs (`bin/`, `pack/` archives, `dist/`) are still fetched or
built by the consumer and remain covered by
`scripts/verify-no-proprietary.sh`. Move the cache to a private asset source if
that policy is tightened again.

## Provenance

This snapshot was generated on 2026-11-01 from the 118 `.spt` assets in
`bin/pack` (local `openmt2/client:buildonly-eaa9495` build), seed 1, with
`speedtreebkr` 1.0.0. The dumper and `SpeedTreeRT.dll` hashes are recorded in
`MANIFEST.json`.

## MANIFEST.json

`MANIFEST.json` records, for every asset:

| Field | Meaning |
| --- | --- |
| `spt` | path relative to `bin/pack` |
| `file` | cache file name, `<fnv1a32>.tree` |
| `fnv1a32` | hash of the `.spt` bytes (the cache key) |
| `spt_bytes` | size of the `.spt` file |
| `bytes` | size of the `.tree` file |
| `sha256` | hash of the `.tree` file |

`generator` records the `speedtreebkr` version, tree format version, seed,
dumper hash and `SpeedTreeRT.dll` hash used to produce the cache. `source`
records the asset globs and counts.

Re-baking can change the branch strip ordering for some trees even when the
vertex data is identical (a small number of `GetGeometry` index lists are not
stable across processes). Do not expect bit-identical `.tree` output across
runs; always commit the `.tree` files together with the manifest that
describes them.

## Verification

```bash
# manifest + file integrity only
python3 scripts/verify-treecache.py

# also check every .spt in bin/pack has a cache entry
python3 scripts/verify-treecache.py --bin bin --strict
```

`--strict` turns a coverage gap (a new or edited `.spt` with no matching
cache file) into a failure. Without it, gaps are reported as warnings; the
client would silently fall back to its procedural generator for those trees.

## Regeneration

The cache is produced by
[open-mt2/speedtreebkr](https://github.com/open-mt2/speedtreebkr):

```bash
# from the client root, with bin/pack present
tools/speedtree_baker/bake.py --force --manifest treecache/MANIFEST.json
```

`bake.py` needs `SpeedTreeRT.dll` and a `speedtree_dumper.exe`. See the
`speedtreebkr` README for the prebuilt dumper and the Wine requirements. This
is only needed when adding or editing trees; normal devkit builds use this
directory as-is.
