# CryptoFloat

**简体中文** · [English](README.en.md)

可自定义的桌面行情与 API 悬浮窗。使用 Flutter 构建，设置界面采用 Fluent UI，支持简体中文和 English。

![CryptoFloat 悬浮窗外观示例](docs/images/panel-preview.png)

外观示例：名称、字体、配色、透明度和显示内容均可自定义。

## 下载与启动

前往 [Releases](https://github.com/Jaron-admin/CryptoFloat/releases) 下载 **CryptoFloat-Windows-x64-1.1.0.zip**。

解压整个压缩包，双击 `cryptofloat.exe` 启动。请保留同目录的运行库和 `data` 文件夹，不能只复制 EXE。

当前发行版支持 **Windows x64**。macOS/Linux 已有项目骨架，尚未完成原生窗口和受保护存储适配；Android/iOS 暂无可用发行版。

## 功能

- 加密货币、美股和部分沪深股票行情，显示价格、涨跌幅、单位与更新状态。
- 自动获取 OKX、Binance、KuCoin 交易对目录，搜索和勾选关注项目；支持拖拽排序和上下移动。
- 自定义 HTTPS JSON API、字段与显示模板，默认行情和自由文本可同时显示。
- 单位简写、参考汇率换算、自定义倍率；提供天气、汇率、公开仓库统计和文字提醒模板。
- 浅色、深色与跟随系统主题，多套命名配色预设和可视化取色器。
- 系统字体及数字字体、透明度、字号、间距、名称和图标自定义。
- 右键菜单、窗口置顶、双击隐藏到托盘、单击托盘恢复，多显示器 DPI 适配。

右键悬浮窗打开设置。在 **设置 → 外观 → 语言** 中选择简体中文、English 或跟随系统；悬浮窗透明度也位于“外观”中。

## 数据与配置

程序首次运行使用通用行情列表，自定义接口与文本均为空。个人设置保存在用户目录；API 请求头密钥由 Windows 当前用户凭据保护。网络自动跟随 Windows 系统网络设置。

公开行情可能延迟、限流或暂时不可用；“实时”表示应用在设定周期内成功获取数据。价格与汇率仅供展示参考。

完整说明见 [使用与构建文档](flutter_app/README.md)。

## 从源码构建

需要 Flutter 3.47.5 / Dart 3.13.4，以及支持 C++ 桌面开发的 Visual Studio 工具链。

```powershell
git clone https://github.com/Jaron-admin/CryptoFloat.git
cd CryptoFloat/flutter_app
flutter pub get
flutter build windows --release
```

工具链安装步骤见 [Flutter Windows 配置文档](https://docs.flutter.dev/platform-integration/windows/setup)。生成包含使用说明与许可证的发布目录和 ZIP：

```powershell
./tool/build_windows.ps1 -PackageName CryptoFloat-Windows-x64-1.1.0
```

## 开源协议

CryptoFloat 自有源码使用 [MIT License](LICENSE)，允许使用、修改、分发和商业使用，分发时保留许可证与版权声明。

第三方依赖和字体分别遵循各自的条款，详见 [第三方许可说明](THIRD_PARTY_NOTICES.md)。发布包附带项目许可证及第三方完整许可文本。
