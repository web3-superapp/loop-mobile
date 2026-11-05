# 0286 · MEME Banner 铬手收回卡内（S361-mobile）

## Status

Accepted · 2026-11-05（S361-mobile）。改写 0220（S264）里「铬手悬出卡片右 14 / 下 16」的那一条；0220 的其余氛围层（墙、雾、Ink 渐隐、光带扫过、皇冠、「IN THE LOOP」标签）不变。

## Context

用户 11-05 在 iOS 真机（TF 65）截图：MEME 页 Banner 右下角的铬手底座压出卡片下边缘和右边缘，判为缺陷。需求方稿 docs/58 §5.5：Banner 353 × 162，圆角 8，1px 白 15% 描边，内放一张可替换位图，没有任何元素越出卡片。S264 故意让手悬出，`launch2DeskOverhang = 16` 给页签器留了悬垂空间。

## Decision

- `Launch2BannerBackdrop` 整体是一个圆角 8 的 `ClipRRect`：底、雾、渐隐、铬手、皇冠、标签都在里面，1px 白 15% 描边最后画、压在所有图层之上。外层不再 `Clip.none`。
- 铬手贴卡片右下角（right 0 / bottom 0），盒子 158 × 157（`handWidth` / `handHeight`，原图 171 : 170 比例，约占 353 卡宽 45%，低于卡高 162）。`Launch2ChromeHand` 本身不改。
- 删除 `launch2DeskOverhang`；页签器高度 = 卡高（两页起 + 14 的点行，`launch2DeskDotsRow`，点在卡下 8）。
- Banner 底 → 跑马灯带顶 = 16（docs/58 §9，`launch2DeskBandGap`）。此前实际是 28.5（页签器下 8 + 悬垂 16 + 跑马灯在 44 触控行里的 4.5 内缩），不是 S353b 汇报里猜的 20。

## Consequences

- 复用 `Launch2BannerBackdrop` 的三种页（活动、事件、空桌）一起生效，无分支逻辑。
- 测试：s264 / s184 改为「手在卡内、贴右下角」；新增 `test/s361_banner_hand_inside_test.dart`（360 / 393 宽：手、皇冠、标签都在卡 Rect 内；Banner → 跑马灯 16；底图是圆角 8 的 ClipRRect）。
