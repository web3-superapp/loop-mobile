# 0122 · 视觉二期：空态插图、发射台卡片、算力榜领奖台、聊天列表 Logo（S121b）

## Status

Accepted 2026-10-09。主代理设计（`LOOP/docs/modules/S121-visual-second-pass.md` §4），S121b 实施（设计兼实现）。
基线 `integration/v2` c5de8aa。不新增依赖、`pubspec.lock` 不变、路由清单不变。

## Context

用户 2026-10-09 真机反馈（`LOOP/docs/evidence/2026-10-09-device-feedback/`）：比上一版难看、字多图少、空态是一行字、
发射台太丑且标签截断、聊天列表没有社区 icon。诊断见设计 §0：身份没有图、空态是一行灰字、信息都用字说、
发射台复用了行情行（无卡片无进度环，已毕业标签被 14pt 高的盒子压扁）。

## Decision

本单分两轮：第一轮按设计 §4 做（卡片 + 进度环 + Lime chips），模拟器截图后主代理转来用户的 5 张 OKX 真机截图与
§1.1.1 十条规则，第二轮以 §1.1.1 为准覆盖第一轮中冲突的部分。下面「逐页计划」写的是**最终**落地的版本，
第一轮被推翻的地方在「偏离表」里写明。

### 共用件
- `LoopEmptyState`（`lib/widgets/loop_empty_state.dart`）+ `LoopIllustration` 八张线稿（`assets/illustrations/`，
  `pubspec.yaml` 登记，`check_illustrations` 校验 96 盒、stroke 1.7、无渐变/滤镜/文字/图片/Emoji、颜色只许
  Lime / Chalk / brass / copper，且 `LoopColors.brass|copper` 只许出现在主题与算力榜）。`LoopEmpty` 保留给内联。
  `CommunityStateBlock` / `LoopChainStateBlock` 新增可选 `empty:`，空态处传 `LoopEmptyState`。
- `LoopQuoteRow` + `LoopChangePill`（`lib/widgets/loop_quote_row.dart`）：OKX 行（圆 Logo 36、左 18 粗 / 14 灰、右 18 粗 /
  14 灰、最右固定 96×44 涨跌胶囊 riseSoft/fallSoft 底 + rise/fall 16 粗字），行高 72、无卡无分隔线；价格太长时
  `FittedBox` 缩小而不是省略号；连续 4 个以上前导零折叠为下标（`$0.000005601` → `$0.0₅5601`，朗读仍是全数）。
- `LoopSegBar` 一律改 OKX 筛选样式：未选中是字、选中是实心深灰胶囊（`LoopColors.line` 面）、字 14；可选 `icons`。
  `LoopSeg(quiet: true)` 同款，独立使用的 `LoopSeg` 默认不变（表单里的单选仍是原样）。分段页标题下的指示条
  Lime → Chalk。
- `LoopUnreadBadge` 加 `color`（默认仍是红），聊天行用 Lime。
- `LoopColors.brass` / `copper`：只用于奖牌与插图。
- `communityFacesProvider`（`lib/features/community/community_faces.dart`）：社区首页聚合与目录页读到的
  `logoRef` / 简介按 `communityId` 记在内存（随账号清空），聊天列表与算力榜按 id 取脸；取不到才回到按 id 的首字母块。

### 页面
- 聊天：头部「头像 40 + 整宽搜索框（→ `/chat/search`）」，右下 Lime 56 圆「发起」（同一个
  `ChatCreateMenuButton`，`floating: true`，key 不变）取代右上「+」；chips 全部/社区/好友带 chat/community/users
  图标；社区频道行用 `CommunityLogo(logoRef)`；无消息副行 = 社区简介首句或「还没有人说话」；未读 Lime；时间 11px；
  无会话与筛选为空用 chat 插图居中空态（无会话带「找朋友」）。
