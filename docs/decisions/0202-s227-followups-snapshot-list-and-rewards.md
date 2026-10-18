# 0202 · S227 中低缺陷与快照名单第一步（S233-mobile）

## Status

Accepted 2026-10-18。基线 `integration/v2` 5cfaba0。依据：S227 staging 补验报告（`LOOP/docs/integration/S227/report.md` ② 缺陷 S227-1…9）、
S232 快照名单调查、loop-api 40921be `src/database/launch2-repository.ts`（`listDynamicRewards` 以 `launch2_dynamic_buy_weights` 为主表）、
`src/features/launch2/launch2-stage.ts:88-96`（`snapshotPublishedAt` 有值即 `priority`）、loop-api 决策 0118（名单不返回地址）、
loop-contracts `LoopAccounting.sol`（`++currentRoundId`，轮次从 1 连续编号）。
只改 App：不新增依赖、路由、字体、颜色 token，`pubspec.lock` 不变，无新请求路径，不改 loop-api。

## Context

S227 用新包 5cfaba0 走了一遍 docs/22 v4，留下 S227-1（中）、S227-2（中，文档 / 产品二选一）和若干低级别文案问题。用户裁定：
快照名单做到「第一步」（两态 + 名单已发布区块，不显示地址），其余按条修，G（配置版本号按项目方全局递增）不改。

## Decision

### A. 快照名单第一步（S227-2）

1. **勋章页读真实的发布状态**。`launch2NftView` 的 `snapshot_pending` 原来写死「铸造已结束 · 名单生成中」，改为
   `铸造已结束 · ${launch2SnapshotPendingTitle(snapshot)}`，与项目页同一函数：`publication` 为空「名单生成中」，`pending / broadcast`「名单发布中」，
   `confirmed` 而尚未投影为已发布「名单已上链，同步中」，`failed / mismatch`「名单发布异常，平台处理中」。按钮文字不变。
2. **名单已发布区块**。新部件 `Launch2SnapshotPublishedBlock`（`launch2_widgets.dart`），`launch2SnapshotPublishedShown(detail)` 为真时画：
   `snapshot.published`、不是「无人持有直接公开」、阶段为 `priority / public / graduated`。项目页放在提前购 / 公开内盘的成交列表之后、
   已毕业页的回购卡之后；勋章页放在「我的勋章」之后。内容：名单人数（`snapshot.memberCount`，缺省用 `publication.memberCount`）、
   发布时间（`publishedAt`）、核验（`verified`「已核验」、`pending`「核验中」、`mismatch`「核验不一致，平台处理中」）、发布交易（短哈希）、
   一句「名单地址不在 App 内列出，可在发布交易里核对。」和按钮「在 BscScan 查看发布交易」。
   链接 `launch2ExplorerTxUri(chainId, txHash)`：`eip155:56` → `bscscan.com`，`eip155:97` → `testnet.bscscan.com`，其它链或无哈希不给链接；
   打开走 0196 的 `launch2ExternalLinkOpenerProvider`（系统浏览器，打不开则复制）。不显示任何地址。
3. **只在 snapshot_pending 提速**。`Launch2Polling.snapshotInterval`（默认 3 s）与 `intervalFor(stage, fast:)`：`fast`（可交易阶段或有待确认的广播）
   仍用 `tradingInterval`，`snapshot_pending` 用 3 s，其它用 `detailInterval`。项目页与勋章页同用；读到下一阶段后下一次定时即回到原频率
   （项目页提前购 5 s，勋章页 15 s）。
- **为什么「名单已发布」不是 snapshot_pending 的第三态**：后端在 `snapshotPublishedAt` 有值时直接把阶段切到 `priority`，`snapshot_pending` 里看不到 `published`。
  所以两态（生成中 / 发布中，偶尔「已上链，同步中」）+ 进入提前购后的「名单已发布」区块，是现有接口能给出的完整过程；无须后端改。

### B. 第三人「外盘奖励」页（S227-1）

- **根因**：`GET …/dynamic-pool/rewards` 只返回该钱包有权重的轮次（`listDynamicRewards` 从 `launch2_dynamic_buy_weights` join 轮次表）。
  没买过的人拿到 `rounds: []`，页面就画「还没有外盘奖励 · 价格 5 分钟内跌超 10% 将开启…」；最近一轮没权重的人看不到那一轮。
