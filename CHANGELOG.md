# DuoMonitor 更新记录 / Changelog

## 项目名称历史 / Project naming history

| 版本 / Versions | 项目名称 / Project name |
| --- | --- |
| v1.1–v1.2 | CryptoFloat |
| v1.3–v1.4.1 | MetricPerch · 数栖 |
| v1.5 起 / v1.5 onward | DuoMonitor |

历史条目和发行附件保留当时使用的名称。Historical entries and release assets retain their original names.

## 未发布 / Unreleased

### 简体中文

- 修复悬浮窗在数值变化时整体左右滑动的问题。横向布局的每一列改为固定宽度，面板内容始终与窗口同宽，不再按当前文字宽度重新居中；网速、价格等数字变宽时，右侧项目不再跟着移动。
- 修复单个项目内部因数值宽度变化而位移的问题。24 小时涨跌幅与“数据过期”标记占用固定槽位，价格和单位靠右对齐后位置保持不动；系统指标数值不再换行，行高保持稳定。

### English

- Fixed the floating panel sliding sideways whenever a value changed width. Horizontal columns now keep a fixed width and the content always spans the full window instead of being re-centred on the current text width, so entries to the right of a changing number no longer move.
- Fixed per-entry drift inside a row. The 24h change and the staleness marker keep reserved slots, prices and units stay right-aligned in place, and system metric values no longer wrap, so row heights stay stable.

## 1.6.0

### 简体中文

- 设置页固定显示当前目标的实时预览，调整字体、颜色、布局、间距或价格精度后立即看到草稿效果；保留保存和关闭时自动保存的行为。
- 修复任务栏将价格与 24h 涨跌幅统一着色的问题。价格继续比较上次刷新，24h 百分比按自身正负独立着色。
- 悬浮窗横向布局改为紧凑的名称与数值列，保留数字右对齐；增加名称与数值间距、列间距设置。任务栏增加名称与数值间距，保留项目间距。
- 任务栏宽度自动使用检测到的空白区域，移除人为的最大宽度限制；空间不足时按完整项目组分页，支持滚轮和自动轮播。轮播间隔可设 2–60 秒，默认 5 秒；悬停或手动滚动时暂停，也可选择仅滚轮模式。
- 每个行情项目可独立选择普通数字或 K/M/B 缩写，以及自动或 0–8 位小数。例如 BTC 可显示为 `81.7K`。悬浮窗和任务栏独立保存，原始数据与涨跌计算不受影响。

### English

- Added a fixed live preview for the selected display in Settings. Draft font, color, layout, spacing, and precision changes render immediately; Save and save-on-close behavior are preserved.
- Fixed taskbar prices and 24h percentages sharing one color. Prices compare with the previous refresh; each 24h percentage uses its own sign.
- Floating horizontal rows now use compact label/value columns with right-aligned numbers. Label/value and column spacing are configurable; the taskbar adds label/value spacing alongside item spacing.
- Taskbar width uses verified free space without an arbitrary maximum. Overflow pages keep complete item groups and support the mouse wheel or automatic rotation. The interval is configurable from 2–60 seconds (default 5); hover or manual scrolling pauses rotation, and manual-only mode is available.
- Per-asset price formatting supports standard or K/M/B notation and automatic or 0–8 decimal places, such as `81.7K` for BTC. Each display stores its own choices; source prices and change calculations remain unchanged.

## 1.5.0

### 简体中文

- 软件与公开仓库由 MetricPerch 改名为 DuoMonitor，Windows 程序改为 `duomonitor.exe` 与 `duomonitor_taskbar.exe`，发行包为 `DuoMonitor-Windows-x64-1.5.0.zip`。保留 Git 历史、历史发行记录、旧版单实例协议和密钥引用；已保存的自定义标题不被改名覆盖。
- 设置可以选择数据保存在系统应用目录，或继续使用程序旁边的便携 `user_data`。切换时可以选择复制现有配置、图标和备份。未做选择时仍使用原来的便携目录。
- 悬浮窗的数字和价格靠右对齐，名称保持靠左。
- 数字字体旁提示等宽字体更适合数字，字体列表会标出已安装的常见等宽字体。
- 价格颜色可在默认主题文字、主题涨跌色、绿涨红跌和红涨绿跌之间选择，并同时作用于悬浮窗和任务栏。红绿比较的是上一次成功刷新的价格，不是 24 小时涨跌；启动或更换品种后的第一次刷新为中性色。24 小时涨跌幅数字本身不变。
- 设置分区标明“同时作用于悬浮窗与任务栏”“仅影响悬浮窗”或“仅影响任务栏”。

