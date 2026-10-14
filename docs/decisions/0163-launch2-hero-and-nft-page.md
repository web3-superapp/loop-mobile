# 0163 · 发射台顶部 Banner 与 NFT 铸造页「共识勋章」（S180-mobile）

## Status

Accepted 2026-10-14。基线 `integration/v2` 6f5eb19，与 loop-api S180（行上可选 `summary` / `links`）同批。
设计定稿：`docs/32-发射台Banner与NFT铸造页设计-2026-10-14.md`（主仓库）。
不新增依赖、`pubspec.lock` 不变、不新增字体与颜色 token；新增一条路由（清单 112 → 113）；无新请求路径。

## Context

需求方反馈发射台太简陋：要一个披露预告、活动、倒计时与进度的顶部 Banner；NFT 铸造要从项目页的一个按钮变成独立页面，
把权益、规则、我的持有和倒计时说清楚。

## Decision

### 1. 契约补充（S180-api）
- 列表行与详情 `instance` 上可选 `summary: string | null`（≤ 60 字）与 `links: string[]`。编解码把两者列为行的可选键
  （`rowOptionalKeys`，详情 `detailOptionalKeys` 同时包含）；缺失 / null / 非字符串 / 空串 / 超过 120 个码点的 `summary`
  一律读作无，`links` 只保留 `https` 绝对地址，任何异常都不让整行判无效。
- 模型 `Launch2InstanceRow.summary` / `links`。Banner 不显示 links，铸造页也不显示 links。

### 2. Banner `Launch2HeroPager`（`lib/features/launch2/launch2_hero.dart`）
- 插在 `Launch2ListSegment` scope=all 的 rows 顶部、`const SizedBox(height: 2)` 之前；scope=graduated 不画；
  无可展示行时整体不渲染，列表起始不变。只用已读到的第一页（`limit=30`，合并后的列表头 30 行）挑选，不发请求。
- 选行与排序 `launch2HeroRows`：`nft_sale` → `priority` → `public` 且 `soldBps ≥ 7000` → `upcoming`（按开售时间近到远），最多 5。
- 横向 `PageView`，不自动轮播、无入场动画；分页点（`launch2-hero-dots`）≥ 2 张才画；倒计时复用 `Launch2Countdown`，
  `onElapsed` 接列表 `reload()`；引线 `Launch2HeroFuse` 为 2 px 自绘（不用 `LoopProgressFill`：它在数值变化时有 300 ms 推进
  动画并在满格时闪一次，与「无动画、只重绘数字」冲突）。
- 点击：`upcoming` / `nft_sale` → `Launch2Route.nft`，其它 → 项目页。语义标签一句话（`launch2HeroSpokenLabel`）。

### 3. NFT 铸造页 `Launch2NftScreen`（`lib/features/launch2/launch2_nft_screen.dart`）
- 新路由 `launch2-nft`：`Launch2Route.nftPath = '/launch2/nft'`、`Launch2Route.nft(instanceId)`（`id` 查询参数，
  与项目页相同的 UUIDv4 校验，非法即 fail-closed、不发请求）；`app.dart` 挂载，`routes-manifest.json` 与
  `route_manifest.dart` 登记（prototypeOrder 126，sha256 重算），`check_harness.py` 计数 113 并把本页加入 `LAUNCH2_GATED_SURFACES`。
- 数据：`launch2InstanceControllerProvider(id)`，与项目页同一个 controller。
- 铸造：项目页原 `_buyNft` 的「确认表单 → `nft/prepare` → 签名出口」抽成 `launch2MintNft`（`launch2_nft_mint.dart`，返回
  `Cancelled / Refused / Signed`，stage mismatch 时自行重读），项目页与铸造页都调它；签名结果文案抽成 `launch2OutcomeText`
  （项目页 `_sign` 也用）。项目页行为不变（既有 S136 / S177 测试全过）。
- 勋章 `Launch2NftMedal`：`CustomPaint` 正圆，外环 2 px（brass / 灰），graphite 面，中心 `MemeLogo` 56，
  环上沿 ticker（mono，>8 字符省略），下沿 `#tokenId` 或「共识勋章」。
- 状态（`launch2NftView`，纯函数）与按钮（key `launch2-nft-mint`，`LoopButtonTone.brass`）：

