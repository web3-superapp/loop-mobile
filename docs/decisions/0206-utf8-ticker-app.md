# 0206 · 发币表单名称 / 代码按 four.meme 规则（S243-mobile）

## Status

Accepted 2026-10-19。基线 `feat/S244-logo-icons` 9c060a5。依据：需求方裁决「名字和代码规则跟 four.meme 一致」；
loop-contracts 决策 0016（S242，`LaunchText`）、loop-api 决策 0164（S243-api）、LOOP `docs/42-附B`。
修订 0199 的长度与 ticker 部分（0199 的「不设语言限制」「`$` 策略」不变）。不新增依赖、路由、字体、颜色 token；`pubspec.lock` 不变；无新请求。

**上线约束：必须与后端 0164、合约 0016（新工厂）同批上线。** 单独上本 App：表单放行中文 / 小写 / 20 字代码，旧后端按
`^[A-Za-z0-9]{2,12}$` 拒、或旧工厂 `_validTicker` 在 `deployLaunch` revert；单独上后端 + 合约而 App 不升级：旧 App 仍挡中文代码，
且旧 App 的解码器按 `^[A-Z0-9]{2,12}$` 读 ticker，**读到中文 / 小写代码的项目会整页判为无效载荷**。

## Context

- 0199 没放开代码，原因是旧工厂 `_validTicker` 只收 2–12 个 `A–Z` / `0–9` 字节，客户端放开只会让项目部署时 revert；当时约定合约换工厂后只改 `_tickerPattern` 与文案。
- 合约 0016 换成 `LaunchText`（名称 / 代码同一套底线、1–80 字节、不转大写），产品规则 1–20 字由后端 0164 与 App 执行。
- four.meme（docs/42 附 B）：名称与代码同一规则，trim 后 1–20 个 UTF-16 单元，不转大写、不要求唯一，允许空格 / `$` / 中文 / 韩文 / emoji。

## Decision

1. **同一规则**（`lib/core/text/loop_token_text.dart`，`loopTokenNameError` / `loopTokenTickerError` 共用 `_tokenTextError`）：
   - `trim` 后 **1–20 个 UTF-16 单元**（Dart `String.length`，与 four.meme 的 JS `string.length` 同口径：中文 1、多数 emoji 2）。
   - 任何文字都收：中文、韩文、假名、带重音字母、emoji（含 ZWJ 序列、标签旗帜）、空格、`$`、小写、数字开头。**不转大写，不要求唯一**。
   - 拒：`\p{Cc}`、`\p{Cf}`（放行 U+200D 与 U+E0020–E007F）、行 / 段分隔符；除 U+0020 / U+3000 以外的空格（NBSP、U+2000–200A 等，合约 0016 拒）；
     ZWJ 在首尾；合约 `LaunchText` 另拒、但不在上述类别里的码点（U+034F、U+115F/1160、U+17B4/17B5、U+180B–180F、U+2800、U+3164、U+FFA0、非字符）；孤立代理项。
   - 首尾空白：表单先 `trim` 再校验、再提交（合约不 trim、首尾空格 revert）；读侧 `loopTokenTickerIsWellFormed` 要求服务端值本身已 trim。
   - 名称不再单独卡 64 字节：20 个 UTF-16 单元的 UTF-8 最多 60 字节，低于合约 80 字节。
2. `launch2-create` 第 1 步：去掉 `_tickerPattern`、`maxLength: 12`、`TextCapitalization.characters` 与提交前 `toUpperCase`；名称 / 代码计数器都是「x/20 字」；
   两框下加一行规则文案「名称和代码各 1–20 个字，可用中文、字母、数字、emoji」；代码框的 `$` 前缀只在 `loopTickerLabel` 会加 `$` 时显示。
   错误文案：「请填写名称 / 代码」「名称 / 代码最多 20 个字（emoji 算 2 个字）」「名称 / 代码不能包含换行、控制符或不可见字符」。
3. `LaunchProjectDraft.invalidField`：去掉 `tickerPattern`，名称 / 代码都走上面的函数；`launchDraftFieldReason` 文案同步；旧版申请页标签与提交同样不转大写。
4. **读侧同步放开**（不放开则中文代码项目在 App 里不可见）：`LoopV2S7Codec.requireTicker`、`LoopV2Launch2Codec.ticker` 替换原 `^[A-Z0-9]{2,12}$`
   （launch / launch2 实例 / 动态活动 / 创作者配置与签名请求）；launch2 持仓 ticker 与 MEME 列表 symbol 的长度上限 16 → 20 码位。
   经典发币页 `meme_create_screen`（后端 0151 已停用）不动。
5. 显示：`loopTickerLabel` 策略不变（纯 ASCII 字母数字加 `$`；`$1`、含空格 / 符号 / 非 ASCII 的不加，不会出现 `$$`）。签名摘要与项目页按原值显示。
   `loopMonogram` 改按字形簇取（`characters`，经 `package:flutter/widgets.dart` 导出，非新依赖）：组合重音不再被剥离；无字母数字时取首个可见字形簇（`🐸`），只有空白才是「·」。
6. 动态税上限：App 内无「20%」封顶文案（grep 结果为空），无需改。

## Consequences

- 已有 launch2 代码全是 `^[A-Z0-9]{2,12}$`，在新规则下仍合法，显示逐字不变。
- 输入小写代码（如 `mcat`）现在原样提交与签名；s135 断言改为小写。
- 测试：`test/core/text/loop_token_text_test.dart`（20 / 21 边界、中文 / emoji、`$1`、`四`、`フリーダム.オブ.マネー`、ZWJ / 旗帜、首尾空格、异常空格、首尾 ZWJ、孤立代理项、草稿中文代码、`$` 策略、monogram 假名 / 谚文 / 组合重音 / emoji）；
  `s135` 新增中文代码通过、21 字拒与计数器用例；`s135` / `s7` 的提交断言改为原样小写 `mcat`。
- 未做：`wallet_watchAsset` 的 11 字符限制（合约 0016 §6）——App 当前未调用。
