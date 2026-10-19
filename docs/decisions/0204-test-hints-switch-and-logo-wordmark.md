# 0204 · 测试相关提示统一开关（默认关）与皇冠 wordmark（S237-mobile）

## Status

Accepted 2026-10-19。基线 `fix/S236-s234-wording-and-wallet` 45d30c7（含 0203 新加的钱包 Launch 链说明句）。
依据：`LOOP/docs/42-需求方反馈八条-2026-10-19.md` 第 5 条（「页面不要有测试相关提示……为什么还有测试相关提示呢？？？？？？」）与第 1 条（Logo）；
相关决策 0097、0100、0123、0133、0154、0158、0164、0175、0200、0201、0203。
不新增依赖、字体、颜色 token；`pubspec.lock` 不变；路由表不增删（样例路由改为受开关重定向）；无新请求路径；不改 loop-api。

## Context

此前几轮都是逐条改字，改完总有新的测试字样混进来（最近一次是 0203 的「Launch 链是 BSC 测试网余额……」）。根因是没有一个总开关，
也没有防回归的守卫。本批把所有用户可见的测试提示收到一个开关下，开关默认关；关时一律不画或改为中性写法，并加源码级守卫测试。

## Decision

### A. 一个开关

- `LoopFeatureSwitches.testHintsVisible`（`lib/core/config/loop_feature_switches.dart`），值来自
  `AppConfig.testHintsVisibleDefine = bool.fromEnvironment('LOOP_TEST_HINTS_VISIBLE')`（harness 规定 `fromEnvironment` 只能在 `AppConfig`）。
  **默认 false**。走查包用 `--dart-define=LOOP_TEST_HINTS_VISIBLE=true`，或在自己的 `--dart-define-from-file` json 里加
  `"LOOP_TEST_HINTS_VISIBLE": "true"`（`config/debug.json` / `release.example.json` 被 harness 锁定内容，未改）。
- 读取一律经 `loopTestHintsVisible`（`lib/core/config/loop_test_hints.dart`），没有 `ref` 的格式化函数也读同一个值；
  测试用 `debugSetLoopTestHintsVisible(bool?)` 切换（每个测试文件独立 isolate）。
- 开关开时才出现的字（BSC 测试网、BSC TESTNET、测试网说明、tBNB / tUSD1、钱包说明句等）**只写在 `loop_test_hints.dart` 一个文件里**。
- 代币符号显示：`loopDisplaySymbol(symbol)` 关时 `tBNB→BNB`、`tUSD1→USD1`，其余原样；只用于显示层，不改模型、签名载荷、金额计算。

### B. 三处源头

| 源头 | 关时 | 开时 |
|---|---|---|
| `loopChainName`（`lib/core/chain/loop_chain_ids.dart:35-40`） | eip155:97 也返回「BNB Smart Chain」 | 「BSC 测试网」 |
| `loopTestnetBadgeFor(chainId)`（新，`loop_chain_ids.dart:52`）；`LoopTestnetBadge`、`LoopTestnetNotice`（`chain_widgets.dart:807-883`） | 返回 `null` / 不渲染 | 原徽章与一次性说明 |
| `loopEnvironmentTag`（`lib/app/loop_backend_identity.dart:52`） | 不显示 DEV / STAGING | 非 release 显示 |

### C. 处理表

门控方式：**开关** = 关时不画 / 中性写法，开时原样；**改词** = 不分开关，直接换成中性措辞；**符号** = 经 `loopDisplaySymbol`。