| 状态 | 状态行 | 按钮 | 环 |
| --- | --- | --- | --- |
| upcoming | 开售倒计时 {倒计时}；下行「100 USD1 / 枚 · 发售 N」 | 开售后可铸造（禁用） | 灰 |
| nft_sale 未持有 | NFT 铸造中 · 剩 {倒计时}；已铸 N 枚 | 铸造 1 枚 · 100 USD1 → `launch2MintNft` | brass |
| nft_sale 已持有 | 同上 | 已持有 · 每地址 1 枚（禁用） | brass + `#id` |
| snapshot_pending | 铸造已结束 · 名单生成中 | 持有：等待名单发布；未持有：铸造已结束（禁用） | brass |
| priority / public / graduated | 提前购进行中 · 剩 … / 内盘已开放（零持有开盘：发售结束时无人铸造，已直接进入公开轮）/ 已毕业 | 去项目页交易 | 持有 brass，否则灰 |
| 钱包未激活（无活动钱包且无 viewer） | — | 激活钱包后可铸造（禁用） | — |
| tradingHold（0161） | `Launch2TradingHoldBanner` + 按钮上方 `Launch2TradingHoldLine` | 铸造禁用 | — |
| closed_no_holders | 发售结束时无人铸造，项目已关闭 | 去项目页 | 灰 |
| paused（表外补） | 项目已暂停 + 原因 | 去项目页 | 灰 |

- 铸造成功：广播后立即重读并在每次读回时检查；读到 `viewer.nft.held > 0` 即清除待确认提示、勋章下沿出现 `#tokenId`、
  按钮变「已持有」，并弹一次 `LoopToast`「已铸造 · 等待发售结束进入名单」；36 次读不到则提示「已广播，但还没有读到确认…不要重复铸造」。
- 有 `summary` 时在「这枚勋章能做什么」之上一段 body text2，最多 3 行省略。

### 4. 入口
- Banner（upcoming / nft_sale）；项目页 `_NftSaleBlock` 价格行右侧文字按钮「铸造页」（key `launch2-nft-open`，brass），
  原「购买 NFT」不动；钱包 NFT 行（`launch2-wallet-nft-*`）改进铸造页（S136 测试相应改为断言 `/launch2/nft?id=`）。

### 5. 组件
- `LoopButton` 新增可选 `tone`（`LoopButtonTone.lime` 默认 / `brass`），默认行为不变；brass 为平涂 brass 底 ink 字，无光晕。
- 项目页的底栏壳 `_BarShell` 移到 `launch2_widgets.dart` 成为 `Launch2BarShell`，两页共用。
- `launch2SaleDurationLabel`（原项目页私有 `_durationLabel`）与 `launch2SpokenDuration` 移入 `launch2_format.dart`。
- 决策 0122 把 brass / copper 限于领奖台与插画；本决策按设计定稿把 brass 作为 NFT 专用强调色，`MEDAL_COLOUR_ALLOWLIST`
  加入 `launch2_hero.dart`、`launch2_nft_screen.dart`、`launch2_instance_screen.dart`（「铸造页」）、`loop_components.dart`（tone）。

## 与设计定稿的逐条对照

照做：§2 token 全部沿用（banner 底 graphite、圆角 20、页边 16、banner 内 20、组间 22，倒计时与百分数 mono，预告用 chalk 不用 lime，
brass 只给 NFT）；§3.1 来源、顺序、最多 5、无行不画、无占位；§3.2 高 196、状态句 / ticker display 26 / name text2 / logo 64、
NFT 阶段 brass 环、主角数字 figureXl、第三行 figureSm、2 px 引线、五种阶段的三行内容与引线比例、复用 `Launch2Countdown` 并到点重读、
点击目标、≥ 2 张才有分页点、无轮播无入场动画、一句话语义标签、无渐变 / 玻璃 / HOT / 全大写；§4.1 结构（勋章、状态行、
这枚勋章能做什么、规则、我的持有、brass 主按钮）；§4.2 各状态；§4.3 成功不做新页、本页刷新、`#tokenId`、按钮变已持有、一次 toast；
§4.4 三个入口；§5 不新增字体与颜色、`Launch2InstanceTile` 不改、稳定 key（`launch2-hero`、`launch2-hero-page-{id}`、
`launch2-hero-dots`、`launch2-nft-screen`、`launch2-nft-medal`、`launch2-nft-mint`）、360 不溢出、ticker > 8 省略。

