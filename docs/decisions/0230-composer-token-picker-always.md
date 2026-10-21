# 0230 · 发帖弹层「关联代币」选择器常驻（S270-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` 8aee1515。依据：用户 2026-10-21 19:51 真机截图，广场 → 动态 → 发帖，
弹层只有「内容」、0/500、「发布」，没有任何代币胶囊。只改 loop-mobile；不加接口、不改 theme、不改 lockfile、route manifest 不变。

## Context

- `SquareFeedComposer` 的「引用代币（可不选）」一段只在 `squareRecentTokensProvider` 非空时渲染；该 provider 只记录
  本次运行里打开过的 MEME 代币（内存、最多 8 个、不落盘）。新开 App 直接发帖 → 整段消失，用户不知道可以关联代币。
- 服务端 `POST /v2/square/posts` 的 `tokenRef` 接受 `{kind: meme, id: memeTokenId}` 与 `{kind: launch2, id: instanceId}`，
  只校验存在性（`tokenRefExists`）；任何已列出的 launch2 instance 都可引用。

## Decision

- 选择器常驻，标题改「关联代币（可不选）」。候选按序合并去重（`squareComposerTokenOptions`，key = kind + id）：
  ① 本次打开过的代币（原 provider）；② 我的 MEME v2 持仓（`launch2PositionsControllerProvider`，与钱包同一判定：
  memeBalance > 0，或旧服务端无 holding 时 curve.net > 0，或持有项目 NFT）；③ MEME Tab 已有的 v2 列表
  （`launch2ListControllerProvider(Launch2ListScope.all)`，已加载的各页，排除 `closed_no_holders`）。②③ 只在
  `launch2SurfaceVisible && !launch2ReadsBlocked` 时读取，复用现有 provider 与 `launch2LoadOnce`，不新加接口、不翻页。
- 胶囊行：「不带代币」+ 前 8 个候选 +「更多 N」（展开全部）+「搜索代币」。搜索是本地过滤（ticker 或名称，忽略大小写），
  只在已加载数据里搜；无匹配显示「没有匹配的代币」。已选代币即使被截断或搜索过滤也固定显示在行首，保持选中态。
- 候选全空：首次读取中显示「正在读取代币…」，否则「暂时读不到代币，稍后再试」；整段不再消失，发帖不受影响。
- `SquareFeedTokenRef` 与 post 的 `tokenRef` 协议不变；launch2 候选的 id 是 `instanceId`。

## Consequences

- 新测试 `test/s270_composer_token_picker_test.dart`：新会话（recent 空）从项目列表出胶囊；顺序 recent → 持仓 → 列表、
  去重、8 个 +「更多 4」；搜索按 ticker / 名称过滤、无匹配提示、选中态跨搜索保留；选中 → `createPost` 带 launch2 `tokenRef`；
  「不带代币」不带；候选全空与 MEME v2 关闭时显示提示。旧测试 `s187_4_square_feed_test.dart` 无需修改。
- 打开发帖弹层会在 MEME v2 可用时触发一次 v2 列表首页与 `me/positions` 读取（若 MEME Tab / 钱包未曾读过）。
- 胶囊只显示 ticker，不画 logo（`LoopSeg` 只有文字 + sprite glyph）；如需 logo 胶囊另起批次。
- MEME v1（经典）代币只经 ① 进入候选；v1 列表未接入（经典发射已隐藏，决策 0195）。
