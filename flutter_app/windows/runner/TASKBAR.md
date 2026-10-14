# Taskbar surface and discovery contracts

The helper owns its hidden controller, taskbar child, and tooltip. The tooltip
owner is the helper controller, not the taskbar child: Win32 promotes a popup's
child owner to that child's top-level parent, which would otherwise be Explorer.
Remove the tooltip explicitly before removing its tool window. Discovery skips
elements and HWNDs belonging to this helper process, including popups and UIA
fragments without HWNDs. External occupancy and the existing one-second
discovery-age limit still fail closed.

## Adaptive placement

The discovery worker reads the `TaskbarAl` DWORD under
`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` each time it samples the
taskbar: `1` selects the far-left placement policy and `0` preserves the existing
right-anchored free-gap selection. It never writes Windows settings. The DWORD
is an observed Explorer storage detail, not the different backup-data registry
representation in Microsoft's Windows settings reference.

With centered taskbar icons, placement scans padded occupied spans from the
far-left edge and uses the first gap that meets the minimum width. Weather,
widgets and every other discovered control remain occupied. A narrow gap can
compact the data; eligibility ends at the taskbar midpoint, so insufficient
left-side space pauses the surface rather than moving it into a right-side gap.
Left-aligned icons retain the previous largest-useful-gap policy, anchored at
the right edge of that gap. DPI-scaled padding and minimum widths are unchanged.

When the value is absent, the documented Windows 11 centered default is used
only after a successful build >= 22000 query. A confirmed earlier build uses
the legacy placement. The Win10/11 compatibility manifest is required for that
query. Unknown values, wrong types, denied reads and failed version queries
leave discovery incomplete with a fixed diagnostic reason. Tests substitute
registry/version responses without reading or changing the user's settings.

References: [Windows taskbar alignment and default](https://support.microsoft.com/en-us/windows/experience/personalization/customize-the-taskbar-in-windows),
[Windows settings backup-data reference](https://learn.microsoft.com/en-us/windows/apps/develop/settings/settings-windows-11),
[VerifyVersionInfo and manifest behavior](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-verifyversioninfow).

## Rendering

`transparentBackground` defaults to true. A 32-bit premultiplied surface uses
background alpha **1/255**, with RGB zero. This is nearly transparent rather
than mathematically zero: alpha zero would let mouse events pass through to
Explorer, losing hover, right-click, and double-click on the empty parts of the
panel. There is no border and no `WS_EX_TRANSPARENT` style. Glyph interiors
retain normal opacity; grayscale antialiasing supplies their edge coverage.
Opaque mode uses the configured background RGB with alpha 255.

GDI draws white grayscale glyph masks onto black DIBs. The helper then composes
each glyph's requested RGB against the background with premultiplied alpha and
uploads it through `UpdateLayeredWindow(ULW_ALPHA)`. Do not additionally call
`SetLayeredWindowAttributes`: the two surface mechanisms cannot be mixed without
resetting the layered style. Geometry is handled by the existing parent/client
mapping; the upload passes a null destination and an explicit bitmap size.
`Present` temporarily adopts the child's DPI awareness for client-size sampling,
bitmap rendering, and upload, then restores the caller's context and error code.
This keeps the explicit size in the child's units: passing it from a PMv2 caller
to an unaware child without the guard expanded a 64-pixel fixture to 112 pixels.

`itemGap` is a logical pixel interval from 0 through 24, default 6. Column widths
use the measured text and numeric fonts; two-row columns use the larger row.
The configured width is a maximum. Short columns retain their measured widths;
long columns are capped only when necessary. If even the ellipsis widths cannot
fit, trailing columns are omitted and the final visible cell carries an ellipsis.
Tooltips retain all full source text, including omitted cells.

## Verification and boundaries

The native suite exercises protocol defaults/bounds, hidden tooltip ownership
and destruction, synthetic notification stability, self-process exclusion,
compact widths, offscreen glyph alpha, and cross-process hidden parents at
multiple DPI awareness levels. It never moves or queries the real taskbar.
Synthetic tooltip notifications do not prove a particular Explorer UIA tree;
real-world hover confirmation remains a separate user-controlled check.

### Explicit-size diagnostic candidate

A real Explorer run reported no visible surface even while the helper reported
`displaying/ready`. That status records native API success, not final compositor
visibility. The hidden sibling fixture has no actual DirectComposition tree;
offscreen glyph assertions and successful uploads do not prove screen output.

The candidate changes only the upload's explicit size and the matching DPI scope;
position stays null and the renderer, alpha policy, and fallback remain unchanged.
TrafficMonitor's layered taskbar upload similarly supplies a size with a null
destination. Windows permits a null size when unchanged, so this is a controlled
hypothesis, not a proven platform requirement or a confirmed visibility repair.
Hidden cross-process tests check source bitmap/client size equality, unchanged
physical placement under PMv2/system/unaware parents (allowing the pre-existing
fractional rounding tolerance), and context restoration on success and failure.

For a separately approved live reproduction, set the process environment variable
`METRICPERCH_TASKBAR_RENDER_DIAGNOSTICS=1` before starting the app/helper. Other
values keep the added capture disabled. Only the first three uploads per helper
record `surface_upload`, bitmap width/height, ink/opaque pixel counts, maximum
alpha, upload success/error, parent/child rectangles, DPI, and awareness values.
Rectangles use the recorded upload thread's DPI coordinate space. Transparent
mode's ink count excludes alpha-one background pixels; opaque mode excludes the
configured background RGB. Records contain no displayed text, titles, paths, or
credentials. Existing API failure status logs remain available after this cap.

Status logs contain fixed labels and numbers, not tooltip text. `tooltip=show`
and `tooltip=pop`, `own_owner`, `panel_overlap`, and discovery `ignored_own`
support diagnosis without recording displayed values.

References: [owned windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features#owned-windows),
[layered windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features#layered-windows),
[alpha and text antialiasing](https://learn.microsoft.com/en-us/windows/win32/direct2d/supported-pixel-formats-and-alpha-modes#cleartype-and-alpha-modes),
[UpdateLayeredWindow size contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-updatelayeredwindow),
[TrafficMonitor upload](https://github.com/zhongyang219/TrafficMonitor/blob/master/TrafficMonitor/TaskBarDlgDrawCommon.cpp#L1736-L1748).