- 发射台：chips 带图标（新发 launch / 热门 chart / 快打满 target / 已毕业 graduate）；「新发 / 热门」下有「快打满」
  横滑 hero（220×120，Logo 48 + 进度环 44，最多 5 张，取自服务端 `graduating` 列表，没有不画）；列表为 OKX 行：
  Logo 36 圆 · 代号 / 市值 · 价格 / 1h 涨跌（色字）· **进度胶囊**（96×44，limeSoft 填充到进度、Lime 百分比；已毕业为
  满填充 + 毕业帽 +「已毕业」）；列表底不画「没有更多」；空态 launchpad 插图 +「创建第一个」。
- 情报 · 算力榜：chips 带图标；「我的名次」一行胶囊（头像/社区 Logo 26 +「第 2 名 · 值」，榜空且无名次时不画）；
  前三名领奖台（第一居中、多一顶皇冠、面更亮；奖牌 Lime / brass / copper，Logo 56）；第 4 名起行（名次 13 灰 +
  Logo 36 + 名字 + 「权重 x」小胶囊 + 数值）；人数与演示持仓说明并入来源行 ⓘ；榜底不画「没有更多」；空榜用 rank 插图
  （推广榜带「去邀请」→ `/profile/referral`）。
- 情报 / 行情：行情行 = `LoopQuoteRow`（价格不再着色，涨跌进胶囊）；活动卡去描边、箭头改灰；列表底不画「没有更多」；
  自选空态 watchlist 插图 +「去主流看看」；chips 带图标（自选 star / 主流 globe / MEME launch / 社区代币 community）。
- 广场：「全部 / 我加入的」带 compass / check 图标，所有 chips 为深灰胶囊；「我加入的」空态 holders 插图；语音房空态
  voice-room 插图 +「还没有人开播」+「去社区看看」（切回社区段）。
- MEME 代币页：顶部 Logo 44（按 id 取稳定底色）；图表 / 持有者 / 成交空态为 compact 插图。代币详情：Logo 32 → 44，
  成交空态 compact 插图（图表空态归 S121a）。
- 钱包：四键改 56 实心 Lime 圆 + Ink 图标 + 下方 13 字（关闭的键保持灰圆）。
- 搜索：空输入与无结果用 search 插图（只改了 `CommunityStateBlock` 的 `empty:` 一处，避开 S121a 的改动区）。

## Consequences

- 与 S121a 的合并点：`intel_rank_board.dart` 用本地 `intelMiningProvenanceDetail(snapshot)`（S121a 的
  `miningProvenanceDetail` 合并后可替换）；`search_screen.dart` 只加了一个 `empty:` 参数；`MiningDemoHoldingsNotice`
  本单已不再引用。
- harness：`check_illustrations` 新增；群聊行检查把 `avatar: LoopInitialsAvatar(` 放宽为 `LoopInitialsAvatar(` 并要求
  `loopCommunityIdForChannelCid(cid)` 与 `CommunityLogo(`；聊天页 `ChatCreateMenuButton()` 放宽为 `ChatCreateMenuButton(`。
- 「没有更多」在行情 / 算力榜 / 发射台已移除（`MarketListEnd` 现在只留 12 的空白）。
- 不新增依赖、不改 lockfile、不改路由。

## 逐页计划（先写计划、对照通病自检，再写代码）

每页六行：色 / 字 / 布局 / 记忆点 / 删掉什么 / 自检。

### P0 · 空态组件 `LoopEmptyState` + 八张插图
- 色：插图 Lime 主笔画 + Chalk 58%（= text3）次笔画；领奖台插图的二、三名台阶用 brass / copper；页面底色不变。
- 字：标题 16 / 600（`LoopType.titleLg`），一句 13 text2（`LoopType.bodySm`），居中；不加第二句。
- 布局：插图 96（compact 64）→ 16 → 标题 → 6 → 一句 → 20 → 主按钮；页面级占内容区约一半高度并垂直居中，分段级距上 32。
- 记忆点：插图本身（每种空态一张，不复用通用 info 图标）。
- 删掉什么：旧 `LoopEmpty` 的左上角 17px info 图标 + 两行 11px 灰字（旧组件保留给内联场景）。
- 自检：线稿统一 stroke 1.7、圆头圆角、无渐变无阴影无文字；不是「卡片里放图标」，没有外框。

