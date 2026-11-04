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

### 主代理已接受的缩写（S355 各批，2026-11-04 补录）

窄宽（360）下放不下时各批改短、主代理已接受的英文；中文取 `app_zh.arb`。

| English（已接受） | 中文 | feature / 位置 |
|---|---|---|
| Level / Rate / Active / NFT / Assets | 层级 / 比例 / 有效 / NFT 算力 / 资产算力 | miningRewards 五级邀请表头 |
| Share link | 分享邀请链接 | mining 邀请页按钮 |
| Old session | 本设备 · 旧会话 | profileSecurity |
| Devices | 设备 / 设备管理 | profileSecurity |
| Limited in your region | 部分功能在当前地区不可用 | system |
| Service unavailable | 服务暂时不可用 | system |
| Market data unavailable | 行情暂时不可用 | system |
| Trading service unavailable | 交易服务暂时不可用 | system |
| {shortName} permission is turned off in system settings | {shortName}权限已被系统关闭 | system |
| Screen lock not read yet | 还没有读到这台设备的锁屏能力 | account |
| Sign-in service unreachable this run | 这次运行没有连上登录服务 | account |
| Start room | 开语音房 | community |
| Copy pool | 复制池地址 | meme |
| View only | 仅浏览 | market |
| No data | 未报告（marketWatchlist）/ 不可读（chain） | marketWatchlist, chain |
| Edit watchlist | 自选管理 | market, coreNavigation |
| Discard | 放弃 / 放弃修改 | marketWatchlist, meme, launch2Creator |
| Resubmit | 重新提交 / 修改资料后重新提交 | launch, community |
| Dev | 创建者 | meme |
| Type or paste CA | 发消息 · 贴合约地址识别代币 | chatV2 输入框提示 |
| Following / Communities（计数） | 关注 / 社区 | socialPublicProfile |
| Mcap {cap}（市值紧凑行，独立 key） | 市值 {cap} | square `square_feedViewMarketCapCompact` |
| Tax {bps} / {bps} + dyn. tax（外盘面板税率） | 外盘税 {bps} / 外盘税 {bps} + 卖出动态税 | launch2 `launch2_poolPanelTax`、`launch2_launch2PoolViewModelTaxLabel`（英文丢了「外盘 / 卖出」，a 批标为待复核） |
| 24h vol {usd1} | 24h 成交 {usd1} | launch2 |

## 五、S355 各批新词（2026-11-04 补录）

S355a–g 与 S357 各批汇报「新词待补」的词，按批次 / feature 分节。中文一律取自 `app_zh.arb` 中英文值等于该词（或以该词为主干）的条目，不另行意译；同一英文对应多个中文时逐一列出并在括号里写 feature。决策 0283。

### 主代理裁决词

| English | 中文 | 备注 |
|---|---|---|
| BNB Chain mainnet | BSC 主网 | S357：界面英文写 BNB Chain mainnet，中文保持 BSC 主网（`wallet_swapMainnetOnly` 等） |
| Mcap | 市值紧凑行 | S355b：紧凑行写 `Mcap $1.3M`，独立 key `square_feedViewMarketCapCompact`；完整标签仍是 Market cap |

### S355b · Launch

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| My allocation | 我的份额 | launch |
| Allocation | 份额 | launch（`launch_settlementSectionLoopLabel` 等） |
| Entitlement | 权益 | launch |
| Soft cap | 软顶 | launch |
| Hard cap | 硬顶 | launch |
| Finalization | 最终化 | launch（`launch_settlementSectionNotice` 等） |
| Vesting schedule | 释放计划 | launch（`launch_chainModelsCompleted` 等） |
| Allowlist round | 名单轮 | launch |
| Public round | 公开轮 | launch |
| Allowlist root | 名单根 | launch |
| Eligibility | 参与资格 | launch |
| Staking | 质押 | launch（`launch_actionScreensLabel4` 等） |
| Ecosystem ledger | 生态账本 | launch（`launch_actionScreensLoopEconomyScreenTitle` 等） |
| Ecosystem tax | 生态税 | launch（`launch_actionScreensCell3` 等） |
| Allowance | 额度 | wallet |
| Network fee | 网络费 | miningRewards, wallet |
| Simulation | 试算 / 模拟 | common（`common_simulationPassed` 等） |
| Report again | 重新上报 | launch, meme, miningRewards |
| Directory | 目录 | launch（`launch_widgetsCatalog` 等） |
| Entity review | 主体审核 | launch（`launch_actionScreensLaunchApplyKybMessage` 等） |
| Launch track | 发射轨道 | launch |
| Bonding pool holders | 内盘持有人 | coreNavigation, launch |
| Purchase | 认购 | launch |
| Buy | 买（launch2, meme） / 买入（common, launch2） / 认购（launch） | 见中文列括号 |
| Claim | 领（launch） / 领取（common, launch） / 领奖（square） | 见中文列括号 |
| Refund | 退（launch） / 退回（launch2） / 退款（launch） | 见中文列括号 |

