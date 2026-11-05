# 0298 · 「我的」身份卡移除「+ 添加简介」入口（S374-mobile）

## Status

Accepted · 2026-11-05（S374-mobile）。改写 0257（UX-017）与 S350c 里「简介为空时在 LOOP ID 下显示黄色「＋ 添加个人简介」入口」的那一条；身份卡其余布局（头像、昵称、分享名片、LOOP ID 复制行、关注数与加入月份行）不变。

## Context

需求方 11-05 17:0x 要求：「我的」页身份卡里 LOOP ID 下面那行黄色的「+ Add a bio / ＋ 添加个人简介」整体拿掉。该入口在简介为空时占一个 44 高的触控行（文字距 LOOP ID 6），点按进资料编辑页，与头像上的编辑键重复。

## Decision

- `ProfileIdentityCard` 简介为空时 LOOP ID 下不画任何东西：删掉 `profile-add-bio` 入口及其 44 触控行，不留空行、不留占位。身份卡上半行高度 = 头像 72 与「昵称 + 2 + LOOP ID 复制行」两者较高者，关注数行（`profile-meta`）紧跟其后。
- 简介非空时照旧：LOOP ID 下 6 处显示简介，最多 3 行，text2。
- 编辑简介仍从资料编辑页进（头像编辑键 `profile-open-edit` → `profile-edit`）。
- `ProfileIdentityCard` 只在本人「我的」页使用，他人主页没有该占位，无需另改。
- 删除不再引用的 ARB 键 `profile_screensProfileAddBioLabel`、`profile_screensText`（fragments/profile.json），重跑 `scripts/l10n/merge.py`，gen 产物同步；`merge.py --check` 为 0。

## Consequences

- 测试：新增 `test/s374_me_no_add_bio_test.dart`（简介为空：找不到入口与文案、关注数行顶 = 上半行底；简介非空：简介在 LOOP ID 行下 6）；`test/s187_profile_home_test.dart` 改为断言入口不存在，删掉对入口的点按与对应的导航期望。
