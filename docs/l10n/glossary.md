<!-- 本文件是 /Users/chenyang/Documents/LOOP/docs/59-英文文案术语表-2026-11-04.md 的仓库内副本（决策 0281），供各 worktree 内的 S355 批次读取；两处同改，以 LOOP/docs 为准。 -->

# 59 · 英文文案术语表（2026-11-04，S354-mobile）

决策 0281（loop-mobile `docs/decisions/0281-english-default-locale.md`）把 App 默认语言改成英文，简体中文可切。S355a–f 填 `lib/l10n/fragments/*.json` 的 `en` 时**一律按本表**；表里没有的词，先查 `lib/l10n/fragments/common.json`（已按本表填好），再按「用法规则」自拟，并在批次汇报里列出新词给主代理补表。需求方 Figma 图层名（Intelligence、Power Ranking、Launchpad Banner…）优先采用。

原标「待拍板」的 7 项主代理已于 11-04 全部按本表裁决（见第四节）；改词只需改 fragment。

## 一、用法规则

1. **大小写：Sentence case**。标题、页签、按钮、行标题都只大写首字母：`Invite code`、`Token approvals`、`Today's P&L`。例外是专有名词与 LOOP 的命名模块（下表标「专名」的）：`LOOP`、`MEME`、`Launchpad`、`Power Ranking`、`Invite Center`、`Security Center`、`Privacy Center`、`Voice rooms` 不算专名（写 `Voice rooms`）。
2. **按钮动词开头**：`Join`、`Copy link`、`Create token`、`View all`，不写 `OK` 以外的名词按钮；确认类用具体动词（`Confirm buy` 而不是 `OK`）。
3. **空态是名词短句，不加句号**：`No conversations yet`、`No holdings yet`、`No trades yet`、`Nothing here yet`。「暂无 X」= `No X yet`（还会有）或 `No X`（本来就没有，如 `No permission`）。
4. **句号**：完整句子（说明、错误、通知正文）结尾加 `.`；标题、标签、按钮、空态、状态词不加。不用全角标点；中文的「」改成英文双引号 `"…"` 或直接去掉。省略号用 `…`（单字符），如 `Loading…`。
5. **语气**：短、平、不道歉、不解释（决策 0248 / 需求方 10-26：不加说明副标题）。用缩写：`can't`、`couldn't`、`doesn't`。错误：`Couldn't load X` / `X isn't available right now`，重试按钮 `Retry`。
6. **占位符**：保留 `{name}`，不要改名、不要拼接半句（`'{count} members'` 而不是 `count + ' members'`）。计数在 en 里用 ICU 复数：`{count, plural, =1{1 member} other{{count} members}}`（zh 不需要）。
7. **数字单位（万 / 亿）**：en 不出现 `万` `亿`，也不机械译成 `10K`。从原始数值重新格式化为 compact：≥1,000 → `K`，≥1,000,000 → `M`，≥1,000,000,000 → `B`，保留至多 1–2 位有效小数、去尾零：`12,345` → `12.3K`，`1.2万` → `12K`，`3.5亿` → `350M`。千分位用 `,`，小数点 `.`。zh 维持原「万 / 亿」规则。由 S355 在 formatter 里按 locale 分支实施（见文末清单）。
8. **日期时间**：en `MMM d, HH:mm`（`Nov 4, 14:05`），跨年加年：`MMM d, yyyy`；仍用 24 小时制（决策 0065）。相对时间：`Just now`、`5m ago`、`3h ago`、`Yesterday`、`Mon`…`Sun`；「今天」`Today`。zh 不变。
9. **金额与代币**：符号与代码照抄（`USD1`、`BNB`、`WBNB`），数字在前、单位在后：`1,234.56 USD1`；百分比无空格 `+12.3%`。
10. **称呼**：对读者用 `you`（少用）；「我的 X」做标题时写 `My X`（`My power`），做 Tab 写 `Me`。
11. **不译**：`LOOP`、`MEME`（模块 / Tab 名，正文里泛指 meme 币时写 `meme coin`）、`NFT`、`DApp`、`DEX`、`USD1`、链名（`BNB Chain`）、钱包名、`LOOP ID`。

12. **Key 与比较不用文案**（S354 试点）：`ValueKey` 用稳定 id，不用 `'x-$label'`；不要 `label == '挖矿'` 这样拿文案当数据。
13. **过渡期混排**：已迁移的文案嵌进未迁移页面的句子里会出现中英混排（「关闭『All messages』通知？」），等对应目录迁完消失；不要为它在 en 里写中文。

## 二、对照表

### 导航与五 Tab

| 中文 | English | 备注 |
|---|---|---|
| 聊天（Tab） | Chat | |
| 广场（Tab） | Square | |
| MEME（Tab） | MEME | 专名 |
| 情报（Tab） | Intel | 稿用 Intelligence 作页面 / 模块名，Tab 位短写 Intel |
| 我的（Tab） | Me | ARB：`shell_tabChat / shell_tabSquare / shell_tabIntel / shell_tabMe`；MEME 不进 ARB |
| 钱包 | Wallet | |
| 返回 | Back | |
| 设置 | Settings | |
| 语言 | Language | 选项写语言自称：English / 简体中文 |

