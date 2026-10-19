# 0207 · 正式方形 App 图标（S244b-mobile）

## Status

Accepted 2026-10-19。基线 `feat/S243-utf8-ticker` c2e207d（栈 S236→S237→S244→S243→S244b）。
部分取代 0205 的 C 节：iOS AppIcon、Android 启动器图标、Web 图标、登录页 104 pt 标志改用正式图；0205 的矢量皇冠、wordmark、启动帧、推送图标不变。
不新增 Dart 依赖；`pubspec.yaml`（`assets/brand/` 目录声明已覆盖新文件）与 `pubspec.lock` 不变；路由不变。

## Context

需求方 2026-10-19 21:00 交来正式方形图标，替换 S244 自己拼的方图：
`LOOP/docs/assets/app-icon-2026-10-19/LOOP-CROWN-square-{1024,512,256}.png`，均为 RGB 无 alpha；黑色纹理底、黄色霓虹描边「LOOP」+ 皇冠、紫色喷溅，**满幅构图**——字斜着从左下角铺到右上角，宽约占 94%，黄色笔画最远处离中心 0.561 × 边长（实测，阈值见脚本 `STROKE_LEVEL`）。

## Decision

### A. 承载面

| 承载面 | 用哪张 | 做法 |
|---|---|---|
| iOS AppIcon 15 个文件 / 19 槽位 | 正式图 | 1024 直接 LANCZOS 缩，RGB 无 alpha，不加边距（iOS 自己裁圆角，正式图四角只有纹理） |
| Android `ic_launcher`（legacy，5 档） | 正式图 | 直接缩到 48 dp，RGB |
| Android `ic_launcher_round`（legacy，5 档） | 自适应合成 | 取自适应两层合成后启动器可见的中间 72 dp，再套圆；直接把正式图套圆会切掉 L 与 P 的笔画 |
| Android 自适应 `ic_launcher_background`（新，5 档） | 正式图的纹理 | 见 B |
| Android 自适应 `ic_launcher_foreground`（5 档） | 正式图 | 见 B |
| Android 12+ 启动图标 | 自适应前景 | `windowSplashScreenAnimatedIcon` 仍指 `@mipmap/ic_launcher_foreground`，底色仍 `@color/loop_ink`；可见圆半径 36 dp，笔画最远 32 dp，不被裁 |
| Web `favicon.png`、`Icon-192/512` | 正式图 | 直接缩，RGB |
| Web `Icon-maskable-192/512` | 自适应合成 | 纹理底 + 正式图缩到边长 67.8%，笔画最远 38%（maskable 安全圆 40%） |
| 登录页 `privy_login_screen.dart` 104 pt | 正式图 | `assets/brand/loop-app-icon-official.webp`，512 px、有损 q90、VP8 无 alpha、89 KB；`LoopBrandMark(kind: officialIcon)` 加 `height × 0.225` 圆角裁切，读起来像 App 图标而不是贴图 |
| 建钱包环 54、桌面侧栏 32、广场官方头像 18 | 0205 矢量皇冠 | 不变（`LoopBrandMarkKind.appIcon`） |
| 启动帧（iOS storyboard / Android `launch_background`）、横版 wordmark、推送单色皇冠 | 0205 | 不变 |

代码：`LoopBrandAssets.officialIconWebp`（正式方图）与 `appIconWebp` / `appIconSvg`（小标志）并存；`LoopBrandMarkKind` 新增 `officialIcon`，由调用处显式选，目前只有登录页一处。`officialIcon` 解码失败时回退到同一张矢量 SVG。

### B. Android 自适应图标两层

- **背景层** `mipmap-*/ic_launcher_background.png`（108 dp，RGB）：从正式图上下两条不含笔画的纹理带（第 0–90 行、第 905–1024 行，按 1024 计）拼成一条，水平 / 垂直镜像铺成无缝平铺，轻高斯 1.2 px、亮度 × 0.85。只取纹理，不含任何文字或光晕。`mipmap-anydpi-v26/ic_launcher{,_round}.xml` 的 background 由 `@color/ic_launcher_background` 改为 `@mipmap/ic_launcher_background`（同名 color 资源保留，类型不同不冲突）。
- **前景层** `mipmap-*/ic_launcher_foreground.png`（108 dp，RGBA）：正式图整体缩到 **57.1 dp 见方（108 dp 画布的 52.8%）** 居中，使黄色笔画最远处 = 32.0 dp（66 dp 安全圆半径 33 dp 再留 1 dp）。边缘 7% 宽做 smoothstep 羽化到透明，画布四角完全透明，叠在纹理背景上看不出方框。
- 为什么不是「整图缩到 66 dp 见方」：正式图满幅，笔画离中心 0.561 × 边长，66 dp 见方时笔画最远 37 dp，超出安全圆，圆形遮罩会切掉 L 的左下与 P 的右上。按笔画而非按画布定比例，字一个都不切。

### C. 为什么小尺寸不用正式图

正式图的辨识靠霓虹光晕、喷溅与滴漆纹理。54 pt 以下（@3x 162 px）这些细节糊成一团黄光，字形反而不如 0205 的矢量实边清楚；18 pt 的广场官方头像更只剩一块黄斑。所以 54 / 32 / 18 三处仍用矢量皇冠，推送图标仍是单色皇冠剪影（Android 状态栏只认 alpha）。

### D. 生成脚本

- 新增 `tool/brand/make_official_icons.py`（只需 Pillow）：读正式 PNG，写出 A 表中「正式图 / 自适应合成」所有文件；`LOOP_LOGO_PREVIEW_DIR=…` 时导出预览 `ios-icon-180.png`、`android-adaptive-circle-preview-432.png`（启动器可见 72 dp 区域套圆）、`login-104@3x.png`。
- `tool/brand/make_crown_icons.py`（0205）去掉 iOS AppIcon、Android 启动器 mipmap、Web 图标三段输出，只保留矢量 SVG、小标志 webp、wordmark、启动帧与推送图标，两个脚本不再写同一文件。
- 以后换图：把新方图放到 `LOOP/docs/assets/`，
  `arch -x86_64 /usr/bin/python3 tool/brand/make_official_icons.py <新图>`；若构图变了，先确认 `TEXTURE_BANDS` 两条纹理带仍不含笔画（脚本会打印笔画半径；测试会查背景层无黄色笔画）。

## Consequences

- 桌面图标、App Store 图标、Android 启动器与登录页同为需求方正式图；App 内小尺寸标志与之不同构图（皇冠矢量），这是有意的，见 C。
- Android 自适应前景比画布 66 dp 小（57 dp），四周露的是同一张图的纹理而不是 Ink 平色，视觉上仍是一整张图。
- 预览：`LOOP/docs/assets/logo-preview/{ios-icon-180,android-adaptive-circle-preview-432,login-104@3x}.png`。

## Verification

- `test/loop_assets_test.dart` 新增 S244b 组：登录 webp 为 VP8 无 alpha；iOS 180 图笔画越过 r 50%（正式图而非矢量）；前景 5 档尺寸 / RGBA / 四角 alpha 0 / 笔画最远 28–33 dp；背景 5 档 RGB 无笔画、两份 adaptive XML 指向 mipmap 背景；legacy 5 档尺寸；`officialIcon` 只在登录页、带圆角裁切。S244 组的 iOS 19 槽位 RGB 与尺寸断言保持通过。
- `scripts/check_harness.py`（含 `check_launch_icon_contract`）、`flutter analyze`、全量 `flutter test` 通过。
