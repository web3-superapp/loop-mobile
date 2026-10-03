# LOOP 非合约服务待补交接（2026-10-03）

本文件按 Flutter `6639279` 基线源码和本次产品反馈整理，供后端、运营、移动端与供应商联调使用。它区分已有客户端契约、可以复用的服务接缝，以及仍未覆盖的需求。初稿依据移动端适配器/模型；文末已补充 loop-api 多人开发分支的社交代码复核。代码存在不等于部署、供应商、双账号或真机验收通过。以下新增字段/能力均为建议，不虚构已上线 endpoint。

本次产品方向：聊天 / 广场 / MEME / 情报 / 钱包；我的社区和挖矿为子入口，广场包含社区/语音房栏目。New Pairs 与 Smart Money 保留次级入口。广场复用社区目录与每社区语音读数；平台 MEME 以匹配目录项目的 `LaunchDetail.saleConfig.projectToken` 与 `detail.launch.chainId` 组成 canonical assetId，且配置版本必须与链上读数一致；社区资产只从社区的 canonical boundAssetKey 判定。不能把 Launch 销售合约地址当作代币，不能按名称、ticker 或页面存在推定平台资产、在线或交易权限。

## 1. 可复用的现有接缝

| 领域 | 仓库已有的契约/能力 | 复用边界 |
|---|---|---|
| 身份、资料 | Privy 认证、V2 account/session；`/v2/profile`、`/v2/profile/loop-id`、头像与隐私资源 | 继续同一 Privy owner；LOOP ID、邀请码、外部钱包地址不是同一种 ID；已有资料保存不证明安全设置已配置 |
| 社区目录/加入 | `/v2/community/home`、`/v2/communities`；目录 cursor、推荐版本；创建/加入/离开及治理模型 | 可复用后台给出的推荐顺序、分页和已确认 membership；社区治理的 `muted` 是禁言，不是用户免打扰 |
| 邀请 | `GET /v2/referral` 签发单账号邀请码，`POST /v2/referral/claim` 绑定；规则版本、绑定窗口及验证阶段 | 邀请码复制已实现；绑定成功不等于挖矿有效，更不是现金收入/返佣 |
| 好友/私聊/群聊 | Friend gateway、后端创建渠道、operation 查询，Stream 官方消息/历史/搜索/转发/合并 | 使用已授权 CID 与 membership；群内 Alias 与公开 Profile 身份分开；消息不因本地动作就算发送或删除成功 |
| 社交治理 | `/v2/connections`、follow、`/v2/blocks`、message requests | blocks adapter 已存在，不能统称“拉黑服务缺失”；删除好友是另一个关系变更需求 |
| 语音 | 每社区 `/v2/communities/{id}/voice-rooms/current`，房间资源、创建/加入/离开、举手/主持人操作；Stream 官方媒体状态 | 可复用真实房间列表与已有大厅；社区可见不等于允许旁听，LOOP roster 不证明 Stream 正在连接或开麦 |
| 行情/Mining | V2 market overview/detail/candles/trades/holders 与 New Pairs/Smart Money 接缝；Mining summary/assets/rank/rules | 行情保留来源和时点；Mining 排名是版本化算力投影；资产持有人列表不等于公开用户的所有持仓 |
| 社区 AI | `/v2/communities/{id}/ai` 下 overview、ask、answer report 适配器；回答引用、来源时点、今日讨论摘要 | 已有问答接缝，不统称“AI 未实现”；模型/供应商当前可用性需服务证据，知识文档库尚不在现有来源模型 |
| 钱包动作/通知 | 原有钱款意图、账户安全接缝、push 注册与通知读数 | 新一级入口只能复用已有门控；二维码、按钮、已登记 token 不能证明支付、兑换、保护状态或消息送达 |

## 2. 注册、邀请与初始社区

