# LOOP Flutter App

Repository phase: `active`.

LOOP 的正式客户端是 **Flutter App**，目标平台为 iOS 与 Android。`web/` 仅用于本地 UI 自动化与响应式预览，不是独立网页产品，也不是生产交付目标。

正式前端仓库：<https://github.com/web3-superapp/loop-mobile>。原仓库中的 HTML 原型、调研、计划和验证脚本已迁入 [`reference/legacy-prototype/`](reference/legacy-prototype/README.md)，仅作为冻结参考，不再作为开发入口。后端契约与适配器位于 <https://github.com/web3-superapp/loop-api>。

## 当前已完成

- 六个固定主入口：Home / Market / Launch / Chat / Wallet / Profile
- 全量 103 个产品 surface 的路由目录；产品优先级独立采用 A / B / C（47 / 46 / 10），`deferred` 单独表达本期不交付
- 受 Privy 会话保护的 Email OTP 实现；缺少 Mobile App Client ID 时保持不可登录，真机验证待补
- Privy Embedded Ethereum wallet readiness 已挂到正式 Wallet：完整认证且无钱包时可走现有 principal-bound SDK 创建链路，已有钱包时只展示并复制当前会话的完整地址。Manage wallets 不再显示假钱包；Receive 不生成二维码或声称支持入金。余额、资产、Send、Swap、签名与交易结果仍明确为演示或不可用
- Wallet 原型路由不再补造默认上下文：资产详情必须携带对应的强类型演示资产，Signing Review 必须携带来源 intent，DApp 预览只允许显示当前 Privy 钱包身份且浏览/注入保持关闭；裸深链统一失败关闭
- Wallet 本地草稿保持精确且不可执行：Send 金额只接受已知后端词法规则并原样保留尾零，Swap 的输入、输出、报价详情与 Review 只来自同一个不可变演示快照；编辑会撤销全部派生值，恢复与快速点击不会制造分叉 intent。HTTP、canonical intent、签名与交易结果仍未启用
- Wallet 其余纯前端控件已闭合：交易历史筛选只显示对应的演示行，Networks 的 testnet 开关只过滤明确标注的环境行，授权撤销保持禁用，Bridge 进度必须携带同一个强类型演示快照；裸深链不会编造路线或进度。所有这些状态仍不代表 provider 查询、钱包网络支持、签名、提交或成功
- Hyperliquid Testnet 公共只读 Spot 行情：独立读取 `spotMetaAndAssetCtxs`，按稀疏 token index 和精确 coin 关联，金额与涨跌使用 Decimal，Market 展示最多 50 个有成交量的交易对并支持搜索、刷新、错误与空状态。每一行可按精确 `spotIndex` 打开实时只读详情，展示当前响应中的价格、24h 成交量、provider/token identity 和客户端 UTC 收取时间。详情页另以该已验收市场的 provider coin 读取真实 `candleSnapshot`，支持精确映射的 1H / 4H / 1D / 1W / 1M、最多最近 120 根、手动刷新以及加载/空/错误状态；还会按 1h / 4h / 1d / 7d / 30d 固定周期严格校验每根 `T-t`。OHLCV 保持 String + Decimal，末根未收盘时明确标记，不回退演示 K 线或其他币种。它们都只是公共发现数据，不是可执行报价；买卖、余额、订单、签名、转账与提现仍全部关闭。旧 Perp 代码仅保留为未挂载的历史实现，不再属于产品范围
- Spot-only 产品边界已经在正式入口闭合：旧 `/perp*` 深链统一返回 Spot Market，正式 `main.dart` 不再装配 Perp 私有网关，目录中的 D1-D12 只作为不可点击的 `Out of scope` 历史记录。静态演示币种先进入实时 Spot 列表，只有当前 provider 快照已验收的市场才携带精确 `spotIndex` 打开详情；裸 `/market/token` 不再回退演示行情或 K 线
- Stream Chat 官方 client、按用户持久化、token-provider 会话、频道列表与消息页已接入；后端身份/token 未就绪时不连接、不声称在线
- Stream `token_card.v1` 只读消息卡已接入官方消息渲染链路：生产消息只接受严格的资产/链/合约/时间标识，不固化价格或风险事实；后端新鲜事实投影未接入前显示不可用，也不提供 Buy / Watch。旧版群聊、私聊、搜索与卡片 fixture 路由已限制为显式离线 Preview
- Chat 的 E9 资产快照已收敛为明确标注 `演示数据` 的 Spot market Preview：不再展示 Position、LONG、Entry、收益、跟单或假保存；唯一可用动作只打开公共 Spot 行情列表，Watch 在真实持久化接入前保持禁用
- Chat 的 Message Requests 已收敛为进程内 `开发预览` 状态：Accept 只从模拟 pending 列表移除且不创建 Stream 会话，Ignore 不通知对方，Report 不提交 moderation 举报；未知或重复处理的 ID 会失败，处理中的卡片禁止重复动作，Chat 首页数量随当前模拟 pending 列表变化
- 原生 Privy Bearer `POST /v1/bootstrap` 客户端已接入；严格解析服务端 LOOP/Stream 身份、隔离账号切换并最多重试一次 401。未配置后端地址时零请求，Stream token 缺失时仍不连接
- Audio Room 前端纵切已完成，并从正式 Chat 顶部提供唯一可见入口：入口只打开生产 Lobby，不发起 provider 操作，也不会回退演示房间。后端授权房间接缝、默认静音单飞加入、官方 `CallState` 状态/成员/能力/麦克风 UI、失败清理和账号/房间/client 轮换均已落地；真实 Video token 与房间 locator 缺失时保持不可加入
- Audio Room 首版只配置前台麦克风能力；任何退房或 App 退到后台都会立即发起原生音频暂停、终态关麦与 single-flight 退房，不让可能卡住的麦克风/原生命令延迟退房。大厅只在旧 `Call` 已从 Stream `activeCalls` 移除、在途麦克风命令已结束且命令后的第二次关麦已执行后开放。为避开 Stream Video 1.4.3 的迟到音轨重建缺陷，每个 `Call` 只允许一次 Speak 启动；Mute 后需离开并重进才能再次发言。失败可显式重试清理。会自动注册 Telecom/CallKit 的 Stream Push 插件不进入当前依赖图，Android 同时移除可选来电、后台通话、相机与推送项，iOS 不启用 Camera、PushKit、CallKit 或后台模式
- 通知导航的 EventSource / Coordinator 纵切已接入根组合：生产 source 默认是无初始点击、无事件的 disabled 实现；协调器只从真实 LOOP session 与已验证 bootstrap identity 取得 Stream 身份。恢复期间最多暂存一个、默认 15 秒且硬上限一分钟的点击，账号切换、超时或授权失败即丢弃；通过完整重验后也只能落到官方 Chat CID、Audio Room 大厅或通知中心。生产通知页不展示伪实时卡片，演示卡仅在显式 `开发预览` 中可见
- Home Global Search 已闭合 providerless 前端行为：只有显式 Preview 会显示并本地筛选一组有界的 `演示数据`，支持大小写/空白归一化、无结果与清空；群组和用户沿用精确注册的 Preview conversation ID，ETH 示例只进入公共 Spot 列表而不猜 `spotIndex`。正式会话在真实跨产品索引接入前显示不可用，不泄漏 Preview 结果
- Home Security Activity 已关闭无来源的安全结论：正式会话不再伪报 MFA、设备登录、审批次数或 `No urgent action`，没有已审核事件源时保持不可用。显式 Preview 只保留持续标注的布局示例，不计算风险分、不发请求，也不提供 Revoke/Block 等账户操作
- Launchpad 继续作为第 3 个一级入口保留，但当前只交付不可操作的 G1 占位：无项目来源时不声称项目正在进行、为空、已审核或满足资格，三个必要条件全部明确为未连接；G2–G4 继续 deferred，正式与 Preview 均不伪造项目、额度、申请、资金、签名或领取动作
- I1 连通性页面已取消默认离线结论：裸 `/system/offline` 只显示状态来源未连接，不再把路由名当成设备断网或服务故障证据；只有组合根显式提供一个已观察的 scope 才能显示离线、公共行情故障或私有 LOOP 服务中断。全局横幅仍未挂载，也未新增连通性插件、健康轮询或自动重试
- I2 服务错误页已取消默认失败与假追踪码：裸 `/system/error` 只显示错误上下文未连接，不再生成 `L-2048`，也不再把回首页伪装成重试或联系客服。只有精确请求返回错误或结果不可确认时，所属 feature 才能显式提供 presentation-safe observation；页面不会把超时说成确定失败。在后端 reference 的来源与精确语法完成审核前不显示任何 reference，Retry / Support 分别要求真实绑定的专用回调
- I3 强更页已取消默认阻断与假更新动作：裸 `/system/update` 只显示版本策略未连接，可以返回 LOOP，不再声称当前版本不安全或不可跳过。只有未来 app-level 策略边界显式提供 verified requirement 才进入阻断态，`Update now` 还必须绑定独立的已审核商店动作；当前没有版本策略源、整数 build 比较、登录前根 gate 或真实 App Store / Play Store 目标
- I4 维护页已取消固定假窗口与全功能中断结论：裸 `/system/maintenance` 只显示维护 notice 未连接，不再生成 `01:00–01:30 UTC`，也不声称 Account / Wallet / Spot / Chat 暂停。只有未来 app-level 来源显式提供仍有效的 approved notice 才显示维护态；当前 marker 不携带时间或受影响服务，`Check again` / `View service status` 分别要求真实专用回调
- I5 功能可用性页已取消默认地区限制结论：裸 `/system/region` 只显示 eligibility decision 未连接，不再声称已读取位置/账户资料，不再把 Spot 下单或出入金的全局未启用状态归因于地区，也不虚构 Market / Wallet / Chat 仍可用。只有未来 app-level 权威来源显式提供当前限制证据才显示限制态；当前 marker 不携带位置、原因或功能清单，Continue / Policy 分别要求真实专用回调
- I6 权限说明页已取消默认 Camera 与假系统动作：裸 `/system/permission` 只显示权限上下文未知，不会请求权限或打开设置。只有发起功能显式提供 Camera / Notifications / Microphone 的 typed prompt 才显示申请前说明或设置恢复；Request / Open settings / Not now 分别要求真实专用回调。当前没有通用权限适配器，Camera / Notifications 不可生产挂载，Microphone 仍由 Audio Room 的 Speak → Stream capture 路径负责
- I7 全局反馈组件已取消无来源的假成功、假警告与假订单状态：裸 `/preview/toast` 只显示 feedback context 未连接，不再自动声称通知偏好已保存、行情延迟或订单状态未确认。只有精确 feature 显式提供 presentation-safe `LoopGlobalFeedback` 才显示 Success / Warning / Error；Action 必须同时具备精确 label 与专用 callback，Dismiss 也使用独立 callback。当前没有全局 event bus、队列、自动消失计时或 root overlay host
- I8 Loading 组件已取消无来源的三套假加载 gallery：裸 `/preview/loading` 只显示 loading context 未连接，不再承诺内容“正在到来”或触发三个虚假 live region。只有当前 pending 状态的 owning feature 显式提供 `LoopLoadingPresentation` 才显示 list / detail / chart 中的一种静态骨架；list 占位密度运行时限制为 1–8，既不代表结果数也不证明请求已发送、内容存在或最终成功。当前没有全局 loading overlay、动画、计时、轮询或业务 loading 批量迁移
- Watchlist 已按后端现有版本化契约完成 providerless 应用逻辑：分组、资产顺序、草稿、保存单飞、显式丢弃与版本冲突恢复均在窄端口后建模。正式入口默认不可用，不发送私有请求；只有 `main_preview.dart` 注入明确标注的内存实现。Watchlist 只保存资产标识，不把价格、涨跌、可交易性或提醒状态伪装成账户事实
- Profile presentation 已按后端现有契约完成 providerless 应用逻辑：只建模 nullable Alias、opaque `avatar:` reference、版本与更新时间；编辑、丢弃、保存单飞、冲突重载、失败重试与迟到结果隔离均已落地。Bio 不属于该契约，Visibility 仍归独立 Privacy 资源，Avatar 选择在来源契约确定前禁用。正式入口默认不可用且不再伪报保存成功；只有显式 Preview 使用带标签的内存实现
- Privacy preferences 已按独立后端契约完成 providerless 应用逻辑：只建模 `discoverable` 与 `private/followers/public` copy-trade visibility 偏好，支持完整草稿替换、冲突冻结、显式重载与 owner/gateway 轮换。旧版 Portfolio Broadcast、群组白名单、活动/仓位可见性和 copy-trade 假授权表单已移除；偏好不代表发现、followers 或跟单执行已启用。正式入口默认不可用，只有显式 Preview 使用带标签的内存实现
- Notification preferences 已按后端契约完成 providerless 应用逻辑：只建模 `price_alert_triggered`、`provider_activity_projected`、`security_notice` 与 `support_update` 四项 owner intent，支持完整草稿替换、冲突冻结、重载、单飞与 owner/gateway 轮换。`delivery` 始终为 `unavailable`；旧版六分类、伪系统权限、空的设备设置动作和 Quiet hours 已移除。正式入口默认不可用，只有显式 Preview 使用带标签的内存实现；这不代表 Firebase、APNs/FCM、系统权限、Price Alert 或任何通知送达已接通
- Account、Wallet、Market、Chat、Profile 与系统状态组件
- 深色 LOOP 设计系统、键盘焦点、语义标签、reduced-motion 与手机/桌面响应式布局

