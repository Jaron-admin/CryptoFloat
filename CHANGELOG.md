# MetricPerch · 数栖更新记录 / Changelog

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
