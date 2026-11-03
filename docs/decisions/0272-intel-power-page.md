# 0272 · 情报「算力」页：挖矿 / 算力明细 / 邀请中心收拢，算力榜改二级页，价格提醒换闹钟

## Status

Accepted · 2026-11-03（S344-mobile）。依据 `LOOP/docs/56-页面精简-需求方脑图-2026-11-03.md` §二「情报」，以及主代理 11-03 追加：「我的挖矿」整页内容进「我的总算力」区。

## Context

需求方脑图：情报的算力榜改为「算力」页面——全网总算力（NFT / 代币）+ 排行榜图标进二级页（社区 / 用户 / 邀请）；我的总算力，下面 tab NFT / 代币 / 邀请（邀请 = 邀请中心 + 邀请加成）；行情页提醒图标与 App 通知区分。挖矿、算力明细、邀请中心三个二级页因此收拢进一页。

## Decision

### 情报分段与深链

- 分段「算力 / 行情」（原「算力榜 / 行情」）。算力段 = `MiningScreen(embedded: true)`；段行右上的 (i) 是「挖矿说明」（`miningInfoAction`，底部「查看挖矿规则」→ `mining-rules`）。邀请 tab 的说明经 `LoopInfoButton` 汇入同一个 (i)（0255 一页一个 (i)）。
- 深链：`/intel?tab=power|market`、`&sub=nft|token|invite`、`&code=<邀请码>`（`IntelPowerRoute`）。`IntelScreen` 在下一帧应用请求（段记忆 / `intelPowerTabProvider` / `intelPendingInviteCodeProvider`），然后 `go('/intel')` 清掉查询，同一链接再次打开会再次生效。

### 算力段结构（自上而下）

1. 全网总算力卡 `MiningNetworkPowerCard`：总数 + NFT / 代币两格，右上皇冠图标 → `mining-rank`。拆分取 `GET /v2/mining/rewards` 的 `hourly.tracks.nft.networkPower` / `tracks.asset.networkPower`（上一结算小时，标「上一小时」，总数 = 两者之和，与 0253 同口径）；没有结算小时时只显示 `summary.networkPower` 总数，不画拆分。
2. 我的总算力卡（原「我的挖矿」大卡，kicker 改「我的总算力」）：总算力、快照时间（没有快照时间整行不画）、名次、格子（LOOP 上线前按 0184 为「上一小时算力 / 有效邀请」，全网算力格去掉——已在上方卡；上线后为「今日预估 / 累计已挖 / 待领取」）、按钮（上线前「挖矿奖励」、上线后「领取奖励」，都 → `mining-rewards`）。主代理截图验收后去掉：我的代币 / NFT 拆分两格（下方 tab 已有）、「当前算力公式」等公式范围 chip（在 (i) 里）。「算力明细」第二按钮在没有 `onOpenAssets` 时不画。
3. 快照来源行 + 「有权重的社区币」一行（→ `market`）。「算力排行榜」「邀请加成」两行去掉（分别由排行榜图标与邀请 tab 承担）。
4. Tab `NFT / 代币 / 邀请`（`LoopSegBar`，默认代币）：
   - 代币：0253 的代币组（小计 + 行 = power − nftPower）；无拆分时为原单列表；末尾「未计入的资产」（原 `mining-assets` 的排除列表；这里只留「未计入」标签和地址，不印服务端原因句）。
   - NFT：0253 的 NFT 组；无拆分时一行「NFT 算力暂未单独提供」。
   - 邀请：`ReferralCenterSections`（邀请卡 + 五级、我的邀请、邀请加成、邀请列表、我的邀请人 / 绑定），与原邀请中心同一套读与绑定逻辑；邀请链接带来的码在这里提示一次。不加解释句（需求方 10-26）：邀请链接未开放时整块「邀请链接」不画（只留邀请码、复制、生成海报）；`stats` 未下发时「我的邀请」整节不画；邀请加成未批准时整节不画；邀请列表空态只一行「还没有邀请」。`ReferralScreen` 同步。
