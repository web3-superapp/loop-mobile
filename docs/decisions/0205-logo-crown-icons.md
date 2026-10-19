# 0205 · 皇冠 Logo 方图：全套图标与启动页（S244-mobile）

## Status

Accepted 2026-10-19。基线 `fix/S237-test-hints-and-logo` 7624a2c（决策 0204 已换 wordmark）。
**部分被 0207 取代**：iOS AppIcon、Android 启动器图标、Web 图标、登录页 104 pt 标志改用需求方正式方图；本决策的矢量皇冠、wordmark、启动帧、推送图标仍有效。
依据：需求方裁决「Logo 先按方图走」——不等大图，用现有 `LOOP/docs/assets/logo-loop-crown-2026-10-19.png` 自行做方形版本，背景必须黑色 `#050604`（`LoopColors.ink`）。
不新增 Dart 依赖、字体、颜色 token；`pubspec.lock`、`pubspec.yaml` 不变（`assets/brand/` 目录声明已覆盖 `2.0x/`、`3.0x/` 变体）；路由不变。

## Context

0204 只换了 App 内 wordmark；桌面图标、启动屏、推送小图标、Web 图标、App 内 appIcon 位仍是旧的金属 ∞ 标（决策 0179）。
源图只有 480×310，直接放大会糊，所以先矢量化，所有位图都从矢量渲染。

## Decision

### A. 来源与矢量化

- 源：`docs/assets/logo-loop-crown-2026-10-19.png`，480×310 RGBA 透明底，两色：皇冠实测 `rgb(253,235,0)` = **`#FDEB00`**（任务单写的 ≈#FFD600 是目测，按实测取色），字为白 `#FFFFFF`。
- 工具 `tool/brand/make_crown_icons.py`（potrace 1.16 + Pillow + resvg）：
  1. 按色相把每个像素的覆盖度拆到皇冠层（`r−b` 大）与字层，两层各自 LANCZOS 放大 8 倍、轻微高斯、阈值 110/255 二值化；
  2. potrace 各描一层（`-t 60 -a 1.0 -O 0.4`，去掉小于原图约 1 px² 的碎点），路径改写为 480×310 坐标系的绝对命令；
  3. 合成 `assets/brand/loop-logo-crown.svg`（透明底，字在下、冠在上）。
- 质量：放大到 1920 px 目检边缘干净、无锯齿、无断笔；笔刷的干刷缝（字内部细黑缝）与冠的滴漆都保留；原图的半透明羽化边变为实边。
- 位图一律由 resvg（`tool/brand/resvg_render.js`，`@resvg/resvg-js`）从 SVG 渲染，不从源 PNG 重采样；flutter_svg 不参与构建产物。

### B. 构图

| 构图 | 画布 | 规则 |
|---|---|---|
| 方形图标 `loop-app-icon-crown` | 1024 | Ink 底；Logo 包围盒宽 72%，包围盒中心对齐画布中心；iOS 圆角裁切点在内容外 |
| Android 自适应前景 | 108 dp | 透明底；Logo 上任一像素到中心 ≤ 32 dp（66 dp 安全圆半径 33 dp 再留 1 dp），实际 55.4×35.0 dp |
| Android 圆形 legacy | 48 dp | Ink 圆盘，圆外透明；Logo 最远像素 ≤ 圆半径 86% |
| Web maskable | 192/512 | Ink 底；最远像素 ≤ 38%（maskable 安全区 40%） |
| 横版 wordmark | 480×310 viewBox | 透明底，原图构图 |

### C. 承载面清单

