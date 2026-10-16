# 0195 · 经典发射入口隐藏，统一走 Loop Hook（v2）发射（S216-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` 3918c5f。依据：需求方 2026-10-16 答题卡与群内确认（LOOP `docs/12` 2026-10-16 18:1x 条）。
后端由 S217-api（loop-api 决策 0151，`MEME_CLASSIC_CREATE_ENABLED` 默认 false → 410 `MEME_CLASSIC_LAUNCH_RETIRED`，读 / 买 / 卖不动）并行实现。
不新增依赖、路由、字体、颜色 token、能力位；路由清单不变（`docs/product/routes-manifest.json` `count` 113，`meme-create` 保留）。
照决策 0110 §11 隐藏 IDO 的做法：编译期开关 + `loopFeatureSwitchesProvider`，只决定入口与渲染分支，不改路由表、不改请求。

## Context

需求方：「正常发射从 App 和 H5 移除，统一 Loop Hook 发射」。「正常发射」即经典发射——旧 MEME 联合曲线（`POST /v2/meme/tokens`、
`lib/features/meme/meme_create_screen.dart`，决策 0120）。App 里的 v2 发射（决策 0138 起，NFT 预售 + 内盘，毕业挂 Loop Hook 外盘）是唯一保留的发射方式。
测试网上已有的经典代币仍在链上、仍有持仓，必须照常可读可卖。我方没有 H5 发射页。

改前，经典发射有五个入口：
1. MEME Tab v2 面「发起」底部抽屉的「经典发射」一行（决策 0146）；
2. v2 面「经典」分段顶栏的「创建代币」（决策 0176）；
3. 非 v2 面（`launch2` 不可用）发射台工具行的「创建代币」；
4. 发射台空态「创建第一个」；
5. 经典草稿代币页底栏「继续创建」（`/meme/create?draft=`）。

## Decision

1. **开关** `LoopFeatureSwitches.classicMemeLaunchVisible = false`（`lib/core/config/loop_feature_switches.dart`），
   `LoopFeatureSwitchValues.classicMemeLaunchVisible` 同名字段，页面经 `loopFeatureSwitchesProvider` 读取，测试覆盖两种取值。
2. **「发起」直接进 v2 创建页，不弹抽屉**（`Launch2CreatorActions`）。只剩一项时抽屉是一次多余的点按、一张只有一行的表，
   而按钮本身就叫「发起」，直达更自然；`我的项目` 不变。开关为 true 时仍是原来的两项抽屉。
3. **「经典」分段改名「历史」**（`MemeScreen.v2SegmentsClassicRetired = ['v2 发射', '历史', '已毕业']`）。分段里的经典代币列表、
   搜索入口、余额块、最佳交易、快打满、四个 chips 全部保留；顶栏「创建代币」不画。「经典」会让新用户以为这是另一种发射方式，「历史」说清它是已有代币。
   v2 列表空态按钮「看经典发射」相应改为「看历史代币」（仍切到该分段）。
4. **非 v2 面发射台**：工具行只留搜索，不画「创建代币」；分段名「发射台」不变（那一面没有 v2 可对照）。
   空态去掉「创建第一个」按钮，文案「经典发射已停用，新代币请走 v2 发射」；读失败的空文案改「这里还没有代币」。
5. **创建路由保留**：`/meme/create`（含 `?draft=`）仍挂在路由表与清单里。开关关时 `MemeCreateScreen` 在 build 第一步就返回停用页
   `meme-create-retired`：标题「创建代币」、插画 + 「经典发射已停用」+「请使用 Loop Hook 发射（v2 发射）创建新代币。已有的经典代币仍可在 MEME 的「历史」里查看和买卖。」
   + 按钮「去 v2 发射」（`onOpenLaunch2Create`，`app.dart` 里 `pushReplacement(Launch2CreatorRoute.createPath)`）。不画表单、不读草稿、不上传、不发任何请求。
   App 内用「v2 发射」称呼这条线，停用页同时写 Loop Hook 与 v2 发射两个名字，让需求方的叫法与界面的叫法对得上。
6. **草稿代币页**：`draft` 状态的底栏改为禁用按钮「经典发射已停用」（`meme-token-resume-retired`）。草稿还没上链，「继续创建」就是新建。
7. **不变**：经典代币页（行情、K 线、持有人、动态、买入 / 卖出 / 快买 / 去兑换）、行情列表、钱包持仓、交易记录、搜索结果、
   `MemeGateway` 与全部交易能力。只是不能再新建。
8. **harness**：`scripts/check_harness.py` 没有「经典发射入口必须存在」类守卫；`test/s123a_navigation_shell_test.dart` 仍须含
   `meme-create-step-1`（创建页返回逻辑），该测试改为在开关为 true 时跑，守卫不需改。

## Consequences

- 新用户在 App 里只能发起 v2（Loop Hook）发射；「发起」少一次点按。经典代币作为「历史」继续可读可交易，持有人不受影响。
- 深链 / 旧通知 / 书签打开 `/meme/create` 不会 404，也不会弹出表单后被后端 410 拒绝，而是停用页加去 v2 的路。
- 经典创建代码（表单、草稿、签名出口）作为可恢复的历史保留，仍由原测试在开关为 true 时覆盖，不会悄悄腐坏。
- 未做：「v2 发射」各处文案不改名为「Loop Hook」（只在停用页同时写两个名字）；如需统一改名另立决策。

## 恢复方法

把 `LoopFeatureSwitches.classicMemeLaunchVisible` 改回 `true`：抽屉两项、「经典」分段名、两处「创建代币」、空态「创建第一个」、
创建表单、草稿「继续创建」全部恢复原样。后端须同时把 `MEME_CLASSIC_CREATE_ENABLED` 打开，否则创建会收到 410。

## Tests

- `test/s117_meme_launchpad_test.dart` 新组「0195 · classic launch retired」（7 例）：构建默认关；发射台保留代币行与搜索、无创建入口、
  已有代币可点开；空态无「创建第一个」；创建路由（带 `draft`）显示停用页、无表单、零读取零创建零上传、按钮进 v2；开关开时创建页为原表单；
  经典代币页照常有买入 / 卖出 / 快买；草稿底栏关时禁用「经典发射已停用」、开时「继续创建」。
- `test/s136_launch2_user_test.dart`「0146 · MEME v2 face」新增 2 例：关时无「经典」有「历史」，「发起」直达 v2 创建页且无抽屉，
  「历史」分段有搜索无创建；v2 空列表按钮为「看历史代币」。
- 原有经典发射测试（s117 列表 / 创建、s123a 创建页返回、s136 抽屉两项与三分段）改为显式 `classicMemeLaunchVisible: true`，
  即「开关为 true 时行为不变」的覆盖。