### English

- Renamed the app and public repository from MetricPerch to DuoMonitor. Windows executables are `duomonitor.exe` and `duomonitor_taskbar.exe`; the archive is `DuoMonitor-Windows-x64-1.5.0.zip`. Git history, historical releases, legacy single-instance identifiers, and secret references are preserved. Saved custom titles are unchanged.
- Settings can store data in the system app directory or keep the portable `user_data` folder beside the app. Switching can copy the current settings, icons, and backups. Existing portable installs stay portable until a choice is saved.
- Numeric values and prices in the floating panel are right-aligned, while labels stay on the left.
- The number-font control suggests monospace fonts, and installed monospace families are marked in the picker.
- Price color can be default theme text, theme up/down colors, green-up, or red-up, and the choice applies to both the floating panel and the taskbar. Red and green compare with the previous successful refresh, not the 24-hour change. The first refresh after launch or a symbol change stays neutral. The 24-hour percentage text is unchanged.
- Settings sections are captioned as shared, floating-panel only, or taskbar only.

## 1.4.1

### 简体中文

- 任务栏新增透明背景、可调项目间距、自动/完整名称和逐项自定义简写。按实际文字宽度紧凑排列，设置中的宽度改为最大宽度；单行和双行均保留，悬停可查看原始名称与数值。
- Windows 任务栏居中对齐时，数据从最左侧可用空白开始排列，并避开天气、小组件和其他控件；左侧空间不足时暂停显示。系统任务栏左对齐时保留右侧空白布局。
- 恢复 **保存** 按钮，提交成功后留在当前设置页；移除“放弃更改”。点击设置外或返回仍自动保存；保存中的关闭请求等待当前提交，重复请求合并，失败保留草稿供重试。密钥在配置提交成功后再清理。
- 应用任务栏按钮仅在设置模式显示。关闭设置窗口会保存后返回悬浮窗，关闭悬浮窗会隐藏到托盘；明确 **退出** 才结束程序。调整任务栏按钮样式时保留已有隐藏状态。
- 修正跨屏 DPI 过渡中旧屏最小尺寸限制新矩形的问题：最小尺寸和可见边界计算使用消息中更新的窗口 DPI，对应原生回归先失败、修正后通过。
- 修正透明任务栏图像提交的尺寸和 DPI 上下文，并独立管理悬停提示窗口的所有者。实机复测与验证范围见 [DPI 调查记录](https://github.com/Jaron-admin/MetricPerch/blob/main/docs/verification/dpi-investigation.md)。

### English

- Added transparent taskbar backgrounds, adjustable item spacing, short/full labels, and per-item custom labels. Text uses a compact layout and the width preference is now a maximum. One and two rows remain available; tooltips retain original names and values.
- With centered Windows taskbar icons, data starts in the far-left available space, avoiding weather, widgets, and other controls. Insufficient space on that side pauses the display. Left-aligned Windows taskbars retain placement in the right-side gap.
- Restored **Save** to commit changes while staying on the current Settings page; removed Discard changes. Outside clicks and returning to the panel still save automatically. Close requests wait for an active save, repeats are merged, and failures retain the draft for retry. Secret cleanup follows a successful configuration commit.
- The application taskbar button is shown only in Settings mode. Closing Settings saves and returns to the floating panel; closing the panel hides it to the tray. Explicit **Exit** ends the app. Taskbar style changes preserve an already-hidden window.
- Corrected a DPI transition that applied the old monitor's minimum size to the new rectangle. Minimum dimensions and visible-bound constraints use the updated window DPI. The targeted native regression failed before the correction and passed afterward.
- Corrected the surface size and DPI context used to present transparent taskbar content, and separated tooltip ownership. See the [DPI investigation](https://github.com/Jaron-admin/MetricPerch/blob/main/docs/verification/dpi-investigation.md) for live observations and verification limits.

## 1.4.0

### 简体中文

- 悬浮窗新增 1–8 列布局，项目支持横向和纵向排列；24h 涨跌幅可隐藏，价格按涨跌着色，支持主题配色、红涨绿跌和绿涨红跌。
- 点击设置外或返回时自动保存，失败保留草稿；取色、字体和文件选择期间不误关闭。移除“保存并返回”，保留主动放弃未保存更改。
- 去掉悬浮窗底部常驻状态和调整大小箭头，仍可拖动窗口边缘调整尺寸；数据更新时间和错误保留在项目提示中。
- 右键菜单使用 Windows 标准菜单绘制；修复混合 DPI 显示器间尺寸基准丢失和设置返回时的缩放问题。
- 修复 Windows 11 任务栏绘制层遮住数据的问题，已通过真实任务栏截图对照确认；同时修复可见区域检测，并在便携数据目录记录有限的技术状态。日志不包含显示内容或窗口标题。

### English

- Added 1–8 floating columns, horizontal/vertical entries, optional 24h percentages, and theme/green-up/red-up price colors.
- Settings save automatically on an outside click or return. Failures keep the draft open; editors and pickers remain protected. Removed the Save and return button and retained explicit discard.
- Removed the persistent floating footer and resize arrow; window-edge resizing and per-item update/error tooltips remain.
- Context menus use standard Windows rendering. Fixed mixed-DPI size baseline loss and settings-to-panel geometry restoration.
- Fixed taskbar content hidden by Windows 11 composition, confirmed with before/after captures on a real desktop. Repaired free-region discovery and added bounded technical diagnostics beside the portable app, without display content or window titles.

## 1.3.0

### 简体中文

- 软件与公开仓库由 CryptoFloat 改名为 MetricPerch，中文名数栖。Windows 主程序为 `metricperch.exe`，任务栏宿主为 `metricperch_taskbar.exe`；发行包为 `MetricPerch-Windows-x64-1.3.0.zip`。
- 默认同时启用行情悬浮窗和主屏任务栏系统监测，任务栏初始显示 CPU、内存百分比、上传和下载速率。两处独立选择行情、API 字段、文字模板与系统指标，以及顺序、单位、字体和配色。
- 新增 Windows CPU、内存、网速、GPU、显存和磁盘读写采集；采样间隔 1–60 秒，设备可自动或手选。缺失与预热数据显示 `—`，有效零值才显示 `0`；每个显示独立判断刷新状态。
- 设置支持切换显示目标、草稿预览、系统设备选择及任务栏宽度和单/双行配置。共享数据请求去重，仅调整显示顺序不会重新请求全部行情。
- 任务栏使用独立原生进程，仅传输显示文本与样式；任务栏不可用、空间不足或布局不支持时暂停显示。Windows 11 不提供受支持的第三方预留布局位置，实际兼容性取决于 Windows 版本与任务栏布局，尚不能宣称覆盖所有真实桌面。
- 原便携 `user_data` 迁移到双显示配置并保留原始备份，保存的自定义标题、图标、模板、字体和主题继续保留。沿用旧单实例和密钥引用标识。高于当前支持版本的配置不会被默认设置覆盖。
- Windows 发布脚本通过明确白名单打包两个可执行文件、运行库、Flutter 资源和许可文本；不包含用户数据、日志或调试符号。

升级：退出旧版并备份 `user_data`；完整解压新包，把自己的 `user_data` 保留在 `metricperch.exe` 旁。不要同时运行旧新版本，也不要只复制主 EXE。Windows DPAPI 密钥仍绑定当前用户和电脑。

### English

- Renamed the app and public repository from CryptoFloat to MetricPerch, with the Chinese name 数栖. The Windows executables are `metricperch.exe` and `metricperch_taskbar.exe`; the archive is `MetricPerch-Windows-x64-1.3.0.zip`.
- Both the floating market panel and primary taskbar monitoring are enabled by default. The taskbar starts with CPU, memory percentage, upload, and download rates. Each display independently selects quotes, API fields, text templates, metrics, ordering, units, fonts, and colors.
- Added Windows CPU, memory, network, GPU, video memory, and disk read/write sampling. The interval ranges from 1 to 60 seconds, with automatic or manual device selection. Missing and warming samples show `—`; valid zero samples show `0`. Each display evaluates its own freshness.
- Settings adds display targets, draft previews, system devices, and taskbar width and one/two-row controls. Shared data requests are deduplicated; reordering content alone does not request all quotes again.
- A separate native helper renders taskbar text and receives only text and style. An unavailable taskbar, insufficient space, or unsupported layout pauses display. Windows 11 has no supported reserved slot for third-party content. Compatibility depends on the Windows version and taskbar layout; complete real-desktop coverage has not been verified.
- Portable `user_data` migrates to two display profiles with an original backup. Saved custom titles, icons, templates, fonts, and themes are retained, as are legacy single-instance and secret-reference identifiers. A newer unsupported configuration schema is not overwritten with defaults.
- Windows packaging uses explicit allowlists for both executables, runtime libraries, Flutter resources, and license texts. User data, logs, and debug symbols are excluded.

Upgrade: exit the old app and back up `user_data`, extract the entire new archive, and keep your `user_data` beside `metricperch.exe`. Do not run old and new versions together or copy only the main EXE. Windows DPAPI secrets remain bound to the current user and computer.
