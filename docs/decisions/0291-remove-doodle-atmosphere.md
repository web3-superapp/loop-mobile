# 0291 · 去掉全局涂鸦氛围背景（S367-mobile）

## Status

Accepted · 2026-11-05（S367-mobile）。基线 `integration/v2` 3c1be4c1。依据：需求方 11-05 TF 66 真机验收第 5 条「App 不要那个涂鸦背景了，感觉不好」（`LOOP/docs/62-需求方验收九条-2026-11-05.md`）。
作废 0220 第 2 / 3 条（墙、标题后皇冠）、0221 第 3 / 4 / 9 条里的墙、雾与预解码、0222 第 6–9 条（选中态黄喷点）、0223 第 1 条里 banner 的墙与雾、0279 的 MEME 紫色环境光。
不新增依赖，`pubspec.lock` 不变（`pubspec.yaml` 按目录登记资源，无需改）；route manifest 不变；不改 loop-api。

## Context

S264 / S265 系列给五个 Tab 铺了一层「涂鸦墙」：墙面纹理（`atmo-wall`）+ 纵向 Ink 压暗 + 两团喷雾雾斑（`atmo-spray-*`，按 Tab 换位置）、标题后的褪色墙皇冠（`atmo-crown-wall`）、选中胶囊左上的黄喷点（`atmo-splat-yellow`）、banner / NFT 默认卡面底下同一张墙和雾，算力卡与名次卡上 30 % 的墙纹理水印，MEME 页还有 Figma 的紫色环境光。需求方看真机后整体不要。

## Decision

1. **中枢组件改为纯色**（页面文件不改）：
   - `LoopWallBackdrop` 只铺 `LoopColors.ink`（key `<prefix>-wall` 保留）；`LoopWallFog` 只剩名字，不再带雾斑；`LoopFogSpot` 删除。`LoopBackdropStage / Scope / Slice` 机制保留（吸顶条切片现在切到的是纯 Ink）。
   - `Launch2AtmosphereBackdrop` = `LoopWallBackdrop(keyPrefix: 'launch2-atmo')`，Figma 紫色环境光（`assets/figma/ambient-glow.svg`）去掉。
   - `LoopTitleCrown` 直接返回 child，不画墙皇冠；`LoopAtmoTitle` 标题下的紫色涂鸦短线（`LoopDoodleTitle`，选中指示）保留。
   - `LoopSplatSticker` 什么都不画，`loopSplatted` 原样返回；`LoopSeg / LoopSegBar / LoopButton / MarketTabBar / K 线工具条 / 创建页` 等调用点不改。MEME 阶段胶囊自带的喷点（`launch2_atmosphere.dart`）删除。
   - `LoopSprayHeading` / `LoopSprayIndex` 去掉喷溅。
   - `LoopChromePlate` 去掉墙纹理、紫雾与角落褪色标记；镀铬边、拉丝面、光带、`LoopSheen` 扫光保留（不依赖涂鸦图）。
   - `loopAtmosphereTabAssets` 清空：各 Tab 的 `LoopAtmoPrecache` 只再预解码本页仍画的件（镀铬默认头像、名次皇冠）。
2. **banner / NFT 默认卡面**：`Launch2BannerBackdrop` 与 `Launch2NftArtBackdrop` 去掉墙底与两团雾，底色为原有的 `#0E0D12`；镀铬手（含 6 s 扫光）、手上黄皇冠、「IN THE LOOP」标签、标题紫笔刷、左→右 Ink 渐隐、1 px 描边保留——它们是卡面内容，不是背景。
3. **算力卡 / 名次卡**：`mining_widgets.dart` 与 `intel_rank_board.dart` 里 30 % 的墙纹理水印删除，渐变底保留。
4. **资源**：删除 `assets/brand/atmo-wall.webp`、`atmo-spray-purple.png`、`atmo-spray-yellow.png`、`atmo-crown-wall.png`、`atmo-splat-yellow.png`、`assets/figma/ambient-glow.svg`（约 300 KB）。`LoopAtmoAssets` 只留仍在用的 `crownYellow / crownFlat / handChrome / brushPurple / tagInLoop / dripYellow / avatarChrome`；`atmo-SOURCES.md` 同步。品牌皇冠图（`loop-app-icon-crown` / `loop-wordmark-crown`）不动。

## Consequences

- 五个 Tab 与 MEME 主页都落在纯 Ink 上，与 docs/58 §9 的灰阶一致；吸顶条与页面同底，行从下方经过不透出（切片仍在）。
- 保留项若需求方也不要：页签下紫色涂鸦短线（`LoopDoodleTitle`）、banner 镀铬手与手上皇冠 / 标签，再单独去。
- 未使用的旧组件（`LoopChromePlate`、`LoopRankCrown`、`LoopDripBar`）保留类型，只去掉背景件，留给测试与以后。
- `LoopSeg` 的低胶囊（`capsuleHeight`）原来经私有 `_LoopSegCapsule.sticker` 挂喷点，该管道一并删除（`lib/widgets/loop_components.dart`）；`splat` 参数保留、不再画任何东西。
- 测试：新增 `test/s367_no_doodle_atmosphere_test.dart`（资源已删且 lib 无引用、`LoopWallBackdrop` 只铺 Ink、皇冠 / 喷点 / 环境光不出现、五个 Tab 屏上无被删资源、紫色涂鸦短线仍在）。改写：`s264`（MEME 底为 Ink、无标题皇冠）、`s265`（四 Tab 底为 Ink、无皇冠，删「五面墙雾位不同」断言）、`s265b`（`splat: true` 与 MEME 阶段胶囊不再有喷点）、`s265d`（镀铬牌无墙 / 雾 / 角标）、`s265e`（「压暗止于 45 %」改为「无压暗层、纯 Ink」）、`s184`（banner 无 `launch2-campaign-ground`）；`loop_ground_probe` 删去 `LoopWallBackdrop · DecoratedBox` 豁免（压暗层已不存在），两条 scrim 豁免的理由改措辞。没有整文件删除。
