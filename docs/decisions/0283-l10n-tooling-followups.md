# 0283 · l10n 工具修正、术语表补录与门禁回补（S355 收口）

## Status

Accepted · 2026-11-04（S358-mobile）。S355a–g 七批英文迁移与 S357-mobile 已合入 `integration/v2` 622e67ca（ARB 6710 条，`pending_dirs.txt` 已空）。本决策收口七批汇报里的工具缺陷、术语表新词与变弱的门禁；不改任何页面视觉（S353a/b/c 并行）。延续决策 0281。

## Context

- 七批都用 `scripts/l10n/apply.py` 改源码、用 `--force-tests` 改测试，反复踩到同一批缺陷（局部变量被改成 getter 编译不过、`static const Map` 变成可变字段、非 BuildContext 的 `context` 被写成 `context.l10n`、import 插在 `library;` 前、只含 common 文案的文件被漏、第二次运行不改测试、`--force-tests` 选错模板 / ICU 原样入断言 / 改到 fixture）。
- 文案进 ARB 之后，`check_harness.py` 里一批「源码里不得出现某句中文 / 某类措辞」的规则读的还是 Dart 字面量，永远不再命中，等于失效；`copy_present` 不认插值模板。
- CJK 判定不含全角标点，只含「；」「？」的字面量漏网。

## Decision

### 工具缺陷 → 修法 → 单测（`tests/test_l10n_tools.py`、`tests/test_check_harness.py`）

| # | 缺陷 | 修法 | 单测 |
|---|---|---|---|
| 1 | 函数体里 `final x = '…'` 被改成 getter | `declaration_scope()` 判断声明在顶层 / 类成员 / 局部；局部只换右值（`context.l10n.k` 或 `LoopL10n.current.k`），局部 `const` 改 `final`；顶层与类成员才改 getter | `DeclarationTest.test_local_final_stays_a_local`、`test_local_const_becomes_final`、`test_member_and_top_level_const_become_getters` |
| 2 | `static const Map` 去掉 `const` 后成了可变 `static Map` | `const_collection_getter()`：整条声明改 `static Map<K, V> get x => {…};`（无声明类型时从 `<K, V>` 推 Map / Set / List），并吞掉范围内的 `const` 编辑 | `test_static_const_map_becomes_a_getter`、`test_typed_const_collection_literal_becomes_a_getter` |
| 3 | 名为 `context` 但不是 BuildContext 的参数被写成 `context.l10n` | `context_param()` 读参数类型：`BuildContext` / 未标类型（builder 闭包）→ context；其他类型 → `LoopL10n.current`（内层同名参数遮蔽外层，不再往外找） | `ContextParamTest` 两条 |
| 4 | import 插在 `library;` 之前 | `header_end()`：有 `library` 指令插其后，否则插在文件头注释之后；`part of` 文件不加 import。「新顶层函数插到 `@immutable` 与类之间」查明不是 apply.py 行为（S355e 手写 `loopRouteTitle`），工具无此路径 | `ImportPlacementTest` 三条 |
| 5 | 只处理 fragment `where` 列出的文件 | `sibling_files()`：扫 `where` 文件所在目录的全部 .dart（跳过生成代码），只含 common 文案的文件也会迁 | `FileScopeTest.test_sibling_files_are_scanned` |
| 6 | 非强制模式第二次运行不再改测试 | `already_migrated()`：lib 里已按 key 读取的 fragment 条目（无占位符）也进 migrated，测试照常同步 | `FileScopeTest.test_second_run_still_knows_migrated_entries` |
| 7 | `--force-tests` 过激 | 跳过固定部分无中文、或占位符 ≥ 2 且固定中文 < 4 字的模板；按固定中文长度取最具体的模板；占位符捕获到中文即判模板不对；ICU 复数按捕获的数字展开（非整数则不改）；不改 `test/support/**`、`test/fixtures/**`、文件名含 fixture 的文件、Stream 中文表里的串、`group(` / `test(` / `testWidgets(` 名字；普通 apply 的测试同步也跳过同样的文件和串 | `ForceTestsTest` 五条 |
| 8 | extract 写出空 fragment | 没有可迁字面量的文件不建 feature；合并后为空不写文件。库里没有已入库的空 fragment，merge.py 只 glob、不依赖 | `ExtractEmptyFragmentTest` |
| 9 | CJK 判定缺全角标点；`copy_present` 不认插值模板 | `l10n_lib.CJK` 加 U+3000–303F、U+FF00–FFEF（全角数字与拉丁字母除外——URL 审查的同形字表是数据）；`copy_present` 对读取的 key 的 zh 模板按固定片段顺序匹配（`共 3 条` 认 `共 {n} 条 · {t}`）；禁用句改用不做模板匹配的 `copy_mentions`（否则 `社区 {name}` 会「说出」`社区 Tab`） | `CjkRangeTest` 两条、`CopyPresentTest` 三条 |
| 10 | 通知设置「正向投递 / 已保存措辞」检查按中文字面量判断，已失效 | `visible_copy_contents()`：措辞规则同时读源码读取的 ARB key 的 zh 值（`harness_rules.copy_read`，默认只取 zh——这些规则按迁移前的中文审过，英文词表会把网络诊断的 `Success` 误判成保存成功）；Profile / Privacy / 通知三处 `contains_positive_*` 与 `notification_preferences_commit_evidence` 都传 root。同类失效规则一并改为 key 判断：Community AI 文档数禁用词、S7 退役原型口径、Token Card「生态税」、IA 过期说法、首帧缓存禁用占位、S6 资金页「演示数据」、A11「已开启 / 已启用 / 已设置」、分页按钮文案 | `L10nArbAwareWordingRuleTests` 两条 |
| 11 | 流程缺两条 | 0281「迁移流程」第 4 步补：`dart fix --apply` 必须在 analyze 干净后跑；溢出截图测试必须 `loopLoadShotFonts`。不做全仓全局真字体（主代理裁决） | 文档 |

