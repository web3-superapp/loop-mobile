# 0246 · 「我的钱包」开放绑定外部钱包与解绑（S306-mobile）

## Status

Accepted 2026-10-25。基线 `integration/v2` d5f46cc5（含 S305 Reown 修复）。主代理下单 S306-mobile，依据用户 2026-10-25 裁决。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api。`/v2` 只做「客户端先行」的可选键与一个可缺省的同步调用（见下）。

## 用户裁决（2026-10-25）

1. 外部钱包计入算力（服务端默认）。
2. 每个账号最多 3 个外部钱包。
3. 钱包已属于另一个账号时不合并：提示用户先在那个账号解绑，再回来绑。
4. 外部钱包地址默认不对外展示（服务端开关，App 不做）。
5. 随时可解绑。

## Decision

1. **「+」= 连接外部钱包。** `wallets-add-action` 不再弹「暂不支持绑定第二个钱包」。点击顺序：
   - 钱包清单未读到 → toast「钱包清单还没有读到，读到之后再连接外部钱包。」
   - 已绑定数 ≥ 上限 → `wallets-limit-sheet`「最多绑定 N 个外部钱包，请先解绑一个，再连接新的钱包。」不调 Reown。
     已绑定数取「清单里 status=active 的外部钱包数」与「会话里 Privy externalEvmCredentials 数」的较大者（服务端清单有短时缓存，刚绑完可能还没出现）。archived 行不计。
     上限取值顺序：`GET /v2/wallets` 根上的可选键 `externalWalletLimit` → `/v2/meta/client-policy` 的可选键 `externalWalletLimit` → 默认 3（`loopDefaultExternalWalletLimit`）。
   - 本机首次 → 一次性说明 `wallets-add-sheet`（取消 / 继续连接）。继续后写入本机布尔 `loop.display.v1.external_wallet_intro_seen`（SharedPreferences，与 0186 同一模式；读不到就再显示，不跳过）。
   - 调用既有 `EmailAuthController.connectExternalWallet`（已登录 → `ExternalWalletCredentialIntent.link` → Privy `siwe.link`）。成功：toast「外部钱包已绑定」并刷新清单；失败：toast 错误文案；取消：无提示。
2. **解绑。** 外部钱包行点按打开 `wallets-external-sheet`：非使用中时含原「切换」（`wallets-activate-confirm`，文案与原确认一致），另有「解绑这个钱包」。二次确认 `wallets-unlink-sheet`：「解绑后这个钱包的持仓从下一小时起不再计入算力。钱包 0x… 里的资产不受影响，之后也可以重新绑定。」确认后 `EmailAuthController.unlinkExternalWallet(address)` → 新增网关方法 `PrivyCredentialGateway.unlinkSiwe` → privy_flutter 0.11.0 `privy.siwe.unlink(address:)`。若会话的 Privy 凭据里有同一地址（大小写不敏感），发送 Privy 自己的拼写。成功：会话账号摘要更新、toast「已解绑外部钱包」、刷新清单。archived 行不可点。
3. **刷新 = 先请求同步，再重读。** 新端口 `WalletInventorySyncGateway.requestSync()`（生产适配器 `POST /v2/wallets/sync`，无 body、无 Idempotency-Key、不读响应体；404/405/任何失败都返回 false、不抛）。`WalletDirectoryController.resyncInventory()` 先调它，再走原 `reload()`（`GET /v2/wallets`）。服务端未部署该路由时等价于原刷新。
4. **错误映射。**
   - privy_flutter 0.11.0：`siwe.link` 失败为 `PrivyAuthException(flow: 'siwe', stage: 'link')`，平台码 `SIWE_LINK_ERROR`；`siwe.unlink` 失败为 `PrivyAuthException(flow: 'unknown', stage: 'unlink')`，平台码 `UNLINK_ERROR`。两者的 `message` 都是 Privy 原生消息原样透传，SDK 不给「已被他人绑定」的独立错误码，所以仍按消息匹配（同 0064 / 0134 的做法）。
   - 「已绑定在别的账号」：消息含 `linked_to_another_user` / `another user` / `another account`，或含 `already` 且含 `linked` / `exists` / `associated` / `user` / `account` → 「这个钱包已绑定在另一个 LOOP 账号上。请先用那个账号登录并解绑，再回来绑定。」（`externalWalletLinkedElsewhereMessage`）。只用于 link；SIWE 登录的映射不变。
   - link 网络类 → 「钱包凭据提交失败，请检查网络后重试。」；其它 → 「钱包绑定没有完成，请重试。」
   - unlink 网络类 → 「解绑没有完成，请检查网络后重试。」；含 `last` / `at least one` / `only login` / `only linked` → 「这是账号唯一的登录方式，不能解绑。请先绑定邮箱或其他登录方式。」；其它 → 「解绑没有完成，请稍后重试。」
   - Reown 侧沿用 `ExternalWalletConnectorException.userMessage`（网络、回跳、超时等）。link 意图下 `cancelled`（关掉钱包列表）与 `rejected`（拒绝连接或签名）静默，不留错误；登录意图保持原样（仍显示「已取消钱包连接。」）。
   - `connectExternalWallet` 改为返回 `ExternalWalletConnectOutcome { ignored, loggedIn, linked, cancelled, failed }`；既有调用点忽略返回值，行为不变。钱包页读完文案后 `clearFeedback()`，不把文案留给其它页面。
