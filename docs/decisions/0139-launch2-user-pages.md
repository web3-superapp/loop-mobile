# 0139 · MEME v2 用户侧：MEME Tab 的 v2 列表与项目页一页六态（S136）

## Status

Accepted 2026-10-10。主代理下单（S136-mobile），基线 `integration/v2` 24695c0，分支 `feat/S136-mobile`。
配套 loop-api 决策 0114（读模型）/ 0117（S139 跟进：报价只在可交易阶段、价格示例更正、对手方校验）/
0118（名单发布者，`snapshot.publication`，loop-api 工作区未合入，客户端按可选键接）。设计稿
`docs/modules/S134-S137-meme-v2-app.md` §1、§4。不新增依赖，视觉 token 不变（只在 `LoopMotion`
追加 `stageSwitch = 150 ms`）。

## Context

S134 只让 App 认识 `launch2` 能力位（决策 0137，`launch2Visible = false`）。本批落用户侧：列表、项目页、
NFT 购买、内盘买卖、毕业与回购、钱包两行。合同：`loop-api/docs/frontend-v2-launch2-api.md`、
`openapi/loop-api.v2.json` tag `launch2`。实例阶段比设计稿多一个 `upcoming`（激活后、开售前），
`paused` 是一致性挂起（`holdReason`），回购暂停是 `buyback.paused`、不置灰页面。

## Decision

### 1. 门控

- `LoopFeatureSwitches.launch2Visible` 改 `true`；入口仍只在 `launch2 == available` 时出现
  （`launch2SurfaceVisible`：开关 ∧ 能力位，Preview 模式除外）。任一不满足，MEME Tab 与钱包与改前完全一致。
- 端口 `launch2GatewayProvider` 默认 `UnavailableLaunch2Gateway`，`lib/main.dart` 挂
  `loopV2Launch2GatewayProvider`（Dio 客户端、客户端元数据、登录会话三者齐才可用）。页面读
  `launch2ReadsBlocked` 决定是否发请求。harness `check_launch2_user_contract` 锁住这四条与签名出口唯一。

### 2. MEME Tab 分段

- 开关与能力位都满足：「v2 发射 / 经典 / 已毕业」（IDO 开关开时第四段）。「v2 发射」= 全部阶段
  （`GET /v2/launch2/instances`），「经典」= S117 曲线发射台原样，「已毕业」= `stage=graduated`。
  原「行情」段（平台 `meme` 行情分类）在这一形态下离开 MEME Tab，仍在 `/market` 可达——设计稿 §4 的三段里没有它。
- 行 = OKX 行（S121 §1.1.1）：logo 36 圆 + ticker / 名称 + 右侧两行 + 96×44 阶段胶囊（Lime 只给可交易两段与已毕业，
  其余灰底灰字，暂停为 warning 字）。右侧两行：`upcoming` 倒计时 / 「后开售」；`nft_sale`「NFT 已售 N」/「剩 倒计时」；
  `snapshot_pending`「NFT 已售 N」/「名单生成中」；`priority/public` 内盘进度百分比 / 当前价；`graduated`「已毕业」/
  「毕业价」；`paused`「已暂停」/「平台核对中」。
- 倒计时只用服务端 `nextChangeAt` 与唯一时钟 `launch2ClockProvider`；`Launch2Countdown` 自己每秒 `setState`，行与页不重建；
  到点调一次 `onElapsed` 让列表/详情重读，自己从不推进阶段，归零停在 `00:00`。
- 列表可下拉、到底自动读下一页（`LoopLoadMoreSentinel`），失败一行重试，到底只留空白与来源行，没有「没有更多」。
  空列表 = 线稿插画（launchpad）+ 标题 + 一个动作（切到另一段）。

### 3. 项目页 `launch2-instance`（`/launch2/instance?id=<instanceId>`）

- 清单不允许路径参数（`route_manifest_test`：path 不含 `:`），所以与 `/meme/token?id=` 同法用查询参数；
  缺失或非 UUIDv4 的 id 整页失败关闭、不发请求。清单 105 → 106（`4-launch`，`prototypeOrder` 112，S117 之后）。
