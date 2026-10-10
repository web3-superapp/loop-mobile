# 0136 · 加入社区即免打扰改由服务端完成；客户端不再抢在频道同步前 `mute()`（S135）

## Status

Accepted 2026-10-10。主代理下单（S135-mobile），基线 `integration/v2` 84ca5c4，分支 `fix/S135-join-mute`。
配套 loop-api 决策 0115（同批 `fix/S135-join-mute`）。不新增依赖，路由清单不变，视觉 token 不变。

## Context

2026-10-10 模拟器验收（`docs/acceptance/2026-10-10-privy-switch-emulator.md`）：引导页一次加入 5 个社区，
4 个显示「已加入，但免打扰没有设置成功」。原因：`OnboardingCommunitiesController.enter()` 在
`POST /v2/communities/{id}/join` 返回后立刻用 `CommunityChannelMuter`（Stream `client.muteChannel`）静音，
而把账号加进 Stream 频道成员的是 loop-api 的 `community-channel-sync` 异步 lane；非成员的 mute 被 Stream 拒绝。
第一个成功只是 lane 恰好先跑完。

## Decision

1. **join 带偏好，服务端静音。** `CommunityGateway.join(id, {notifications})`，引导页的「加入并进入」一律传
   `CommunityNotificationPreference.muted` → 请求体 `{"notifications":"muted"}`；默认值（社区页、目录行的普通「加入」）
   不带 body，与旧请求逐字节一致。muted 的 join 使用独立的幂等 keyring 签名 `join:{id}:muted`（服务端把 muted 绑进摘要）。
2. **引导页不再调 `CommunityChannelMuter`。** 端口与 `communityChannelMuterProvider` 保留，留给会话页手动静音。
3. **新读接口与轮询。** `CommunityGateway.loadMembershipSync(id)` → `GET /v2/communities/{id}/membership`
   （`membership` / `notifications` / `channelSynced`）。加入成功的行先显示「已加入 · 免打扰生效中」；
   `settleMutes()` 每 1 s 读一次、最多 10 轮，`channelSynced == true` 的行改为「已加入 · 已免打扰」。
   - 全部加入成功：等全部确认或 10 轮结束后自动进入 LOOP；等待期间按钮是「进入 LOOP」，随时可点离开（只离开一次）。
   - 有失败：页面停留说明失败行（同前），成功行照样轮询换字。
   - 某行读失败（例如旧后端没有这个接口，404）：该行停止等待、保持「免打扰生效中」，不算失败。
   - 10 s 内没确认：保持「免打扰生效中」并照常进入——服务端仍会完成静音，页面只是不再等。
4. **结果枚举。** `OnboardingJoinResult.joinedNotMuted` 删除，换成 `joinedMutePending`（不是失败，`isJoined`）。
5. **codec 向后兼容。** `LoopV2CommunityMembershipSyncCodec` 对 `notifications` / `channelSynced` 两个字段按可选读取：
   缺失读作 `notifications: null, channelSynced: false`，不报错；其余键仍严格（多键、别的社区 ID、非法取值都是 invalid）。
6. **预览网关**（memory）没有频道 lane：已加入即 `channelSynced: true`。

## Consequences

- 引导页一次加入多个社区不再出现「已加入，但免打扰没有设置成功」：静音只在服务端把账号加进频道之后发生，不再和异步同步赛跑。
- 引导页「进入 LOOP」在全部加入成功后最多多等约 10 s（通常一轮 lane 间隔约 5 s），期间可直接点「进入 LOOP」离开。
- 新 App 依赖 loop-api 决策 0115：后端必须先部署，否则 muted join 会被旧后端拒成 400。
- `CommunityGateway` 多了 `loadMembershipSync`，`join` 多了可选 `notifications`；所有实现（生产、预览、测试替身）已同步。

## 未做 / 偏离

- 社区页（详情页「加入」、目录行「加入」）在基线里没有「加入并免打扰」动作，只有普通加入，本批保持 `default`，不改行为。
- 「下次进入会话时读」未做：会话页的静音状态本来就读 Stream 频道自身的 mute 状态，不依赖本接口。
- 部署顺序：新 App 发 `{"notifications":"muted"}` 给旧后端会被旧后端的「join 不收 body」规则拒成 400，
  所以 loop-api（决策 0115）必须先于这个 App 构建上线。

## 验证

- `test/s109a_onboarding_communities_test.dart`：join 请求全部带 muted、`CommunityChannelMuter` 一次也没被调用；
  文案「已加入 · 免打扰生效中」→ 第二次轮询后「已加入 · 已免打扰」并自动离开；10 轮未确认保持「生效中」且离开；
  等待中点按钮只离开一次；读接口失败立即结束等待。
- `test/community_api_contract_test.dart`：default join 无 body / 无 content-type，muted join 只发 `{"notifications":"muted"}`；
  membership 读是普通 GET（无 Idempotency-Key）且完整解码；缺两个新字段不报错；多键 / 别的社区 / 非法值拒绝。
