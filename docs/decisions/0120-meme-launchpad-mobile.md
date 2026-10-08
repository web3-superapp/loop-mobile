# 0120 · MEME 曲线发射台前端（S117-mobile）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S115-S118-meme-launchpad.md` §3），S117-mobile 实施。
基线 `integration/v2` 73788dc（已含 S111–S114）。后端契约：loop-api 决策 0101、`docs/frontend-v2-meme-api.md`、
`openapi/loop-api.v2.json` tag `meme`（loop-api `integration/v2` c85c566，dev 已部署）。不新增依赖、
`pubspec.lock` 不变。路由清单 101 → 105。

## Context

1. 需求方 v3（`LOOP/docs/09` §1 位置 3、§2 A2/A3/A4、§6.1 第 5 条）：MEME Tab 的发射台改为 four.meme 式曲线
   发射台（创建、买卖、打满自动上 PancakeSwap），IDO Launch 隐藏可恢复。参数由主代理裁定（`LOOP/docs/10` §1/§2）。
2. 后端 0101 已在 `GET /v2/meta/capabilities` 加 `meme`，并在 `category=meme` 行情里用 `quote.source = loop_curve`。
   旧客户端对两者都是严格解码：能力文档条目数与枚举不等即判整份无效（会让全部能力读成 unknown），
   `loop_curve` 不在 `LoopFactSource` 里会让整个 MEME 行情分类判无效。本单必须同时放宽这两处。

## Decision

### 1. 数据层（`lib/integrations/backend/v2/meme/**`）

- `DioLoopV2MemeApi`：列表（`tab` + `limit=30` 或 `tab` + `cursor`，二者互斥）、详情、成交 / 持有者（`limit=50` 或
  `cursor`）、K 线（`interval` + `limit=200`）、报价（`tokenId`/`side`/`amount`/`walletId`）、创建、准备 intent、
  broadcast-report、读 intent、`POST /v2/media/community-logos`（multipart `file`，`ref` 必须是 `logo:media/{id}`）。
  读与写的错误目录按 OpenAPI 每路由列出（读加 `403` 三件套与 `429`，同 S5 约定）。
- `LoopV2MemeCodec`：全部对象 `strictMap` / `strictMapWithOptional`（只有 `quoteUnavailable`、`viewerUnavailable`、
  `predictedAddress`、`refund` 是可选键）。原始 18 位整数 → `BigInt`，价格 → `Decimal`，无 `double`。
  `imageUrl` 只取路径 `/v2/media/{mediaId}.webp` 里的 id，再用本机后端源拼地址（不信任载荷里的主机）。
  价格缺失必须带 `quoteUnavailable` 原因（没有则记为 `MEME_QUOTE_NOT_REPORTED`），价格存在必须带 `priceSource`。
  K 线按时间严格递增、`low ≤ open/close ≤ high`。intent 校验 `chainId == eip155:{chainReference}`，并计算
  `payloadMatchesReview`：主交易 `to == calldata.to == contractAddress`、`data` 一致、链一致；授权交易 `to == token`、
  `spender == contractAddress`、`from` 与主交易一致。
- `DioLoopV2MemeGateway`：三种写各占一个幂等键（`LoopV2CommandKeyring`），只有结果未决（offline / cancelled /
  outcomeUnknown / unexpected）时重放同一个键。失败统一映射为 `LoopChainException`（带 `detailsSafe.reasonCode`）。
- `loopV2MemeGatewayProvider`：Dio + 客户端元数据 + 已认证会话三者齐才可用，否则 `UnavailableMemeGateway`；
  `lib/main.dart` 只加这一处 override。

### 2. 端口与控制器（`lib/features/meme/**`）