### 社区 · 聊天 · 广场

| 中文 | English | 备注 |
|---|---|---|
| 动态 | Feed | |
| 社区 | Community / Communities | 复数按语境 |
| 精选社区 | Featured community | 稿：Featured Community |
| 发现社区 | Discover communities | |
| 语音房 | Voice rooms | 单个：Voice room |
| 会话列表 | Conversation list | 稿名，界面上一般不出现 |
| 群聊 | Group chat | |
| 私聊 | Direct message | 短形 DM 不用 |
| 陌生人请求 | Message requests | |
| 置顶 | Pinned | 动作：Pin / Unpin |
| 观点 | Opinion | |
| 讨论 | Discussions | |
| 关注 / 已关注 | Follow / Following | |
| 粉丝 | Followers | |
| 加入 / 已加入 | Join / Joined | |
| 成员 | Members | |
| 全部 | All | |
| 我加入的 | Joined | 筛选胶囊 |
| 我创建的 | Created | 筛选胶囊 |
| 成员最多 | Most members | |
| 静音 / 取消静音 | Mute / Unmute | |
| 举报 | Report | |
| 屏蔽名单 | Block list | |
| 转发 / 多选 / 合并转发 | Forward / Select / Forward as one | 主代理 11-04 裁决 |

### MEME · Launch

| 中文 | English | 备注 |
|---|---|---|
| 发射 | Launch | |
| 发射台 | Launchpad | 专名；稿：Launchpad Banner |
| 内盘 | Bonding pool | **选择**：Bonding pool / DEX pool。理由：读者是加密用户，bonding curve / DEX 是 four.meme 类产品的通用词；Inner / Outer 是直译，英文读者看不出含义。主代理 11-04 裁决采用 |
| 外盘 | DEX pool | 同上；「外盘奖励」DEX pool rewards |
| 公开内盘 | Public pool | |
| 预告 | Upcoming | |
| 已毕业 / 毕业 | Graduated / Graduate | 「毕业与迁移」Graduation and migration |
| 回购 | Buyback | |
| 市值 | Market cap | |
| 已售 | Sold | |
| 持有人 | Holders | |
| 总量 | Total supply | |
| 流动性 | Liquidity | |
| 买入 / 卖出 | Buy / Sell | 确认：Confirm buy / Confirm sell |
| 滑点上限 | Slippage limit | |
| 预计获得 / 最少获得 | Estimated to receive / Minimum received | |
| 创建代币 | Create token | |
| 实时动态条 | Realtime ticker | 稿：Realtime Ticker |

### 情报 · 算力 · 邀请

| 中文 | English | 备注 |
|---|---|---|
| 情报 | Intelligence | 页面 / 模块标题；Tab 位 Intel |
| 算力 | Power | |
| 算力榜 | Power Ranking | 专名（稿） |
| 算力社区 | Power community | |
| 全网总算力 | Network power | |
| 我的算力 | My power | |
| 名次 / 第 N 名 | Rank #N | `Rank #{rank}` |
| 领奖台 | Podium | 稿 |
| 排行榜 | Leaderboard | 稿 |
| 快照 | Snapshot | 「快照区块」Snapshot block |
| 实时更新 | Live | |
| 产生算力 | Earns power | 行内标签 |
| 行情 | Market | 稿：Market Tabs |
| 邀请中心 | Invite Center | 专名 |
| 邀请 | Invitation | 稿；按钮写 Invite |
| 邀请数据 | Invitation metrics | 稿 |
| 邀请码 | Invite code | |
| 邀请链接 | Invite link | |
| 生成海报 | Poster | 按钮：Create poster |
| 直接邀请 | Direct invites | |
| 有效成员 | Active members | |
| 二至五级 | Levels 2–5 | en dash |
| 邀请加成 | Invite boost | |
| 挖矿 / 社区挖矿 | Mining / Community mining | |

### 我的 · 钱包 · 安全

