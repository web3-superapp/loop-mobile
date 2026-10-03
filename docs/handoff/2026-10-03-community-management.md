# 社区管理入口交接

日期：2026-10-03。分支：`codex/management-operations-20261003`。本批基于上一轮 UI 分支 `codex/loop-v2-ui-edits-20261002`（724b34f），应在上一轮 PR 合并后再合并本批。

## 行为与边界

社区资料页顶部新增“管理”，在底部面板集中放置成员与权限、所有者资料编辑、语音房入口。复用原路由、控制器、后端逐目标 actions 和语音确认/结果逻辑；不改变五个主 Tab，不新建消息或 RTC 服务。

打开面板和选择操作前均刷新当前 viewer；面板监听撤权与能力变化。成员不存在、封禁、刷新失败、能力不可用均不放行。禁言管理员依照后端政策继续拥有治理权限；资料编辑仍仅所有者开放。语音入口保留 provider evidence、能力、忙态、实时房间状态及确认处理。

这只是已存在社区治理功能的入口整合。普通群成员目录、邀请/移除/转让及 Stream 对账需要独立服务端契约，不能按本批已完成验收。平台运营工作台、挖矿系数、独立审批、快照和审计在 loop-api 同名分支，完整交接见该仓库 `docs/handoff/2026-10-03-management-operations.md`。

## 验证

- 18 项新增管理测试通过；与现有 community_pages 合计 111 项通过。
- 之前 community_pages、community_mobile_layout、community_public_profile_and_apply 合计 116 项通过；最后的修正仅调整 muted 管理员资格并新增回归。
- `python3 -m unittest discover -s tests`：407 项通过；harness 检查通过。
- 修改文件 `bin/dart analyze` 无诊断，格式与 diff 检查通过。全仓 Dart 分析无 error/warning，仅原有 social_qr.dart:262 info。
- `bin/flutter analyze --no-pub` 遇 pinned SDK LSP Content-Length 中文路径字节数问题，退出 255；使用同一 SDK 的 `bin/dart analyze` 完成替代检查，未改 SDK。
- Flutter 3.47.1 / Dart 3.13.1；真机、原生构建和真实 Privy/Stream 供应商行为未验收。

## GitNexus 范围核查

提交前 detect-changes 将整个 `_CommunityProfileScreenState` 识别为变更，报告 critical / 140 flows；保留告警但不据此声称修改了 140 条业务流程。人工核对发现索引将其他 Dart 私有类的 accesses 归到此类，而相关文件并无引用或导入。精确 `_openManagement` impact 为 LOW、直接调用 1；`_canManage` 为 LOW、直接调用 3。

实际源码 diff 仅 community_profile_screen.dart 的两个 hunk：顶部管理按钮及管理辅助方法，共 175 行新增；原网关、控制器、成员写逻辑、路由均未改。compare main 含此前 integration/v2 和 UI 分支的 1,122 文件差异，不能作为本批改动数量。
