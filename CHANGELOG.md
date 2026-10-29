# 更新日志

本项目的所有重要变更都会记录在此文件中，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [1.0.0] - 2026-10-29

### 新增

- 原生 Windows PowerShell 版本 `ruijie-login.ps1`，不依赖 WSL / Git Bash。
- 双击启动脚本 `ruijie.bat`。
- 首次运行交互式初始化：输入学号、密码、运营商后自动写入 `shell/ruijie.conf`。
- 有线 / 无线网络自动识别，日志显示接口、IP 与默认路由。
- 移动、联通、电信、校园网四类运营商适配。
- 掉线自动重连、失败按间隔重试、控制台与文件双日志。
- 贡献指南、行为准则、Issue / PR 模板与分支模型文档。
- GitHub Actions：对 PowerShell 脚本做语法检查。

### 修复

- 修复移动运营商 `service` 编码多出一个 `t` 的问题。
- 修复 Windows 检出导致 Shell 脚本 CRLF 无法运行的问题，新增 `.gitattributes` 统一 LF。
- 修复失败重试时日志刷屏的问题。
- 修正 README 中的仓库地址。

### 变更

- 真实配置文件 `shell/ruijie.conf` 不再纳入 Git，新增 `ruijie.conf.example` 模板。
- 移除误提交的 Go 模块缓存 `pkg/` 与预编译产物 `auto_login/output/`，仓库结构更清晰。

### 许可证

- 沿用上游项目的 Apache License 2.0。
