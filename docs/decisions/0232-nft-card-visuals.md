# 0232 · 项目 NFT 显示图片：NFT 卡片（S273-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 273c6b41（S265d–S270 合入后）。主代理下单 S273-mobile，方案 a（只改 App）。
依据：需求方反馈「NFT 应该展示图片吧」；`LOOP/docs/32-发射台Banner与NFT铸造页设计-2026-10-14.md` §4.1（共识勋章）、`LOOP/docs/44-主页氛围层设计稿-2026-10-21.md`（默认艺术）、`LOOP/docs/46-字体与间距规范v3-2026-10-21.md`（字阶 / 间距）、`LOOP/docs/42-附C-App视觉规范v2-2026-10-20.md`（圆角）；决策 0163 / 0212（勋章与紫环）、0217（钱包「代币 / NFT」）、0220 / 0222 / 0223（banner 默认艺术）、0229（字体与间距 v3）。
不新增依赖与素材，`pubspec.lock` 不变；不改 loop-api、路由与 OpenAPI。
追加（同日，主代理产品裁决）：项目方创建项目时上传专门的 NFT 图片；loop-api 在并行批次 S274 加 `nftImageUrl`，本单按「客户端 codec 先行」先落可选键（第 5 条）。创建流程的上传步骤（`creator/launch2_create_screen.dart`）不在本单，由另一子代理负责。

## Context

调查事实（主代理 S273 调查）：

- 合约没有 tokenURI，链上 NFT 没有图片；
- `/v2/launch2/me/positions` 每条持仓只给 `logoUrl`（可为空）和 `nft { mintedTokenId, held }`，详情给 `row.logoUrl`；
- 所以 App 能显示的「NFT 图片」只有项目 logo，没有 logo 时只能由 App 自己画。

改动前：钱包「NFT」页是 36 dp 圆形 logo + 文字行，没有 logo 时是两个字母的色块（`MemeLogo`）；共识勋章页是 152 dp 勋章、中间 56 dp logo；铸造确认弹层没有图。需求方看不出 NFT 是一张图。

## Decision

1. **`Launch2NftCard`**（`lib/features/launch2/launch2_nft_card.dart`）——一张项目 NFT 的图，三处共用：
   - 有 logo：logo 铺满卡面（`BoxFit.cover`，按 640 px 解码）；底部 45 % 黑色渐变；左下 ticker（headline 18 / 700，Chalk），右下 `#tokenId`（figure 17 / 600，Yellow）。logo 加载中或失败时，卡面是下一条的默认艺术（不带字），字照样压在底部——任何时候都不出现字母色块。
   - 没 logo：MEME banner 的默认艺术缩到正方形——墙 90 %、左上紫雾、右下黄雾、左上→右下 Ink 渐隐、右下镀铬手（静态图，不带 6 s 高光）+ 手上黄皇冠；左上大字 ticker（title1 28 / 700）、其下 `#tokenId`（figure，Yellow）。
   - 方卡圆角 16（`LoopRadius.card`，小于 120 dp 的缩略图用 10）；外圈 1.5 px 紫环 + 内缩 5 的淡紫细环，是勋章双环的方形版，保留 0163 / 0212 的勋章身份。
   - 小于 120 dp（缩略图）不画 `#id`，ticker 用 tag 字阶；有 logo 时只有图和环。
   - 卡片内没有任何动效（减少动效与否都一样）。用到的素材（墙、两团雾、黄皇冠、镀铬手）由 `launch2NftCardAssets` 列出，三处页面都经 `LoopAtmoPrecache` 在首帧前预解码。
2. **钱包「NFT」页**：36 dp 行改为两列卡片网格（`Launch2NftGrid`，横竖间距 `LoopSpacing.rowGap` = 12，页边 20；单数时最后一张占左列）。每张卡下一行 `T NFT`（body1），再一行 `×持有数 · 阶段`（caption，Text2；隐藏金额时持有数为 `****`）。点击仍打开 `Launch2Route.nft`（0163）；「来源 LOOP 链上索引 · 观察于 …」脚注、空态、未开放 / 读取失败 / 加载态不变。tap key `launch2-wallet-nft-<instanceId>` 不变。
3. **共识勋章页：图片换进勋章中心**（不做勋章上方的独立大卡）。勋章由 152 放大到 200 dp；弧形字带（上弧 ticker、下弧 `#tokenId` / 「共识勋章」）和外圈紫环 / 灰环不变，字带以内的整个圆面（直径 134）就是这张 NFT 的图（`Launch2NftCardShape.medal`：有 logo 铺满圆面，没 logo 是默认艺术 + 居中 ticker）。
   选这个的理由：① 页面上只有一个物件——勋章本身就是那张图，不会出现「上面一张方卡、下面一枚勋章」两个东西讲同一件事；② 勋章的 ticker / 编号已经在弧上，方卡的底部字压在圆里会和弧形字打架，圆面形态正好不要字；③ 0163 / 0212 的身份（正圆、紫环、弧形字、灰环表示未点亮）完整保留，钱包方卡的双紫环与之对应。