| 文件:行（改后） | 原文 | 改后 | 门控 |
|---|---|---|---|
| core/chain/loop_chain_ids.dart:38-39 | `'BSC 测试网'` | 关时「BNB Smart Chain」 | 开关 |
| features/chain/chain_contract.dart:360 | Launch 运行在 BSC 测试网，测试网数据暂时读不到。 | Launch 链上数据暂时读不到。 | 改词 |
| chain_contract.dart:361 | 正在校验测试网连接，暂时不显示测试网数字。 | 正在校验 Launch 链连接，暂时不显示链上数字。 | 改词 |
| chain_contract.dart:362 | 测试网节点暂时连不上，与你的网络无关，稍后再看。 | Launch 链节点暂时连不上，与你的网络无关，稍后再看。 | 改词 |
| chain_contract.dart:363 | 连接到的不是 BSC 测试网，Launch 相关内容不可用。 | 连接到的不是 Launch 链，Launch 相关内容不可用。 | 改词 |
| chain_contract.dart:497-511 | `loopTestnetBadgeLabel` / `NoticeTitle` / `NoticeBody` 字面量 | 改为引用 `loop_test_hints.dart` 常量 | 开关（经 B 行） |
| chain/chain_widgets.dart:812-822 | `LoopTestnetBadge` 恒画 | 关时 `SizedBox.shrink` | 开关 |
| chain_widgets.dart:865-868 | `LoopTestnetNotice` | 关时不画；关闭按钮标签「关闭测试网说明」移入 hints | 开关 |
| app/loop_backend_identity.dart:52-53 | 非 release 显示 DEV/STAGING | 关时 `null` | 开关 |
| meme/meme_signing.dart:576、launch/launch_signing.dart:617、launch2/launch2_signing.dart:977、wallet/money_actions_widgets.dart:332、mining_rewards/mining_rewards_signing.dart:343、launch2/creator/launch2_sign_screen.dart:513 | 签名单 `networkBadge: isTestnet ? 'BSC 测试网' : null` | `loopTestnetBadgeFor(chainId)` | 开关 |
| 同上各签名单「网络」字段（meme_signing:148、launch2_signing:230、money_actions_signing:353、mining_rewards_signing:68、launch2_sign_screen:23） | BSC 测试网 | 经 `loopChainName`，关时「BNB Smart Chain」 | 开关 |
| wallet/wallet_read_screens.dart:426（原 :436） | 钱包首页「领取测试币 / 测试网专用 · 领 tBNB 与 tUSD1」卡片 | 删除（同时删 `TestnetFaucetEntry`） | 删除 |
| wallet_read_screens.dart:475-480（原 :504） | Launch 链 ⓘ「关于 Launch 测试网」 | 关时不画 | 开关 |
| wallet_read_screens.dart:1144-1146（原 :1168） | 资产详情印章「BSC TESTNET」 | 关时「BSC」 | 开关 |
| wallet_read_screens.dart:2795-2805（原 :2819-2824） | 网络设置「测试网 / 没有已发布的测试网」整行 | 关时整行不画 | 开关 |
| wallet_read_screens.dart:2548、wallet_read_widgets.dart:226 | 转账记录「收到 tBNB」、详情数量 | `loopDisplaySymbol(entry.symbol)` | 符号 |
| chain/chain_models.dart:204-210 | `loopAssetSymbolLabel` 原样 | 经 `loopDisplaySymbol` | 符号 |
| wallet/wallet_read_widgets.dart:493-514 | Launch 链行标题 tBNB | `loopDisplaySymbol(native.symbol)` | 符号 |
| wallet_read_widgets.dart:498/531 | 两行的「BSC 测试网」徽章 | `LoopTestnetBadge` 关时不画 | 开关 |
| wallet_read_widgets.dart:545、564-574（0203 新加） | 「Launch 链是 BSC 测试网余额，不计入总资产……」说明句 | 关时不画；卡片标题仍是「Launch 链」 | 开关 |
| wallet_read_widgets.dart:577-580 | `'tUSD1'` | 关时「USD1」 | 符号 |
| wallet/testnet_faucet/testnet_faucet_sheet.dart:47 | 领取测试币 | 获取资金 | 改词 |
| testnet_faucet_sheet.dart:50 | 测试币池暂时不足，请稍后再试 | 资金池暂时不足，请稍后再试 | 改词 |
| testnet_faucet_sheet.dart:101-114 | tBNB 已到账，tUSD1 这次没成功 / 这次只发出了一部分测试币 | 符号经映射；「这次只发出了一部分」 | 改词 + 符号 |
| testnet_faucet_sheet.dart:127-137 | 测试币领取已关闭 / 当前网络不是测试网，不能领取测试币 / 测试币领取暂时不可用 / tUSD1 合约暂时不可用 | 领取已关闭 / 当前网络不支持领取 / 领取暂时不可用，稍后再试 / USD1 合约暂时不可用 | 改词 + 符号 |
| testnet_faucet_sheet.dart:164 | 关闭领取测试币 | 关闭获取资金 | 改词 |
| testnet_faucet_sheet.dart:417-424（原 :444-449） | 测试网专用……测试币没有价值。 | 领取 BNB 与 USD1 到当前钱包，用来支付手续费和买卖，每 24 小时一次。／这次会发 x BNB 和 y USD1 到当前钱包，每 N 可以领一次。 | 改词 + 符号 |
| testnet_faucet_sheet.dart:560-590（原 :588-610） | 已发出 x tBNB 和 y tUSD1；交易行标签 tBNB / tUSD1 | 符号经映射 | 符号 |
| profile/profile_v2_screens.dart:912、927 | 领取测试币后首次买入 0 手续费 | 首次买入 0 手续费 | 改词 |
| launch2/launch2_widgets.dart:557 | 余额不足旁链接「领取测试币」 | 获取资金 | 改词 |
| launch2/launch2_launchpad.dart:203-209 | LAUNCH DESK · BSC TESTNET | 关时 LAUNCH DESK · BSC | 开关 |
| launch2/launch2_instance_screen.dart:515 | 测试网合约还在核对，交易可能暂时不可用 | 合约核对中，交易可能暂时不可用 | 改词 |
| meme/meme_token_screen.dart:591 | 发射台合约还在核对，交易可能暂时不可用 | 合约核对中，交易可能暂时不可用 | 改词 |
| meme/meme_create_screen.dart:938 | 发射台合约还在核对，创建可能暂时不可用。 | 合约核对中，创建可能暂时不可用。 | 改词 |
| meme/meme_token_screen.dart:456 | 测试网不支持站内兑换 | 暂不支持站内兑换 | 改词 |
| market/market_fomo_widgets.dart:53 | 测试网代币不报价 | 暂无报价 | 改词 |
| launch2/launch2_format.dart:403 | tBNB 手续费不足，充值后再试 | BNB 手续费不足，充值后再试（开时 tBNB） | 符号 |
| launch2_format.dart:462-480 | tBNB 手续费不足：钱包里的 tBNB 不够……／这笔约需 x tBNB | 符号经映射（`launch2GasShortText` 改为 getter） | 符号 |
| meme/meme_format.dart:91 | tBNB 手续费不足 | BNB 手续费不足（开时 tBNB） | 符号 |
| wallet/money_actions_widgets.dart:486、489、492 | 名单 / 上限由 LOOP 在灰度期间维护 / 设定 | 名单由 LOOP 维护 / 上限由 LOOP 设定 | 改词 |
| mining/mining_models.dart:236 | 当前算力公式是试运行版本……当日产量是占位预算…… | 当前版本：……当日产量为预估值…… | 改词 |
| mining/mining_secondary_screens.dart:1484 | 占位产量 | 预估产量 | 改词 |
| profile/about/about_client_register.dart:143 | 链上写入灰度规则 | 链上写入规则 | 改词 |
| profile/about/about_screen.dart:97-98（原 :100-122） | 关于页「服务端（DEV/STAGING · 主机名）」「构建模式」两行 | 从关于页移除 | 移走 |
| profile/about/network_diagnostics_screen.dart:112、145-180 | — | 网络诊断页「本机构建」组（服务端、构建模式），只在开关开时画 | 开关 |
| network_diagnostics_screen.dart:195 | 探测行副标题「api-staging.… \n 用途」 | 关时只写用途 | 开关 |
| network_diagnostics_screen.dart:226-231 | 复制的诊断文本「主机（STAGING）」 | 关时只写主机，不带环境标签 | 开关 |
| app.dart:775-798、894-904 | `/preview/token-card · contract-facts · asset-message · toast · loading`、`/system/offline · error · maintenance · permission · token-card · sign-sheet`（组件样例 / 开发预览 / 英文 guard） | 开关关且非开发预览会话时重定向到 `/chat` 并记路由错误 | 开关 |
| launch/launch_screen.dart:303 | 旧 IDO 首页说明「BSC 测试网」字面量 | 改引用 hints 常量，行为不变（IDO 隐藏，不动） | — |

