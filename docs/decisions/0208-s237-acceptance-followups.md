# 0208 · S237 验收回修：钱包 Launch 链 USD1 读错代币、漏网文案、外盘买入税两处不一致（S237b-mobile）

## Status

Accepted 2026-10-19。基线 `feat/S243-utf8-ticker` c2e207d。依据：S237 真机验收记录（`LOOP/docs/integration/S237/notes.md` §1 表 d/e/f、§4 第 2、3 条，
截图 `shots/03-wallet-home-launch-chain-card.jpg`、`08-meme-token-S227W-buy-5.jpg`、`11-sign-sheet-meme-v2-graduated-buy.jpg`），
客户端决策 0148、0159、0197、0203 §E、0204；loop-api 决策 0038 / 0077 / 0152。
只改 App：不新增依赖、路由、字体、颜色 token，`pubspec.lock` 不变，无新请求路径，不改 loop-api。

## Context

S237 验收 0204 时记下三件和测试提示无关、但要回修的事：钱包「Launch 链」卡片 USD1 显示 0（演示账号晚风 0xbcc0…5ef8 链上约 2,885 tUSD1，
MEME 买入面板读到的余额正常）；0204 的禁词守卫漏了三处「还在核对 / eip155:97」；S227W 外盘买 5 USD1 时输入页写「基础税 2% 0.1 USD1」、签名单写「外盘税 2% · 0 USD1」。

## Decision

### A. 钱包 Launch 链 USD1 改读 MEME v2 的 USD1（根因：读的是另一个代币）

**定位（2026-10-19 21:35，staging，晚风账号，钱包 4b1f36d8…）**

- `GET /v2/wallets/{id}/balances` 的 `launchChain.usd1` 原样返回 `{"balance":"0","allowance":"0"}`（`availability: available`，tBNB 0.0498699991 正常）。
  前端解码、单位（18 位）、`hidden` / `available` 都没错——**后端给的就是 0**。
- 后端 `wallet-read-service.ts` 的 Launch 槽 USD1 读的是 `launchUsd1` 目标 = `config.launchContract.usd1Address` = 环境变量 `LAUNCH_USD1_ADDRESS`
  （`app.ts:1810-1816`），即**已隐藏的旧 IDO Launch 合约所用的 MockUSD1**（dev 配置为 `0x17d5…ce2b`）。
- MEME v2 / launch2 / 获取资金（faucet）用的是 Hooks Factory 的 `usd1()`（`0x3a12…0195`）。同一时刻直接 `eth_call balanceOf(晚风)`：
  `0x17d5…ce2b` = 0，`0x3a12…0195` = 2,892.0066875959。
- MEME 买入面板正常，是因为它读的是 MEME v2 自己的读数（`me/positions` 与报价的 `usd1Balance`，同一个 Factory USD1）：
  同一时刻 `GET /v2/launch2/me/positions` 两条已毕业持仓都带 `usd1Balance: 2892.006687595931906156 @ 137710132`。

**根因**：0203 §E（S236）把 `launchChain.usd1` 当成「Launch 链上的 USD1」画进钱包卡片，但那对数字是 IDO Launch 合约的 `balanceOf / allowance`
（loop-api 0077，用于 IDO 授权），在测试网槽上和用户实际持有、MEME v2 实际花的 USD1 不是同一个代币。显示 0 不是解码错误，是读错了来源。

**修法（App）**

- 新视图模型 `WalletLaunchUsd1`（`wallet_read_models.dart`）：要么是读到的数，要么是一句原因，二者恰有其一。
- 来源改为 `me/positions`：`launch2WalletUsd1Of(state, walletId:)`（`launch2_wallet_rows.dart`）取本钱包、`balanceStatus = available` 的持仓里
  `usd1Balance`，多条时取块高最大的一条。钱包页已在读 `me/positions`（0139 的 MEME v2 行），不新增请求。
- 卡片的 USD1 行**一直画**：有数显示数（两位小数，隐藏余额时 `****`）；没数显示「—」并在下方写原因，绝不显示 0。原因四种：
  读取中 / 读取失败（error、offline、permission）/ MEME 暂未开放（开关关或能力不可用）/ 持有已毕业代币后显示（读到了但没有已毕业持仓——服务端只对已毕业持仓读 USD1）。
- `launchChain.usd1` 不再进钱包卡片，只保留它原本的用途（旧 IDO 授权闸门，`launch_approval.dart`）。

**留给后端 / 主代理**：没有任何已毕业持仓的账号，钱包卡片只能显示「—」。要让所有账号都有数，需要 loop-api 在钱包级发布 MEME v2 USD1
（例如让 `launchChain.usd1` 读 Factory `usd1()`，或新增字段），或把 staging 的 `LAUNCH_USD1_ADDRESS` 指到同一个代币——后者会影响旧 IDO，需主代理裁决。

