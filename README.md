# Claude Glance

[English](README.md) | [简体中文](README.zh-CN.md)

A native macOS menu bar app for viewing local Claude Code activity, active sessions, and lightweight usage stats.

Claude Glance passively reads local transcript data under `~/.claude/projects/` and surfaces recent activity, active sessions, and lightweight stats.

## Demo

![Claude Glance demo](https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/claude-glance-demo.gif)

A short walkthrough of the menu bar overview, daily stats, and mascot settings.

[Watch the HD MP4 demo](https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/claude-glance-demo.mp4)

## Highlights

- Menu bar quick glance for today's activity, active sessions, and recent completions
- Lightweight local stats dashboard for Claude Code usage
- Minimal settings panel for mascot styles and floating behavior
- Passive transcript scanning under `~/.claude/projects/`
- Local-first by default, with no hook installation required
- CSV / JSON export

## Screenshots

### Menu Bar Overview

Quick glance at today's stats, active sessions, and recent completions from the menu bar.

![Menu bar popover](https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/menupannel.png)

### Mascot Settings

Two settings states that show how the floating mascot can be configured without leaving the app.

<table>
  <tr>
    <td width="50%"><img src="https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/settingpannel-cat-floting.png" alt="Floating mascot settings" /></td>
    <td width="50%"><img src="https://claude-glance-1390058464.cos.ap-singapore.myqcloud.com/settingpannel-cat-play-guitart.png" alt="Guitar mascot settings" /></td>
  </tr>
  <tr>
    <td align="center"><sub>Floating mascot preset</sub></td>
    <td align="center"><sub>Guitar mascot preset</sub></td>
  </tr>
</table>

## Installation

### From Release

1. Download the latest `.dmg` or `ClaudeGlance.zip`
2. Open the DMG or unzip `ClaudeGlance.app`
3. Move it to `/Applications`
4. If macOS blocks launch, use `Open Anyway` in `Privacy & Security`

Notes:

- The current public build is unsigned and not notarized.
- On first launch, macOS may block the app until you manually allow it in `Privacy & Security`.
- GitHub Releases may include both `ClaudeGlance.zip` and a DMG build. If both are available, the DMG is the easier entry point.

### From Source

Requirements:

- Xcode 16+
- macOS 14 SDK
- Optional: `xcodegen`

```bash
git clone git@github.com:caigee-cmd/claude-glance.git
cd claude-glance
xcodebuild build -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
```

If you changed `project.yml`:

```bash
xcodegen generate
```

## Privacy

Claude Glance runs locally by default.

| Item | Behavior |
| --- | --- |
| Read | `~/.claude/projects/` transcript / session data |
| Write | `~/Library/Application Support/ClaudeDash/` |
| Network | Not required |
| Account | No login required |
| Telemetry | No cloud upload |
| Claude config changes | Does not modify `~/.claude/settings.json` |

The current public build is passive-only and keeps using `~/Library/Application Support/ClaudeDash/` for compatibility with earlier builds.

## Limitations

- macOS 14+
- Unsigned developer-oriented build
- Not notarized
- No auto-update yet
- Passive local read-only workflow

## Development

```bash
cd claude-glance
xcodebuild build -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
xcodebuild test -project ClaudeDash.xcodeproj -scheme ClaudeDash -destination "platform=macOS"
./scripts/build-release.sh
./scripts/build-dmg.sh
```

More details:

- [Release guide](docs/releasing.md)
- [Open source release checklist](docs/open-source-release-checklist.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)
- [Support](SUPPORT.md)

## License

[MIT](LICENSE)