所有供应商写入默认 fail-closed。正式入口 `lib/main.dart` 不注入 fixture；只有 `lib/main_preview.dart` 的显式离线 Preview 组合根注入 memory/fixture gateway。Preview 中的聊天、语音、钱包和交易状态都标注为 offline / simulated 或 `开发预览`，不代表生产登录、签名、下单、聊天或语音已经接通。

应用逻辑继续通过页面状态、Riverpod controller 和窄业务 port 隔离 provider。`lib/features/` 不直接依赖 Dio 或保存 `/v1/` 路由；旧 Perp adapter 仅作为未挂载的实现历史保留，不再继续产品开发。尚未接入的 production port 仍使用 unavailable 实现，Fake 仅允许测试与显式 Preview 注入。

Stream 生产路径必须先通过 BFF 获取或刷新短期用户 token，并由 session authorizer 建立 SDK 会话。每个 Privy principal 使用独立的 Stream client/persistence 实例，账号切换会废弃旧实例，避免不可取消的旧连接污染新账号。正式 Chat 页面直接使用 Stream 官方 controller/UI 作为消息、分页、已读、输入状态与离线历史的真相源；缺少授权时保持 fail-closed，也不会把本地 preview 伪装成在线能力。附件与语音录制会等平台权限和产品策略正式配置后再开放。

