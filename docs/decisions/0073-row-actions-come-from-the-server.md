# 0073 · 每行的治理动作由服务端下发

## Status

Accepted 2026-09-14. S17。它依赖 `GET /v2/communities/{communityId}/members`
新增的必填字段 `items[].actions`（`loop-api` 同名分支
`feat/S17-row-actions`，`loop-api/docs/frontend-v2-community-api.md` §4.6）。
不新增路由，93 条路由清单不变。

## Context

设备实测：当前账号是某社区的 **Admin**，打开**另一个 Admin** 的成员行，界面
显示了「禁言」和「封禁」。按下去服务端返回 `403 PERMISSION_DENIED`，数据库状态
没有变化，界面只能说「上一次操作没有完成 / 当前账号没有执行这个操作的权限」。

服务端的安全边界是牢的；客户端提供的是一个注定失败的入口，而且是在全 App
权限模型最敏感的一块。

根因不是权限判断写错了，而是**投影丢掉了一个维度**：

- 服务端有一张完整的 actor × action × target 矩阵。`admin` 的 `mute` / `ban`
  只允许作用于 `member`，从来不含 `admin`。
- 成员目录对外只给三个**观察者级**布尔 `canInviteAdmin` / `canMute` /
  `canBan`。它们的含义是「这个人在本社区里是否拥有某项权限」，**不带目标**。
  一个 admin 拿到的是 `canMute: true, canBan: true`。
- 客户端拿这三个布尔逐行推导动作，于是把「在本社区里能禁言某些人」读成了
  「能禁言这一行」。

决策 0054 当时就写下过「a second client-side matrix could only drift」。
漂移发生了，因为下发的事实本身少了一维，客户端无论多克制都补不回来。
`community_members_screen.dart` 里那个函数上方的注释写的是「The commands the
server has told this viewer it may run against this row」——原始意图本来就是
按行下发，只是实现走偏了。

## Contract facts this rests on

| Fact | Value |
| ---- | ----- |
| 字段 | `items[].actions`，成员目录每行必填 |
| 取值 | `assignAdmin` / `revokeAdmin` / `transferOwnership` / `mute` / `unmute` / `ban` / `unban` |
| 来源 | 服务端按 actor × action × target 矩阵 **加上**目标当前状态的前置条件逐行计算，与写接口执行的是同一对判断 |
| 顺序 | 固定为上表顺序，元素不重复 |
| 空数组 | owner 行、`isSelf` 行、`publicProfileId === null` 行、矩阵不允许的组合，一律 `[]` |
| 被封禁行 | 恒为 `["unban"]` |
| 观察者标记 | `viewer.canInviteAdmin/canMute/canBan` 保留，但只表示观察者级权限，只用于页面级入口（`canBan` 开「已封禁」分段），不决定任何一行 |
| 性质 | 投影而非授权：写接口仍用同一张矩阵重新校验 |

## Decision

| Topic | Ruling |
| ----- | ------ |
| 行动作来源 | `CommunityMemberEntry.actions` 是客户端**唯一**的行动作来源。`communityGovernanceActions(viewer, entry)` 被删除，不是改写。 |
| 客户端规则 | 客户端不再判断 owner 是否可作为目标、banned 行给什么、muted 行给 `mute` 还是 `unmute`、`isSelf` 或缺资料行是否可操作。这些结论全部由服务端算出后下发。`CommunityMemberEntry.isActionable` 一并删除。 |
| 枚举 | `CommunityGovernanceAction` 移入 `community_models.dart`，每个值带服务端的 `wireName`。UI 文案留在 `community_members_screen.dart` 的扩展里；模型只管契约，屏幕只管文案。 |
| 解析严格度 | 缺字段、非数组、非字符串元素、本版本不认识的名字、重复项、超长，一律 `invalidPayload`。半懂的治理清单不做部分渲染。 |
| 观察者标记 | 保留 `canInviteAdmin/canMute/canBan`，但 `community_members_screen.dart` 里只允许出现一次 `canBan`（开「已封禁」分段）。`canMute`、`canInviteAdmin`、`canGovern` 在该文件中被守卫禁止出现。 |
| 守卫 | `check_harness.py` 的 S3 治理守卫从「必须保留一个可检查的推导函数」改为「必须逐行渲染服务端清单，且不得在该文件里出现无目标的权限标记，也不得对下发的清单做任何过滤」。三条 Python 单测分别钉住：用 viewer 标记造清单、对清单加过滤、放松解析。 |
| Preview | `MemoryCommunityGateway` 像服务端一样逐行下发 `actions`，不再让 Preview 走另一条可见性路径。 |

## Consequences

- Admin 看另一个 Admin 时，行内没有任何治理动作，不再有注定 403 的入口。
- 顺带修掉一个同源缺陷：此前对**已禁言**成员仍显示「转让所有者」，而服务端的
  状态前置条件要求目标必须是 `active`，按下去会得到 `409 DATA_STALE`。现在
  该动作不会出现。
- 成员目录的响应每行多一个短字符串数组；分页上限 50 行，代价可忽略。
- 将来矩阵改动（新增角色、放宽某一格）只需要改服务端一处：客户端渲染什么，
  完全跟随下发结果，不会再出现「两边各有一张表」的漂移。
