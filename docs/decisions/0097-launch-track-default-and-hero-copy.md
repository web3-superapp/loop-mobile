# 0097 · 发射轨道默认展开、手风琴内容宽度、Launch 首屏与详情文案对齐链上事实

## Status

Accepted 2026-09-27。S89a 修复，客户端单侧。主代理模拟器验收（Pixel 440 dpi，Launch →
待排期 → 发射 #5）发现四个缺陷。不新增依赖、`pubspec.lock` 不变、不改路由清单（93 条
不变）、不改接口契约与解码逻辑、不新增网络请求。

## Context

Launch 合约已在 BSC 测试网上线（`launch` capability evidence 为 confirmed，带
`launchContractVersion`，决策 0093），但首屏仍写死「链上状态……暂时读不到」+ `OFF-CHAIN`，
已毕业卡仍说「合约还没有上线」；详情页读取中借用了读取失败的句子与「暂无名称」；sale 已结束
时发射轨道三条等宽空壳，224 dp 空白；打开条的右对齐数字被裁 2 dp。

## Decision

### 1 手风琴打开条的内容宽度（`lib/widgets/loop_accordion_strip.dart`）

条的 `Ink` 装饰带 1 dp `Border.all`，`Ink` 会把装饰的 padding 叠进子节点，因此内容区比
`openWidth - 2 × padding` 再少 2 dp，右对齐数字（「04:36」「USD1」）末字被裁。边框宽度
收为常量 `_border = 1`，detail 的 `SizedBox.width` 与 `OverflowBox.maxWidth` 都取
`openWidth - (_padding + _border) × 2`。`fits()` / `openWidthFor()` 语义不变。

### 2 发射轨道「当前条」默认展开（`launchTrackInitialIndex(rounds, now)`）

- 有进行中的轮次 → 该轮；
- 所有轮次都已结束（now ≥ 最后一轮 endAt）→ END 条（索引 = 轮次数）；
- 否则 → 下一个要开始的轮次；尚未开售时即第一轮；
- 无轮次 → 不展开（`null`）。

「两轮之间」任务单未明示，取「下一个要开始的轮次」，与「当前条」一致。

### 3 `launch-detail` 加载态（决策 0095 的延伸）

详情未读到且仍在读取时：标题走 `LoopFolioPrimary.headingLoading` 同高骨架（语义标签
「项目资料读取中」），caption 为中性的「正在读取项目资料与链上状态」。只有读取结束且
`onChain` 为空时才用「……链上状态、价格与毕业进度暂时读不到。」；「暂无名称」只在读取完成
而 name 为空时出现；读取失败时标题为「没有读到项目资料」。区分读取中与读取结束用的是现有
`LaunchResourceState.phase`，未新增 view model 字段。

### 4 Launch 首屏 hero 与 baseline-pending 文案

- 首屏 caption / stamp 由目录各分段里是否存在 `onChainState.source == "chain"`
  （`LaunchOnChainAvailable`）的项推导：有 → 「目录、申请与轮次配置由 LOOP 提供；链上状态
  读自 BSC 测试网。」（Launch 链槽不是测试网时为「BSC 主网」）与 `ON-CHAIN`；没有 → 原文案与
  `OFF-CHAIN`。
- `LoopCapabilityProjection` 新增 `evidenceConfirmed`（`launch` evidence 为
  `confirmed`，决策 0093），取自现有 `loopCapabilityProvider`。confirmed 时
  `LAUNCH_CONTRACT_BASELINE_PENDING` 在「已毕业」卡读「已毕业名单还没有开放读取」，在详情
  「内盘持有人」行读「参与人数还没有开放读取」；未 confirmed 保持原句。全局
  `launchReasonCodeText` 不变，由 `launchBaselineReasonText` 在两处调用点覆盖。
- 目录行副标题：在「发射中」「已结束」分段里用链上 saleState 的中文（`launchSaleStateLabel`：
  已排期 · 未开售 / 销售进行中 / 销售已结束 / 销售成功 / 未达软顶 / 已取消，暂停时「已暂停」），
  没有链上读数时用分段名本身；不再出现「已批准 · 待排期」。其余分段保持 scheduleStatus 文案。
  分段本身的归属由后端 S83b7 按 saleState 推导，前端未改分段逻辑。

## Consequences

- 文案只在事实到达后改口：首屏的 `ON-CHAIN` 依赖目录行真的带链上读数，而不是 capability；
  「合约还没有上线」只在 evidence 未 confirmed 时出现。
- `LoopCapabilityProjection` 多一个只读字段，其他能力与既有判定（`evidencePending`、
  `isUsable`）不变。
- 若后端以后为已毕业名单或参与人数给出专门的 reasonCode，应替换这两处覆盖句。

## Evidence

- `test/s89a_launch_track_accordion_test.dart`：详情内打开条的 detail 宽度 == 条宽 − 22、
  右对齐数字不越过内容边；独立挂载 `LoopAccordionStrip` 的 detail RenderBox 宽度与末字右缘；
  `launchTrackInitialIndex` 五种情况（进行中 / 全部结束 / 未开始 / 两轮之间 / 无轮次）；
  两轮之间打开下一轮、全部结束打开 END。原「无进行中轮次则全部等宽」用例按新规则改写。
  两条宽度用例在回退修复后确认失败。
- `test/s89a_launch_hero_copy_test.dart`：详情读取中骨架与中性文案、读取完成两种 caption、
  失败不出「暂无名称」；首屏 OFF-CHAIN / ON-CHAIN 与测试网/主网文案；confirmed 与 pending
  下的已毕业卡与参与人数行；发射中 / 已结束分段副标题不出「待排期」，待排期分段保持原文。
- 全量 3633 通过（3 skip 不变）。
