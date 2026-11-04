# 0281 · 英文为默认语言，简体中文可切（多语言底座）

## Status

Accepted · 2026-11-04（S354-mobile）。用户裁决：App 默认语言改成英语。**推翻决策 0130 的「系统本地化（M4）」一节**（固定 `zh-CN`、`supportedLocales` 只有它）；0130 其余各节（触感、按下态、热区、抽屉把手、推送前置、复制 / Toast / 分享 / 焦点）不变。全仓迁移分 S355a–f 按目录并行。

## Context

- 0130 起 App 只有一种语言：`MaterialApp.router` 固定 `locale: Locale('zh', 'CN')`，所有文案是 Dart 里的中文字面量。S354 开工时 `extract.py --stats lib` 统计：281 个文件、8,672 处 CJK 字面量、6,405 条去重（见下「迁移规模」）；测试大量直接断言中文。
- Stream 官方组件的中文由 `LoopStreamChatLocalizations`（决策 0065）提供，对任何 locale 都回答中文。
- 后端返回的文案（错误信息、通知、活动名）不在本单范围。

## Decision

### 语言与切换

- 默认 **en**，不跟随系统：首次启动就是英文。可选 English / 简体中文（`LoopL10n.supportedLocales = [en, zh_CN]`）。
- 设置 · 通用 · 第一行 `settings-language`（Language / 语言）：右侧写当前语言的**自称**（English / 简体中文，不翻译），点开 `showLoopLanguageSheet` 二选一，选中即生效、关闭抽屉。原来的只读「语言」行（读 `/v2/settings` 的账号值 `languageLabel`）退役：App 语言是这台设备的选择，不是账号资源。底注改为「货币单位与主题在当前版本固定」。
- 状态：`loopLocaleProvider`（Riverpod `Notifier<Locale>`，`lib/app/loop_locale.dart`）。持久化在 `SharedPreferencesLoopLocaleStore`（`lib/integrations/personalization/shared_preferences_locale_store.dart`），只有一个键 `loop.locale`，值是语言标签 `en` / `zh-CN`；读不到 / 不认识的标签 = 英文。`main.dart` / `main_preview.dart` 在首帧前读出（与显示偏好并行，1 秒上限），中文用户不会先闪一帧英文。写失败只影响下次启动，本次照样切换。
- `MaterialApp.router`：`locale` 取自 provider，`supportedLocales: LoopL10n.supportedLocales`，delegates = `LoopL10n.delegate` + Stream + `GlobalMaterial/Cupertino/WidgetsLocalizations`。系统控件（粘贴 / 全选、日期选择器、读屏标签）跟随 App 语言。`loopAppLocale` 保留名字指向 `LoopL10n.fallbackLocale`，标 `@Deprecated`。
- Stream：`LoopStreamChatLocalizationsDelegate` 对所有 locale 回答（Flutter 要求每个 delegate 支持 App 的 locale，否则调试期报错）；`zh` 载入 `LoopStreamChatLocalizations`（不变），其余载入 `LoopStreamChatEnglishLocalizations`——由 `scripts/l10n/gen_stream_english.py` 从 SDK 的 `Translations` 生成、逐项转发给 `DefaultTranslations.instance`，即 SDK 自己的英文，不改一个字。Stream 升级后重跑该脚本。
- 字体：语言切换只换 `Localizations`，不换主题；拉丁字形走 `LoopFonts` 的拉丁面，中文仍回退到打包的 Noto Sans SC（主题的 fallback 列表不随 locale 变化）。

### ARB 结构

