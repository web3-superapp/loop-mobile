# 0178 · 全局搜索页改为设计稿「搜索」版式（S187-6-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 5055f92（含 0166 ~ 0174、0179）。来源：主仓库
`docs/35-代币列表与代币页设计稿-2026-10-15.md` 与 `body2.html`「搜索」手机框（HTML 结构即规格）、
`docs/33-全App对照原型一致性走查-2026-10-15.md` §1 家族五条。只改 `/search` 的版式、分段与「最近搜索」：
路由（数量不变）、请求路径、`SearchGateway` 端口、结果的 `destination.kind` 导航、签名出口不变；不新增依赖、字体与颜色 token。
后端 `GET /v2/search`（loop-api `routes/v2/search.ts`）只读：域 = `users / communities / assets / launch / dapps`，
结果字段 = `resultType / stableId / displaySnapshot{title, subtitle, avatarRef, logo, memberCount, verificationStatus} / destination`。

## Context

旧页顶部是搜索框 + 「粘贴」按钮 + 一行范围说明 + 三个 quiet 分段（资产 / 社区 / 用户，0170 M14），结果是一组 `LoopRecordRow`，
没有「全部」、没有最近搜索，域不可用时用的是 v1 `LoopEmpty`（0172 白名单项）。设计稿照 fomo：顶部一排分段（全部为 `.seg.on`）、
「最近搜索」横滑卡、结果行（44 tile logo + ticker + 类型徽标 + 市值 / 价格 + 涨跌）、底部固定胶囊输入条 + 「粘贴」。

## Decision

### 1. 分段（`.filters`）
- 顺序 全部 / 代币 / 社区 / 用户（key `search-seg-all` / `search-seg-assets` / `-communities` / `-users`，后三个 key 不变）。
  选中的那个是 `LoopSeg`（非 quiet）= 满 lime 的 `.seg.on`，其余 `LoopSeg(quiet)`；同屏唯一满 lime。
- `SearchDomain.assets.label` 「资产」→「代币」，`searchFieldLabel` 随之为「搜索代币、社区、用户」。
- **算力榜不画**：后端 search 没有这个域。Launch / DApp 仍由 `searchOutboundDomainsVisible`（0121）控制，默认不画。
- 页面默认「全部」。服务端没有 `all` 域：`SearchController` 新增 `SearchState.all`，`_fetchAll` 对三个可搜域各取第一页
  （`Future.wait`，按分段顺序发出）。结果按 代币 / 社区 / 用户 分节（`search-section-{domain}`，flat 下 `LoopLabel(tight)`）；
  某域第一页带 `nextCursor` 时节标题右侧 lime「更多」（`search-more-{domain}`）切到该域分页；全部模式不翻页。
  某域拒绝而别的域有回答时，拒绝单独一行 `LoopInlineUnavailable`（`search-domain-failed-{domain}`），不并进「没有结果」；
  三域都拒绝时页面用第一个拒绝的失败态（限流 / 离线 / 错误），三域都 `unavailable` 时为不可用态。
- 单域模式行为不变（含 0121 的「提交后落到有结果的域」与「手选的域不被推翻」）。LOOP ID 查询（粘贴、`/u/` 链接）仍直接问「用户」。

### 2. 最近搜索（`.label-row` + `.recent`）
- 打开一条结果（结果行或最近搜索项）即记录到最前；去重按 `type + stableId`；最多 10 条。
- `LoopLabel('最近搜索')` + 右侧 lime 文字「清除全部」（`search-recent-clear`，≥44 触控）。
- 用户 / 社区 = 横滑 `LoopRecordCard`（新增 `margin` 参数，缺省等于原 16 / 0 / 16 / card，其它调用方像素不变），150 宽，
  头像 56（用户 `LoopProfileAvatar`，社区 `CommunityLogo`）、名字 14 / 700、底部 `LoopPillAction(soft)`：
  用户「关注」→ `SocialGateway.setFollowing(following: true)`，以服务端 `viewerFollows` 为准变「已关注」（本次运行内存）；
  社区「进入」→ 打开社区。右上 × 单个删除（`search-recent-remove-{type}-{id}`，44 方块）。
- 代币 = `LoopPersonRow` 行（44 tile logo + ticker + `LoopBadge('代币')`），行尾 ×；**× 只出现在最近搜索区**。
- **「成员数 · 收益」一行不画**：最近搜索只存 id + 类型 + 显示名（清单要求），存下来的成员数会被当成现值；搜索结果也没有收益字段。
- 持久化：`SearchRecentStore` 端口（`features/community/search_recent.dart`）+ `SharedPreferencesSearchRecentStore`
  （`integrations/personalization/`，`SharedPreferencesAsync`，唯一 key `loop.search.v1.recent`，值为 `[{t, id, n}]` JSON），
  读写 1 秒超时 fail-open，写按顺序串行；解码容错（坏 JSON = 空、未知类型 / 超长字段丢该条、去重、截 10 条）。
  缺省 provider 是 `RunLocalSearchRecentStore`（只在本次运行），只有 `lib/main.dart` 覆盖为设备存储；`main_preview` 不覆盖。
- **预览不混入生产**：只有 `CommunityGatewayMode.production` 的结果才读写存储；Preview 模式既不读已存条目也不写入，只在本次运行保留。
- 它是安装级便利数据，不是账户资源（AGENTS 23 已补一句）。`check_harness.py` 的 SharedPreferences 导入白名单加第三个文件，
  新增 `check_search_recent_store_contract`（导入只三条、只调 getString / setString / remove、恰一个 `SharedPreferencesAsync()`、
  恰一个 key、带 `.timeout(_budget)`、`main.dart` 覆盖、测试标记）。