### S355b · Square

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| Host | 主持（chat, chatV2） / 主持人（chatV2） | 见中文列括号 |
| listening | 收听中 | chatV2 |
| Live {n}m / h / d | 开播 {inMinutes} 分钟 | square |
| Just started | 刚开播 | square |
| Global | 全球 | square |
| Apply to list | 申请入驻 | community, square |
| Rules and listing | 规则与入驻 | square |
| Power community | 算力社区 | integrations, square |

### S355b · DApp

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| DApp browser | DApp 浏览器 | coreNavigation, dapp |
| Bookmarks | 收藏 | dapp |
| Bookmark | 收藏 | dapp |
| Recent | 最近访问 | dapp |
| Same origin | 来源一致 | dapp |
| Caution | 需注意 | dapp |
| Blocked | 已屏蔽（chain） / 已拉黑（socialPublicProfile） / 已阻止（dapp, wallet） | 见中文列括号 |
| Permit signature | 签名授权（Permit） | dapp |
| Unverified contract | 未验证合约 | dapp |
| Reject | 拒绝 | dapp |

### S355a · Launch2

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| Consensus medal | 共识勋章 | launch2 |
| Medal mint | 勋章铸造 | launch2 |
| Mint | 铸造 | launch2 |
| Mint period | 铸造期 | launch2Creator |
| Priority buy | 提前购 | launch2 |
| Allowlist | 白名单 | launch |
| Snapshot allowlist | 快照名单 | launch2（`launch2_launch2NftEntry` 等） |
| Cutoff block | 截止块 | launch2 |
| Official pool | 官方池 | launch2 |
| Escrow | 托管 | launch2（`launch2_launch2InstanceLaunch2BuybackEscrowLabel` 等） |
| Base tax | 基础税 | launch2（`launch2_launch2PoolViewModelBase` 等） |
| Dynamic tax | 动态税 | launch2（`launch2_launch2DynamicPoolLaunch2DynamicFeeRows` 等） |
| Reward pool | 奖金池 | launch2 |
| Weight | 权重 | community |
| Round | 轮次 | launch |
| Buyback recipient address | 回购收币地址 | launch2Creator |
| Launch configuration | 发射配置 | launch2Creator |
| Project details | 项目详情（coreNavigation, launch） / 项目资料（launch, launch2Creator） | 见中文列括号 |
| Classic launch | 经典发射 | launch2Creator |
| v2 launch | v2 发射 | launch2, launch2Creator |
| Executor | 执行器 / 执行账户 | launch2, launch2Creator（`launch2Creator_launch2Switch17` 等） |
| Candle | K 线 | launch2（`launch2_launch2DynamicRewardsStart` 等） |
| Graduation reserve | 毕业储备 | launch2, launch2Creator |
| Per-address cap | 单地址上限 | launch2, launch2Creator |
| Launch chain | Launch 链 | launch2, socialPublicProfile, wallet |
| Bonding pool sprint | 内盘冲刺 | launch2 |
| Action | 操作 | launch2 |
| Filled | 已打满（meme） / 成交（launch2） | 见中文列括号 |
| Listed | 名单内（launch2） / 已上线（launch） | 见中文列括号 |
| Not listed | 不在名单（launch2） / 未收录（chatTokenCard） | 见中文列括号 |
| 24h vol | 24h 成交 | launch2（`launch2_launch2InstanceAside` 等） |
| Published | 发布时间（launch2） / 已发布（wallet） | 见中文列括号 |
| Legacy price protection active | 旧版合约价格保护生效 | launch2 |
| Source: chain read | 来源：链上读数 | launch2（`launch2_launch2FormatLaunch2BuybackHeldLine` 等） |
| Pay | 支付 | common |
| Get amount | 按到手金额 | launch2 |