### B. 漏网文案与守卫

| 位置 | 原文 | 现文 |
|---|---|---|
| `launch2_format.dart` `LAUNCH2_SNAPSHOT_UNVERIFIED` | 名单还在核对，提前购暂不可用 | 名单核验中，提前购暂不可用 |
| `launch_contract.dart` `LAUNCH_CONTRACT_VERIFICATION_PENDING` | Launch 合约已配置，还在核对链上代码，请稍后刷新。 | Launch 合约正在完成链上校验，请稍后刷新。 |
| `launch_widgets.dart` `LaunchChainBlock`（旧 IDO） | 整块（含 `eip155:97` 副标题与读屏句「Launch 运行在 BSC 测试网，eip155:97…」）不受开关控制 | 整块受 `loopTestHintsVisible` 门控，开关关时不画、不朗读 |

`test/s237_source_guard_test.dart`：禁词「还在核对，交易」「合约还在核对」合并为「还在核对」；新增「eip155:97」——只禁句子里的链 ID，
恰好等于一个 CAIP-2 ID 的字面量（`loop_chain_ids.dart` 的常量定义）是标识符，按与原因码相同的方式跳过。放行列表没有新增条目（仍只有 `loop_test_hints.dart` 整文件与原有 `STAGING` 一条）。

### C. 外盘买入税：签名单与输入页同一来源、同一写法

- 输入页（`launch2DynamicBuyTaxLine`）：S209 LoopDynamic Hook 买入，标签「基础税 2%（从付出的 USD1 扣）」，数值是报价的 `quote.taxUsd1`（0.1 USD1），4 位小数。
- 签名单（`launch2IntentFields`）：标签「外盘税 2%」，数值是 `launch2Intent.taxUsd1`。loop-api 对**所有**外盘买入意图都把 `tax` 写成 0
  （`launch2-service.ts` pool prepare：`tax: side === "sell" ? numbers.tax : 0n`），于是显示「0 USD1」。不是取整，是字段本身为 0。
- 修法：池子 prepare 的解码（`loop_v2_launch2_pool_codec.dart`）在买入且报价 `taxToken = usd1` 时，把同一响应里报价的 `taxUsd1` 交给意图
  （与已有的 `taxMeme` 同一做法）；并把 `quote.dynamic.baseTaxToken` 记在意图的 `dynamicBuyTaxToken` 上，签名单标签按它写成与输入页相同的
  「基础税 2%（从付出的 USD1 扣 / 从到手的 MEME 扣）」。数值同为 `launch2Usd1Label(…, maxFractionDigits: 4)`。普通外盘买入（MEME 计税）与卖出不变。

## Consequences

- 晚风账号钱包「Launch 链」USD1 显示约 2,892.01；没有已毕业持仓的账号显示「—」+「持有已毕业代币后显示」，不再出现假 0。
- 旧 IDO 恢复时，其授权闸门仍读 `launchChain.usd1`，行为不变。
- S227W 一类外盘买入：签名单与输入页都写「基础税 2%（从付出的 USD1 扣） 0.1 USD1」。
- 「名单核验中」「Launch 合约正在完成链上校验」；开关关时旧 IDO 的链说明整块不出现。

## Tests

- `test/fixtures/s237b/`（`_derived` 写明）：`wallet_balances_launch_chain_ido_usd1.json` 是 staging 晚风账号 balances 响应的 `launchChain` 原样；
  `launch2_positions_wanfeng.json` 是同一时刻 `me/positions` 原样（仅 `logoUrl` 置空）。
- `test/s237b_acceptance_followups_test.dart`：两份真实响应解码（`launchChain.usd1 = 0`、持仓 `usd1Balance = 2892.0066…`）；解析函数在 ready / 他人钱包 /
  空 / loading / empty / error / offline / permission / unavailable 下的数或原因；卡片有数、四种原因「—」、隐藏；钱包页级 ready（2,892.01、无 0）、
  error、offline、empty；B 的两句文案与 `LaunchChainBlock` 门控；C 用 S146 外盘买意图（`taxUsd1 = 0`）+ S168b 动态买报价改成 S209（0.1 USD1）拼出 prepare，
  断言签名单标签与数值和输入页一致，普通外盘买仍是「外盘税 2%」MEME。
- 改动的旧测试：`s236_s234_followups_test.dart`（钱包页不再画 `launchChain.usd1` 的 4,850，无 `usd1` 时行仍在且为「—」；卡片构造加 `usd1`）；
  `s9_dual_chain_pages_test.dart`（USD1 行也带徽章，徽章断言限定到 tBNB 行）；`s237_source_guard_test.dart`（禁词与链 ID 规则，加两条自测）。