- **修法（只用已有数据）**：`launch2DynamicRewardEntries(rewards, pool)` 用 `dynamic-pool` 的 `summary.roundCount` 与 armed 时的 `currentRoundId`
  补出 1…N 的全部轮次（合约 `++currentRoundId`，从 1 连续编号），自己有记录的照旧画 `_RoundRow`，其余画 `_NoWeightRoundRow`：
  已结束「本轮没有可领取的奖励 / 你在本轮没有买入，没有奖励权重。」，进行中「你在本轮还没有买入 / 轮次开启期间买入即计入本轮权重…」，都没有按钮。
  最新在上；无记录的补位最多 50 轮（与 rewards 默认页大小相同）。「还没有外盘奖励」只在项目一轮都没开过（补完仍为空）时显示。
  自己有记录但 `no_reward` 的轮次按钮文字统一为「本轮没有可领取的奖励」。
- **后端须知**：不需要改。若以后要在 rewards 里直接带出无权重轮次（例如显示每轮奖金），可让 `listDynamicRewards` 以轮次表为主表 left join 权重；App 侧届时去掉补位。

### C. 用词统一（S227-3）

- 用户侧 MEME 列表 / 发射台：「白名单提前购」→「提前购进行中」（`launch2HeroHeadline`、`launch2RecordSubtitle`、发射台账本卡）。详情页阶段名仍是「提前购」。
- 公开页 `LOOP/ops/web/meme-page/app.js` 的阶段徽章「优先认购中」→「提前购进行中」（改前备份 `app.js.bak-S233`，未部署 Vercel）。

### D. 发起第 2 步（S227-4）

- 步骤名「社区」→「链接」；页内加 `.label`「外部链接」，说明改为「项目的 X / Telegram / 官网 / Discord，都可不填；审核与用户都会看到。」，
  另起一行「要绑定社区，请由社区群主在社区侧「社区管理 → 绑定代币」里操作。」。字段与校验不变。

### E. 第三人权重（S227-7）

- `launch2DynamicRoundRows` 的「本轮我的权重」：没有钱包，或钱包本轮权重 ≤ 0，都显示「暂无」，不再是「0 USD1 · 占 0%」。

### F. 部署进度返回项目页不刷新（S227-9）

- 在 5cfaba0 上不复现：项目页包在 0200 的 `Launch2RefreshOnReturn` 里；「去签名部署」push 签名页、签名页 `pushReplacement` 成部署进度，
  返回时项目页重新成为栈顶即重读。S227 看到的是旧包 65d9a2d（不含 0200）。本批不改代码，只补回归测试（去掉 onReturn 重读时该测试失败）。

### G. 配置版本号按项目方全局递增（S227-5）

- 不改。版本号由后端分配，App 只显示「配置版本 vN」。

## Consequences

- 快照阶段多 3 s 一次的详情读取，只持续到名单发布（通常 20 秒内）。
- 外盘奖励页对没买过的人也列出全部轮次；项目轮次很多时最多补 50 行。
- 名单仍看不到地址（0118）；需要看地址的人用 BscScan 发布交易核对。

## Tests

- `test/fixtures/s233/`：由 S171 BSC 测试网抓包派生（每个文件 `_derived` 写明改了什么）——`instance_snapshot_pending_{generating,broadcast,confirmed}`、
  `instance_priority_published`（快照对象原样，`verified`、`publication.confirmed`）、`rewards_third_person` / `dynamic_pool_third_person`（一轮已关、无权重）、
  `rewards_latest_round_without_weight` / `dynamic_pool_two_rounds`（第 1 轮已领、第 2 轮无权重）。
- `test/s182_launch2_desk_nft_test.dart` 组 `S233 · decision 0202`：勋章页三态文案；勋章页与项目页在 snapshot_pending 每 3 s 读一次、进入提前购后回到 15 s / 5 s；
  `intervalFor`；项目页与勋章页的名单已发布区块（人数、时间、已核验、短哈希、不出现签名人地址和完整哈希、点按钮打开 testnet BscScan）；
  显示条件与主网 / 测试网链接；列表行「提前购进行中」。原两处「白名单提前购」断言改为「提前购进行中」；`_pump` 加 `polling` / `extra`。
- `test/s168_launch2_dynamic_pool_test.dart` 组 `S233 · decision 0202`：第三人列出第 1 轮「本轮没有可领取的奖励」且无「还没有外盘奖励」；
  最近一轮无权重排在已领轮之上；从未开轮仍是空态；`launch2DynamicRewardEntries` 补位与进行中判定；armed 而本轮无买入「暂无」、无「占 0%」。
  原「no rounds yet」用例把 `summary.roundCount` 置 0（空态现在只属于从未开轮）。
- `test/s135_launch2_creator_pages_test.dart` 组 `S233 · decision 0202`：步骤条「资料 / 链接 / 发售」、第 2 步「外部链接」与社区提示、无「绑定项目的社区」；
  项目页 → 签名页 → `pushReplacement` 部署进度 → 返回，配置重读并显示已激活。
