# 参与贡献 / Contributing

欢迎通过 [Issues](https://github.com/Jaron-admin/DuoMonitor/issues) 报告缺陷或提出建议。较大的功能或设计调整请先开 Issue 讨论目标和范围。安全漏洞请按 [安全政策](SECURITY.md) 私下报告。

Use [Issues](https://github.com/Jaron-admin/DuoMonitor/issues) for bugs and suggestions. Discuss the goal and scope of larger features or design changes in an issue first. Report vulnerabilities privately as described in the [security policy](SECURITY.md).

## 开发环境 / Development environment

- Windows 10/11 x64；当前发行版仅支持 Windows。 / Windows 10/11 x64; current releases support Windows only.
- Flutter **3.47.5** / Dart **3.13.4**；`flutter_app/pubspec.yaml` 的 Dart 约束为 `^3.13.4`。 / Flutter **3.47.5** / Dart **3.13.4**; the Dart constraint in `flutter_app/pubspec.yaml` is `^3.13.4`.
- Visual Studio 的“使用 C++ 的桌面开发”工作负载，包含 MSVC、CMake 和 Windows SDK。 / Visual Studio with the Desktop development with C++ workload, including MSVC, CMake, and the Windows SDK.

环境准备、插件链接问题、目录结构和原生检查见 [中文开发文档](flutter_app/README.md) / [English development guide](flutter_app/README.en.md)。

## 分支与提交 / Branches and commits

从最新 `main` 创建独立分支，例如 `feat/short-description`、`fix/short-description`、`docs/short-description` 或 `chore/short-description`，通过 PR 合入 `main`。外部贡献者可先 fork 仓库。

Create a branch from the latest `main`, such as `feat/short-description`, `fix/short-description`, `docs/short-description`, or `chore/short-description`, and open a PR targeting `main`. External contributors can fork the repository first.

提交信息遵循 Conventional Commits：`类型(可选范围): 简短说明`。每次提交聚焦一项相关改动。常用类型为 `feat`、`fix`、`docs`、`test`、`refactor`、`chore` 和 `ci`。

Use Conventional Commits: `type(optional scope): short description`. Keep each commit focused on a related change. Common types are `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, and `ci`.

```text
fix(taskbar): handle display reconnect
docs: clarify portable mode
ci: add Windows build
```

## 检查、测试与构建 / Checks, tests, and builds

在仓库根目录打开 PowerShell，执行： / Open PowerShell at the repository root and run:

```powershell
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

需要生成完整 ZIP 时，使用已有打包脚本；下面的 `1.6.0` 应与 `pubspec.yaml` 中的版本一致（去掉 `+构建号`）：

To create the complete ZIP, use the existing packaging script. Replace `1.6.0` below with the version in `pubspec.yaml`, without the `+build` suffix:

```powershell
./tool/build_windows.ps1 -PackageName DuoMonitor-Windows-x64-1.6.0
```

脚本在 `flutter_app/dist/` 生成发布目录与 ZIP，拒绝覆盖已有同名输出。Flutter 未加入 PATH 时可传入 `-Flutter` 指定命令路径。脚本不生成 SHA-256；校验值由发布流程另行生成。

The script creates the release directory and ZIP under `flutter_app/dist/` and refuses to overwrite existing outputs with the same name. Use `-Flutter` to specify the command path if Flutter is not on PATH. The script does not generate SHA-256 checksums; the release process generates them separately.

任务栏、显示器或 DPI 相关改动还应按开发文档运行适用的原生检查，并在真实 Windows 桌面上验证相关场景。在 PR 中记录 Windows 版本、显示器数量、缩放和验证结果；无法执行的检查需说明原因。纯文档改动可说明运行时测试不适用。

For taskbar, display, or DPI changes, also run the applicable native checks in the development guide and verify relevant scenarios on a real Windows desktop. Record the Windows version, display count, scaling, and results in the PR, and explain any checks that could not be run. Documentation-only changes may explain why runtime testing is not applicable.

## 提交 PR / Opening a pull request

1. 保持改动范围清晰，并链接相关 Issue。 / Keep the change focused and link related issues.
2. 运行适用的检查，记录结果；为行为变化补充适用的测试。 / Run applicable checks, record the results, and add appropriate tests for behavior changes.
3. 更新相关中英文文档和 [CHANGELOG.md](CHANGELOG.md)，无需更新时在 PR 中说明原因。保留历史记录和已有的配置、路径迁移兼容逻辑。 / Update relevant Chinese and English documentation and [CHANGELOG.md](CHANGELOG.md), or explain why no update is needed. Preserve historical records and existing configuration and path migration compatibility.
4. 推送你的分支，填写 PR 模板，说明改动、原因和验证结果；界面变化附脱敏截图或录屏。 / Push your branch and fill out the PR template with the change, rationale, and validation results; include redacted media for UI changes.
5. 根据检查结果和评审意见更新同一个 PR。 / Address check results and review feedback in the same PR.

提交前检查暂存内容。不要提交 API Key、令牌、`.env`、个人配置、`user_data`、日志或构建产物。报告问题时只提供脱敏的相关片段，不要上传完整配置。

Review staged changes before committing. Do not commit API keys, tokens, `.env` files, personal configuration, `user_data`, logs, or build artifacts. Provide only relevant redacted excerpts when reporting issues, without uploading complete configuration files.