- `l10n.yaml`：`arb-dir: lib/l10n`、模板 `app_en.arb`、`output-dir: lib/l10n/gen`（生成文件入库，analyze 能看到）、类 `LoopLocalizations`（`lib/l10n/gen/loop_localizations.dart`）、`nullable-getter: false`、`format: true`、未翻译清单写 `build/l10n_untranslated.json`。`pubspec.yaml`：`flutter: generate: true`，`intl: 0.20.3` 直接依赖（= lockfile 原 transitive 版本，lock 只有 `dependency` 字段变为 `direct main`）。`synthetic-package` 在 Flutter 3.47 已移除，未写。
- **ARB 是生成物**：真源是 `lib/l10n/fragments/*.json`（每目录一个 + `common.json`），`scripts/l10n/merge.py` 合成 `app_en.arb` / `app_zh.arb` 再跑 `flutter gen-l10n`。不要手改 ARB；harness 比对 fragments 与 ARB，不一致即失败。
- key = `<feature>_<slug>`：feature 是 `lib/features/` 下的目录（camelCase，如 `profileSettings`），slug 来自文件名 + 就近标识符（调用的 ValueKey、命名参数、变量 / getter / switch 分支）。跨目录常用短句用 `common_*`（`common.json`，约 140 条，已按术语表填好英文）。
- 占位符一律 `Object?` 类型（与 Dart 插值同语义：null 印成 `null`），名字取自插值表达式；en 与 zh 的占位符集合必须一致（merge 拒绝）。复数 / select 本批不用；需要时在 fragment 的 en 里直接写 ICU。

### 两种取值方式

- `context.l10n.<key>`：手里有 `BuildContext`（`build`、builder 回调、带 context 参数的函数）时一律用它——它登记依赖，切语言时该 widget 重建。没有装 `LoopL10n.delegate` 的上下文（只挂了 `MaterialApp()` 的测试）回退到 `LoopL10n.current`，不会抛错。
- `LoopL10n.current.<key>`：没有 context 的地方——view model、gateway 错误映射、通知文案、formatter、`State` 的非 build 方法（`initState` 里不能读 `Localizations`）、`static` getter。它是 App 当前语言的那份实例：`LoopLocaleController` 切换时赋值，App `builder` 外层的 `LoopLocaleScope` 按解析出的 `Localizations` 再对一次，并在语言变化时把整棵子树标脏重建一次（不重挂载，路由、滚动、表单状态都保留），所以 build 里读 `LoopL10n.current`（enum 标签、formatter）切换后也会更新。仍然**不要缓存**到 `static final` / 顶层 `final`，常量声明改成 getter（`static String get x => LoopL10n.current.k;`）。
- 测试里 `LoopL10n.current` 默认英文；`test/flutter_test_config.dart` 每个用例后 `LoopL10n.debugReset()`。

### 迁移流程（S355 每个目录照做）

1. `python3 scripts/l10n/extract.py lib/features/<dir>` → `lib/l10n/fragments/<feature>.json`（zh 已填、en 空、`where` = 文件:行）。
2. 人工按 `docs/59-英文文案术语表-2026-11-04.md`（LOOP/docs）填 en，可以改 key 名，不要改占位符名。
3. `python3 scripts/l10n/apply.py lib/l10n/fragments/<feature>.json`：改源码（字面量 → getter / 带参调用，去最近的 `const`，常量声明 → getter）并把 `test/` 里对同一中文的 `find.text` / `textContaining` / `expect` 断言改成英文——仅当 lib 里已经没有任何地方再印这句中文。打印 `TODO`：enum 构造参数、switch-case 模式、参数默认值、const 集合声明里的字面量、插值表达式里的中文、`State` 非 build 方法（已用 current，请复核）、测试里只部分匹配的断言。
   apply 还会把 enum 的中文构造参数（`chat('chat', '聊天')` + `this.label`）改成 `String get label => switch (this) {...}`（只支持位置参数 `this.x`）。
