# Taskbar surface and discovery contracts

The helper owns its hidden controller, taskbar child, and tooltip. The tooltip
owner is the helper controller, not the taskbar child: Win32 promotes a popup's
child owner to that child's top-level parent, which would otherwise be Explorer.
Remove the tooltip explicitly before removing its tool window. Discovery skips
elements and HWNDs belonging to this helper process, including popups and UIA
fragments without HWNDs. External occupancy and the existing one-second
discovery-age limit still fail closed.

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
mapping; the upload deliberately passes null destination/size to preserve it.

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

Status logs contain fixed labels and numbers, not tooltip text. `tooltip=show`
and `tooltip=pop`, `own_owner`, `panel_overlap`, and discovery `ignored_own`
support diagnosis without recording displayed values.

References: [owned windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features#owned-windows),
[layered windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features#layered-windows),
[alpha and text antialiasing](https://learn.microsoft.com/en-us/windows/win32/direct2d/supported-pixel-formats-and-alpha-modes#cleartype-and-alpha-modes).
