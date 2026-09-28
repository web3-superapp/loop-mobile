# 0102 · 网络诊断页（关于 → 网络诊断）

## Status

Proposed 2026-09-28。S95，客户端单侧。基线 `integration/v2` 3086bf4。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条）、`LoopDioFactory` 未改。

## Context

中国大陆不走代理的测试者需要一个能自己跑、能把结果发回来的连通性检查，用来区分「LOOP 服务不通」
和「某个第三方服务在这台设备上连不上」。

## Decision

- **入口**：设置 → 关于与法务 → 「本机构建」组末行「网络诊断」。页面是 `Navigator.push` 的子页
  （`openNetworkDiagnostics`，减弱动效时零时长转场），**不是路由**，manifest 仍 93 条。
  业务 archetype = action，布局 = dashboard。
- **探测项**（全部同时发出；每项所有步骤合计限时 8 s，整轮上限 15 s，到点仍在跑的记「超时」）：

  | 行 | 请求 | 判定 |
  | --- | --- | --- |
  | LOOP 服务 · 就绪 | `GET {LOOP_BACKEND_BASE_URL}/health/ready` | 2xx 成功，其余「已连上，但服务返回 HTTP n」 |
  | LOOP 服务 · 能力清单 | 同一连接池连续两次 `GET /v2/meta/capabilities`，记第二次耗时 | 2xx |
  | 登录服务 Privy | `GET https://auth.privy.io/api/v1/apps/{PRIVY_APP_ID}` | 任何 HTTP 响应 = 可达 |
  | 聊天服务 Stream | `GET https://chat.stream-io-api.com/` | 任何响应 |
  | 语音服务 Stream | `GET https://video.stream-io-api.com/` | 任何响应 |
  | 代币图标 | `GET raw.githubusercontent.com/trustwallet/…/smartchain/info/logo.png` | 2xx 且字节是图片签名 |
  | 推送服务 Firebase | `GET https://firebaseinstallations.googleapis.com/` | 任何响应 |
  | BSC 主网节点（仅参考） | `POST https://bsc-dataseed.bnbchain.org/` `eth_blockNumber` | 任何响应；能解析时附区块号 |
  | 网络基线 Apple | `GET https://www.apple.com/library/test/success.html` | 任何响应 |

  未配置后端 / Privy app id 时对应行为「未配置」，不发请求。
- **传输**：`lib/integrations/diagnostics/loop_network_probe.dart`。每轮每个 origin 一个
  `LoopDioFactory` 客户端（LOOP 用 `createLoopBackend` 只因开发构建可能是 loopback http；第三方用
  `createCredentialFreePublic`），不设 Authorization、不走会话/刷新/重试层、不跟随重定向，
  `validateStatus` 全收、`ResponseType.bytes`。失败映射为 超时 / 域名解析失败 / 连接被拒绝或中断 /
  安全连接握手失败 / 未发出（地址不符合本机网络规则）；传输与控制器都不向页面抛异常。
  `scripts/check_harness.py` 的 `factory_consumers` 增加这一文件，仅此一处 harness 改动。
- **页面五态**：未开始（idle）/ 探测中（loading）/ 逐行 成功·超时·失败（结果）/ 全部发出的都失败时
  顶部「所有探测都没有连上」提示（offline）/ 未配置行。没有权限态：不需要会话与系统权限。
- **导出**：「复制诊断结果」写剪贴板；「分享」走 share_plus 文本分享。文本含时间（本地时间 + 偏移）、
  App 版本、构建模式（声明 + 运行时）、服务端主机与档位、平台与系统版本、总耗时、逐行
  `[状态] 名称 (主机) 耗时 原因`。只写主机名，不写完整 URL（Privy app id 不出现），不上传。
- **文案**：页首「这个页面只测连通性和耗时，不发送账号信息。」；失败写「无法连接」「超时」，
  不使用任何评价网络环境的词。

## Consequences

- 页面显示的耗时含 DNS、TLS 与首包；「能力清单」第二次耗时反映连接复用后的单次往返。
- folio 的 stamp 组件会把文字转大写，「总耗时 1883 MS」中的单位呈大写，属既有组件行为。

## Evidence

`test/s95_network_diagnostics_test.dart`（假 `HttpClientAdapter` 驱动真实 Dio 传输）：目标清单、
未开始不发请求、9 项并行发出后全部成功、单项 8 s 超时、域名解析失败 / 连接拒绝 / LOOP 503、
全部失败提示、未配置、复制与分享文本内容、关于页入口 push。Android 模拟器 emulator-5554 截图见
S95 报告。
