# 0080 · 字体改用系统无衬线，数字用等宽数字（参考 OKX）

## Status

Accepted 2026-09-23。S78a，客户端单侧，只改 `lib/core/theme/loop_theme.dart`、
`pubspec.yaml` / `assets/fonts/`、`scripts/check_harness.py` 与对应测试。
不新增路由，93 条路由清单不变；不动任何接口、状态机或文案（`eyebrow` 的
**字面**替换由各页另立单，本单只改样式）。

本决策是对冻结原型（Sora 展示体 + IBM Plex Mono 数字 + Noto Sans SC 中文，
见决策 0069）的**有意偏离**，由需求方 2026-09-23 裁决：「字体先调整下，参考
OKX」。冻结原型仍是结构、文案与状态的权威；字体一项以本决策为准。
决策 0069 的第 2 节（七档字号表）与第 3 节（等宽只给数字）被本决策取代；
0069 的第 1 节（打包 Noto Sans SC 三个静态字重）继续有效。

## Context

0069 把梯子定在原型的 Latin 声音上：Sora（几何展示体，800 字重、-0.046em
收紧、42px 顶格）配 IBM Plex Mono 打所有数字，外加大写、+0.15em 字距的
`MARKET SIGNALS` 式 eyebrow。那套梯子在 Latin 原型里成立，在一个中文为主的
交易类 App 上有三个问题：

1. **展示体没有汉字。** 一行中英混排永远是两套设计：Latin 来自 Sora，汉字来自
   Noto Sans SC。0069 靠打包中文字体把「汉字用哪个文件」控住了，但没有解决
   「两半不是一家人」。
2. **层级靠字号拉开。** 梯子从 11 一路到 42，hero 数字 32–42/800。交易所不这么
   做：OKX 的页面标题 20–22、卡片标题 15–16、正文 14、辅助 12、数字大字
   24–28，层级靠**字重与灰度**，不靠字号夸张。
3. **等宽体用错了地方。** 价格、涨跌、余额用 IBM Plex Mono，页面上就出现第二种
   声音。交易所的价格列也是对齐的，但用的是同一套无衬线的**等宽数字**
   （`tnum`），不是等宽字体。

## Decision

### 1 · 比例字体 = 平台自己的 UI 无衬线

`LoopFonts` 不再指定任何打包的展示体：

| 名称 | 值 | 说明 |
| --- | --- | --- |
| `system` | `CupertinoSystemText` | 引擎别名，Apple 上解析为 SF Pro Text |
| `systemDisplay` | `CupertinoSystemDisplay` | Apple 上解析为 SF Pro Display（≥20px） |
| `android` | `Roboto` | 非 Apple 平台的 Latin 面 |
| `mono` | `IBM Plex Mono` | 只给地址 / 哈希 / 代码 |
| `cjk` | `Noto Sans SC` | 打包的中文面，兜底 |

回退链 `systemFallback = [Roboto, PingFang SC, Noto Sans SC, HarmonyOS Sans SC,
Source Han Sans SC, Microsoft YaHei, sans-serif]`。

为什么要显式写平台家族名，而不是把 `fontFamily` 留空：`dart:ui` 的规则是
「`fontFamily` 为空且给了 `fontFamilyFallback` 时，回退链的**第一项**顶替主
字体位」（`sky_engine/lib/ui/text.dart:1737`）。留空再写回退链，Latin 会落到
Noto Sans SC 上。所以主位写 `CupertinoSystemText`：iOS/macOS 解析到 SF Pro；
Android 上这个别名解析不到，顺位落到 `Roboto`。于是

- iOS：Latin/数字 = SF Pro，汉字 = PingFang SC（Apple 给 SF Pro 配的中文面）；
- Android：Latin/数字 = Roboto，汉字 = 打包的 Noto Sans SC（与系统 Noto Sans
  CJK 同源）。

两个平台各自是**一家人**，这正是 0069 想要而没拿到的东西。

`≥20px` 走 display 光学尺寸，`<20px` 走 text 光学尺寸，与 Apple 自己的切换点
一致（`LoopFonts.familyFor(size)`）。

### 2 · 新的七档梯子

