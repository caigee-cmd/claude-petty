# Claude Glance

[English](README.md) | [简体中文](README.zh-CN.md)

一个原生 macOS 菜单栏应用，用来查看 Claude Code 的本地活动和会话状态。

![Claude Glance Demo](docs/screenshots/claude-glance-demo.gif)

[观看 MP4 演示](docs/screenshots/claude-glance-demo.mp4)

Claude Glance 默认以被动读取方式工作：扫描 `~/.claude/projects/` 下的本地 transcript 数据，展示最近活动、活跃 session 和轻量统计。

## 亮点

- 动画化浮动面板
- 菜单栏快速查看
- 活跃 session 查看
- 本地 transcript 扫描
- CSV / JSON 导出
- 默认纯本地
- 不需要安装 Hook

## 安装

### 从 Release 安装

1. 下载 `ClaudeGlance.zip`
2. 解压得到 `ClaudeGlance.app`
3. 拖到 `/Applications`
4. 如果 macOS 阻止启动，请在 `Privacy & Security` 中选择 `Open Anyway`

### 从源码构建

要求：

- Xcode 16+
- macOS 14 SDK
- 可选：`xcodegen`

```bash
cd /Users/cj/Documents/personal/project/claudenotification/ClaudeDash
xcodebuild build -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
```

如果你修改了 `project.yml`：

```bash
xcodegen generate
```

## 隐私

Claude Glance 默认只在本地运行。

| 项目 | 当前行为 |
| --- | --- |
| 读取 | `~/.claude/projects/` transcript / session 数据 |
| 写入 | `~/Library/Application Support/ClaudeDash/` |
| 联网 | 不需要 |
| 账号 | 不需要登录 |
| 遥测 | 不上传到云端 |
| Claude 配置 | 不会修改 `~/.claude/settings.json` |

当前公开版本是纯被动模式。为兼容旧版本，仍使用 `~/Library/Application Support/ClaudeDash/` 作为本地数据目录。

## 当前限制

- 仅支持 macOS 14+
- 当前为面向开发者的未签名构建
- 尚未 notarize
- 暂无自动更新
- 当前为被动本地读取模式

## 开发

```bash
cd /Users/cj/Documents/personal/project/claudenotification/ClaudeDash
xcodebuild build -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
xcodebuild test -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
./scripts/build-release.sh
```

更多说明：

- [发布说明](docs/releasing.md)
- [开源发布检查清单](docs/open-source-release-checklist.md)
- [贡献指南](CONTRIBUTING.md)
- [安全说明](SECURITY.md)
- [支持说明](SUPPORT.md)

## License

[MIT](LICENSE)
