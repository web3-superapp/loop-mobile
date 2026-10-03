# LOOP 社交开发接手说明

更新日期：2026-10-03。范围：社交客户端、后端接口衔接和验收；合约需求仍见 [合约交接](2026-10-03-contract-handoff.md)。本文记录代码状态，不代表生产已部署或真机验收完成。

## 1. 从哪个版本开始看

- 移动端：`web3-superapp/loop-mobile`，当前工作分支 `codex/loop-v2-ui-edits-20261002`；已接受的视觉基线为 `6639279`。本轮增量仍在工作区，交接时需连同新增文件一起审查，不能仅检出该基线当成最终代码。
- 后端：[`web3-superapp/loop-api` 的 `integration/v2`](https://github.com/web3-superapp/loop-api/tree/integration/v2)。本次逐项核对固定在 [`83f5ac7a9de654d28a0628f38a79db44a0c6221b`](https://github.com/web3-superapp/loop-api/tree/83f5ac7a9de654d28a0628f38a79db44a0c6221b)，提交日期 2026-09-30；提交记录包含 muxiaodeng、CWD1208、Doog-bot534 等多人。
- 先前对旧 `main` 的判断不能作为当前能力清单。本次没有修改、推送或部署 API 仓库。分支后续可能前进，接手时先比较上述固定提交，再更新本文证据。

## 2. 能力与状态

| 能力 | 当前实现 | 后续注意事项 |
|---|---|---|
| 好友申请、接受/拒绝、好友目录、私聊 | 已有客户端与真实后端逻辑，继续复用 | 接受关系与创建/挂载 Stream 会话是不同步骤；仍需双账号联调 |
| 关注、取消关注、拉黑/解除拉黑 | 已有真实接口；公开资料面板新增拉黑确认和失败处理 | 不把 follow 或 block 当作解除 friendship |
| 私聊点头像看资料 | 使用服务端 direct-channel 目录或目标资源返回的公开 peer | 不从消息用户名或 Stream ID 生成公开身份；无映射时保持不可操作 |
| 群消息点头像看公开资料 | 尚缺后端授权映射 | 群内 Alias/Persona 和公开 Profile 是不同身份层，见 S-02 |
| 添加菜单 | 创建社区、创建群组、添加好友、扫一扫、我的二维码入口 | 创建/加入沿用原资格、权限和请求流程 |
| 用户/社区二维码、二维码 PNG 分享 | 客户端本地编码与分享逻辑已有 | 相机解码、系统相机唤起与原生外链验收未完成；粘贴识别不等于相机扫码 |
| 长按、转发、多选、合并海报 | 保留 Stream 官方复制/回复/删除权限；文本消息新增转发/多选入口，合并操作移至底栏 | 重读精确 CID 与成员资格；成功状态依据真实 SDK/导出结果 |
| 海报附带社区二维码 | 从当前社区资源传入上下文，要求 CID 匹配；可取消附带 | 私聊不附社区码；保留原匿名导出投影，不泄露私聊 CID 或钱包信息 |
| 删除好友、公开资产/交易、群友买入提示 | 当前未完成 | 缺口、责任与验收见下一节，不能显示为已上线 |

## 3. 后端待补项与接口边界

以下 S 编号仅用于交接追踪，不代表已批准的 API 路径。新增接口先定 schema、错误码、授权与测试，再接移动端。

### S-01 删除好友（对应总清单 N-09）

证据：[000013 迁移](https://github.com/web3-superapp/loop-api/blob/83f5ac7a9de654d28a0628f38a79db44a0c6221b/migrations/000013_social_chat_closed_loop.ts#L284) 的 `friendships_immutable` 触发器主动拒绝 UPDATE/DELETE。取消关注接口只修改 follow，拉黑也不会删除 friendship。

后端需定义解除关系的双方视图、已有私聊权限、历史消息保留、重新申请和幂等/不明结果恢复，再提供迁移及正式命令。移动端据返回关系更新目录和按钮；不能仅本地移除一行或调用 unfollow 冒充删除成功。

验收：重复删除、超时恢复、双端关系一致、删除后旧私聊与历史访问、重新添加、拉黑后解除拉黑不能意外恢复已删除关系。

### S-02 群消息到公开资料的授权映射

证据：`src/features/communication/community-persona-service.ts`、`src/integrations/stream/channel-gateway.ts` 的 Persona 投影没有可供客户端使用的公开 Profile 映射；成员列表也不能把消息 Stream ID 与公开资料可靠关联。

后端需明确查看者、社区、发送者和公开资料的授权映射及失效条件。移动端只消费正式投影，延续 `ConversationSocialScope` 的可信来源边界。禁止用 Alias、显示名、Stream ID 或钱包地址猜测 `publicProfileId`。

验收：同名用户、不同社区 Alias、退群、封禁、无权限、资料不可见和映射失效；失败时不能打开另一人的资料。

### S-03 公开持仓与交易（对应 N-10）

证据：[identityProjectionSchema](https://github.com/web3-superapp/loop-api/blob/83f5ac7a9de654d28a0628f38a79db44a0c6221b/src/routes/v2/community-schemas.ts#L210) 只有公开身份字段。现有 wallet balances/activity 是本人资源，转账记录不等于买卖记录。

后端需定义查看者范围、持有者授权、隐私设置、canonical assetId、来源/时点、分页和不可见状态；移动端再补展示模型。不能改用目标 ID 调用本人钱包接口，也不能把不可见或读取失败显示成零持仓。

验收：本人/好友/陌生人、隐私开关、撤销授权、空数据与不可见区分、缓存按账号隔离、买卖与普通转账区分。

### S-04 群友买入提示（对应 N-11）

代码中未发现对应的授权事件生产链路；存在 `trade.result` 通知类别不能证明社区广播已实现。

后端需定义用户可取消的授权、钱包归属、确认买入判定、社区可见范围、重复投递去重及链重组撤销；明确由谁发布事件。移动端依据该事件展示提示，点击资产仍使用 canonical assetId；不能把任意入账转账当成买入，也不能从客户端模拟生产群消息。

验收：关闭分享、退出社区、失败/未确认交易、重复事件、链重组、账号切换和资产身份错误。

### S-05 相机扫码与外部唤起（对应 N-07）

`socialQrScannerProvider` 默认 `null`；现有入口可粘贴识别。个人码为完整 LOOP ID，社区码为 `loop://community/{id}`；HTTPS 仅接受配置允许的来源。二维码是发现入口，不是加好友或加入社区的授权票据。

后续提供 iOS/Android 相机解码适配器，完成权限拒绝、取消、恢复、错误码和设备测试。外部相机唤起需要正式域名/平台关联配置及原生验收；当前没有交付证明。扫描结果仍先过现有白名单解析，再进入原搜索/社区权限流程，不执行任意 URL 或支付。

## 4. 移动端代码入口

| 路径（相对仓库根目录） | 用途 |
|---|---|
| `lib/features/chat/friends/chat_create_menu_button.dart` | 添加菜单与本人二维码入口 |
| `lib/features/chat/friends/friend_gateway.dart` | 好友/申请/建群/私聊能力边界；当前无删除好友命令 |
| `lib/features/social/social_gateway.dart` | 关注、拉黑、消息请求；与 friendship 区分 |
| `lib/features/social/public_profile_sheet.dart` | 公开资料、申请、拉黑确认与失败反馈 |
| `lib/features/chat/v2/direct_message_screen.dart` | 从已授权资源取得公开 peer |
| `lib/features/chat/v2/conversation_social_scope.dart` | 传递公开 peer / 社区分享上下文 |
| `lib/features/chat/group_alias/group_alias_stream_message_identity.dart` | 消息身份保护；仅可信 DM peer 开放资料入口 |
| `lib/features/chat/v2/loop_channel_message_policy.dart` | 长按操作与 Stream 原有权限动作 |
| `lib/features/chat/v2/chat_forward_screens.dart` | 重新读取源会话、初选消息、转发、合并海报与社区码开关 |
| `lib/features/social/social_qr.dart` | 编码、解析白名单、PNG 分享、扫码适配器接缝 |
| `lib/main_preview.dart` | 显式离线样例，包括二维码演示用 LOOP ID；不是生产注册数据 |

## 5. 验证与继续开发顺序

本轮已有记录：Dart analyze 通过，Web Wasm 编译通过，行情/QR 77 项、社交相关 165 项测试通过；补充 QR 入口/解析 6 项通过。这些集合有重叠，不相加为唯一测试总数。Harness 检查通过。

额外 Preview 路由回归为 8 项通过、5 项失败；失败为已登记的 `chat_preview_conversation_identity` 背景对比度基线问题，未降低断言。浏览器中确认个人二维码显示；最后针对底栏遮挡改为根 Navigator 弹层后已编译并通过上述 QR 测试，但该层级修复仍需补充浏览器/设备视觉复验。生产双账号消息、真实相机、外部唤起、公开资产服务、真实买入广播均未验收。

提交前只读社交评审未发现阻断问题。现有 S99 测试没有安装 GoRouter，不覆盖新增转发菜单的完整导航；开发接手需补一条真实路由下的「长按 → 初选消息 → 合并海报」回归。静态评审不替代这项验收。

接手建议：先核对 API 版本与 S-01/S-02 契约，再完成删除好友和群头像链路；S-03/S-04 先确定授权和数据来源；S-05 按平台适配验收。不要把待补项直接替换成前端假成功。

复查命令（沿用本仓库 `bin/` 工具链）：

```sh
bin/dart analyze --format machine
python3 scripts/check_harness.py
bin/flutter test --no-pub test/social_qr_test.dart test/chat_mobile_entry_test.dart test/community_public_profile_and_apply_test.dart test/communication_pages_test.dart test/s99_chat_feedback_test.dart
bin/flutter test --no-pub test/chat_preview_conversation_identity_test.dart test/chat_preview_route_guard_test.dart
```

产品范围与其余非合约缺口见 [服务待补交接](2026-10-03-non-contract-service-gaps.md)；实现及先前验证记录见 [社交规格](../superpowers/specs/2026-10-03-social-completeness.md)。