| 档 | 步 | 字号 | 字重 | 行高 | 字距 | 字体 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 display | `displayXl` | 28 | 600 | 1.2 | 0 | system display |
| 1 display | `display` | 26 | 600 | 1.2 | 0 | system display |
| 1 display | `displaySm` | 24 | 600 | 1.2 | 0 | system display |
| 2 heading | `headingLg` | 22 | 600 | 1.25 | 0 | system display |
| 2 heading | `heading` | 20 | 600 | 1.25 | 0 | system display |
| 2 heading | `headingSm` | 17 | 600 | 1.3 | 0 | system text |
| 3 title | `titleLg` | 16 | 600 | 1.3 | 0 | system text |
| 3 title | `title` | 15 | 600 | 1.3 | 0 | system text |
| 3 title | `titleSm` | 13 | 500 | 1.3 | 0 | system text |
| 4 body | `bodyLg` | 15 | 400 | 1.4 | 0 | system text |
| 4 body | `body` | 14 | 400 | 1.4 | 0 | system text |
| 4 body | `bodySm` | 13 | 400 | 1.4 | 0 | system text |
| 5 caption | `caption` | 12 | 400 | 1.35 | 0 | system text |
| 5 caption | `captionSm` | 11 | 400 | 1.35 | 0 | system text |
| 6 label | `action` | 14 | 600 | 1.25 | 0 | system text |
| 6 label | `label` | 12 | 500 | 1.25 | 0 | system text |
| 6 label | `eyebrow` | 12 | 500 | 1.25 | 0 | system text，次级灰 |
| 7 figure | `figureXl`（`monoDisplay`） | 28 | 600 | 1.2 | 0 | system display + `tnum` |
| 7 figure | `figureLg`（`monoTitle`） | 20 | 600 | 1.25 | 0 | system display + `tnum` |
| 7 figure | `figureMd`（`monoQuote`） | 17 | 600 | 1.3 | 0 | system text + `tnum` |
| 7 figure | `figure`（`monoValue`） | 13 | 500 | 1.3 | 0 | system text + `tnum` |
| 7 figure | `figureSm`（`monoBody`） | 12 | 400 | 1.4 | 0 | system text + `tnum` |
| 7 figure | `figureXs`（`monoStamp`） | 11 | 400 | 1.35 | 0 | system text + `tnum` |
| 7b code | `code` | 13 | 500 | 1.4 | 0 | IBM Plex Mono |
| 7b code | `codeSm` | 11 | 500 | 1.35 | 0 | IBM Plex Mono |

与 0069 的差：梯子从 `11–42` 收到 `11–28`；800 字重全部退到 600；所有负字距
（-0.046em / -0.027em / -0.012em / -0.008em）与 eyebrow 的 +0.15em 归零；行高
从 1.05–1.55 收到 1.2–1.4。11px 下限保留（原型 `.scr` 的屏上地板）。

**字距写成 `0`，不是 `null`。** 实施中发现：`TextStyle.letterSpacing` 留空时，
Material 自己的 2021 typography 会在 `Text` 的 style 合并里漏进来（labelMedium
+0.5，title +0.3），梯子就不再是梯子——2× Dynamic Type 下代币卡的价格行因此
多出 4px 溢出。builder 里一律 `letterSpacing ?? 0`。

**字重不再写 `fontVariations`。** 不再有可变字体需要拨轴：系统字体由引擎自己
实例化，打包的 Noto Sans SC 是三个静态字重按 `fontWeight` 匹配。
`LoopTypography.withWeight` 保留为改字重的唯一出口（现在就是一次
`copyWith`），调用点不需要知道这件事。

### 3 · 数字是等宽数字，不是等宽字体

band 7 由 `LoopTypography.figure(...)` 生成：平台无衬线 +
`FontFeature.tabularFigures()`。价格、涨跌、余额、计数、时间戳全部走这里，右对齐
后逐位对齐，而页面只有一种声音。涨跌**只靠颜色**区分（lime 涨 / danger 跌），
不靠字体。

IBM Plex Mono 只剩一件事：地址、交易哈希、合约标识、原始 payload
（band 7b `code` / `codeSm`，`LoopMono.address`）。字体资源保留、`pubspec.yaml`
注册保留。

### 4 · eyebrow 不再是大写英文戳