### P1 · 发射台（MEME · 发射台段）
- 色：卡片 `card` 面 + `line` 1px，圆角 16；Lime 只出现在进度环弧、已毕业实心圆与「创建代币」；涨跌 rise/fall。
- 字：名称 16/600、`$SYMBOL` 胶囊 11 text3 描边、价格 14 tabular、1h 涨跌 12、副行 13 text2；全卡只有这几档。
- 布局：搜索 + 创建 → 带图标 chips → 「快打满」横滑 hero（220×120，Logo 48 + 进度环 44）→ 卡片列表（Logo 56 / 两行字 / 环 40）。
- 记忆点：进度环（列表和 hero 同一个环，已毕业为实心 Lime 圆 + 毕业帽）。
- 删掉什么：行底 2px 进度条、被压扁的「已毕业」标签、「外盘」字样、「没有更多」。
- 自检：卡片之间只有间距没有阴影；不加 eyebrow、不加编号；hero 只在「新发 / 热门」出现，避免与「快打满」列表重复。

### P2 · 情报 · 算力榜
- 色：第一名 Lime、第二 brass `0xFFD9B36A`、第三 copper `0xFFB87B5A`（只用于奖牌）；行无卡。
- 字：领奖台名字 14、数值 figure 15；行名次 13 text3、名字 15、数值 13 tabular；「权重 x」11 小标签。
- 布局：chips → 一行「我的名次」胶囊（头像 24 + 「第 2 名 · 476,359」）→ 三张等高卡领奖台（第一名居中高 16）→ 第 4 名起行。
- 记忆点：三甲领奖台（本批唯一的大块）。
- 删掉什么：「我的名次」大卡、「含演示持仓」横幅（并入来源行 ⓘ）、「N 人有算力 ·」（并入 ⓘ）、每行数值下的「算力」二字。
- 自检：奖牌用实心小圆 + 名次数字，不用 Emoji 奖牌；领奖台三卡同圆角同描边但第一名描边 Lime，层次靠高度不靠阴影。

### P3 · 聊天列表
- 色：未读角标 Lime 底 Ink 字；其余保持 Stream 行。
- 字：标题 15、副行 13、时间 11。
- 布局：社区频道左侧 `CommunityLogo`（logoRef 来自社区首页聚合 joined / owned / discover 与广场目录的已读缓存，取不到才首字母）；私聊对方头像；小群 `users` 图标块。
- 记忆点：一列有图的会话（社区 Logo 与头像）。
- 删掉什么：社区行的首字母块、「还没有消息」（改为社区简介首句，没有则「还没有人说话」）、红色未读角标。
- 自检：chips 带图标（全部 chat / 社区 community / 好友 users）；无会话空态用 chat 插图 +「找朋友」。

### P4 · 广场 / 行情 chips 与空态
- 色、字不变；chips 左侧 16px 图标（选中 Ink、未选中 text2）。
- 布局：行情 自选 star / 主流 globe / MEME launch / 社区代币 community；广场 全部 compass / 我加入的 check。
- 记忆点：无新增（广场的记忆点仍是俱乐部卡片）。
- 删掉什么：语音房空态的一行灰字 → voice-room 插图 +「还没有人开播」+「去社区看看」；自选空态 → watchlist 插图 +「去主流看看」。
- 自检：图标与文字同色同基线；不给排序 chips 加图标（字已经是 2–4 个字，图标反而挤）。

### P5 · 代币页（MEME 代币页与代币详情）
- 色、字不变；顶部 Logo 44（代币详情 32 → 44，MEME 代币页保持 44）。
- 布局：图表空态 chart-empty 插图（compact）、持有者空态 holders 插图、动态 / 成交空态 chart-empty（compact）。
- 记忆点：沿用页面已有的价格大字。
- 删掉什么：「只画有成交的时段，空时段不会补 0」这类工程说明移进来源行 ⓘ（MEME 页）；代币详情的图表空态归 S121a。
- 自检：compact 插图 64，不抢价格大字。
