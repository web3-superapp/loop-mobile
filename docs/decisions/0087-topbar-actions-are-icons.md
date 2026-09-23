# 0087 · 顶栏动作一律是图标，词留在名字里

## Status

Accepted 2026-09-23。S82b，客户端单侧。不新增路由，93 条路由清单不变，
没有接口、没有 view model、没有状态合同的改动。

改动范围：`lib/widgets/loop_components.dart`（`LoopIconButton` 增加
`onBlocked` 与 tooltip）、`lib/core/assets/loop_assets.dart` 与
`assets/icons/`（新增 `i-plus.svg`、`i-share.svg`）、六个页面各自
`actions:` 的那几行、`scripts/check_harness.py`（新增结构性守卫）。
页面主体、folio、列表、五态一行未动。

## Context

需求方 2026-09-23 提的要求只有一句：**顶栏里的文字按钮全部换成图标按钮**，
并点了几个例子（价格提醒页右上角的「新建」、钱包页的动作、授权页）。

盘点的口径是 `LoopTopbar.actions`——也就是 `LoopFocusPage` /
`LoopDashboardPage` / `LoopStreamPage` 三个页面骨架和 `LoopTopbar` 本身接到的
`actions:`。全 App 共 33 处顶栏动作，其中 27 处已经是字形控件——24 个
`LoopIconButton`（搜索、铃铛、信息、用户、设置、星标、时钟、钱包……）加社区首页
那 3 个 `CommunityToolButton`——**6 处是 `LoopSeg` 文字药丸**：

| 页面 | route | 原文字 | 新图标 | 无障碍名（未变） |
| --- | --- | --- | --- | --- |
| 价格提醒 | `/market/alerts` | 新建 | `plus` | 新建 |
| 自选管理 | `/market/watchlist/edit` | 完成 | `check` | 完成 |
| 授权盘点 | `/wallet/approvals` | 批量回收 | `blocked` | 批量回收 |
| Wallet 资产 | `/wallet/asset/:id` | 行情 | `chart` | 行情 |
| 我的钱包 | `/wallet/manage` | 添加 | `plus` | 添加 |
| 交易历史 | `/wallet/history` | 导出 / 导出中 | `share` | 导出 / 导出中 |

这 6 处不是随手写的，是**照着冻结原型抄的**：`#scr-alerts`、
`#scr-watchlist-edit`、`#scr-approvals`、`#scr-wallets`、`#scr-tx-history`、
`#scr-asset` 六段的顶栏里，右侧控件确实都是
`<button class="seg" style="min-height:44px">…</button>`。所以本单是一处
**有意偏离冻结原型的文案呈现**，依据是需求方 2026-09-23 的口头裁决；原型文件
本身不动，偏离记在这里。

需求方点到的另外三个例子——行情页「自选」、钱包页「切换钱包」「交易记录」——
核过了，它们**已经是图标**：`自选` 是行情页的 tab（`MarketTabBar`），不在顶栏；
`切换钱包`/`交易记录` 是 `wallet` / `clock` 两个 `LoopIconButton`，语义名就是这
两个词。代币页右上角的 `自选` 星标也早就是图标，且在自选中时上 Lime。

## Decision

### 1 顶栏只放字形，词移进名字

一条顶栏里已经有返回控件和一个可能折两行的标题；一个中文词是那一行里最宽的
东西，而 6 个页面写词、27 个位置画图，同一条栏在不同页读起来不一样。统一成
字形。

**词一个字都不删**，只是换了住处：`LoopIconButton.label` 同时是

- 语义树里的 `Semantics.label`（走查脚本按名字找控件，名字必须保住）；
- 长按弹出的 `Tooltip.message`（新增，`excludeFromSemantics: true`——名字已经由
  上面那层 `Semantics` 播报过一次，tooltip 再播一次会让每个控件念两遍自己的
  名字）。

`导出` 那个按钮的 `label` 仍然随状态在 `导出` / `导出中` 之间切换：这一位状态
以前只由那个词承载，换图标不能把它弄丢。

### 2 保留原型药丸的「有边」，只换内容

