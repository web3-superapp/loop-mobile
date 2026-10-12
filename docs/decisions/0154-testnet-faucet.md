# 0154 · 测试网领取测试币（S156-mobile）

## Status

Accepted 2026-10-12。用户 2026-10-12 裁决，主代理下单（S156-mobile），基线 `integration/v2` 5a5b615，分支
`feat/S156-testnet-faucet`。后端契约以任务单为准（loop-api S156 同时在做，本批编写时 loop-api 尚无实现可核对）。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变、签名出口不动（领取不经钱包签名，服务端发币）。

## Context

测试网阶段新钱包零余额，付不起手续费也买不了 MEME v2。需要 App 内一个入口：服务端给当前内置钱包发 0.02 tBNB + 500 tUSD1，
每钱包每 24 小时一次。入口只看服务端能力位，不看本地 build flag，主网构建自然不显示。

## Decision

### 1. 能力位 `testnetFaucet`

- `LoopV2CapabilityId` 追加第 34 个 id `testnetFaucet`（在 `launch2` 之后），harness 钉 34 个。
- 与 `launch2` 一样可缺省：S156 之前的后端不发这一行，解析器补一行 `unavailable` + 客户端自有码
  `TESTNET_FAUCET_CAPABILITY_ABSENT`（`DioLoopV2MetaRepository.testnetFaucetAbsentReasonCode`），evidence `notApplicable`。
  其余 id 仍严格必需。
- 可见条件 `testnetFaucetVisible(ref)`：能力位 `isUsable`（available 且无 pending 前置）且 `testnetFaucetGatewayProvider`
  不是 unavailable 默认。不满足时**不渲染任何组件**（不是隐藏、不是占位）。

### 2. 端口与适配器

- 端口 `lib/features/wallet/testnet_faucet/testnet_faucet_gateway.dart`：`loadStatus(walletId)` / `claim(walletId)`，
  生产默认 `UnavailableTestnetFaucetGateway`；`lib/main.dart` 挂 `loopV2TestnetFaucetGatewayProvider`（缺 Dio / 元数据 / 会话即回落默认）。
- 适配器 `lib/integrations/backend/v2/testnet_faucet/`：`GET /v2/testnet/faucet?walletId=`、`POST /v2/testnet/faucet`
  （`Idempotency-Key` 由 `LoopV2CommandKeyring` 给出，签名 `testnet:faucet:<walletId>`，结果未定时重放同一 key）。
- 严格 codec：每个对象键集合精确（缺键 / 多键判无效）；金额是十进制字符串转 `Decimal`，必须 > 0；`cooldownSeconds` 整数 1–31 天；
  `available == (nextAvailableAt == null)`；`lastGrant` 两个 hash 至少一个非空；201 两笔转账 hash 都必需，`nextAvailableAt` 必须晚于 `grantedAt`；
  返回的 `walletId` 必须等于请求的。地址 / hash 接受大小写，统一存小写。
- 错误：先按七字段错误体校验，再分流——
  - `429 RATE_LIMITED` + `TESTNET_FAUCET_COOLDOWN` → 值 `TestnetFaucetCoolingDown(nextAvailableAt)`（`detailsSafe.nextAvailableAt`，读不出则为 null，拒绝仍成立）；
  - 502 / 503 + `TESTNET_FAUCET_PARTIAL` → 值 `TestnetFaucetPartial`（`detailsSafe.bnbTransactionHash` / `usd1TransactionHash`，各自可缺、坏值丢弃）；
  - 其余照常成 `LoopChainException`（reasonCode 透传）。写错误表加 `502: PROVIDER_UNREACHABLE`。

### 3. 钱包 Tab

- 四个快捷键下、「资产」标题上一行卡片（`LoopRecordGroup` 单行，图标 droplet）：「领取测试币」+「测试网专用 · 0.02 tBNB + 500 tUSD1 · 每 24 小时一次」。
  只在已选定当前钱包时出现（在有 walletId 的分支里）。
- 点开底部抽屉 `TestnetFaucetSheet`：说明（读到状态后用服务端金额）、「收币钱包」地址缩写、按钮「领取」。
  - 读状态中「正在读取领取状态…」；读失败 / 离线 / 无权限 / 不可用各自 key 的提示 +「重试」。
  - 进行中按钮「正在发放…（约 30 秒）」并置灰。
  - 成功：「已发出 0.02 tBNB 和 500 tUSD1，到账以链上确认为准，余额会自动刷新。」+ 两行 hash（复制哈希 / 复制 BscScan 测试网链接），
    立即 `walletBalancesControllerProvider(walletId).reload()`，钱包页另刷 MEME v2 持仓。
  - 冷却（状态 `available:false` 或 429）：按钮置灰「下次可领 HH:mm」（本地时区；非今天时前缀「明天」或「M月d日」）。
  - 文案：operator 不足「测试币池暂时不足，请稍后再试」；非本人钱包「只能给当前登录的内置钱包领取」；
    partial「tBNB 已到账，tUSD1 这次没成功，24 小时后可再领」（反向时对调，都没 hash 时「这次只发出了一部分测试币…」）；
    DISABLED「测试币领取已关闭」；WRONG_CHAIN「当前网络不是测试网，不能领取测试币」；OPERATOR_NOT_CONFIGURED「测试币领取暂时不可用，稍后再试」。

### 4. MEME v2 余额不足联动

