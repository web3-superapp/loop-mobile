# 0277 · 设计系统底座按需求方 Figma 稿重建（字体 / token / 共享组件 / 门禁）

## Status

Accepted · 2026-11-04（S352-mobile）。来源：用户 11-04 裁决「色、字体、字号、字重、行高、间距、圆角、组件形态一律按需求方 Figma 稿走」，数值与裁决见 `docs/58-Figma设计规范-需求方稿-2026-11-04.md`（§9 为准）。页面结构不回退（docs/56 §四 10 条、§五 0274–0276 保留）。逐页对齐是 S353a / b / c（0278–0280），不在本决策。

## Context

TF 64（d04be4a9）的底座仍是 0210 / 0229：拉丁 Arimo + 大数字 Anton、行主标题 17 / 600、副标 14、胶囊紫实心 + 黄喷点、底栏 70 高 r20 + 铬顶线 + 黄喷底、页签 3 × 24 黄短线、卡片 r16、按钮 r12、`pill` 999。稿子（393 宽）全是 Inter，字阶整体低一到两档，选中态是白，大量 10 / 11 小字，卡片 12、按钮 8、筛选胶囊 8，底栏 353 × 68 r12 白 3% 玻璃。docs/58 §7 列了 46 条冲突、§7.5 列了稿内矛盾，§9 一次定死。

## Decision

### 字体

- 拉丁与数字 = **Inter**（rsms/inter v4.1 `extras/ttf/` 静态 Light 300 / Regular 400 / Medium 500 / SemiBold 600 / Bold 700 + Black Italic 900，OFL，`assets/fonts/Inter-*.ttf` + `OFL-Inter.txt`）。**Anton、Arimo、`Noto Sans SC Display` 撤掉**（文件、pubspec 注册、`LoopFonts.display` / `cjkDisplay` / `displayFallback`、`LoopTypography.condensed`）。
- 中文 = Noto Sans SC（Regular / Medium / Bold，经 `fontFamilyFallback` 第一位）。引擎按最近字重取：300 / 400 → Regular、500 → Medium、600 / 700 / 900 → Bold。
- 地址 / 链接（`LoopType.code` / `codeSm`）改 Inter 14 / 400、13 / 400（tnum）；IBM Plex Mono 保留注册与 `LoopTypography.mono`，只给真代码块。

### 字阶（`LoopType`，docs/58 §9.2）

| step | 值 | 默认色 |
| --- | --- | --- |
| `plateFigure` | 40 / 700 / 46 | 主字 |
| `heroFigure` `sectionIndex` | 30 / 700 | 主字 |
| `title1` | 28 / 700 / 1.2 | 主字 |
| `segmentTitleIdle` | 24 / 600 / 1.2 | 三级字 |
| `inviteCode` | 23 / 600 | 黄 |
| `title2` | 22 / 700 / 1.3（稿无，保留） | 主字 |
| `headline` | 19 / 700 | 主字 |
| `postAuthor` | 18 / 600 | 主字 |
| `emptyTitle` | 17 / 700 / 24 | 主字 |
| `headlineSm` | 16 / 700 | 主字 |
| `rowTitleLg` | 16 / 500 / 23 | 主字 |
| `figure` | 16 / 600 / 23 tnum | 主字 |
| `button` | 16 / 600 | 主字 |
| `tab` / `tabIdle` | 16 / 600 / 20 · 16 / 500 / 20 | 白 · 次字 |
| `body2` | 16 / 400 / 25 | 主字 |
| `searchHint` | 15 / 500 | 三级字 |
| `body1` | 14 / 500 / 22 | 主字 |
| `figureSm` | 14 / 600 tnum | 次字（旧默认色） |
| `label` | 14 / 500 / 20 | 三级字（旧默认色） |
| `body2Sm` | 14 / 400 / 22 | 主字 |
| `captionMd` | 14 / 300 / 22 | 次字 |
| `code` | 14 / 400 tnum | 主字 |
| `figureXs` | 13 / 600 tnum | 次字 |
| `chip` / `chipIdle` | 13 / 600 · 13 / 500 | 白 · 次字 |
| `buttonSm` | 13 / 600 | 主字 |
| `eyebrow` `kicker` | 13 / 500 | 次字 |
| `codeSm` | 13 / 400 tnum | 主字 |
| `caption` | 12 / 300 / 16 | 三级字 |
| `tag` | 12 / 600 / 1.2 | 次字 |
| `buttonXs` | 12 / 600 | 黄 |
| `navLabel` | 12 / 500 / 16（英文项 `navLabelLatin` 11 / 600 / 15） | 次字 |
| `meta` | 12 / 500 | 三级字（旧默认色） |
| `emptyMessage` | 12 / 400 / 18 | 次字 |
| `tickerFigure` | 12 / 600 / 16 tnum | 主字 |
| `count` | 11 / 500 / 15 | 次字 |
| `stageTag` | 11 / 400 / 1.0 | 黄 |
| `buyTag` | 10 / 600 / 15 | rise |
| `unreadCount` | 10 / 700 | onYellow |
| `metaSm` | 10 / 400 | 次字 |
| `progress` | 10 / 300 / 16 | 次字 |
| `rankFigure` | 16 / 900 italic tnum | 按名次在调用处给 |

