# 0285 · 底部 Tab 栏真机三处缺陷：居中、毛玻璃、选中只剩光晕（S360-mobile）

## Status

Accepted · 2026-11-04（S360-mobile）。用户 11-04 22:25 在安卓真机 build65（integration/v2 6743338d）截图报三处问题；同日裁决「选中态按稿做软光晕（不做圆角矩形），毛玻璃必须真机可见」。改写 0261 的选中形状（玻璃胶囊 → 光晕），动效保留；0277 / docs/58 §5.18 的数值不变。

## Context

1. **图标文字偏上**：`LoopDockBar` 把五格放在 `Stack` 的非定位 `Row` 里，`Stack` 默认 `topStart` 且给子项松约束；格子只有 `minHeight 55`、内容 `Column` 居中，于是一行只有 55 高贴在 68 栏顶部，内容在上 55 里居中——图标 y≈5、文字 top≈34，底部多出 13。
2. **没有毛玻璃**：`BackdropFilter`（sigma 15，`ClipRRect` 内、格子之下）本身没问题；问题在栏后面没有东西可模糊。`LoopStreamPage` 的 `tabPage` 把整块滚动区包在 `Padding(bottom: 92 + 安全区)` 里，列表视口在栏顶就截止，栏后只剩墙纸暗底，模糊肉眼不可见（广场社区 / 动态 / 语音房、聊天四页都是）。Dashboard 页（MEME、我的）用滚动内 `SliverPadding`，本就能滚到栏后。
3. **选中项一个带硬边的大椭圆**：那是 0261 的玻璃胶囊 `loop-tab-indicator`（白 10% 底 + 1px 白 8% 描边 StadiumBorder，内缩 4），不是光晕。38 光晕 SVG（径向 24%→0）其实画在胶囊里、被胶囊盖成一团。

## Decision

- **格子布局**：`LoopTouch.tabCellMinHeight` 55 → 68（值改名不改），格子撑满栏高；图标顶 `LoopTabItem.glyphTop = 10`，图标 22（MEME 24）+ 间距 7（MEME 5）→ 文字 top 39，12/500/16（MEME 11/600/15）。触控区 68 × 70。
- **选中态**：去掉胶囊，选中的唯一标记是一个 38 圆 `RadialGradient`（`#FFD21C` 24% → 0，`LoopTabBar.haloGradient`），距栏顶 4、水平居中于格子（稿 (16,4)，圆心在图标圆心下 2）。不用 SVG（`nav-active-halo.svg` 保留但不再引用）。0261 的「同一个标记从旧格伸到新格」保留为「同一个光晕沿伸缩区间的中点滑过去」：前沿先走、后沿弹簧落位，光晕形状始终是 38 圆。按压整栏放大 2%、图标选中动效、颜色交叉淡入都不变；无底板、无描边、无涟漪。
- **毛玻璃**：`LoopStreamPage.scrollsUnderTabBar`（默认 false）——tab 页打开后滚动区不再在栏顶截断，列表自己在末尾留 `loopTabScrollBottom(context)`（= shell 给的 92 + 安全区）。广场三段与聊天打开；聊天列表原有 92 底距不变。模糊值仍是稿的 15。

## Consequences

- 以上即三条根因。
- 测试：`test/s360_tab_bar_device_fixes_test.dart`（图标 10 / 文字 39、选中无底板且光晕为 RadialGradient、BackdropFilter 15 在格子之下与 12 圆角裁切内、列表滚到栏后且末行仍在栏上、未打开的页不变）；`s331` / `loop_shell_test` 改为光晕断言。
- 新 tab 页若是 `LoopStreamPage` 且要毛玻璃，必须同时打开 `scrollsUnderTabBar` 并在自己的滚动视图末尾加 `loopTabScrollBottom`，否则末行会被栏挡住。
- 聊天 / 广场的空态、错误态现在也延伸到屏底（顶对齐，不受影响）。
