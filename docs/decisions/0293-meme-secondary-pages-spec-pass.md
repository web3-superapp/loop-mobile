# 0293 · MEME 二级页按 docs/58 §9 扫一遍（S370a-mobile）

## Status

Accepted · 2026-11-05（S370a-mobile，基于 integration/v2 6fbcb2e1 = TF 68，放 TF 69）。来源：用户 11-05 裁决「二级页按稿规则扫一遍、不等需求方出稿」。规范 `docs/58` §9（主代理裁决）为准、§1–§5 作细节参考；度量语言沿用 0277（底座）与 0278 / 0279 / 0280（九页）。**只改视觉度量**：不重排、不增删功能、不改文案（ARB 未动）、不改路由与 key、不改 `lib/widgets/` 与 `lib/app/` 共享件和主题 token。MEME 首页（launchpad / atmosphere / hero / list / overview）与旧 IDO 不在范围。

## Context

需求方只画了九页，MEME 二级页（详情、交易面板、奖励、K 线全屏、NFT、签名、发射申请 / 我的项目、曲线 MEME）没有稿，按 §9 通用规则套；稿里没有对应件的标「类推」。0277 之后大部分字号、色、圆角已经经 token 吃到（`LoopType` / `LoopRadius` 旧名都映射到稿值），本批只处理页面里**本地写死、或选错档位**的度量。

页面对照表（现状 → 稿值）：

| 页面 / 件 | 现状 | 稿值 / 本批 | 依据 |
| --- | --- | --- | --- |
| 详情 · 分段（`Launch2InstanceTabs`） | 卡底紫色实心胶囊条（选中紫底白字 16 / 600），条 → 列表 12 | 一级文字 tab `LoopTabStrip`（选中白 16 / 600 + 满格 2px 黄线、未选次字、通栏 1px 白 10 %），条 → 列表 16；per-tab key `launch2-tab-*` 不变 | §9.4 一级分段、tab 条 → 列表 16 |
| 详情 · 页头头像 | `MemeLogo` 44 圆角方 | 44 圆 | §9.4 代币头像 44 圆（类推） |
| 详情 · 阶段胶囊（`_StageCapsule`） | r8 紫底 / 灰底，阶段字 12 / 600，倒计时 14 / 600 | r4，进行中 `yellowSoft` 底黄字、其余白 8 % 底次字（同首页 `Launch2BoardStage`），阶段字 `stageTag` 11 / 400，倒计时 `figureXs` 13 / 600 | §4 阶段胶囊 r4、§9.2 `stageTag` |
| 详情 · 价格 | `statFigure` 28 / 700 | `heroFigure` 30 / 700 | §9.2（类推算力值） |
| 详情 · 内盘进度卡标签 | `body2` 16 / 400 次字 | `eyebrow` 13 / 500 次字 | §5.14 算力卡标签（类推） |
| 详情 · 成交行（`_tradeRow`、`Launch2PublicTradeRow`） | 上下 9–10、无最小高、头像 28 + 间距 6、主行 `body2` 16、右值 `figure` 16 / 600 + `figureSm` | 51 高（上下 6）、头像 36 + 间距 12、主行 `body1` 14、右值 `figureSm` 14 / 600 主字 + `caption` 副值、无线 | §9.4 持仓 / 榜单行（类推） |
| 详情 · 「只看我的」勾选框 | r6 | r5 | §4 标签 5（类推） |
| 内盘交易面板 | 买 / 卖胶囊 → 输入框 14 + 8 = 22；限额标签 `body2` 16 | 胶囊 → 内容 12；限额标签 `eyebrow` 13 / 500 | §9.4 胶囊 → 内容 12；§5.14（类推） |
| 外盘交易面板 | 付 / 得、滑点胶囊间距 6 | 8 | §9.4 胶囊间距 8 |
| LoopDynamic 本轮卡 / 不可用块 / 奖励页 / NFT 页 | 来源行、失败行、按钮右边距 16（左 20） | 左右都 20 | §9.4 页边距 20 |
| 签名 · NFT 确认抽屉、步骤条下「已刷新」行 | 左右 16（抽屉标题是 20） | 20 | §9.4 页边距 20（类推抽屉） |
| 发射申请 · 分组标题 | `title`（= `body1` 14 / 500） | `headlineSm` 16 / 700 | §9.2 小区块标题（类推热门社区） |
| 发射申请 · 开售时间抽屉 | 说明行、确定按钮左右 16 | 20 | §9.4 |
| 发射申请 · 固定回购地址框 | r10 | r12 | §9.4 搜索框 / 输入框 12（类推） |
| 我的项目列表 | 头像 36 圆（字面量） | 保持 36 圆，改引用 `Launch2SecondaryMetrics.recordFace`。试过 44（代币行类推）：`LoopRecordRow` 的状态徽章不可伸缩，英文「Pending review」类徽章在 390 宽溢出 3px，故按持仓行 36 类推 | §9.4 持仓头像 36（类推） |
| 我的项目详情 · 页头 | 头像 56 圆角方，页头 → 第一块 16 | 44 圆，12 | §9.4 代币头像、标题区 → 第一块 12（类推） |
| 部署进度 · 事件行 | 上下 8 | 上下 6 | §9.4 持仓 / 榜单行上下 6（类推） |
| 曲线 MEME 代币页 | 介绍、价格、持仓、进度条、计数行、底栏、分享抽屉左右 16；成交行 52 高、左右 16 | 20；成交行 51 高、左右 20 | §9.4 页边距 20、持仓 / 榜单行 51（类推） |
| 曲线 MEME 交易抽屉 | 左右 16；买 / 卖胶囊 → 内容 14；滑点胶囊间距 6 | 20；12；8 | §9.4 |
| 曲线 MEME 阶段标签（`memeTagDecoration`） | r8 | r4 | §4 阶段胶囊 r4 |
| 曲线 MEME 指标卡注释 | `captionSm` + 写死 `fontSize: 12` | 去掉写死字号（`captionSm` 本身 12） | token 化 |
| 曲线 MEME 搜索入口 | 本地 44 灰底 r12 无描边、图标 16、占位 16 | 共享 `LoopSearchEntry`（44、r12、1px `cardEdge`、图标 20、占位 15 / 500），key `meme-search-entry` 不变 | §9.4 搜索框 44 r12 |

