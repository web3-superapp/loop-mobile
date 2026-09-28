# 0104 · 复制、分享与粘贴 LOOP ID

## Status

Proposed 2026-09-28。S97，客户端单侧。基线 `integration/v2` e10a529。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条，没有新增 GoRoute）。

## Decision

- **我的**：身份卡 LOOP ID 下方两个次级按钮「复制」「分享」（Chalk 卡上的描边款，编辑资料仍是唯一
  Ink 主按钮；44px；语义标签「复制 LOOP ID LOOP-…」「分享我的 LOOP ID」）。LOOP ID 读不到时两个都不画。
  - 复制：剪贴板只放纯 ID，Toast「已复制 LOOP ID」。
  - 分享：share_plus 文本，`在 LOOP 上加我为好友：LOOP-XXXXXXXX` + 换行 +
    `{LOOP_BACKEND_BASE_URL 的 scheme+host}/u/LOOP-XXXXXXXX`；未配置后端时只分享第一行。
    面板打不开时 Toast「无法打开分享，可以改用复制」。
- **公开资料卡**（他人）：有 LOOP ID 时多一个「复制 LOOP ID」块按钮，复制后卡片不关闭。不提供分享。
- **添加好友 = `search` 页**：搜索框右侧「粘贴」。只在点按时读一次剪贴板，用
  `(?<![0-9A-Za-z])LOOP-[0-9A-Za-z]{8}(?![0-9A-Za-z])`（不分大小写）取第一个 ID 并转大写，填入输入框，
  直接在「用户」域搜索；其余剪贴板文字不进入输入框也不发请求。没有 ID 时 Toast「剪贴板里没有 LOOP ID」。
  5 位邀请码 `LOOP-XXXXC` 不会被误认。
- **`/u/{loopId}` 链接**：不是路由。顶层 redirect 识别 `/u/<ID>`（宽松匹配，转大写）后改写为
  `/search?q=LOOP-…`，`search` 页收到 LOOP ID 形式的 `q` 时先查「用户」域。登录前或启动页期间到达的链接
  存进 `LoopProfileLinkInbox`；账号照常落 `community`（登录落点红线与 harness 断言不变），落地后再把
  search 页 push 到上面，返回回到社区。格式不对的 `/u/...` 按未知路由记错并回社区。
  - Android：`flutter_deeplinking_enabled` 仍为 false（Reown）。`MainActivity` 只把 https `/u/<id>`
    交给 Flutter：冷启动经 `getInitialRoute`，运行中经 `onNewIntent` → `pushRouteInformation`。
    manifest 为 `api-dev` / `api-staging` 两个 host 加 `autoVerify` intent-filter（`pathPrefix=/u/`）。
  - iOS：Flutter 默认深链处理开启（Info.plist 未设 `FlutterDeepLinkingEnabled`），entitlements 加
    `applinks:api-dev.quant-dinger.cc`、`applinks:api-staging.quant-dinger.cc`。
- 不做二维码：本单只做文本，仓库虽有自研 `LoopQrCode` 编码器，但没有扫码能力，另议。

## 服务端需要放的文件（本单不含）

- `https://<host>/.well-known/apple-app-site-association`（`application/json`，无扩展名，不重定向）：
  `{"applinks":{"details":[{"appIDs":["867CN6U7W9.com.cywd.loop"],"components":[{"/":"/u/*"}]}]}}`
- `https://<host>/.well-known/assetlinks.json`：
  `[{"relation":["delegate_permission/common.handle_all_urls"],"target":{"namespace":"android_app","package_name":"com.cywd.loop","sha256_cert_fingerprints":["<签名证书 SHA-256>"]}}]`
  本机 debug keystore 为 `AE:60:82:E6:21:F5:9D:3E:63:96:F8:CB:4B:8D:86:28:7C:F6:2B:29:06:D5:2C:2E:5D:8E:A7:D4:DB:5E:3E:FA`；
  release 签名尚未配置，到时追加。
- `/u/{loopId}` 的网页落地页（未装 App 时）。

## Consequences

- 后端 `users` 域目前只按别名前缀匹配（`loop-api` `searchUsers` 只比 `alias_search_key`），不匹配
  `loop_id`，且排除自己。所以粘贴/链接进来的 ID 现在都会是「没有匹配的结果」，直到后端加 LOOP ID 精确匹配。
- 新增 host 要同时改 AndroidManifest 与 entitlements，并在该 host 放上面两个文件。

## Evidence

`test/s97_share_loop_id_test.dart`（18 项）：文本规则（前后文字、小写、邀请码、无匹配、链接路径）、
复制文本与 Toast、分享文本、分享失败、无 ID 不画、公开资料复制、粘贴四种剪贴板、initialQuery 走用户域、
运行中链接、登录前链接落社区后 push、畸形链接。模拟器截图 `/private/tmp/s97/`。
