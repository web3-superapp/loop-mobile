# 0121 · 修正与文案：搜索三域、反应图标、开发环境提示清零（S121a）

## Status

Accepted 2026-10-09。主代理设计（`LOOP/docs/modules/S121-visual-second-pass.md` §0、§1、§1.1、§3、§5），
S121a-mobile 实施。基线 `integration/v2` c5de8aa。不新增依赖、`pubspec.lock` 不变、路由清单不变。
视觉部分（`LoopEmptyState`、插图、发射台卡片、领奖台、聊天列表 Logo）是 S121b / 决策 0122。

## Context

用户 2026-10-09 真机反馈（`LOOP/docs/evidence/2026-10-09-device-feedback/`，截图 7、8、9、11）：

1. 搜索里 Launch / DApp 两个 chips 只会答「域暂不可用」，「不能搜就别放」；底部「搜索范围」说明卡占版面。
2. 长按消息出现「赞 哈 心 哇 叹」五个汉字（决策 0117 当时图标集没有反应图标），选中后的反应贴在气泡右上角。
3. 「含演示持仓 · 仅开发环境」、「交易验证还开不了…LOOP 不会保存 PIN，也不会把『能开』说成『已经开了』」、
   「DApp 目录还没有接入，这一域搜不到东西」等面向工程的实话外露。
4. MEME 交易面板 25 / 50 / 75 / 100% 把 18 位小数原样塞进输入框。
5. 代币页图表空态「成交还太少，画不出走势 / 只画有成交的时段，空时段不会补 0」两行字。

## Decision

### 1. 搜索

- `LoopFeatureSwitches.searchOutboundDomainsVisible = false`（`LoopFeatureSwitchValues` 同名字段，测试可覆盖）。
  页面只画 `visibleSearchDomains(outboundVisible:)`：关时为 `searchableDomains`（资产 / 社区 / 用户），开时为原五域。
  `SearchDomain` 枚举、`searchDomainOrder`、延迟域探测与原因文案全部保留，改 `true` 即恢复。
- 删 `search-scope-notice` 卡片；输入框下一行 11px（`LoopType.captionSm`）
  `searchScopeHint` =「按昵称只能搜到允许被发现的账号，LOOP ID 可以精确搜索」（key `search-scope-hint`）。
- 延迟域（开关打开时才可达）的标题由「"X" 域暂不可用」改为「X 暂时搜不到」；DApp 原因改为「DApp 目录暂未开放。」。

### 2. 反应

- 新增五个线稿图标 `assets/icons/i-react-like / i-react-laugh / i-react-heart / i-react-wow / i-react-sad.svg`
  （24 viewBox、`fill="none"`、`stroke="currentColor"`、1.7、圆头圆角，同 `i-bell.svg`），登记进
  `LoopIconNames.all`（65 → 70）。`loopReactionIconNames` 把 Stream 类型 `like / haha / love / wow / sad`
  映射到这五个图标；`loopReactionLabels` 改为无障碍名「点赞 / 大笑 / 喜欢 / 惊讶 / 难过」。
- 长按反应条 `LoopStreamReactionBar`：五个 28px `LoopIcon`，48px 触控，本人已选的那个 Lime、其余 Chalk；
  不再用 `StreamEmojiButton`，条内不画任何字符；仍无「+」。
- 消息上的反应：`lib/app.dart` 装 `reactions: loopStreamReactionsBuilder`。`LoopStreamReactions` 用 Stream 自己的
  `StreamIntrinsicColumn` 把气泡和一行胶囊上下排，胶囊从气泡的起始边（左边）开始，收到的和自己的消息一致，
  群聊私聊一致。胶囊 = 16px 图标 + 数量（数量为 1 也显示），高 24、`elevated` 底、`line` 描边、999 圆角。
  胶囊是标签不是按钮：LOOP 的消息项本来就关着 Stream 的反应详情弹层（决策 0117），24px 也不是触控目标。
- `LoopStreamReactionIconResolver.resolve` 仍返回 `StreamUnicodeEmoji(loopReactionLabel(type))`（只到达 LOOP 没替换的
  Stream 表面，印的是词）；`supportedReactions` 为空、`emojiCode` 为 `null` 不变；`check_no_emoji` 规则不变。
- 预览夹具 `ChatMessageTile` 的反应胶囊同样改为图标 + 数量。

### 3. 开发环境提示清零

