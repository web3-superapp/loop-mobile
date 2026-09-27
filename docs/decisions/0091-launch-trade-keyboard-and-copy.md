# 0091 · launch-trade 键盘与底栏，内盘持有人行与资格页质押入口的文案

## Status

Accepted 2026-09-27。S83c3，客户端单侧，不改 loop-api。93 条路由清单不变，没有新增
路由、没有新增依赖，`pubspec.lock` 不变。

## Context

2026-09-27 iPhone 14 Pro Max（iOS 26）真机走查：

1. `launch-trade` 输入金额后键盘收不起来。`TextInputType.numberWithOptions(decimal: true)`
   在 iOS 上是没有回车键的小数键盘；页面没有点空白收起；「先授权 USD1」/「买入」排在
   body 流里，被键盘盖住，用户以为没有下一步。`USD1 余额 / 授权额度` 行和「授权状态
   未读取」说明卡也在键盘下面。
2. `launch-detail` 的「内盘持有人」行在四轴 LIVE 时仍写「Launch 合约还没有上线……」。
   原因：该行读的是详情载荷自己的 `holders` 槽，而 loop-api 在详情里对它固定返回
   `unavailable(LAUNCH_CONTRACT_BASELINE_PENDING)`（`launch-service.ts` 详情分支）；真实
   参与人数只在 `GET /v2/launch/{id}/holders`。
3. `launch-tier` 在 `dependsOnStaking: false`（白名单模式）时仍有大主按钮「查看 LOOP
   质押」，暗示资格与质押有关。

## Decision

1. **`LoopFocusPage.keyboardAccessory`（共享组件，默认 false）。** 打开后：
   - 整个页面（含可滚动 body）包一层 `HitTestBehavior.translucent` 的
     `GestureDetector(onTap: unfocus)`；按钮、行、输入框自己的点击在手势竞技场里先赢，
     只有没人要的点击才收起键盘。
   - iOS 上键盘弹起（`viewInsets.bottom > 0`）时，在 Scaffold body 最底部——即紧贴键盘
     顶边——渲染 44pt 高的 Graphite「完成」条（`LoopKeyboardDoneBar`），点按收起键盘。
   - Android 的数字键盘自带完成键：各金额输入框加 `textInputAction: TextInputAction.done`。
2. **`launch-trade`**：主动作（「先授权 USD1」/「买入」）改走 `primaryAction` 固定在
   body 下方；Scaffold 按 `viewInsets` 缩高，主动作随键盘上浮，始终可见。已准备好的
   意图仍用 body 里的「重新报价 / 签名认购」复核对，此时不固定主动作。键盘弹起时
   folio 折叠（`folioCollapsed`，沿用 `send-to` 先例）；授权说明卡从轮次列表之后移到
   金额卡正下方，打字时与「USD1 余额 / 授权额度」行一起留在可视区。
3. **同类页复核**：`send-to`（已有固定主动作与 folio 折叠）、`swap`（固定主动作，folio
   未折叠）、`approval-guard`（「按限额授权」在 body 流里）三页都有同一个「iOS 小数
   键盘收不起来」问题，统一打开 `keyboardAccessory` 并加 `TextInputAction.done`；
   `swap`、`approval-guard` 打字时折叠 folio。`approval-guard` 的两个授权按钮仍在
   body 流里（原型顺序：限额按钮紧跟输入、无限授权在后），用户可用「完成」或点空白
   收起键盘后看到。
4. **内盘持有人行**改读 holders 资源（与 `launch-holders` 页同一 controller），按分支
   出文案：`available` →「N 位参与者」（决策 0089：去重买家数）；`unavailable` 时
   只有 `LAUNCH_CONTRACT_BASELINE_PENDING` 说「Launch 合约还没有上线」，
   `LAUNCH_ONCHAIN_STATE_NOT_INDEXED / NOT_PROJECTED` 说「链上记录索引中，参与人数稍后
   可见」，其他 reasonCode 与读失败都说「参与人数暂时读不到」；读取中写「正在读取
   参与人数」。详情下拉刷新时一并重读 holders。
5. **资格页**：`dependsOnStaking == true` 才渲染「查看 LOOP 质押」主按钮；`false`
   时换成一行说明「本次发射的资格不依赖 LOOP 质押」。

## Consequences

- 详情页多一次 `GET /v2/launch/{id}/holders` 读取；详情载荷里的 `holders` 字段仍解码，
  但不再用于展示。若后端以后让详情 `holders` 带真实分支，可再改回。
- `keyboardAccessory` 是显式开关，未打开的 focus 页行为不变。
- 测试：`test/s83c3_launch_keyboard_copy_test.dart`（点空白收起、iOS 完成条紧贴键盘、
  底栏在 viewInsets 下可见且说明卡在可视区、Android 无附件条、四种持有人文案与读取中/
  失败、资格页按钮显隐）；`test/s59_launch_block_order_test.dart` 相应更新。

## Main-agent rulings (2026-09-27)

1. approval-guard keeps its prototype order; 「按限额授权」 is not pinned. The blank-tap dismiss and the iOS 「完成」 bar are enough there.
2. The detail response's `holders` field stays as it is on the backend for now; the client reads the holders route. Folding the real branch into the detail response is a backend follow-up, not a blocker.
