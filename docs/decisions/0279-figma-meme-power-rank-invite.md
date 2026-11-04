# 0279 · MEME / 情报·算力 / 算力榜 / 邀请 按需求方 Figma 稿逐页对齐

## Status

Accepted · 2026-11-04（S353b-mobile）。依据：主代理 S353 任务单 §S353b、docs/58 §5.1–§5.5、§5.14–§5.17、§5.20、§9（裁决优先），底座见 0277。结构不回退（docs/56 §四、§五 0274–0276 保留），文案以 TF 64 / S355 英文为准，不加说明句（0248）。不改路由、view model、gateway、codec，不改 `launch2_candle_chart.dart`。

## Context

稿 vs 现状，改前诊断：

MEME（稿 `1-meme-2001-21.png`）

1. `launch2_atmosphere.dart` `Launch2DeskTabs`：内盘 / 预告 / 已毕业是卡底上的紫色实心胶囊 + 黄喷点；稿 §5.2 是一级文字 tab（选中白 16 / 600 + 满格 2px 黄线、未选次字、计数小标、通栏 1px 白 10%）。
2. `Launch2Board` 继承 `LoopAtmoBoard`：行放在 r12 卡底里；稿 §5.4 行直接站在页面上，每行底 1px 白 5%。
3. `Launch2BoardRow`：80 高、黄色喷滴进度条 88 宽、已售 % 14 / 600；稿 71 高、进度条 142×4 轨 `#22232a` 填白 80%、% 10 / 300、阶段胶囊 19 高 r4 11 / 400。
4. `Launch2TradeTicker`：36 高卡底 + 紫色「实时」胶囊；稿 §5.5 35 高 r8 白 3% + 1px 白 3% + 阴影，「实时」是 5 点 + 12 / 600 紫字无底，买入 17 高 r4 10 / 600。
5. 横幅 `launch2DeskCampaignHeight` 180、r12、只有顶边线；稿 353×162 r8 1px 白 15%。
6. `Launch2LaunchCapsule`（发射）36 高 r8 图标 18；稿 §5.20 30 高 r6 火箭 21 + 16 / 600、onYellow。
7. 氛围层无稿的 420 圆紫光（2001:22）。

情报 · 算力（稿 `6-power-2001-576.png`）

1. `MiningSummaryHero` 是 `LoopRecordCard`（r12 卡底 + 灰皇冠水印），总算力 Inter 40 黄；稿 §5.14 算力卡：渐变 `#14151a → #1b1028`、涂鸦墙 30%、标签 13 / 500、值 30 / 700 白、快照右上 10 / 400 白 30%。
2. `MiningRankEntry` 是右上角灰底胶囊（皇冠图标 + 「Rank #12」+ 箭头）；稿是值下方一行「当前排名 第 N 名」12 / 500 + 数字 Black Italic 16（第 1 名黄、第 3 名铜）+ 皇冠位图 61×37。
3. `mining_screen.dart` 代币 / NFT / 邀请用 `LoopSegBar`；§9.4 二级 = 54×32 筛选胶囊（`LoopFilterChips`）。

邀请（稿 `8-invite-2001-760.png`）

1. `referral_screen.dart` 邀请码卡是 `LoopLedgerComposite`；稿 §5.17 r8 底 `#121318` 内边距 19。
2. 标签 12 / 300、码 `keyFigure`、链接 14 / 400；稿标签 11 / 400、码 23 / 600 黄（`inviteCode`）、链接 13 / 400。
3. 两个按钮是 48 高常规按钮、分享无图标；稿 36 高 r8：分享黄底 + 分享图标 18 + 13 / 600，生成海报白 8% 黄字，间距 12。

算力榜（稿 `7-power-2001-676.png`）

1. `IntelRankBoard` 用户 / 社区 / 邀请是带图标的 `LoopSegBar` 胶囊；稿 §5.2 一级文字 tab。
2. 「我的名次」是 `LoopChromePlate`（铬边拉丝底），名次 Inter 40 黄；稿算力卡渐变 + 30 / 700。
3. 「Podium」是 `LoopLabel`；稿 §5.14 区块标题 19 / 700 + 右端「ⓘ 实时更新」10 / 400。
4. 领奖台是墙面 + 紫雾底板、72 / 56 头像铬环、喷漆 01/02/03、名字 14 / 500 两行、数值 `figureLg`；稿 §5.15 紫光椭圆 270×85、三块 `#191a20` r12 台（中台高 17）、头像 62 / 54（黄 / 紫环）、黄线条皇冠 27、名次 17 / 700（01 黄）、名字 14 / 600、数值 13 / 600、「我」小标、空位 52 圆环。
5. 名次行 72 / 80 高、名次列 22 右对齐、头像 40、副行 12 / 300、数值 16 / 600；稿 §5.16 51 高（上下 6）、名次列 34 13 / 600 次字、头像 36、副行 10 / 300、数值 13 / 600、无线。

