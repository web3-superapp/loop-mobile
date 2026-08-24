# Historical reference

本目录保存从 `Doog-bot534/web3-superapp-prototype` 迁入的历史资料。

`legacy-prototype/` 包含冻结的 HTML 原型、生成脚本、产品与设计文档、调研记录、离线 fixture 及历史验证脚本。它们用于追溯交互、安全边界与决策依据，不属于 LOOP 当前生产客户端，也不应继续扩展。

当前开发边界：

- 客户端以仓库根目录的 Flutter 源码为准。
- 钱包与授权目标为 Privy。
- 行情与交易目标为 Hyperliquid Core。
- 聊天与语音目标为 Stream Chat + Stream Video/Audio Rooms；当前仓只具备未配置、失败关闭的接入边界，不代表 SDK 或生产 token 链路已经打通。
- 单个 20 万成员持久群不是已验证能力；取得 Stream 对成员、提及、reaction、历史、搜索与治理语义的书面确认并完成压测前，不得对外承诺，否则采用分群/频道模型。
- Pay 的产品优先级保持 B5=A、B6/B7=B、B8=C，但 B5-B8 本期全部 deferred；首页与对应路由只能显示不可操作的 `Coming soon`。
- 历史目录中的旧供应商选择、支付实现、HIP-3、builder fee、AI Guard、风险分或“钱包地址即社交身份”等内容不代表当前实施范围；相关历史结论应以 `SUPERSEDED` 标识阅读。
- 当前身份主键是内部不可变 `user id`，钱包地址只是可绑定、可替换凭证；安全界面只展示带来源和时间的客观事实。
- 后端契约和服务适配器位于 `web3-superapp/loop-api`。

安全说明：历史原型含公开的 `DEMO_PHRASE` 和全 `1` 演示私钥，用于离线流程验证。它们是永久暴露的 burned fixture，绝不能用于真实钱包、充值、签名或任何生产环境；精确文件可能触发 secret scanner，不能据此关闭整仓安全扫描。

原仓 `apps/mobile/` 没有在本目录重复保存，因为它已经作为本仓库根目录的正式 Flutter 工程迁入；原仓 `contracts/` 与 `server/` 则迁入后端仓库。完整来源历史通过本次迁移合并提交保留。

因此 `legacy-prototype/` 不是可独立发布的完整 monorepo：依赖 `contracts/integration-catalog/**` 的历史验证器（例如 `verify_platform_ui.py`）需要在对应的原仓检查点运行，不能把参考目录缺少已迁走合同导致的失败解释为当前 Flutter 回归。
