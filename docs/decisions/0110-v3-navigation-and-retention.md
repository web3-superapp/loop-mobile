# 0110 · v3 导航重构：聊天/广场/MEME/情报/钱包，旧四 Tab 保留为子页面（S106）

## Status

Accepted 2026-10-08。S106 前端第一批。基线 `integration/v2` ebf5f49。不新增依赖、`pubspec.lock`
不变。路由清单 93 → 97，重新冻结（`frozenAt` 2026-10-08）。依据：`LOOP/docs/09-需求方v3需求与裁决.md`
§1–§2、`LOOP/docs/modules/S106-v3-navigation.md`、`LOOP/docs/00-主代理规则.md` §4.1。取代决策 0048
的五个主入口（0048 的其余内容不变）。

## Context

需求方 2026-10-08 把一级导航改为 聊天 / 广场 / MEME / 情报 / 钱包，并裁决：IDO Launch 保留代码、UI
隐藏、可一键恢复（A4）；挖矿资产/奖励/规则放 Me 页（A5）；聊天页头像进 Me，钱包页底部设置（B6）。
原型没有这些页面，由主代理设计、需求方真机验收。

## Decision

1. **路由清单**（`docs/product/routes-manifest.json` 与 `LOOP/docs/routes-manifest.json` 同文，
   `lib/core/navigation/route_manifest.dart` 镜像）新增四个 tab slug：`chat`(/chat, 2-community)、
   `square`(/square, 2-community)、`meme`(/meme, 4-launch)、`intel`(/intel, 3-market)，
   `prototypeOrder` 100–103（原型外页面）。`community` / `mining` / `launch` / `market` 改
   `tab: false`，路径、页面、状态不变。`defaultRoute = chat`；`/home` 兼容重定向改到 `/chat`；
   非法路由记录后落 `/chat`。`/chat` 从 supplementary 列表移入清单，`/chat/dm` 等子路径不变。
2. **清单指纹**：`sha256` 改为清单自身内容的指纹——对 `defaultRoute`、`tabs`、`count`、`modules`
   做 UTF-8 规范 JSON（键排序、紧凑分隔符）后 SHA-256；算法写在 JSON 的 `sha256Basis`，
   `scripts/check_harness.py` 每次重算比对。原型哈希 `bdbe1832…` 保留在 `prototypeSha256`，
   Dart 侧 `LoopRouteManifest.prototypeSha256`。
3. **壳**：`LoopShell._destinations` = 聊天(chat 图标) / 广场(compass) / MEME(launch) /
   情报(chart) / 钱包(wallet)。旧四个页面移出 ShellRoute，作为普通子页面挂在根导航上，各自带返回
   （`onBack` → pop，栈底时回 `/chat`）。
4. **聊天 Tab**（`StreamChatInboxPage` 升级）：Stream 官方频道列表（社区群聊 + 私聊 + 小群），
   筛选 全部/社区/好友 只按服务端分配的 CID 前缀隐藏行，不重查、不读显示名；顶栏左为本人头像
   （进 `/profile`），右「＋」底部菜单：搜索/添加用户、创建社区（与发现社区同一申请流程，
   `startCommunityApplication`）、创建群聊、扫一扫（本版无相机路径，提示暂未开放）。陌生人请求行
   只在陌生人请求列表读到待处理项时出现并显示条数。Preview 与 Stream 未连接
   一律关闭列表，不显示任何夹具会话；Preview 会话页仍在各自受保护的路由上。
5. **社区页退役面板**：`CommunityScreen` 去掉搜索面板、消息面板与「个人中心」按钮（职责已归聊天
   Tab），去掉 `tabPage`，作为子页面保留在 `/community`。
6. **广场 Tab**：页内两段（标题行即分段，选中段为页面标题，与筛选条区分）：社区 = 发现社区目录
   （嵌入模式，无顶栏）；语音房 = `GET /v2/voice-rooms/live`。目录与语音房列表都改为滚动到底自动
   读下一页（`LoopLoadMoreSentinel`，每个 cursor 只读一次，失败页给「重试」），不再有「载入更多」。
   追加页按 id 去重。分段选择记在 `loopTabSegmentMemoryProvider`，离开 Tab 再回来保留。
7. **语音房列表契约**按 loop-api `integration/v2` 0748c31 的最终形状写 codec（严格键集）：
   `communityLogoRef`（预设引用，不是 URL）、`title` 恒空用社区名、`host` 三字段同空 = 匿名主持
   （显示 `voiceRoom.member.anonymousMember` 文案）、`countsObservedAt` 恒空；人数文案为
   「N 人已加入」（listener + speaker，不含主持），不写「在线」。`404`（模块未启用或路由不存在）
   与 `503 CAPABILITY_UNAVAILABLE` 都走不可用态，不显示空列表或假数据。`joinable=false` 时进社区
   资料页并提示先加入。Preview 用 `MemoryLiveVoiceRoomGateway`，只在 `main_preview.dart` 注入，
   页面带「演示数据」提示。
8. **MEME Tab**：发射台 | 行情。发射台在 `idoLaunchVisible` 为真时渲染 `LaunchScreen`（嵌入），
   否则空态「发射台即将开放」；行情段空态「平台 MEME 资产上线后在这里显示」。
9. **情报 Tab**：算力榜 | 行情。算力榜 = `MiningRankScreen`（嵌入）加第三个榜「推广榜」，后端没有
   推广 scope，选中时显示「推广榜还没有开放」，不读任何数据；行情 = `MarketScreen`（嵌入，
   `hideOutboundLists`）去掉「新币」分段与「聪明钱」入口，自选空态的添加行改为切到「热门」。
   两个页面的路由保留。
10. **我（`/profile`）**：标题「我」，顺序：身份卡、挖矿（总算力 + 挖矿资产/奖励/规则 + 挖矿总览）、
    邀请（邀请码一键复制，行进 referral）、我的社区、账户（钱包/隐私/安全/关注与粉丝/好友请求/
    通知设置）、设置、退出登录。「参与记录」「我的资格」跟随 `idoLaunchVisible`。
11. **功能开关** `lib/core/config/loop_feature_switches.dart`：`LoopFeatureSwitches`
    （`idoLaunchVisible = false`、`groupAliasVisible = false`）为编译期常量，页面经
    `loopFeatureSwitchesProvider` 读取，测试覆盖两种取值；开关只决定入口与渲染分支，不改路由表、
    不改请求。`groupAliasVisible` 本批只定义。
12. **页面骨架**：`LoopDashboardPage` / `LoopStreamPage` 增加 `embedded`（不画顶栏，供分段页嵌入），
    `LoopStreamPage` / `LoopTopbar` 增加 `leading`（聊天页头像）。新增
    `LoopSegmentedTabPage`（`lib/widgets/loop_tab_segments.dart`）。

## Consequences

- harness（`scripts/check_harness.py`、`harness.json`、`tests/test_check_harness.py`）与 README /
  AGENTS / `docs/product-decisions.md` / `docs/product/implementation-constraints.md` 的主入口描述
  同步改为 Chat / Square / Meme / Intel / Wallet；两处评审指纹（预览 group-info 路由段、
  `chat_preview_conversation_identity_test.dart`）因有意改动重算。
- 通知「社区申请」意图仍落 `/community`（现为子页面，返回到聊天）。
- 已知未做：聊天列表的 Stream 就绪态（真实频道行）只能真机验证；广场社区行没有「加入/已加入」
  按钮（目录行不含成员关系，点行进社区资料页加入）；扫一扫没有相机实现。