旧档名全部保留、换到对应稿值：`title` `titleLg` → `body1`；`body` `bodyLg` → `body2`；`bodySm` → `body2Sm` 次字；`captionSm` → `caption`；`figureMd` `figureBody` → `figure`；`figureCompact` → `figureXs`；`action` → `button`；`headingSm` `sectionTitle` → `headline`。**已有档位稿里没给色的保留原默认色**（`figureSm` / `figureXs` 次字、`label` / `meta` 三级字），页面要稿色在调用处给——否则 60 多处「行内次要数字」会一起变成白色粗体。字号下限 10。

### 色（`LoopColors`，§9.3，收敛到 §1.3 第一列）

`bg` / `ink` #070809、`textPrimary` / `chalk` #f4f5f7、`textSecondary` / `text2` #a2a4ad、`textTertiary` / `text3` #6f717a、`textOnSelected` 白、`yellow` #ffd21c、`onYellow` #090a0c、`purple` #a62eff、`podiumGlow` #8e22ff、`yellowSoft` #30280c（实色）、`rise` #22c982 / `riseSoft` #123025、`tagGreen` #1ad68c / `tagGreenBg` #053324、`tagPurple` #c957ff / `tagPurpleBg` #290a3b、`bronze` #cd8032（`copper` 别名）、`fall` 不变。面与线：`white3/4/5/8/10/15/30/60`（语义名 `surfaceGlass` `chipIdle` `divider` `buttonGhost` `chipActive` `tabRule` `bannerEdge`）、`navEdge` #34353b、`cardEdge` #1d1f24、`dividerSolid` #24262c、`surfaceElevated` #1a1b20、`cardInset` #0b0c0f、`card` #121318、`searchBg` #0e0f12、`countBg` #131417、`progressTrack` #22232a / `progressFill` 白 80%、`powerCardGradient` #14151a → #1b1028。

旧名留作别名指向新值：`line` = 白 5%、`line2` = `cardEdge`、`plate` = `panel` = `card`、`plateRaised` = `card2` = `input` = #24262c、`graphite` #111214、`bg2` = `searchBg`、`assistFill` = 白 8%、`purpleSelected` = 白 10%（**选中态改白**，紫不再做选中底）、`purpleCapsule` / `purpleInk` = 观点标签色。色相字面量（`09090B` / `FFD600` / `9C36FF` / `F2F2F4`）全仓换成新值。`LoopGround` 判定「浅底」的亮度线从 0.3 降到 0.05（三级字 #6f717a 亮度 0.17，否则会被当成浅底墨色）。

### 间距 / 圆角 / 阴影（§9.4）

