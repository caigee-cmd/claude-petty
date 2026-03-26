# Claude Glance

## 发布流程

### 1. 提交代码到 main 分支
```bash
git add .
git commit -m "描述"
git push origin main
```

### 2. 打 tag 触发 Release 构建
```bash
git tag v<version>
git push origin <version>
```

**版本号规则：**
- Patch: `v0.0.x` - Bug 修复
- Minor: `v0.x.0` - 新功能
- Major: `v1.0.0` - 破坏性改动

### 3. GitHub Actions 自动完成
- 从 git tag 提取版本号写入 `project.yml`
- 重新生成 Xcode 项目
- 构建 Release 版本
- 创建 DMG 安装包
- 创建 GitHub Release 并上传 DMG 和 ZIP

### Workflow 文件
- `.github/workflows/ci.yml` - CI 构建和测试
- `.github/workflows/release.yml` - Release 构建和发布
