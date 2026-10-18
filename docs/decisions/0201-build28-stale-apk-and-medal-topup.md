# 0201 · build 28 未含 0200；勋章页补「去充值」（S230-mobile）

## Status

Accepted 2026-10-18。基线 `integration/v2` dd29fed。依据：S227 用 build 28 staging APK 的走查四条（拒绝原话、重提后不刷新、
提交时间、「测试网合约还在核对」）与附带一条（铸造余额不足无「去充值」）；staging `GET /v2/meta/capabilities`（loop-api aefffe0）；
loop-api aefffe0 `src/routes/v2/launch.ts` hooks-config 路由、`src/database/hooks-launch-project-config-repository.ts`；
`LOOP/docs/22-Staging真人走查流程-MEME-v2.md` §3 第 4 条。不新增依赖、路由、token；`pubspec.lock` 不变；无新请求路径。

## Context

0200（dd29fed）宣称修好的四处在 build 28 真机上都没生效，单测全过。要回答「为什么测试过了真机不行」。

## Decision

### 1. 四处的共同根因：build 28 的 APK 不是 dd29fed 构建的

- `~/Desktop/Loop-Archive/Android/LOOP-v3-staging-profile-20261017-2317-dd29fed.apk` 与
  `…-20261017-1337-65d9a2d.apk` 字节相同（SHA-256 均为 `aa2235c6…5dc9`），也与主检出
  `build/app/outputs/flutter-apk/app-profile.apk`（修改时间 10-17 13:37）相同。23:16 那次只构建了 `app-debug.apk`（门禁的 `build apk --debug`），
  归档时拷走的是 13:37 留下的旧 profile 包，文件名却按当时 HEAD 写成了 dd29fed。
- 佐证（AOT 快照 `lib/arm64-v8a/libapp.so` 字符串检索）：0200 新增的 `LAUNCH2_TESTNET_EVIDENCE_PENDING`、`Launch2RefreshOnReturn`、
  「按当前曲线价计算」均为 0 处；同一时刻的 `app-debug.apk` 内核里分别有 2 / 10 / 2 处。S227 看到的列表副标题「审核未通过：材料不完整」
  正是 0200 之前的文案（0200 改为「已拒绝 · 材料不完整」）。
- 所以测试没漏：被测的是 dd29fed，装上手机的是 65d9a2d。四处无需改代码。
- 逐条对照真实响应，确认 0200 的生效条件在真实流程里走得到：
  - 拒绝横幅：hooks-config `approval = {configVersion, status: rejected, approvedAt: null, rejection: {reasonCode, note, at}}`，
    与 `hooks_config_rejected.json` 同形；编辑页读同一个 `launch2ProjectControllerProvider`，状态投影为 `rejected` 即出横幅。
  - 提交时间：`draft.updatedAt` 在 loop-api 里是该版本行的 `created_at`（`c.created_at as updated_at`），重提 v5 即 v5 的保存时间，`launch2LatestSubmission` 取到的就是 11:17。
  - 重提刷新：编辑页保存后 `pushReplacement` 到新的项目页，`save` 已作废两个 provider；栈下的旧项目页 / 我的项目回栈顶重读。
  - evidence：staging 实际返回 `launch2.evidence = {status: pending, reasonCode: LAUNCH2_TESTNET_EVIDENCE_PENDING}`，正是 0200 屏蔽的那个码。
    新增 `test/fixtures/s230/capabilities_staging.json`（staging 原样抓取）经 `DioLoopV2MetaRepository` 解码 → 投影 → `launch2EvidenceNoticeShown` 为 false。

### 2. 勋章页铸造余额不足没有「去充值」

- docs/22 §3 第 4 条要求「USD1 余额不足：需要 100 USD1」+「去充值」，且该流程从勋章页（按钮「铸造 1 枚 · 100 USD1」）铸造。
- 根因：0153 / 0154 只给项目页底栏的 `Launch2ActionFailureLine` 接了 `onTopUp` / `onFaucet`；勋章页（`launch2_nft_screen.dart`，0163 起）底栏只传了 `message`，
  `failure.topUp` 为真也不画链接。这一条与 APK 无关，dd29fed 上也缺。原测试只断言失败行存在，没断言链接。
- 修法：勋章页底栏失败行与项目页一致：`failure.topUp` 时「去充值」进钱包收款页（活动钱包 canonical id 时带 id），
  服务端公布 `testnetFaucet` 可用时旁边「领取测试币」，领取后重读该实例。键 `launch2-nft-bar-topup` / `launch2-nft-bar-faucet`。

## Consequences

- 需重新打 staging profile 包：在 dd29fed（或含本批的提交）上实际执行 `flutter build apk --profile --dart-define-from-file=config/staging.json`，
  归档前核对 `app-profile.apk` 的修改时间晚于构建开始、且 SHA 与上一个归档不同；可用 `unzip -p … lib/arm64-v8a/libapp.so | grep -c LAUNCH2_TESTNET_EVIDENCE_PENDING` 抽查（应 ≥ 1）。
- 后端无需配合。

## Tests

- `test/s230_staging_payload_test.dart`：staging 原样 capabilities → launch2 可用、evidence pending 且原因码为模块常量、项目页不画 evidence 行。
- `test/s182_launch2_desk_nft_test.dart` 新组 `S230 · decision 0201`：prepare 被拒 `LAUNCH2_USD1_BALANCE_INSUFFICIENT`（requiredUsd1 100、balanceUsd1 0）时
  底栏「USD1 余额不足：需要 100 USD1，当前 0 USD1」内有「去充值」，点了进 `/wallet/receive?walletId=…`；非余额拒绝不出「去充值」。
  首例在本批代码改动之前失败。`_Fake` 加可选 `nftError`。