4. **铸造确认弹层**：标题下、价格上加一张 64 dp 缩略卡，让用户看到要铸的是哪张。`showLaunch2NftConfirmSheet` 新增可选 `logoUrl`，`launch2MintNft` 传 `detail.row.logoUrl`。

5. **`nftImageUrl`（可选键，客户端先行）**：`GET /v2/launch2/instances` 列表行、实例详情（`rowOptionalKeys`，详情经 `detailOptionalKeys` 继承）与 `GET /v2/launch2/me/positions` 持仓行（新 `positionOptionalKeys` = 钱包持仓键 + `nftImageUrl`）都接受可选的 `nftImageUrl`。键缺失、`null`、非字符串、空串、或不是客户端会去取的地址（与 logo 同一规则：自家 `/v2/media/{id}.webp` 或白名单 https 主机）一律读成「没有 NFT 图」，从不因此拒绝整行。模型 `Launch2InstanceRow.nftImageUrl`、`Launch2Position.nftImageUrl`。
6. **图片优先级**：`nftImageUrl` → `logoUrl` → 默认艺术卡面。`Launch2NftCard.pictureUrls` 给出顺序；前一张加载失败时换下一张，全部失败才是默认艺术；加载中始终是不带字的默认艺术。钱包网格、共识勋章中心、铸造弹层缩略卡三处同一优先级（`Launch2NftMedal.nftImageUrl`、`showLaunch2NftConfirmSheet(nftImageUrl:)`，`launch2MintNft` 传 `detail.row.nftImageUrl`）。

## Consequences

- 测试：新增 `test/s273_nft_card_test.dart`（codec 对 `nftImageUrl` 的读取与缺失 / null / 非法值容忍——列表行、详情、持仓三处；优先级顺序、先请求 NFT 图且加载中不请求 logo、NFT 图失败后回落 logo、勋章与弹层透传；有 / 无 logo 两种卡面、缩略图不画 `#id`、钱包两列网格与间距 / 两行文字 / 点开勋章页、勋章中心是图且居中 134、无 logo 勋章居中 ticker、弹层 64 缩略卡在价格之上、任何一处都没有 `MemeLogo` 和两字母）；`test/s273_shots_test.dart`（`--dart-define=LOOP_SHOTS=true` 才运行，输出 `docs/integration/S273/shots/nft-cards.png`，logo 用 App 图标代替）。
  `s259`、`s136` 中「项目 NFT #1」「× 1」行文案断言改为卡面 `#1` 与 `×1 · 提前购`；`s182` 在持有态勋章断言里加「中心是图、没有 MemeLogo」。
- `loop_ground_probe` 新增豁免 `Launch2NftArtBackdrop · DecoratedBox-[<'launch2-nft-card-scrim'>]`，理由同 0220 / 0223 的 banner 渐隐：测试里不解码墙图，Ink 渐隐落在 Ink 上不改变颜色。
- 全量 `flutter test`：5623 通过、10 跳过（新增的截图用例默认跳过）。`python3 scripts/check_harness.py` 通过；`python3 -m unittest discover -s tests` 有 1 个失败 `test_rejects_ungated_meme_tab`（变异目标 `lib/features/meme/meme_screen.dart` 的原文已不在，本单未改该文件，基线已有）。
- 真机需看：① 亮色或带字的 logo 铺满后，底部 45 % 渐变上的白色 ticker / 黄色编号是否清楚；② 横幅比例很宽 / 很窄的 logo 被 cover 裁切后是否还认得；③ 两列网格在 360 宽机型上 ticker 大字（`FittedBox` 缩放）是否过小；④ 勋章灰环（未点亮）时中心图仍是彩色——如需求方希望未点亮时图也变灰，另开一条。
- **主网待定**：外部钱包（MetaMask、OKX 等）显示 NFT 图片需要合约 `tokenURI` / `baseURI` 指向元数据（含 image），本单只解决 App 内显示。「外部钱包显示 NFT 图片需要合约 baseURI，留到主网工厂定版前拍板」。