### S355d · Wallet / Chain / Security

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| Usable | 可动用 | wallet |
| Fee reserve | 手续费保留 | wallet |
| Approval guard | 授权拦截 | coreNavigation, wallet |
| Limited approval | 限额授权 | wallet |
| Unlimited approval | 无限授权 | dapp, wallet |
| Revoke approval | 回收授权 | wallet |
| Get funds | 获取资金 | launch2, walletTestnetFaucet |
| Net value trend | 净值走势 | wallet |
| Net value snapshot | 净值快照 | wallet（`wallet_homeLabel9` 等） |
| Large-amount verification | 大额交易二次验证 | securityStepUp |
| Large-amount verification threshold | 大额交易验证金额 | securityStepUp |
| Embedded wallet | 嵌入式钱包 | wallet |
| External wallet | 外部钱包 | wallet |
| External wallets | 外部钱包 | wallet |
| Unified signing exit | 统一签名出口 | system, wallet |
| Price impact | 价格影响 | wallet |
| Verified | 已核验（chain, launch2） / 已验证（community, securityStepUp） / 验证通过。（securityAppLock） | 见中文列括号 |
| Pending check | 待校验（wallet） / 待核验（chain） | 见中文列括号 |
| Unregistered | 未登记 | chain |
| Observed | 观察于 | wallet |
| No data | 不可读（marketWatchlist） / 未报告（chain） | 见中文列括号 |
| Facts expired | 事实已过期 | wallet |
| Per-transaction limit | 单笔上限 | wallet |
| Platform fee | 平台费 | wallet |
| LOOP service fee | LOOP 服务费 | wallet |
| Confirmations | 确认数 | wallet |
| Reorg | 重组 | launch2Creator（`launch2Creator_launch2Reorged` 等） |
| Indexer | 索引器 | wallet |
| App lock | 应用锁 | account, profileSettings |

### S355g · Mining / Intel

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| Invite list | 邀请列表 | mining |
| Invite boost | 邀请加成 | mining |
| Total boost | 总加成 | mining |
| Active | 已激活（launch2） / 有效（mining） / 有效邀请（miningRewards） / 活跃（profileSecurity） | 见中文列括号 |
| Pending verification | 待验证 | securityStepUp |
| Invalid | 已失效 | mining |
| Invalidated | 已作废（mining） / 已失效（launch） | 见中文列括号 |
| Power snapshot | 算力快照 | community, mining |
| Latest power snapshot | 最近一次算力快照 | mining |
| Not updated | 未更新 | mining |
| Formula version | 公式版本 | mining |
| Pending approval | 待批准 | mining |
| Approved | 审核已通过（notifications） / 已批准（launch2Creator, mining） / 已通过（community, launch） | 见中文列括号 |
| Retired | 已退役 | mining |
| Mining rewards | 挖矿奖励 | mining |
| Claimable | 可领（launch2） / 可领取（launch, miningRewards） / 待领取（mining） | 见中文列括号 |
| Claim voucher | 领取凭证 | miningRewards（`miningRewards_screenPreparing` 等） |
| Settlement period | 结算时段 | miningRewards（`miningRewards_screenMiningMinuteEpochBody` 等） |
| Anonymous member | 匿名成员 | chatV2, mining |
| Hidden member | 未公开的成员 | mining |
| Like | 点赞 | integrations, square |
| Haha | 大笑 | integrations |
| Love | 喜欢 | integrations |
| Wow | 惊讶 | integrations |
| Sad | 难过 | integrations |
| Source | 来源 | chain, widgets |
| Observed at | 观察于 | widgets |
| Trace ID | 追踪号 | system（`system_surfacesTraceId` 等） |
| Share link | 分享邀请链接 | mining |

### S355e · Account / System / Profile

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| Guardian | 守护人 | profileSecurity（`profileSecurity_screensSocialRecoveryActionLabel` 等） |
| Guardians | 守护人 | profileSecurity |
| Automatic recovery | 自动恢复 | account, profileSecurity |
| Social recovery | 社交恢复 | coreNavigation, profileSecurity |
| Recovery methods | 恢复方式 | account |
| Transaction verification | 交易验证 | account, profileSecurity |
| Multi-factor authentication | 多因素验证 | profileSecurity |
| Device sessions | 设备会话 | profileSecurity |
| This session | 本次会话 | profileSecurity |
| Revoke session | 撤销会话 | profileSecurity |
| Ticket | 工单 | profileSupport（`profileSupport_screenLoopLabel3` 等） |
| Help and support | 帮助与客服 | coreNavigation, profileSettings, profileSupport |
| Network diagnosis | 网络诊断 | profileAbout |
| Skeleton | 骨架 | system（`system_surfacesLoopLabel8` 等） |
| Component specimen | 组件样例 | system |
| Maintenance window | 维护窗口 | system |
| Version policy | 版本策略 | system |
| Region policy | 地区策略 | system（`system_surfacesHeading3` 等） |
| Force-update floor | 强制更新下限 | system |
| Built-in wallet | 内置钱包 | integrations（`integrations_networkProbePurpose3` 等） |
| Username | 用户名 | account, profile |
| Bio | 简介 | account, profile |
| Alias | 别名 | profile（`profile_screensProfileAlias` 等） |
| Discoverable | 可被发现 | profile |
| Anonymous mode | 匿名模式 | profile |
| Share card | 分享名片 | profile, socialPublicProfile |
| Muted | 已禁言（community） / 已静音（common） | 见中文列括号 |
| Seen | 观察于 | profileSecurity（`profileSecurity_screensSecurityObservedAtText` 等） |
| Joined {date}（如 Joined Oct 2026） | 加入于 {communityObservedAtLabel}（community） / 加入于 {launchTimestampLabel}（mining） | 见中文列括号 |

