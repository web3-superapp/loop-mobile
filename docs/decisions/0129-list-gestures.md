# 0129 · 列表手势：下拉、横滑、长按、到底自动续读、分段横滑（S123b）

## Status

Accepted 2026-10-09。主代理下单（S123b，审查 `docs/integration/review-2026-10-09/s123-interaction-audit.md` 的 M2 M3 M7 m7 m16 与 §五 规则 7、8）。
基线 `integration/v2` bd52fd1。不新增依赖、`pubspec.lock` 不变、路由清单不变。未用模拟器，验证为 widget 测试 + `flutter build apk --profile`。

## Context

S123 交互审查（真机 emulator-5554，profile 包）记下列表「像网页」：聊天列表没有下拉刷新、长按只打开会话、没有横滑（M2，截图 03/04/05/17）；
自选管理写着「左滑删除」但没做，头部「47 个自选资产」下面只有 4 行（M3，44/45）；成员 / 关注 / 陌生人请求 / 屏蔽 / 语音房名单等 8 处手动「载入更多」按钮（M7）；
广场、情报的分段不能左右滑切换（m7，41）；消息搜索必须按回车，说明里还写着已不存在的「社区 Tab」（m16，88/89）。

## Decision

### M2 聊天列表

- `StreamChannelListView` 包 `loopRefreshable`，下拉调用 `controller.refresh(resetValue: false)`：行留在屏上，不回骨架。
- 每行包 `ChatInboxSwipeRow`（`lib/features/chat/chat_inbox_row_actions.dart`）：向左滑露出 置顶/取消置顶、静音/取消静音、删除；向右滑露出 标为已读。
  开启时整行一次轻点只关闭、不打开会话；横向拖动越过 slop 才开始，竖向滚动归列表，列表一滚动已开的行就合上（`ChatInboxSwipeScope`）。越过半宽时 `selectionClick`。
- 长按行（Stream 自带 `onChannelLongPress`）弹 `showLoopSheet` 动作菜单（同上四项）+ `mediumImpact`。
- 能做什么只看 Stream 自己的频道状态，不支持的不画：置顶需要本人 membership；静音需要 `mute-channel` 能力；标为已读需要 `read-events`（或本地未读计数）且未读 > 0；
  删除 = Stream `hide()`（从本人列表移除，有新消息会回来，记录不清），只给私聊/群聊——社区官方群随社区，不在这里删。删除先过 `confirmCommunityAction` 确认抽屉。
- 列表排序改为 `pinned_at desc, last_updated desc`；置顶/取消后重读一次让行归位。失败统一 `LoopToast` err。

### M3 自选管理

- 行包 `Dismissible`（endToStart，busy 时不可滑）；左滑即从草稿移除，底部出「已移除 X，保存后生效 · 撤销」4 秒（`_WatchlistUndoToast`，Chalk + Lime 条，与 `LoopToastView` 同形），撤销按原分组原位置放回（`WatchlistEditorController.restore`）。拖动排序（把手）保留，两者手势不重叠。
- 「删除」小标与左滑同一流程（不再弹确认抽屉；未保存前什么也没离开服务器，撤销就是确认）。
- 47 vs 4 的来源：标题用 `itemCount` = 所有分组行数之和，同一资产在多个分组里被重复计数，而下方列表只画当前分组。改为：标题 = 去重后的资产数（`distinctAssetCount`，与行情 overview 的去重一致）；列表标签 = 「分组名 当前分组行数 · 拖动排序 · 左滑删除」。

### M7 到底自动续读

- 新 `LoopLoadMoreFooter`（`lib/widgets/loop_load_more.dart`）：有游标且控制器可读时，脚部进入视口一屏内即读下一页；读取中一行骨架；
  游标没动（失败）显示一行「下一页没有读到 · 重试」；无游标什么都不画。同一游标只问一次，游标变化（新页/刷新/到底）即清记忆。调用处给稳定 key。
- 替换 9 处按钮：成员、关注与粉丝、陌生人请求、屏蔽名单、语音房发言人/听众名单、好友（V1 未挂路由）、好友申请收到/已发送（V1 未挂路由）、社区搜索。语音房名单底部的「没有更多 XX」一并删除。

### m7 分段横滑

- `LoopSegmentSwipe`（`lib/widgets/loop_tab_segments.dart`，外观不变）：在分段主体上横向拖动松手时判定，距离 ≥ 72 或速度 ≥ 520 切到相邻分段，`selectionClick`。
  `LoopSegmentedTabPage` 默认装上（广场 社区/语音房、MEME、情报 算力榜/行情）；算力榜三榜自己也装一层，处在首/末榜时把滑动交给外层情报分段。
- 不冲突：横向列表（横滑卡）是更深的 Scrollable，手势竞技场里先拿到；图表区域用 `LoopSegmentSwipeBarrier` 吞掉横向拖动（行情行的迷你走势线已包）。

### m16 消息搜索

- 输入即搜（300 ms 防抖），回车与切换范围立即搜；变短到 2 字以下作废在途结果。删去「全局资产与社区搜索从社区 Tab 顶部进入」。

### Harness（审查 §五 7、8）

- `check_list_refresh_contract`：含 `LoopPageArchetype.listing` 的文件必须有 `loopRefreshable(` 或 `onRefresh:`，否则进 `LIST_REFRESH_EXEMPT`（带理由；豁免文件消失会报错）。
- `check_no_paging_buttons`：以「加载更多/载入更多/查看更多/下一页/上一页」开头的字符串字面量报错（含「没有/失败/读不到」的状态句除外）。
- 聊天列表 identity 规则放宽为：itemBuilder 内 `defaultItem` 只能作为 `loopStreamChannelListIdentityItem(defaultItem)` 的参数出现（允许外包横滑行）。

## Consequences

- 列表页默认可下拉；新列表页不装下拉会被 harness 拦下，除非写进豁免表并给出理由。翻页按钮文案被 harness 拦下。
- 聊天行的能做什么跟随 Stream 能力；服务端给了 `mute-channel` / `read-events` 才出现对应动作。删除只是对本人隐藏。
- 置顶排序依赖 Stream `pinned_at` 排序（服务端查询支持）；本地置顶后重读一次列表。
- 主代理合并后需要在模拟器 / 真机核对的手势见汇报清单；本单只做了 widget 测试与 APK 构建。

## Deviations

- 撤销 toast 是自选页本地组件：共享 `LoopToastHost` 刻意 `IgnorePointer`，加交互要改共享件（S123c 正在改 widgets），留给主代理合并时决定是否并入 `LoopToast`。
- 触感直接调 `HapticFeedback`（待 S123c 的 `LoopHaptics` 合并后统一）。
- 改到任务单外的文件：`lib/features/community/search_screen.dart`（第 9 处「载入更多」，规则 8 会拦）、`lib/features/intel/intel_rank_board.dart`（三榜横滑）、
  `lib/features/market/market_widgets.dart`（走势线屏障）、`lib/features/chat/v2/chat_search_screen.dart`（m16）、`scripts/check_harness.py`、`test/support/community_test_harness.dart`。
- 语音房名单在 Column 里（非懒构建），脚部以「离视口一屏内」为准才读，不会一次把全部页读完。
