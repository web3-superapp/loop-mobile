# LOOP Flutter App

Repository phase: `active`.

LOOP 的正式客户端是 **Flutter App**，目标平台为 iOS 与 Android。`web/` 仅用于本地 UI 自动化与响应式预览，不是独立网页产品，也不是生产交付目标。

正式前端仓库：<https://github.com/web3-superapp/loop-mobile>。原仓库中的 HTML 原型、调研、计划和验证脚本已迁入 [`reference/legacy-prototype/`](reference/legacy-prototype/README.md)，仅作为冻结参考，不再作为开发入口。后端契约与适配器位于 <https://github.com/web3-superapp/loop-api>。

## 当前已完成

- 六个固定主入口：Home / Market / Launch / Chat / Wallet / Profile
- 全量 103 个产品 surface 的路由目录；产品优先级独立采用 A / B / C（47 / 46 / 10），`deferred` 单独表达本期不交付
- 受 Privy 会话保护的 Email OTP 实现；缺少 Mobile App Client ID 时保持不可登录，真机验证待补
- Hyperliquid Testnet 公共只读永续行情；D8 已接入 principal-bound 后端会话、显式钱包绑定以及短时效 config/account 读取。D4 Positions 已接入后端短时效只读投影、有限首屏和 cursor-only 续页，过期会同步清空仓位与空结果；D5 生产详情仍 fail-closed，orders / fills / funding 只有严格运输、尚未挂载产品页。下单、撤单、平仓、杠杆、转账、提现与签名仍全部关闭
- Stream Chat 官方 client、按用户持久化、token-provider 会话、频道列表与消息页已接入；后端身份/token 未就绪时不连接、不声称在线
- Stream `token_card.v1` 只读消息卡已接入官方消息渲染链路：生产消息只接受严格的资产/链/合约/时间标识，不固化价格或风险事实；后端新鲜事实投影未接入前显示不可用，也不提供 Buy / Watch。旧版群聊、私聊、搜索与卡片 fixture 路由已限制为显式离线 Preview
- 原生 Privy Bearer `POST /v1/bootstrap` 客户端已接入；严格解析服务端 LOOP/Stream 身份、隔离账号切换并最多重试一次 401。未配置后端地址时零请求，Stream token 缺失时仍不连接
- Audio Room 前端纵切已完成：后端授权房间接缝、默认静音单飞加入、官方 `CallState` 状态/成员/能力/麦克风 UI、失败清理和账号/房间/client 轮换；真实 Video token 与房间 locator 缺失时保持不可加入
- Audio Room 首版只配置前台麦克风能力；任何退房或 App 退到后台都会立即发起原生音频暂停、终态关麦与 single-flight 退房，不让可能卡住的麦克风/原生命令延迟退房。大厅只在旧 `Call` 已从 Stream `activeCalls` 移除、在途麦克风命令已结束且命令后的第二次关麦已执行后开放。为避开 Stream Video 1.4.3 的迟到音轨重建缺陷，每个 `Call` 只允许一次 Speak 启动；Mute 后需离开并重进才能再次发言。失败可显式重试清理。会自动注册 Telecom/CallKit 的 Stream Push 插件不进入当前依赖图，Android 同时移除可选来电、后台通话、相机与推送项，iOS 不启用 Camera、PushKit、CallKit 或后台模式
- 通知导航的 EventSource / Coordinator 纵切已接入根组合：生产 source 默认是无初始点击、无事件的 disabled 实现；协调器只从真实 LOOP session 与已验证 bootstrap identity 取得 Stream 身份。恢复期间最多暂存一个、默认 15 秒且硬上限一分钟的点击，账号切换、超时或授权失败即丢弃；通过完整重验后也只能落到官方 Chat CID、Audio Room 大厅或通知中心。生产通知页不展示伪实时卡片，演示卡仅在显式 `开发预览` 中可见
- Watchlist 已按后端现有版本化契约完成 providerless 应用逻辑：分组、资产顺序、草稿、保存单飞、显式丢弃与版本冲突恢复均在窄端口后建模。正式入口默认不可用，不发送私有请求；只有 `main_preview.dart` 注入明确标注的内存实现。Watchlist 只保存资产标识，不把价格、涨跌、可交易性或提醒状态伪装成账户事实
- Profile presentation 已按后端现有契约完成 providerless 应用逻辑：只建模 nullable Alias、opaque `avatar:` reference、版本与更新时间；编辑、丢弃、保存单飞、冲突重载、失败重试与迟到结果隔离均已落地。Bio 不属于该契约，Visibility 仍归独立 Privacy 资源，Avatar 选择在来源契约确定前禁用。正式入口默认不可用且不再伪报保存成功；只有显式 Preview 使用带标签的内存实现
- Privacy preferences 已按独立后端契约完成 providerless 应用逻辑：只建模 `discoverable` 与 `private/followers/public` copy-trade visibility 偏好，支持完整草稿替换、冲突冻结、显式重载与 owner/gateway 轮换。旧版 Portfolio Broadcast、群组白名单、活动/仓位可见性和 copy-trade 假授权表单已移除；偏好不代表发现、followers 或跟单执行已启用。正式入口默认不可用，只有显式 Preview 使用带标签的内存实现
- Notification preferences 已按后端契约完成 providerless 应用逻辑：只建模 `price_alert_triggered`、`provider_activity_projected`、`security_notice` 与 `support_update` 四项 owner intent，支持完整草稿替换、冲突冻结、重载、单飞与 owner/gateway 轮换。`delivery` 始终为 `unavailable`；旧版六分类、伪系统权限、空的设备设置动作和 Quiet hours 已移除。正式入口默认不可用，只有显式 Preview 使用带标签的内存实现；这不代表 Firebase、APNs/FCM、系统权限、Price Alert 或任何通知送达已接通
- Account、Wallet、Market、Perp、Chat、Profile 与系统状态组件
- 深色 LOOP 设计系统、键盘焦点、语义标签、reduced-motion 与手机/桌面响应式布局