### S355f · Community / Market / MEME

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| Dev | 创建者 | meme |
| Pool estimate | 池子推算 | market |
| Derived from trade price | 按成交价折算 | market |
| New pairs | 新币（market） / 新币发现（coreNavigation） | 见中文列括号 |
| New pair discovery | 新币发现 | market |
| Smart money | 聪明钱（market） / 聪明钱追踪（coreNavigation） | 见中文列括号 |
| Large trades | 大单 | market |
| Risk screening | 风险预筛 | market |
| Majors | 主流 | market |
| Community tokens | 社区代币 | market |
| Short link | 短链接 | community（`community_widgetsLabel4` 等） |
| Linked token | 绑定代币 | community |
| Ban | 封禁 | community |
| Mute | 禁言（community） / 静音（common） | 见中文列括号 |
| Make admin | 任命为 Admin | community |
| Remove admin | 撤销 Admin | community |
| Transfer ownership | 转让所有者 | community |
| Almost full | 快打满 | meme |
| New | 发起（chatFriends） / 新发（meme） / 新建（marketAlerts） | 见中文列括号 |
| Hot | 热门 | meme |
| Quick buy | 快买 | meme |
| Curve contract | 曲线合约 | launch2, meme |
| LP burned | LP 已烧毁 | meme |

### S355c · Chat / Social

| English | 中文（app_zh.arb） | feature |
|---|---|---|
| Speak | 发言 | chatCalls |
| Raise hand | 举手 | chatV2 |
| Leave stage | 下麦 | chatV2 |
| Invite to speak | 邀请上麦（chatV2） / 邀请其发言（chatV2） / 邀请发言（chatV2） | 见中文列括号 |
| Mute all | 全体静音 | chatV2 |
| Go live | 开播 | chatV2 |
| End room | 结束房间 | chatV2 |
| Speaker | 发言人（chatV2） / 扬声器（chatCalls） | 见中文列括号 |
| Listener | 听众 | chatV2 |
| Earpiece | 听筒 | chatCalls |
| Mic access | 麦克风权限 | chatCalls（`chatCalls_streamVoiceRoomMessage17` 等） |
| Forward one by one | 逐条转发 | chatV2 |
| Merged image | 合并长图 | chatV2（`chatV2_forwardScreensChatMergePreviewScreenTitle` 等） |
| Group nickname | 当前群昵称（chatGroupAlias） / 群昵称（chatGroupAlias） | 见中文列括号 |
| Member bought | 群友买入 | chatAttachments, chatMemberBuy |
| Message request | 消息请求 | chatV2（`chatV2_directMessageMessage3` 等） |
| Block | 区块（wallet） / 屏蔽（community） / 拉黑（socialPublicProfile） / 阻止（wallet） | 见中文列括号 |
| Unblock | 解除（social, socialPublicProfile） / 解除屏蔽（social） / 解除拉黑（socialPublicProfile） | 见中文列括号 |
| Friend request | 好友申请 | socialPublicProfile（`socialPublicProfile_controllerCommand` 等） |
| Add friend | 加好友 | socialPublicProfile |
| QR card | 二维码名片 | socialQr（`socialQr_cardLoopUserQrCard` 等） |
| Token detected | 自动识别到代币 | chatTokenCard |

### §二 对照表与 ARB 实际用词不一致（只列不改，待主代理定）

| §二 写法 | ARB 实际 | 涉及 |
|---|---|---|
| 讨论 = Discussions | 讨论 = Discuss | 唯一一条 zh 恰为「讨论」的条目 |
| 领奖台 = Podium | Podium = 前三名 | intel 算力榜 |
| 实时更新 = Live | Live = 实时 / 直播中 / 发射中 | 多处 |
| 大额验证 = Large-amount verification | Large-amount verification = 大额交易二次验证 | securityStepUp |
| 提交状态未知 = Submission status unknown | Submission status unknown = 提交结果未知 | 资金页 submissionUnknown |
| 外盘 = DEX pool（「外盘税」） | 外盘税 {bps} = Tax {bps}（无 DEX pool） | launch2 面板税率 |
| 算力 = Power | NFT 算力 = NFT、资产算力 = Assets | miningRewards 表头（已接受的缩写） |