| 编号 | 具体缺口 | 需要的服务能力（建议，待定稿） | 最小验收 |
|---|---|---|---|
| N-01 | 邀请下载后首次安装自动归因；现有 referral 只接受手工 claim，未见 deferred install attribution 契约 | 经批准的 App/Universal Link 及安装落地路径，短期不透明归因 token、验证/有效期/消费规则、账号确认与绑定窗口；无供应商时继续手动填码 | 未安装→下载→首次登录、已安装直达、换账号、失效/篡改 token、自邀请、已绑定不可覆盖；失败不阻断注册；不以设备指纹猜邀请人 |
| N-02 | 自定义邀请码；当前单账号服务器签发码只有读取/绑定，无自定义写入 | 全局唯一性、允许字符、保留词、大小写归一化、修改次数/冷却、旧码是否继续有效、原子冲突处理与审计 | 两账号抢同名只成功一个；旧分享链接/已绑定关系不被改写；不可冒充 LOOP ID；丢响应可查原变更 |
| N-03 | 注册填邀请码获得“初始算力”；当前 boost/关系状态不构成固定新人奖励 | 版本化新人奖励规则、发放时点、资格/反作弊、是否需要钱包或首个有效持仓、一次性奖励账本及撤销口径 | 重复注册/绑定/重装不重复给；关系 pending 不展示已得算力；数额来源可查；发放后的总算力与排名同版本 |
| N-04 | 后台可编辑默认推荐 5 个；已有推荐 ID/规则版本和 discover 顺序，但未见专用推荐编辑接口 | 可由人工运营先维护服务器配置，明确名单/排序/生效版本、社区撤下和不足5个时行为；审计及回滚。移动端默认最多5个且可取消/跳过 | 0/少于5/多于5条、隐藏/封禁社区、名单更新；只对用户当前勾选项 join；部分失败仅重试未确认项，已入社区不重复宣告成功 |
| N-05 | 所有新加入社区默认免打扰；当前 join 无用户通知偏好字段，成员 mute 是治理禁言 | 服务器绑定新 membership 的频道通知策略；定义默认免打扰对普通推送、@提及、角标的范围，以及后续修改/跨设备一致性；Stream 与 LOOP 配置同步状态 | 新人首次加入及重入、旧成员保留偏好、双设备、同步失败；缺证据时不能显示“已开启免打扰”；不能通过禁言实现免打扰 |

Email OTP、Google/Apple 与外部 EVM 凭据流程已存在。产品提及 DEBOX 式6位密码只是参考，不能将其当成已批准身份架构；新增密码/恢复/设备锁需要单独设计。大陆可下载、无需翻墙登录、真实邮件速度、商店分发和双端回跳需真实网络/供应商/签名安装验证，本文件不以编译或本地预览代替。

## 3. 广场、公开语音与二维码

| 编号 | 具体缺口 | 需要的服务能力（建议，待定稿） | 最小验收 |
|---|---|---|---|
| N-06 | 全平台公开在线语音索引；目前只有每社区 current room，不是全局公开房间 feed | 带 cursor 的公开/可发现房间投影，社区/房间稳定 ID、可见性、状态/时点、标题来源、允许加入/需入社区的规则、封禁过滤；服务端权限检查 | 未加入可见社区是否能听由返回规则决定；隐藏/封禁/结束房间不泄漏；跨页无重复；索引显示在线后加入仍重新授权；不能从 presence/人数推导直播 |
| N-07 | 用户、社区、房间二维码及扫码识别；已有 `lib/core/qr/loop_qr_code.dart` 编码器、LOOP ID 文本分享和社区房间链接规则，完整扫码协议与目标路由/服务仍需联调 | 复用本地编码器，按已批准链接生成/解析 QR；限定 host/path/type，版本、失效/撤销、隐私；已安装直达与未安装落地；相机扫描在明确动作后请求权限 | 扫自己/他人/不存在/隐藏/已结束房间、坏码/外部域名、相机拒绝；扫码只定位，不自动加好友、入群、加入语音或签名支付 |
| N-08 | 合并转发海报附二维码；现有 PNG 由本机渲染捕获并系统分享 | 明确海报目标为个人/社区/房间哪一种、可分享链接和 QR；如需线上回看另定义服务器上传、鉴权、撤销、保留期；本机导出可继续不上传 | 文本复制/转发与图片导出均保持当前消息权限/匿名规则；撤回/删除内容排除；二维码目标与海报一致；不夹带内部身份、钱包、token或虚假下载地址 |

