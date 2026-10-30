# TA.2 — Pure-logic characterization tests

- agent: agent-01
- date: 2026-10-30
- command: `ctest -R "crc|tea|lzo|file|locale|math|detector|dxt"` (built with `openmt2/client -t --skip-pack`)
- before: 27/27 CTest pass. Coverage limited to the first three slices (EterBase, EterLocale, SphereLib); `test_image` decompressed one DXT1 block and `test_eterlib` was a smoke test only. Two product bugs were already fixed by earlier slices: `GetCaseCRC32` never folded case, and `tea_encrypt` wrote padding past its const source buffer.
- after: 30/30 CTest pass with asserts active. `ctest -R "crc|tea|lzo|file|locale|math|detector|dxt"` runs 12/12 targeted tests. A third product bug was found and fixed: OBB collision transformed the sphere by the box rotation instead of its inverse.
- notes: see the slices below. No game assets, GPU or audio device are needed.

## Slices

| Package | PR | Result |
|---|---|---|
| `pkg_eterbase` | [#2](https://github.com/open-mt2/pkg_eterbase/pull/2) | CRC32 vectors, LZO edge cases; **fix** case-insensitive CRC |
| `pkg_eterlocale` | [#2](https://github.com/open-mt2/pkg_eterlocale/pull/2) | UTF-8/CP1252/CP949 round-trips and size queries |
| `pkg_spherelib` | [#2](https://github.com/open-mt2/pkg_spherelib/pull/2) | vector arithmetic, ray/sphere invariants |
| `pkg_eterbase` | [#3](https://github.com/open-mt2/pkg_eterbase/pull/3) | TEA vectors; **fix** padding write past source |
| `pkg_eterimagelib` | [#2](https://github.com/open-mt2/pkg_eterimagelib/pull/2) | DXT1/3/5 blocks, mip chain, header validation |
| `pkg_eterlib` | [#3](https://github.com/open-mt2/pkg_eterlib/pull/3) | `GrpMath`, `CRay`, OBB detector; **fix** OBB inverse rotation |

## EterImageLib (DXT)

`test_dxt_invariants` adds 8 sections:

- DXT1 four-colour mode: all four 2-bit selectors and exact 2/3 interpolation.
- DXT1 three-colour mode: median colour and transparent selector 3.
- DXT3: all 16 explicit alpha nibbles expand to 8-bit.
- DXT5: 8-alpha and 6-alpha interpolation, including pinned codes 0 and 255.
- 8x8 block-grid addressing (row-major blocks, per-row selectors).
- Mip chain: level-1 pointer from `dwLinearSize`, per-level decompression, `Copy()`.
- Header validation: empty/truncated input, bad magic, DXT2/DXT4/unknown fourCC.

No product bug in the covered paths. `m_bMipTexture` is left unasserted for a
single-level file: it is true whenever `dwMipMapCount > 0`, but nothing reads the
field.

## EterLib (GrpMath / ray / OBB)

`test_grpmath`: `CrossProduct2D`, `IsInTriangle2D` (interior, vertices, edges,
line extensions), `ClampDegree` (one wrap), vector/quaternion blend,
`GetVector3Distance` (documented as squared **XZ** distance), segment-point
distance (endpoint clamp, perpendicular, degenerate segment), quaternion rotation
helpers, and `CRay` normalisation/endpoints.

`test_detector`: OBB containment for axis-aligned and 45-degree yawed boxes,
sphere-radius margin, and the swept-position check.

**Bug**: `COBBCollisionInstance` applies `matRot` (local -> world) to the sphere
before clamping against world-aligned `v3Min`/`v3Max`. The correct transform is
world -> local. With a 45-degree yaw and half extents `(2, 0.5, 0.5)`, the local
point `(1.5, 0.4)` is inside the box, but it was rejected:

```
[FAIL] tests/test_detector.cpp:104: collides(obb.instance, toWorld(obb, insideLocal), 0.001f)
```

The fix adds `TOBBData::matRotInv`, computed with `D3DXMatrixInverse` when the
instance is built; both collision entry points use it and `Render` keeps using
`matRot`. After the fix the test passes (30/30).

## Deviations / follow-ups

- The OBB test is named `test_detector` so the task's verification regex
  (`…|math|detector|dxt`) selects it; it covers collision, not
  `D3D_CDisplayModeAutoDetector`.
- `D3DXVec3Rotation` composes quaternions in the opposite order (`q^-1 v q`) and
  is unused; only its identity case is pinned.
- `ClampDegree` only normalises one wrap. Out-of-range inputs (`720`, `-361`) are
  not covered because no caller feeds them.
- The task sheet's regex does not select the SphereLib test names; the full
  `ctest` run covers them.
