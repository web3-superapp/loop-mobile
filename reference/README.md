# Historical reference

本目录保存从 `Doog-bot534/web3-superapp-prototype` 迁入的历史资料。

`legacy-prototype/` 包含冻结的 HTML 原型、生成脚本、产品与设计文档、调研记录、离线 fixture 及历史验证脚本。它们用于追溯交互、安全边界与决策依据，不属于 LOOP 当前生产客户端，也不应继续扩展。

当前开发边界：

- 客户端以仓库根目录的 Flutter 源码为准。
- 钱包与授权目标为 Privy。
- 行情与交易目标为 Hyperliquid Core。
- 聊天与语音目标为 Agora Chat + RTC。
- 历史目录中的 Stream、支付、HIP-3、builder fee 等内容不代表当前实施范围。
- 后端契约和服务适配器位于 `web3-superapp/loop-api`。

安全说明：历史原型含公开的 `DEMO_PHRASE` 和全 `1` 演示私钥，用于离线流程验证。它们是永久暴露的 burned fixture，绝不能用于真实钱包、充值、签名或任何生产环境；精确文件可能触发 secret scanner，不能据此关闭整仓安全扫描。

原仓 `apps/mobile/` 没有在本目录重复保存，因为它已经作为本仓库根目录的正式 Flutter 工程迁入；原仓 `contracts/` 与 `server/` 则迁入后端仓库。完整来源历史通过本次迁移合并提交保留。