所有供应商写入默认 fail-closed。正式入口 `lib/main.dart` 不注入 fixture；只有 `lib/main_preview.dart` 的显式离线 Preview 组合根注入 memory/fixture gateway。Preview 中的聊天、语音、钱包和交易状态都标注为 offline / simulated 或 `开发预览`，不代表生产登录、签名、下单、聊天或语音已经接通。

应用逻辑继续通过页面状态、Riverpod controller 和窄业务 port 隔离 provider。`lib/features/` 不直接依赖 Dio 或保存 `/v1/` 路由；Perp 私有只读的真实 adapter 已位于 `lib/integrations/backend/`，正式入口仅在已验证 Privy principal、已观测钱包和 HTTPS 后端 URL 同时存在时创建会话。其他尚未接入的 production port 仍使用 unavailable 实现，Fake 仅允许测试与显式 Preview 注入。

Stream 生产路径必须先通过 BFF 获取或刷新短期用户 token，并由 session authorizer 建立 SDK 会话。每个 Privy principal 使用独立的 Stream client/persistence 实例，账号切换会废弃旧实例，避免不可取消的旧连接污染新账号。正式 Chat 页面直接使用 Stream 官方 controller/UI 作为消息、分页、已读、输入状态与离线历史的真相源；缺少授权时保持 fail-closed，也不会把本地 preview 伪装成在线能力。附件与语音录制会等平台权限和产品策略正式配置后再开放。

当前产品决定以 [`docs/product-decisions.md`](docs/product-decisions.md) 为准。内部不可变 `user id` 是账户与社交关系的主身份，钱包地址只是可绑定、可替换的凭证。界面只陈述可验证的安全事实及来源时间，不使用 AI Guard 或风险分口径。

## 开发入口

```bash
bin/flutter pub get
bin/dart format --output=none --set-exit-if-changed lib test
bin/flutter analyze
bin/flutter test
bin/flutter build apk --debug
bin/flutter run
```

你提供的 Privy App ID、Mobile App Client ID 与 Stream API key 都已作为客户端安全的 Development 默认值接入。需要切换 Privy Client 时仍可显式覆盖：

```bash
bin/flutter run --dart-define=PRIVY_APP_CLIENT_ID=client-新的完整值
```

连接 Development 后端的 Perp 私有只读入口：

