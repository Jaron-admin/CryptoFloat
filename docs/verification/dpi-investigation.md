# Mixed-monitor DPI investigation

Status: minimum-size defect corrected; R2 visual checks passed as reported by the user, with the flash's exact cause still unproven, 2026-10-14. The earlier installed candidate failed visual acceptance. Alignment checks, the final release build and archive audit passed. Final package verified; GitHub publication is tracked by the v1.4.1 tag/release.

## Report

The initial report was enlarged text after moving the panel to a lower-scaling display, recovering after one more click. A later report described persistent enlargement. An earlier diagnostic probe produced a normal-size report with a momentary black flash and exposed the minimum-size defect documented below.

After that correction, the user tested an initial installed v1.4.1 diagnostic candidate. Font size was reported as normal in that run, but the black flash persisted. Taskbar content was also invisible despite helper ready/displaying status. That test instance was closed and the failed candidate was not published.

In the subsequent R2 A run, using an opaque layered floating host and the revised taskbar upload, the user reported normal size, no black flash, visible taskbar data and working hover. R2 B used an opaque nonlayered floating host; the user reported no black flash and normal font size. Both owned test instances were closed. The user additionally reported that transparent mode was normal. That last observation is accepted as user-reported evidence, not an instrumented measurement of an exact alpha value. See the [v1.4.1 verification record](v1.4.1.md).

These later observations are positive checks of the tested runs. They neither establish that alpha caused the flash nor prove every original symptom on every monitor combination. The existing ordinary opacity implementation remains unchanged; a further C-mode test is not a release requirement in the confirmed scope.

Geometry-only tests do not verify Flutter viewport propagation or final desktop composition.

## Earlier deidentified observation and confirmed defect

Only the relevant numeric extent is retained here; the private log, display identifiers, coordinates and configuration are not included.

| Observation | Host width in physical pixels | Scale | Derived logical width |
| --- | ---: | ---: | ---: |
| Higher-scale display | 805 | 1.75 | 460 DIP |
| Lower-scale display | 560 | 1.00 | 560 DIP |

The window did not preserve its logical width across this transition. The 560-pixel result also matches the application's 320-DIP minimum scaled using the old display's 175% factor. That numerical match alone is not proof of the cause; source inspection and a targeted native regression reproduce the stale-DPI minimum constraint.

During `WM_DPICHANGED`, the application has already received the new window DPI, but its physical rectangle can still identify the old monitor. Querying that monitor to scale the minimum size can therefore constrain the new rectangle with the old scale. Microsoft's contract makes the most recently delivered `WM_DPICHANGED` DPI the window's current DPI; the message also provides a suggested rectangle for the transition. [WM_DPICHANGED](https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged)

The correction uses `current_dpi_`, updated from `WM_DPICHANGED`, for both `WM_GETMINMAXINFO` minimum dimensions and the scale passed to `VisibleBounds`. Monitor work areas still provide visibility bounds; they are not used to re-derive the DPI for this transition's minimum-size calculation.

The native regression holds the monitor lookup at 168 DPI while delivering 96 DPI to the window. It checks that the minimum and the clamped dimensions use the new DPI. This check failed before the correction and passed afterward. See `DpiMinimumDuringTransitionTest` in [native_window_test.cpp](../../flutter_app/windows/runner/tests/native_window_test.cpp) and the [window implementation](../../flutter_app/windows/runner/win32_window.cpp).

This evidence establishes a geometry/minimum-size bug. It does not establish the cause of the black flash, prove that a frame was presented at the right time, or verify every reported font-size symptom.

## Diagnostic switches

- `--dpi-diagnostics` enables numerical observations in portable `user_data/dpi-diagnostics.log`, limited to 64 KiB plus one previous file.
- `--dpi-probe-isolated` has an effect only with diagnostics enabled. It gives the diagnostic process a separate single-instance namespace. Use a separate application folder and temporary configuration; this switch does not isolate files on its own.
- `--dpi-probe-opaque-layered` and `--dpi-probe-opaque-nonlayered` are optional A/B host-composition policies requiring both flags above. They apply only when creating that diagnostic HWND, are not persisted, and do not change ordinary startup. Supplying both variants retains the ordinary policy.
- Ordinary launches neither register Dart observers nor create diagnostic logs. They retain the normal single-instance namespace.

Observations include host/child DPI, geometry, parent/child DPI notifications, size and move-loop boundaries, the first click after a transition, Flutter metrics, natural post-frame callbacks, and limited frame timings. Payload keys and events are allowlisted and numeric; displayed text, API values, credentials and paths are not collected. Geometry can still reveal monitor layout, so logs remain local and excluded from Git and release archives.

To investigate the reported flash, native transition observations also include child resize duration and before/after dimensions. Child paint and background-erase messages increment counters without writing per-message records. Each transition has a two-second observation window and at most sixteen detailed resize records. These measurements preserve the existing resize/repaint behavior and are inactive during ordinary launches.

The observer itself never requests a frame, changes font size, adjusts DPI awareness, or changes window geometry. The explicitly selected A/B host policy is separate from this observation sink. Frame callbacks may be delivered after the corresponding frame. Correlate timestamps and transition boundaries; do not treat callback arrival as presentation time.