- 删 `MiningDemoHoldingsNotice` 横幅。新 `miningProvenanceDetail(MiningSnapshotRef?)` 在快照含演示持仓时返回
  `miningDemoHoldingsDetail`「这次算力里含演示持仓：它们不在链上，没有人真的持有，数字只用来体验。」，否则 `null`；
  挖矿首页 / 资产 / 排行 / 社区四处原横幅位置改为 `MiningSnapshotProvenanceLine`（11px 来源行「来源 LOOP 算力快照 ·
  观察于 hh:mm」+ ⓘ，弹层详情即上句）。情报算力榜（`intel_rank_board.dart`）只删了横幅一行，ⓘ 详情接入留给 S121b。
- 安全设置（`security-setup`，`lib/features/account/account_screens.dart`）：删「交易验证还开不了」横幅
  （`protection-setup-unavailable`）；「大额交易二次验证」副标 `securityLargeAmountSubtitle`「超过阈值时再验一次身份 ·
  即将推出」，无右侧状态、不可点；底部说明卡改一行 11px `securityBiometricFallbackLine`「设备不支持生物识别时，会改用
  系统锁屏密码验证。」（key `security-biometric-fallback`）。页面仍不保存 PIN、不提供开关、不把能力说成已开启。
- 全库逐条改写：`Passkey 还开不了` → `Passkey 暂不可用`；`暂时读不到链上数据，请稍后再试。`；`社区服务暂时不可用，请稍后再试。`；
  `这项功能暂时不可用，请稍后再试。`；`按资产拆分的挖矿数字暂未开放…`；`公告和官方动态暂未开放…`；`AI 助理暂未开放。`；
  语音房「语音没连上，你仍在房间里；要退出请点下面的「离开」。」；建群副标去掉「LOOP 不会把钱包地址…」。
- harness `check_user_visible_copy` 新增禁词 `仅开发环境|还没有接入|还开不了`。

### 4. MEME 交易面板

- `memeFillText(raw)`：按两位小数截断（不进位，避免超过余额），代币与 USD1 同为两位。
- 面板记住快捷键选中的精确 `BigInt`（`_filledRaw`）和它印出的文本；输入框文本未被改动时，报价与请求都用精确值
  （100% 卖出就是全部持仓），用户一改就按输入走。输入框显式 `maxLines: 1`。

### 5. 代币页图表空态

- MEME 代币页少于两根 K 线时只一句 `memeChartEmptyMessage`「还没有成交」，key `meme-chart-empty`
  （原 `meme-candles-empty`）；组件仍是 `LoopEmpty`，S121b 换 `LoopEmptyState` + `chart-empty` 插图。

### 6. OKX 实拍规律（设计 §1.1.1，主代理 2026-10-09 追加）

- 搜索域 chips 改为二级胶囊 `LoopSubChip`（`search_screen.dart`）：32 高、44 触控，未选描边 `line`、选中实心
  `card2` 深灰 + Chalk 字，不再用 Lime 实心 `LoopSeg`。key 不变（`search-seg-*`）。
- 反应胶囊：图标 16 + 数量 12（`LoopType.caption`），`elevated` 深灰底、无描边；本人的反应 Lime 描边 + Lime 图标。
  Stream 的 `StreamReactionsProps` 不带消息，所以 `LoopStreamMessageRow` 在每个 LOOP 消息项外放一层
  `LoopOwnReactionScope`（本人反应类型集合），胶囊从这里读。
- 安全设置：两组改为 `_SecurityCard`（`card` 面、圆角 16、无描边无阴影、行间 1px 内缩分隔线），行 `_SecurityRow`
  是 `LoopRecordRow` 的子类（字段与 key 不变，测试照旧按 `LoopRecordRow` 读），右侧状态词 14 灰字 + 箭头（可点时）。
  共享 `LoopRecordRow` / `LoopRecordGroup` 未改。
- 交易面板 25 / 50 / 75 / 100% 改为一行四个描边小胶囊 `_FillChip`（32 高、44 触控、12 tabular、不留选中态）。

### 7. 主代理裁定（2026-10-09 追加）