### 3. 结果行（`.row`）
- 代币：`LoopPersonRow`（key `search-result-{stableId}` 不变）+ `LoopTokenLogo` 44（新增可选 `cornerRadius`，传 `LoopRadius.tileValue` =
  15 的圆角方块；缺省 `null` 仍是圆形，其它调用方像素不变；保留注册表图 → 内置图 → 字母的回退链）+ ticker + `LoopBadge('代币')`（mute）+ 副标题（代币名）。
- **价格 / 涨跌 / 市值不画数字**：搜索快照没有这些字段。右侧写「搜索不含价格」（`search-result-price-{id}`，captionSm text3），
  不写 0、不写破折号（AGENTS 25）。没有为每行另起行情请求：那会让一次搜索变成 N 次 `GET /v2/market/assets/{id}`。
- 社区 / 用户：`LoopPersonRow`。社区副标题只在服务端给了 `memberCount` 时写「N 位成员」（不再显示 slug），用户副标题为服务端 subtitle；两者带 chevron。
- 页面包 `LoopFlat`（0170：OKX 行页面必须是 flat）。

### 4. 底部输入条（`.searchbar`）
- 去掉顶部搜索框，顶栏只留标题「搜索」与返回。输入条在列表下方（`search-bar`，ink 底、line 上边线），随 Scaffold
  `resizeToAvoidBottomInset` 被键盘顶起。0121 的范围说明行（`search-scope-hint`）移到输入框正上方。
- 胶囊输入框（`search-field`，card2 填充、`LoopRadius.pill`、无边框），左侧搜索字形即提交键（`search-submit`）。
  提示文字为「搜索代币、社区、用户…」而不是设计稿的「搜索任何内容…」：2026-09-23 走查（a55–a65）已裁定输入框只承诺有后端的域。
- 右侧 `LoopSeg`「粘贴」（key `search-paste-loop-id` 不变）：剪贴板里有 LOOP ID → 只取 ID 问「用户」（0104 不变）；
  否则若是一行 2–40 字的文本 → 填入并按当前分段搜索；多行 / 过长 / 为空 → toast「剪贴板里没有可以搜索的内容」，不发请求。

### 5. 状态
- 空态 / 失败态沿用 `CommunityStateBlock` + `LoopEmptyState(search)`；单域不可用改为 `LoopInlineUnavailable`
  （`search-domain-unavailable-{domain}`，detail = `communityUnavailableReason`，3 行），`search_screen.dart` 不再用 `LoopEmpty`，
  已从 `FEATURE_LEGACY_WIDGET_ALLOWLIST` 删除（白名单只缩）。
- 搜索 capability 不可用时整页 block 不变（也不显示输入条）。

## Consequences

- 首屏：分段 → 最近搜索（无则空态插图）→ 底部输入条；输入后分节列出三域结果。
- 「全部」一次查询发三个请求（旧页提交后的「落域」最多也是三个）；`users` 域仍走共享公开搜索配额。
- 最近搜索按设备保存，不按账户分区：同一台设备换账号会看到上一个账号打开过的名字（清单规定为设备本地、非账户资源）。
- 可见变化（均待主代理真机验收）：顶部搜索框没了、输入在底部；分段多了「全部」、选中为满 lime；「资产」改名「代币」；
  结果行变 OKX 人物行、代币 logo 变 r15 方块、右侧「搜索不含价格」；社区行副标题「N 位成员」；最近搜索卡与行。

### 未按清单做的点
- 算力榜分段：后端 search 无此域，不画（清单允许）。
- 最近搜索卡「成员数 · 收益」：只存 id + 类型 + 名字，且搜索无收益字段，只画名字（清单允许）。
- 代币行「市值 $44.1K」、价格 mono 13、涨跌：搜索快照无这些字段，写来源原因（清单允许）。
- 输入框提示：用「搜索代币、社区、用户…」而非「搜索任何内容…」（见 §4）。
- 「粘贴」是非 quiet 的 `LoopSeg`（`LoopRadius.button` 圆角矩形），不是设计稿的全圆胶囊：`LoopSeg` 非 quiet 没有全圆形态，未新增变体。
- 「关注」不预知是否已关注：最近搜索不存关注状态；点了以服务端回答为准。

## Verification

- `bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`、search / community 相关 `bin/flutter test`（结果见提交说明）。
- 新增 `test/s187_6_search_layout_test.dart`：分段顺序与横向位置、无算力榜、同屏只有选中分段一个满 lime（切到代币后仍是一个）；
  全部模式三域按序请求、分节顺序、「更多」进单域；打开结果记录 / × 单删 / 清除全部及存储写入；重启后从存储读回、卡宽 150、
  头像 56、卡上无数字、「关注」soft 且走 `setFollowing` 后变「已关注」；Preview 结果不写存储、不读已存条目；
  存储 key、10 条上限、只存三字段、坏 JSON / 未知类型、抛错与 1 秒超时 fail-open；代币行 tile 44 r15、mute「代币」徽标、
  「搜索不含价格」且无 0 / 破折号、结果行无 ×；输入条在底部、键盘 300 弹起时上移、提示文字、粘贴在输入框右侧；粘贴普通文本填入并搜索全部。
- 改写：`s121a`（分段与范围行位置）、`s26`（hintText、「128 位成员」）、`s97`（粘贴语义名、普通文本被搜索、多行不发请求）、
  `community_social_pages_test`（全部三域请求、hintText、手选域不被推翻的请求序列）。
- 未起模拟器、未做真机验收。
