# 0135 · 内嵌图表在滚动页里可拖可缩、十字线逐桶触感；未读停靠条两枚按钮 44 pt 热区（S131）

## Status

Accepted 2026-10-10。主代理下单（S131-mobile），基线 `integration/v2` 1af7ae0，分支 `fix/S131-chart-gestures-unread-touch`。
来源：交互审查 `docs/integration/review-2026-10-09/s123-interaction-audit.md` §二 2.5 / §三 m6、§五 规则 9（触控 ≥ 44）与规则 11（触感只经 `LoopHaptics`）；
决策 0134「未做」第三条（浮条两枚按钮是 Stream 的 32 dp）。不新增依赖，路由清单不变，视觉 token 不变。

## Context

1. **m6**：`token`（及 MEME 详情）页内嵌的 `LoopMarketChart` 与 `chart-full` 是同一个组件、同一套手势（决策 0118），
   但内嵌时放在纵向滚动页里。原实现用 `GestureDetector(onScale…)`：`ScaleGestureRecognizer` 要单指走满 36 pt（pan slop）才认领，
   而页面的纵向拖动只要纵向走满 18 pt 就认领。真机拇指横划总带一点纵向漂移——偏角超过约 30° 时纵向 18 pt 先到，页面赢走整个手势，
   所以内嵌图表「拖不动」，全屏页（页面几乎不滚）才拖得动。
2. 十字线：出现时有 `LoopHaptics.medium()`（决策 0130），在不同桶之间移动时没有任何触感。
3. 未读停靠条（决策 0134）里的「↑ N 条未读」与「×」是 Stream `StreamButton` 的 small 尺寸（高 32、× 为 32×32），
   `tapTargetSize: shrinkWrap`，低于 44；按下态是 Stream 的底色覆盖，没有触感。

## Decision

### 一、图表手势判定（`lib/features/market/loop_chart_gestures.dart`）

新增 `LoopChartScaleGestureRecognizer extends ScaleGestureRecognizer`，在触控 slop（`computeHitSlop`，触摸 18 pt）处按**按下点起算的位移方向**自己判定：

- 单指、横向位移 > slop 且 |dx| > |dy| → 立即 `resolve(accepted)`，图表接管（平移；之后再落第二指即缩放）；
- 单指、纵向位移 > slop 且 |dy| ≥ |dx| → 立即 `resolve(rejected)`，图表退出竞技场，页面的纵向拖动无对手地接管；
- 第二根手指在判定前落下 → 视为捏合，立即接管。

图表在命中测试里比页面的 `Scrollable` 更深，同一个 move 事件先到图表，所以横向占优的手势在 18 pt 处总是先于页面判定；
父级 `ListView` 不会被锁死——纵向占优的手势图表主动让出。原生 `ScaleGestureRecognizer` 的 36 pt 判定不再触发（任一方向超过 25 pt
之前本判定已经给出结论）。长按十字线仍用标准 `LongPressGestureRecognizer`：手指不动 500 ms 才赢，移动超过 slop 即被上面两条之一接走。

`LoopMarketChart` 用 `RawGestureDetector` 挂这两个识别器（key `loop-market-chart-gestures` 不变）。内嵌（`TokenCandleSection` / MEME 图表区）
与全屏（`chart-full` 也是 `TokenCandleSection`）是同一个组件实例类型，因此缩放范围（20–300 桶，`LoopChartViewport`）、平移换算、
左缘 24 pt 手势保护（决策 0118）完全一致——复用而非复制。两处目前都**没有惯性**（松手即停），保持一致，未新增。

页面滚动中不误触：页面正在惯性滚动时，`Scrollable` 自身在内容上套 `IgnorePointer`，此刻落在图表上的那一下只会让页面停下，不会平移图表、
也不会出十字线（测试固定此行为，不需要额外代码）。

### 二、十字线触感

`_crosshairAt` 在十字线从一个桶移到另一个桶时播 `LoopHaptics.selection()`（「同级之间的选择变了」）；出现时仍是 `medium`（决策 0130），
同一桶内移动不响。harness `PRESS_HAPTICS_CALL_SITES` 为 `loop_market_chart.dart` 增加 `LoopHaptics.selection()`。

