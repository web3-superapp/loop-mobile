# 0221 · 氛围层铺到四个 Tab + MEME 为第一个页面 + banner 封面优先（S265-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` ab6816b0（S264 合入后）。主代理下单 S265-mobile；E 项为用户 2026-10-21 14:4x 追加。
依据：`LOOP/docs/44-主页氛围层设计稿-2026-10-21.md` §0 规则与 §5 最后一条、`LOOP/docs/42-附C-App视觉规范v2-2026-10-20.md`（色板 / 字体 / 圆角不变）、决策 0220。
不新增依赖与素材，`pubspec.lock` 不变；route manifest 的路由清单（slug / 路径 / 模块 / Tab 顺序）不变，只有 `defaultRoute` 由 `chat` 改为 `meme`，清单指纹按 0110 第 2 条重算；不改 loop-api。

## Context

S264（0220）只给 MEME 主页做了氛围层，另外四个 Tab 还是纯 Ink 底，五个 Tab 放在一起像两套 App。设计稿 44 §5 最后一条已经写了其他页面的铺法：钱包总资产卡 = 镀铬牌；聊天 / 广场只加背景墙；情报算力榜前三名用皇冠压印。
同时主代理要求 MEME 成为进入 App 后的第一个页面：0110 / 0128 定的「登录后落聊天、非聊天 Tab 按返回先回聊天」改为以 MEME 为家。
E：用户要求 MEME 主页 banner 的背景「后台封面优先，氛围图为默认」——S264 把封面压到 30 % 再罩 Ink 55 %，后台配了封面也几乎看不见。

规则不变：墙是黑的，材料只有镀铬和喷漆；喷漆只落在品牌件上（顶栏皇冠、区块编号、选中胶囊、默认头像、进度条滴漆），数据行保持扁平可读；黄 = 要你点的，紫 = 选中 / 品牌带。

## Decision

### A. 公共化

1. `lib/widgets/loop_atmosphere.dart` 收拢可复用的氛围件：`LoopWallBackdrop`（墙 85 % + Ink 15→70 % 压暗 + 两团雾，雾位由 `LoopWallFog` 按 Tab 给出）、`LoopBackdropStage` / `LoopBackdropScope` / `LoopBackdropSlice`、`LoopTitleCrown` / `LoopAtmoTitle`、`LoopSplatSticker`、`LoopSprayHeading`、`LoopAtmoBoard`、`LoopAtmoEmpty`、`LoopYellowButton`、`LoopChromePlate`、`LoopChromeMedal` / `LoopChromeAvatar`、`LoopRankCrown`、`LoopDripBar`、`loopPrecacheAtmosphere` / `LoopAtmoPrecache`。
2. `launch2_atmosphere.dart` 的同名件改为薄包装（key 不变），MEME 主页行为与 s264 测试不变；跑马灯、镀铬手高光等循环动效仍只在 launch2。

### B. 四个 Tab

3. **页面骨架**：`LoopStreamPage` 与 `LoopSegmentedTabPage` 新增可选 `backdrop`（默认 null，其他页不受影响），`LoopDashboardPage.backdrop` 改经 `LoopBackdropStage` 挂墙。墙在页面最底层、不随滚动；骨架通过 `LoopBackdropScope` 告诉下层：嵌入的分段页（`embedded: true`）在墙上时 Scaffold 底改透明，让墙透出来。
   吸顶行为与 MEME 一致：`LoopDashboardPage` 的吸顶栏照旧画同一层墙（0220 第 2 条）；广场社区段的吸顶筛选条改用 `LoopBackdropSlice`——按自己在页面上的位置裁出同一层墙画在身后，行从下面经过不透出（墙外仍是 Ink）。
4. **雾位**：MEME 左上紫 / 右下黄（不变）；聊天右上紫 / 左下黄；广场右上黄 / 左下紫；情报左上黄 / 右下紫；钱包右上黄（压在镀铬牌后）/ 左下紫。透明度 10–15 %，同 0220。
5. **聊天**（`StreamChatInboxPage`，`LoopStreamPage`）：墙 + 顶栏搜索框后方的褪色皇冠（顶栏标题位是搜索框，皇冠从框上沿露出）；会话行在不透明 card 板上（行宽收进页边 16，首行上圆角、末行下圆角，滑动行的底色换成 card），行本身无装饰；「全部 / 社区 / 好友」分段 = `LoopSegBar(splat: true)`，选中紫实心 + 左上黄喷点；
   空态（无会话、筛选后为空）= `LoopAtmoEmpty`：灰阶皇冠线稿 + 一句话 + 黄按钮（无会话 →「找朋友」；社区筛选空 →「去广场看看」切到广场 Tab；好友筛选空 →「找朋友」）。连接失败 / 读取失败仍是原来的状态卡（是错误不是空）。
6. **广场**（`SquareScreen`，`LoopSegmentedTabPage`）：墙 + 皇冠压在分段标题行第一个词之后；社区列表行整体放进一块 `LoopAtmoBoard`；「已验证」胶囊不变；没有 logo 的社区用镀铬圆牌（`CommunityLogo.chromeFallback`，只在广场社区行打开，其他页面仍是字母色块）。
   社区段没有「推荐 / 热门」这类区块标题（排序由筛选条决定），所以不画喷漆编号；`LoopSprayHeading` 的无编号形态（16 / 700 + 小喷溅）留给以后有非顺序区块标题时用。