- `MemeGateway` 端口（无 Dio、无 `/v2/` 字面量），生产默认 unavailable，不回退任何夹具。
- `MemeListController`（按 chip）、`MemeTradesController`、`MemeHoldersController`（`MemePagedController`：
  `loadMore` 追加去重，cursor 被拒回第一页，翻页失败保留已读行并给一行重试）、`MemeTokenController`、
  `MemeCandlesController`，均复用 `LoopChainReadController`（单飞、账号切换重置、五态）。
- `MemeSubmissionController`（按 `create` / `trade:{id}` 分域）：prepare → 签名出口 → 记录结果 → 每 3 秒读 intent
  至 `confirmed` / `failed` / `expired`，最多 60 次后「再查一次」；上报被拒且可重试时「重新上报」同一哈希。

### 3. 签名出口（`meme_signing.dart`）

- 只经共享 `LoopSignSheet`。有 `approval` 时先把 `approval.unsignedTransaction` 原样交钱包（nonce N），再交主交易
  （N+1），只回报主交易哈希；两者都是 `SigningIntent.backendCanonical`，`payloadDigest` 取 intent 的
  `payloadDigest`。钱包前的拒绝：`signing.allowed` 为假（读服务端 `reasonCode`）、过期、载荷与复核不符、
  钱包地址不明或与 `from` 不符。`wallet_outcome_unknown` 锁定不再签。
- 签名事实只取 intent 本身：操作、代币地址（create）、支付 / 预计获得 / 最少获得（卖出为到手 USD1）、打满退回、
  手续费、先授权金额、模拟结果、有效期、快照区块、合约、网络；测试网显示「BSC 测试网」徽标。
- 广播后显示「已广播」，结果以 intent 状态为准；create 确认后 `pushReplacement` 到代币页。

### 4. 页面

- `meme`：段「发射台 | 行情」，开关 `idoLaunchVisible` 打开时追加第三段「IDO」放原 Launch 目录与其两个工具。
  - 发射台（index · dashboard）：搜索入口（跳 `/search`）+ Lime「创建代币」；chips 新发 / 热门 / 快打满 / 已毕业；
    72 高无卡片行：Logo 44（圆角 10，图片缺失为符号首字母方块）、「名称 $SYMBOL」、「市值 $x · N 持有」、
    价格 /「▲x%」（1h，rise/fall），行底 2px Lime 进度条，已毕业显示「已毕业」标签；滚动加载到「没有更多」；
    空态「还没有代币，来创建第一个」+ 创建按钮；能力关闭为一行 `LoopInlineUnavailable`；来源一行。
  - 行情：`GET /v2/market/assets?category=meme`，复用 S113 `MarketFomoRow.category`，点行进 S113 代币页；
    空态「平台 MEME 资产上线后在这里显示」。
- `meme-create`（action · focus，`/meme/create`，`?draft=` 续建草稿）：同页三步 + 进度点。① 名称 1–32、符号 2–10
  （自动大写）、简介 ≤500；② 图片（S107 选图 + 方形裁剪 → community-logos）+ X / Telegram / 官网（仅 https）；
  离开 ② 时 `POST /v2/meme/tokens` 生成草稿（同内容复用草稿，不重复占用每日额度）；③ 参数摘要（总量、可售及占比、
  费率、单钱包上限、毕业条件「募满约 X USD1 后自动上 PancakeSwap」，X 由草稿曲线快照按 `V0·S/(T0−S)` 算出）、
  预测地址（尾 4 位 Lime）、`vanity=false` 提示「本次无法分配 6666 尾号」、可选首买（本机按曲线公式估算
  「约得 / 手续费 / 上限」，低于最小买入或超过单钱包上限即禁用「创建」）。429 文案「今天的创建次数用完了，明天再来」。
