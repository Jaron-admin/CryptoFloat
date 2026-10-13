# CryptoFloat 1.2.0 · Flutter 桌面便携版

**简体中文** · [English](README.en.md)

Windows 首期桌面版。数据、设置和界面使用 Dart/Flutter，原生悬浮窗口与密钥保护隔离在 `lib/platform/` 和 Windows runner 中。macOS/Linux 工程骨架已生成，原生悬浮窗口和系统密钥适配将在后续补齐。

## 使用

发布目录中的 `cryptofloat.exe` 可以直接启动；整个目录需要一起保留，不能单独复制 EXE。程序使用 Windows 图形应用入口，正常启动不创建命令行窗口。

解压到具有写入权限的目录。程序使用 EXE 同级的 `user_data` 保存个人数据，目录不可写时会提示，不能通过回退到 C 盘继续保存。同一 Windows 用户的当前登录会话只允许一个实例，即使从另一个便携版目录启动，也会唤回已运行的窗口；隐藏在托盘中的窗口会重新显示。v1.1 及更早版本没有这一机制，升级前请先退出旧版。

- 标题区域拖动窗口，右下角调整大小；右键悬浮窗任意位置打开常用菜单。双击悬浮窗隐藏到右下角托盘，单击托盘图标恢复；托盘右键也可刷新、进入设置或退出。图标可能被 Windows 收进 `^` 隐藏区域。设置页标题也可拖动窗口。
- 设置使用 Flutter Material 3 控件。左侧分类与搜索，右侧分组设置；较窄窗口会调整为图标侧栏或横向分类导航。有草稿时返回可选择保存、放弃或继续编辑。
- **关注行情**：自动载入 OKX、Binance、KuCoin 的完整可用现货交易对目录，按名称、代码和交易所搜索勾选；目录只显示名称和代码，不请求所有价格。只刷新已关注项目的价格。目录每 24 小时更新并缓存，也可手动刷新；单家失败保留其上次目录。股票/ETF 仍有常用列表，也可手动添加代码。“已关注”位于页面上方，支持拖动左侧手柄排序，也可点击每项右侧的上移、下移按钮；较长列表可滚动。保存后悬浮窗使用同样的顺序。
- **自定义内容**：填写 HTTPS GET JSON 地址，读取返回字段，选取要显示的内容并设置名称、单位。请求头密钥由 Windows 当前用户的 DPAPI 保护，配置文件只记录引用。
- **显示布局**：默认行情与自由显示行可以同时显示；也能关闭默认行情列。使用文字和字段组合显示行，调整顺序和小数格式；编辑器与悬浮窗使用相同的渲染。
- **实用模板**：添加城市天气、参考汇率、GitHub 公开仓库统计、简洁行情条或文字提醒。模板追加到当前草稿，保留现有内容；字段与文字可继续编辑。
- **外观**：“悬浮窗透明度”位于页面最上方，0% 表示完全不透明。分别选择系统文字/数字字体，调整字号与间距；字体选择器预览含中英文及数字。
- **语言**：在“外观 → 语言”中选择简体中文、English 或跟随系统。保存后应用于界面、提示、悬浮窗和托盘菜单；再次启动时保留选择。自定义名称、显示文本及接口返回内容保留原值。
- **浅色与深色**：主题模式可选浅色、深色、跟随系统；两套配色独立保存。提供 Fluent 蓝、Catppuccin、Nord、Solarized 四组浅深预设，并保留独立自定义背景。“将当前配色另存为主题”可创建任意多套命名预设；每套包含浅、深两组颜色，支持编辑、复制、删除。图形取色器提供方形色谱、色相/亮度滑条、RGB/HEX 输入与实时预览，可分别设置背景、卡片、文字、次级文字、边框、强调色、上涨和下跌颜色。图标下拉显示真实图形，旁边可预览表情和本地图片。
- **单位与换算**：管理单位简写、自定义标签、显示货币和固定倍率。
- **窗口与托盘**：调整置顶，查看窗口移动与托盘操作；透明度在“外观”中调整。
- **名称与图标**：修改左上角名称，选择内置图标、表情或本地图片，也能分别隐藏名称和图标。本地图片上限 1 MB，导入后保存为应用私有 PNG，不改原图片。任务栏使用应用品牌图标。

