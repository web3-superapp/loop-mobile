# 0114 · 群友买入卡片；长按「转发 / 多选」、会话内多选与合并转发入口迁移（S108-mobile）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S108-S110-social-batch2b.md` §2），S108-mobile 实施。
基线 `integration/v2` e1007fd。对接后端 S108-api（loop-api 决策 0097，消息形状见设计 §1.2）。
不新增依赖、`pubspec.lock` 不变、路由清单不变（`/chat/forward` 保留，99 条）、`lib/app.dart` 不变。

## Context

1. 需求方 v3（`LOOP/docs/09` §6.1 第 3/4 条、§6.2 第 3/4 节）：社区群聊里要看到「群友买入」动态（本社区
   绑定代币，群成员买入即插入聊天流）；消息要能长按转发、多选后逐条或合并转发，私聊也要能转发。
2. 盘点（2026-10-08 只读报告）：长按菜单是 Stream 10.3.0 默认清单，LOOP 只在
   `loopApplyChannelMessagePolicy` 里按 0105 · 3 去掉置顶；转发只能从顶栏 shuffle 进 `/chat/forward`
   （读源会话 50 条再勾选），合并转发只是该页的「预览合并长图」；私聊没有入口；没有会话内多选。
3. 后端 S108-api 以 Stream 用户 `loop_feed_bot` 发 `type: regular` 消息，`text` = `群友买入 · {SYMBOL}`，
   事实全在自定义字段（Stream Flutter 客户端里即 `message.extraData`）：`loop_schema: "member_buy.v1"`、
   `publicProfileId`、`symbol`、`decimals`、`amountRaw`、`quoteAmountRaw`、`quoteIsStable`、`txHash` 等。

## Decision

### 1. 群友买入卡片 `LoopMemberBuyCard`

- 分流点：`loopStreamGroupMessageItemBuilder`（`app.dart` 已注册的 `messageItem`）。判定
  `loopIsMemberBuyMessage` = `extraData['loop_schema'] == 'member_buy.v1'` **且** 发送者
  `user.id == 'loop_feed_bot'` **且** `user.extraData['loop_bot'] == true`，未删除 → 卡片；同一 bot 的其他
  消息照常按文本气泡渲染。任何成员都能在自己的消息上写自定义字段，所以非 bot 发的带 tag 消息就是普通消息：
  气泡原样显示正文（不剥 tag），预览也是它自己的正文。卡片解析（`tryParse`）、会话列表预览、多选可勾选
  判定都走同一判定；群聊列表行对 bot 消息直接用原消息预览（成员投影会把发送者换成显示用户、丢掉
  `loop_bot`）。
- 校验（`LoopMemberBuyEvent.tryParse`）：`publicProfileId` UUID、`symbol` 见下条、
  `decimals` 0–36、`amountRaw` 非零十进制整数串（或非负 int）、`quoteAmountRaw` 十进制整数串、
  `quoteIsStable` bool、`txHash` `0x` + 64 hex。任一不满足 → 「群友买入 · 动态数据不完整」小卡，不画 0、
  不画回退文本。`blockTimestamp` 可选（ISO 串或秒），缺省用消息的 `created_at`。
- 代币符号（`loopMemberBuySymbolIsValid`，预览 formatter 内逐字重述、测试按同一组样本逐个比对两处结果
  与全部字段名常量）：`^[\p{L}\p{N}\p{M}$._-]+$`（`unicode: true`，任意文字的字母 / 数字及其组合附标），
  组合附标不得开头，按字素（基字符 + 其后附标）计数 ≤ 20；空白、控制字符、bidi 覆盖 / 隔离符、零宽连接符、
  emoji 一律拒绝。中文符号（`狗狗币`）可用。
- 金额：`amountRaw / 10^decimals` 用 `Decimal` 精确换算；先按将显示的精度（两位小数）舍入再选档位：
  < 1 万两位小数并分组，否则 `x.xx万`，万档舍入后满 1 万再进 `x.xx亿`（`9,999.995` → `1万`，
  `99,999,999.5` → `1亿`）；< 1 最多六位小数，正数舍入为 0 时显示 `<0.000001`。副行：稳定币 `≈ $x`，否则
  `x WBNB`；报价为 0 时不画副行。