当前产品决定以 [`docs/product-decisions.md`](docs/product-decisions.md) 为准。内部不可变 `user id` 是账户与社交关系的主身份，钱包地址只是可绑定、可替换的凭证。界面只陈述可验证的安全事实及来源时间，不使用 AI Guard 或风险分口径。

## 开发入口与日常验证

```bash
bin/flutter pub get
bin/dart format --output=none --set-exit-if-changed lib test
bin/flutter analyze
bin/flutter test
```

日常功能开发不在每次中间修改后打包。需要确认原生侧能够编译时，只在功能检查点运行一次 Android Debug：

```bash
bin/flutter build apk --debug
```

Release、iOS no-codesign、Web release、`bin/flutter run`、签名和真机验证都不是日常自动检查；只有明确提出时才运行。真机结果由产品方验证，未执行时始终记录为未验证。

你提供的 Privy App ID、Mobile App Client ID 与 Stream API key 都已作为客户端安全的 Development 默认值接入。需要切换 Privy Client 时仍可显式覆盖：

```bash
bin/flutter run --dart-define=PRIVY_APP_CLIENT_ID=client-新的完整值
```

不要把 Privy Secret、Stream Secret、Firebase service-account、APNs 私钥或 Hyperliquid 私钥放进 Flutter 或 Git。

