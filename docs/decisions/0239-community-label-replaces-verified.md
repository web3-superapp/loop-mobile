# 0239 · 社区「已验证」标识改为后台自定义文字标签（S283-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 1274db1c（S276 合入后）。主代理下单 S283-mobile；后端 S282 同步加字段，本批客户端先行。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api。

## Context

需求方 2026-10-22 反馈第 02 条：前台的「已验证」标识全部去掉，改为显示后台填写的一个自定义文字标签（任意文字，如「算力社区」「精选社区」）；没填就不显示任何标识。

与 S282 约定的接口形状：所有带 `verificationStatus` 的社区响应新增**可选**键 `label: string | null`。后端默认不发，开关打开后才发。`verificationStatus` 仍会下发，但前台不再拿它显示。按 /v2 新增键「客户端先行」的规矩，客户端必须先能接受这个键，否则后端一开开关，严格键集的 codec 会把整页判成无效。

## Decision

1. **模型。** `CommunitySummary` 与 `ProfileCommunity` 各加可选 `label`（`String?`，默认 `null`）；`withJoin` 带上 label。
2. **解析从宽。** `communityLabelFromWire`（`community_models.dart`）：缺键、`null`、空串、全空白、非字符串一律当「无标签」，返回 `null`；字符串去首尾空白。label 只是装饰，绝不让它所在的社区解析失败。
   - `LoopV2ProjectionCodec` 的 `_communityOptionalKeys` 加 `label`：社区详情 `community()` 与发现列表行 `communityRow()` 同时生效。
   - `LoopV2ProfileCommunitiesCodec.row` 改 `strictMapWithOptional`，可选键 `label`。
   - 搜索结果的社区 `displaySnapshot` 也容忍 `label`（搜索行不画它，只保证键到达不报错）。
   - 其余未知键照旧拒绝。
3. **显示。** 新组件 `CommunityLabelBadge`（`community_widgets.dart`）：单行、超长省略；文字最多 12 个字（按码点截断，`communityLabelDisplay`，超出补「…」）。两种外观沿用原「已验证」的样式：
   - `badge`：Yellow 13 % 底、Yellow 字（原 `LoopBadge` kind `up` / `launch`），用于广场社区列表行与个人主页「社区」栏；
   - `tag`：20 高 LimeSoft 底、Lime 字（原 `LoopTag(lime)`），用于社区主页名字后面；去掉了原来的对勾图标（对勾意味着「验证」，自定义文字不是验证结论）。
4. **四处改动。**
   - 广场社区列表（`square_community_list.dart` `SquareCommunityRow`）：名字后的徽章改为 label，无则不画；徽章最多占该行文字宽度的 45 %，长标签先省略，名字不会被挤没。key `square-community-label-<id>`。
   - 发现社区行（`community_widgets.dart` `communityDirectoryRow`）：副标题由「N 名成员 · 已验证 / 审核中 / 未通过」改为「N 名成员 · <label>」，无 label 只剩成员数（排序版为「<label> · N 名成员」）。
   - 社区主页头部（`community_profile_screen.dart`）：名字后显示 label（key `community-profile-label`，最宽 140）；**群主本人**在社区仍审核中 / 未通过时另见一枚灰色 `LoopTag`「审核中 / 未通过」（key `community-profile-owner-review`），这是管理态提示；普通访客看不到审核状态。已验证社区对群主也不再显示「已验证」。
   - 他人主页「社区」栏（`user_profile_screen.dart`）：行尾胶囊改为 label（key `user-profile-community-label-<id>`，最宽 112），无则不画。
   - 读屏文案同步：有 label 时读 label，没有就不读任何验证状态。
5. **预览数据。** 开发预览的「演示社区 · Frogs」带 label「算力社区」，个人主页预览社区「预览社区」带「精选社区」，其余不带，两种行都能在预览里看到。

## Consequences

- 测试：新增 `test/s283_community_label_test.dart`（14 例，含默认跳过的截图例：详情 / 发现行 / 个人主页社区行三处解析，各覆盖有键、无键、`null`、空串，详情另覆盖全空白与非字符串；label 旁边的未知键仍被拒绝；搜索快照带 / 不带 / `null` label 都能读；`withJoin` 保留 label；12 字截断；发现行副标题有 / 无 label 与审核中社区不对访客显示状态；广场列表有 / 无 / 超长 label 渲染且名字不被挤没；社区主页访客见 label 不见审核态、无 label 无标识、审核中只对群主显示；截图用例）。
  改写 6 个旧断言（`community_pages_test`、`s111_square_club_list_test`、`s121f_secondary_pages_test`、`s261_profile_communities_launch2_test`、`s265_atmosphere_all_tabs_test`、`s82_logos_discover_and_token_test`）：从「必须有已验证」改为「无 label 无标识」；s261 的个人主页行加了一行带 label 的夹具。`test/support/community_test_harness.dart` 的 `testCommunity` 加可选 `label`。
- 截图：`docs/integration/S283/shots/square-community-labels-*.png`（`--dart-define=LOOP_SHOTS=true` 才写）。
- 未改动（不在本批文件范围）：`community_screen.dart` 「我加入的社区」行对未验证社区显示「审核中 / 未通过」（这是成员自己的社区列表，不是「已验证」标识）；`community_home_widgets.dart` 的「发现，N 个已验证」kicker 目前没有任何调用方传数字，实际只显示「发现」。如需一并处理由主代理另派。
- `communityVerificationLabel` 保留：仍用于群主审核提示与上面的「我加入的社区」行。
- 后端 S282 开关打开前，所有社区都显示「无标识」——这是预期行为：「已验证」已经不再显示。
