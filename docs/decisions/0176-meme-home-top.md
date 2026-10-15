# 0176 · MEME Tab「经典」段顶部改为设计稿「首页」版式（S187-3-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 25d303c（含 0173 列表 A、0174 代币页 B、0175 我）。来源：主仓库
`docs/35-代币列表与代币页设计稿-2026-10-15.md` 与 `body2.html`「首页（MEME Tab 顶部）」手机框（HTML 结构即规格）。
配套 loop-api 决策 0142（S187-api-a：`GET /v2/meme/best-trades?window=7d`）。
只改 MEME Tab「经典」段（`MemeLaunchpadSegment`）列表之上的部分；「v2 发射」「已毕业」两段、列表 A 行、
快打满横滑卡（用户裁决 M1 不动）、来源行、空态版式不动。路由数不变；不新增依赖与字体；签名出口不变。

## Context

设计稿首页 = 余额 + 满 lime「充值」、「每周最佳交易」横滑卡、「☆ 自选 / 代币 / 已毕业」下划线 tab、一排筛选胶囊，
然后是列表 A。原「经典」段顶部是一行「搜索框 + 满 lime 创建代币」再接子段胶囊。

## Decision

### 1. 顶栏
- `LoopSegmentedTabPage` 三段（v2 发射 / 经典 / 已毕业）与 0 / 2 段的「我的项目 / 发起」不变。
- 「经典」段（v2 Tab 第 1 段）的顶栏新增两枚字形键：搜索（key `meme-search-entry` → `/search`）与创建
  （key `meme-create-entry` → `/meme/create`，读取被关闭时禁用）。设计稿的搜索就在顶栏；这样段内不再有工具行。
- `MemeLaunchpadSegment` 新增 `toolsInTopbar`（缺省 false）与 `onOpenGraduated`（缺省 null）。非 v2 Tab（发射台 / 行情）
  仍画原工具行，但「创建代币」改为次级 `LoopButton`（不再满 lime），让「充值」成为同屏唯一满 lime。
  列表空态的「创建第一个」同理改为次级。

### 2. 余额块（`.balance`，`MemeBalanceBlock`，key `meme-balance`）
- 左：钱包总资产，`LoopType.figureXl`（28，最接近设计 32 的 figure 档，不新增字号）700，小数部分 `figureLg` text3
  （设计 `<small>.40</small>`），key `meme-balance-figure`。
- 来源只认钱包自己的读：`walletDirectoryControllerProvider` 的活跃钱包 → `walletBalancesControllerProvider(walletId)`
  的 `netWorth`（只读引用钱包 provider，未改 `lib/features/wallet/`）。
  - `LoopNetWorthValued(partial: false)` 才画金额；
  - `partial: true` 画「--」+「N 项资产暂无价格，总资产暂不显示」（AGENTS 20 / 25：部分和不能当总资产）；
  - `LoopNetWorthUnavailable` 画「--」+ 服务端 reasonCode 文案；
  - 钱包模块 / BSC 读关闭、读失败、没有钱包同样「--」+ 原因（key `meme-balance-reason`）；永远不画 0。
  - 读取中画骨架块（key `meme-balance-loading`）。
- 下一行「+$12.08 · 24 小时」（key `meme-balance-change`）只在 `change24h` 为 `LoopNetWorthChangeAvailable` 时画，
  金额用 `LoopPriceMove` 的 rise / fall（0117）；`stale / derived / proxied` 的质量标记接在后面。
- 隐藏余额：跟随 0175 的设备偏好 `loop.display.v1.hide_balance`，直接读 `loopBalanceVisibilityProvider`
  （`lib/app/loop_balance_visibility.dart`，S187-5 已合入；本批不碰 SharedPreferences，`check_balance_visibility_store_contract`
  不变）。fail-open：未读到 / 读失败 = 显示。隐藏时金额与 24h 都画「****」；「我」里切换后同一运行内即时生效。
- 右：满 lime「充值」`LoopButton(primary)`（key `meme-top-up`，最小宽 120）。`testnetFaucet` 可用（`testnetFaucetVisible`）
  且活跃钱包是内嵌钱包、id 规范时，打开现有「领取测试币」抽屉（0154/0158，领取成功后重读余额）；否则进钱包的
  收款页 `WalletRoute.receive(walletId)`（与 0164 发射台「去充值」同一去处；收款即充值入口）。

### 3. 每周最佳交易（`MemeBestTradesStrip`，key `meme-best-trades`）
- 新端口 `MemeBestTradesGateway`（`meme_best_trades.dart`，缺省 Unavailable）+ `MemeBestTradesController`
  （`LoopChainReadController`，保留答案）；V2 适配器 `loop_v2_meme_best_trades_api.dart`
  （`GET /v2/meme/best-trades?window=7d`，Bearer、带会话 Dio，读错误表沿用 meme 读）。
