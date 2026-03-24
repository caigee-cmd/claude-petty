# 更新日志

所有对本项目的重大变化都会记录在此文件中。

## [1.0.0] - 2026-03-24

### 添加

- 原生 macOS 状态栏应用
- 毛玻璃设计的仪表盘界面
- 概览统计 Tab - 展示今日和 30 天数据
- 实时监控 Tab - 追踪活跃 Claude Code Session
- 设置 Tab - 自定义通知模板和样式
- 一键安装 Hook 功能 - 自动配置 Claude Code Stop Hook
- 原生系统通知 - 支持自定义模板、声音和智能总结
- Session 历史记录 - 本地 JSON 存储，无云端依赖
- Swift Charts 可视化 - 柱状图、热力图、趋势图等
- Hook Installer - 自动化配置管理
- ClaudeDashHelper - CLI 工具用于接收任务完成通知
- 单元测试 - FloatingPanelLayout、SessionTimelineAxis 测试

### 技术特性

- 纯原生 Swift 6 + SwiftUI 实现
- 无第三方依赖
- DispatchSource 文件监控
- UserNotifications 系统通知
- 本地数据存储（UserDefaults + JSON）
- macOS 14.0+ 支持

---

## 版本说明

### 如何更新此文件

请遵循 [Keep a Changelog](https://keepachangelog.com/) 格式：

- `Added` - 新增功能
- `Changed` - 现有功能的改动
- `Deprecated` - 很快将被移除的功能
- `Removed` - 已移除的功能
- `Fixed` - Bug 修复
- `Security` - 安全相关修复