仍按字面量判断、本批没改的规则（读的不是用户可见 ARB 文案，或需要逐条复核）：`check_harness.py` E9 Spot 快照禁词（受指纹锁定）、聊天 fixture 敏感话题、Shell 禁用 `'首页'`、`isPreview ? '开发预览' : null` 的唯一出处、`LoopBadge('等待')`。

### key 不随语言变（0281「S354 试点学到的规则」落实）

- `LaunchUnavailableCard` 的 key 是 `launch-unavailable-<id>`，没传 `id` 时用 `reason-<reasonCode>`，不再用 label。唯一没传 `id` 的调用方在 `lib/features/mining/mining_secondary_screens.dart`（S353 归属，未改）。
- `LoopStepUpSettingRow.rowKey` = `security-large-amount-step-up`。
- `LoopFactLine.id` 改为必填，key 只用 id。

### 术语表

`docs/l10n/glossary.md` 新增第五节（S355 各批新词，中文取自 `app_zh.arb`）、第四节末尾「主代理已接受的缩写」，以及 §二 与 ARB 不一致清单（只列不改）。

## Consequences

- CJK 判定变严后，`check.py --enforce` 拦出两处只有全角标点的字面量：`lib/features/chat/token_card/chat_token_card_view.dart:518` `join('；')`、`lib/features/chat/v2/voice_room_screens.dart:1284` `'${command.label}？'`。两处都在 S353 归属目录，本批不改；英文界面里它们会印出中文标点。全角判定单独成一个提交，S353 修掉这两处之后再合。
- 措辞规则现在能看到 ARB 文案：通知设置页的「通知设置已保存」重新受「必须绑定 CAS 提交结果 + 同页说明推送不可用」约束（目前满足）。
- 新写的迁移工具单测 33 条；`tests/test_check_harness.py` 新增 2 条。
