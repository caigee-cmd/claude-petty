# Screenshots Guide

This folder stores visual assets used by the GitHub README, release notes, and social previews.

这个目录用于存放 GitHub README、Release 页面和社交分享图会用到的截图素材。

## Current Assets

- `claude-demo.gif`
- `claude-glance-demo.mp4`
- `menupannel.png`
- `settingpannel-cat-floting.png`
- `settingpannel-cat-play-guitart.png`

Notes:

- `menupannel.png` is currently the only lightweight overview screenshot in the repo.
- The two settings screenshots work well as supporting visuals, but they should not replace a proper hero image.
- If you need a stronger first-screen visual later, export a 16:9 cover image from the MP4 demo and upload that separately.
- The `mascots/` folder is currently empty, so README should not reference GIF mascots until new assets are added back.

## Recommended README Order

1. One-sentence value proposition
2. `claude-demo.gif`
3. Highlights list
4. `menupannel.png`
5. `settingpannel-cat-floting.png` + `settingpannel-cat-play-guitart.png` side by side
6. Installation / Privacy / Limitations

## Layout Advice

- Keep the top of the README compact; do not stack several tall media blocks before the highlights.
- Use GIF for the README demo section, and keep MP4 as the high-quality fallback link.
- Treat the settings screenshots as supporting material rather than hero content.
- Keep Chinese and English README structures aligned so screenshots appear in the same order in both files.
- If you add animated mascot assets again later, place them near the settings section instead of above the fold.
- If you need a social preview image, export a clean 16:9 still from the MP4 demo instead of reusing a narrow window screenshot.

## 截图建议

- 使用真实数据或脱敏后的真实数据，不要用明显的占位内容
- 保持窗口尺寸稳定，避免一张大一张小
- 尽量统一浅色或深色外观，不要混搭
- 如果后续要强化首页第一屏，优先从 MP4 中导出一张 16:9 封面图，不要直接拿窄图硬撑主视觉

## README 中的推荐顺序

建议在仓库首页按这个顺序展示：

1. 一句话介绍产品
2. GIF 演示
3. 功能亮点
4. 菜单栏 popover
5. 两张挂件设置图并排展示
6. 安装、隐私和限制说明

## Release 页面建议

GitHub Release 文案里至少放：

- 一张主封面图，优先使用从 `claude-glance-demo.mp4` 导出的 16:9 封面
- README 首页优先使用 `claude-demo.gif`
- 一个视频入口，直接链接 `claude-glance-demo.mp4`
- 当前版本亮点
- 已知限制
- 安装说明入口
- `ClaudeGlance.zip` 的 SHA-256
