# 0262 · 内测反馈悬浮入口、提交页与我的反馈

## Status

Accepted · 2026-11-02（S332-mobile）。合同见 `LOOP/docs/52-内测反馈入口与个人主页无数据-2026-11-02.md` §一、§二；后端 S332-api、后台 S332-admin 并行实现同一份合同。

## Context

需求方 2026-11-01：内测版本加一个「内测反馈」入口，图文提交 Bug，数据进后台。主代理裁决用悬浮按钮（不用 banner），只在内测包出现，不加说明文案。

## Decision

### 门控

- dart-define `LOOP_BETA_FEEDBACK`，只有 `"true"` 打开，缺省关闭：`AppConfig.betaFeedbackDefine` → `LoopFeatureSwitches.betaFeedbackVisible` → `LoopFeatureSwitchValues.betaFeedbackVisible`（测试经 `loopFeatureSwitchesProvider` 覆盖）。
- `config/debug.json`、`config/staging.json` 设 `"true"`；`config/release.example.json` 设 `"false"`，`config/README.md` 注明内测（TF / staging）的 `release.json` 要改成 `"true"`。`ops/ios-testflight.sh` 读的是本地被忽略的 `config/release.json`，那一份不在仓库里。
- 关闭时：壳里不画悬浮按钮；`/beta-feedback`、`/beta-feedback/mine` 在 redirect 里按非法路由处理（记入 routing error，回 MEME）。

### 悬浮按钮（`BetaFeedbackEntry`）

- 32 高玻璃胶囊「内测反馈」，触控目标 44 高；底色 / 描边 / 模糊直接用 tab 栏的 `loopTabBarGround` / `loopTabBarEdge` / `loopTabBarBlur`，阴影 `0x52000000` blur 12 y 4；字 `LoopType.label` Chalk。
- 位置：右缘 `max(8, 安全区右)`，与 tab 栏右缘对齐；默认胶囊底边 = `tabPageBottomReserve(90) + 安全区底 + 12`（宽屏无 tab 栏时为 `安全区底 + 12`）。
- 可在屏内任意拖（`DragStartBehavior.down`），松手横向 220 ms easeOutCubic 滑回右缘、纵向停在松手处；纵向下限是默认位置（不压 tab 栏），上限是顶栏以下。纵向高度存在 `betaFeedbackEntryLiftProvider`（会话内，不持久化）。reduced motion 下松手直接回到右缘，无动画。
- 只挂在 `LoopShell` 里（五 Tab 壳），push 出去的页面盖住它；需要开关打开且 `loopSessionProvider.canEnterProduct`；键盘弹起时让开。Semantics：button，label「内测反馈」。
- 点按时采集当时的路由（壳的 location）与设备 locale，作为 `extra` 推入 `/beta-feedback`。

### 提交页 `beta-feedback`（`/beta-feedback`，action · focus）

- 类别 `LoopSegBar`（Bug / 建议 / 其他，默认 Bug）；「描述」多行输入，必填（去空白后非空），≤ 2000 码点，计数 `n / 2000`；图片三列网格，最多 4 张，相册（`pickMultiImage(limit: 剩余)`）+ 拍照，单张可删；只读「环境」块（版本 (build)、设备、系统、页面、语言）；提交按钮。
- 流程：逐张 `POST /v2/media/feedback-images`（multipart `file`，每张一个 idempotency-key），再 `POST /v2/feedback`（`{category, body, mediaIds, context}`，一个 idempotency-key）。已上传的图在表单生命周期内记住 mediaId，重试不重传；发送结果未决（超时 / 断线）时重试复用同一个 key。成功 toast「已提交」并返回。
- 状态：无适配器整页不可用；环境读取中骨架；发送失败在表单下 `LoopErrorState`（离线 / 无权限 / 频率 / 校验 / 未决各一句）并 toast「没有提交」；相册 / 相机被拒 toast。
- 右上 `LoopIconButton`（clock，label「我的反馈」）进 `/beta-feedback/mine`。

### 我的反馈 `beta-feedback-mine`（`/beta-feedback/mine`，index · dashboard）

- `GET /v2/feedback/mine?cursor=`，卡片：类别、状态（待处理 / 已确认 / 已解决 / 暂不处理）、时间、正文前三行、缩略图 56；下拉刷新；按 cursor 自动加载下一页。
- 空态只一行「还没有提交过反馈」；加载骨架；离线 / 无权限 / 错误（可重试）/ 不可用各有块。

### 环境

- 原生平台通道 `com.cywd.loop/platform` 新增 `appInfo`：Android `MainActivity`（versionName、longVersionCode、`MANUFACTURER MODEL`、`Android x (API n)`），iOS `AppDelegate`（`CFBundleShortVersionString`、`CFBundleVersion`、`utsname.machine`、`ProcessInfo` 系统版本）。通道不答时退回 `Platform.operatingSystem(Version)` 与 `LOOP_CLIENT_VERSION`，build / 设备为空（显示「未知」）。

### 编解码

- 新路由与 API 并行落地，codec 只要求合同列出的键、忽略多出的键（如 `contractVersion`），避免 /v2 新增键打坏已发版本。`url` 接受绝对 http(s) 或 `/v2/media/…`（按后端 origin 解析）。
- 失败按状态码先判：404 / 503 → unavailable（含 `BETA_FEEDBACK_ENABLED` 关闭），429 → rateLimited，413 / 415 / 422 → validationFailed，其余走 `loopChainExceptionForV2`。

### 路由清单

- `beta-feedback`、`beta-feedback-mine` 进 `docs/product/routes-manifest.json` 的 `7-profile`（prototypeOrder 129 / 130），清单 115 → 117，sha256 重算；`route_manifest.dart`、`scripts/check_harness.py`、`test/route_manifest_test.dart` 同步。

## Consequences

- 内测包（`LOOP_BETA_FEEDBACK=true`）在五个 Tab 上都多一个悬浮胶囊；公开发布包不画、两页不可达。TF 用的本地 `config/release.json` 需要手动加这个键。
- 后端 S332-api 未部署或 `BETA_FEEDBACK_ENABLED` 关闭时，提交页与列表按 404 / 503 显示不可用，不回退任何样例数据。
- codec 对新路由宽松（忽略多余键）；合同若改键名或状态值，客户端会把那一条读成数据不完整。
- iOS / Android 平台通道多了 `appInfo` 一个方法；没有原生实现的宿主（测试、未来平台）退回 Dart 能读到的系统信息，build 与机型显示「未知」。