### D. 样例路由：受开关，不删除

11 条样例路由有 8 个 `system_*_truthfulness` / `*_states` 测试文件、`route_manifest_test`、`chat_preview_route_guard_test` 依赖，
且在路由清单（manifest）里。按任务单「被测试大量依赖则受开关」处理：路由表与 manifest 不变，顶层 `redirect` 在开关关、
且不是开发预览会话时把它们送回 `/chat` 并 `routingErrors.record`（与未知路由同一处理）。`/system/update`、`/system/region` 是真实闸门，不受影响。
`chat_preview_route_guard` 的英文挡板因此在默认构建里到达不了。

### E. Logo：只换 wordmark

- 新图 `LOOP/docs/assets/logo-loop-crown-2026-10-19.png`（480×310 RGBA 透明底，黄冠 + 白字）复制为 `assets/brand/loop-wordmark-crown.png`；
  旧 `loop-wordmark-u3d.webp`（不透明黑底）删除。`LoopBrandAssets.wordmarkWebp` → `wordmarkPng`；`LoopBrandMark` 的 wordmark 走该 PNG，
  失败时仍回退 `loop-wordmark.svg`。
- 承载面核对（9 处）：
  - wordmark（5 处，已换）：启动页 `account_screens.dart:366`（Scaffold）、会话恢复 `privy_login_screen.dart:473`（Scaffold）、
    等待网络 `privy_login_screen.dart:569`（Scaffold）、应用锁 `app_lock_gate.dart:103`（`ColoredBox(LoopColors.ink)`）、
    引导过渡 `onboarding_communities.dart:1079`（Ink 页 + Lime 光晕；PNG 透明，去掉原来为避开 WebP 黑底而用的 `vector: true`）。
    Scaffold 底色来自 `LoopTheme.dark.scaffoldBackgroundColor = LoopColors.ink`，App 只有暗色主题（`themeMode: ThemeMode.dark`）。
  - appIcon（4 处，未动，等大图）：登录页 `privy_login_screen.dart:105`、建钱包环 `account_screens.dart:971`、桌面侧栏 `loop_shell.dart:489`、
    广场官方头像 `square_feed_view.dart:742`。
