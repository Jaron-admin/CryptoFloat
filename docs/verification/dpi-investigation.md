# Mixed-monitor DPI investigation

Status: investigating, 2026-10-14. This is a diagnostic candidate based on v1.4.0, not a verified rendering fix.

## Report

Moving the panel to a lower-scaling display leaves text enlarged until one more click. Geometry-only tests do not verify Flutter viewport propagation or final desktop composition.

## Diagnostic switches

- `--dpi-diagnostics` enables numerical observations in portable `user_data/dpi-diagnostics.log`, limited to 64 KiB plus one previous file.
- `--dpi-probe-isolated` has an effect only with diagnostics enabled. It gives the diagnostic process a separate single-instance namespace. Use a separate application folder and temporary configuration; this switch does not isolate files on its own.
- Ordinary launches neither register Dart observers nor create diagnostic logs. They retain the normal single-instance namespace.

Observations include host/child DPI, geometry, parent/child DPI notifications, size and move-loop boundaries, the first click after a transition, Flutter metrics, natural post-frame callbacks, and limited frame timings. Payload keys and events are allowlisted and numeric; displayed text, API values, credentials and paths are not collected. Geometry can still reveal monitor layout, so logs remain local and excluded from Git and release archives.

The observer never requests a frame, changes font size, adjusts DPI awareness, or changes window geometry. Frame callbacks may be delivered after the corresponding frame. Correlate timestamps and transition boundaries; do not treat callback arrival as presentation time.

Logging still adds execution and file-I/O overhead, so timing-sensitive failures may behave differently while tracing. Failure to reproduce with tracing is not evidence that the original issue is fixed.

## Evidence gates

1. Confirm native and Flutter DPR/extent transitions are consistent.
2. Determine whether a new frame was produced before the recovery click.
3. Distinguish produced frames from actual desktop presentation.
4. Select the correction only after observing the failing boundary.
5. Repeat transitions without a recovery click before claiming a fix.

No interactive cross-monitor experiment has been performed for this candidate yet. Hidden-window and widget tests cover the observer contracts only.

## Local checks

- 171 application widget/unit tests passed, including 8 passive-observer checks.
- 35 native diagnostic checks passed, covering disabled logging, payload rejection, geometry observations and bounded log rotation.
- Existing native geometry/menu/outside-click/saved-notification checks passed.
- Static analysis passed with no issues.
- Windows x64 release-mode diagnostic candidate built successfully; not launched or published as a fix.
- Independent reusable modules are maintained in the local EngineeringPlaybook repository with their own checks and evidence boundaries.

## References

- [Microsoft high-DPI desktop development](https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-desktop-application-development-on-windows)
- [WM_DPICHANGED](https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged)
- [WM_DPICHANGED_BEFOREPARENT](https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged-beforeparent)
- [WM_EXITSIZEMOVE](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-exitsizemove)
- [Flutter 3.47.5 Windows viewport implementation](https://github.com/flutter/flutter/blob/3.47.5/engine/src/flutter/shell/platform/windows/flutter_windows_view.cc)
