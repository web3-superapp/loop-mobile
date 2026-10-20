# 0215 · 远程图片磁盘缓存 + 主流代币内置首帧图标（S238-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` faaccbc7。配合 loop-api 决策 0161（图标服务端归一化 128 px WebP、预热、手工覆盖，`TOKEN_LOGO_URL_MODE=proxy`）。
不新增依赖、`pubspec.lock` 不变、不改路由、不改 loop-api、不改 `lib/features/**`。

## Context

需求方反馈代币图标加载慢、常显示占位。App 端现状：

- `LoopTokenLogo` 用 `NetworkImage`，只有 Flutter 内存 `ImageCache`，冷启动与内存淘汰后重新下载；首帧只有 7 个按符号匹配的原型 SVG，其余是字母占位。
- `LoopMediaImage`（头像）已有磁盘副本（`loop_media_v1`，FNV 文件名），但没有容量上限、不读 `Cache-Control`，图标不走它。
- 锁文件里有 `crypto` 与 `cached_network_image`，但都是传递依赖；直接引用要改锁文件，属于依赖决策，本批不做。

## Decision

1. **一条读取链**：`ImageCache`（内存，按 provider 键）→ 磁盘副本 → 网络。`LoopMediaImage` 成为所有远程图片（头像、社区图、活动封面、代币图标）的唯一 provider；
   `LoopTokenLogo` 由 `NetworkImage` 换成 `LoopMediaImage`，其余行为（失败记忆、5 s 首帧预算、按像素解码）不变。
2. **磁盘缓存** `lib/core/cache/loop_image_disk_cache.dart`：应用缓存目录下 `loop_images_v2/`；文件名 = URL 的 SHA-256（自写 `lib/core/crypto/loop_sha256.dart`，FIPS 向量测试）；
   `.img` 原字节 + `.meta`（写入时间、`max-age` 秒）。读取时 touch 文件修改时间；每次写入后按修改时间从旧到新删除，直到 ≤ **64 MB**（LRU）。
   旧目录 `loop_media_v1` 首次打开时删除。所有磁盘错误都等于「没有副本」，不会让图片失败。
3. **过期策略**：遵守响应 `Cache-Control: max-age`（`no-cache` = 立即过期、`no-store` = 只显示不落盘、无头 = 1 天）。
   副本未过期直接用；**过期副本先显示，后台重新下载**，新字节不同则写盘并替换当前帧（`LoopRefreshingImageCompleter`，不经过占位）；
   **网络失败时旧副本继续用**。只有「无副本 + 下载失败」才把错误交给调用方，调用方保持现有占位（字母 / 内置图）。HTTP 状态仍以 `NetworkImageLoadException` 抛出，0101 的「确定失败」判定不变。
   磁盘副本解码失败（文件损坏）时改为下载并覆盖。同一地址并发请求合并为一次下载。只取第一帧（头像 0095、图标 0161 都是单帧 WebP）。
4. **内置首帧图标**：`LoopTokenAssets.byAddress` 以 `<chainId>/<地址>`（与 logo 代理路径一致，BNB 为 `native`）映射 BSC 主流资产，
   地址取自 loop-api `token-logo-mainstream.ts`（0161 已逐个核对）。新画 9 张（同 64 视框、灰 / 黄配色）：BNB、WBNB、USD1、BTCB、ETH、CAKE、DOGE、SHIB、XRP；
   复用 USDT、USDC、SOL、PEPE；LOOP 仍按符号（无主网地址）。**只按地址匹配新增图**，避免同名仿冒币套用主流图；原有 7 个按符号匹配保持不变。
   网络图标 `LoopNetworkAssets` 增加 CAIP-2 别名 `eip155:56 / 1 / 8453`（网络图标本来就只用内置 SVG；测试网 `eip155:97` 的字面量受 harness 约束只能写在 `loopLaunchTestnetChainId`，未加）。
5. **预取**：`loopPrefetchImages(urls)`（`lib/integrations/media/loop_image_loader.dart`）并发 ≤ 4、只看前 24 个地址、已有新鲜副本只读一次文件、失败忽略、只接受 HTTPS（调试版本地回环 HTTP）。
   App 启动、钱包与 MEME 列表首屏数据到达的调用点在 `lib/features/**` 与启动代码里，本批范围不含，**由后续单接入**（见 Consequences）。

## Consequences

- 冷启动、切页、离线都先画磁盘里的图；图标服务端 1 天 `max-age`，过期后先显示旧图再静默换新；后台手工覆盖最迟 1 天后客户端可见。
- 磁盘占用上限 64 MB（实际图标约 4 KiB / 张、头像几十 KiB）。
- 待接入调用点（`lib/features/**`，本批未改）：钱包资产列表首屏（`wallet_read_models` 的 `logoUrl`）、MEME 首页与列表（`imageUrl` / `logoUrl`）在数据到达时调用 `loopPrefetchImages(rows.take(n).map((r) => r.logoUrl))`；
  `market_fomo_widgets.dart` 仍用 `Image.network`，不走缓存，建议换成 `LoopRemoteAvatar` / `LoopTokenLogo`。
- 测试：`test/s238_image_disk_cache_test.dart`（SHA-256 向量、Cache-Control 解析、命中 / 未命中、过期刷新、刷新同字节、网络失败保留旧图、无副本失败、no-store、并发合并、LRU 淘汰、损坏副本改下载、预取并发 ≤ 4 与前 24 个、过期副本先显示再换帧、内置图按地址匹配与仿冒币保持字母）；
  `test/s123f_first_frame_cache_test.dart` 改用新缓存 API；`s78b`（provider 类型改为 `LoopMediaImage`）、`s94`（先让磁盘查找的真实 I/O 跑完）随之调整。
- 磁盘目录查找只缓存结果、不缓存未完成的 Future：跨 widget test 的单例若缓存了已死 zone 里的 Future，后续读取会永远挂起。