- `meme-token`（record · dashboard，`/meme/token?id=`）：顶栏 `$SYMBOL` + 分享（二维码 + 复制 + 系统分享）；
  身份行（Logo、名称、地址 + 复制）；价格 +「▲x% · 1h」+ 市值 + 来源行（LOOP 曲线 / DexScreener）；
  有余额时「持有 x $SYMBOL · ≈$y」；进度区「内盘进度 x%」8px 进度条、「已募 x / ≈17,582 USD1」、
  「打满后自动上 PancakeSwap」；图表复用 S113 `LoopMarketChart`（折线默认可切 K 线，1分 / 5分 / 15分 / 1时 / 4时 /
  1日，少于两根显示「成交还太少」）；Tab 持有者（创建者 / 我 标记，毕业后「分布冻结于毕业时」）/ 动态（买 rise、
  卖 fall，账号名或钱包缩写）/ 关于（简介、链接、创建者卡 → 公开资料、合约事实、毕业事实、外盘行情入口、来源行）。
  底栏按 §10：trading 买入 / 卖出；full「打满，毕业中…」；graduated「去兑换」；paused「已暂停交易」；
  draft「继续创建」；pending_chain「创建中…」。pending_chain / full / 交易确认中每 5 秒重读详情；
  full → graduated 时进度满格并出现一次性庆祝条（展开动画，reduce motion 下直接出现）。
- 买卖面板：金额（USD1 或代币）、25/50/75/100%（按 `viewer` 余额）、报价（得 / 费 / 影响 / 打满退回 + 来源行）、
  上限 / 最小买入 / 余额不足在签名前一行说明并禁用确认、滑点 1% / 3% / 自定义（0.01–50%）。确认后由页面准备
  intent 并打开签名出口。
- `meme-token-holders` / `meme-token-trades`：同一列表的独立页（滚动加载），代币页 Tab 右侧图标进入。

### 5. 共享层的最小改动（越出 `lib/features/meme/**` 的部分）

| 文件 | 改动 | 原因 |
| --- | --- | --- |
| `lib/integrations/backend/v2/loop_v2_meta.dart` | `LoopV2CapabilityId.meme` | 后端已返回 32 项能力；不加则整份能力文档判无效 |
| `lib/integrations/backend/v2/loop_v2_meta_repository.dart` | `meme` 与 `launch` 一样允许 `confirmed` 带 reasonCode | 后端 `MEME_CONTRACT_OBSERVED` |
| `lib/features/chain/chain_contract.dart` | `LoopFactSource.loopCurve`（「LOOP 曲线」）、`poolSlot0`（「池子推算」） | 契约 §9「客户端解码请放宽」、S116b |
| `lib/integrations/backend/v2/market/loop_v2_market_api.dart`、`lib/features/market/market_fomo_widgets.dart` | 分类行接受 `quality = derived`；`pool_slot0` 行标记「池子推算」 | S116b，AGENTS 25 可见标记 |
| `lib/features/wallet/swap_screens.dart` + `lib/app.dart` | Swap 接受 `?from=&to=` 预填（只做选择，不自动报价） | 「去兑换」预填代币对；原 Swap 无参数 |
| `lib/core/navigation/route_manifest.dart`、`docs/product/routes-manifest.json`、`scripts/check_harness.py`、`tests/test_check_harness.py`、`test/route_manifest_test.dart`、`AGENTS.md`、`docs/product-decisions.md` | 清单 101 → 105、sha256 重算 | 新增 4 路由 |
| `test/s106_v3_navigation_test.dart`、`test/s106b_nav_followups_test.dart`、`test/s7_api_contract_test.dart`、`test/loop_candle_chart_test.dart` | 发射台改为曲线、IDO 为第三段；能力 32 项；`meme_format.dart` 进摘要格式白名单 | 行为变化 |

## Consequences

