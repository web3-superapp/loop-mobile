# 0085 · 边缘右滑返回，价格列印完价格，折线随行下发

## Status

Accepted 2026-09-23。S81a，客户端单侧。不新增路由，93 条路由清单不变。

改动范围：`lib/core/theme/loop_theme.dart`（转场主题）、`lib/app.dart`（一处注释）、
`android/app/src/main/AndroidManifest.xml`（一个属性）、`lib/features/market/**`、
`lib/features/chain/chain_widgets.dart`（给既有格式化函数加一个可选参数）、
`lib/features/market/market_read_models.dart` 与
`lib/integrations/backend/v2/market/loop_v2_market_api.dart`（行级折线的解码槽位）。

折线字段的契约由 S81b 定稿；本单按 `{status, interval, closes[], observedAt}`
预留解码，键仍是**可选**的（见 §3.3）。

## Context

需求方 2026-09-23 在 iPhone 真机上提了两条：

| 现象 | 位置 |
| --- | --- |
| iOS 和 Android 都不能从屏幕边缘右滑返回 | 所有二级页 |
| 行情列表 BTCB 的价格「$85,866….」被截成省略号；多数行没有小折线 | `market` |

### 右滑返回

根因不在路由，也不在 `PopScope`，在主题。`LoopTheme.dark` 把六个平台的
`PageTransitionsBuilder` 全部换成了自写的 `LoopPushTransitionsBuilder`（第 7 章
的「右侧滑入 + 淡入」）。而 **iOS 的边缘右滑不是 Navigator 的功能，它长在
Cupertino 转场里面**：`CupertinoRouteTransitionMixin.buildPageTransitions` 才是
把页面包进 `_CupertinoBackGestureDetector` 的那一段。换掉 builder，整条右边缘就
失效了。Android 那边同样被换掉的是 `PredictiveBackPageTransitionsBuilder`——
系统返回手势仍然会 pop（`FlutterFragment` 用 AndroidX 的
`OnBackPressedDispatcher` 接住它），但**没有任何动画跟着手指走**，读起来就是
「滑了，没反应」。

顺带核了一遍会把手势关掉的四处 `PopScope`（`popGestureEnabled` 在
`popDisposition == doNotPop` 时返回 false）：

| 位置 | `canPop` | 结论 |
| --- | --- | --- |
| `voice_room_screens.dart:204` 语音房 | 默认 `true`，只挂 `onPopInvokedWithResult` 释放在场状态 | 不拦截，手势可用 |
| `system_surfaces.dart:554` 强制更新弹窗 | `false` | 对，这是 dialog 不是页面，版本低于下限时没有「返回」可言 |
| `system_surfaces.dart:609` `_StatePage` | 未传，默认 `true` | 不拦截；这层 `PopScope` 只为带一个测试用的 key，是冗余的一层 |
| `system_surfaces.dart:716` 策略门 | `!blocking` | 对，只有 region-blocked 这类真正拦住的页面才为 `false` |
| `money_actions_widgets.dart:288` 签名出口 | `_state != signing` | 对，钱包打开着时不能让签名悬空 |

也核了所有自定义 `pageBuilder`：只有五个 Tab 用 `LoopTabPage`，它们在 Shell 的
嵌套 Navigator 里且是 `isFirst`，本来就不该有返回手势；其余二级页全部是根
Navigator 上的默认 `MaterialPage`，没有一处阻断手势。

### 价格与折线

- `marketRowPrice` 在一美元以上一律走 `loopFormatUsd`，也就是「永远两位小数」。
  BTCB 于是是 `$85,866.13`（10 个字符），装不进 84pt 的定宽价格列。被截掉的是
  这一列存在的唯一理由。
- `MarketRowSparkline` 每行挂载时自己去要一份 `1h` candles。一屏八行就是八个
  请求，滚一次再来一批，provider 限流后大部分行拿不到序列——走查里「只有三行
  有小折线」是这么来的，不是渲染问题。

## Decision

### 1 · 转场交还给平台

`loopPageTransitionsTheme`：

- iOS / macOS → `CupertinoPageTransitionsBuilder`（原生视差 + 边缘右滑）；
- Android / fuchsia / linux / windows → `PredictiveBackPageTransitionsBuilder`
  （Android U 及以上跟手，其余回落 `FadeForwardsPageTransitionsBuilder`——
  正好就是第 7 章描述的「横向滑入 + 淡入」）。

`LoopPushTransitionsBuilder` 删除。留着一个没人用的转场类只会让下一个人把它装
回主题里。第 7 章的「味道」由平台 builder 提供，差异是视差曲线，不是方向。