- archetype `record`、layout `dashboard`。顶部：「你是项目方」一行（`viewerIsProjectOwner`）→ 身份行 → 阶段条（圆点 + 阶段名 +
  说明 + 倒计时）→ 内容区。内容区按阶段换内容，`AnimatedSwitcher` 只做一次 150 ms 淡入（旧内容立刻离开，减弱动态时 0），
  不跳页。详情每 15 s 重读，可交易阶段与有待确认广播时 5 s；倒计时归零立刻重读。
  - `upcoming`：开售时间、NFT 价格、发售时长；「发射规则」固定模板卡（总量 / 内盘 / 毕业储备 / 买卖税 / 外盘税 / 单地址上限），
    「由平台模板固定」与风险句进 ⓘ。
  - `nft_sale`：100 USD1 大字、我的持有 `n / 1`（无钱包写「未激活钱包」，不写 0）、已售、截止；底栏 Lime「购买 NFT」，
    已持有则「已持有 NFT」置灰。点击先开确认抽屉：价格、每地址终身 1 枚、整句「我已知晓：不保证成交、不保证配售，
    公开内盘可能不发生。」必须勾选才能继续 → `nft/prepare` → 有 `approval` 先授权（nonce N）再 mint（N+1），
    全部走 `LoopSignSheet` 签名出口（`Launch2IntentSigner`，Launch 槽位的两种 intent kind）。拒绝（含
    `LAUNCH2_GAS_INSUFFICIENT`「tBNB 手续费不足，充值后再试」）一行写在页内，不签任何东西。
  - `snapshot_pending`：线稿插画（holders）+ 标题 + 「截止块 #N，名单发布后开始 1 小时提前购」；标题按 0118 的显示规则：
    无发布 → 名单生成中；pending/broadcast → 名单发布中；confirmed 且 snapshot 仍 pending → 名单已上链，同步中；
    failed/mismatch → 名单发布异常，平台处理中。截止块取 `snapshot.cutoffBlockNumber`，没有再取 `publication.cutoffBlock`。
  - `priority/public`：当前价大字、内盘进度条（已售 / 8 亿）、我的内盘持仓；交易面板（见 §4）；最新 20 笔成交，空则线稿插画。
  - `graduated`：「官方池」毕业时间 / 毕业价 / 外盘税，池 ID（v4 没有池地址）、Hook、LP 费、tickSpacing、2% 外盘税说明进 ⓘ；
    底栏 Lime「去外盘交易」→ `/wallet/swap?to=<chainId>:<meme>`（与 S117 同一预填）。回购面板读 `…/buybacks`：托管余额（优先
    `live`）、累计回购（金额 · 笔数）、最近一笔（时间 / 金额 / 成交或原因）、下一笔 = `nextOrderBlockedReason` 中文；
    `liveUnavailable` 一行原因；「回购不等于销毁」、规则、收币地址进 ⓘ。被拒尝试链上不留日志，不列。
  - `paused`：顶部 warning 通知写 `holdReason` 中文，其余整页灰态（`Launch2Greyed`：亮度保持的灰度滤镜 + 不响应触摸）。
    用透明度做灰会把灰字压到可读下限以下（ground probe 拦下），所以用灰度不用透明。底栏不画。
- 五态：loading 骨架、notFound 空、error / offline / permission / unavailable 各自的 `LoopChainStateBlock`；能力位关闭整页
  `LoopPageBlock`。资金动作的后三态：签名前拒绝写「没有提交任何交易」；钱包结果未知为锁定（submissionUnknown）；
  广播后页内一条「已广播…广播不代表已成交」（pending）并锁住下一次签名，直到详情的 viewer 变化（「已在链上确认」）或 36 次
  重读后解锁并改写为「还没有读到确认…不要重复」。合同没有上报路由（索引后 viewer 自然变化），也没有 intent 状态可读，
  所以链上 revert 只能表现为 viewer 不变 + 超时文案（未覆盖项，见偏离）。

### 4. 交易面板（复用 S117 面板的形，内嵌不叠抽屉）

S117 `MemeTradePanel` 绑死 v1 的 `MemeTokenDetail` / `MemeQuote` / 端口，不能直接复用；v2 面板保持它的结构（单行金额框、
报价块、确认键滚到键盘上方、无双层抽屉），画在项目页内：

