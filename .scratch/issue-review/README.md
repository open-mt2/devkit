# Proposed issue rewrites

Source: all 40 issues and their comments in open-mt2/devkit. No implementation performed.

Create one child rewrite for each unfinished task; retain original IDs, parent scope and deferred status. Keep #1/#39 as tracking records and #2/#3 closed. Reviews are separate comments.

1. **[TA.3] Binary formats, fixtures, fuzzing** (parent #4)
   - **Blocked by:** TA.1
   - **What it delivers:** round-trip + malformed-input tests; fuzz targets build and survive a 60 s run; **no game assets committed**.
   - [Ticket draft](04-ticket.md) · [Review comment](04-review.md)

2. **[TA.4] Headless renderer goldens** (parent #5)
   - **Blocked by:** TA.1
   - **What it delivers:** ≥10 scenes pinned; diff tool reports per-scene similarity; runs headless in CI.
   - [Ticket draft](05-ticket.md) · [Review comment](05-review.md)

3. **[TA.5] Headless audio / effect / model** (parent #6)
   - **Blocked by:** TA.1
   - **What it delivers:** tests run with no sound device and no GPU.
   - [Ticket draft](06-ticket.md) · [Review comment](06-review.md)

4. **[TA.6] Python binding smoke tests** (parent #7)
   - **Blocked by:** TA.1
   - **What it delivers:** interpreter boots in CI; API snapshot committed.
   - [Ticket draft](07-ticket.md) · [Review comment](07-review.md)

5. **[TA.7] Coverage ratchet** (parent #8)
   - **Blocked by:** TA.2
   - **What it delivers:** ratchet enforced in CI.
   - [Ticket draft](08-ticket.md) · [Review comment](08-review.md)

6. **[TA.8] Pre-refactor snapshots** (parent #9)
   - **Blocked by:** TA.2–TA.6
   - **What it delivers:** `golden/` committed; every later wave diffs against it.
   - [Ticket draft](09-ticket.md) · [Review comment](09-review.md)

7. **[TB.1] Merge engine layers L0–L3 into `neoeter`** (parent #10)
   - **Blocked by:** TA.8, D14
   - **What it delivers:** same targets, same 22 CTest cases, same golden hashes.
   - [Ticket draft](10-ticket.md) · [Review comment](10-review.md)

8. **[TB.2] Create `neoeter-python` and `client`** (parent #11)
   - **Blocked by:** TB.1
   - **What it delivers:** same golden hashes; target graph unchanged.
   - [Ticket draft](11-ticket.md) · [Review comment](11-review.md)

9. **[TB.3] Compatibility shims + devkit rewire** (parent #12)
   - **Blocked by:** TB.1, TB.2
   - **What it delivers:** `build.sh` and the image work unchanged against the new layout.
   - [Ticket draft](12-ticket.md) · [Review comment](12-review.md)

10. **[TB.4] Archive old repositories** (parent #13)
   - **Blocked by:** TB.3
   - **What it delivers:** the 3 new repos are the only writable source of truth.
   - [Ticket draft](13-ticket.md) · [Review comment](13-review.md)

11. **[T0.1] Toolchain spike (read-only)** (parent #14)
   - **Blocked by:** D8
   - **What it delivers:** ranked blocker list replaces the assumptions in the plan.
   - [Ticket draft](14-ticket.md) · [Review comment](14-review.md)

12. **[T0.2] Build harness** (parent #15)
   - **Blocked by:** D7, D8, TB.3 (soft)
   - **What it delivers:** `docker run … windows` configures and fails only on missing deps.
   - [Ticket draft](15-ticket.md) · [Review comment](15-review.md)

13. **[T0.3] Data-width audit** (parent #16)
   - **Blocked by:** D10
   - **What it delivers:** documented audit + list of required `static_assert`s.
   - [Ticket draft](16-ticket.md) · [Review comment](16-review.md)

14. **[T1.1] Replace `__LINUX__` with explicit macros** (parent #17)
   - **Blocked by:** T0.2
   - **What it delivers:** no new `__LINUX__`; Linux output unchanged.
   - [Ticket draft](17-ticket.md) · [Review comment](17-review.md)

15. **[T1.2] SDL2 window and event loop on both targets** (parent #18)
   - **Blocked by:** T1.1, D2
   - **What it delivers:** no `CreateWindowEx` in tree; window opens under Wine.
   - [Ticket draft](18-ticket.md) · [Review comment](18-review.md)

16. **[T1.3] SDL2 input** (parent #19)
   - **Blocked by:** T1.1, D2
   - **What it delivers:** no `dinput.h` outside legacy headers.
   - [Ticket draft](19-ticket.md) · [Review comment](19-review.md)

17. **[T1.4] GL function loader for Windows** (parent #20)
   - **Blocked by:** T1.2
   - **What it delivers:** renderer initialises on Windows; no unresolved `gl*`.
   - [Ticket draft](20-ticket.md) · [Review comment](20-review.md)

18. **[T1.5] Enable compat renderer on Windows** (parent #21)
   - **Blocked by:** T1.4, T1.7, D1
   - **What it delivers:** Windows links the GL renderer without the DirectX SDK.
   - [Ticket draft](21-ticket.md) · [Review comment](21-review.md)

19. **[T1.6] IME / text input** (parent #22)
   - **Blocked by:** T1.2, D6
   - **What it delivers:** one implementation for both targets.
   - [Ticket draft](22-ticket.md) · [Review comment](22-review.md)

20. **[T1.7] Renderer seam skeleton** (parent #23)
   - **Blocked by:** T1.4, D11
   - **What it delivers:** `grep -rn "gl[A-Z]" eterbase/src` matches only `backends/gl/**`; Linux screenshots byte-identical.
   - [Ticket draft](23-ticket.md) · [Review comment](23-review.md)

21. **[T1.8] Fixed-function feature matrix** (parent #24)
   - **Blocked by:** T1.3, D13
   - **What it delivers:** matrix checked in; T5.2 uses it as its test plan.
   - [Ticket draft](24-ticket.md) · [Review comment](24-review.md)

22. **[T2.1] Remove DevIL** (parent #25)
   - **Blocked by:** D4
   - **What it delivers:** `IL` gone from every CMakeLists and include.
   - [Ticket draft](25-ticket.md) · [Review comment](25-review.md)

23. **[T2.2] libjpeg audit** (parent #26)
   - **Blocked by:** D5, T2.1
   - **What it delivers:** documented decision + build green.
   - [Ticket draft](26-ticket.md) · [Review comment](26-review.md)

24. **[T2.3] Cross-build Windows dependencies** (parent #27)
   - **Blocked by:** T0.2
   - **What it delivers:** toolchain file resolves everything without host libraries.
   - [Ticket draft](27-ticket.md) · [Review comment](27-review.md)

25. **[T2.4] Python 2.7 for Windows** (parent #28)
   - **Blocked by:** D3, TA.6 (recommended)
   - **What it delivers:** `metin2client.exe` boots the interpreter and loads the `.pyc` set.
   - [Ticket draft](28-ticket.md) · [Review comment](28-review.md)

26. **[T2.5] CMake platform hygiene** (parent #29)
   - **Blocked by:** T0.2
   - **What it delivers:** no POSIX libs linked on Windows.
   - [Ticket draft](29-ticket.md) · [Review comment](29-review.md)

27. **[T3.1] Windows packaging** (parent #30)
   - **Blocked by:** T2.3, T2.4
   - **What it delivers:** trees differ only by binary + runtime DLLs.
   - [Ticket draft](30-ticket.md) · [Review comment](30-review.md)

28. **[T3.2] Automated smoke test** (parent #31)
   - **Blocked by:** T3.1, TA.4
   - **What it delivers:** CI fails on crash/black screen on either target.
   - [Ticket draft](31-ticket.md) · [Review comment](31-review.md)

29. **[T3.3] Parity audit** (parent #32)
   - **Blocked by:** T3.2, D9
   - **What it delivers:** pass/fail checklist per item.
   - [Ticket draft](32-ticket.md) · [Review comment](32-review.md)

30. **[T4.1] Delete legacy surface** (parent #33)
   - **Blocked by:** T1.5, T2.1
   - **What it delivers:** `grep -r "mss32\|SpeedTreeRT.lib\|directxsdk\|dinput"` empty.
   - [Ticket draft](33-ticket.md) · [Review comment](33-review.md)

31. **[T4.2] CI + docs** (parent #34)
   - **Blocked by:** T3.1
   - **What it delivers:** green pipeline; docs describe one pipeline.
   - [Ticket draft](34-ticket.md) · [Review comment](34-review.md)

32. **[T5.1] Vulkan backend spike** (parent #35)
   - **Blocked by:** T1.7
   - **What it delivers:** quad renders; GL build untouched.
   - [Ticket draft](35-ticket.md) · [Review comment](35-review.md)

33. **[T5.2] Program synthesis + shader translation** (parent #36)
   - **Blocked by:** T1.8, T5.1, D12
   - **What it delivers:** feature matrix and all shader effects render on both backends.
   - [Ticket draft](36-ticket.md) · [Review comment](36-review.md)

34. **[T5.3] Full Vulkan backend** (parent #37)
   - **Blocked by:** T5.2
   - **What it delivers:** feature matrix passes on Vulkan.
   - [Ticket draft](37-ticket.md) · [Review comment](37-review.md)

35. **[T5.4] Cross-backend conformance harness** (parent #38)
   - **Blocked by:** T3.2, TA.4
   - **What it delivers:** CI reports per-scene similarity.
   - [Ticket draft](38-ticket.md) · [Review comment](38-review.md)

36. **[CI] pkg_eterbase cannot be built standalone (missing stb_image.h, __LINUX__ not propagated)** (parent #41)
   - **Blocked by:** Not specified in source; overlap with #17 and #33 requires coordination.
   - **What it delivers:** The missing-header and unknown-GL-type failures described in the parent no longer occur; the six affected package workflows are restored. Package identities must be established before implementation.
   - [Ticket draft](41-ticket.md) · [Review comment](41-review.md)
