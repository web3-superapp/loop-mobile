# 0233 · 项目方创建项目时上传一张 NFT 图（S275-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 144a830c（S272 合入后）。主代理 2026-10-22 产品裁决：项目方创建项目时上传一张 NFT 图。
关联：loop-api 决策 0173（S274：hooks-config 草稿新增可选 `nftImageAssetUrl`，新媒体种类 `project_nft_image`，图片 pin 到 IPFS）、App 决策 0232（S273：钱包 NFT 卡片展示与 `nftImageUrl` 解码）。
不新增依赖与素材；不改 loop-api；不动钱包行、`launch2_nft_card*.dart`、`launch2_nft_screen.dart` 与持仓 / 实例 codec（归 S273）。

## Context

项目 NFT 在钱包里一直用项目 logo 或占位图，项目方没有地方给 NFT 单独配图。API 侧（S274）给 hooks-config 草稿加了可选字段 `nftImageAssetUrl`，所有权规则同 `logoAssetUrl`；图片通过新的媒体种类上传，响应在 `mediaId` / `url` 之外可带 `cid`、`ipfsUri`，`url` 是 IPFS 网关的 https 地址。

## Decision

### A. 创建页

1. 第一步「资料」在头像行下面加「NFT 图」：120 方形预览，卡片底色 + 顶部 1 px 微光线 + 左上黄喷点（`Launch2NftImageFrame`，与氛围层同一套件），内嵌 6、圆角 `LoopRadius.inner`；未上传时显示相机线稿。右侧标题「NFT 图」、按钮「上传 NFT 图 / 换一张」、说明「这张图会作为项目 NFT 的图片显示在钱包里」。
2. 选图与裁剪和头像相同（同一个 picker、同一个方形裁剪）；上传走新的媒体种类，**种类名只在一处**：`launch2NftImageMediaKind = 'project_nft_image'`（`launch2_creator_gateway.dart`，S274 定稿名不同时只改这一个常量）。上传路由由适配器按 `community_logo → /v2/media/community-logos` 的规则推出（`/v2/media/project-nft-images`，`DioLoopV2MemeApi.nftImageUploadPath`；功能层不写 `/v2/` 路径）。头像仍走 `community-logos`。
3. 上传响应宽松解码（`LoopV2MemeCodec.uploadedNftImage`）：只要求 `mediaId`（UUID）与 `url`（绝对 https，或 `/v2/media/…` 按头像规则解析）；`cid`、`ipfsUri` 有就读进 `MemeUploadedImage`，其余键（`ref`、`width`、新增键）一律忽略，不校验键集。预览直接用返回的 `url`。
4. **新项目必填**：没传 NFT 图不能离开第一步，提示「发射需要一张 NFT 图」（Chalk 字 + 预览框 Chalk 描边），与头像的 `logoMissing` 同一套样式。编辑旧项目（草稿里没有这张图）时显示「NFT 图（可不传）」，不拦步骤——服务端字段可选。
5. 提交：返回的 `url` 原样作为 `nftImageAssetUrl` 写进 `PUT …/hooks-config` 的 `config`，与 `logoAssetUrl` 同一种做法；为 `null` 时不发这个键（键集仍是原来七个）。
6. 草稿恢复：`GET …/hooks-config` 的 `config` 把 `nftImageAssetUrl` 列为可选键（和 `poolHookKind` 一样），读到即回填预览；必须是 https，否则整个草稿按非法处理（同头像）。
7. 「放弃发起？」的判定把已上传的 NFT 图算作已填写内容。

### B. 项目页

8. 项目状态页（`Launch2ProjectScreen`）在头部下面显示已提交的 NFT 图（72 方形框）+「NFT 图」标签 + 同一句说明；草稿没有这张图时整块不画。我的项目列表行不变（只放头像）。

## Consequences

- **发版顺序（重要）**：旧服务端的 hooks-config 请求体是 `additionalProperties: false` 且 `removeAdditional: false`，**不会忽略未知键，而是 400**；旧服务端也没有 `project-nft-images` 上传路由。新项目必填 NFT 图，所以本版 App 只能在 S274（loop-api 0173）部署到对应环境之后发出，否则新项目第一步就上传失败、或提交审核 400。编辑旧项目且不传 NFT 图时请求体与之前完全一致，不受影响。
- 媒体种类名是 S274 的工作名；定稿不同时只改 `launch2NftImageMediaKind`（路由随之变化），并对照 S274 的 OpenAPI 核对路由是否仍是「种类名下划线换横线 + s」。
- 测试：新增 `test/s275_create_nft_image_test.dart`（第一步必填、上传后预览、上传走独立种类、请求体带 `nftImageAssetUrl`、编辑回填并再次提交、旧草稿可编辑不拦步、草稿往返、无图时键集仍为七个、非 https 拒绝、种类常量推出路由、响应宽松解码、项目页显示 / 不显示）；`s117_meme_codec_test` 加 NFT 上传路由与 `cid` / `ipfsUri` 读取；`s135_launch2_creator_pages_test` 中新项目流程在头像后补传 NFT 图，并覆盖 `launch2NftImageUploaderProvider`。
- 组合根：`main.dart` 把 `launch2NftImageUploaderProvider` 接到 `loopV2Launch2NftImageUploaderProvider`（复用 MEME 适配器的鉴权与幂等键）；缺 Dio / 会话时 fail-closed。
- 真机需看：第一步在 390 宽下两行图片 + 表单的滚动；IPFS 网关图片首次加载速度（加载前显示占位相机线稿）；上传失败的提示条位置。
