# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.0.8] - 2026-03-28

### Added

- README mascot preview GIFs for selected animated mascots

### Changed

- Refined the mascot settings UI into a more minimal single-panel layout with fewer visible labels and a larger default mascot size

## [1.0.0] - 2026-03-24

### Added

- Native macOS status bar app for Claude Code local activity tracking
- Quick-glance status bar popover with today metrics and recent sessions
- Detailed statistics window with `Overview`, `Tokens`, `Tools`, `Projects`, and `Insights` tabs
- Floating panel for active session monitoring
- Local transcript scanning from `~/.claude/projects/`
- Local persistence in `~/Library/Application Support/ClaudeDash/` for compatibility with earlier builds
- CSV / JSON export
- Unit tests covering layout, timeline axis, hook merge behavior, directory scanning, and history scan cache reuse

### Changed

- Public release guidance now targets developer users who can handle unsigned macOS builds
- Repository documentation now describes the current passive monitoring flow instead of the older manual Xcode project bootstrap flow
- Dashboard scope is documented around the current stats and monitoring views

### Removed

- Outdated public documentation for the removed Settings tab
- Outdated release notes claiming a three-tab dashboard and end-user notification customization flow