| 承载面 | 文件 | 尺寸 | 底 |
|---|---|---|---|
| iOS AppIcon | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`（`Contents.json` 19 个槽位、15 个文件） | 20–1024 px | Ink，RGB 无 alpha |
| iOS 启动图 | `LaunchImage.imageset/LaunchImage{,@2x,@3x}.png` 替换 1×1 占位；storyboard 资源尺寸改 160×103 | 160/320/480 px 宽 | 透明，storyboard 底色本就是 Ink |
| Android 自适应 | `mipmap-*/ic_launcher_foreground.png` | 108/162/216/324/432 | 透明（背景层 `@color/ic_launcher_background` = #050604 不变） |
| Android legacy | `mipmap-*/ic_launcher.png`（RGB）、`mipmap-*/ic_launcher_round.png`（新）；`mipmap-anydpi-v26/ic_launcher_round.xml`（新，同自适应）；Manifest 加 `android:roundIcon` | 48 dp × 5 档 | Ink |
| Android 12 前启动 | `drawable{,-v21}/launch_background.xml` 加居中 bitmap `@drawable/launch_wordmark`；`drawable-*dpi/launch_wordmark.png`（新） | 160 dp 宽 × 5 档 | Ink + 透明图 |
| Android 12+ 启动 | `values-v31/styles.xml` 的 `windowSplashScreenAnimatedIcon` 已指向 `@mipmap/ic_launcher_foreground`，未改 | — | `@color/loop_ink` |
| 推送小图标 | `drawable/ic_loop_notification.xml`：皇冠单独一条白色填充路径（alpha 遮罩），24 dp 画布、内容 22 dp | 24 dp | 透明 |
| Web | `favicon.png`（32）、`icons/Icon-{192,512}.png`、`icons/Icon-maskable-{192,512}.png`；`manifest.json` 两个颜色 → `#050604` | — | Ink |
| App 内 appIcon（登录 104、建钱包环 54、侧栏 32、广场官方头像 18 vector） | `assets/brand/loop-app-icon-crown.webp`（512，无损、无 alpha、Ink 底）、`loop-app-icon-crown.svg`（同构图透明底） | — | — |
| App 内 wordmark（0204 的 5 处） | `assets/brand/loop-wordmark-crown.png` 1x 240×155 + `2.0x/` 480×310 + `3.0x/` 720×465；SVG 回退 `loop-logo-crown.svg` | 最大用到 96 pt 高 | 透明 |

删除：`assets/brand/loop-app-icon-u3d.webp`、`loop-app-icon.svg`、`loop-wordmark.svg`，旧生成器 `scripts/make_app_icons.py`（0179）、`tool/brand/render_app_icon.swift`。
`LoopBrandAssets` 常量名不变，只换路径；`LoopBrandMark` 调用点不改。

### D. 黑底保证点

- iOS 所有槽位 RGB 无 alpha，底色 `#050604`（测试读 PNG 头断言 colour type 2 与尺寸）。
- Android 自适应背景层与 Android 12+ 启动背景均为 `@color/loop_ink` / `ic_launcher_background` #050604；前景四角全透明、白色占比低于 harness 的 12% 底板阈值（`check_launch_icon_contract` 通过）。
- 启动帧（iOS storyboard、Android `launch_background`）底层仍是 Ink，Logo 是透明图叠上去。
- Web `background_color` / `theme_color` 为 #050604。

## 以后换大图时

1. 把新图放到 `LOOP/docs/assets/`；如果仍是两色透明 PNG，直接
   `NODE_PATH=<resvg 安装目录>/node_modules arch -x86_64 /usr/bin/python3 tool/brand/make_crown_icons.py <新图>`，
   全部承载面一次重出（可选 `LOOP_LOGO_PREVIEW_DIR=…` 导出预览）。
2. 若给的是矢量原稿：跳过描摹，把原稿两层路径放进 `loop-logo-crown.svg`（保持冠在上、字在下），从脚本的「compose」步开始跑。
3. 若颜色变了：改脚本顶部 `CROWN` / `TEXT`，同步 `test/loop_assets_test.dart` 里的颜色断言。
4. 宽高比变了：`LaunchScreen.storyboard` 的 `<image name="LaunchImage">` 尺寸、wordmark 1x/2x/3x 的高度断言要跟着改。
5. 跑 `scripts/check_harness.py`、`flutter test test/loop_assets_test.dart`，真机看桌面图标、启动帧、推送小图标。

## Consequences

- 原图的柔边变成实边，小尺寸（iOS 20 pt、Android mdpi）更利落；源图只有 480 px，皇冠细节（滴漆）在 29 pt 以下基本看不出。
- 推送小图标只用皇冠（LOOP 字在 24 dp 下会糊成一团）。
- 构建期依赖 potrace / resvg 只在重出图标时需要，不进 App 构建。

## Verification

- 生成脚本：iOS 15 个文件、Android 5 档 × 4 张 + 5 张启动 bitmap、Web 5 张全部写出；前景 Logo 55.4×35.0 dp，最远像素 32.0 dp。
- `test/loop_assets_test.dart` 新增 S244 组：旧资源已删、新 SVG 颜色/视窗、webp 为 VP8L、wordmark 三档尺寸、iOS 19 槽位 RGB 与尺寸、启动帧与 round 图标、推送图标为白色填充 24 dp、flutter_svg 能解析两张 SVG、Web manifest 颜色。
- `scripts/check_harness.py`、`python3 -m unittest discover -s tests`、`flutter analyze`、`flutter test` 通过。