保存会应用设置并返回运行中的悬浮窗。菜单打开后，点击窗口内菜单以外的位置可以关闭。

交易对目录中勾选或取消项目时保持当前列表位置；重新进入关注行情页面时，再将已勾选项目排到前面。

Windows 右键菜单使用独立的原生弹出层，可超出小悬浮窗边界；面板和托盘菜单共用配色、图标与紧凑间距，支持方向键、Enter 和 Esc。设置页使用 Flutter Material 3；桌面窗口、托盘和跨窗口右键菜单由平台适配层处理。

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

## 便携数据与旧版导入

个人数据全部位于 `cryptofloat.exe` 同级的 `user_data`：设置保存在 `user_data/settings.json`，保存前保留 `.bak`，文件损坏时尝试恢复备份；交易对缓存、导入图标和受保护的密钥文件也保存在此目录。移动或备份软件时，保留整个目录。

没有 `user_data` 时从默认配置开始，不自动读取、复制或迁移旧版 C 盘文件。旧 `%APPDATA%\CryptoFloatFlutter` 与 `%LOCALAPPDATA%\CryptoFloat\secrets` 保持原样。Windows DPAPI 密钥保护仍绑定当前用户和电脑，换电脑或账户后需要重新输入 API 密钥。

发行 ZIP 不含个人数据。不要直接分享自己运行过的程序目录；请使用原始发行 ZIP，或从用于分享的副本中移除 `user_data`。

在“关注行情”的“导入与数据位置”中选择导入旧版设置，填写旧 `crypto_config.json` 的位置。导入先形成草稿，点击保存后应用；旧文件不被修改。兼容的行情选择、顺序、字体和显示行可以迁移，旧密钥需要重新输入。

窗口位置和大小保存在新版设置中。Windows runner 使用 PerMonitorV2 DPI；保存的显示器消失或窗口完全离屏时，恢复到主屏可见区域。

## 开发与构建

构建使用 Flutter 3.47.5 / Dart 3.13.4、Windows x64，以及 Visual Studio 的 C++ 桌面工具、MSVC、CMake 和 Windows SDK。按 [Flutter Windows 配置文档](https://docs.flutter.dev/platform-integration/windows/setup)准备工具链。

```powershell
git clone https://github.com/Jaron-admin/CryptoFloat.git
cd CryptoFloat/flutter_app
flutter pub get
flutter run -d windows
```

代码检查与发布构建：

```powershell
flutter analyze
flutter test
flutter build windows --release
```

生成完整发布包：

```powershell
./tool/build_windows.ps1 -PackageName CryptoFloat-Windows-x64-1.2.0
```

发布目录和 ZIP 写入 `dist/`，包含程序、中英文使用说明、项目许可证和第三方许可文本。脚本从全新暂存目录打包，只复制白名单中的程序、运行库和 Flutter 资源，不复制 `user_data`。目标目录或 ZIP 已存在时会报错，请更换 `-PackageName`，脚本不会覆盖或清空已有程序目录。调试信息保存在独立目录，分享时使用生成的 ZIP。Flutter 未加入 PATH 时，可以传入 `-Flutter` 指定本机 Flutter 命令路径。

脚本在 Windows 无符号连接权限时，会在项目生成目录创建插件目录连接，无需修改系统开发者模式。构建 macOS/Linux 需要相应平台的开发环境，并补齐平台窗口、受保护存储与字体资源适配。Android/iOS 尚未生成项目。

## 平台范围

当前发行包仅面向 Windows x64。真实多屏跨 DPI 拖动、屏幕断开恢复等行为还取决于显示器与系统配置。

## 开源协议

CryptoFloat 自有源码使用 [MIT License](../LICENSE)。允许使用、修改、分发和商业使用；分发时请保留版权声明及许可文本。

依赖、图标字体和外部数据分别遵循各自的许可与服务条款，见 [第三方许可说明](../THIRD_PARTY_NOTICES.md)。Windows 发布包保留 Flutter 生成的 `data/flutter_assets/NOTICES.Z`，并附有解压后的 `THIRD_PARTY_LICENSES.txt`。
