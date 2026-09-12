# 底色清单与深色专用色 token

适用范围：`lib/` 里任何绘制颜色的代码 —— 填充、描边、文字、图标、CustomPainter。

问题的形状：`LoopColors` 里所有柔和 token（`bg2` / `panel` / `card` / `card2` /
`line` / `line2` / `text2` / `text3`）都是同一个米白（Chalk `#F3F5EF`）把 alpha
调低。它们是为 Ink 深色页设计的。画在米白卡或柠檬绿卡上就是米白画米白：控件照样
布局、照样占 200px，只是什么都没有。**代码里看不出来，只渲染深色页的测试也看不
出来，只有真机上表现为「东西不见了」。**

守卫：`scripts/check_harness.py` 的 `check_light_ground_contract`（用例在
`tests/test_check_harness.py`）与 `test/s16e_ground_test.dart`（渲染探针，助手在
`test/support/loop_ground_probe.dart`）。本文件记录两条守卫都覆盖不到的部分。

## 1. 底色清单

| 底 | 颜色 | 谁画的 | 是否声明自己的底 |
| --- | --- | --- | --- |
| Ink 页面 | `#050604` | `LoopTheme.dark` 的 `scaffoldBackgroundColor` | 是（`ThemeData`） |
| Chalk 卡 | `#F3F5EF` | `LoopChalkCard` | 是 |
| Lime 卡 | `#B8FF20` | `LoopLedgerCard`（非 quiet） | 是 |
| Quiet 卡 | Lime 7.5% 叠在 Ink 上，实为深色 | `LoopLedgerCard(quiet: true)` | 是 |
| Lime folio | `#B8FF20` | `LoopFolioPrimary(variant: lime)` | 是（S16e 起） |
| Chalk folio | `#F3F5EF` | `LoopFolioPrimary(variant: chalk)` | 是（S16e 起） |
| Quiet folio | Lime 7.5% 叠在 Ink 上，实为深色 | `LoopFolioPrimary(variant: quiet)` | 是（S16e 起） |
| Chalk Token Card | `#F3F5EF` | `LoopTokenCard(chalk: true)` | 是（S16e 起） |
| 底部 Tab 栏 | `#F3F5EF`，选中格是 `#C6FF45 → #B8FF20` 渐变 | `LoopTabBar` / `LoopTabItem` | 否，但自己画完每一格，不接收外来 widget |
| Toast | `#F3F5EF` | `LoopToastView` | 否，同上 |
| 主按钮 | `#C6FF45 → #B8FF20` 渐变 | `LoopButton(primary: true)` | 否，同上 |
| 选中的 seg | `#B8FF20` | `LoopSeg(selected: true)` | 否，同上 |
| 下拉刷新指示器 | `#F3F5EF` 底 + Ink 弧 | `loopRefreshable` | 否，同上 |
| 收款二维码 | `#F3F5EF` 底 + Ink 模块 | `_QrPainter` | 否，同上 |
| Sheet | Ink + Lime 微光，深色 | `LoopSheet` | —— |

「声明自己的底」= 用 `DefaultTextStyle` + `IconTheme` 把该底的 ink 交给子树。
`LoopGround.*` 全部从这两者推导，所以**一个画浅色底却不声明的容器，会让每一个
`LoopGround` 派生出来的颜色都悄悄算错**。`check_light_ground_contract` 拦这件事：
注册在 `LIGHT_GROUND_CONTAINERS` 里的容器必须声明；任何画不透明 Chalk/Lime 填充
又持有 `Widget` 槽位的类必须注册。

## 2. 浅色底上的危险 token

| token | 实际颜色 | 落到浅色底上的后果 |
| --- | --- | --- |
| `LoopColors.chalk` | `#F3F5EF` | 米白底上完全消失 |
| `LoopColors.card2` | Chalk 10% | 填充消失（头像兜底、骨架块、索引方块） |
| `LoopColors.card` | Chalk 6% | 同上，更轻 |
| `LoopColors.panel` / `bg2` | Chalk 5.5% / 2.5% | 同上 |
| `LoopColors.line` / `line2` | Chalk 13% / 22% | 分隔线、网格线、控件描边消失 |
| `LoopColors.text2` / `text3` | Chalk 68% / 58% | 副文案与辅助文案不可读 |
| `LoopColors.textSecondary` / `textTertiary` | 同上（别名） | 同上 |
| `LoopDepth.liftPrimaryEdge` / `liftCardEdge` / `innerEdge` | Chalk 10% / 5.5% / 4% | 顶部高光边消失 |
| `LoopTypography.*` 的默认 `color` | `chalk` 或 `text3` | **不写 `color:` 就是危险默认值** |
| `LoopType.*` / `LoopMono.*` / `theme.textTheme.*` | 全部内嵌 Chalk 系颜色 | 同上；`DefaultTextStyle` 救不了显式颜色 |

对应的派生写法在 `LoopGround`：`inkOf` / `fillOf`(card2) / `tintOf`(card) /
`hairlineOf`(line) / `edgeOf`(line2) / `secondaryOf`(text2) /
`auxiliaryOf`(text3)。每个权重都从它替代的 token 上读 alpha，所以 **Ink 页上逐字
节不变**。

## 3. 两条守卫覆盖不到的部分（人工检查项）

静态守卫只看「浅色容器的参数里**字面**写了危险 token」；渲染探针只看「测试真的渲染
过的那一帧」。以下几类必须评审时人看：

- [ ] **间接传入的 widget**。一个 `Widget` 先存进变量、字段或 builder，再交给
      `LoopChalkCard(child:)` / `LoopFolioPrimary(trailing:)`，静态守卫追不到。
      新增这类间接时，问一句：这个 widget 会不会落到浅色底上？
- [ ] **`LoopTypography.*` 不写 `color:`**。默认值是 `chalk` / `text3`。
      守卫不拦（Ink 页上到处都这么写），浅色底上就是不可读。
- [ ] **`CustomPainter`**。`_QrPainter`、`LoopLedgerTexturePainter`、图表画笔
      都在 `paint()` 里取色，不经过 widget 树，探针看不到。
- [ ] **Lime 强调色落在 Lime 或 Chalk 底上**。`LoopColors.lime` 在 Ink 上是强调，
      在 Lime folio 上消失，在 Chalk 卡上对比度约 1.05，几乎读不出。
      `LoopBadge.onLedger` 是现有的出口；新增 Lime 文字/图标时必须问它在哪个底上。
      本项**故意没有自动化**：探针的文字对比度下限会把 Ink 页上大量合法的
      Lime 强调一起判错，放宽下限又拦不住真问题。
- [ ] **`lib/integrations/communication/stream_chat_appearance.dart`**。Stream 的
      主题对象由 SDK 消费，不是 LOOP 的 widget 树，两条守卫都不覆盖。它目前只服务
      深色聊天页。
- [ ] **动态底色**。任何由运行时值决定 `variant` / `chalk` 的调用点，守卫按「可能
      是浅色」处理；测试只覆盖它实际渲染过的分支。

## 4. 新增一个浅色底时

1. 在容器里加 `DefaultTextStyle.merge` + `IconTheme.merge`，颜色是该底的 ink。
2. 把类名加进 `scripts/check_harness.py` 的 `LIGHT_GROUND_CONTAINERS`，并列出它
   对外开放的 widget 槽位名。
3. 在 `test/s16e_ground_test.dart` 的 `_grounds` 里加一行，整份 `_catalogue` 会
   自动在新底上跑一遍。