偏离（技术或事实原因）：
1. 倒计时文字沿用 `Launch2Countdown` 的既有格式：「2天 03:00:00」（数字与「天」之间无空格），不足 1 小时为「MM:SS」，
   与列表和项目页一致；设计写「D 天 HH:MM:SS」。
2. 主角数字前加一个 body text2 的「距开售」/「剩」小字，数字本身 `FittedBox` 缩放以保证 360 宽带天数时不溢出。
3. 价格沿用列表的折零精度，去掉列表列里的 `$` 再接「USD1」：「0.0₄4167 USD1」。
4. §3.2 表里有 `snapshot_pending` 一行，但 §3.1 的选行规则不含它；按 §3.1 不选入（卡片内容已实现，传入即可画）。
5. 组内次序设计未定：`nft_sale` / `priority` 按结束时间近到远，`public` 冲刺按已售比例高到低；同值保留服务端顺序。
6. 分页点画在整个 pager 右上角（一组，随翻页移动高亮，active chalk / 其余 line2），而不是每张卡各画一组。
7. 引线底轨用 `card2`，进度 lime；未用 `LoopProgressFill`（见上，动画冲突）。
8. `closed_no_holders` 是旧工厂的终态（0120 / 0142：提前购与公开轮都不会开），设计句「已直接进入公开轮」与事实不符，
   改为「发售结束时无人铸造，项目已关闭」；「已直接进入公开轮」用于 `public` 且 `snapshot.openedWithoutHolders` 的情形（0122）。
9. 权益第三条「项目若 N 天未毕业可按比例退回」依赖 `exitPaths`，契约里没有该字段，不显示。
10. 规则「不可转让给同项目已持有者」在合约文档里查不到依据，不写；规则写「每个地址终身只能铸 1 枚 · 100 USD1 / 枚」、
    「发售 N，截止 时间」与风险句（`launch2NftRiskSentence`）。权益第二条按 docs/21（NFT 款进项目托管、keeper 每笔
    `template.buybackOrderUsd1` 回购）写作「铸造款进入本项目的托管合约，毕业后由平台按每笔 100 USD1 回购 MEME」。
11. tradingHold 只禁用「铸造」；「去项目页交易」只是跳转、不动 USD1，保持可点（项目页自己会禁用交易键）。
12. 「钱包未激活」判定为没有活动钱包且详情无 `viewer`；按钮禁用，不跳激活流程（本页没有可靠的激活入口路由）。
13. 契约没有 report 路由（frontend-v2-launch2-api §3.4「there is no report route」），所以「prepare → 签名 → report」
    在本仓库是「prepare → 签名出口 → 重读直到 `viewer.nft` 出现」，与项目页一致。
14. 表外补 `paused`：「项目已暂停」+ 原因、灰环、「去项目页」。upcoming 状态行下加一行「100 USD1 / 枚 · 发售 N」，
    之后各阶段下加「已铸 N 枚」。
15. 项目页价格大字改为可缩放（`FittedBox`），在窄屏上给「铸造页」让位；视觉在 390 宽不变。
16. 勋章 152 dp，内侧加一道 35% 透明度的细环作为环带的内界；ticker 与名称放在勋章右侧（与草图一致）。

## 复用点
`Launch2Countdown`、`Launch2TradingHoldBanner` / `Launch2TradingHoldLine`、`Launch2ActionFailureLine`、`launch2MintNft`
（项目页与铸造页共用）、`launch2OutcomeText`、`Launch2BarShell`、`showLaunch2NftConfirmSheet` / `showLaunch2SignSheet`、
`launch2InstanceControllerProvider`、`MemeLogo`、`LoopKeyValue`、`LoopToast`、`LoopProvenanceLine`。

## Consequences

- 新测试 `test/s180_launch2_hero_nft_test.dart` 31 条：选行与排序（活动在前、预告在后、≥ 70% 冲刺、最多 5、只有预告、
  无可展示行不渲染、已毕业列表不渲染）；五阶段三行文案、引线比例与点击目标；语义句与 ticker 省略；渲染出的 NFT 卡
  （三行、倒计时、引线比例、brass 环）；分页点（1 张无点、3 张三点、翻页高亮移动）与点击路由；铸造页 upcoming /
  nft_sale 未持有（含 summary 在权益标题之上）/ 已持有 / snapshot_pending 两种 / priority·public·graduated 跳项目页 /
  零持有开盘 / closed_no_holders / 钱包未激活 / tradingHold / 非法 id；一次铸造走确认 → prepare → 签名后勋章出现 `#7`、
  按钮变已持有、弹 toast；prepare 被拒在按钮上方说明且未签名；项目页「铸造页」入口且「购买 NFT」保留；路由形状；
  `summary` / `links` 可选与容错；360 × 800（`tester.view.physicalSize`）下 banner（长 ticker、长名称、翻到第三张）与
  铸造页（长 ticker、长名称、长简介、6 位 tokenId、滚到底）无溢出。
