# 0213 · 钱包交易历史接入 Launch 链 MEME v2 行（S252-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` faaccbc7（含 0212 视觉规范 v2）。对应 loop-api 决策 0167 / S251（`integration/v2` 4cb7311，
`docs/frontend-v2-wallet-api.md` §7.1，OpenAPI `GET /v2/wallets/{walletId}/activity`）。不新增路由、不新增依赖、`pubspec.lock` 不变、不改 loop-api。

## Context

演示账号「晚风」的 MEME 买卖都在 Launch 链（测试网 97），钱包「交易历史」只读主网 ERC-20 转账，所以是空的。loop-api 0167 在
`/activity` 后面加了开关 `WALLET_ACTIVITY_LAUNCH2_EMIT`（默认 off）：开时根对象多一个可选键 `launch2`，`items[]` 混入带 `kind` 的 14 键新行。
App 的 V2 解码器严格拒绝未知键（整页 invalidPayload），所以这个开关必须等支持新键的 App 版本先发出去才能打开（0167 §F、0209 同一规则）。

## Decision

1. **codec**（`loop_v2_wallet_api.dart` `getActivity`）：根对象由 7 键 `strictMap` 改为 `strictMapWithOptional`，唯一可选键 `launch2`。
   - `launch2` 两种形状都严格：`{status:"available", chainId, indexerBlockNumber, headBlockNumber|null}`（四键）或 `{status:"unavailable", reasonCode}`（两键）；其他 status 或多 / 少键 → invalidPayload。
   - `items[]` 逐行：**有 `kind` 键**按 14 键严格解码为 MEME v2 行；**没有 `kind`** 走原转账解码（14 键不变，仍拒绝未知键）。
   - `kind` 不是字符串 → invalidPayload；`kind` 是本版本不认识的值 → **跳过该行**（以后新增 kind 不打坏旧版本）。
   - 字段校验：`chainId` CAIP-2 模式；`instanceId` UUIDv4；`ticker` 按代币代码规则（0206），长度按契约 80 字符放宽到 160 UTF-16 单元；
     `name` 按 provider 文本（1–64 码点，去掉危险码位）；`logoUrl` 按 launch2 logo 规则（自家媒体或白名单主机，否则当作无图，不判整页失败）；
     三个金额为 18 位小数十进制字符串或 null；`transactionHash` / `logIndex` / `blockNumber` / `occurredAt` / `confirmations` 同转账行规则。
   - 键缺省（开关 off）时解析结果与之前完全相同：`rows == items`，`launch2 == null`。
2. **模型**：新增 sealed `LoopWalletActivityRecord`（`entryId`、`at`），`LoopWalletActivityEntry`（转账）与新的 `LoopWalletLaunch2ActivityEntry`
   都是它的子类；`LoopWalletLaunch2ActivityKind` 七值；`LoopWalletLaunch2Leg`（available / unavailable）。`LoopWalletActivityPage.rows` 是服务端合并顺序的完整列表，
   `items` 仍是其中的转账（导出 CSV、资产页「最近活动」、收到 / 发出筛选不变），`launch2Items` 是其中的 MEME 行。
   MEME 行的 `entryId` = `launch2:{chainId}:{tx}:{logIndex}:{kind}`，与转账键不会相撞；翻页按 `rows` 去重。
3. **页面**（`tx-history`「全部」段）：
   - 混排渲染 `rows`，按本地日分组不变。MEME 行：左侧项目 logo 40（无图或加载失败用首两字的 `MemeLogo` 字母底）；
     标题「买入 X」「卖出 X」「铸造勋章 · X」「领取奖励 · X」「回购 · X」（内盘外盘同词）；副标「时间，Launch 链」，`confirmations == null` 时追加「确认中」（附 C 不用中点串）；
     右侧：买入 `-N USD1` rise、卖出 `+N USD1` fall，第二行 MEME 数量（买入 `+`、卖出 `-`）；铸造 `-N USD1` 中性色；领奖 `+N USD1` rise；
     回购是收币地址收到 MEME，第一行 `+N 代币`、第二行「花费 N USD1」。
   - 点 MEME 行跳 `Launch2Route.instance(instanceId)`（`/launch2/instance?id=`）；转账行仍开详情 sheet。`TransactionHistoryScreen` 新增可选 `onNavigate`，缺省 `context.push`。
   - `launch2.status == unavailable`：「全部」列表顶部一行 `LoopUnavailableLine`「MEME 记录暂不可用」+ reasonCode 文案（新增 `LAUNCH2_INDEXER_NOT_STARTED`、`LAUNCH2_ACTIVITY_READ_FAILED` 两条中文），不是空态。
   - MEME 行用 48 高的 logo 槽，使 flat 行高为 64（附 C §4）；转账行仍是 flat 统一的 56（`LoopFlat.rowHeight`，全局值，本批不动）。
   - 「收到 / 发出」两段只列转账；「原生转账」「跨链 / 挖矿」两段不变。
4. **数据注入**：`loopV2WalletApiProvider` 给 `DioLoopV2WalletApi` 传 `loopV2MediaUrlResolverProvider` 的 `urlFor`，让 MEME 行的自家媒体 logo 能通过校验。

## Consequences

- 开关 off 时线上行为不变；本 App 版本发出且仍受支持的旧版本都 ≥ 本版本后，服务端才可在目标环境把 `WALLET_ACTIVITY_LAUNCH2_EMIT` 切到 on（0167 §F.4）。
- 开关切换会使客户端手里的旧游标 400 一次：现有规则下「继续加载」显示本页错误，下拉刷新从第一页重拉；本批未加「400 自动回第一页」。
- 导出 CSV 仍只导出转账行（MEME 行不进 CSV）。
- 测试：`test/s252_wallet_activity_launch2_test.dart`（codec：无键 / 有键混排 / head 不可读 / unavailable / 未知 kind 跳过 / 非字符串 kind / 未知根键 / 转账行未知键 / MEME 行多键少键 / launch2 块多键与错 status / 金额格式；页面：混排渲染与顺序、涨跌色、确认中、行高 ≥ 64、点击跳项目页、收到段不含 MEME 行、unavailable 顶部提示、空 / 加载 / 离线 / 权限 / 不可用 / 错误态）。