当前可先对可见社区按页展示，并仅对本页做有界的逐社区语音查询。该方案只能说明“当前可见社区的房间”，不能标成“全平台在线语音”，也不能把请求失败显示为无房间。全局索引是规模与权限层面的服务待补项。

## 4. 社交管理、公开资产与买入提示

| 编号 | 具体缺口 | 需要的服务能力（建议，待定稿） | 最小验收 |
|---|---|---|---|
| N-09 | 删除好友及从资料页管理关系；friend gateway 尚无删除命令，公开资料 sheet 当前主要为加好友/关注/私聊 | 后端定义双向好友关系删除、已有私聊可读/可写、通知与重新申请冷却；稳定 publicProfileId、幂等命令及结果查询。block 已有服务，资料页可在确认权限后复用 | 删除不等于取消关注/拉黑；双方并发删/加、丢响应及跨设备一致；删除不擅自删对方历史；拉黑实际影响以服务器 admission 为准 |
| N-10 | 看好友持仓/交易；隐私资源有 visibility 字段，当前公开资料 sheet 不含资产读数 | viewer-scoped 公共 Portfolio/Trade History 投影，用户授权绑定的钱包范围、来源/时间/链、public/followers/private 判定、撤销/分页；匿名群内不能自动暴露公开账户 | 非好友/仅关注/已拉黑/隐私变更即时限制；缺来源不显示零持仓；跨钱包无重复；资产行情 holders/trades 不冒充该用户数据 |
| N-11 | 社区“群友买入”提示/持仓广播；隐私页源码明确该原型广播未实现 | 钱包归属授权、真实已确认交易索引、税后到账和买卖分类、社区资产映射、用户 opt-in 与群权限、事件幂等、重组撤销；消息仅携带稳定事件引用 | 自成交/路由多跳/转账不能误判买入；同一tx只一次；失败/未知交易不广播；关闭公开/退出社区停止后续广播；点头像仍受隐私限制 |
| N-12 | 长按消息复制/删除/转发的权限与治理全量验收 | 先复用 Stream 官方消息动作及已接搜索/转发/合并；删除、撤回、管理员删除和附件保留必须由 provider role/权限定义，不新增假删除 API | 自己/他人/已删除/管理员消息；失败不移除本地内容冒充成功；转发仅可读来源到已加入目标；群 Alias 和公开身份不混用；真机复制/附件/撤回同步 |

拉黑适配器在 `lib/integrations/backend/v2/social/loop_v2_social_api.dart`，并有 Social controllers。仍需验收某个资料入口是否准确携带公开目标及 UI 回执、后端/Stream 权限投影是否一致。不能因好友纵切老文档写“block out of scope”就否认后续 V2 blocks，也不能因 adapter 存在就宣称群内消息已隐藏。

## 5. 情报、平台资产、AI 与钱包

