# LOOP Flutter App

LOOP 的正式客户端是 **Flutter App**，目标平台为 iOS 与 Android。`web/` 仅用于本地 UI 自动化与响应式预览，不是独立网页产品，也不是生产交付目标。

正式前端仓库：<https://github.com/web3-superapp/loop-mobile>。原仓库中的 HTML 原型、调研、计划和验证脚本已迁入 [`reference/legacy-prototype/`](reference/legacy-prototype/README.md)，仅作为冻结参考，不再作为开发入口。后端契约与适配器位于 <https://github.com/web3-superapp/loop-api>。

## 当前已完成

- 六个固定主入口：Home / Market / Launch / Chat / Wallet / Profile
- 全量 103 个产品 surface 的路由目录；产品优先级独立采用 A / B / C（47 / 46 / 10），`deferred` 单独表达本期不交付
- Privy 登录、钱包与唯一签名审查边界
- Hyperliquid Core BTC / ETH / SOL 行情、订单、仓位与账户 UI
- 已选 Stream Chat + Stream Video/Audio Rooms 的薄适配边界、显式 preview / production mode、语音房五态与跨页 mini bar
- Account、Wallet、Market、Perp、Chat、Profile 与系统状态组件
- 深色 LOOP 设计系统、键盘焦点、语义标签、reduced-motion 与手机/桌面响应式布局

所有供应商写入默认 fail-closed。`communicationGatewayProvider` 默认使用未配置的 production Stream seam；只有 `main.dart` 的显式 Preview 组合根注入 memory gateway。Preview 中的聊天、语音和在线状态都标注为 offline / simulated，不代表生产登录、签名、下单、聊天或语音已经接通。

Stream 生产路径必须先通过 BFF 获取或刷新短期用户 token，并由 session authorizer 建立 SDK 会话；gateway 会在每次 bridge 操作前执行授权。缺少授权或授权失败时不会调用 bridge，也不会把本地 preview 伪装成在线能力。

当前产品决定以 [`docs/product-decisions.md`](docs/product-decisions.md) 为准。内部不可变 `user id` 是账户与社交关系的主身份，钱包地址只是可绑定、可替换的凭证。界面只陈述可验证的安全事实及来源时间，不使用 AI Guard 或风险分口径。

## 开发入口

```bash
flutter pub get
dart analyze lib test
flutter test
flutter run
```

Web release build 只用于本地视觉验收：

```bash
flutter build web --release
```

## 不要重复建设

- 不要继续扩展根目录的 HTML 原型；它只是历史交互与安全契约参考
- 不要重新搭 Flutter 路由、主题、六 Tab 壳层、页面目录或通用状态组件
- 不要新建第二套交易确认弹层；所有资金意图统一进入 F11 `SigningReviewSurface`
- 不要把 Perp 做成第七个底部 Tab；入口固定在 Market 的现货 / 合约分栏
- 不要自建钱包、撮合、桥、IM 或 RTC 基础设施；只实现已选供应商的薄适配与 LOOP 编排
- 不要启用 Hyperliquid HIP-3、builder fee 或非 Core 市场
- Pay 保留首页 `Coming soon` 入口以表达产品位置，但 A / B / C 优先级不等于交付期；B5-B8 当前全部 deferred，落地页不得出现扫码、相机、金额或支付动作

下一阶段应集中在真实 Privy、Hyperliquid、Stream、BFF、推送与行情数据接入，以及 testnet / 真机验证，而不是重复 UI 基础工程。

## 仓库结构

- `lib/`、`ios/`、`android/`、`test/`：当前 Flutter 客户端源码与测试
- `reference/legacy-prototype/`：原仓迁入的冻结 HTML 原型、产品文档、调研与历史验证脚本
- 后端的 `contracts/` 与 `server/`：已迁入 `web3-superapp/loop-api`

迁移提交保留了原仓 Git 历史；追溯旧实现时可沿合并父提交查看，日常开发只应修改 Flutter 正式源码。
