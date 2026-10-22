# 0236 · 说明性文字收进 ⓘ，点开才展开（S278-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 1274db1c（S276 合入后）。主代理下单 S278-mobile。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api；不改设计 Token 值。

## Context

需求方 2026-10-22 验收反馈第 11–14 条：跨链页、安全中心、钱包资产卡和全 App 的说明性文字常驻页面，占了首屏，读者每次都要再读一遍。
要求统一改成「ⓘ 图标，点击才展开」。

主代理裁决的分级：

- 「来源 … · 观察于 …」这类出处 / 观察时间是诚实线，**不删，收进 ⓘ**：页面只留一个 ⓘ（可带两个字「来源」），点开看全文。
- 纯解释（「这是什么 / 为什么这样」）→ 收进 ⓘ。
- 警告、错误、失败态、fail-closed 的「未开放 / 没有数据」状态行、需要用户操作的提示 → 原样保留。
- 收进去后不留空洞：ⓘ 放在区块标题右侧或区块末行的尾端。

## Decision

1. **一个触发器。** `lib/widgets/loop_inline_states.dart` 新增 `LoopInfoTrigger`：13 px ⓘ + 可选两字标签（「来源」/「说明」），辅助墨色 captionSm，44 dp 触控。
   它的无障碍名是**整句**出处 / 说明（读屏用户听到的内容不变）；`expand: true` 时整行 44 dp 都接受点按（与原来整条出处行可点一致），图标靠行尾。
   `leading` 可在 ⓘ 前打印一个不能藏的短词（见第 4 条）。
2. **出处组件一处改全局。**
   - `LoopProvenanceLine`：不再打印「来源 X · 观察于 HH:mm」，只画行尾「ⓘ 来源」；点开仍是原来的「数据来源」sheet（范围 / 来源 / 观察于 / 说明），sheet 抽成公用的 `showLoopProvenanceSheet`。
   - `LoopProvenanceFooter`（chain_widgets.dart）：同样只画「ⓘ 来源」，点开 `showLoopInfoSheet` 显示 `text` 全文；新增 `label` / `title` / `notes`，解释性文字用「ⓘ 说明」并可把原来同区块的说明卡并进同一个 sheet。
   - `LoopFactLine`：数字与 stale 徽标照常显示，出处换成行尾 ⓘ。
   - 手工拼出处的两处换成同一触发器：聊天代币卡（`LoopTokenCardModel.provenance` 新字段，脚注条右侧 ⓘ；「资产目录状态 · 未登记」、过期徽标、「买入与卖出现在不可用」原样保留）、持有人分布页的 folio caption（改到 kicker 行尾 ⓘ；读不到时的原因仍印在 caption）。
3. **不是出处的灰行改用 `LoopFootnote`**（原样式的一行灰字）：「没有更多提醒」「没有更多触发记录」「未读 N 条」「这一页放不下全部…」「客服还没有回复这张工单…」——这些是列表 / 工单的状态，不收。
4. **AGENTS 规则 25 的可见标记不进 ⓘ。** `LoopProvenanceLine.marker` 在 ⓘ 前打印质量标记：K 线出处行打印「按成交价折算 / 以 WBNB 计价 / 数据可能过期 · 单位 X」（价格单位不是默认 USD，也不能藏），合约事实与概览出处行打印「含延迟或折算的数值」。来源与观察时间仍在同页一次点按可达，规则 25 的「rendered with its source and observation time」按此解释（主代理 2026-10-22 裁决）。
5. **通用的标题 ⓘ。** `lib/widgets/loop_info_sheet.dart` 新增 `LoopInfoButton`（44 dp ⓘ，打开 `showLoopInfoSheet`）与 `LoopInfoLabel`（`LoopLabel` + 行尾 ⓘ，平铺页与账本页两种对齐，照 `Launch2SectionLabel`）。
6. **第 11 条 · 跨链（`deferred_screens.dart`）。** 删掉页面上的 caption「先选来源链…」、底部「这里不会出现预估数字」卡；两段都进 folio kicker 行尾「ⓘ 说明」。默认的 `BRIDGE_RUNTIME_DEFERRED` 原因句「跨链还没有开放，这里不会发起任何跨链操作。」与标题「跨链尚未开放」重复，不再打印；服务端给出**别的**原因时才出现原因行。保留标题、禁用的从 / 到 / 开始跨链、「查看跨链进度」。
   同文件：Pay（caption + 「为什么现在不做」卡 → ⓘ；占位舞台里的未开放原因保留）、跨链进度（caption + 「可以离开此页」卡 → ⓘ；「还没有可跟踪的跨链」保留，默认原因句同理不重复）、DApp 核对（caption + 「这一页不会打开网址」折叠 → ⓘ；冒充域名危险卡、空态、连接签名未开放行保留）。
