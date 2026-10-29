# 分支模型与协作流程

本项目采用轻量级的 GitHub Flow：`main` 始终保持可运行，所有改动都在短期分支上完成，通过 Pull Request 合并。

## 1. 分支约定

| 分支 | 用途 | 生命周期 |
| --- | --- | --- |
| `main` | 稳定分支，随时可发布 | 长期 |
| `feature/<name>` | 新功能 | 合并后删除 |
| `fix/<name>` | 缺陷修复 | 合并后删除 |
| `docs/<name>` | 文档、注释、示例 | 合并后删除 |
| `chore/<name>` | 构建、依赖、仓库维护 | 合并后删除 |

分支名使用小写英文和连字符，例如 `feature/wifi-detect`、`fix/mobile-service-encode`。

## 2. 标准流程

```bash
# 1. 同步主分支
git switch main
git pull --ff-only

# 2. 创建短期分支
git switch -c feature/wifi-detect

# 3. 开发并提交（Conventional Commits）
git add .
git commit -m "feat: 自动识别无线网络接口"

# 4. 推送并创建 Pull Request
git push -u origin feature/wifi-detect

# 5. 评审通过后合并（保留合并记录）
git switch main
git merge --no-ff feature/wifi-detect

# 6. 删除已合并分支
git branch -d feature/wifi-detect
git push origin --delete feature/wifi-detect
```

## 3. 提交信息规范

```
<type>(<scope>): <subject>
```

常用类型：`feat`、`fix`、`docs`、`chore`、`refactor`、`test`。主题使用中文或英文均可，但同一项目内保持一致。

## 4. 解决合并冲突

当两个分支修改了同一文件的同一区域时，Git 会停止合并并标记冲突：

```bash
git merge --no-ff docs/community-health
# CONFLICT (content): Merge conflict in README.md
```

处理步骤：

1. 执行 `git status`，确认冲突文件；
2. 打开文件，查找 `<<<<<<<`、`=======`、`>>>>>>>` 标记；
3. 与另一分支的作者沟通，保留双方都需要的内容，删除冲突标记；
4. 运行一次脚本或文档检查，确认没有引入错误；
5. `git add <file>` 标记已解决；
6. `git commit` 完成合并，提交信息中说明冲突原因与取舍。

```bash
git status
# 编辑冲突文件 ...
git add README.md
git commit -m "merge: 合并社区文档分支并解决 README 冲突"
```

## 5. 本项目的一次真实冲突

在完善开源文档时，`main` 与 `docs/community-health` 同时修改了 README 的“本仓库”链接一行：

- `main` 修正了仓库地址（`Autoconnect-cuitNet` → `Autoconnect-38`）；
- `docs/community-health` 在同一行补充了文档导航；
- 合并时产生冲突，最终保留“正确地址 + 文档导航”两部分内容，并通过 `git add` + `git commit` 完成合并。

该过程保留了完整的合并提交，可在提交历史中复查。

## 6. 发布

- 版本号遵循语义化版本 `MAJOR.MINOR.PATCH`；
- 在 `main` 上打标签：`git tag -a v1.0.0 -m "v1.0.0"`；
- 推送标签：`git push origin v1.0.0`；
- 在 GitHub Releases 中根据 `CHANGELOG.md` 编写发布说明。