## Decision

- MEME：`Launch2DeskTabs` 包 `LoopTabStrip`（计数、per-tab key 不变，`scaleDownLabels: true` 让英文「Bonding pool」在 360 不截断）；tab → 列表 8。`Launch2Board` 改为页面内平铺 + 每行 1px 白 5%；`Launch2BoardRow` 70 + 线、新 `Launch2ProgressBar`（142×4、`progressTrack` / `progressFill`）、% `LoopType.progress`；`Launch2BoardStage` 19 高 r4 `stageTag`，已毕业用 `tagPurple`；跑马灯 35 高白 3% + `LoopDepth.ticker`，「实时」无底紫字，买入 17 高 `buyTag`；横幅 162、r8、1px `bannerEdge`；162 高下空态标题改两行 19 / 700（不再缩成小字），活动副标改 12 / 300 两行、按钮 36；发射 30 高 r6 火箭 21；`Launch2AtmosphereBackdrop` 在墙上叠稿的 `ambient-glow.svg`（420 圆 `#a62eff`，(−175, 70)）。
- 情报 · 算力：`MiningSummaryHero` 改算力卡（渐变 + 墙 30%、标签 `eyebrow`、快照右上 `metaSm` 白 30%、值 `heroFigure` 白）；`MiningRankEntry` 改「Current rank #12 + 皇冠位图」，数字 `rankFigure`，颜色 `MiningRankEntry.placeColor`（1 黄 / 3 铜 / 其余主字），无名次时只画皇冠 + 箭头；新增文案 `mining_widgetsCurrentRank`（当前排名 / Current rank）、`mining_widgetsRankPlace`（第 {n} 名 / #{n}）。代币 / NFT / 邀请改 `LoopFilterChips`。
- 邀请：卡片改 r8 `card` 内边距 19；标签 11 / 400、码 `inviteCode`、链接 `codeSm`；按钮 `LoopButtonSize.medium`，分享带 `share` 图标。「邀请列表 / 邀请加成」已是 `LoopFilterChips`（0277），不动。
- 算力榜：分组改 `LoopTabStrip`；「我的名次」改 `IntelPowerCard`（同算力卡），名次数字 30 / 700 按名次着色；新 `IntelRankSectionHeading`（19 / 700 + 「ⓘ 榜单实时更新」，邀请中心卡自带实时点时不重复）；领奖台按 §5.15 重画（紫光用 RadialGradient 画、皇冠用 `assets/figma/crown-vector.svg`、头像环改描边不填充）；名次行 51 高 / 列 34 / 头像 36 / 副行 `progress` / 数值 `figureXs`。
- 英文溢出（S355 报的 b 类）：NFT 铸造页 folio 倒计时戳与挖矿规则页「Pending approval」戳给 `LoopFolioPrimary` 新可选参数 `stampWidthFactor`（默认仍 0.42），两页分别放到 0.6 / 0.5。

共享件只加了可选参数（汇报单列）：`LoopTabStrip.scaleDownLabels`（默认 false）、`LoopFolioPrimary.stampWidthFactor`（默认 0.42）。

## Consequences

- 旧断言改到稿值（无删除、无 skip）：s182 / s264 / s279 / s326（MEME 页签不再有喷点、行高 70、跑马灯 35 白 3%）、s269 / s325、s350b、s344、s321、s265d / s265 / s190 / s121c（算力卡、领奖台 62 / 54、线条皇冠）、s197_4。
- 新增 `test/s353b_figma_alignment_test.dart`（四页稿值 + 360 / 390）与 `test/s353b_shots_test.dart`（`LOOP_SHOTS=true` 才出图）。
- 未做 / 待定：邀请页稿里的「直接邀请 / 有效成员 / 二至五级」三格卡是 TF 64 没有的新结构，未加；「邀请列表」行仍是 `LoopRecordGroup` 卡片行（稿里只有邀请排行榜）；发射轨道折叠条、认购轮次行、360×640 NFT 签名抽屉三项英文溢出在 `launch_widgets.dart` / 旧 IDO 页（S358 / 隐藏页），未动。