- `Launch2ActionFailureLine` 加 `onFaucet` / `faucetKey`：只在有「去充值」时、且调用方给了 `onFaucet` 时，在其右侧加「领取测试币」（同款 44 dp 次要链接）。
- 项目页 `_faucetAction`：`testnetFaucetVisible` 且当前钱包 id 规范才给回调；打开同一个抽屉，领取成功后重读该项目。
  key：底部栏 `launch2-bar-faucet`、曲线面板 `launch2-trade-faucet`、官方池面板 `launch2-pool-faucet`。

### 5. 与 loop-api S156（8c1927a）对齐后的补充

- `lastGrant.bnbTransactionHash` 必填，`usd1TransactionHash` 可为 null（部分到账 / 结果未知时 tUSD1 没铸出）；POST 201 两笔 hash 仍都必填。
- 两个路由的允许错误表都加 `409 RESOURCE_CONFLICT` 与 `502 PROVIDER_UNREACHABLE`。
- 新 reasonCode 中文：`USD1_NOT_CONFIGURED` / `RPC_NOT_CONFIGURED` / `RUNTIME_UNAVAILABLE`「测试币领取暂时不可用，稍后再试」；
  `USD1_UNAVAILABLE`「tUSD1 合约暂时不可用，稍后再试」；`CHAIN_READ_FAILED`「链上读数暂时取不到，稍后再试」；`BUSY`「正在给别人发放，几秒后再试」；
  502 `TRANSFER_FAILED`「这次没有发出，可以重试」（不计冷却，按钮保持可点，key 已释放，重试用新 key）。
- `TESTNET_FAUCET_SUBMISSION_UNKNOWN`（503，带 `bnbTransactionHash` 与 `nextAvailableAt`）按部分到账处理，`unconfirmed`：
  「tBNB 已发出但还没确认，tUSD1 这次没发；24 小时后可再领」。部分到账同样读 `detailsSafe.nextAvailableAt` 作为「下次可领」。
- `409 RESOURCE_CONFLICT` + `TESTNET_FAUCET_IN_FLIGHT` → 值 `TestnetFaucetPending(inFlight)`：不报错，按钮保持「正在发放…」，
  每 3 秒 GET 一次（最后一次在 20 秒），`lastGrant` 出现（且不同于打开抽屉时那条）即按成功 / 部分到账显示并刷新余额；仍没有则「结果稍后在这里查看」。
- `503 REQUEST_TIMEOUT` → 值 `TestnetFaucetPending(timedOut)`：立即 GET 一次、3 秒后再一次；`lastGrant` 出现按成功显示，两次都没有则「发放还在进行，稍后再进来看」。
- 轮询期间只读状态，从不再次领取。429 `detailsSafe` 形状 `{reasonCode, nextAvailableAt}` 与实现一致。

## 偏离

- 「可打开 testnet.bscscan 链接」：App 没有组装外部浏览器启动器（`url_launcher` 不是直接依赖），沿用现有链接组件的做法——复制 BscScan 链接。
- 冷却时间超出今天时加日期前缀，避免只写 HH:mm 被读成今天。

## Fixtures / 测试

- `test/s156_testnet_faucet_test.dart`：loop-api 8c1927a 真实样例（GET 领取前 / 部分到账后、POST 201、partial detailsSafe 有无 tUSD1 hash）；codec 正例 / 缺键 / 多键 / 坏值；传输层 Idempotency-Key 与 body、GET query、429 冷却、502/503 partial、
  503 operator 不足与 403 非本人保持拒绝；钱包页能力位 unavailable 无入口、有能力位无适配器无入口、可用时入口位置、抽屉、进行中、两笔 hash、余额重读；
  冷却置灰与时间；429 文案；partial 文案与 hash；operator / 非本人文案；读状态离线 / 无权限 / 重试；409 进行中轮询成功与 20 秒提示；503 超时重读成功与两次都没有；结果未知文案；发放失败可重试；新 reasonCode 文案；时间与 partial 文案单测。
- `test/s136_launch2_user_test.dart`：能力位可用时 NFT 底部栏 USD1 / tBNB 不足出现「领取测试币」并打开抽屉、领取后重读项目；非余额拒绝两个链接都无；
  能力位关闭时只有「去充值」；曲线面板链接在确认按钮上方。
- `test/loop_v2_meta_repository_test.dart` / `test/s7_api_contract_test.dart`：34 个 id，`testnetFaucet` 可缺省读作 unavailable，两个可缺省 id 同时缺也能解析。
- `test/support/testnet_faucet_fakes.dart`（新）；`s5MetaSnapshot(testnetFaucet:)`、`FakeWalletReadGateway.balanceReads`。

## Consequences

- 测试网新钱包可以在钱包 Tab 或 MEME v2 余额不足提示里一步拿到手续费与试用 USD1，不再需要外部水龙头。
- 主网后端不发 `testnetFaucet` 或发 unavailable，入口与联动链接都不出现；无需任何本地开关。
- 能力位变为 34 个；之后新增可缺省 id 继续走 `omissibleCapabilities`。

## 未决项

1. partial 键名、502 码、成功体无 `contractVersion` 已由 loop-api S156 8c1927a 样例确认（样例进了 codec 正例测试）。
2. tUSD1 余额在钱包 Tab 是否有展示行取决于钱包余额 / MEME v2 持仓接口，本批只负责触发刷新。