```bash
bin/flutter run --dart-define=LOOP_BACKEND_BASE_URL=https://api-dev.quant-dinger.cc
```

不要把 Privy Secret、Stream Secret、Firebase service-account、APNs 私钥或 Hyperliquid 私钥放进 Flutter 或 Git。

离线 UI 目录与演示数据使用独立入口：

```bash
bin/flutter run -t lib/main_preview.dart
```

该入口会清空供应商标识并显式开启 Development Preview，不会发送 OTP、连接 Stream、请求实时行情或发起钱包/交易操作。

Web release build 只用于本地视觉验收：

```bash
flutter build web --release
```

## 已锁定工程基线

本仓库的目的为：Build Loop, a Flutter iOS/Android app with six primary destinations—Home, Market, Launch, Chat, Wallet, and Profile—using Privy identity/wallets, Stream Chat/Video, and backend-mediated Hyperliquid Testnet trading.

- Flutter 3.47.1 / Dart 3.13.1
- Android API 28–36、AGP 8.13.2、Gradle 8.14、Kotlin 2.3.20、Java 17
- iOS 17+、Xcode 26.6、CocoaPods 1.16.2
- Privy 0.10.1；Stream Chat/Persistence 10.3.0；Stream Video 1.4.3（Push 1.4.3 已验证兼容但首版不链接）
- Firebase Core 4.13.0 / Messaging 16.5.0
- Riverpod 3.4.2 / go_router 17.5.0 / Dio 5.11.0
- Decimal 3.2.6 / UUID 4.6.0

`harness.json` 是可机器校验的工程画像，`AGENTS.md` 是开发与安全边界。任何依赖、原生工具链、主导航或安全边界变更都要同步更新决策和验证报告。

Native release matrix：

```bash
bin/flutter build apk --release
bin/flutter build ios --debug --no-codesign
bin/flutter build ios --release --no-codesign
```

Harness validation：

```bash
python3 scripts/check_harness.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

## 不要重复建设

- 不要继续扩展根目录的 HTML 原型；它只是历史交互与安全契约参考
- 不要重新搭 Flutter 路由、主题、六 Tab 壳层、页面目录或通用状态组件
- 不要新建第二套交易确认弹层；所有资金意图统一进入 F11 `SigningReviewSurface`
- 不要把 Perp 做成第七个底部 Tab；入口固定在 Market 的现货 / 合约分栏
- 不要自建钱包、撮合、桥、IM 或 RTC 基础设施；只实现已选供应商的薄适配与 LOOP 编排
- 不要启用 Hyperliquid HIP-3、builder fee 或非 Core 市场
- Pay 保留首页 `Coming soon` 入口以表达产品位置，但 A / B / C 优先级不等于交付期；B5-B8 当前全部 deferred，落地页不得出现扫码、相机、金额或支付动作

前端现已具备原生 LOOP identity bootstrap、Stream Chat 与前台 Audio Room 的主体轮换、后端 token/locator 边界、麦克风原生声明、通知意图契约和根协调器。根协调器的存在不代表通知已连接：正式入口仍使用 disabled EventSource，只有真实 session 与 bootstrap identity 同时成立时才可能处理一个有界点击。后端可并行实现 Stream Chat/Video 短期 token，以及“预创建房间 + 成员角色无 `create-call`”的 Audio Room locator 契约；双方就绪后再做真机双端联调。Firebase/Push 仍未初始化；还需要 Android/iOS Firebase 配置、精确 Stream provider name、真实 payload fixture、服务端事件 ID/过期/账号绑定契约，以及 iOS 普通推送与 VoIP 的单一路由策略。后台响铃、Camera、PushKit 与 CallKit 随后单独启用。

## 仓库结构

- `lib/`、`ios/`、`android/`、`test/`：当前 Flutter 客户端源码与测试
- `reference/legacy-prototype/`：原仓迁入的冻结 HTML 原型、产品文档、调研与历史验证脚本
- 后端的 `contracts/` 与 `server/`：已迁入 `web3-superapp/loop-api`

迁移提交保留了原仓 Git 历史；追溯旧实现时可沿合并父提交查看，日常开发只应修改 Flutter 正式源码。