IDE 顶部 Run 可直接选择 `Loop`（正式入口）或 `Loop (Preview)`（前端体验入口），设备仍以 IDE 右下角当前选择为准，不固定 Pixel 7a。

离线 UI 目录与演示数据使用独立入口：

```bash
bin/flutter run -t lib/main_preview.dart
```

该入口会清空需要鉴权的供应商标识并显式开启 Development Preview：不会发送 OTP、连接 Stream 或发起钱包/交易操作；Chat cell、群聊/私聊和消息发送只写入进程内演示网关，并持续标注 `开发预览`。Market 是唯一例外，可读取无需身份的 Hyperliquid Testnet 公共 Spot 快照与有界 `candleSnapshot`；Preview 不会为它们提供伪实时回退。

Web release build 只在明确要求本地视觉验收时运行：

```bash
flutter build web --release
```

## 已锁定工程基线

本仓库的目的为：Build Loop, a Flutter iOS/Android app with six primary destinations—Home, Market, Launch, Chat, Wallet, and Profile—using Privy identity/wallets, Stream Chat/Video, public Hyperliquid Testnet spot discovery, and future backend-mediated spot execution.

- Flutter 3.47.1 / Dart 3.13.1
- Android API 28–36、AGP 8.13.2、Gradle 8.14、Kotlin 2.3.20、Java 17
- iOS 17+、Xcode 26.6、CocoaPods 1.16.2
- Privy 0.10.1；Stream Chat/Persistence 10.3.0；Stream Video 1.4.3（Push 1.4.3 已验证兼容但首版不链接）
- Firebase Core 4.13.0 / Messaging 16.5.0
- Riverpod 3.4.2 / go_router 17.5.0 / Dio 5.11.0
- Decimal 3.2.6 / UUID 4.6.0

