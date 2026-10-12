# CryptoFloat 1.0.0 · Flutter 桌面版

Windows 首期桌面版。数据、设置和界面使用 Dart/Flutter，原生悬浮窗口与密钥保护隔离在 `lib/platform/` 和 Windows runner 中。macOS/Linux 工程骨架已生成，原生悬浮窗口和系统密钥适配将在后续补齐。

## 使用

发布目录中的 `cryptofloat.exe` 可以直接启动；整个目录需要一起保留，不能单独复制 EXE。程序使用 Windows 图形应用入口，正常启动不创建命令行窗口。

- 标题区域拖动窗口，右下角调整大小；右键悬浮窗任意位置打开常用菜单。双击悬浮窗隐藏到右下角托盘，单击托盘图标恢复；托盘右键也可刷新、进入设置或退出。图标可能被 Windows 收进 `^` 隐藏区域。设置页标题也可拖动窗口。
- 设置使用 Fluent UI 导航、输入框、按钮、开关、下拉框和对话框。左侧分类与搜索，右侧单列设置卡片；较窄窗口通过菜单按钮展开导航。有草稿时返回可选择保存、放弃或继续编辑。
- **关注行情**：自动载入 OKX、Binance、KuCoin 的完整可用现货交易对目录，按名称、代码和交易所搜索勾选；目录只显示名称和代码，不请求所有价格。只刷新已关注项目的价格。目录每 24 小时更新并缓存，也可手动刷新；单家失败保留其上次目录。股票/ETF 仍有常用列表，也可手动添加代码。“已关注”位于页面上方，支持拖动左侧手柄排序，也可点击每项右侧的上移、下移按钮；较长列表可滚动。保存后悬浮窗使用同样的顺序。
- **自定义内容**：填写 HTTPS GET JSON 地址，读取返回字段，选取要显示的内容并设置名称、单位。请求头密钥由 Windows 当前用户的 DPAPI 保护，配置文件只记录引用。
- **显示布局**：默认行情与自由显示行可以同时显示；也能关闭默认行情列。使用文字和字段组合显示行，调整顺序和小数格式；编辑器与悬浮窗使用相同的渲染。
- **实用模板**：添加城市天气、参考汇率、GitHub 公开仓库统计、简洁行情条或文字提醒。模板追加到当前草稿，保留现有内容；字段与文字可继续编辑。
- **外观**：“悬浮窗透明度”位于页面最上方，0% 表示完全不透明。分别选择系统文字/数字字体，调整字号与间距；字体选择器预览含中英文及数字。
- **浅色与深色**：主题模式可选浅色、深色、跟随系统；两套配色独立保存。提供 Fluent 蓝、Catppuccin、Nord、Solarized 四组浅深预设，并保留独立自定义背景。“将当前配色另存为主题”可创建任意多套命名预设；每套包含浅、深两组颜色，支持编辑、复制、删除。图形取色器提供方形色谱、色相/亮度滑条、RGB/HEX 输入与实时预览，可分别设置背景、卡片、文字、次级文字、边框、强调色、上涨和下跌颜色。图标下拉显示真实图形，旁边可预览表情和本地图片。
- **单位与换算**：管理单位简写、自定义标签、显示货币和固定倍率。
- **窗口与托盘**：调整置顶，查看窗口移动与托盘操作；透明度在“外观”中调整。
- **名称与图标**：修改左上角名称，选择内置图标、表情或本地图片，也能分别隐藏名称和图标。本地图片上限 1 MB，导入后保存为应用私有 PNG，不改原图片。任务栏使用应用品牌图标。

保存会应用设置并返回运行中的悬浮窗。菜单打开后，点击窗口内菜单以外的位置可以关闭。

