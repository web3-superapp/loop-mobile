# 0235 · 扫码识别邀请链接；我的邀请重排（S277-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 1274db1c（S276 合入后）。主代理下单 S277-mobile，对应需求方 2026-10-22 验收反馈第 06、07 条。
不新增依赖，`pubspec.lock` 不变；路由清单不变（邀请码填写页仍是 slug `referral`，`/profile/referral?code=`）；不改 loop-api；不新增、不改全局设计 Token。

## Context

- 第 06 条（bug）：扫一扫扫邀请海报二维码（`https://api-staging.quant-dinger.cc/i/LOOP-1ZR9N`）提示「不是 LOOP 二维码」。`loopScanResultFor` 的 http(s) 分支只认 `/u/`、`/c/{id}/room`、`/c/{id}`，没有调用 0214 已有的 `inviteCodeFromLinkPath`。另外，海报二维码下印的裸 `LOOP-XXXXX`（5 位邀请码）也不被识别——已识别的裸 `LOOP-XXXXXXXX` 是 8 位 LOOP ID，不是邀请码。
- 第 07 条：「邀请链接和复制按钮的布局较乱，邀请码、分享操作及各数据模块划分不清晰。模块底图颜色太深看不出模块的区分。邀请链接单排展示，复制直接做成 icon。」原布局：邀请码卡（Graphite `card`，与 Ink 页几乎同色）+ 两个整行按钮（复制邀请码 / 生成海报）+ 「邀请链接」行（链接折两行 + 文字「复制」）+ 整行「分享邀请链接」按钮 + 三格统计（无底）。

## Decision

1. **扫码识别邀请。** `scan_result.dart` 新增 `LoopScanInvite(code)`（`location = referralClaimLocation(code)`）。http(s) 分支在 `/u/`、`/c/…/room`、`/c/` 之后、兜底之前识别 `/i/<code>`（规则即 `inviteCodeFromLinkPath`：大小写、`LOOP-` 可省、Crockford `I/L→1`、`O→0`、允许一个尾斜杠，query 忽略）。非 http 文本：完整的 `LOOP-` + 5 位（整串、不含其它字）也识别为邀请码；裸 5 位不认（太容易撞别的内容）。非法 code 一律 `LoopScanUnknown`。
2. **扫到邀请码先确认、不直接跳。** 扫码页底部面板显示「LOOP 邀请码 LOOP-1ZR9N」+ 一句「在填写页确认后才会绑定，绑定后不能更换。」，按钮「继续扫描」/「去填写邀请码」（主按钮）。点主按钮才 `onOpen('/profile/referral?code=…')`，进入邀请中心后按 0214 已有逻辑：可绑定则绑定表单预填，已绑定则 Toast 说明不再绑定。面板显示期间其它帧的码不处理。「发送页扫收款地址」模式（`returnsRecipient`）下邀请码与其它非地址一样按文本显示，不跳转。取景提示改为「对准 LOOP 名片、邀请海报、社区二维码或钱包地址二维码。」
3. **我的邀请分三块。** 情报「邀请中心」卡与邀请中心页共用：
   - 邀请码块（情报卡）：`我的邀请码` 小字 + 邀请码大字（Yellow keyFigure）+ 右侧复制 icon（`copy`，Toast「邀请码已复制」）+ 一行说明。邀请中心页的邀请码仍在 hero 里（含五级带），复制 icon 放在大字右侧。原「复制邀请码」整行按钮删除。
   - 邀请链接块：头行「邀请链接」小字 + 右侧「生成海报」小胶囊（`LoopPillAction` soft，LimeSoft 底 Yellow 字，44 触控）；下一行链接**单行**（`maxLines: 1`、`softWrap: false`），屏幕上去掉 `https://`，放不下时**中间省略**（保留开头的域名和结尾的邀请码，尾部多留），右侧复制 icon、分享 icon（`share`，调系统分享，文案沿用 `referralInviteText`）。复制 / 分享仍是完整链接。无链接时块内显示原「邀请链接还没有开放…」，生成海报照常（只有邀请码）。原「分享邀请链接」整行按钮删除。
   - 数据块：三格等宽一行（直接邀请 / 有效成员 / 二至五级），标题小字在上、数字（statFigure）在下，格间 1px `line` 竖线。截止说明一行在块外下方；「打开邀请中心」行保持。
4. **分块底色只用现有 Token。** 三块统一 `LoopColors.card2`（#1C1B22，现有「亮一级」的 elevated 面）+ 1px `LoopColors.line` 描边 + `LoopRadius.card`；左右边距 `LoopSpacing.page`，块间 `LoopSpacing.rowGap`（12）。没有新增或修改任何全局 Token。

## Consequences

- 测试：`test/s109b_qr_scan_manage_test.dart` 新增 3 例（https 邀请链接 / 带 query 与尾斜杠 / http / 裸 `LOOP-XXXXX` 识别为邀请；9 种非法形态走 unknown；页面上显示「LOOP 邀请码 LOOP-1ZR9N」、面板期间不处理别的码、继续扫描、去填写邀请码打开 `/profile/referral?code=LOOP-1ZR9N`）。`test/s239_referral_center_test.dart` 新增「我的邀请 · layout」3 例（复制 icon 在邀请码块内且是 `LoopIconButton`、点按复制邀请码；链接 `maxLines 1` / `softWrap false` / 结尾是邀请码 / 单行高度；复制 icon 与链接同行并复制完整链接；分享 icon 调系统分享并带文案与主题；三块均为 card2 底；三格同一行、标题在数字上方；块间 12；无链接时海报仍在、无复制 / 分享）。`test/s7_referral_test.dart` 两例随布局更新（复制控件改为 `LoopIconButton`；链接断言改为单行并以邀请码结尾）。
- 截图：`test/s277_shots_test.dart`（仅 `--dart-define=LOOP_SHOTS=true` 运行）输出到 `docs/integration/S277/shots/`：`intel-referral-center.png`（情报卡）、`referral-page.png`（邀请中心页顶部）、`referral-page-no-link.png`（链接未开放）。
- 中间省略在构建时按当前字体测量；内置字体在首帧前已注册，真机无影响。测试字体（Ahem）下省略得更多，测试只断言单行与结尾邀请码。
- 真机需确认：扫邀请海报 → 面板 → 去填写邀请码 → 绑定表单预填；分享 icon 拉起系统分享面板；小屏（320 宽）链接省略后仍能看到邀请码。