`harness.json` 是可机器校验的工程画像，`AGENTS.md` 是开发与安全边界。任何依赖、原生工具链、主导航或安全边界变更都要同步更新决策和验证报告。

Manual-only native release matrix（仅在明确要求时运行）：

```bash
bin/flutter build apk --release
bin/flutter build ios --debug --no-codesign
bin/flutter build ios --release --no-codesign
```

生成的 `build/`、APK、AAB、IPA 和 `Runner.app` 不作为仓库交付物保留。需要清理时运行：

```bash
bin/flutter clean
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
- 不要恢复 Perp 产品入口、合约分栏或永续交易文案；旧实现仅作为未挂载的回归历史保留
- 不要自建钱包、撮合、桥、IM 或 RTC 基础设施；只实现已选供应商的薄适配与 LOOP 编排
- 不要启用 Hyperliquid HIP-3、builder fee 或非 Core 市场
- Pay 保留首页 `Coming soon` 入口以表达产品位置，但 A / B / C 优先级不等于交付期；B5-B8 当前全部 deferred，落地页不得出现扫码、相机、金额或支付动作

前端现已具备原生 LOOP identity bootstrap、Stream Chat 与前台 Audio Room 的主体轮换、后端 token/locator 边界、麦克风原生声明、通知意图契约和根协调器。根协调器的存在不代表通知已连接：正式入口仍使用 disabled EventSource，只有真实 session 与 bootstrap identity 同时成立时才可能处理一个有界点击。后端可并行实现 Stream Chat/Video 短期 token，以及“预创建房间 + 成员角色无 `create-call`”的 Audio Room locator 契约；双方就绪后再做真机双端联调。Firebase/Push 仍未初始化；还需要 Android/iOS Firebase 配置、精确 Stream provider name、真实 payload fixture、服务端事件 ID/过期/账号绑定契约，以及 iOS 普通推送与 VoIP 的单一路由策略。后台响铃、Camera、PushKit 与 CallKit 随后单独启用。

## 仓库结构

- `lib/`、`ios/`、`android/`、`test/`：当前 Flutter 客户端源码与测试
- `reference/legacy-prototype/`：原仓迁入的冻结 HTML 原型、产品文档、调研与历史验证脚本
- 后端的 `contracts/` 与 `server/`：已迁入 `web3-superapp/loop-api`

迁移提交保留了原仓 Git 历史；追溯旧实现时可沿合并父提交查看，日常开发只应修改 Flutter 正式源码。