- 原生启动屏、App 图标不在本批（480×310 不够，等需求方大图，见 docs/42）。

## Consequences

- 默认构建（含 TF / 安卓归档包）里看不到「测试网 / 测试币 / TESTNET / tBNB / tUSD1 / DEV / STAGING / 灰度 / 试运行 / 占位产量 / 组件样例路由」。
- 测试币领取保留：入口为「我」与 MEME 首页的「充值」（能力位可用时）和 MEME v2 余额不足的「获取资金」链接；钱包页没有「充值」键，所以钱包页不再有入口。
  能力位判断（`testnetFaucetVisible`）不变。
- 网络设置页 Launch 链行在关时写「BNB Smart Chain（Launch）」，副标题仍有 `eip155:97`（链 ID 是技术事实，未门控）。
- 浏览器链接仍是 `testnet.bscscan.com`（复制出去的链接必须能打开），不是界面文字。

## Tests

- `test/s237_test_hints_test.dart`：默认值为 false；关时——钱包首页（Launch 链测试网余额 + faucet 能力位可用 + staging 后端）无 faucet 卡、
  无「领取测试币」「测试」「TESTNET」「STAGING」「tBNB」「tUSD1」，Launch 链两行写 BNB / USD1、无徽章 / ⓘ / 说明句；`loopChainName(97)`=「BNB Smart Chain」、
  徽章与说明不渲染；`memeReasonText` / `launch2ReasonText` 的 gas 文案以「BNB 手续费不足」开头；kicker 无 TESTNET；环境标签为 null；
  关于页无服务端 / 主机名 / 构建模式；网络诊断无本机构建组与主机名；11 条样例路由在非预览会话关闭、预览会话不关。开时——链名 / kicker / 环境标签 / 符号 /
  钱包徽章与 STAGING 恢复，样例路由开放。
- `test/s237_source_guard_test.dart`：扫描 `lib/` 全部 Dart 字符串字面量（跳过注释，插值拆段），禁词「测试、水龙头、灰度、试运行、占位产量、占位预算、
  合约还在核对、没有价值、TESTNET、STAGING、tBNB、tUSD1」；整串是大写下划线代码的（`TESTNET_FAUCET_*` 等原因码）跳过；
  只放过 `lib/core/config/loop_test_hints.dart`，以及 `loop_backend_identity.dart` 的 `STAGING`（tier 名，开关控制显示）。另有扫描器自测。
- `test/s135_launch2_creator_pages_test.dart` 新增：开关关时签名部署页「网络」为 BNB Smart Chain，签名弹层无「测试网」。
- 钉住开关开时原行为的套件在 `main` 开头调用 `loopShowTestHints()`（`test/support/test_hints.dart`）：s9_dual_chain(_pages)、s236、s91、s182、s83c、s83c2、
  s135、s59、s58、s121c、s146、s160、s136、s95、route_manifest、chat_preview_route_guard、8 个 system_* 文件。
- 改词同步的断言：s113（暂无报价）、s117（暂不支持站内兑换）、s7（预估产量）、s8（链上写入规则）、s136（获取资金）、s156（获取资金、BNB / USD1、
  从「充值」打开弹层、钱包页无 faucet 卡）、s91（服务端 / 构建模式改在网络诊断页断言）、loop_assets_test（`wordmarkPng`）。
