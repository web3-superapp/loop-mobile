# 0179 · 桌面图标换成金属版品牌渲染

## Status

Accepted 2026-10-15。基线 `integration/v2` 3e49203。用户要求「logo 换一下，用加载页面那个金属的」。

## Context

App 内的品牌标（`LoopBrandMark`）自决策 0051 起就优先画金属渲染 `assets/brand/loop-app-icon-u3d.webp`，只在非黑底上退回平面 SVG；
只有手机桌面图标（iOS `AppIcon.appiconset`、Android `mipmap-*`）还是平面 lime 线版。金属渲染只有 256 px，而 App Store 市场图标要 1024 px。

## Decision

- 新脚本 `scripts/make_app_icons.py <源图>`：找出黑底上的深色圆角底板（非黑像素包围盒 + 2 px 出血）裁成正方形，LANCZOS 生成
  iOS `Contents.json` 列出的全部槽位与 Android 五档 `ic_launcher.png`（48 dp）/ `ic_launcher_foreground.png`（108 dp 画布，底板占 78%，其余透明，
  背景色仍是 `ic_launcher_background` #050604）。本机 PIL 只有 x86_64 版本，用 `arch -x86_64 /usr/bin/python3` 跑。
- 本次用 256 px 渲染生成：设备上的槽位（≤ 192 px）均为缩小，清晰；1024 px 市场图标是 212 px 底板的放大，偏软，
  **拿到 ≥ 1024 px 原图后重跑脚本即可替换，其它不变**。
- `assets/brand/` 与 `LoopBrandMark` 不改；Android 包名、iOS Bundle 不改。

## Consequences

- TestFlight / 安卓包桌面图标即为金属版；App Store 上架前必须用高清原图重跑一次（docs/34 第 20 题的上架素材一并要）。
- 平面 SVG 仍是 App 内非黑底场景的品牌标，没有删除。

## Verification

- `arch -x86_64 /usr/bin/python3 scripts/make_app_icons.py assets/brand/loop-app-icon-u3d.webp`：iOS 19 个槽位、Android 10 个文件全部写出。
- 180 px（iPhone 3x）、432 px 自适应前景、1024 px 预览并排目检：底板裁切正确，无黑边残留。
- harness 的「plate-free launch icon」规则原先把任何一个不透明纯白像素都当成烘进去的白底板；金属渲染本身有纯白高光（mdpi 前景纯白占 0.18%），规则改为纯白面积占比 > 12%（`LAUNCH_ICON_WHITE_PLATE_SHARE`）才算底板，仍能抓住 b653942 那种整块白底。
- `python3 scripts/check_harness.py` 与 `python3 -m unittest discover -s tests` 通过。