- `test/route_manifest_test.dart` 与 `tests/test_check_harness.py` 计数 112 → 113；S136 钱包 NFT 行目标改为铸造页。
- 后端没有 `summary` 时行为与之前一致；列表无可展示行时与之前一像素不变。

## 第二阶段（docs/32 §7，2026-10-14 追加）

### 接口与数据层
- `GET /v2/launch2/overview`（S181-api）：`{activity[], stats{…}, observedAt, contractVersion}`。新端口
  `Launch2OverviewGateway`（`lib/features/launch2/launch2_overview.dart`，默认 `UnavailableLaunch2OverviewGateway`，
  `lib/main.dart` 挂 `loopV2Launch2OverviewGatewayProvider`；harness 新增 `LAUNCH2_OVERVIEW_PORT` 同样要求默认 unavailable）。
  适配器与编解码 `lib/integrations/backend/v2/launch2/loop_v2_launch2_overview_api.dart`，错误表复用 launch2 读接口。
- 编解码按「增强数据」从宽：读不懂的单条丢弃（未知 kind、非 UUID、ticker 不合 `^[A-Z0-9]{2,12}$`、`at` 不可读），
  `actor` 不是 0x 地址读作「有人」，`amountUsd1` 不可读读作无金额，`stats` 任一字段不可读整块为 null；只有根不是对象才算失败。
  404 / 503 / 任何失败：实时流与战绩条都不渲染。
- `Launch2OverviewController`（autoDispose，无自己的定时器）：列表 scope=all 首读时一起读；60 s 轮询、从项目页返回、下拉刷新
  都由 `Launch2ListSegment` 一并 `reload`（§7.1「随列表轮询一起刷新」）。

### §7.1 实时流 `Launch2ActivityTape`（`launch2_launchpad.dart`）
- 位置：分段条之下、hero 之上（列表 rows 的第一项）；高 32；`figureSm` mono；每条之间 24；每条前一个 3×12 的标记
  （铸造 brass、卖出 text3、其余 lime）。
- 文案：「{相对时间} {0x1d2f…9b / 有人}买入 DOGE 20 USD1」「…卖出…」「有人铸造 DOGE 勋章」「DOGE 毕业了」
  「平台回购 DOGE 100 USD1」「DOGE 外盘新一轮激活」「0x1d2f…9b 领取 DOGE 奖励 10.94 USD1」；相对时间
  刚刚（< 1 分）/ N 分钟前（< 1 小时）/ 本地 HH:mm。
- 运动：`Ticker` 每帧按 40 dp/s 推进；手指按下即停（可拖），抬起继续；`MediaQuery.disableAnimations`（`LoopMotion.reduced`）
  时不起 ticker，改为静态横滑列表，只显示最新 3 条。新条目进入队列末尾，下一轮才出现，屏上已排好的条目不动、不闪；
  空数组整行不渲染。点击一条进该项目页。

### §7.2 引线首次出现动画
- `Launch2HeroFuse(introduce:)`：pager 对每张卡只在第一次出现时传 `introduce: true`，600 ms easeOutCubic 从 0 画到实际值；
  之后数据变化直接重画；减少动画时直接画。

### §7.3 阶段计数条 `Launch2StageCountBar`
- 铸造中 / 提前购 / 内盘 / 预告，数字来自已加载的行；为 0 的不画，全为 0 整条不画。胶囊为 card 底 + line 描边的 stadium，
  数字 `figureMd` mono。点击滚到该组标题：列表是懒加载 sliver，远处标题可能尚未构建，所以先按一屏一屏 `jumpTo` 直到标题出现，
  再 `Scrollable.ensureVisible`（减少动画时无动画）。

### §7.4 分组列表
- scope=all：铸造中 → 提前购 → 内盘 → 名单生成中 → 预告 → 已毕业 → 已暂停 / 无人铸造；组内保持服务端顺序；空组不画。
  组标题 `LoopType.title` + 右侧 text3 mono 计数（key `launch2-group-{name}` / `launch2-group-count-{name}`）。
