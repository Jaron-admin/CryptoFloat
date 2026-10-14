# Cross-monitor DPI refresh implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Implement and review each owned component independently.

**Goal:** Resolve click-to-recover text scaling with evidence, and capture reusable engineering interfaces.

**Architecture:** Native and Flutter observations feed an opt-in numerical trace. A framework-independent consistency model keeps observation separate from rendering policy. The correction is selected after reproduction.

**Tech Stack:** Win32 C++17, Flutter/Dart, Markdown, local Git.

**Spec:** ../specs/2026-10-14-dpi-refresh-design.md

**Release gate:** final package verified, 2026-10-14. Final build, fresh verification, archive audit and local installation file comparison passed; GitHub publication is tracked by the v1.4.1 tag/release. The initial candidate failed visual acceptance; subsequent R2 A/B checks received positive user feedback, including a separate report that transparent mode is normal. The new alignment regressions and read-only review passed. Both R2 instances are closed.

## Global constraints

- Do not manipulate the real desktop without new explicit permission.
- Use temporary data for tests; retain existing portable settings.
- Keep numerical diagnostics opt-in and bounded; no user text, names, paths or API content.
- Do not claim the rendering symptom fixed from geometry tests alone.
- No dependency changes or platform-wide DPI overrides.

## Review focus

- Pending raster work may ignore an immediate ForceRedraw request.
- DPI changes with unchanged physical dimensions still require correct framework metrics.
- Nested DPI events must not overwrite a stable logical size with a temporary physical size.
- Diagnostic frame callbacks must neither loop indefinitely nor survive disposal.
- Frame timing and viewport consistency do not prove final desktop composition.

## Tasks

- [x] Native trace: add an opt-in sink and parent/child event observations, validate event allowlists and bounded logs with hidden fixtures.
- [x] Flutter trace: report didChangeMetrics, post-frame state and frame timing with a finite payload; cover lifecycle and disabled tracing.
- [x] Create an isolated diagnostic build and request approval for concrete live reproduction.
- [x] Reproduce and correct the concrete minimum-size defect: retain the DPI delivered by `WM_DPICHANGED` for `WM_GETMINMAXINFO` and `VisibleBounds`, rather than deriving the scale from the old rectangle's monitor. The native regression first failed with an old 168-DPI monitor lookup and new 96-DPI window message, then passed after correction.
- [x] Create and verify reusable observation interfaces plus case documentation in EngineeringPlaybook.
- [x] Obtain the user's actual-desktop observation of the installed v1.4.1 diagnostic candidate and close the test instance afterward: normal font size, persistent black flash, no visible taskbar data despite ready/displaying status. This records the result; it does not mark acceptance as passed.
- [x] Obtain the R2 user-observed size/flash result: opaque layered A reported normal glyph size and no flash; opaque nonlayered B reported normal font size and no flash. Both test instances were closed afterward. This is tested-run evidence, not exhaustive monitor/tracing coverage or a proven flash root cause.
- [x] Obtain the R2 A user-observed taskbar visibility and hover result. The user reported both working; hidden alpha pixels, rectangle/API checks and helper status alone would not prove final composition.
- [x] Record the user's additional report that transparent mode is normal. Do not infer an exact alpha or an alpha-caused flash; retain ordinary opacity behavior. No additional C-mode launch is required by the confirmed scope.
- [x] Complete the final Windows x64 release build (exit 0), fresh Flutter analysis/192 tests, fresh DPI 63/native window 193 checks and the canonical 20-file ZIP audit with no findings. Record the final SHA-256 in the verification document.
- [x] Scan tracked source text for private paths, local identity, email and known credential formats; review the two synthetic path-test literals and retain private runtime evidence outside source and archives.
- [x] Install the verified final package locally, compare all 20 package files, retain portable data separately and back up the previous candidate. Update the shortcut without launching a visible application.
- GitHub upload/publication status is tracked by the v1.4.1 tag/release, separately from these local verification checks.

## Confirmed scope added during implementation

These product changes were explicitly confirmed by the user. Their completion does not imply that desktop presentation has been verified.

- [x] Implement taskbar transparent/solid background, adjustable spacing, compact text-width layout, maximum-width semantics, original-content tooltips, automatic/full labels and per-item aliases. Retain independent floating and taskbar settings.
- [x] Record actual taskbar visibility/hover acceptance for R2 A. Retain the first v1.4.1 live failure as historical evidence rather than the latest outcome.
- [x] Initial integrated local verification: 192 Flutter checks, static analysis, 87 native taskbar checks, 36 channel checks, 50 passive diagnostic checks and the native window suite passed. Initial build and archive privacy audit passed; these results remain scoped to that earlier artifact.
- [x] Verify the R2 native changes: 108 taskbar checks, 63 diagnostic checks and 193 native window checks passed; independent read-only review covered diagnostic gating, hidden fixtures, bounded numerical logs and preserved upload errors.
- [x] Implement and locally verify the new alignment rule: centered Windows taskbar icons place data in the far-left available blank region, avoiding widgets and other controls; left-aligned icons retain right-side placement. All 124 native taskbar checks passed, including mocked registry/version inputs and geometry bounds; production helper compilation passed. Independent read-only review found no blocker. Display profiles and ordinary opacity behavior remain intact.
- [x] Restore Save while staying in Settings and remove Discard changes. Keep automatic saving on leave; merge close requests during an active save, retain a failed draft and defer secret cleanup until configuration commit. Forty focused widget/unit checks passed across the relevant Settings and lifecycle suites.
- [x] Separate ordinary `WM_CLOSE` from explicit Exit. Settings close enters the save coordinator and returns to the panel; panel close hides to the tray. Only Settings has an application taskbar button. Native lifecycle checks cover styles, hidden-state preservation and explicit exit.
- [x] Prepare v1.4.1+11 metadata, bilingual README instructions and changelog, retaining existing screenshots and the open visual-investigation limitation.

## Evidence checkpoint — 2026-10-14

The earlier diagnostic probe's numeric trace included a host width of 805 physical pixels at 175% (460 DIP), then 560 pixels at 100% (560 DIP). The 560-pixel width matched the old-scale 320-DIP minimum and led to the reproduced transition constraint above. This establishes a geometry/minimum-size defect, not the cause or elimination of the black flash.

The initial installed v1.4.1 check reported normal font size, persistent black flash and invisible taskbar content. Subsequent R2 A reported normal size, no flash, visible taskbar data and working hover; R2 B reported no flash and normal font size. The user also reported transparent mode normal, without an instrumented exact-alpha measurement. These reports do not prove opacity caused the flash. Alignment checks, the final build and archive audit have passed; GitHub publication is tracked by the v1.4.1 tag/release. See the [investigation record](../../verification/dpi-investigation.md) and [candidate verification](../../verification/v1.4.1.md). Private logs and configuration remain outside public documentation and commits.
