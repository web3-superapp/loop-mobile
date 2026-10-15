# 0177 · 广场新增「动态」时间线段（S187-4-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` ec93084（含 0173 ~ 0176、0178）。来源：主仓库
`docs/35-代币列表与代币页设计稿-2026-10-15.md` 与 `body2.html`「动态（广场）」手机框（HTML 结构即规格）。
配套 loop-api 决策 0143（S187-api-b：`GET /v2/square/feed`、`POST /v2/square/posts`、`DELETE /v2/square/posts/{id}`、
`PUT|DELETE /v2/square/posts/{id}/like`，能力位 `squareFeed`）。路由数不变；不新增依赖、字体与图标；签名出口不变。

## Context

设计稿「动态」= 全球 / 已关注 下划线 tab + 帖子流：每条是头像 + 名字 + 类型徽标 + 时间、一行代币报价、正文、♡ 计数；
官方日报置顶并装在 `.recap` 卡里、超三行折叠。原广场只有「社区 / 语音房」两段。

## Decision

### 1. 能力位与段序
- `LoopV2CapabilityId` 末尾新增 `squareFeed`（与 loop-api OpenAPI 第 35 个 id 同序）；它和 `launch2` / `testnetFaucet` 一样是
  **可省略** id：后端未发布时客户端补一行 `unavailable` / `SQUARE_FEED_CAPABILITY_ABSENT`（`DioLoopV2MetaRepository.squareFeedAbsentReasonCode`）。
  `check_harness.py` 的能力位清单同步。
- `squareFeedVisible(ref)` = `squareFeed` 投影 `isUsable` 且 `squareFeedGatewayProvider` 不是 unavailable。
  为真时广场段序 **动态 / 社区 / 语音房**（`SquareScreen.feedSegments`），否则保持原「社区 / 语音房」，页面与现状完全一致。
  语音房空态「去社区看看」改用 `SquareScreen.communityIndex(feed:)` 选回社区段。段记忆键仍是 `square`。

### 2. 数据层（照 0176 best-trades 写法）
- 端口 `lib/features/square/square_feed.dart`：`SquareFeedGateway`（缺省 `UnavailableSquareFeedGateway`）+ 模型
  （`SquareFeedPost / Author / Token / Page / Like / TokenRef`）+ `SquareFeedController`（`LoopChainReadController`，按 scope 的 family，
  保留答案；`loadMore` 用 cursor 追加并按 postId 去重；`toggleLike` 乐观更新、失败回滚；`delete`；`insertCreated` 插在置顶之后）。
- V2 适配器 `integrations/backend/v2/square/loop_v2_square_feed_api.dart`：Bearer + 会话 Dio；读用 `readErrors`，写用本文件
  `writeErrors`（含 `409 PROFILE_ACTIVATION_REQUIRED` / `IDEMPOTENCY_CONFLICT`、`422 VALIDATION_FAILED`、`429 RATE_LIMITED`）。
  `PROFILE_ACTIVATION_REQUIRED` 没有对应的 feature kind，转成 `permissionDenied` + `reasonCode` 交给发帖弹层。
  每次点赞 / 删除各生成一个新 UUIDv4 `Idempotency-Key`；发帖的键在弹层里按「文本 + 代币」保留，同内容重试重放，改了内容换新键。
- `main.dart` 覆盖 `squareFeedGatewayProvider`；`main_preview.dart` 不覆盖（预览不接生产，段不出现）。
- 宽松解码：信封必须有 `items` 列表与 `observedAt`；`scope` 若有必须等于请求的 scope，cursor 形状错 = invalid。
  行内：非 UUID postId、未知 kind、非 system 缺作者、opinion / system 缺正文、likeCount / likedByViewer 不对 → 丢该行；
  未知键忽略；重复 postId 只留第一条；`pinned` 只认 system；置顶帖排在最前（最多 3 条）。
  报价里读不懂的十进制当 `null`（不当 0）；`logoUrl` 只取 LOOP 自己的 `/v2/media/{id}.webp` 路径并从本构建后端源加载；
  `avatarRef` 只接受 `avatar:media|preset/…`；`event` 只保留非空字符串值。

### 3. 段内版式（`SquareFeedSegment`，key `square-feed`）
- `LoopStreamPage(listing, embedded, tabPage)`，`filters` 固定在上：`MarketTabBar`（chalk 下划线，key `square-feed-tab-全球 / 已关注`）
  + 右侧次级 `LoopButton('发帖', icon: plus)`（key `square-feed-compose`）。设计稿右上「≡」筛选键：没有筛选项，**不画**。