- `LoopSpacing`：`section` 36 → 24、`headingGap` 16 → 12、`bannerGap` 28 → 16；新增 `chipGap` 12、`chipSpacing` 8；`page` 20、`rowGap` 12 不变；`rowMin` 72 / 80 未动（各列表行高由 S353 按 §3.2 定）。
- `LoopRadius`：`card` 16 → 12、`tabBar` 20 → 12、`button` / `tool` / `wideButton` 12 → 8、**`pill` 999 → 8**；新增 `chip` 8、`tag` 5、`stage` 4、`count` 2、`compactButton` 6、`round`（= `pillRound`）999。全仓 45 处 `LoopRadius.pill` 逐处看过：进度条、轮播圆点、步骤点、引用竖条、未读圆徽章 8 处改 `round`，其余是胶囊 / 标签 / 徽章，随 8。
- `LoopDepth.tabBar` / `ticker` = `0 8 20 rgba(0,0,0,.38)`；`tabBarEdge` = `navEdge`。
- `LoopTouch.tabBarHeight` 68、`LoopLayout.tabBarInset` 24（底）、新增 `tabBarSideInset` 20、`tabBarPadding` 0、`tabPageBottomReserve` 90 → 92；新增 `buttonCompact` 30、`buttonMedium` 36、`buttonJoin` 28 × 54、`chipHeight` 32、`chipMinWidth` 54、`searchField` 44。
- `LoopTheme`：`onPrimary` = onYellow、`outline` = divider、`dividerColor`、chip 主题（白 4% / 10%、r8、chip 字）、导航主题按稿同步。

### 共享组件

1. **页标题 + 涂鸦**（`lib/widgets/loop_title_doodle.dart`）：`LoopTitleDoodle`（稿位图按 §5.1 裁出可见段，64 × 13，r2，1x / 2x / 3x）、`LoopTitleDoodle.under`（涂鸦画在标题下方的留白里，不占布局高度，任何字号缩放都不会撑爆 74 高的栏）、`LoopDoodleTitle`、`LoopFigmaAssets`。用在 `LoopTopbar`（无返回键、非 dense / flat、无 kicker / subtitle）、`LoopAtmoTitle`（MEME / 我的）、`LoopSegmentedTabPage` 选中段；未选段 `segmentTitleIdle`，基线对齐，间距 14。
2. **一级分段**（`lib/widgets/loop_tab_strip.dart` · `LoopTabStrip`）：等宽格、选中白 16 / 600 + 满格 2px 黄底线、未选次字 16 / 500、通栏 1px 白 10%、可选计数小标（选中紫 / 未选白 60%，底白 5% r2）、格高 42 + 条内 2 = 44 触控。`LoopProfileSectionsBar` 改用它。
3. **二级筛选**（`lib/widgets/loop_filter_chips.dart` · `LoopFilterChip` / `LoopFilterChips`）：54 × 32 r8，白 10% / 4%，13 / 600 白 / 13 / 500 次字，间距 8，44 触控，按下变深。`WalletAssetTabs` 与 `ReferralSubTabs`（S350 留下的两份同款）、广场「全部 / 我加入的」改用它。`LoopSeg` / `LoopSegBar` 同步：选中白 10% + 白字、未选白 4%、胶囊 32、间距 8、**默认不贴黄喷点**（`splat: true` 才贴）。
4. **底栏**（`LoopTabBar` / `LoopTabItem`）：353 × 68、左右 20、距底 24、r12、白 3% + 1px #34353b + 稿阴影 + 模糊 15；图标换稿 SVG（`flutter_svg` 已是依赖，无新增），22（MEME 24）；选中黄光晕 38 + 稿黄色实心图标 + 黄字；文字 12 / 500（MEME 11 / 600），未选 #a2a4ad。**0261 动效全保留**（玻璃指示条拉伸回弹、按压放大、字形动效、放大镜）；S264 铬顶线与黄喷底撤掉。「我的」（slug `wallet`）用稿的钱包图标。
5. **搜索框**（`lib/widgets/loop_search_entry.dart` · `LoopSearchEntry`）：44 高 r12、1px #1d1f24、搜索图标 20；`chat` 底 #0e0f12 + 15 / 500 三级字，`square` 底 #111214 + 14 / 400 次字。聊天、广场入口改用；广场控件行 52 → 44。
6. **按钮**（`LoopButtonSize`）：`regular` 48 r8 16 / 600；`compact` 30 r6 16 / 600（发射）；新增 `medium` 36 r8 13 / 600（次按钮白 8% 黄字）、`join` 54 × 28 r6 白 8% 黄字 12 / 600。小尺寸都在 44 触控里。
7. **行分割线**：`LoopRecordRow.divider`（默认关）画 1px 白 5%，跨内容宽；哪些列表开由 S353 定。
8. **空态**：`LoopEmptyArt` 换稿彩色皇冠位图（页 106、块内 72），标题 `emptyTitle` 17 / 700；**说明句默认不画**（0248 优先于稿），`message` 仍读给读屏。新增 `showMessage`：只给陈述状态事实的句子（拒绝原因、列表规则、数据来源），画成 `emptyMessage` 12 / 400 次字。带 `emptyReason` 的通用状态块（`LoopChainStateBlock` / `LaunchStateBlock` / `CommunityStateBlock`）与 15 处被测试钉住的事实句调用点开了 `showMessage`。`LoopAtmoEmpty` 同样不画说明句。
9. **标签**：新增 `LoopStatusTag`（`post` 22 r5 12 / 600、`stage` 19 r4 11 / 400、`buy` 17 r4 10 / 600；色 `yellow` / `green` / `purple` / `rise`）；`LoopBadge` 改 r5 12 / 600；`LoopTag`（人物行）r5；`LoopUnreadBadge` 字 10 / 700。