- `Launch2InstanceTile` 新增可选 `fuse`（行底 2 px，左右留 16）与 `ringed`（logo 外 1.5 px brass 环）；只有 scope=all 传入：
  nft_sale = 发售时间已过比例、priority / public = 已售 / 8 亿，其它不画；nft_sale 画环。已毕业列表不分组、不加引线与环
  （仍用原 `launch2ListOrder`）。

### §7.5 战绩条 `Launch2StatsStrip`
- 列表末尾、来源行之前；三组 mono 数字 + 小标签：「3」本周毕业 · 累计 12 /「4,200.5 USD1」累计回购 /「318 枚」铸造；
  数字 `FittedBox` 缩放保证 360 宽；`stats` 缺失不渲染。

### 与 §7 的偏离
1. 接口按协调方定稿用合并的 `GET /v2/launch2/overview`，不是 §7.1 / §7.5 分开的 `activity` / `stats`。
2. `round_activated` 没有轮次字段，文案写「DOGE 外盘新一轮激活」，不写「第 N 轮」。
3. 匿名主语与动词连写（「有人买入」），有地址时中间空格（「0x1d2f…9b 买入」）；地址显示前 6 后 2。
4. §7.4 顺序里没有「已毕业」，而 scope=all 列表会含毕业项目：放在「预告」之后、「已暂停 / 无人铸造」之前。
5. 实时流用一个只在末尾增长的序列实现循环（到距末尾两屏时追加一轮队列，上限 2000 条），以保证新条目「插队尾」时屏上不跳；
   页面长时间停留时序列会缓慢增长。
6. 计数条的滚动在懒加载列表上分两步（先逐屏跳到标题构建出来，再 ensureVisible），而不是单次 ensureVisible。
7. 减少动画时实时流显示最新 3 条（§7.1 原文），协调方的「静态横滑列表」同时满足。
8. 引线首次动画按卡计「首次出现」（翻到第二张时第二张也画一次），之后不再动画。

### 第二阶段测试（同文件 `test/s180_launch2_hero_nft_test.dart`，新增 15 条，合计 46 条）
七种 kind 文案（含匿名与有地址）、相对时间三档、overview 编解码容错；实时流以约 40 dp/s 漂移（1 s 内 30–50 dp）、按住不动、
松手继续、点击进项目页；第二次读到的新条目不改变第一条；减少动画为静态 3 条且无 controller；无活动 / 无 overview 时无流无战绩；
hero 引线 250 ms 时介于 0 与目标之间、650 ms 到目标，减少动画时立即到目标；分组顺序、组计数、组内服务端顺序、计数胶囊
为 0 不画、行引线比例（nft_sale 4/7、public 0.25、upcoming / graduated 无）、nft_sale brass 环；只有毕业 / 关闭行时无计数条；
点胶囊把远处「预告」标题滚进视口；已毕业列表无分组 / 计数 / 流 / 战绩；战绩条三组数字与位置在来源行之前；360 × 800 下
流、hero、计数、分组、战绩无溢出。

## 补丁：动作名按入口全程一致（模拟器验收反馈）

- `launch2MintNft` 新增 `entry: Launch2NftMintEntry`（默认 `projectPage`）。从共识勋章发起（`mintPage`）时：确认弹层标题
  「铸造 {TICKER} 共识勋章」、按钮「继续铸造」；签名页标题「确认铸造」、两步条主步骤「铸造」、事实行「操作」为
  「铸造 {TICKER} 共识勋章（每个地址 1 枚）」、交给钱包的意图标题「确认铸造」、广播 / 未确认提示里的动作名「铸造」；成功 toast 仍是
  「已铸造 · 等待发售结束进入名单」。从项目页「购买 NFT」发起的文案不变。
- 实现：`showLaunch2NftConfirmSheet` 加可选 `heading` / `confirmLabel`；`showLaunch2SignSheet` / `Launch2SignSheet` /
  `Launch2IntentSigner.sign` / `mainSigningIntent` / `approvalSigningIntent` / `launch2IntentFields` / `launch2IntentTitle` /
  `launch2BroadcastText` / `launch2OutcomeText` 加可选 `noun`，缺省时与之前逐字相同。
- 测试 +2（两个入口各一条，断言弹层标题、按钮、签名页标题、两步条与事实行不出现另一个动作名、钱包意图标题）。
