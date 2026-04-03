# Screenshots Guide

This folder stores visual assets used by the GitHub README, release notes, and social previews.

这个目录用于存放 GitHub README、Release 页面和社交分享图会用到的截图素材。

## Current Assets

- `claude-glance-demo.mp4`
- `menupannel.png`
- `stastic.png`
- `settingpannel-cat-floting.png`
- `settingpannel-cat-play-guitart.png`

Notes:

- `stastic.png` is currently the best hero-style screenshot because it explains the product fastest.
- `menupannel.png` is useful as supporting context, but it is visually too small to carry the first screen alone.
- The `mascots/` folder is currently empty, so README should not reference GIF mascots until new assets are added back.

## Recommended README Order

1. One-sentence value proposition
2. MP4 demo link
3. Highlights list
4. `menupannel.png`
5. `stastic.png`
6. `settingpannel-cat-floting.png` + `settingpannel-cat-play-guitart.png` side by side
7. Installation / Privacy / Limitations

## Layout Advice

- Keep the top of the README compact; do not stack several tall media blocks before the highlights.
- Use the stats screenshot as the largest visual and treat the settings screenshots as supporting material.
- Keep Chinese and English README structures aligned so screenshots appear in the same order in both files.
- If you add animated mascot assets again later, place them near the settings section instead of above the fold.
- If you need a social preview image, export a clean 16:9 still from the MP4 demo instead of reusing a narrow window screenshot.

## 截图建议

- 使用真实数据或脱敏后的真实数据，不要用明显的占位内容
- 保持窗口尺寸稳定，避免一张大一张小
- 尽量统一浅色或深色外观，不要混搭
- 如果界面重点很多，优先突出一张“第一眼能懂产品”的主图，目前最适合的是 `stastic.png`

## README 中的推荐顺序

建议在仓库首页按这个顺序展示：

1. 一句话介绍产品
2. MP4 演示链接
3. 功能亮点
4. 菜单栏 popover
5. 详细统计窗口
6. 两张挂件设置图并排展示
7. 安装、隐私和限制说明

## Release 页面建议

GitHub Release 文案里至少放：

- 一张主截图，优先 `stastic.png`
- 一个视频入口，直接链接 `claude-glance-demo.mp4`
- 当前版本亮点
- 已知限制
- 安装说明入口
- `ClaudeGlance.zip` 的 SHA-256