- 买家：资料接口 `GET /v2/profiles/{id}`（经 `publicProfileGatewayProvider` 端口）**总是**要问，它决定能不能
  显示这个人：`404 PROFILE_NOT_FOUND`（无此人或对方拉黑了读者，故意不可区分）→「群友」+「群」首字头像，
  不论 Stream 知道什么。Stream 只提供名字与头像：已加载的 Stream 状态（频道成员，再 `client.state.users`）
  里 `publicProfileId` 相同、带真名的用户（决策 0112 的 `loopStreamRealIdentityOf`），查找按
  `publicProfileId` → Stream 用户 id 在每个 client 上记忆化（未命中按已知用户数记忆，见到新用户才重扫）。
  资料找到 → Stream 名字 / 图片优先，缺则资料的别名 / `avatarRef`；资料未答或传输失败 → 有 Stream 身份
  就用，没有就「群友」。缓存 `LoopMemberBuyProfileCache`（每账号一个）只保存服务端真正给出的答复（资料或
  404）；离线、`503`、解码失败不缓存，下一张挂载的卡片重问；同一买家的并发请求合并为一次。点头像 → `LoopChatAvatarTapScope`（app 已装）→ `user-profile`。
- 交易哈希 `0x1234…abcd`（前 6 后 4）+ 复制图标，整块 ≥ 44 pt，点按复制全哈希并 toast「已复制交易哈希」。
- 会话列表预览：`LoopStreamTokenCardMessagePreviewFormatter`（app 唯一注册的 formatter）先判 member-buy，
  输出 `群友买入 · SYMBOL`（无发送者前缀；无合法 symbol 时只 `群友买入`）。

### 2. 长按菜单

- `loopApplyChannelMessagePolicy` 现在对每条消息都安装 `actionsBuilder`：去掉 `MuteUser`/`UnmuteUser`、
  `BlockUser`/`UnblockUser`；置顶规则不变（0105 · 3）；回复、复制、编辑、删除、标为未读、回复话题保持
  Stream 原样。**「举报消息」（`FlagMessage`）保留**（主代理 2026-10-08 裁决），待 LOOP 自有举报端点上线后
  再评估；用户级静音没有 LOOP 替代，拉黑在资料页。
- 追加两项（`loopMessageForwardActions`）：「转发」只给已发送、非删除、有正文且没有用户附件
  （Stream 抓取的链接预览不算）的消息；「多选」只在页面装了选择宿主时出现。删除 / 发送失败 / 发送中消息
  不追加任何项。

### 3. `ForwardTargetSheet`

- `showChatForwardTargetSheet`：底部弹层列最近 30 个已加入会话（与 `chat-forward` 同一查询
  `queryChatForwardTargets`，排除源会话），五态：加载骨架 / 错误 + 重试 / 离线 + 重试 / 空 / 列表。
  点一行即发送（无二次确认），每条带 `loop_forwarded_from: { cid, messageId }`，完成后关闭并 toast
  「已转发」（多条为「已转发 N 条」，有跳过 / 失败时追加「跳过 M 条」，勾选后已被删除或不在本机的追加
  「K 条已删除或不在本机，未转发」）。发送期间弹层 `PopScope(canPop: false)`（系统返回与点遮罩都关不掉），
  弹层不开拖拽关闭（拖拽会绕过 PopScope 直接关路由；`showLoopSheet` 为此新增可选 `enableDrag`，默认仍随
  `isDismissible`）。
- 发送与目标读取经新端口 `ChatForwardPort`（`chatForwardPortProvider`，生产实现 = Stream 会话），测试可替换。

### 4. 会话内多选

- 宿主 `LoopMessageSelectionHost`（`community-chat`、`group`、`dm` 三页包住整页）+ `InheritedNotifier`。
  进入：长按「多选」，被长按的消息预选。系统返回先退出多选。
- 控制器只存消息 id。逐条转发 / 合并转发 / 删除执行时从 `channel.state.messages` 重取（删除在确认后再取），
  取不到或已删除的计入跳过，并在 toast 里说明（合并：「K 条已删除或不在本机，没有放进长图」；删除：
  「K 条已不在本机，跳过」）；底栏按钮可用性也按重取结果计算。
- 顶栏 `LoopSelectionAwareTopbar`：多选时换成「已选 N 条」+ 副标题「最多 20 条」+ 关闭图标（无障碍名
  「取消」）。
- 每行前 44 pt 勾选列；多选时行内手势（长按、链接、头像）全部暂停，整行点按即勾选；不可选的行（已删除、
  失败、群友买入卡片）留同宽空列不画框。超过 20 条 toast「一次最多选择 20 条」。
- 底部固定栏（替换输入框，输入框控制器保留草稿）：「逐条转发」（有可转发消息时可用 → 同一弹层，按时间
  正序逐条发送，成功后退出多选）、「合并转发」（主按钮，同条件 → 把所选消息按时间正序写入
  `chatForwardControllerProvider.seedSelection` 后 push `/chat/merge-preview`，发送者按 0112 真实身份
  规则）、「删除」（仅全部是自己的消息且频道允许删自己的消息 → 确认弹层 → 逐条软删 → toast）。
- 顶栏 shuffle 按钮从 `community-chat` 与 `group` 移除；`/chat/forward` 路由和页面保留（深链仍可达），
  被多选数据写过的状态带 `seededFromSelection`，再进 `/chat/forward` 会重新读源会话。

