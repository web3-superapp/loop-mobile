# 0082 · LoopSeg 按自己的宽度排版

## Status

Accepted 2026-09-23。S80，客户端单侧，只动共享组件与两处局部绕过。不新增路由，
93 条路由清单不变；无接口依赖、无文案变更、无 token 变更。

## Context

2026-09-23 真机走查（h05）记下两处同样的版式问题：兑换页「滑点上限」的三个档位
竖排成三个整宽按钮，资料编辑页「关注赛道」的五个兴趣标签同样一行一个。S77a 在
滑点处把 `Wrap` 换成 `Row` + `Expanded`（等分三格），S77c 在兴趣标签处包了一层
`IntrinsicWidth`。两次都只压住了症状。

根因在 `LoopSeg` 自己：它用 `Container(alignment: Alignment.center)` 居中标签，
而 `Container` 的 `alignment` 编译成 `Align`——`Align` 在没有 `widthFactor` 时，
只要收到的 `maxWidth` 是有限值就撑满它。`Row` 给非弹性子件的主轴约束是无限的，
所以横向滚动的 `.segs` 一直是对的；`Wrap` 与 `Column` 给的是「松但有界」的约束
（min 0 / max 一整行），于是每个 chip 都吃满整行宽，`Wrap` 只能每行放一个。
`loop-id`（开户第 4 步）的「关注赛道」同一个 `Wrap` 里也有这个病，只是没被记下。

## Decision

### 1 · chip 量自己的标签，撑满是页面显式要的

`LoopSeg` 的 `Container` 拆成 `ConstrainedBox`（44×44 触控下限）+
`Align(widthFactor: 1)` + `Padding`：

- 松约束（`Wrap` / 默认 `Column` / `Center`）下宽度等于标签宽 + 30 的左右内距，
  不足 44 时补到 44；
- 紧约束（`Expanded`、`CrossAxisAlignment.stretch` 的列、`ListView` 的横轴）下
  仍然撑满——约束优先于 `widthFactor`，既有页面的行为不变；
- 需要整行时页面显式写 `block: true`（对齐 `LoopButton.block` / `.btn-block`
  的命名）。今天没有调用点用它，它是给将来要整行 chip 的页面留的出口。

顺带修好的一点：`Align` 现在拿到的是含 44 下限的约束，短标签（「1%」）被补到
44 宽时标签是居中的，以前它停在左内距上。

### 2 · 两处局部绕过撤掉

- `swap`：滑点段回到 `Wrap(spacing: 8)`，三个档位各自按「0.5% / 1% / 3%」的宽度
  排在一行。等分三格是 S77a 为了绕开这个 bug 引入的，原型的 swap 页根本没有这个
  选择器（滑点是明细里的一条读数），等分让三个档位看上去像三个动作。
- `profile-edit`：兴趣标签去掉 `IntrinsicWidth`，回到普通 `Wrap` 流式排列。

`community-ai` 的两处示例问题 chip 仍留着 `IntrinsicWidth`（S76 引入，不在本单
范围内）。修好根因后它们是冗余的一层，宽度结果一致，下次改到那页时再摘。

### 3 · 调用点核查

31 处 `LoopSeg` 调用点逐个核过：横向滚动 `.segs`（社区、社交、行情、钱包、
Launch）与顶栏 `actions` 都在 `Row` 的无界主轴里，本来就是按内容取宽；
`swap` 的旧写法与 `CrossAxisAlignment.stretch` 的列是紧约束，行为不变。没有任何
页面依赖「松约束下也撑满」，因此没有调用点需要补 `block: true`。
`loop-id-setup` 的「关注赛道」`Wrap` 不改一行代码就跟着修好了。

## Consequences

- 共享组件回到「chip 是一个 chip」的语义，后面的页面把 `LoopSeg` 放进 `Wrap`
  不会再撞同一个坑，也不需要 `IntrinsicWidth` 这种按次绕行。
- `LoopSeg` 的公开 API 多了一个默认 `false` 的 `block`，既有调用点不受影响。
- 测试：`test/loop_components_test.dart` 增一组 5 条——松约束按内容取宽（与无界
  `Row` 里的同一 chip 等宽）、短标签仍有 44 触控、紧约束仍撑满、`block: true`
  取整行、`Wrap` 里三个档位同一行三个不同横坐标。S77a 的「滑点一行」回归测试
  继续守着页面侧的结果。
