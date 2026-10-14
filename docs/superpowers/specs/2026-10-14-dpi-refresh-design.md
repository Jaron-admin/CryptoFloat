# Cross-monitor DPI and stale frame diagnosis

## Confirmed intent

Fix the reported oversized text after moving the floating panel to a lower-scale display. The user clarified that another click restores the correct appearance. Preserve configured font sizes, transparency, portable data and independent displays. Extract verified findings and reusable interfaces into a separate cross-project engineering repository, with native and framework adapters.

The user approved local checks using temporary configurations and hidden test windows. Real desktop interaction requires a separate approval. Design and implementation notes are prepared automatically under the existing workflow authorization.

## Evidence and uncertainty

The current engine updates its child-window DPI in BEFOREPARENT, and sends Dart metrics on a subsequent size event. Its ForceRedraw call can be ignored while a resize is in progress. The app does not process the end of interactive movement. These are possible failure paths, not a confirmed root cause. Existing native geometry fixtures do not exercise the Flutter engine or final presentation.

## Approach

1. Add opt-in bounded numerical telemetry for host and child DPI/geometry, native event sequence, Flutter metrics and rendered frame timestamps. Normal launches do not collect the trace. No text, titles, API data, credentials, or user paths are logged.
2. Reproduce with a temporary build and inspect the event ordering. Hidden tests exercise trace bounds, payload validation and known notification boundaries. They are not substitutes for the reported visual symptom.
3. Apply the smallest correction justified by the trace. Possible seams are geometry selection/reentrancy, viewport metrics refresh, end-of-move frame scheduling, or layered-window invalidation. Do not reduce font sizes or override MediaQuery DPR as compensation.
4. Verify that the correct picture returns without another click. Keep verification claims separate for isolated geometry, Flutter behavior and real desktop rendering.

## Reusable repository

EngineeringPlaybook stores cases with evidence levels and official references. A dependency-free DPI observation/consistency core, a Win32 snapshot adapter and a Flutter observation adapter may be shared. App-specific window lifecycle and policy remain in the application. Only proven fixes are documented as verified; investigative tools may be published as diagnostic tools.

## Sources

- https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged
- https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-getdpiscaledsize
- https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged-beforeparent
- https://github.com/flutter/flutter/blob/3.47.5/engine/src/flutter/shell/platform/windows/flutter_windows_view.cc
