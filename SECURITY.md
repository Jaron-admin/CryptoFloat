# 安全政策 / Security policy

## 私下报告漏洞 / Report a vulnerability privately

如果发现 DuoMonitor 的安全漏洞，请通过 GitHub Security Advisories 的 [私密漏洞报告入口](https://github.com/Jaron-admin/DuoMonitor/security/advisories/new) 联系维护者。登录 GitHub 后，也可在仓库的 **Security → Advisories → Report a vulnerability** 提交。

If you discover a security vulnerability in DuoMonitor, contact the maintainers through GitHub Security Advisories using the [private vulnerability reporting form](https://github.com/Jaron-admin/DuoMonitor/security/advisories/new). After signing in to GitHub, you can also use **Security → Advisories → Report a vulnerability** in the repository.

**请勿公开提交安全漏洞 Issue、PR 或包含漏洞细节的评论。** 请先通过私密报告与维护者协调修复和披露时间。

**Do not report vulnerabilities in public issues, pull requests, or comments that expose vulnerability details.** Use a private report to coordinate the fix and disclosure timing with the maintainers.

## 报告内容 / What to include

- 受影响的 DuoMonitor 版本、Windows 版本与必要的运行环境。 / Affected DuoMonitor version, Windows version, and relevant environment details.
- 漏洞描述、可能的影响、复现步骤及最小验证示例。 / A description, potential impact, reproduction steps, and a minimal proof of concept.
- 已脱敏的必要日志或截图，以及已知的缓解办法（如有）。 / Necessary redacted logs or screenshots, and any known mitigations.

即使是私密报告，也请去掉 API Key、令牌、账户信息、私人网址和个人路径。不要上传完整配置或 `user_data` 文件夹；使用虚构数据复现问题即可。

Even in a private report, remove API keys, tokens, account details, private URLs, and personal paths. Do not upload complete configuration files or the `user_data` folder; use dummy data to reproduce the issue.

普通缺陷和功能建议请使用 [公开 Issue 表单](https://github.com/Jaron-admin/DuoMonitor/issues/new/choose)。

For ordinary bugs and feature requests, use the [public issue forms](https://github.com/Jaron-admin/DuoMonitor/issues/new/choose).
