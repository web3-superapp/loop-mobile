# 0304 · MEME 详情页头部改回「符号为大字」、顶栏不放标题（S380-mobile）

## Status

Accepted · 2026-11-06（S380-mobile，基于 integration/v2 3c2486b6 = 安卓 build71）。改写 0303（S379）第 3 节「MEME 详情页头部」（派单里称第 4 条）：头像旁大字由代币全名改回代币符号，第二行由「符号 | 地址」改为「名称 | 地址」，顶栏不再显示任何标题。0303 的钱包卡、触摸动效、周期胶囊三项不变。

## Context

需求方 11-06 18:30 在安卓 build71 上反馈：S379 把头部改反了。build71 顶栏标题是 `loopTickerLabel(ticker)`，长符号（「猫猫啦咯啦咯啦咯啦咯啦咯啦咯」）在顶栏折成两行；头像旁大字是名称「猫猫」，下一行是被截断的符号 | 地址 | 阶段。需求方要的是 TF 69 之前 0240 的做法：符号是大字，名称在下一行。

## Decision

- 顶栏：`LoopDashboardPage` 传 `titleField: SizedBox.shrink()`（key `launch2-instance-no-title`），顶栏只剩返回和 ⓘ，360 / 390 / 412 任何宽度都不画标题。`title` 仍传 `loopTickerLabel(ticker)`（加载中为 `MEME v2`），只作顶栏的无障碍名称（`LoopTopbar.titleField` 已有的约定：设置后 `title` 不画、只作 Semantics label）。
- 头像 44 在左；右侧第一行是 `Launch2HeadSymbol`（原 `Launch2HeadName` 改名）：`loopTickerLabel(row.ticker)`（ASCII 符号带 `$`），`LoopType.headline`（19 / 700）Chalk，紧挨头像右侧；最多 3 行、不截断，超过 3 行降到 `headlineSm`（16 / 700），不设行数上限。各阶段都是 Chalk（不再随可交易阶段变黄）；阶段的颜色只在胶囊上。
- 第二行（仍在头像右侧列）一行到底、不换行：名称（`LoopType.caption`，Text2）+ 1×12 竖线 + 合约地址（中间省略，`codeSm` Text2）+ 复制键（44 触控）靠左；阶段胶囊在行尾、右缘贴内容区右缘。挤不下时地址先缩到 0，然后名称省略，复制键和胶囊不动。去掉 0303 里符号「最宽 120」的上限，名称取自身宽度，上限为行宽减复制键减竖线。
- key：`launch2-head-ticker` 现在是大字符号，`launch2-head-name` 现在是第二行名称；`launch2-head-address`、`launch2-head-rule`、`launch2-copy-address`、`launch2-stage-capsule`、`launch2-identity`、`launch2-instance-folio` 不变。
- 价格、24h 成交、K 线 / MA / VOL、周期胶囊、本轮状态卡未改。

## Consequences

- 新增 `test/s380_launch2_head_test.dart`（14 例）：三种宽度顶栏内无任何 Text、只有 ⓘ 工具、符号只在头部出现一次且顶栏无障碍名称为符号；三种宽度大字 = 符号、19 / 700 Chalk、换行不截断、在头像右侧；ASCII 符号带 `$`；放大字号下超 3 行降 16 / 700 仍完整；`styleFor` 档位；三种宽度第二行名称 / 竖线 / 地址 / 复制依次靠左、阶段右缘贴内容区右缘、名称 caption Text2；360 宽长符号 + 长名称不溢出、地址先缩到 0 再省略名称、胶囊不动；短名称保持自身宽度、地址取余量。
- 改写的旧断言：`test/s379_me_wallet_flat_chip_font_test.dart`「MEME detail head」组（全名大字 → 符号大字；「符号 | 地址」→「名称 | 地址」；超长降档改测 `Launch2HeadSymbol.styleFor`，因 codec 限制符号 ≤ 20 单位，正常字号下到不了 3 行以上）；`test/s182_launch2_desk_nft_test.dart`（nft_sale 头部符号 `FROG` → `$FROG`、黄 → Chalk；upcoming / paused 符号 Text2 → Chalk，名称 Chalk → Text2）。s285 / s136 / s353b / s359 / s355a / s285_shots 无需改动、已复跑通过。
