# Cross-monitor DPI refresh implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Implement and review each owned component independently.

**Goal:** Resolve click-to-recover text scaling with evidence, and capture reusable engineering interfaces.

**Architecture:** Native and Flutter observations feed an opt-in numerical trace. A framework-independent consistency model keeps observation separate from rendering policy. The correction is selected after reproduction.

**Tech Stack:** Win32 C++17, Flutter/Dart, Markdown, local Git.

**Spec:** ../specs/2026-10-14-dpi-refresh-design.md

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
- [ ] Verify repeated transitions of the corrected build on a real desktop, without a recovery click and with tracing both enabled and disabled. Investigate the reported momentary black flash separately; geometry regression success does not close the entire visual issue.
- [ ] Review, build, audit public files, and deliver the corrected application and local repository with precise verification limits.

## Confirmed scope added during implementation

These product changes were explicitly confirmed by the user. Their completion does not imply that desktop presentation has been verified.

- [x] Implement taskbar transparent/solid background, adjustable spacing, compact text-width layout, maximum-width semantics, original-content tooltips, automatic/full labels and per-item aliases. Retain independent floating and taskbar settings.
- [ ] Complete integrated verification of the new taskbar preferences and native frame path; check the corrected build's actual taskbar layout only with the required desktop authorization.
- [x] Integrated local verification: 192 Flutter checks, static analysis, 87 native taskbar checks, 36 channel checks, 50 passive diagnostic checks and the native window suite passed. Build and archive privacy audit passed; actual desktop confirmation remains separate.
- [x] Restore Save while staying in Settings and remove Discard changes. Keep automatic saving on leave; merge close requests during an active save, retain a failed draft and defer secret cleanup until configuration commit. Forty focused widget/unit checks passed across the relevant Settings and lifecycle suites.
- [x] Separate ordinary `WM_CLOSE` from explicit Exit. Settings close enters the save coordinator and returns to the panel; panel close hides to the tray. Only Settings has an application taskbar button. Native lifecycle checks cover styles, hidden-state preservation and explicit exit.
- [x] Prepare v1.4.1+11 metadata, bilingual README instructions and changelog, retaining existing screenshots and the open visual-investigation limitation.

## Evidence checkpoint — 2026-10-14

The user reported normal size with a short black flash in the diagnostic probe. Its numeric trace included a host width of 805 physical pixels at 175% (460 DIP), then 560 pixels at 100% (560 DIP). The 560-pixel width matched the old-scale 320-DIP minimum and led to the reproduced transition constraint above. This establishes a geometry/minimum-size defect, not the cause or elimination of the black flash. See the [investigation record](../../verification/dpi-investigation.md) for the evidence boundaries and rechecked Microsoft contracts. Private logs and configuration remain outside public documentation.
