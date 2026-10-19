# 0206 · 发币表单名称 / 代码按 four.meme 规则（S243-mobile）

## Status

Accepted 2026-10-19。基线 `feat/S244-logo-icons` 9c060a5。依据：需求方裁决「名字和代码规则跟 four.meme 一致」；
loop-contracts 决策 0016（S242，`LaunchText`）、loop-api 决策 0164（S243-api）、LOOP `docs/42-附B`。
修订 0199 的长度与 ticker 部分（0199 的「不设语言限制」「`$` 策略」不变）。不新增依赖、路由、字体、颜色 token；`pubspec.lock` 不变；无新请求。

**上线顺序约束（可执行）：**

1. 本批与后端 0164、合约 0016（新工厂）同批合并；后端迁移与新工厂先上 dev / staging。
2. **含本批的首个 TF / APK（build 30）必须先分发，并由需求方确认已安装**；在此之前不得在任何环境上链第一个非 ASCII（中文、emoji、小写、含空格 / `$`）代码的项目。
3. 没有强制升级：上链之后，仍在用旧包（≤ build 29）的设备会坏，不会自动恢复，只能提示升级。
4. 反向也不行：只上 App 而后端 / 工厂未换，表单放行的代码会被旧后端 `^[A-Za-z0-9]{2,12}$` 拒，或在旧工厂 `_validTicker` revert。

**旧包读到非 ASCII 代码时的表现**（旧解码器 `^[A-Z0-9]{2,12}$`，失败即 `invalidPayload`）：

- 整页失败（整个响应判无效，页面进错误态）：MEME v2 列表（launch2 `instances` 分页，一条坏就整页）、项目详情、创作者项目列表 / 详情（`/v2/launch/projects`）、发射配置（hooks-config）、签名请求页、launch / launch2 摘要。
- 只跳过该条：MEME v2 首页动态带（overview 活动，读不了的条目丢弃）、广场流的代币卡（`_displayText` 失败只丢该卡）。
- 旧包的 symbol 字段（钱包资产、换币、社区绑定资产、持仓、MEME 列表）原本按 `displayTextPattern` / `aliasPattern` 整体拒 `\p{Cf}`：中文 symbol 能读，**带 ZWJ / 标签字符的 emoji symbol 会让整份载荷无效**；launch2 持仓 ticker 与 MEME 列表 symbol 旧上限 16 码位，17–20 字的代码同样整份无效。

**NFC**：服务端先 NFC 规范化再存与签名，App 不做规范化。个别组合序列规范化前后 UTF-16 长度不同（如分解形式的带重音字母，规范化后变短），可能出现「表单按原文算超 20、服务端算没超」或反过来的边界差异；两侧都是 fail-closed（表单拦、或服务端 / 读侧拒），不会产生链上与库内不一致，可接受。

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
   （launch / launch2 列表与详情 / 动态活动 / 创作者配置与签名请求）。动态活动带只丢该条，其余整份载荷判无效。
   **symbol 字段**（钱包资产 / 余额、钱包意图资产、链上资产、换币最佳交易、广场代币卡、挖矿资产、公开主页持仓、社区绑定资产、MEME 列表）
   改用同一个 `loopTokenTickerIsWellFormed`（放行 ZWJ 与 E0020–E007F），**长度仍按各字段原有上限**（钱包等 32、社区绑定资产 1024、MEME 列表 20），
   其它文本字段的 `displayTextPattern` / `aliasPattern` 不动。launch2 持仓 ticker 仍走 `providerText`（只丢危险码点不判无效），但
   `keepEmojiJoiners: true`，不再剥 ZWJ / 标签字符。经典发币页 `meme_create_screen`（后端 0151 已停用）不动。
5. 显示：`loopTickerLabel` 策略不变（纯 ASCII 字母数字加 `$`；`$1`、含空格 / 符号 / 非 ASCII 的不加，不会出现 `$$`）。签名摘要与项目页按原值显示。
   `loopMonogram` 改按字形簇取（`characters`，经 `package:flutter/widgets.dart` 导出，非新依赖）：组合重音不再被剥离；无字母数字时取首个可见字形簇（`🐸`），只有空白才是「·」。
6. 部署失败码：后端 0164 的 `HOOKS_LAUNCH_NAME_INVALID` / `HOOKS_LAUNCH_TICKER_INVALID`（合约 `InvalidName` / `InvalidTicker`）
   显示「名称 / 代码不合规，请修改后重新提交。」，`launch2JobFailureNeedsEdit` 为 true，按钮「修改名称或代码」（铸造时间失败仍是「修改铸造开始时间」）。
7. `loopMonogram` 每个字形簇最多保留基字 + 2 个附加符；以附加符开头的簇不作首字。
8. 动态税上限：App 内无「20%」封顶文案（grep 结果为空），无需改。

## Consequences

- 已有 launch2 代码全是 `^[A-Z0-9]{2,12}$`，在新规则下仍合法，显示逐字不变。
- 输入小写代码（如 `mcat`）现在原样提交与签名；s135 断言改为小写。
- 测试：`test/core/text/loop_token_text_test.dart`（20 / 21 边界、中文 / emoji、`$1`、`四`、`フリーダム.オブ.マネー`、ZWJ / 旗帜、首尾空格、异常空格、首尾 ZWJ、孤立代理项、草稿中文代码、`$` 策略、monogram 假名 / 谚文 / 组合重音 / emoji）；
  `s135` 新增中文代码通过、21 字拒与计数器用例；`s135` / `s7` 的提交断言改为原样小写 `mcat`。
- `scripts/check_harness.py` 的聊天代币卡片段从 `optionalText(map, 'symbol', maxLength: 32)` 改为 `optionalSymbol(map, 'symbol')`（仍是可选字段）。
- 追加（审查中项）：`test/s243_token_text_codec_test.dart`（launch2 列表 / 详情 / 持仓 / overview / 创作者配置 / 签名请求、S7、chain / projection / S7 symbol、社区绑定资产、`providerText` 保留 ZWJ 的正反用例）；`s7_api_contract_test` 项目列表中文 / 小写代码正、空 / 控制符 / 21 字 / 首尾空格反；`s135` 部署失败码映射；monogram 附加符上限。
- 未做：`wallet_watchAsset` 的 11 字符限制（合约 0016 §6）——App 当前未调用。
