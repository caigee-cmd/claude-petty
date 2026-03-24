# 贡献指南

感谢你对 ClaudeDash 的兴趣！本文档提供了贡献代码的指导。

## 如何开始

### 报告问题

在创建 Issue 之前，请：
- 检查是否已存在相关 Issue
- 提供清晰的标题和描述
- 包含 macOS 版本和 Swift 版本等系统信息
- 提供复现步骤（如适用）

### 提交代码

1. **Fork 本仓库**
2. **创建功能分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **提交代码**
   - 使用有意义的提交消息
   - 一个提交应只包含一个逻辑变化
4. **推送到你的 Fork**
   ```bash
   git push origin feature/your-feature-name
   ```
5. **创建 Pull Request**
   - 清晰描述你的改动
   - 关联相关 Issue（如有）
   - 确保所有测试通过

## 代码风格

- 遵循 Swift 官方风格指南
- 使用 4 个空格缩进
- 保持代码简洁易读
- 添加适当的注释说明复杂逻辑

## 提交消息约定

使用清晰的提交消息：
- `feat: 添加新功能`
- `fix: 修复 bug`
- `docs: 文档更新`
- `refactor: 代码重构`
- `test: 添加/修改测试`

## Pull Request 检查清单

- [ ] 功能已测试
- [ ] 代码遵循风格指南
- [ ] 更新了相关文档
- [ ] 提交消息清晰有意义
- [ ] 没有新增警告信息

## 问题反馈

如有任何问题，欢迎通过以下方式反馈：
- 在 Issue 中讨论
- 在 Pull Request 中评论

感谢你的贡献！
