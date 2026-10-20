# 0218 · 他人主页：社区列表 + Launch 链持仓 / 交易（S261-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` a72bcf2f。对应 loop-api S260（决策 0169，与本批并行实现；本文件按派单契约落地，
0169 定稿若有出入以其为准并另起补丁）。不新增路由、不新增依赖、`pubspec.lock` 不变、不改 loop-api。

## Context

`user-profile` 的「社区」段一直是「已加入 N 个社区 / 社区列表暂未开放查看」，因为后端没有按人列社区的读口。
「持仓」「交易」只读主网（BSC）资产，演示账号在 Launch 链（测试网 97）的 MEME 持仓与买卖看不到。
loop-api S260 新增 `GET /v2/profiles/{id}/communities`，并在 `/holdings`、`/trades` 后面加开关 `PROFILE_LAUNCH2_EMIT`（默认 off）。
App 的 V2 解码器严格拒绝未知键，所以客户端必须先落可选键（0166 / 0213 同一规则），开关才可打开。

## Decision

1. **社区列表 codec**（新文件 `lib/integrations/backend/v2/community/loop_v2_profile_communities.dart`）：
   - 两种形状都严格：`{status:"available", items, nextCursor, contractVersion}` /
     `{status:"unavailable", reasonCode, contractVersion}`；其他 status、多 / 少键 → invalidPayload。
   - 行七键全必填：`communityId`（UUID）、`name`、`slug`（社区 slug 规则）、`logoRef`（社区 logo 规则或 null）、`memberCount`、
     `verificationStatus`（只认 `verified` / `unverified`）、`joinedAt`；行重复 → invalidPayload。
   - `unavailable` 任何合法 reasonCode（当前只有 `PROFILE_COMMUNITIES_HIDDEN`）都读作「对方未公开」。
   - 传输在 `DioLoopV2PublicProfileApi.communities`（`limit=20`，游标同 trades 规则），端口 `PublicProfileGateway.communities`。
2. **`/holdings` codec**：根对象改 `strictMapWithOptional`，唯一可选键 `launch2`（两种形状同 0213 的 `_launch2Leg`，复制到
   `LoopV2PublicProfileCodec.launch2Leg`，复用钱包模型 `LoopWalletLaunch2Leg`）。
   - `items[]` 有 `kind` 键 → Launch 链持仓行，十键全必填：`kind`、`chainId`、`instanceId`、`ticker`、`name`、`logoUrl`、
     `amountMeme`、`nftCount`、`stage`、`valueUsd1`；`kind` 非字符串 → invalid；未知 kind → 跳过该行。
   - `launch2_meme` 必须有 `amountMeme`，`launch2_nft` 必须有 `nftCount`，否则 invalid。`stage` 必须是 1–32 字符串，
     本版本不认识的阶段不判失败（行只写「Launch 链」）。金额按 launch2 18 位小数规则；logo 按 launch2 logo 规则（自家媒体或白名单）。
   - 无 `kind` 的行按原六键解析；`hidden` / `unavailable` 仍不许带任何行。
   - 模型：`ProfileHoldings.rows`（服务端顺序的混排）+ `items`（仍是主网行，派生）+ `launch2`。
3. **`/trades` codec**：根同样可选 `launch2`。主网交易行本身就有 `kind`（buy / sell / transfer_*），所以区分规则是：
   **有 `eventId` 的行**按原九键解析（未知 kind 仍判失败，保留既有测试）；**无 `eventId` 且有 `kind` 的行**是 Launch 链行，
   按 0213 的十四键严格解析（复制自 `loop_v2_wallet_api.dart` `_launch2Entry`，产出钱包模型 `LoopWalletLaunch2ActivityEntry`），
   未知 kind 跳过。模型：`ProfileTradesPage.rows` + `items`（主网）+ `launch2`；控制器翻页按 `rowId` 去重。
4. **页面**（`user_profile_screen.dart`）：
   - 社区段：行 = `CommunityLogo` 40 + 名称 + 「N 名成员」+ 右侧 `已验证` 淡黄胶囊（`LoopBadge` launch 档，yellowSoft 底黄字，附 C §4）；
     点行开 `communityProfileLocation(id)`；`LoopLoadMoreFooter` 翻页；`unavailable` →「对方未公开社区列表」空态；
     另有加载 / 空 / 离线 / 权限 / 不可用 / 错误态（社区服务 404/503 读作不可用）。
   - 持仓段：混排；Launch 行 = `MemeLogo` 36 + ticker + 名称，灰行尾注「Launch 链，阶段」（逗号，不用中点）；右侧 MEME 数量或「× N」，
     有 `valueUsd1` 时第二行「≈ N USD1」；点行开 `Launch2Route.instance`。`launch2.unavailable` → 列表顶一行
     `LoopUnavailableLine`「MEME 持仓暂不可用」+ reasonCode 文案，不是空态。
   - 交易段：混排；Launch 行直接用钱包的 `walletLaunch2ActivityRow`（0213），点行开项目页；`launch2.unavailable` → 顶部「MEME 记录暂不可用」。
   - 新增可选 `onNavigate`（缺省 `GoRouter.push`），`app.dart` 不改。
5. Preview（`memory_public_profiles.dart`）给两条演示社区，页面顶部已有「演示数据」提示。

## Consequences

- 开关 off 时线上行为不变；App 版本发出且旧版本退场后，服务端才可打开 `PROFILE_LAUNCH2_EMIT`。
- 社区新路径在服务端未上线时返回 404（无 `PROFILE_NOT_FOUND`）→ 社区段显示「社区列表暂时读不到」，不是空列表。
- 「我」页（自己的主页）没有持仓 / 交易 / 社区三段：自己打开 `user-profile` 会转交 `/profile`，那里的「我加入的」仍读社区模块的
  home 聚合（0073），本批不换成第二个来源。
- 持仓总额 `totalUsd` 仍只是主网资产的美元合计，Launch 链行的 USD1 估值不并入。
- 测试：`test/s261_profile_communities_launch2_test.dart`（三个 codec 的无键 / 有键 / unavailable / 未知 kind / 未知根键与行键拒绝；
  三段页面渲染、点击跳转、翻页、社区五态与 hidden）；`test/s109a_public_profile_test.dart` 的旧「社区暂未开放」断言改为读列表。