- MEME Tab 的发射台读真实曲线数据；`meme` 能力关闭或无会话时只显示一行不可用，不出现假数据。
- 能力文档多了 `meme` 一项，旧版本客户端会把整份能力文档判无效；本版起与后端 32 项一致。
- 所有曲线写操作只经共享签名出口；结果以 intent 状态为准，广播只说「已广播」。
- S118 裁定（2026-10-08）：持有者口径为「按曲线买卖统计」；测试网毕业代币底栏为「测试网不支持站内兑换」+ 复制池地址，
  主网才跳 Swap 预填；`residual` 非空才提示「外盘池已存在，部分资金留在合约」；毕业后无价格显示「暂无外盘报价」，
  价格来源新增 `pool_slot0`。
- S116b（loop-api 决策 0103）：`pool_slot0` 在 MEME 行与 `LoopFactSource` 里均标为「池子推算」；`category=meme`
  行情接受 `quality = derived`（行上可见标记「池子推算」，24h 涨跌与成交量为 null 时照常显示「涨跌未报告」）；
  `residual` 零头已由后端投影为 null，客户端只在非空时提示；毕业兜底 15 秒，代币页 full 状态每 5 秒重读。

## 偏离表

| 设计 / 契约 | 实现 | 原因 |
| --- | --- | --- |
| 签名意图种类 | 主交易 `IntentKind.launchPurchase`、授权 `IntentKind.launchApproval` | 曲线在 Launch 链槽位（契约 §12、决策 0038）；钱包边界只允许这两种离开主链。新增 `memeTrade` 要改 `lib/core` 与 Privy 签名器，超出文件边界，留给主代理决定 |
| 授权交易的摘要 | 授权与主交易共用 intent 的 `payloadDigest` | 契约只给一个 `payloadDigest`；授权无独立摘要 |
| 422 `MEME_METADATA_INVALID` 按 `field` 标红 | 只显示一句「资料不符合要求，请检查名称、符号、简介和链接」 | `LoopFailureDetails` 的白名单不含 `field`，放宽属于共享错误层；客户端校验已覆盖常见情况 |
| 关于 · 链接「点开」 | 点按复制链接 | 仓库没有 `url_launcher` 直接依赖，新增依赖需主代理批准 |
| 全屏图表复用 S113 `chart-full` | 未接 | `chart-full` 只接受登记资产 `assetId` 与 GeckoTerminal K 线；曲线 K 线无对应路由。毕业后「外盘行情」入口进 S113 代币页 |
| 分享复用 S109b 二维码卡 | 自有分享弹层：合约地址二维码（`LoopQrView`）+ 复制 + 系统分享 | S109b 卡只有用户 / 社区两种主体 |
| 搜索 `scope=meme` | 只跳 `/search` | 搜索页没有 scope 参数 |
| 创建草稿时机 | 离开第 2 步即 `POST /v2/meme/tokens` | 第 3 步要展示预测地址与 vanity（契约 §7）；返回修改内容会生成新草稿并占用额度，同内容不重复 |
| 首买「将得代币」 | 本机按曲线公式估算并注明「签名前以服务端报价为准」 | 草稿未上链，`/quote` 返回 `MEME_TOKEN_NOT_ON_CHAIN` |
| 曲线 1分 / 5分 时间轴 | 复用 S113 的 15 分刻度格式（时:分） | 不改 `LoopCandleInterval`（S113 文件边界） |
| `docs/routes-manifest.json`（LOOP 根目录镜像） | 未改 | 在 worktree 之外；需主代理按 `docs/product/routes-manifest.json` 同步 |

## 未验证项

- 真实 dev 后端联调（创建 → 买 → 卖 → 补满 → 毕业 → 去兑换）未跑：无设备会话；只做了 OpenAPI 对照与编解码契约测试。
- Privy 对测试网 97 的两次连续 `eth_sendTransaction`（nonce N / N+1）未在设备上验证。
- 图片上传在真机的裁剪与 community-logos 返回未验证。
- 毕业后的 Swap 预填：测试网代币不在 OKX / Privy Swap 资产里，预填只在资产列表包含该代币时生效。
- `flutter build apk --debug` 已通过（2026-10-09）；未在模拟器或真机上运行。