这六个位置原来是 `.seg`：卡片底 + 发丝边 + 14 圆角。换成
`LoopIconButton(framed: true)`——卡片底 + 发丝边 + 13 圆角、44×44。视觉重量与
原型一致，变的只有里面是词还是形。社区首页顶栏那三个圆角方块
（`CommunityToolButton`）是同一形态的另一种底色，本单不动它。

### 3 `LoopIconButton` 学会 `onBlocked`

`批量回收` 和 `添加` 两处原本靠 `LoopSeg.onBlocked` 工作：控件按禁用画、按禁用
播报，但**仍然接住那一下点击**并给出理由（决策 0079）。`LoopIconButton` 以前
没有这个能力，`onPressed: null` 就是彻底吞掉点击。图标比词更需要它——`批量回收`
四个字摆在那儿本身就说明了自己是什么，一枚灰色的禁止号不会。于是把 0079 的同
一笔交易照搬进 `LoopIconButton`：

```dart
onTap: onPressed ?? onBlocked,   // 画与播报仍只看 onPressed
```

### 4 两个自绘字形

原型精灵表（61 个）里没有「多一个」和「交给系统」这两个形——因为原型这两处是
文字药丸，压根不需要。按与导入表完全相同的规格自绘：24 画布、`fill="none"`、
`currentColor`、1.7 描边、round 端点与拐角，因此颜色和尺寸照样从调用方继承。

- `i-plus.svg`：`M12 5.2v13.6M5.2 12h13.6`
- `i-share.svg`：箭头出托盘，系统分享的通用形，正好是「导出」那一下真正做的事

精灵表从 62 个（61 + `refresh`）变成 64 个。`i-edit` / `i-endpoint` /
`i-provider` 在原型里出现过但从未导入，本单也不导入——没有用到。

### 5 守卫写成结构性的，不是词表

`scripts/check_harness.py` 新增 `check_topbar_action_glyph_contract`：对
`LoopFocusPage` / `LoopDashboardPage` / `LoopStreamPage` / `LoopTopbar` 的每一个
`actions: <Widget>[…]`，读它的**直接子元素**，出现 `LoopSeg` / `LoopButton` /
`LoopBadge` / `Text` 即失败。

只看直接子元素是必要的：`添加` 的 `onBlocked` 里开的那张 sheet 有一个
`LoopButton('知道了')`，`批量回收` 的 toast 里有文案，聊天收件箱的 `IconButton`
里套着 `Badge(label: Text(...))`——那些是各自控件自己的事。实现上按括号栈判断：
只有当从元素起点到该位置为止所有未闭合的括号都是 `[` 时，才算列表的直接子项。

守卫在改动前的工作树上跑，正好报出上面那 6 行，一行不多；改动后为零。

## Consequences

- 顶栏在全 App 同一读法：返回 + 标题 +（0–4 枚）44 网格上的字形。
- 语义树不变。走查脚本按「新建」「完成」「导出」「批量回收」「行情」「添加」
  找控件仍然找得到，`find.bySemanticsLabel` 依旧命中。
- 长按任一顶栏图标会浮出中文名，这是图标化之后新增的一条自解释路径。
- **不在本单范围**：仍在用 Material `AppBar` 的历史页面
  （`lib/widgets/loop_ui.dart` 的 `LoopPage`、`chat_inbox_page`、
  `conversation_pages`、`perp/*`）。它们的顶栏动作本来就已经是图标
  （`IconButton` + Material 图标），只是英文 tooltip；换成 LOOP 描边字形属于这
  些页面各自的还原任务，不在「文字换图标」这条要求里。守卫也因此只盯 LOOP 页面
  骨架。
- 精灵表一致性测试 `loop_assets_test.dart` 的两处计数从 62 改成 64，并各加一条
  `contains` 断言；「每个字形都按同一张表的规格画」那条测试对新字形自动生效。

## Verification

```
bin/flutter pub get --enforce-lockfile
bin/dart format --output=none --set-exit-if-changed lib test
bin/flutter analyze
bin/flutter test
python3 scripts/check_harness.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

新增 `test/s82b_topbar_icons_test.dart`：六个替换点各一条，全部**按语义名**找控件
再点击，断言字形名、无障碍名、tooltip、44 触控区，以及点击后的行为与替换前一致
（编辑器打开、草稿提交、理由 toast、路由跳转、说明 sheet、CSV 交给分享口）。
