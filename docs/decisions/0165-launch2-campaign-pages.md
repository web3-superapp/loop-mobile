# 0165 · 发射台账本分页接入后台「运营活动卡」（S184-mobile）

## Status

Accepted 2026-10-14。基线 `integration/v2` e72fc43（0164 之上）。接 loop-api S183 的 `GET /v2/launch2/campaigns`
（后台配置、发布的活动卡）。不新增依赖、不新增字体与颜色 token、路由数不变（113）；新增一条只读请求路径。

## Context

0164 给账本卡做了分页并为运营活动预留了页模型（`Launch2DeskCampaignPage`）与渲染桩，但没有数据。S183 后端已定契约：

```
GET /v2/launch2/campaigns → { items: [{ campaignId, title, subtitle|null, coverUrl|null, startsAt, endsAt,
  ctaLabel, link: { kind: "route"|"url", value }, pinned, sortOrder, state: "live"|"upcoming" }],
  observedAt, contractVersion }
```

最多 10 条，服务端已按 pinned → sortOrder → startsAt 排好，只给已发布、未结束、7 天内开始的。
设计参考：方案 A 定稿版第 3 页（低饱和账本卡 `ledger-quiet` + 右侧封面 + kicker「活动 · 10-15 → 10-22」+ 标题 + 一句副标题 + 印章）。

## Decision

### 1. 数据层
- 端口 `Launch2CampaignsGateway`（`lib/features/launch2/launch2_campaigns.dart`），默认 `UnavailableLaunch2CampaignsGateway`；
  `main.dart` 挂 `loopV2Launch2CampaignsGatewayProvider`（Dio / 客户端元数据 / 会话缺一即 unavailable）。
- Codec `LoopV2Launch2CampaignsCodec`（`loop_v2_launch2_campaigns_api.dart`），宽松同 overview：
  根不是对象或 `items` 不是数组 = 失败；单条读不懂（缺字段、类型错、未知 `state` / `link.kind`、`endsAt ≤ startsAt`、
  标题空或 > 48 字、副标题 > 120 字、重复 id）整条丢弃；副标题空白 = 无；`ctaLabel` 空 / 缺 / > 16 字 = 「查看」；
  `coverUrl` 走 launch2 图片同一套接受规则（LOOP 媒体地址或 logo 白名单），不接受 = 无封面（条目保留）；最多读 10 条；
  `observedAt` 读不懂 = 无。
- `Launch2CampaignsController`（`LoopChainReadController`，`retainsAnswer: false`）没有自己的计时器：
  和 overview 一样随列表首读加载，随 60 s 轮询、从项目页返回、下拉刷新一起 `reload()`（`_refreshOverview` 一并刷新两者）。
  404 / 503 / 解码失败 → 状态无值 → 不画活动页，页面其它块不受影响。

### 2. 页序（`launch2DeskPages(hero, campaigns:, now:)`）
1. 进行中的事件（`launch2HeroRows` 中非 `upcoming` 的行：铸造中 / 提前购 / 内盘冲刺）
2. `pinned` 活动
3. 预告（`upcoming` 行）
4. 其余进行中的活动（`startsAt ≤ now < endsAt`）
5. 未开始的活动

活动先过滤：`endsAt ≤ now` 不进；`startsAt > now + 7 天` 不进（置顶也不进）。每步内保持服务端顺序。总数 ≤ 5（`launch2DeskPageLimit`），超出截断。
「进行中 / 未开始」按本地时钟（`launch2ClockProvider`）判断，`state` 只是服务端读数时的状态。

### 3. 活动页 `Launch2DeskCampaignCard`
- `LoopFolioPrimary(variant: quiet, archetype: listing, ring: false)`：与铸造页顶部同款低饱和 ledger。
- kicker `活动 · MM-dd → MM-dd`（本地日历）；heading = title（`headingMaxLines: 2`，省略号）；caption = subtitle（无则不画，最多两行）；
  caption 下方小文字按钮 = `ctaLabel` + chevron（lime eyebrow 11，默认「查看」）。
- stamp：进行中「剩 N 天」（N = 剩余整天数），不足 1 天「今天结束」；未开始「MM-dd 开始」。
- 封面：`coverUrl` 非空时在卡右侧画 112 dp 宽、满高的竖条（`.desk-cover`），`BoxFit.cover` 居中等比裁切，
  左侧 1 px lime 20 % 描边分隔；文字右内边距 122（原型 `.desk-campaign{padding-right:122px}`）。
  图片走 `loopRemoteImageSource(url)`（= `LoopMediaImage` 磁盘缓存 + 下载，与头像 / MemeLogo 同一套；按原尺寸解码，
  不套头像的 256 方形 ResizeImage，避免竖条糊）。加载中竖条是 card2 底；读取失败下一帧去掉竖条，文字占满整卡，不再重试同一地址。