5. **文案。** 说明弹层三条：「外部钱包只用于计算算力，不能在 LOOP 内交易或领奖励；LOOP 不会获取你的私钥。」「所有绑定钱包的持仓都计入算力 / 已绑定钱包里的社区币都会计入算力，不用把资产搬到某一个钱包。」「大陆网络需要开 VPN 才能连接外部钱包。」「开放之后会发生什么」「暂不支持绑定第二个钱包」「一个账号，一个嵌入式钱包」全部删除。页脚 (i) 的 S304「所有绑定钱包的持仓都计入算力，不用搬家。」保留。
6. **客户端先行的可选键。** `GET /v2/wallets` 与 `/v2/meta/client-policy` 原本是严格键集，新增未知键会让整页（client-policy 是整个启动）失效。两处都改为接受可选 `externalWalletLimit`；值不是 0–50 的整数时当作「未说明」，不拒绝整份文档。

## Consequences

- 测试：新增 `test/s306_external_wallet_link_test.dart`（0 / 2 / 3 个外部钱包、archived 不计、会话凭据兜底计数、服务端上限覆盖默认、说明只出一次与取消、绑定成功后同步 + 重读、已绑他人 / Reown 网络 / 取消与拒绝三类错误、解绑确认 / 取消 / 失败 / archived 行、Privy 消息映射、清单可选键解码）；`test/loop_v2_meta_repository_test.dart` 加 client-policy 可选键五例；`s77a` / `s82b` 的弹层标题断言改为「连接外部钱包」；四个 `PrivyCredentialGateway` 测试替身补 `unlinkSiwe`。
- 依赖 S306-api 契约（待主代理校正）：`externalWalletLimit` 的实际位置与类型；`POST /v2/wallets/sync` 是否存在、是否要求 `Idempotency-Key` / origin 头、成功状态码；服务端是否也强制 3 个上限及其错误码（当前 App 只在前端拦，Privy link 本身不经过 LOOP 服务端）。
- 已知限制：Privy 的具体英文消息未在真机取证，「已绑他人」「唯一登录方式」靠关键词匹配；若真机消息不同，需要补关键词。用外部钱包登录的账号，这个钱包本身也在外部钱包列表里、计入 3 个上限；若它是唯一登录方式，Privy 会拒绝解绑，App 显示上面的「唯一的登录方式」文案。