### 三、未读停靠条（`lib/integrations/communication/stream_unread_pill_band.dart`）

不再用 Stream 的 `UnreadIndicatorButton` / `StreamJumpToUnreadButton`，改为本文件的 `LoopUnreadJumpPill`：

- **外观不变**：底、描边、圆角、阴影高度 3、内边距、图标（`streamIcons.arrowUp` / `xmark`，16）、文字（`captionEmphasis`）、颜色全部从
  Stream 主题（`context.streamColorScheme` 等）按 `DefaultStreamJumpToUnreadButton` 的同一套数值取；测试比对胶囊宽高与 Stream 原件一致（±0.5）。
- **热区**：「↑ N 条未读」与「×」各是一个 `LoopPressable`，高 44（胶囊面 40，上下各外扩 2）；× 宽 44（图标方块 32 + 右侧向胶囊外扩 4），
  左侧「↑」区同样向外扩 4 以保持胶囊居中。热区画在胶囊面之上、不改变胶囊面尺寸。
- **按下态**：`LoopPressable` 的变暗 + 缩小（减弱动态时只变暗）；**触感**：点按落下时 `LoopHaptic.light`。
- 读屏：「↑」合并为一个按钮「N 条未读」，× 标注「标为已读」。
- 条带上边距从 `LoopSpacing.x2` 减去外扩量，胶囊面的位置与 0134 相同；条带总高多 2 pt（下沿热区外扩），列表顶仍在条带下方。
- ↑ 的跳转与 × 的 `markRead` 逻辑不变（0134）。

harness：`PRESS_HAPTICS_CALL_SITES` 增加本文件（`LoopPressable(` 与 `haptic: LoopHaptic.light`）；
`test/s123c_haptics_press_test.dart` 的触控尺寸清单（Android 44 / iOS 44 / 有标签）加入 `LoopUnreadJumpPill`。

## Tests

- 新 `test/s131_chart_gestures_unread_touch_test.dart`（8 例）：
  - 图表放进纵向 `ListView`：以 35° 偏角、每步 4×2.8 pt 的小步横划，图表窗口平移、页面不动（旧实现下此例失败，页面先赢）；反向带漂移拖动窗口回移；
  - 在图表上纵向上拖，页面滚动 > 100 pt、图表窗口不变；
  - 页面内双指捏合，可视桶数从 60 变少、页面不动；
  - 页面惯性滚动时落指横拖，图表窗口不变；
  - 图表挂的是 `LoopChartScaleGestureRecognizer` + `LongPressGestureRecognizer`；
  - 长按：先 `medium`，换桶后只追加 `selection`，同桶内微移不再响；
  - 停靠条：两枚按钮尺寸 ≥ 44×44，胶囊面宽高与 Stream 原件一致，× 热区越过胶囊右缘与上缘；
  - 在 × 热区外角（胶囊面外）按下：按下态 `pressOpacity`，松开触发 dismiss 并播 `light`；点 「N 条未读」 触发 jump 并播 `light`。
- `test/s130_unread_pill_band_test.dart`：查找对象从 Stream 组件改为 `LoopUnreadJumpPill`，并断言 Stream 的浮条组件不出现；× 改按 key 点。
- `test/s123c_haptics_press_test.dart`：触控尺寸清单加入停靠条。
- 原有图表测试（`s113` 拖动 / 左缘保护 / 捏合 20–300 / 十字线）不改且通过。

## Consequences

- 内嵌图表横划（偏角 < 45°）一律归图表，纵划一律归页面；斜 45° 附近的手势按先越过 18 pt 的轴归属。
- 停靠条外观与 0134 相同，按钮热区达到 44 pt，按下有反馈与轻触感。

### 未做

- 惯性（松手后继续滑动）：全屏与内嵌都没有，本单要求「与全屏一致」，故未新增；若需要可在 `onScaleEnd` 的速度上统一加。
- 真机手感（尤其斜划判定阈值与十字线逐桶 selection 的密度：60 桶约 5 pt 一响）需主代理真机验收确认。