- 买/卖分段只在 `public`（提前购只能买，`LAUNCH2_SELL_NOT_OPEN`）。金额框 decimal 键盘 + 过滤，后缀内 MAX 键（44pt）。
- **MAX = 服务端 `max.amountIn`**：有报价用报价的，没有就为这个键单独报一次价（amount=1），填入后重报。
- `exceedsMax: true` → 一行「超出可买上限（限额原因）」+「填入 X」一键填 MAX，确认键关闭（报价数字已是 MAX 的）。
- 累计额度条：已用 / 5,000,000（`quota` 优先，否则 viewer `cumulativeBought` 与模板上限），两轮共用、卖出不恢复。
- 税率一行「税率 10%」（模板 `curveBuyTaxBps` / `curveSellTaxBps`）；报价块：预计 / 最少获得（到手）、税、退回、价格前→后、来源行。
- 名单资格徽章（仅 `priority`）：「名单内」Lime / 「不在名单」灰。提前购阶段 viewer `eligibleNow=false`、报价
  `eligibility.eligible=false` 或 prepare `LAUNCH2_NOT_IN_SNAPSHOT` → 面板灰态（同上灰度）+「提前购仅限名单内持有人，
  公开内盘开始后可买入」；`LAUNCH2_SNAPSHOT_UNVERIFIED` / 名单 `mismatch` → 不可用一行；无钱包 → 「还没有可用的钱包」。
- 面板自己调 `trade/prepare`（amount = 报价 `amountIn`，`minOut` / `deadline` 原样），拒绝留在面板：
  `QUOTE_EXPIRED` 静默重报；`DATA_STALE / LAUNCH2_PRICE_MOVED` 一行「价格已变化，已刷新」并重报；
  `LAUNCH2_AMOUNT_ABOVE_MAX` 重报（新报价带 exceedsMax 与填 MAX）；其余写规则中文。不弹 toast、不进错误页。
  报价到 `deadline` 自动静默重报。成功把 intent 交给页面的签名出口。

### 5. 钱包「资产」

`Launch2WalletRows` 插在资产列表之后、Launch 链块之前，每个实例最多两行（内盘持仓 `curve.net > 0`、NFT `held > 0`），OKX 行，
右侧两行 = 数量 / 阶段，点开项目页；读 `me/positions`；读取中与空都不画，失败一行重试；跟随「隐藏金额」。
不加标题、不进总资产（`curve.net` 是曲线买卖差，不是钱包余额）。

### 6. Codec

`LoopV2Launch2Codec`：每个对象按 OpenAPI 的完整键集 `strictMap`（全部必填、可空按 schema），金额 `Decimal`、计数 `BigInt`、
时间 UTC。可选键只有一个：`snapshot.publication`（0118 新增，旧后端缺省读作「还没开始发布」）。交易对象 schema 是开放的，按
loop-api `unsignedTransactionFor` 实际产出的 11 键读，`legacy` 必须有 `gasPrice`、`eip1559` 必须有两个 fee。`logoUrl` 是图片不是事实：
只认本后端媒体地址或 `isAcceptedLogoUrl`，否则画字母块、不判 invalid。附加一致性：列表 id 不重复、`stage=graduated` 列表行必须是
graduated、报价必须是所问的实例 / 方向 / 钱包、prepare 必须是所问的实例 / 钱包 / kind、回购 `live` 与 `liveUnavailable` 恰有其一、
intent 的主交易 to / calldata / 授权 token / spender 与审阅字段一致（否则签名出口拒签 `REVIEW_PAYLOAD_MISMATCH`）。

## 与下单描述的偏离

- 路由写作 `/launch2/instances/:id`；清单禁止路径参数，落为 `/launch2/instance?id=`。
- 「去外盘交易」在测试网也照做（S117 在测试网改为「测试网不支持站内兑换」+ 复制池地址）；v4 没有池地址可复制，按下单走兑换页。
- 「池价」：列表与详情都没有毕业后池价字段，行与页写「毕业价」（曲线最后价 = 建池价），不冒充实时池价。
- 合同 §3.2 `nftSale.endAt`（下单写作 `endsAt`），按 OpenAPI。
- 面板没有直接复用 `MemeTradePanel` 类（见 §4），复用的是形与 `memeFillText` 之外的交互规则；没有滑点选择（服务端默认 100 bps）。
- 预检样例目录在 LOOP 工作区根（不在本仓库），15 个手写样例不随分支提交，README 已记录；回放入口在本仓库。
- dev 后端的 `upcoming` 实例需要登录 token 才能读，本批没有实抓。
- 签名后链上 revert（被抢先、过期）合同没有可读的 intent 状态，App 不能区分「还在确认」与「已回滚」，只在超时后提示稍后再查；
  合同 §3.5 的「签名后回滚 → 重报」需要后端给 intent 读路由或交易回执后才能做。

## Consequences

- 清单 106 条；与 S135（项目方页面）合并时清单计数、sha256、`prototypeOrder` 需要主代理按合入顺序重算。
- `launch2Visible = true` 后，只要后端把 `launch2` 发成 `available`，MEME Tab 立即换成三段；回退只需改回 `false`。