## 与契约的偏离

| # | 项 | 设计 §1.2 / §2 | 本批实现 | 原因 / 后续 |
| --- | --- | --- | --- | --- |
| 1 | 报价精度 | `custom` 只有 `quoteAmountRaw`，无报价代币精度 | 默认 18 位（BSC 上 WBNB / USDT / USDC / USD1 全为 18）；若 payload 带 `quoteDecimals` 则用之 | **建议后端在 `custom` 补 `quoteDecimals`**（及非稳定币时的 `quoteSymbol`），客户端已按这两个字段名读取，无需再改 |
| 2 | 非稳定币报价名 | `{quoteAmount} WBNB` | 读可选 `quoteSymbol`，缺省 `WBNB` | 同上 |
| 3 | 卡片时间 | 「时间」 | `blockTimestamp`（ISO 或秒）→ 本地 `HH:mm`，缺省用消息 `created_at` | 设计未定 `blockTimestamp` 编码；两种都收 |
| 4 | 预览 formatter 位置 | `app.dart` 的 `messagePreviewFormatter` 换实现 | 分支加在已注册的 `LoopStreamTokenCardMessagePreviewFormatter` 内，schema 常量在该文件重述并有测试对齐 | 该类是 `final`，harness 钉死 `app.dart` 里的注册片段与该文件的 import 白名单；不动 `app.dart` 也避开与 S109b 的冲突 |
| 5 | 顶栏「取消」 | 文字「取消」 | 关闭图标，无障碍名「取消」 | 决策 0087：顶栏只放图标（harness 检查） |
| 6 | 群友买入卡片可否转发 / 多选 | 未规定 | 卡片不进长按菜单、多选里不可勾选 | 卡片是 LOOP 自有行而非成员消息；转发后的纯文本「群友买入 · PEPE」脱离卡片无意义 |
| 7 | 转发确认 | 「选一个 → 发送」 | 无二次确认，点即发 | 与设计一致；旧 `/chat/forward` 页仍保留确认弹层 |
| 8 | 可转发判定 | 「图片与已删除消息不出现此项」 | 有用户附件（图片 / 文件，链接预览除外）的消息都不出现「转发」；`chat-forward` 页同规则（此前带图带字的消息可只转文字） | 只转文字会把图文消息拆坏；统一一处判定 `chatForwardMessageIsForwardable` |
| 9 | 删除 | 「仅全是自己的消息时可用」 | 另需频道 `delete-own-message`（或 `delete-any-message`）能力 | Stream 没给能力时删除必然被拒，不给假可用 |
| 10 | 举报 | 设计 §2.2 去掉 Flag | 保留「举报消息」 | 主代理 2026-10-08 裁决：LOOP 尚无自有举报端点，先保留 Stream 的；待自有端点上线再评估 |
| 11 | 卡片判定 | 只看 `loop_schema` | 另要求发送者是 `loop_feed_bot` 且 `loop_bot: true` | 主代理审查：成员可在自己消息上伪造自定义字段 |

## Consequences

- 新文件：`lib/features/chat/member_buy/member_buy_event.dart`、`loop_member_buy_card.dart`、
  `lib/features/chat/v2/forward_target_sheet.dart`、`loop_message_selection.dart`；`lib/widgets/loop_sheet.dart`
  加可选 `enableDrag`。测试 `test/s108_member_buy_forward_test.dart`（卡片完整 / 缺字段 / 解析失败、WBNB 副行、
  金额格式与档位舍入、预览 formatter、房间内卡片替换气泡；bot 门控：成员伪造 tag 出普通气泡、预览不出
  「群友买入」；符号规则两处同样本逐个比对与常量对齐、中文符号；买家解析：404 压过 Stream、Stream 供名字、
  404 缓存而传输失败重问；长按两项且保留举报、无屏蔽，自己消息保留删除；转发弹层发送一次、发送中关不掉；
  多选顶栏与底栏切换、系统返回先退出多选、草稿保留、三按钮可用性、合并转发以所选消息进入且时间正序、
  逐条转发、勾选后被删除的计入跳过并提示、上限 20、不可勾选判定；私聊长按转发与多选、`dm` 页挂选择宿主）。
- `test/communication_pages_test.dart` 社区群顶栏工具从四个改为三个，断言转发按钮不存在。
- `CommunityChatScreen.onOpenForward` / `GroupChatScreen.onOpenForward` 不再绘制，参数保留（`app.dart` 由
  S109b 持有，不在本单改动范围）；可在下一次碰 `app.dart` 时一并删掉。
- 未验证：真实 bot 消息（需 S108-api 部署后在 dev 社区触发）、真机长按手感与多选滚动、真机系统返回退出
  多选、真实 Stream 软删回显。
