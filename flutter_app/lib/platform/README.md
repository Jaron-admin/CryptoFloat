# Desktop platform boundary

`FloatingWindowHost()` is the portable window contract. Its Windows implementation
and `PlatformSecretStore` use the `cryptofloat/platform` method channel, registered
in `windows/runner/platform_channel.cpp` with Flutter's standard method codec.

The window methods are `window.initialize`, `window.setAlwaysOnTop`,
`window.setOpacity`, `window.getBounds`, `window.setBounds`, `window.beginDrag`,
`window.beginResize`, `window.setSettingsMode`, `window.close`, and
`window.getSystemFonts`. The resize edges are `left`, `right`, `top`, `bottom`,
`topLeft`, `topRight`, `bottomLeft`, and `bottomRight`.

Bounds contain physical screen `x`, `y`, `width`, and `height`, the Windows display
device name in `displayId`, and the capture-time DPI factor in `scale`. Restoring
preserves the logical size at the destination display's current DPI. A missing
display or entirely offscreen rectangle returns to the primary monitor; all
restored rectangles are clamped to its visible work area. The runner retains its
PerMonitorV2 manifest, forwards Flutter content resizing, and handles DPI changes.
The default panel is 460 × 360 logical pixels with a 320 × 180 minimum. Settings
mode expands to 920 × 720 and restores the prior panel rectangle on dismissal.
Call `getBounds()` after leaving settings mode when saving the floating bounds.

The secret methods are `secret.write`, `secret.read`, and `secret.delete`. Each
accepts a `key`; write also accepts a `value`. Keys are credential references,
hashed with SHA-256 for filenames. DPAPI protects each value for the current
Windows user, and only encrypted bytes are written under
`user_data/secrets` beside the executable. Writes replace the protected file atomically.
The store never logs credential values and rejects invalid or oversized inputs.

Portable data paths derive from the executable directory, not the process working
directory or Windows profile. `user_data` contains settings, cached catalogs,
imported icons, and protected secrets. Startup does not import the old profile
directories and does not fall back to them when the portable folder is unwritable.
DPAPI secrets still require the original Windows account and computer; portable
settings and icons do not make credentials transferable to another machine.

The Windows runner allows a single instance per user in the current login
session, independent of the executable directory. A repeated launch activates
the existing window, restoring it from the tray as needed. This contract applies
from version 1.2 onward; older instances must be exited before upgrading.

On macOS, Linux, and web, window calls are harmless no-ops and font discovery
returns common fallback families. Secret reads return null and deletes are
harmless; writes report that protected storage is unavailable. Future native
adapters can implement these contracts without changing data or UI models.