Windows 右键菜单使用独立的原生弹出层，可超出小悬浮窗边界；面板和托盘菜单共用配色、图标与紧凑间距，支持方向键、Enter 和 Esc。设置页采用 [fluent_ui](https://pub.dev/packages/fluent_ui) 的 Windows 风格控件，布局参考 [PowerToys 设置卡片](https://github.com/microsoft/PowerToys/blob/main/src/settings-ui/Settings.UI/SettingsXAML/Views/MouseWithoutBordersPage.xaml) 和 [微软设置设计指南](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings)。fluent_ui 是社区维护的 Flutter 实现；桌面窗口、托盘和跨窗口右键菜单由平台适配层处理。

配色参考 [Microsoft Fluent](https://fluent2.microsoft.design/color)、[Catppuccin Latte/Mocha](https://catppuccin.com/palette/)、[Nord](https://www.nordtheme.com/docs/colors-and-palettes/) 与 [Solarized](https://ethanschoonover.com/solarized/)。部分强调色与涨跌颜色为行情小字的对比度作了调整。

## 数据源与单位

内置 OKX、Binance、KuCoin 公开行情；Binance 使用只读行情域名。预置美股、ETF 和部分沪深股票使用 Yahoo Finance 公共图表端点。Yahoo 不是稳定性受保证的官方开放 API，数据可能延迟、限流或暂时不可用。

自动行情行显示报价货币（如 USDT、BTC、USD、CNY）。自定义字段可以设置任意单位。接口返回的文本保持原值；需要格式化数字字符串时，在显示行中明确选择小数格式。

单位显示可选完整代码、简写（如 USDT → U）或自定义标签；单改标签不改数值。价格换算支持 USD、CNY、EUR、GBP、HKD、JPY、USDT、USDC，使用 Coinbase USD 基准参考汇率，每 5 分钟刷新，USDT/USDC 不假设与美元等值。汇率缺失、失效或换算失败时保留原值和原单位。其他数值可设置“原单位 → 目标单位 × 固定倍率”；手工倍率优先，温度偏移等非线性转换不属于倍率转换。

加密行情默认约 15 秒刷新、Yahoo 约 60 秒刷新；自定义接口间隔为 15–3600 秒。每个来源独立刷新，失败时保留上次值并标记过期，悬停可查看更新时间和原因。

左下角显示实际自动刷新周期；所有来源在各自周期内成功获取时显示绿色“实时”，超过周期或尚有来源未更新时显示灰白色“上次更新于”或“等待首次更新”。这里使用本地成功获取时间，上游行情时间另在提示中展示；“实时”不代表上游市场零延迟。

网络自动跟随 Windows 系统网络设置；连接失败时保留上次数据，并显示简短的连接状态。

自定义 API 只支持 HTTPS GET JSON，拒绝重定向和在 URL 中放置常见密钥参数；API Key 请使用受保护的请求头。

天气模板使用 [Open-Meteo](https://open-meteo.com/en/docs)，遵循其个人非商业服务限制和署名要求；仓库模板使用 [GitHub REST API](https://docs.github.com/en/rest/repos/repos#get-a-repository)。公开接口可能限流或临时不可用，网络模板不会在首次启动时自动添加。

## 设置与旧版导入

Windows 新版设置保存在 `%APPDATA%\CryptoFloatFlutter\settings.json`，保存前保留 `.bak`，文件损坏时尝试恢复备份。受保护的密钥文件在 `%LOCALAPPDATA%\CryptoFloat\secrets`。

在“关注行情”的“导入与数据位置”中选择导入旧版设置，填写旧 `crypto_config.json` 的位置。导入先形成草稿，点击保存后应用；旧文件不被修改。兼容的行情选择、顺序、字体和显示行可以迁移，旧密钥需要重新输入。

窗口位置和大小保存在新版设置中。Windows runner 使用 PerMonitorV2 DPI；保存的显示器消失或窗口完全离屏时，恢复到主屏可见区域。

## 开发与构建

当前开发环境：Flutter 3.47.5 / Dart 3.13.4，Windows x64，Visual Studio 2022 Build Tools 的 C++ 桌面工具、MSVC、CMake 和 Windows SDK。其他机器按 [Flutter Windows 配置文档](https://docs.flutter.dev/platform-integration/windows/setup)准备工具链。

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

也可运行 `tool/build_windows.ps1`；发布目录和 ZIP 会写入 `dist/`。脚本在 Windows 无符号连接权限时，会在项目生成目录创建插件目录连接，无需修改系统开发者模式。构建 macOS/Linux 需要相应平台的开发环境，并需要补齐平台窗口/受保护存储适配。Android/iOS 尚未生成项目。

## 1.0.0 检查范围

静态分析与 Windows 发布版构建；回归检查范围为菜单关闭、系统数字字体保存、保存后主窗口继续运行。其余已有测试未在本次全部重跑。

实际桌面外观、真实多屏跨 DPI 拖动、屏幕断开恢复和系统密钥存储往返仍需实际验收。