`.label`（`600 10px mono`、`letter-spacing:.15em`、大写）变成 12px 中文小标题
样式：medium、次级灰（`LoopColors.text3`）、无字距、无大写。
**页面上的字面**（`MARKET SIGNALS`、`SYSTEM` 之类）不在本单范围内，由各页在自己
的单里换成中文小标题；本单只保证样式已经就位。

### 5 · 删掉的字体资源

- `assets/fonts/Sora-Variable.ttf`（111 KB）
- `assets/fonts/OFL-Sora.txt`

`pubspec.yaml` 的 `family: Sora` 注册随之删除，`lib/features/profile/about/`
的开源字体署名从「Sora / IBM Plex Mono / Noto Sans SC」改为
「IBM Plex Mono / Noto Sans SC」——署名必须与实际打包一致。

### 6 · 守卫

`scripts/check_harness.py :: check_typography_band_contract` 保持原有禁令
（`lib/features/**`、`lib/widgets/**` 不得出现 `fontSize:` / `fontWeight:` /
`fontFamily:` 字面），理由文字里对 Sora 可变轴的说法改掉，并新增四条：

- `assets/fonts/Sora-Variable.ttf` / `OFL-Sora.txt` 回来 → 失败；
- `pubspec.yaml` 出现 `family: Sora` → 失败；
- `lib/core/theme/loop_theme.dart` 出现 `'Sora'` → 失败；
- 同一文件里没有 `FontFeature.tabularFigures()` → 失败（价格列会失去对齐）；
- IBM Plex Mono 的三个字重文件与 OFL 文本必须存在并注册（地址/哈希的字体）。

### 7 · 行情页（S78/市场代理）要用到的档位

需求方同日还批准了交易所形态的行情页与代币页设计稿。本单只提供梯子，页面实现
在市场代理的分支上。对应关系：

| 设计稿 | 本梯子的档 |
| --- | --- |
| symbol 15/600 | `LoopType.title`（15/600） |
| 成交额副行 12 | `LoopType.caption`（12/400，text3） |
| 列头「名称 / 成交额 · 最新价 · 24h 涨跌」 | `LoopType.label`（12/500）或 `eyebrow` |
| 右对齐最新价 15/600 | `LoopTypography.figure(15)`（tnum） |
| 涨跌块内文字 | `LoopTypography.figure(13)`（tnum），色块用 LoopColors |
| 代币页大字价 | `LoopType.figureXl`（28/600，tnum） |
| 四格「24h 高/低/成交额/市值」数值 | `LoopType.figure`（13/500，tnum），标签 `caption` |

设计稿的字体族写的是 `-apple-system,BlinkMacSystemFont,…`，与本决策同向，
可以直接落到梯子上。两处不落：

设计稿里有一处 10px/700 的小标记。**未采纳**：11px 是原型自己的屏上地板
（`.scr :is(.label,.badge,…,small){font-size:11px}`），0069 定下、本决策保留，
该处用 `captionSm`（11）或 `label`（12）。

设计稿把代币页大字价标为 30/700。**未采纳**：需求方对字体的指示是数字大字
24–28 semibold，梯子的顶格是 28/600；30/700 会把刚收下来的梯子重新撑开。若需求方
坚持 30/700，需要单独裁决并改 `figureXl`，而不是在页面里写死字号。

## Consequences

- **App 体积**减少 111 KB（Sora）。中文仍然打包（Noto Sans SC 三档，6.66 MB），
  因为 Android OEM 的中文面不可控。
- **全 App 的字变小了一档**：页面标题 24→22，卡片标题 15 的字重 700→600，正文
  14 的字重 500→400，hero 数字 32→28。这是梯子的意义：改一处，93 页跟着走，没有
  逐页改动。
- **真机上才能最终确认的两件事**（本机测试环境不加载自定义字体，widget test 用的
  是引擎测试字体）：
  1. iOS 上 `CupertinoSystemText` / `CupertinoSystemDisplay` 是否如预期解析为
     SF Pro Text/Display；
  2. 中文是否落在 PingFang SC（iOS）与打包的 Noto Sans SC（Android）上。
  两条都记为 unverified，进真机走查清单。
