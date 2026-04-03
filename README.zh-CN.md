# Claude Glance

[English](README.md) | [简体中文](README.zh-CN.md)

一个原生 macOS 菜单栏应用，用来查看 Claude Code 的本地活动、活跃会话和轻量统计。

Claude Glance 默认以被动读取方式工作：扫描 `~/.claude/projects/` 下的本地 transcript 数据，展示最近活动、活跃 session 和轻量统计。

## 演示视频

![Claude Glance 演示](https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/claude-demo.gif)

快速看一遍菜单栏概览、统计面板和挂件设置。

[观看高清 MP4 演示](https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/claude-glance-demo.mp4)

## 亮点

- 菜单栏快速查看今日活动、活跃 session 和最近完成
- 轻量本地统计面板，快速了解 Claude Code 使用情况
- 极简设置面板，可切换挂件样式和浮动行为
- 扫描 `~/.claude/projects/` 下的本地 transcript
- 默认纯本地，无需安装 Hook
- CSV / JSON 导出

## 界面预览

### 菜单栏概览

菜单栏内快速查看今日统计、活跃任务和最近完成。

![菜单栏面板](https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/menupannel.png)

### 挂件设置

这两张图适合作为补充说明，展示挂件样式和设置方式，而不是占据首屏。

<table>
  <tr>
    <td width="50%"><img src="https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/settingpannel-cat-floting.png" alt="浮动挂件设置" /></td>
    <td width="50%"><img src="https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/settingpannel-cat-play-guitart.png" alt="吉他挂件设置" /></td>
  </tr>
  <tr>
    <td align="center"><sub>浮动挂件样式</sub></td>
    <td align="center"><sub>吉他挂件样式</sub></td>
  </tr>
</table>

## 安装

### 从 Release 安装

1. 下载最新的 `.dmg` 或 `ClaudeGlance.zip`
2. 打开 DMG，或解压得到 `ClaudeGlance.app`
3. 拖到 `/Applications`
4. 如果 macOS 阻止启动，请在 `Privacy & Security` 中选择 `Open Anyway`

说明：

- 当前公开构建未签名，也没有 notarize。
- 首次启动时，macOS 可能会拦截应用，需要你手动在 `Privacy & Security` 中放行。
- 如果 GitHub Release 同时提供 `ClaudeGlance.zip` 和 DMG，优先使用 DMG 会更方便。

### 从源码构建

要求：

- Xcode 16+
- macOS 14 SDK
- 可选：`xcodegen`

```bash
git clone git@github.com:caigee-cmd/claude-glance.git
cd claude-glance
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
cd claude-glance
xcodebuild build -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
xcodebuild test -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
./scripts/build-release.sh
./scripts/build-dmg.sh
```

更多说明：

- [发布说明](docs/releasing.md)
- [开源发布检查清单](docs/open-source-release-checklist.md)
- [贡献指南](CONTRIBUTING.md)
- [安全说明](SECURITY.md)
- [支持说明](SUPPORT.md)

## License

[MIT](LICENSE)
