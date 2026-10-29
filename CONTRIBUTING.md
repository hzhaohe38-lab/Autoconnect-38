# 参与贡献

感谢你对 **Ruijie Auto Login** 的关注！无论是提交 Bug、改进文档，还是适配新的认证页面，都欢迎参与。

## 1. 遵守行为准则

参与本项目即表示你同意遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。请保持友善、尊重不同观点，技术讨论对事不对人。

## 2. 报告问题

- 提交前请先搜索 [已有 Issue](https://github.com/hzhaohe38-lab/Autoconnect-38/issues)，避免重复。
- 使用 [Bug 报告模板](https://github.com/hzhaohe38-lab/Autoconnect-38/issues/new?template=bug_report.yml) 或 [功能建议模板](https://github.com/hzhaohe38-lab/Autoconnect-38/issues/new?template=feature_request.yml)。
- 请提供操作系统版本、PowerShell 版本、运营商、复现步骤和相关日志。
- **不要上传包含学号、密码、Cookie 的截图或日志**。日志中的账号请自行打码。

## 3. 提交代码

1. Fork 本仓库，并从 `main` 创建分支：

   ```bash
   git switch -c feature/your-feature main
   ```

2. 分支命名遵循 [docs/BRANCHING.md](docs/BRANCHING.md)：

   | 前缀 | 用途 | 示例 |
   | --- | --- | --- |
   | `feature/` | 新功能 | `feature/wifi-detect` |
   | `fix/` | 缺陷修复 | `fix/mobile-service-encode` |
   | `docs/` | 文档改进 | `docs/quick-start` |
   | `chore/` | 构建、依赖、仓库维护 | `chore/ignore-build-output` |

3. 提交信息使用 Conventional Commits 风格：

   ```
   feat: 支持有线网络自动识别
   fix: 修复移动运营商 service 编码多出 t 的问题
   docs: 补充 Linux 后台运行说明
   ```

4. 提交前自测：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\ruijie-login.ps1 -Once
   ```

5. 发起 Pull Request，说明变更内容、关联 Issue，并勾选模板中的检查项。

## 4. 代码与文档规范

- PowerShell 代码保持 Windows PowerShell 5.1 兼容，避免引入仅 PowerShell 7 可用的语法。
- Shell 脚本必须使用 LF 换行；仓库已通过 `.gitattributes` 强制。
- 新增配置项时，同时更新 `shell/ruijie.conf.example` 和 README 的配置表。
- 用户可见的日志使用中文，级别统一为 `INFO / OK / WARN / ERROR / DEBUG`。
- 文档使用简体中文，命令、路径、代码保持原文。

## 5. 敏感信息

- 真实账号密码只保存在本地 `shell/ruijie.conf`，该文件已被 `.gitignore` 忽略。
- 提交前请执行 `git diff --cached` 检查，确认没有把 `ruijie.conf`、`*.log` 或含个人信息的截图加入暂存区。
- 如果误提交了敏感信息，请立即修改密码，并联系维护者清理历史记录。

## 6. 许可证

提交代码即表示你同意以 [Apache License 2.0](LICENSE) 授权你的贡献。
