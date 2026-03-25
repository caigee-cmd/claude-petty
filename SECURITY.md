# Security Policy

## Supported Versions

当前仓库以最新主分支和最近公开 Release 为主，不承诺维护长期支持分支。

如果你发现安全相关问题，优先报告：

- 最新默认分支上的问题
- 最近一个公开发布版本上的问题

## Reporting A Vulnerability

如果你认为 Claude Glance 存在安全问题，请不要先公开发 Issue 讨论细节。建议直接联系维护者，并至少提供以下信息：

- 问题描述
- 影响范围
- 复现步骤
- 相关系统环境
- 如有可能，给出修复建议或风险缓解方式

在维护者确认和修复前，请避免公开披露可直接利用的细节。

## Security Notes

Claude Glance 当前公开模式是本地被动读取：

- 读取 `~/.claude/projects/` 下的 transcript / session 数据
- 写入 `~/Library/Application Support/ClaudeDash/`（为兼容现有版本，目录名暂未重命名）
- 默认不上传数据到云端
- 不会自动修改 `~/.claude/settings.json`

## Disclosure Expectations

维护者会尽量：

- 确认问题是否成立
- 评估影响范围
- 在修复后给出公开说明

但当前项目仍处于较早期阶段，请不要假设存在企业级 SLA 或响应时限承诺。
