# 0248 · 清理说明文案，钱包地址独立成行

## Status

Accepted · 2026-10-26。

## Context

用户提供 MEME、授权盘点与钱包三张截图，要求清理 App 同类冗余说明，并将钱包地址与复制按钮移到余额下方。

## Decision

- 移除 MEME / 旧 Launch 的「精品发射」宣传卡。
- 授权盘点保留空态标题与真实区块、观察时间，移除额度为零的补充句与 Approval / allowance 技术解释。
- 钱包地址和复制图标在 USD 与人民币金额下方独立成行，完整地址仍由原复制回调处理；44 dp 触控区、金额隐藏及汇率过期标记保留。
- 移除钱包跨链、代币授权、网络、DApp、设置入口的解释副标题。
- 清理聊天供应商与群内搜索说明、社区推荐和入驻说明、社区 AI 重复范围说明、行情持有人/自选教程与来源中的实现解释、挖矿排行解释、旧 Launch 重复说明与私钥导出宣传文案。
- 保留操作反馈、未确认结果、功能不可用状态、交易费用/签名确认、数据质量与来源事实、开发预览标识；共用提示组件不做全局隐藏。

### 取代 S278 notes / 决策 0080 的保留结论

用户 2026-10-26 裁决：需求方不要解释性提示文案。以下删除超出上面清单或推翻 `docs/integration/S278/notes.md` 与决策 0080 的「留」，维持删除、不恢复：

- 私聊（`direct_message_screen.dart`）：页顶 `dm-protection-note` 一行「不声明端到端加密 · 私聊由 Stream Chat 承载」与阻断态 `dm-protection-note-blocked` 卡（原按决策 0080 视为隐私期待警告保留）。页面仍不作任何端到端加密承诺。
- 授权盘点（`approval_screens.dart`）：出处脚注里的覆盖范围限制「覆盖起点以下的区块只索引了转账，更早授予的授权不会出现在这里」（连同 allowance() 解释与回收网络费句）；覆盖起点区块行仍在。
- 旧 Launch 持有分布（`launch_detail_screens.dart`）：`launch-holders-notice`「空白不是『没有持有人』」卡；「持有排行」下只保留「我」一行，持有人数读不到时仍有 `LaunchUnavailableCard`。
- 行情持有人（`market_secondary_screens.dart`）：`token-holders-notice`「没有分布就不画分布」卡；读不到时仍有 `LoopUnavailableLine`。
- 自选编辑（`watchlist_editor_screen.dart`）：`watchlist-add-asset-note`「怎么添加资产」卡；无分组空态仍有添加指引。
- MEME 列表（`launch2_list.dart`）：出处细节里的「内盘进度按已售 / 8 亿计、价格以 USD1 计」等计量口径说明。
- 钱包资产（`wallet_read_screens.dart`）：出处里的「余额为 0 的资产不显示」。

## Consequences

变更限于 Flutter 展示层，未改服务端、协议、数据读取、权限或交易逻辑。GitNexus 工具与本地索引不可用，使用源码引用检查：WalletTotalHeader 仅由 WalletScreen 装配；launch2CurationNotice 仅用于 Launch2List，本次同时删除调用与常量；其他移除项均为页面内说明 Widget。

更新既有页面断言，增加地址位于金额下方、44 dp 点击区域及完整地址复制回归验证。验收结果见本次交付说明；未进行真机或 TestFlight 发布。

## Verification

S308 审查修订后最终运行（2026-10-26，`integration/v2` 基于 82fec7f1）：

- `env -u PUB_HOSTED_URL bin/flutter analyze --no-pub`：No issues found。
- `env -u PUB_HOSTED_URL bin/dart format --output=none --set-exit-if-changed lib test`：1022 个文件 0 处改动，退出码 0。
- `env -u PUB_HOSTED_URL bin/flutter test --no-pub`：6832 项通过、30 项跳过，All tests passed。
- 审查修订：`s8_launch_mining_state_pages_test.dart` 去掉指向已删 Widget 的恒真 `alsoUnreadKeys`，`mining-rank` 的 readyKey 改为读成功才渲染的 `mining-formula-row`；钱包地址行最小高度改用 `LoopTouch.minimum`；复制测试断言剪贴板为 42 位完整地址且不等于屏幕上的截断串。
- 未进行真机或 TestFlight 发布。