| 编号 | 具体缺口 | 需要的服务能力（建议，待定稿） | 最小验收 |
|---|---|---|---|
| N-13 | 推广排名与全产品一致的增长/榜单口径；现有 Mining rank 用户/社区榜单、Referral 层级计数不是推广排行榜 | 排名 metric、有效邀请口径、时间窗/结算版本、反作弊、cursor、匿名/公开显示规则、个人名次；不要从有限页本地重排称全平台排名 | 并列/零值/隐藏算力/关系 invalidated、重结算与分页；推荐绑定不等于有效增长；榜单与算力/发射增长证据可核对 |
| N-14 | 平台 MEME/社区资产分类的完整服务集合 | 当前可复用 Launch 目录及匹配详情中已确认的 `saleConfig.projectToken` + `launch.chainId` 映射、社区 canonical `boundAssetKey`，再独立读取行情；客户端每追加批次 6 条来源记录，并发最多 3 条，链不支持/配置未确认/缺行情均保留原因。未来补完整平台资产 registry、上下架/毕业/取消状态、分页和 sourceVersion，不以 ticker 推导 | 同名代币/跨链同地址、销售合约与代币混淆、配置版本不一致、未发布/取消项目、缺行情、目录截断；只将已验证项目映射纳入，剩余范围说明未加载 |
| N-15 | 情报活动驻留、公告与社区运营数据 | 管理后台人工维护活动/公告投影：生效窗口、社区/资产作用域、目标链接白名单、排序/撤销与版本；增长/活跃指标定义与权限 | 活动到期/撤下、跨账号权限、未知链接、历史版本；没有活动源保持不可用，不造活动卡片 |
| N-16 | 社区 AI 文档知识库及管理辅助/分析 | 现有问答、引用和讨论摘要继续复用；需新增按社区授权的文档导入/更新/删除、白皮书/FAQ/AMA版本、来源引用、检索权限、上传处理状态、用量与成本；管理建议是否人工确认后执行单独定义 | 删除/撤回来源后不继续引用；多社区隔离、恶意文档、无依据拒答；现有 `documents` unavailable 不能伪报篇数；AI建议不自动封禁、转账或修改合约 |
| N-17 | 扫码支付/兑换及钱包管理、安全闭环 | 仅在已有 reviewed money intent/quote/签名/状态协议可用时复用；支付 QR 须另定义网络/资产/接收地址/数量/有效期和 canonical review，安全入口从状态源读取 enrollment | 扫码不自动签名；地址/金额变化重新确认；过期报价/错误链/不足授权/超时先对账；身份钱包不等于有余额；安全设置缺来源不宣称保护已开启 |
| N-18 | 登录后默认通知与真实推送验收 | 已有 push token 注册、偏好及通知路由继续复用；默认社区 DND 需 N-05 服务策略、发送规则、iOS/Android sender 配置与真实送达回执 | 前台/后台/杀进程、账号切换、权限拒绝、群@提及、免打扰；登记 token/保存偏好不等于送达；只有用户明确点击才导航 |

New Pairs/Smart Money 按本次确认移到次级入口；原服务的 unavailable 原因和来源限制保留。它们不再属于一级首页核心，不因此新增 provider、假 listing time、风险结论或自动交易。

## 6. 接口定稿与人工优先的交付方法

上述表格描述资源与验收，不为未确认服务分配 HTTP 路径。新增契约先在 `loop-api` 正式 schema/错误目录定稿，再增加 Flutter integration adapter 和 feature-facing narrow port。沿用 request-local Privy Bearer、owner-scoped 资源、版本 CAS（适用偏好/配置）、严格来源/时点、可展示原因码、写入 UUID 幂等与不明结果对账；每个接口单独声明重试/恢复范围，不把所有写操作当成可重复 POST。

推荐社区、活动名单、合格资产申请、增长审核、文档上传和 AI 管理建议可以先人工运营。需要说明是谁发布、审批版本、何时生效、撤销/回滚与审计，不将人工操作包装成实时自动算法。好友关系、公开资产权限、供应商房间创建和资金交易仍由服务器/协议权限执行，人工后台不能替代用户授权。

优先顺序建议：N-04/N-05 初始社区与 DND、N-06 公共语音索引、N-09 关系管理、N-07 QR；随后 N-01/N-02/N-03 邀请增强、N-10/N-11 公共资产与交易广播；N-13/N-15/N-16 推广/活动/文档知识库单独验收。N-17/N-18 按现有安全与供应商发布门控联调，不因页面移动而提前放开。

## 7. 核对来源及交付边界