- 正文改 400 字重后，Ink 深底上的中文更细。深底上浅字有视觉膨胀，400 在深色界面
  通常比 500 更干净；若真机上偏细，改 `LoopTypography.body` 一处即可。
- `LoopLayout.topbarHeight` 保持 80：新梯子下的推导是 6 + 12×1.25 + 2×22×1.25 =
  76，留 4px 余量，页面布局不动。

## Evidence

命令与结果（worktree `.worktrees/loop-mobile-s78a`，分支 `s78/typography-okx`）：

- `bin/flutter pub get --enforce-lockfile` — Got dependencies!
- `bin/dart format --output=none --set-exit-if-changed lib test` — 无改动
- `bin/flutter analyze` — No issues found!
- `bin/flutter test --concurrency=2` — `+3224 ~3: All other tests passed!`（3 个 skip 为既有）
- `python3 scripts/check_harness.py` — 通过；植入 `family: Sora` / 删掉
  `tabularFigures` 时按预期失败（`tests/test_check_harness.py` 两个新用例）
- `python3 -m unittest discover -s tests -p 'test_*.py'` — Ran 396 tests, OK
- `bin/flutter build apk --debug` — ✓ Built app-debug.apk；APK 内 `assets/fonts/` 只剩 IBM Plex Mono 三档与 Noto Sans SC 三档，Sora 已不在包里

三个页面的**实测**字体普查（用 `pumpProductionApp` 跑 `/community`、`/market`、
`/wallet`，把每个 `Text` 通过它的 `DefaultTextStyle` 解析后去重；临时用例跑完删除）。
格式为 `family/size/weight/height/letterSpacing/第一回退`：

| 页面 | 改前 | 改后 |
| --- | --- | --- |
| `/community` | `Sora/24.0/800/h1.22/ls-0.65/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/ls-0.18/fb:Noto Sans SC`<br>`Sora/12.0/700/h1.25/ls0.10/fb:Noto Sans SC`<br>`Sora/11.0/700/h1.45/ls0.25/fb:Noto Sans SC`<br>`Sora/11.0/500/h1.45/ls0.25/fb:Noto Sans SC` | `CupertinoSystemDisplay/22.0/600/h1.25/ls0.00/fb:Roboto`<br>`CupertinoSystemText/15.0/600/h1.30/ls0.00/fb:Roboto`<br>`CupertinoSystemText/12.0/700/h1.25/ls0.00/fb:Roboto`<br>`CupertinoSystemText/11.0/700/h1.35/ls0.00/fb:Roboto`<br>`CupertinoSystemText/11.0/400/h1.35/ls0.00/fb:Roboto` |
| `/market` | 同上，另加 `Sora/12.0/600/h1.25/ls0.10/fb:Noto Sans SC` | 同上，另加 `CupertinoSystemText/12.0/600/h1.25/ls0.00/fb:Roboto` |
| `/wallet` | 与 `/community` 同五档 | 与 `/community` 同五档 |

读法：页面标题从 24/800/-0.65 变成 22/600/0；卡片标题字重 700→600；辅助行从
1.45 行高收到 1.35；字距全部归零；每一档的主字体从打包的 Sora 变成平台自己的
UI 无衬线，中文回退链上第一位是 PingFang SC（Apple）再到打包的 Noto Sans SC。
仓库没有 golden 机制（`matchesGoldenFile` 零调用），所以对照以实测样式表呈现，
与决策 0069 的证据格式一致。

被改到的既有断言（都是把旧梯子的数字换成新梯子的，没有放松任何判断）：

| 测试 | 改动 |
| --- | --- |
| `test/loop_theme_test.dart` | 两个字体用例重写 + 新增「打包字体资源」用例 |
| `test/loop_components_test.dart` | topbar 标题 24/800 → 22/600；两处数字断言从「等宽字体」改为「系统字体 + tnum」 |
| `test/loop_token_card_test.dart` | 价格断言同上 |
| `test/s16e_tail_test.dart` | 密集标题 18→17，普通标题 24→22 |
| `test/stream_chat_appearance_test.dart` | 气泡字重 500→400 |
| `test/stream_chat_message_layout_test.dart` | 气泡行高 1.55→1.4，两行高度 43.4→39.2 |
| `test/loop_assets_test.dart` | Sora 从「必须存在」改为「必须不存在」 |