7. **第 12 条 · 安全中心（`security_screens.dart`、`step_up_widgets.dart`）。** 每行描述小字收进该行右侧 ⓘ（在状态胶囊 / 开关 / 数字之前）：未开放方法的用途（2-of-3 守护人… / 把私钥带走…）、读取中与未开启方法的用途、自动恢复的来源、「达到 N USD1 时再验一次身份」、「当前钱包上仍然生效的 ERC-20 授权」「额度没有上限的授权，风险最高」。
   「授权记录自区块 … 观察于」「观察于 …」两条出处走全局 `LoopProvenanceFooter`。页尾「这些保护由 Privy 提供…」卡移到「验证」标题右侧 ⓘ。
   保留：行标题、开关、数字、「还没有开放 / 未开启 / 已开启 / 默认方式」胶囊、服务端给的不可用原因、「读不到 · 点按重试」、大额验证的「这台设备没有锁屏」「这次有效，重开 App 后不会记得」、已开启方法读到的凭证名、「始终开启，无法关闭」、高风险会话警告、「这些保护怎么开启」折叠。
8. **第 13 条 · 钱包资产卡。** 图表下的「净值快照 · 来源 · 观察于」与「人民币按欧洲央行参考汇率…」两行删去；`showWalletTotalInfoSheet`（总资产旁已有的 ⓘ「关于总资产」）新增 `history` 参数，补「净值快照来源 / 快照观察于」两行与「走势是服务端每小时…不是可用余额」一句（汇率句本来就在）。资产列表下与 NFT 页的出处走全局 `LoopProvenanceLine`。
9. **第 14 条 · 全局走查。** 五个 Tab 首屏、钱包各子页、launch2 详情与创建流程、个人资料 / 设置逐个过 `LoopNotice`，清单与理由在 `docs/integration/S278/notes.md`。本批收进 ⓘ 的说明卡：钱包管理「绑定钱包计入算力」、授权盘点「数据出处」折叠、兑换路由「只展示最终报价」、发送确认「统一签名出口」、隐私「可见性只影响展示」、关于「开源组件」两段、普通群「与社区的区别」、全屏 K 线「这张图能做什么」、逐笔成交「不下发对手方地址」、聪明钱「胜率不是预测」、自选编辑「自选不是行情」。其余 `LoopNotice` 是警告 / 失败 / 状态 / 操作提示，保留。

## Consequences

- 页面高度：出处行原本就是 44 dp 一行，现在同高，只是文字换成行尾「ⓘ 来源」；说明卡与 caption 被移除的页面整体变矮。
- 测试：新增 `test/s278_info_icons_test.dart`（8 例 + 3 个截图例）：`LoopProvenanceFooter` 默认不渲染长文、只渲染「来源」且 ≥44 dp、读屏名为全文；点 ⓘ 后 sheet 有全文与 notes；「说明」标签；`LoopFootnote` 照印；`LoopFactLine` 出处进 sheet；跨链页无说明句、点 ⓘ 可见；安全中心描述全部不在页面、点行 ⓘ 可见；钱包首页无「观察于」、点出处行可见区块号。
  新增 `test/support/provenance_finders.dart` 的 `findProvenanceContaining`（按触发器的无障碍名查找出处），25 个既有测试文件改为断言 ⓘ 或点开后断言 sheet。
- 截图（`--dart-define=LOOP_SHOTS=true`）：`docs/integration/S278/shots/` 钱包首页、跨链页与其说明 sheet、安全中心。
- 约束：MEME 首页（`lib/features/meme/*`）与 `launch2_list.dart` 等本批禁改文件里的出处行随全局组件一起变成 ⓘ，但其中的 `LoopNotice` 未逐个处理，留给后续批次。
- 真机需确认：ⓘ 触发器在 iOS / Android 的点按区与 VoiceOver / TalkBack 朗读；安全中心行内 ⓘ 与整行点按（社交恢复 / 导出私钥 / 大额验证）不互相抢。