### 门禁与资产

- `scripts/check_harness.py`：字号下限 G2 11 → **10**（画布白名单不动）；字体文件清单换 Inter（缺 Inter 文件 / 未注册 / pubspec 无 `family: Inter` 报错），Sora / Anton / Arimo 文件与家族注册拒收；`fontFamily:` 规则改为「只允许 `LoopFonts.*`」（正则 `fontFamily\s*:(?!\s*LoopFonts\.)`）。`tests/test_check_harness.py` 同步并新增一条用例。
- 资产 `assets/figma/`（pubspec 注册目录）：涂鸦线 1x / 2x / 3x、皇冠矢量 + 两张皇冠位图（各 1x / 2x / 3x）、MEME 氛围光、领奖台紫光、底栏光晕、底栏 10 个图标、钱包 15 个图标 + 净值走势线、帖子迷你走势线。头像 / Banner 未拷。

## Consequences

- 改动在 `lib/core/theme/loop_theme.dart` 与 `lib/widgets/**`、`lib/features/shell/loop_shell.dart`，及少量页面调用点（WalletAssetTabs、ReferralSubTabs、聊天 / 广场搜索入口、广场「全部 / 我加入的」、算力榜名次列 `figureXs`、dense 顶栏标题 `headlineSm`、自己的聊天气泡保持实紫、空态事实句 `showMessage`）。View model / gateway / codec / 路由表未动；lockfile 未变；无新增依赖。
- 测试：旧断言改到稿值，无删除、无 skip；新增 `test/s352_design_system_test.dart`（九件组件）、`test/s352_shots_test.dart`（复用 S350a / b / c 出图 + 底栏，`LOOP_SHOTS=true` 才出图）。
- 已知取舍（待主代理 / 需求方定）：三级字 #6f717a 在 #070809 上对比度 4.1、在聊天磨砂板上 3.8，不到正文 4.5（相关断言改为 ≥ 3:1）；0261 的玻璃指示条与稿的光晕并存；MEME 首页「内盘 / 预告 / 已毕业」（`Launch2DeskTabs`）仍是紫胶囊 + 喷点，稿是一级分段（S353a 换 `LoopTabStrip`）；总资产仍黄（稿白，S353c）；`LoopButton` 选中项与 MarketTabBar 的黄喷点未动。
