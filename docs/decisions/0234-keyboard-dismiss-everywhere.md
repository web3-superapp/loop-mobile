# 0234 · 全 App 输入框键盘必须能收起（S276-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 5f7ec3dc（S275 合入后）。主代理下单 S276-mobile。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api。

## Context

需求方 iPhone（TestFlight 40）：MEME 代币页交易面板（`launch2_trade_panel.dart` / 官方池 `launch2_pool_trade_panel.dart`）的金额框弹出 iOS 小数键盘，键盘上没有「完成」键；点页面别处不失焦，滚动页面也不收键盘，键盘一直挡着确认按钮。
业主要求：「所有的输入框，至少要点其他的地方要能下去，或者滚动页面让他下去」。

原因：Flutter 在移动端触摸时，`EditableText` 点外面的默认动作是**不**失焦（只有桌面 / 鼠标才失焦）；滚动视图默认 `keyboardDismissBehavior: manual`；0091 只给 7 个 `LoopFocusPage(keyboardAccessory: true)` 页加了点空白收起和完成条，MEME 代币页（`LoopDashboardPage`）和所有弹层都不在内。

## Decision

1. **点外面收起，全局一次装好。** 新增 `lib/widgets/loop_keyboard.dart` 的 `LoopKeyboardScope`，挂在 `app.dart` 的 `MaterialApp.builder` 最外层（根 Navigator 之上，页面、底部弹层、对话框都在它下面）。它用 `Actions` 覆盖 `EditableTextTapOutsideIntent`：焦点输入框的 tap region 外任何按下都 `unfocus()`。
   只覆盖这一个 intent，不加手势识别器，不吞点击——按下去的按钮 / 行照常响应。
2. **不算「外面」的控件 = `LoopKeepsKeyboard`**（`TextFieldTapRegion` 包装）：Stream composer 整条（经组件构建器，所有会话 / 群 / 线程 composer 一处生效，发送、附件、引用条都保焦点）、`LoopComposer` 与预览 `ChatComposer` 的发送键、内盘「买入 / 卖出」切换与「填入上限」、官方池「付 / 得」模式切换、经典 MEME 交易「买入 / 卖出」切换、大额验证金额的预设胶囊、完成条本身。MAX 键在输入框装饰的后缀里，本来就在字段自己的 tap region 内；文本选择菜单、Stream 的 @ 联想浮层同理。
3. **拖动收起。** `LoopScrollBehavior.getKeyboardDismissBehavior` 返回 `onDrag`：所有不自己指定的 `ScrollView` / `SingleChildScrollView`（四个共享页骨架 `LoopFocusPage` / `LoopDashboardPage` / `LoopStreamPage` / `LoopSegmentedTabPage` 的滚动区、`NestedScrollView` 内外层、弹层里的滚动）一拖即收。统一在滚动行为上设一次，不逐个页面加参数。
   Stream 的消息列表显式传 `manual`，保持 Stream 自身行为（点外面仍生效）。
4. **iOS 数字键盘的「完成」条。** `LoopKeyboardScope` 监听焦点（焦点变化后在当帧结束时再查字段，避免对正在停用的元素查祖先）：焦点字段是数字 / 小数 / 电话键盘（`loopKeyboardLacksReturnKey`）、非只读、平台是 iOS、且键盘已弹起（`viewInsets.bottom > 0`）时，在键盘上沿画 `LoopKeyboardDoneBar`（0091 的组件：Graphite 底、右侧黄色 LoopType.action「完成」，44pt），点按失焦。
   条出现时，下层的 `MediaQuery.viewInsets.bottom` 加上条高 44：会随键盘缩高的 Scaffold、按 insets 垫高的弹层、字段自己的滚到可见都会把内容让到条的上方，不会被条盖住。
   0091 的 `LoopFocusPage(keyboardAccessory: true)` 页自己画条（对所有键盘类型）；焦点字段在这种页里时全局条让位，不会出现两条。
5. **Android 完成键。** 单行数字框统一 `textInputAction: TextInputAction.done`；本单补了 5 个：官方池自定义滑点、价格提醒阈值、经典 MEME 自定义滑点、二次验证 6 位码、大额验证金额。
6. **审计**：`docs/integration/S276/input-fields.md` 列出全部 59 个 `TextField` + Stream composer，逐个标注页面、键盘类型与可用的收起路径。

## Consequences

- 测试：新增 `test/s276_keyboard_dismiss_test.dart`（11 例：滚动行为为 onDrag；无回车键盘判定；MEME 内盘点外面失焦；MAX / 买卖切换 / 点字段本身保焦点；从字段上拖动页面失焦（不经点外面）；iOS 小数键盘弹起后出现完成条且贴键盘上沿、字段在条上方、点完成失焦且条消失；Android 无条且点外面失焦；弹层字段点外面失焦且弹层不关；弹层在条上方、文本框无条；`LoopComposer` 发送保焦点、点外面失焦；0091 页只有一条）。
  `test/support/s7_page_harness.dart` 的 `pumpS7Page` 新增 `appKeyboard` 开关（默认关），按 `app.dart` 的方式挂滚动行为与 `LoopKeyboardScope`；其他测试不受影响。
- 行为变化：全 App 点任何非输入区都会收键盘，包括点「确认 / 下一步」按钮——按下先失焦、抬起照常触发按钮；会话里点消息列表收键盘（发送键不收）。横向滚动条（筹码行、Tab 条）拖动也会收键盘，这是 `onDrag` 的本义。
- 0091 的页面级点空白收起与完成条保留不动（与全局规则同向，不冲突）；`s83c3` 测试不变。
- 真机需确认：iOS 小数键盘的完成条贴合键盘上沿、随键盘动画上下；Stream 会话里发送后键盘不收、附件按钮（系统选图）正常；登录 OTP 页点格子仍能唤起键盘。