- 帖子行 `SquareFeedPostRow`（`.post`：内距 14/16、底部 line）：
  - 头像 36（`LoopProfileAvatar`，avatarRef 按公开资料规则，null 画首字母）；官方帖画 card2 圆底 + 扁平品牌标（不用 lime 底，守 lime 预算）。
    名字 = alias，否则 LOOP ID；官方帖「LOOP 官方」。点头像 / 名字进公开资料页。
  - 徽标：opinion `LoopBadge(mute)`「观点」；buy `launch`「买入」；claim `up`「领奖 N USD1」（无金额时「领奖」）；
    graduation `launch`「毕业」；system 仅 pinned 时 `mute`「置顶」。
  - 时间：设计稿的紧凑相对时间（`43s / 12m / 5h / 3d`，30 天后写日期），figure 11 text3。
  - 报价行（缩进 46）：logo 28 圆（`MemeLogo`）+ symbol + 价格（figure）+ 1h 涨跌（`LoopPriceMove` 色，`loopSignedPercent`）。
    buy 行改为「买入 $X」+「市值 $Y」（当前市值，后端未存成交时市值，所以不写「以…市值」）；claim 行为「第 N 轮」+「权重 N%」。
    任何为 null 的字段都不画、不写 0；一项都没有时整行不画。点报价行进 MEME 代币页或 MEME v2 实例页。
  - 正文 ≤ 500 字，`SquareFeedText`：`https://…` 与「域名/路径」标成 lime 下划线，点击复制链接并 toast「已复制链接」，不开浏览器。
  - system 帖正文放在 `LoopRecordCard(margin: 0)` 里（首行为标题），超过三行折叠，lime「展开」。
  - 底部 ♡：sprite 已有 `react-heart`（0121），**未新增图标**；点赞后图标与计数变 lime。点击乐观 +1 / −1，服务端回答的计数为准；
    失败回滚并 toast「没有点上赞 / 没有取消点赞，请稍后再试」。
- 列表：首屏骨架；不可用 / 读失败 `LoopInlineUnavailable`（服务端不可用时无重试键）；空态 `LoopEmptyState(chat)`「还没有动态」；
  下拉刷新（`onRefresh`）；`LoopLoadMoreSentinel` 按 cursor 续读，下一页失败画内联重试；60 s 轮询（`squareFeedPollInterval`，只刷新已有行）；
  `LoopFreshnessStrip` + `LoopProvenanceLine(['LOOP'])`。
- 自己的帖（作者 LOOP ID = 我的 `profileControllerProvider` LOOP ID，或本次运行发出的帖）长按 → 确认弹层 → `DELETE`；404 视为已删。

### 4. 发帖弹层（`SquareFeedComposer`，`showLoopSheet`）
- 多行输入（4–8 行），脚注计数 `n/500`（按 code point，与服务端一致），超出标红并禁用「发布」。
- 可选代币：本次运行打开过的 MEME 代币（`squareRecentTokensProvider`，最多 8 个，只在内存，账户切换清空；
  `MemeTokenScreen` 读到生产适配器的已上链代币时记录），`LoopSeg(quiet)` 胶囊，含「不带代币」；没有就不画这一栏。
- 「发布」是弹层唯一满 lime（`LoopButton(primary, block)`）。成功后关闭、插入全球时间线、记为自己的帖、toast「已发布」。
- 错误文案：`SQUARE_POST_RATE_LIMITED`「发得太快了，稍等一分钟再发」、`_TEXT_EMPTY`「写点内容再发布」、
  `_TEXT_TOO_LONG`「最多 500 字，删减一些再发布」、`_TEXT_INVALID`「内容里有不支持的字符，删掉后再发布」、
  `SQUARE_TOKEN_REF_INVALID`「引用的代币读不到了，换一个或不带代币」、`PROFILE_ACTIVATION_REQUIRED`「先完成开户设置再发帖」；
  离线 / 结果未确认 / 幂等冲突 / 不可用各有一句。

## Consequences

- 可见变化（待主代理真机验收）：后端发布 `squareFeed=available` 后广场第一段出现「动态」；未部署 / 关闭时广场与之前一致，无需发版。
- `squareRecentTokensProvider` 是运行内便利数据，不落设备、不是账户资源。

### 未按清单做的点
- 筛选图标键：没有筛选项，按清单「无筛选项就不画」不画。
- 代币引用只来自「本次打开过的 MEME v1 代币」：搜索结果的稳定 id 是 CAIP `assetId`，不是 `memeTokenId / instanceId`，不能当 `tokenRef`；
  MEME v2 实例页本批未接入记录。
- 心形用现有 sprite `react-heart`，未新增 `i-heart.svg`，图标计数不变（71）。
- 买入帖的「以 $3.40M 市值」改写为「市值 $3.40M」：后端只有当前市值（loop-api 0143 §6.2）。
- `MarketTabBar` 两个 tab 左对齐（共用部件），没有改成设计稿的各占一半。

## Verification

- `bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`。
- 新增 `test/s187_4_square_feed_test.dart`：能力位可用时段序动态 / 社区 / 语音房、不可用或无适配器时回落两段、后端省略 id 读 unavailable；
  五种 kind 的徽标文字与色系、system 非置顶无徽标、置顶在前且在 record card 里、时间线无满 lime；报价行 null 不画且无 0；
  点赞乐观 +1 → 失败回滚 + toast、服务端计数为准；空态 / 不可用；链接识别；发帖弹层唯一满 lime =「发布」、计数 n/500、
  429 文案、同内容重试同一键、成功插入、长按自己的帖删除；六个错误码文案；codec 置顶在前 / 丢坏行 / 忽略未知键 / 头像与 logo 规则 /
  报价坏数字为 null / scope 不符与缺 items 为 invalid。
- `test/loop_v2_meta_repository_test.dart`（含「client capability enum equals the frozen contract enum」，对照 loop-api 主检出 OpenAPI 35 个 id）、
  `test/s7_api_contract_test.dart` 计数改为 35 并新增 squareFeed 两例。
- 回归：广场 / 导航 / 群友买入 / MEME 相关测试与 `test/loop_assets_test.dart`。未起模拟器、未做真机验收。
