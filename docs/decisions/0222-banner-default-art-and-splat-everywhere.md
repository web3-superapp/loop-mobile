# 0222 · MEME banner 永远用默认艺术 + 选中态黄喷点全局统一（S265b-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` 98a7e22e（S265 合入后）。依据：用户看 build 37 后的两条修正——
「背景都用闪动高光那个图，只换内容就行」；「现在选中按钮有的左上角有黄色喷漆，有的没有，统一都加下」。
不新增依赖与素材，`pubspec.lock` 不变；route manifest 不变；不改 loop-api。

## Context

决策 0221 E（第 14–16 条）把 MEME 主页 banner 改成「后台封面优先」：配了封面就整张铺开，镀铬手等默认艺术不画。用户看了真机后要回到一张固定的氛围背景，每个活动只换文字。

0220 / 0221 只给 MEME 阶段胶囊、聊天筛选、钱包「代币 / NFT」加了选中喷点（`splat` 要显式传 `true`），其余同样是「紫实心 + 白字」的选中胶囊没有喷点，同一类控件两种样子。

## Decision

### 1. banner 永远用默认艺术

1. `Launch2DeskCampaignCard` 的背景永远是 0220 第 4 条的默认艺术：墙 90 %、紫雾黄雾、左→右 Ink 渐隐、镀铬手（每 6 s 高光，减少动效时不跑）、手上黄皇冠、右上「IN THE LOOP」tag。
2. 不管后台有没有配封面，**不请求、不解码、不画**封面。`coverUrl` 仍按 codec 读进模型，只是 banner 不再用它。
3. 每个活动只换文字：标题 / 紫笔刷 / 说明 / 日期 / 黄按钮文案；翻页点按活动数量变化。
4. 封面相关代码（`_cover`、`frameBuilder` / `errorBuilder`、`_failedCover` 失败地址记录）删除。
5. **作废**：决策 0221 第 14–16 条（E：封面优先、底部 55 % 渐变、无闪烁回落），以及决策 0220 第 4 条里的封面部分（「有活动封面时叠在墙上、整体 30 % 透明，其上再叠 Ink 55 %」「封面缺失或加载失败只剩墙」）。0220 第 4 条其余内容（尺寸、版式、镀铬手、皇冠、tag、高光）不变。

### 2. 选中态黄喷点全局统一

6. **规则**：凡是「紫实心 + 白字」的选中态（分段、筛选、阶段 / scope 胶囊、选项按钮），左上角一律带黄喷点（`atmo-splat-yellow`，24 宽，−18°，相对选中框 left −7 / top −8）。
7. **公共入口**：
   - `LoopSeg.splat` 与 `LoopSegBar.splat` 默认改为 `true`。`LoopSeg` 两种画法都带：低胶囊（`capsuleHeight`）走原来的贴纸位，44 高胶囊走新的 `loopSplatted`。
   - `LoopSegBar` 带喷点时不再裁剪自己的横向滚动区。
   - `LoopButton(selected: true)`（选项按钮的选中态，紫实心白字）同样带喷点。
   - 新增公共函数 `loopSplatted(widget)`（`lib/widgets/loop_atmosphere.dart`），手写的选中胶囊也改为经它加喷点。
   - 聊天筛选、钱包「代币 / NFT」原来显式传的 `splat: true` 去掉。
8. **不加喷点**：
   - 顶部文字页签（`LoopSegmentedTabPage` 的分段标题，黄短线那种，docs/42 §4）
   - 主黄按钮与普通次级按钮
   - Tab 栏（已有黄喷雾）
   - 开关
   - 工具键的「打开」态（社区工具键）
   - 圆形功能键（`LoopRoundKey`）
   - 扫码页手电筒切换
   - 勾选框 / 勾选方块
   - 翻页点、OTP 聚焦格、头像选择描边
   - 列表选中行（紫 9 % 底 + 紫竖线，不是实心）
9. **改到的位置**：

   | 位置 | 组件 | 页面 |
   | --- | --- | --- |
   | `LoopSegBar` / `LoopSeg`（默认开） | 公共组件 | 聊天「全部 / 社区 / 好友」；钱包「代币 / NFT」；广场「全部 / 我加入的」+ 四个排序；情报算力榜「社区 / 用户 / 推广」scope；挖矿排行「社区榜 / 用户榜」；行情列表筛选；MEME 发射台列表页签；代币页 K 线周期、K 线 / 线图切换；MEME 交易面板买卖与滑点；Launch2 内盘交易「买入 / 卖出」；Launch2 外盘交易「精确输入 / 输出」；广场动态代币筛选；关注 / 粉丝切换；用户主页分段；聊天搜索分段；客服分类；大额验证阈值预设；行情二级页 `MarketSegmentBar`；旧 Launch 页分段与质押切换 |
   | `LoopButton(selected:)` | 公共组件 | 所有选项按钮的选中态 |
   | `MarketTabBar`（原手写紫胶囊） | `loopSplatted` | 行情 Tab 条、代币页下半区 Tab、MEME 主页列表 Tab（`MemeHomeTabs`）、广场动态 Tab |
   | 推广关系深度格（当前深度 L1，原手写紫格） | `loopSplatted` | 推广 / 邀请页 |
   | MEME 阶段胶囊 | 原 0220 贴纸，不变 | MEME 主页 |

## Consequences

- 测试：
  - `test/s184_launch2_campaigns_test.dart` 的两条封面用例改为「配了封面也不请求、不画封面层，默认艺术与镀铬手永远在」，以及「一个有封面、一个没有封面的两个活动，背景相同、文字不同」。
  - 新增 `test/s265b_splat_everywhere_test.dart`，共 7 处断言：`LoopSegBar` 默认带喷点且位置在左上；`LoopSeg` 44 高胶囊带喷点、`splat: false` 可关；`LoopButton` 只有选中的选项带、主 / 次按钮不带；`MarketTabBar`；钱包「代币 / NFT」不传参也带；MEME 阶段胶囊不变；顶部文字页签不带。
  - `LoopRankCrown` 改为固定 4:3 盒子，图片解码前就占位，情报前三名皇冠的位置断言不再依赖解码时机。
- 带喷点的胶囊左上会伸出选中框 2–8 px：广场筛选条与 `LoopSegBar` 的横向滚动不再裁剪。放在别的会裁剪的容器里时，喷点可能被切掉一角，需真机走查。
- 遗留：只在开发预览里出现的英文聊天收件箱（`chat_inbox_page.dart` 的 Material `SegmentedButton`）与旧聊天搜索（`chat_secondary_pages.dart` 的 `ChoiceChip`）没有接入，它们不在产品路由里。推广页「关系深度」说明列表里的 `_LevelTile`（静态 L1 图例）也没加，因为它不是选中态。