4. `python3 scripts/l10n/merge.py`（合 ARB + gen-l10n）→ `bin/dart fix --apply` → `bin/dart format lib test` → `flutter analyze` → 全量 `flutter test`；手工处理 TODO。
   测试仍失败时，读完原因再用 `apply.py <fragments> --force-tests test/a_test.dart …`：只改这些文件里断言调用（`find.text`、`expect`、`containsAllInOrder`、`matchesSemantics`…）中与 fragment zh 完全相等或按模板匹配的字面量。**不要**改：服务端 fixture 原样回显的文案（如「服务端 title / body 优先」用例）、未迁移页面自己印的中文（页面标题等）、`group(` / `testWidgets(` 的名字（harness 的行为证据按名字匹配）。
5. 从 `scripts/l10n/pending_dirs.txt` 删掉该目录（或加 `!子目录`），`python3 scripts/check_harness.py` 的 `check_no_hardcoded_cjk` 从此拦住该目录的新中文字面量。

### S354 试点学到的规则（S355 照做）

- **Key 不随语言变**：`ValueKey('x-$label')` 这种用文案拼的 key 改成稳定 id（试点：意见反馈环境块改为 `version / device / system / page / language`）。
- **不要拿文案当数据比较**：`category.section == '挖矿'` 这类分组在英文下全部落空（试点：通知设置的分组改为从枚举推导）。grep `== '` 与 `case '` 里的中文。
- **过渡期混排是预期的**：已迁移目录的文案嵌进未迁移页面的中文句子（「关闭『All messages』通知？」「Theme，Dark，不可更改」）或反过来（`Updated 5 分钟前`），等对应目录迁完自然消失；测试按当时的真实输出断言并注明。

### 门禁

- `check_no_hardcoded_cjk`（`scripts/l10n/harness_rules.py`，由 `check_harness.py` 调用）：`pending_dirs.txt` 之外的 `lib/` 不得有 CJK 字符串字面量（判定与 extract 相同：注释、doc 注释、`Key(...)`、`Semantics(identifier:)`、`log(` / `debugPrint(` / `assert(` / `RegExp(`、注解不算；`lib/l10n/loop_l10n.dart` 的语言自称和 Stream 中文翻译表豁免）；fragments 与 ARB 一致；生成代码不过期；`app_en.arb` 里没有中文。
- 决策 0070 的用户可见文案规则（步骤号、`rule:`、内部词汇「口径 / 观测 / 投影 / 聚合」等）同时对 `app_zh.arb` 的值生效。
- `require_fragments` 类规则里要求某文件含某句中文的，若该句已进 ARB，则「文件读取了 zh 值含该句的 key」也算满足（`copy_present`）。其他手写的 `if '中文' not in source` 规则，S355 碰到时照此改。
- `check_l10n_locale_contract`：store 只读写 `loop.locale`；设置页语言行打开语言抽屉；默认 `LoopL10n.fallbackLocale`。

### 测试语言

全套测试在默认语言（英文）下跑、断言英文。尚未迁移的目录页面本身仍印中文，相关测试照旧断言中文；直接挂 Stream 组件并断言 LOOP 中文 Stream 文案的 8 个聊天测试文件显式 `locale: LoopL10n.simplifiedChinese`（注释标明，S355 聊天批改回英文）。

### 不在范围

后端返回的文案（只在 LOOP 后端请求上加了 `Accept-Language`：`LoopDioFactory.createLoopBackend(acceptLanguage:)` 每次请求读 `LoopL10n.currentLocale`，请求自带的同名头优先）；数字单位「万 / 亿」在 en 下改 K / M / B、日期格式 en `MMM d, HH:mm` 的实施（规则写在术语表，S355 落）。

## Consequences

- 新文案只能进 fragment；在已迁移目录写中文字面量会被 harness 拦下。
- ARB 冲突在 fragments 里解决（每目录一个文件，S355 并行基本不撞）；`app_*.arb` 与 `lib/l10n/gen/` 冲突时直接重跑 `merge.py`。
- `pending_dirs.txt` 清空之日即全仓迁移完成；届时 harness 的豁免只剩语言自称与 Stream 中文表。