已合规、未动（逐项看过）：钱包持仓行 `Launch2WalletRows` / NFT 格（0280 已按 §5.13 对齐，`LoopQuoteRow` 共享件）；`LoopRecordCard` / `LoopRecordGroup` / `LoopKeyValue` / `LoopButton` / `LoopSegBar` / `LoopEmptyState` 等共享件（0277 已到稿值）；全屏 K 线（无本地度量）；最近成交 / 活动 / NFT 铸造（只是数据与逻辑）；NFT 卡与勋章（插画件，非列表规格）；`Launch2LaunchCapsule`（0279 已按发射键 30 r6）。

## Decision

- 新增 `lib/features/launch2/launch2_secondary_metrics.dart` · `Launch2SecondaryMetrics`：把类推值集中命名（`recordRow` = `LoopRowHeight.holdings` 51、`recordInset` 6、`recordFace` = `LoopRowHeight.holdingsAvatar` 36、`faceGap` 12、`tokenFace` 44（详情页头、项目详情页头）、`chipToContent` = `LoopSpacing.chipGap` 12、`chipSpacing` = `LoopSpacing.chipSpacing` 8），各页引用它而不是散落字面量。
- 按上表逐页改；所有 key、文案、结构、路由不变；`Launch2InstanceTabs` 公开 API 不变（新增静态 `listGap`），`_InstanceTab` 私有类删除（由 `LoopTabStrip` 的格子代替）。
- 选中态全部按 §9.3 改白 / 黄线，详情页不再有紫色实心选中底。

需要共享件才能满足、本批未做（留给主代理）：

1. `LoopRecordRow` 行高仍是 0229 的 72 / 80（`LoopSpacing.rowMin` / `rowMinWithSub`）。二级页里用它的列表（我的项目、NFT 权益、发射申请入口、曲线代币页信息行）按 §9.4 应为代币行 71 / 功能行 56；要改得动共享件或加 `height` 参数（同 0280 给 `LoopQuoteRow` 加的那种）。
2. `LoopLabel`（二级页区块标题，`Launch2SectionLabel` 也包它）字阶是共享件定的；§9.2 区块标题 19 / 700 是否套到二级页小节，需主代理定一次再改共享件。
3. `LoopFolioPrimary`（NFT 页、曲线代币页的状态卡）与 `LoopSheetHeading`（抽屉标题 `heading` 22 / 700，稿无对应）仍是旧形，稿没有对应件，未动。

## Consequences

- 改动文件：`lib/features/launch2/` 下 `launch2_instance_parts.dart`、`launch2_instance_screen.dart`、`launch2_trade_panel.dart`、`launch2_pool_trade_panel.dart`、`launch2_dynamic_pool_widgets.dart`、`launch2_dynamic_rewards_screen.dart`、`launch2_nft_screen.dart`、`launch2_signing.dart`、新 `launch2_secondary_metrics.dart`；`creator/` 下 `launch2_create_screen.dart`、`launch2_creator_widgets.dart`、`launch2_projects_screen.dart`、`launch2_project_screen.dart`、`launch2_deployment_screen.dart`；`lib/features/meme/` 下 `meme_token_screen.dart`、`meme_trade_panel.dart`、`meme_design.dart`、`meme_launchpad.dart`。ARB、view model、gateway、codec、路由表未动；lockfile 未变。
- 测试：新增 `test/s370a_secondary_spec_test.dart`（类推常量；详情分段 = `LoopTabStrip` + 无紫底 + tab 字阶 + 20 起点；页头 44 圆 + 阶段胶囊 r4 / 11 / 400 黄；价格 30 / 700；成交行 51 / 14 / 14 / 600 / 20 起点；LoopDynamic 重试按钮两侧 20；NFT 确认抽屉两侧 20；固定回购地址框 r12；曲线阶段标签 r4）。需要整页 harness 的三页把断言加在已有测试里：`s135_launch2_creator_pages_test.dart`（我的项目列表头像 36 圆、项目详情页头 44 圆）、`s117_meme_launchpad_test.dart`（搜索入口 = `LoopSearchEntry`、高 44）。
- 旧断言：无需改动（无删除、无 skip）；只在 s135 / s117 追加了上述度量断言。门禁：`dart format --set-exit-if-changed lib test` 0 改动、`flutter analyze` 0、`scripts/l10n/merge.py --check` 0；相关 131 个测试文件 + 全量 `flutter test`（工作树）6450 过 / 310 跳过 / 0 失败。