**减少动效这里不加分支，也不允许加。** 一个 `if (disableAnimations) return child;`
会把手势检测器连着动画一起丢掉；而且它是多余的：`AnimationController` 本身读
平台的 disable-animations 标志，命中时把时长压到 0.05×，500ms 的 Cupertino 推
进变成 25ms。LOOP 自己的减少动效分支留在它们该在的地方——Tab 指示器和
`LoopTabPage` 的同级淡入，两者都不是路由手势。

Android 清单加 `android:enableOnBackInvokedCallback="true"`。targetSdk 36 本来
就开着 dispatcher，写出来是为了 API 33–35 的机器上手势和它的动画一起生效。

### 2 · 价格按量级取位，价格列可以挤名称列

`marketRowPrice`：

| 数值 | 小数位 | 例 |
| --- | --- | --- |
| ≥ 10,000 | 0 | `$85,866` |
| ≥ 1,000 | 1 | `$1,248.4` |
| ≥ 1 | 2 | `$747.39` |
| < 1 | 四位有效数字 | `$0.8741`、`$0.000001235` |

位数是**补齐**的，不是裁掉的：`$12.00` 与 `$12.30` 是一列，`$12` 挨着 `$12.34`
是参差的一列。阈值在四舍五入后重读一次——9,999.96 进位成 10,000.0，它属于上
一档。一美元以下沿用既有的 `loopFormatCompactFigure(preciseBelowOne: true)`，
只把有效位从 3 放宽到 4（新增可选参数，其他调用点不变）：行情价格列是唯一一处
把两行亚美元价格上下对读的地方。

`marketRowPriceWidth = 84` 从「宽度」改成「下限」，再加一个上限
`marketRowPriceMaxWidth = 124`。`Row` 先按无界宽度排非弹性子件，所以价格列超出
下限的部分是从旁边 `Expanded` 的名称格里取的——截断的「PancakeSwap Tok…」仍然
说清了这是哪一行，截断的价格什么都不说。涨跌块固定 70×30 不动；读不到的涨跌块
仍然是灰底「读不到」，不是 `0.00%`。

### 3 · 折线随行下发，行不再自己发请求

3.1 行模型加 `MarketAssetRow.sparkline`，类型 `MarketRowSparklineSeries?`
（`interval` / `observedAt` / `closes: List<Decimal>`）。`closes` 少于两个点时
`hasShape == false`，不画——一个点画出来是一条平线，那是在替 provider 下结论。

3.2 `MarketRowSparkline` 变成无状态组件，只画行自己带来的序列，**不读任何
controller**。没有序列就留空占位：槽位 48×24 照样占着，价值列不会逐行左右移动。
「为什么没有」属于代币页，那里有地方把话说完。

3.3 解码按 `{status, interval, closes[], observedAt}` 写好了，但 `sparkline`
这个键在 `strictMapWithOptional` 里仍是**可选**的：契约冻结前遇到老服务器要能
把列表画出来，而不是拒绝它。`status != 'available'` → `null`（行里没地方写
reason），`available` 但形状不对 → `invalidPayload`，和 LOOP 读其他事实一样。
**契约定稿后要做的唯一一件事**：把 `'sparkline'` 从 optional 挪进 required 集合
（`loop_v2_market_api.dart` 的 `_assetRow`）。

## Consequences

- 二级页的返回动画在 iOS 上变成原生视差（500ms），在 Android 上变成
  450ms 的 FadeForwards / 跟手的预测式返回。有一处测试的 pump 预算按此调整
  （`system_loading_truthfulness_test.dart`：400ms → 600ms，原值卡在 450ms 转场
  中间，旧页面还在树上时新页面已建，go_router 的 shell Navigator
  `GlobalObjectKey` 重复）。
- 行情列表在一屏内不再发 candles 请求；代币页的整图仍然走 candles，没有变化。
- 后端未下发 `sparkline` 之前，生产路径上的行情行没有折线（留空占位），符合
  「缺数据显示 unavailable，不回退 fixture」。
- 真机验收仍待：iOS 与 Android 各一次边缘右滑，以及开启系统「减少动效」后的同一
  次操作。widget test 覆盖了手势本身（`dragFrom` 从 x=2 起手确实 pop），但它跑在
  测试绑定上，不是触摸屏。

## Alternatives considered

- **在 Android 上包一层 `LoopPushTransitionsBuilder`**：可以保住第 7 章的曲线，
  但 `PredictiveBackPageTransitionsBuilder` 不接受自定义回落 builder，包在外面
  就等于再写一遍它的手势检测；收益是一条曲线，代价是又一处会悄悄吃掉系统手势的
  自写代码。不做。
- **价格列改成 `FittedBox` 缩字**：一列里字号逐行不同，价目表就不成列了。
- **行级折线继续用 candles，但加一层请求合并**：合并器要缓存、要失效、要限流
  退避，而这些服务端已经有了。让服务端在行里多带一个数组是更小的东西。