7. **情报**（`IntelScreen`，`LoopSegmentedTabPage`）：墙 + 分段行皇冠；前三名头像右上压一枚小皇冠——第 1 名黄色滴漆皇冠（`atmo-crown-yellow`），第 2 / 3 名镀铬灰阶皇冠（`atmo-crown-flat` 去色，第 3 名再暗一档）；原第 1 名头上的紫色皇冠图标移除（位置留空，三张卡高度不变）。
   「我的名次」改为 `LoopChromePlate`：1.5 px 镀铬渐变边（chrome1 → chrome2 → chrome3 → chrome2）+ card 牌面 + 牌面顶部 7 % 的镀铬微光；名次数字 Arimo 32 / 700 黄，其余 Text2；「TOP x%」戳不变。推广榜是同一块榜的第三个 scope，规则自动一致。行仍扁平，落在压暗后的墙上。
8. **钱包**（`WalletScreen`，`LoopDashboardPage`）：墙 + 顶栏「钱包」后方皇冠；总资产区包进 `LoopChromePlate`（同上规格，总资产数字黄、副行 Text2）；四个快捷键 raised 底不变；「代币 / NFT」选中态加黄喷点（`LoopSeg.splat`）；持仓行、流水行不变。
   Launch2 持仓行没有进度条（决策 0219 后只有一行文字），因此没有滴漆进度条要换。
9. **预解码**：每页经 `LoopAtmoPrecache` 在首帧前 `precacheImage` 本页用到的素材（墙、两团雾、墙皇冠、喷点；广场 / 钱包加镀铬牌，情报加两枚皇冠）。
10. **减少动效**：这四页没有任何循环动效。

### C. MEME 为第一个页面

11. `docs/product/routes-manifest.json` 的 `defaultRoute` = `meme`（指纹重算），`LoopRouteManifest.defaultSlug / defaultPath` = `meme` / `/meme`。登录完成、冷启动、`/`、`/home`、非法路由、`_popOrHome` 栈底、系统页「返回首页」都落 `/meme`。
12. 返回（取代 0128 第 4 条的落点）：壳外层 `PopScope(canPop: selectedIndex == LoopShell.homeIndex)`，在聊天 / 广场 / 情报 / 钱包按系统返回 `goBranch(LoopShell.homeIndex)` 回 MEME；只有 MEME 再按返回才退出 App。`LoopShell.homeIndex` 由 `defaultPath` 在 Tab 列表里的位置得出（= 2）。
13. Tab 顺序不变（聊天 广场 MEME 情报 钱包）；深链、通知点开、资料链接（落地后在首页上 push）不受影响。登录后若需设置 LOOP ID，可被「抬走」的落点由 `/chat` 换成 `/meme`。

### E. banner 封面优先

14. 后台配了封面且加载成功 → banner 背景就是这张封面：`BoxFit.cover` 居中、全不透明，只保留底部 55 % 的黑色渐变（docs/42 §5，透明 → Ink 85 %）；镀铬手、手上皇冠、右上 tag、紫雾黄雾、左→右 Ink 渐隐、墙纹理这组「默认艺术」不画。标题 / 紫笔刷 / 说明 / 日期 / 黄按钮 / 翻页点布局不变。
15. 没配封面、URL 不被接受、或加载失败 → S264 的默认艺术（墙 90 % + 雾 + 渐隐 + 镀铬手 + 皇冠 + tag + 高光）。
16. 无闪烁：封面 `Image.frameBuilder` 在第一帧到之前返回默认艺术，到了才换成封面层；`errorBuilder` 返回默认艺术并记下失败地址，下一帧起不再请求。0220 第 4 条「封面整体 30 % 透明、其上 Ink 55 %，只隐约可见」由本条取代。

## Consequences

- 测试：新增 `test/s265_atmosphere_all_tabs_test.dart`（四页有墙且不随滚动、聊天 / 广场 / 情报 / 钱包皇冠、广场吸顶条画墙切片、镀铬牌、前三名皇冠、广场镀铬默认头像、聊天空态、喷点胶囊、初始落点 /meme、返回规则）。
  `s184`（封面全显无镀铬手 / 失败回落默认艺术且加载中先画默认）、`s190`（名次卡为镀铬牌）、`s123a`（返回回 MEME）、`route_manifest_test`、`loop_shell_test` 与写死 `/chat` 落点的测试按新落点更新；`loop_ground_probe` 豁免键 `Launch2AtmosphereBackdrop · DecoratedBox` 改为 `LoopWallBackdrop · DecoratedBox`，`launch2-campaign-cover-veil` 豁免删除（该层已不存在）。
- harness：`check_harness.py` 的落点、重定向、返回、文档措辞断言由「聊天」改为「MEME」；AGENTS.md、`docs/product-decisions.md`、`docs/product/implementation-constraints.md` 的「Chat is the post-login home」改为 MEME。
- `LOOP/docs/routes-manifest.json`（父仓库副本）不在本单改动范围，`defaultRoute` 需主代理同步。
- 对比度：聊天 / 广场 / 钱包镀铬牌上的文字都在不透明 card 上；情报、钱包的数据行与分段标题在压暗后的墙上（同 0220 的 MEME 区块标题），需真机走查确认 ≥ 4.5:1。
- E 的风险：封面只有底部渐变保护，banner 标题在卡片上部，后台封面若是亮图或自带文字，标题会看不清 / 重复——docs/42 §5 已要求封面为无文字的纯视觉，上线前需后台按此出图。
- 偏离：聊天顶栏没有标题文字，皇冠改为压在搜索框后（从框上沿露出）；广场 / 情报的顶栏是分段标题行，皇冠压在第一个分段词之后；广场无区块标题故无编号；钱包无进度条故无滴漆。
- 冷启动不再先构建聊天分支：Stream 会话列表要到第一次切到聊天 Tab 才挂载（连接、本机副本仍由壳外的会话层负责）。