Logging still adds execution and file-I/O overhead, so timing-sensitive failures may behave differently while tracing. Failure to reproduce with tracing is not evidence that the original issue is fixed.

## Evidence gates

1. Confirm native and Flutter DPR/extent transitions are consistent.
2. Determine whether a new frame was produced before the recovery click.
3. Distinguish produced frames from actual desktop presentation.
4. Select the correction only after observing the failing boundary.
5. Repeat transitions without a recovery click before claiming a fix.

The initial corrected candidate failed the visual check; later R2 A/B runs passed the user-reported size/flash checks, and R2 A also passed the taskbar visibility/hover check. The additional transparent-mode report is positive without an exact-alpha measurement. No unique flash root cause has been established, and these runs do not provide exhaustive with/without-tracing or multi-monitor coverage. Those limits must accompany claims; they do not require an unrequested additional launch before the currently scoped release.

The taskbar failure and subsequent visible result remain separate from font-size evidence. Hidden-window alpha tests, rectangle checks and successful window/drawing API calls validate intermediate results, not Explorer's final composition. Ready/displaying status could not override the earlier invisible-content report; the later user observation supplies the actual visibility evidence. The new taskbar alignment rule passed local regressions and is included in the completed final build/archive audit. GitHub publication is tracked separately by the v1.4.1 tag/release. Raw logs and configuration remain local and are not included in public documentation.

## Related Save, close and taskbar lifecycle regression

This is a separate lifecycle correction, not evidence that DPI presentation is fixed:

- Save commits the draft and keeps Settings open. A close request during that save waits for the same operation; repeated close requests are merged. Failure retains the page and draft for retry.
- Native `WM_CLOSE` asks the application to save and leave Settings, or hide the floating panel. Only explicit Exit destroys the host. Secret cleanup follows a successful configuration commit.
- Settings uses an application taskbar button; the floating panel uses tool-window styling. Microsoft's documented transition for removing a visible taskbar button is hide, change the relevant extended style, then show. Preserve an already-hidden state when applying this transition. [Managing Taskbar Buttons](https://learn.microsoft.com/en-us/windows/win32/shell/taskbar#managing-taskbar-buttons)

The reusable lesson is to keep persistence, ordinary window close, explicit application exit, and taskbar presence as distinct operations. A taskbar close command must enter the same save coordinator as other Settings close requests. Widget checks cover these application decisions; hidden native checks cover styles and host lifetime, not the appearance of a live Shell taskbar.

## Local checks

Final confirmation: the Windows x64 release build completed with exit 0; the 20-file canonical archive audit reported no findings. Fresh runs passed 63 DPI diagnostic checks, 193 native window checks, Flutter static analysis and all 192 Flutter tests. The final artifact hash and tracked-source privacy scope are recorded in [v1.4.1 verification](v1.4.1.md). These local results do not expand the R2 user-observation evidence to every display or platform.

Latest alignment checks:

- 124 native taskbar checks passed after adding alignment selection, widget/occupied-area avoidance, narrow-gap behavior and negative-coordinate/high-DPI coverage. Registry/version queries are test substitutions; the production helper was compiled only. Independent read-only review found no blocker.

Earlier R2 native checks:

- 108 native taskbar checks passed, including PMv2/system/unaware hidden parents, explicit-size uploads, stable repeated frames, and error/context restoration. Hidden fixtures do not establish final Explorer visibility.
- 63 diagnostic checks and 193 native window checks passed, including opt-in A/B gating and hidden-window composition policies.

Earlier focused checks:

- The native stale-monitor minimum regression failed before the correction and passed after it; this is geometry evidence only.
- 40 focused application tests passed across Settings autosave, window events, appearance, localization, independent display settings and desktop flow. They include Save staying open, pending-close serialization, failure/retry and secret cleanup ordering.
- Native lifecycle checks cover taskbar styles, hidden-state preservation, close requests and explicit exit.

Earlier diagnostic baseline, before this minimum-size correction:

- 171 application widget/unit tests passed, including 8 passive-observer checks.
- 35 native diagnostic checks passed, covering disabled logging, payload rejection, geometry observations and bounded log rotation.
- Existing native geometry/menu/outside-click/saved-notification checks passed.
- Static analysis passed with no issues.
- Windows x64 release-mode diagnostic candidate built successfully; that build result alone was not a rendering-fix claim.
- Independent reusable modules are maintained in the local EngineeringPlaybook repository with their own checks and evidence boundaries.

## References

- [Microsoft high-DPI desktop development](https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-desktop-application-development-on-windows)
- [WM_DPICHANGED](https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged)
- [WM_DPICHANGED_BEFOREPARENT](https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged-beforeparent)
- [WM_EXITSIZEMOVE](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-exitsizemove)
- [Managing Taskbar Buttons](https://learn.microsoft.com/en-us/windows/win32/shell/taskbar#managing-taskbar-buttons)
- [Flutter 3.47.5 Windows viewport implementation](https://github.com/flutter/flutter/blob/3.47.5/engine/src/flutter/shell/platform/windows/flutter_windows_view.cc)

`WM_DPICHANGED` and Managing Taskbar Buttons were rechecked against Microsoft Learn on 2026-10-14. These contracts do not promise flash-free presentation for the application.