| 中文 | English | 备注 |
|---|---|---|
| 资产概览 | Asset summary | 稿：Asset Summary |
| 总资产 | Total assets | |
| 今日盈亏 | Today's P&L | |
| 快捷操作 | Quick actions | 稿 |
| 持仓 | Holdings | |
| 交易 | Trades | 分区 / 页签；动作「交易」Trade |
| 接收 | Receive | |
| 发送 | Send | |
| 兑换 | Swap | |
| 扫码 / 扫一扫 | Scan | |
| 跨链 | Bridge | |
| 代币授权 / 授权盘点 | Token approvals | |
| 网络 | Network | |
| 管理 / 钱包管理 | Manage / Wallet management | |
| 内测反馈 / 意见反馈 | Beta feedback / Feedback | |
| 大额验证 | Large-amount verification | |
| 二次验证 | Two-step verification | |
| 应用锁 | App lock | |
| 减少动效 | Reduce motion | |
| 助记词 | Recovery phrase | |
| 私钥 / 导出私钥 | Private key / Export private key | |
| 安全中心 / 隐私中心 | Security Center / Privacy Center | 专名 |
| 签名 / 待签名 | Sign / Awaiting signature | |
| 已广播 / 已确认 / 已回滚 | Broadcast / Confirmed / Reverted | |
| 提交状态未知 | Submission status unknown | |
| 演示数据 / 开发预览 | Demo data / Development preview | |

### 通用

| 中文 | English |
|---|---|
| 确认 / 取消 | Confirm / Cancel |
| 确定 | OK |
| 复制 / 已复制 | Copy / Copied |
| 已复制链接 | Link copied |
| 重试 | Retry |
| 加载中… / 读取中 | Loading… / Loading |
| 关闭 | Close |
| 保存 / 删除 / 编辑 | Save / Delete / Edit |
| 分享 | Share |
| 更多 | More |
| 刚刚 / 今天 / 昨天 | Just now / Today / Yesterday |
| 不可用 / 暂不可用 | Unavailable / Not available right now |
| 当前账号没有权限 | This account doesn't have permission |
| 这里还没有内容 | Nothing here yet |
| 已开启 / 已关闭（开关） | On / Off |
| 已关闭（会话 / 活动） | Closed |

## 三、日期 / 数字 formatter 清单（S355 按第一节 7、8 实施）

`grep DateFormat( / NumberFormat(`：全仓 **0 处**（LOOP 不用 intl 的 formatter，全部手写）。手写中文单位的 formatter（2026-11-04 基线，行号供定位）：

| 位置 | 现状 | en 规则 |
|---|---|---|
| `lib/features/chain/chain_widgets.dart:216` `loopRelativeTime` | `N 秒前 / 分钟前 / 小时前 / 天前` | `Ns ago` / `Nm ago` / `Nh ago` / `Nd ago`（不足 1 分钟可写 `Just now`） |
| `lib/widgets/loop_loading.dart:11–14` | 同上（另一份相对时间） | 同上；建议 S355 合并成一个 |
| `lib/features/launch2/launch2_launchpad.dart:46` | `N 分钟前` | `Nm ago` |
| `lib/features/square/square_feed_view.dart:812` | `M 月 D 日` | `MMM d` |
| `lib/features/wallet/wallet_read_widgets.dart:382–383` | `M月D日` / `YYYY年M月D日` | `MMM d` / `MMM d, yyyy` |
| `lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:67` | `M月D日 HH:mm` | `MMM d, HH:mm` |
| `lib/features/chat/member_buy/member_buy_event.dart:238–240` | `x万` / `x亿` | compact `K / M / B` |
| `lib/features/launch2/creator/launch2_creator_widgets.dart:34–37` | `x 亿` / `x 万`（发行量） | compact `K / M / B` |
| `lib/features/market/loop_market_chart.dart:212`、`lib/features/meme/meme_models.dart:572` | K 线周期 `1日` | `1D`（其余周期 `15m` `1h` `4h` 已是拉丁） |
| `lib/features/community/community_widgets.dart:478` | `预估/日` | `Est./day` |
| `lib/integrations/communication/stream_chat_localizations_zh.dart` | Stream 中文表的周一…周日、今天 / 昨天 | en 走 SDK 英文，不用改 |

月份缩写用英文三字母（Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec），不依赖 intl 的 locale 数据也能手写；若 S355 决定用 `intl` 的 `DateFormat`，它已是直接依赖（0.20.3），但要先 `initializeDateFormatting` 或只用 `en` / `zh` 内置符号。

## 四、主代理裁决（2026-11-04）

以下 7 项全部按本表写法执行，不再待定；需求方若改口再改 fragment。情报：Tab 写 Intel、页面 / 模块标题写 Intelligence（与 Figma 图层名一致）。专名清单就是这五个加 LOOP / MEME。

1. 内盘 / 外盘：本表选 **Bonding pool / DEX pool**（备选 Inner / Outer pool、Bonding curve / DEX）。
2. 大小写：本表定 **Sentence case**，专名清单（Launchpad、Power Ranking、Invite Center、Security Center、Privacy Center）是否就这些。
3. 情报：Tab 写 **Intel**、页面标题写 **Intelligence**（稿名），还是两处都 Intel。
4. 「交易」作分区 / 页签写 **Trades**，作动作写 **Trade**；通知设置的分组目前是 common_trade = Trade。
5. 合并转发：Forward as one（备选 Merge and forward）。
6. 数字：en 用 K / M / B compact；「万」不保留成 10K 的写法。
7. 语言选项写自称（English / 简体中文），不随界面语言翻译。
