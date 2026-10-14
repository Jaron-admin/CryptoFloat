# MetricPerch · 数栖更新记录 / Changelog

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