- **挖矿公式基线**：`miningBaselineLabel` 由「开发基线」改为「当前算力公式」，所有引用处（挖矿各页、社区 / 钱包 /
  行情挖矿钩子）随之变化；挖矿首页英雄区与「不做本地估算」卡不再有基线专用句；公式行副标「当前算力公式」、右侧
  「已生效」；规则页的基线横幅改为来源行（`mining-rules-baseline-notice`）。基线含义 `miningBaselineDetail`
  进来源行 ⓘ：`miningProvenanceDetail(snapshot, formula:)` 与 `MiningSnapshotProvenanceLine(formula:)`；没有快照
  但公式是基线时，来源行写「当前算力公式 · 来源 LOOP 挖矿规则」。「开发基线」「开发验证」加入禁词。
- **反应胶囊可点**：点自己的反应撤回、点别人的反应以本人身份加同一反应（`loopToggleReaction`，与 Stream 自己的
  `_selectReaction` 同语义，遵守 `enforceUniqueReactions` 与 `send-reaction` 能力）。私聊行拿到的是显示副本，所以
  按 id 从 `channel.state.messages` 取频道自己的那条再写，避免把显示副本写回状态。胶囊触控 44、视觉 24 不变：
  列间距 -6、换行间距 -14 把多出的 10 收回，胶囊仍在气泡下 4。Stream 的详情弹层仍关着。

## 偏离表

| 设计 | 实际 | 原因 |
| --- | --- | --- |
| §2 安全设置页在 `lib/features/security/**` | 页面实际在 `lib/features/account/account_screens.dart` 的 `SecuritySetupScreen`；`lib/features/security/mfa/*` 只改了「Passkey 还开不了」 | 文件位置事实 |
| §3.5 图表空态在 `lib/features/market/token_screen.dart` | 「成交还太少，画不出走势」在 `lib/features/meme/meme_token_screen.dart`；`token_screen.dart` 的「这个区间没有成交 / 空桶不会补 0」未动（`s8_five_state_pages_test` 锁定，且不在本单文案清单） | 文件位置事实 |
| 「内容并入该页 LoopProvenanceLine 的 ⓘ 详情」 | 挖矿四页原本没有来源行，新增 `MiningSnapshotProvenanceLine`（来源 + 观察时间 + ⓘ）放在原横幅位置 | 无处可并 |
| §2 文件边界不含 `intel_rank_board.dart` | 删除了其中 `MiningDemoHoldingsNotice(...)` 一行（组件已删，不删编译不过）；ⓘ 详情接入留 S121b | 编译 |
| 「大额交易二次验证 · 不可用」 | 副标「超过阈值时再验一次身份 · 即将推出」，右侧不再写「不可用」，A11 的「不可用」计数 3 → 2 | 按设计原文；harness 证据同步 |
| 安全页卡片「去描边」只作用于本页 | 用私有 `_SecurityCard` / `_SecurityRow`，共享行组件不动 | `lib/widgets` 属 S121b 边界；全站行样式要统一时由 S121b / 主代理决定 |
| 胶囊 44 触控区 | 触控区向上与气泡底边重叠 6px（仅胶囊宽度内） | 不加大气泡下方留白 |

## Consequences

- 搜索恢复两域只需改开关；`community_social_pages_test` 的两个延迟域测试改为显式打开开关运行。
- 新反应图标让 `LoopIconNames` 变为 70 个；S121b 若再加图标需要合并计数。
- S121b 接口：`miningProvenanceDetail(snapshot)`（`lib/features/mining/mining_widgets.dart`）、
  `miningDemoHoldingsDetail`、`MiningSnapshotProvenanceLine`；图标名 `react-like / react-laugh / react-heart /
  react-wow / react-sad`；图表空态 key `meme-chart-empty`、文案常量 `memeChartEmptyMessage`。

## Evidence

- `test/s121a_copy_search_security_test.dart`：搜索三 chips、11px 提示行位置、开关恢复五域；安全页无禁词、
  大额行副标、11px 回退行、无横幅。
- `test/s112_reaction_picker_test.dart`：反应条五图标无字符、本人反应 Lime、28px；收到 / 自己的气泡胶囊在气泡下方
  左起；`lib/app.dart` 安装两个 builder。
- `test/s117_meme_launchpad_test.dart`：`memeFillText` 截断、25% 显示 `250.00`、100% 卖出显示 `3.14` 而报价带全部
  18 位、改输入后按输入；图表一根 K 线只一句「还没有成交」。
- `test/s60_discover_sorts_test.dart`：演示持仓只在来源行 ⓘ 弹层里出现。
- `scripts/check_harness.py`：禁词、反应图标映射与 SVG 画法、`reactions: loopStreamReactionsBuilder,`。
