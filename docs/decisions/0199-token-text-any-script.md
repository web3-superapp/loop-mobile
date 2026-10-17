# 0199 · 发币表单不设语言限制 + 非 ASCII 代码不加 `$`（S223-mobile）

## Status

Accepted 2026-10-17。基线 `integration/v2` 65d9a2d。依据：loop-api 决策 0154（分支 `feat/S223-unicode-token-names`）、
`loop-contracts` `LoopLaunchFactoryCore._validateRequest` / `_validTicker`。不新增依赖、路由、字体、颜色 token；`pubspec.lock` 不变；无新请求。

## Context

需求方 2026-10-17：发币不要做中英文限制。盘点：

- `launch2-create` 第 1 步：名称 `String.length ≤ 64`（UTF-16 单元，**无语言限制**，但合约按 UTF-8 **字节** 64 计，22–64 个汉字能过表单、在链上 revert）；代码 `^[A-Z0-9]{2,12}$`、自动转大写、`$` 前缀；简介 `String.length ≤ 2000`（emoji 算 2）。
- 旧版申请页（`LaunchProjectDraft`）：名称 ≤ 80 码位（同样不知道 64 字节）。
- 经典发币页 `meme_create_screen`（后端 0151 已停用）：只动展示，不动校验。
- 展示：约 25 处把代码写成 `'\$${symbol}'`；`loopMonogram` 只取 ASCII 与 CJK 基本区，假名 / 谚文 / 带重音字母会退化成「·」。列表与代币页的代码都在 `maxLines: 1` + 省略号的 `Text` 里，无固定宽度，中文代码不截断问题。

## Decision

1. 新增 `lib/core/text/loop_token_text.dart`，与后端 0154 一致：
   - 名称、简介**不设语言 / 文字限制**；拒绝控制字符（简介保留换行与制表）、`\p{Cf}`（双向覆写、零宽空格等）、行 / 段分隔符；放行 ZWJ 与 emoji 标签字符。
   - 长度按字符（码位）计；名称另受合约 64 字节约束：**最多 64 个字（中文最多 21 个字）**，emoji 16 个。名称输入框计数器显示「已用字节/64 字节」，不再用 `maxLength` 截断（截断按字形计，与链上不一致）。
   - NFC 规范化与首尾空白由服务端做（Dart 无内建 NFC，不为此加依赖）；客户端只按 trim 后的值校验。
2. `launch2FieldError` 与 `LaunchProjectDraft.invalidField` 改用上面的规则；文案「名称最多 64 个字（中文最多 21 个字）」「简介最多 2000 个字」。
3. **代码 ticker 暂不放开**：合约 `_validTicker` 只收 2–12 个 `A–Z` / `0–9` 字节，客户端放开只会让项目在部署时 revert。输入仍可小写（提交前转大写），文案改为「代码暂只支持 2–12 位英文字母或数字（链上合约限制）」，明确这是合约而非产品的限制。合约换工厂放开后，客户端只需改 `_tickerPattern` 与文案。
4. **`$` 前缀策略**：`loopTickerLabel(symbol)`——纯 ASCII 字母数字的代码显示 `$DOGE`；含任何非 ASCII 字符（中文、emoji、混排）的代码不加 `$`，直接显示 `狗狗`（`$` 加在中文前读作价格）。MEME 列表、代币页、交易面板、签名摘要、launch2 实例 / 项目 / 签名页全部改用它。
5. `loopMonogram` 取任意文字的字母与数字（`\p{L}\p{N}`）。

## Consequences

- 当前 launch2 代码仍全是 ASCII，`$` 显示与之前逐字相同；外部 / 未来的非 ASCII 代码自动不加 `$`。
- 服务端会把名称 NFC 规范化后存回；编辑页读回的是规范化后的值，用户可见文字不变。
- 测试：`test/core/text/loop_token_text_test.dart`（中文 / 混排 / emoji / ZWJ 通过；64 ASCII、21 汉字、16 emoji 边界；控制 / 双向 / 零宽拒绝；简介按码位 2000；中文 ticker 仍拒；`$` 策略；monogram）；`s135` 与 `s7` 文案断言更新。
