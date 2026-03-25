# Releasing Claude Glance

本文件描述当前面向开发者用户的最小发布流程。当前公开版本采用被动本地读取模式，不依赖 Apple Developer Program、Developer ID 或 notarization，目标是稳定地产出一个可下载、可校验、可排障的 `ClaudeGlance.zip`。

## 发布前检查

在仓库根目录执行：

```bash
cd /Users/cj/Documents/personal/project/claudenotification/ClaudeDash
git status --short
xcodebuild test -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
```

发布前应满足：

- 当前分支没有你不想发布的改动
- `README.md` 已反映当前真实功能范围
- `CHANGELOG.md` 已更新
- 测试通过

## 构建发布产物

运行：

```bash
cd /Users/cj/Documents/personal/project/claudenotification/ClaudeDash
chmod +x scripts/build-release.sh
./scripts/build-release.sh
```

脚本会做这些事：

- 清理旧的 `dist/`
- 以 `Release` 配置构建 `ClaudeGlance.app`
- 复制 app 到 `dist/ClaudeGlance.app`
- 生成 `dist/ClaudeGlance.zip`
- 输出 zip 的 SHA-256 校验值

## 产物

构建完成后应有：

- `dist/ClaudeGlance.app`
- `dist/ClaudeGlance.zip`

发布时优先上传：

- `dist/ClaudeGlance.zip`

`ClaudeGlance.app` 保留在本地用于快速检查。

## 校验值

重新计算校验值：

```bash
cd /Users/cj/Documents/personal/project/claudenotification/ClaudeDash
shasum -a 256 dist/ClaudeGlance.zip
```

把结果贴到 GitHub Release 说明中，便于用户校验。

## GitHub Release

创建 Release 时，正文至少包含：

- 当前版本包含的主要功能
- 已知限制：
  - 非 Developer ID 签名
  - 未 notarize
  - 首次打开可能被 Gatekeeper 拦截
  - 暂无自动更新
  - 被动本地读取模式，不包含 Hook 安装流程
- 安装说明入口：指向 `README.md`
- `ClaudeGlance.zip` 的 SHA-256 校验值

## 首次安装提示

当前构建面向开发者用户。Release 文案应直接提醒：

- 下载后可能需要 `Open Anyway`
- 如果打不开，请看 README 中的 `First Launch on macOS`
- 如果没有数据，请检查 `~/.claude/projects/`

## 当前不做的事

本流程刻意不包含：

- DMG 生成
- Sparkle 自动更新
- Developer ID 签名
- notarization

这些能力属于后续面向普通用户分发时的 P1 范围。