- 整卡一个点击（`LoopPressable`），按钮文字是视觉提示，点它与点卡同效。分页点在活动卡上用 lime（实心 / 30 %），事件卡仍 ink。

### 4. 点击分发 `launch2OpenCampaign`
- `route`：只接受以单个 `/` 开头、无 scheme / authority、无空白与反斜杠的站内路径，交给列表的 `onNavigate`（= MEME Tab 的 `context.push`）；
  否则忽略并 `debugPrint` 一行日志。
- `url`：只接受 `https`、有 host、无 user info；交给 `launch2ExternalLinkOpenerProvider`。项目里没有应用内浏览器，
  `url_launcher` 只是 stream_chat 的传递依赖、不在直接依赖里（按 AGENTS.md 新增直接依赖需两端原生构建与单独决策）；
  外部地址在项目里一贯的处理是复制（区块浏览器行），所以默认实现 = `LoopCopy.text` 复制链接并 toast「链接已复制，可在浏览器打开」。
  **已由 0196 修订**：默认实现改为 `url_launcher` 系统浏览器打开，失败回退复制并 toast「没能打开浏览器，链接已复制」。
  端口可在以后换成真正的外部打开，不动卡片。

### 5. 公共部件改动
- `LoopFolioPrimary` 新增可选 `aside` / `asideWidth`（默认 112）/ `headingMaxLines` / `captionMaxLines` / `footer`；
  全部缺省时像素不变（stamp 仍 right 14）。有 `aside` 时文字区右边距 = asideWidth + 10，stamp 落在文字区右下（right = 118），不压在封面上。
- `loop_remote_avatar.dart` 新增 `loopRemoteImageSource(url)`（头像本身改用它，行为不变），让非头像图片也能用测试替身。

## Consequences
- 发射台账本分页从此有两类页：事件页（0164）与活动页（本决策），页序与 ≤5 的上限由 `launch2DeskPages` 一处决定；后台改活动不需要发版。
- 活动接口不可用、返回坏数据或为空时，分页退回 0164 的纯事件页，列表其它块不受影响；没有新的失败面。
- `url` 外链暂为复制链接，真正打开浏览器需要新增直接依赖与原生构建，另立决策（见 docs/34 第 23 题）。**已由 0196 落地**：点按直接跳系统浏览器。
- `LoopFolioPrimary` 多了 `aside` 等可选参数，其它调用方像素不变；活动卡成为今后「封面 + 文字」账本卡的唯一写法。

## 与方案 A 参考图的差异
- 参考图的印章 `剩 6D` 叠在封面右下；这里印章放在文字区右下，避免压图失读。文字为「剩 6 天」（中文，按 S184 任务定）。
- 参考图没有按钮文字；按任务加 `ctaLabel` 小按钮于副标题下。
- 副标题最多两行（文字区在 360 dp 下约 106 dp 宽，参考图同样窄）。
- 列表本身为空（无任何 v2 项目）时仍是空态插画，不画账本卡，因此也不画活动页。

## 测试
`test/s184_launch2_campaigns_test.dart`（25 例）：解码（全字段 / 可空字段与默认按钮文字 / 不接受的封面 / 11 种坏条目与重复 id 丢弃 /
最多 10 条 / 根错误 = 失败 / 默认端口 unavailable）；页序（五段顺序、置顶在预告前、置顶的未开始活动、> 7 天不进（含置顶）、已结束不进、截断 5）；
活动卡（quiet、kicker、两行标题、副标题、「剩 N 天」/「今天结束」/「MM-dd 开始」、无副标题、无封面、封面竖条 112 宽满高且文字不进竖条、
封面读取失败回退、活动卡 lime 分页点）；点击（route 推入、按钮同效、url 交给外链端口、8 种非法 route / url 忽略、默认端口复制链接）；
列表（活动接口 503 时账本卡 / 计数 / 进度卡照常且无活动页；活动随首读加入分页、> 7 天的不出现、下拉刷新再读；默认端口不画活动）；
360 dp 长标题 + 长副标题 + 封面 + 印章在 textScale 1 与 1.3 下无溢出。
`test/s182_launch2_desk_nft_test.dart` 的页模型与活动桩两例改为新模型（quiet、`Launch2CampaignLink`）。