- 用户产品计划及本次确认：5个推荐可取消、可人工流程人工、次级 New Pairs/Smart Money、导航和钱包整合。
- 注册/邀请：`lib/integrations/backend/v2/referral/loop_v2_referral_api.dart`、`lib/features/mining/referral_models.dart`、`referral_screen.dart`。
- 社区/语音：`lib/integrations/backend/v2/community/loop_v2_community_api.dart`、`lib/features/community/community_models.dart`、`lib/integrations/backend/v2/communication/loop_v2_communication_api.dart`、`lib/features/chat/v2/chat_v2_gateway.dart`、`voice_room_share.dart`。
- 社交/分享：`lib/features/chat/friends/friend_gateway.dart`、`lib/integrations/backend/v2/social/loop_v2_social_api.dart`、`lib/features/social/public_profile_sheet.dart`、`loop_id_share.dart`、`lib/features/chat/v2/chat_merge_export.dart`。
- AI/资产/隐私：`lib/features/community/community_ai_models.dart`、`lib/integrations/backend/v2/community/loop_v2_community_ai_api.dart`、`lib/integrations/backend/v2/market/loop_v2_market_api.dart`、`lib/features/profile/profile_v2_screens.dart`。
- 工程约束：`docs/product/implementation-constraints.md`、`docs/product-decisions.md`；旧说明与现行 adapter 冲突时以核实的当前源码及正式协议定稿为准，不据旧占位文案否认已存在接缝。

本清单的“待补”主要指需求协议范围未覆盖、管理/供应商流程未闭环或真实验收未完成。前端已有适配器、离线样例、编译/测试成功与生产服务开通分别交付，不能互相代替。

## 8. 社区类型的结构缺口 N-19

文档第25段定义普通社群、算力社区和品牌社区。当前客户端的 `CommunitySummary` / `CommunityDetail` 无上述权威类型字段，核验状态、绑定资产、成员角色都不能代替社区类型。普通社群沿用 group 命令（当前要求2–29个已接受好友）；算力社区沿用目录/主页/聊天与资产绑定读数；品牌社区不可由“已认证”标签推导。

后端需定义类型、人工审核/变更权限、适用入口、成员准入与持仓变化、白名单及权重、品牌权益清单。前端依据正式投影展示权益；类型切换后的会话/成员权限与历史状态需一致。品牌空投涉及合约时归入合约交接，不能用本地名单显示“已到账”。文档结构核对见同目录 navigation-structure-review。

## 2026-10-03 GitHub 实际开发分支复核

具体代码入口、S-01 至 S-05 的开发边界与验收见 [社交开发接手说明](2026-10-03-social-development-handoff.md)。

检查源为 `web3-superapp/loop-api` 的 `integration/v2`，固定提交 `83f5ac7a9de654d28a0628f38a79db44a0c6221b`（不是旧 main）。可核实贡献者 muxiaodeng、CWD1208、Doog-bot534。以下为代码检查，不代表部署验收。

- 真实已有：`src/routes/v2/chat.ts` / `listDirectChannels` 返回本人 direct CID 的公开 peer；`src/routes/v2/social.ts` 与 community-service 已实现好友请求、接受建立 friendship、关注、拉黑和解除拉黑。
- N-09 删除好友：`migrations/000013_social_chat_closed_loop.ts` 的 `friendships_immutable` 主动拒绝 UPDATE/DELETE。`DELETE /v2/connections/follow/:publicProfileId` 只取消关注，`block` 也不会解除 friendship。应新增正式删除决策、迁移、私聊权限变化、重加好友及幂等验证。
- N-10 公开持仓和交易：四字段 identityProjectionSchema 无资产数据，wallet balances/activity 为本人资源，activity 是转账，不是买卖。不能把本人钱包接口改个标题当公开主页。
- N-11 群友买入：未发现授权广播 producer 或已确认买入事件契约；trade.result 类别不是社区广播实现。须补 opt-in、钱包归属、买入判定、确认/重组撤销与去重。
- 群消息头像映射：community members 有公开 profile，但不含 Stream ID；provider Persona 仅发布 alias ID、alias、version。因此不能用群内 alias 或 Stream ID 推断公开身份。DM 可接通，群消息还需经授权映射契约。
- N-07 扫码：移动端增加了个人/社区二维码、PNG 分享和严格识别入口；相机 QR 解码适配器仍未接入。社区自定义码尚未验证系统相机外部唤起，不算完整扫码交付。