- 宽松解码：信封必须有 `items` 列表与 `observedAt`（`window` 若有必须是 `7d`），否则 invalid；行内未知键忽略，
  读不懂的行（非 UUID 的 `memeTokenId`、非正或非字符串的 `realizedUsd1`、缺 user/token）丢弃，不拒整份；
  重复（用户, 代币）只留第一条；最多 10 条。`user.avatar` 只接受 `avatar:media/…` / `avatar:preset/…`，否则当 null；
  `logoUrl` 只取 LOOP 自己的 `/v2/media/{id}.webp` 路径并从本构建后端源加载（同 meme codec）。
- 读取中 / 空 / 404 / 503 / 解码失败 / 能力关闭：整段不画（不占位、不报错、不影响下面的列表）。
- 卡：`LoopLabel('每周最佳交易')` + 横滑 `LoopRecordCard`（170 宽，内距 10/12，间距 10）：上行头像 24
  （`LoopProfileAvatar`，按公开资料头像规则）+ 名称（alias，空则 LOOP ID）+ Line 分隔线；下行代币 logo 26
  （`MemeLogo`，圆角 `LoopRadius.toolValue` 13 = 半径）+ lime figure 15/700「+$116,807.57」。
  点卡 → 该代币页；点上行用户 → `userProfileLocation(userId)` 公开资料页。
- `LoopRecordCard` 新增可选 `margin`（缺省 = 原 16/0/16/card 间距，其它调用方像素不变），横滑卡传 0。
- 刷新：下拉列表时，若上次读取已满 60 s（`memeBestTradesRefreshFloor`）或没有答案，同时重读；服务端本身 5 分钟缓存。

### 4. 自选 / 代币 / 已毕业（`MemeHomeTabs`，`MarketTabBar` chalk 下划线，key `meme-home-tab-{label}`）
- 「代币」= 现有经典列表（默认选中）。
- 「已毕业」= v2 Tab 里 `select(2)` 切到第三段；非 v2 Tab 没有该段，改为选中经典「已毕业」子段（tab 也随之高亮）。
- 「自选」：`/market` 默认打开的就是行情的「自选」列表，所以画这个 tab，点了 push `/market`。
- 设计稿的「☆」不画：LOOP 不打印符号 / Emoji 字形，`MarketTabBar` 只有文字。

### 5. 筛选胶囊
- 仍是原 `LoopSegBar`（`LoopSeg(quiet)`）四个子段：新发 / 热门 / 快打满 / 已毕业（`MemeListTab`）。
- 设计稿的「最多人持有」「涨幅榜」没有服务端排序，不画；「内盘」没有单独的 tab，不画（新发 / 热门即内盘列表）。
- 筛选图标键：仓库里没有排序 / 筛选抽屉，不画。

### 6. 顺序
（非 v2 才有的工具行）→ 余额块 → 每周最佳交易 → 三 tab → 子段胶囊 → 快打满条 → 列表 → 来源行。

## Consequences

- 可见变化（待主代理真机验收）：经典段顶部出现总资产与满 lime 充值；有数据时出现最佳交易横滑卡；
  搜索与创建从段内工具行移到顶栏两枚字形键；「创建代币」/「创建第一个」不再是满 lime。
- 后端 S187-api-a 未部署时最佳交易整段不出现，部署后自动出现，无需发版。

### 未按清单做的点
- 充值兜底去处是钱包收款页而非钱包首页：收款就是充值动作，且与发射台「去充值」一致。
- 「☆」字形、「最多人持有」「涨幅榜」「内盘」胶囊、筛选图标键：无字形规则 / 无数据源 / 无抽屉，不画。
- 设计 32 号余额字：取 figure 档最大的 `figureXl` 28，未新增字号。

## Verification

- `bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`。
- 新增 `test/s187_meme_home_top_test.dart`：余额缺来源画「--」+ 原因且无 0、钱包模块关闭、部分净值不算总资产、
  有值画 figureXl 金额 + rise 色 24h、隐藏偏好画「****」、同屏唯一满 lime =「充值」且无水龙头时进收款页；
  最佳交易 404 / 503 / 解码失败 / 空整段不画且列表照常、12 条只画 10 张 170 宽卡、lime 金额、点卡进代币页、点用户进公开资料；
  余额 → 最佳交易 → tab → 胶囊 → 行的纵向顺序、tab 与胶囊标签顺序、自选 → `/market`、已毕业 → 第三段 / 经典已毕业子段；
  codec 宽松解码（丢坏行、忽略未知键、头像与 logo 规则、≤10、非信封 invalid）。
- 回归：`s117_meme_launchpad_test`、`s136_launch2_user_test`、`s121b`、`s121c`、`s106*` 通过。未起模拟器、未做真机验收。