- 挖矿能力关闭时不再整页封锁：在卡片位置显示 `LoopCapabilityBlockCard`，tab 仍在，邀请（独立能力）照常可用。

### 算力榜二级页

- `mining-rank`（`/mining/rank`）渲染 `IntelRankBoard(onBack: …)`：标题「算力榜」、我的名次卡、`社区 / 用户 / 邀请` 三段（第三段原「邀请中心」改「邀请」，段内不再嵌邀请中心卡）、领奖台；作为独立页带情报墙背景。`mining-community` 的「查看排行榜」仍到这一页。旧 `MiningRankScreen` 不再挂路由。

### 重定向

- `mining`（`/mining`）、`mining-assets`（`/mining/assets`）→ `/intel?tab=power`；`referral`（`/profile/referral[?code=]`）→ `/intel?tab=power&sub=invite[&code=]`。邀请链接 `/i/{code}`、扫码结果仍指向 `/profile/referral?code=`，随之转到邀请 tab。
- 实现为 `LoopRouteForward`（`NoTransitionPage`，页面到位后一帧 `go`）。不用路由级 `redirect`：从壳外页面 `push` 一个重定向进 `StatefulShellRoute` 分支的地址，会克隆出第二个壳，`StatefulNavigationShell` 的 GlobalKey 重复报错（已用最小用例复现）。
- 路由清单数量不变，只改目标。`mining-assets` 的「查看社区挖矿面板」死行删除；`MiningAssetsScreen` 类保留但无路由。

### 价格提醒图标

- 新增线性图标 `alarm`（闹钟，24 box、1.7 描边，同 sprite 规范），情报行情段与 `/market` 的「价格提醒」都用它；App 通知继续用 `bell`。图标总数 72 → 73。

## Consequences

- 全网算力的 NFT / 代币拆分只有上一结算小时口径；若要与快照总数同口径，需要 `GET /v2/mining/summary` 增加可选键（如 `networkAssetPower` / `networkNftPower`），客户端按 0253 的方式先落可选键。
- 我的 NFT / 代币明细依赖 `summary.assetPower` / `nftPower` 与 `included[].nftPower`（0253 可选键）；服务端未发时 NFT tab 显示不可用一行，代币 tab 显示全部计入行。

## Amendment · 2026-11-03（S347 · docs/57 N1 / N4）

- 算力榜（`/mining/rank`，含从挖矿社区页进入的同一页）点本人行改走 `LoopProfileFaceLink.push`（`/wallet` 是 Tab，用 `go`），不再经 `onNavigate` 把 Tab `push` 到壳上触发 Navigator 断言；路由层 `onNavigate` 也按 `Uri.parse(location).path` 判 Tab 则 `go`、否则 `push`（`_goTabOrPush`，`_profileScreen` 共用）。
- 删除仅测试引用的死代码：`MiningAssetsScreen`、`MiningRankScreen`（及其私有行 / 折叠 / 来源块）、`ReferralScreen`、整个 `intel_referral_board.dart`（`IntelReferralBoardSection` / `ReferralBoardController`）。`miningExcludedRow`、`_assetSymbols`、`ReferralCenterSections` 等仍被情报 · 算力使用的部分保留。
- 对应旧测试：只测这两个页面的用例删除；测 `ReferralScreen` 的用例改为挂 `test/support/referral_center_host.dart`（`ReferralCenterSections` + 邀请 tab 同款 (i)），只依赖旧页面外壳（页面标题、能力拦截块、页面级「更新中」、失败态下的页面 (i)）的 5 条删除。
- 回归测试：`test/s347_regressions_test.dart`（本人行 `go('/wallet')`、`/mining/rank` 与社区页进入的榜到 `/wallet` 不崩、`profileDestinationPath('invite')` 经 `_profileScreen` 落到情报 Tab）。
