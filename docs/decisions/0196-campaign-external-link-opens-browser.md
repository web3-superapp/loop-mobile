# 0196 · 运营活动卡外链直接用系统浏览器打开（S216-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` 3918c5f + 0195。依据：需求方 2026-10-16 答题卡（LOOP `docs/34` 第 23 题）与群内确认。
修订 0165 §4「`url` … 默认实现 = `LoopCopy.text` 复制链接」一句与 Consequences「`url` 外链暂为复制链接」一句。
新增一个直接依赖 `url_launcher` 6.3.2；路由、字体、颜色 token、能力位不变。

## Context

0165 的活动卡 `link.kind == "url"` 时只能复制链接（toast「链接已复制，可在浏览器打开」），因为项目里没有 `url_launcher` 直接依赖。
需求方要求点按直接跳系统浏览器。0165 已把打开动作做成端口 `launch2ExternalLinkOpenerProvider`，卡片本身不需要动。

## Decision

### 1. 依赖（AGENTS.md 锁定栈规则，照 0056 share_plus 先例）
- `url_launcher: 6.3.2` 精确版本。pub.dev 当前最新为 6.3.3（2026-10-02 发布，到今天正好 14 天，处在「≥ 两周」的边上）；
  6.3.2（2025-07-10）是**已在解析图里**的版本（stream_chat_flutter 的传递依赖），选它让解析图零变化。
- `pubspec.lock`：只有 `url_launcher` 一行 `dependency: transitive` → `"direct main"`，版本、sha256 与各平台实现包（android 6.3.32 /
  ios 6.4.1 / …）不变，新增传递包 0 个。
- `ios/Podfile.lock`：本机 CocoaPods 1.14.3 `pod install` 后**无变化**——`url_launcher_ios (0.0.1)` pod 本来就在锁文件里
  （PODS、DEPENDENCIES、EXTERNAL SOURCES `:path: ".symlinks/plugins/url_launcher_ios/ios"`、SPEC CHECKSUMS `bb13df58…` 四处都有），
  TestFlight 归档所需的插件 pod 齐全。
- Android：`AndroidManifest.xml` `<queries>` 增加 `VIEW` + `BROWSABLE` + `https` intent（Android 11+ 包可见性）。
- iOS：只开 `https`，不需要 `LSApplicationQueriesSchemes`，`Info.plist` 不变。
- 登记：`docs/open-source-attribution.md`、`harness.json` 栈、`scripts/check_harness.py` `PINNED_DEPENDENCIES`、关于页开源列表
  （`about_client_register.dart`）。

### 2. 适配器与端口
- `lib/integrations/browser/system_external_browser.dart`：`LoopExternalBrowser = Future<bool> Function(Uri)`，
  `loopExternalBrowserProvider` 默认 = `launchUrl(uri, mode: LaunchMode.externalApplication)`；非 `https` / 无 host 直接 false，抛错 = false。
  只有这一个文件 import `url_launcher`。
- `launch2ExternalLinkOpenerProvider`（`launch2_campaigns.dart`）改为 `launch2OpenExternalLink(context, uri, browser:)`：
  先交给系统浏览器；返回 false 或抛错时回退为复制链接，toast「没能打开浏览器，链接已复制」。
- 只在用户点按卡片时调用：不预取、不内嵌 WebView、不读回任何结果。`launch2CampaignUrl` 的 https / host / 无 user info 校验不变（0165 §4）。
- `route` 类型（站内路径）照旧走 `onNavigate`，与浏览器无关。

## Consequences

- 活动卡外链一次点按到浏览器；没有浏览器或系统拒绝时，用户仍拿到链接，不会「点了没反应」。
- 以后其它外链（区块浏览器行等）若也要跳浏览器，复用 `loopExternalBrowserProvider`，不再新增依赖；本决策不改它们（仍是复制）。
- 依赖升级（如 6.3.3）另行按锁定栈规则处理。
- `docs/38` 不在本仓库，未改。

## Tests

`test/s184_launch2_campaigns_test.dart`（用可注入的 `loopExternalBrowserProvider` 替身，不真打开）：
- url 点按前不调用、点按后浏览器收到该地址，无复制、无回退 toast；
- 浏览器返回 false / 抛错两种情况都回退复制该链接并显示「没能打开浏览器，链接已复制」；
- 站内 route 推入 `onNavigate`，浏览器未被调用；
- 原「a url is handed to the outside-link opener」与 8 种非法 route / url 忽略的用例不变。
原生编译证据：`bin/flutter build apk --debug` 一次（见 S216 交付报告）；iOS 只跑 `pod install`，未做签名构建（AGENTS.md 第 27 条）。
