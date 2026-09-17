/// The open-source components **this app** ships, and the Chinese name of each
/// rule snapshot the server publishes.
///
/// 关于 used to print the server's own register: the card title was the
/// repository path `docs/open-source-attribution.md`, the body was an English
/// paragraph about `pnpm-lock.yaml`, and the rows were Fastify and
/// `@privy-io/node` — the backend's dependencies, which no reader of a phone
/// screen has any relationship with. The same page printed the raw rule keys
/// `productPolicy` / `clientPolicy` / `bscWriteCanary`, one of which named a
/// mechanism that has not been released.
///
/// So the register rendered here is the client's own, maintained beside
/// `docs/open-source-attribution.md` in this repository and matching the direct
/// dependencies pinned in `pubspec.yaml` / `pubspec.lock`; and the rule list is
/// translated through [loopAboutModuleName], which also decides what may be
/// named at all.
library;

import 'package:loop_mobile/features/profile/about/about_models.dart';

/// Direct dependencies of this Flutter client. Versions are deliberately absent
/// — the build's lockfile is the only exact record, and a version printed here
/// could disagree with the binary the reader is holding.
const List<LoopOpenSourceEntry> loopClientOpenSourceEntries =
    <LoopOpenSourceEntry>[
      LoopOpenSourceEntry(
        name: 'Flutter / Dart',
        purpose: '应用框架与运行时',
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(name: 'dio', purpose: '网络请求', license: 'MIT'),
      LoopOpenSourceEntry(
        name: 'decimal',
        purpose: '金额与行情的精确十进制计算',
        license: 'Apache-2.0',
      ),
      LoopOpenSourceEntry(
        name: 'flutter_riverpod',
        purpose: '状态管理',
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'go_router',
        purpose: '页面路由',
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'privy_flutter',
        purpose: '登录与内置钱包',
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'reown_appkit',
        purpose: '外部钱包连接与签名凭证',
        license: 'Reown Community License',
      ),
      LoopOpenSourceEntry(
        name: 'stream_chat_flutter',
        purpose: '社区聊天',
        license: 'Stream Source Code License',
      ),
      LoopOpenSourceEntry(
        name: 'stream_chat_persistence',
        purpose: '聊天本地缓存',
        license: 'Stream Source Code License',
      ),
      LoopOpenSourceEntry(
        name: 'stream_video_flutter',
        purpose: '语音房',
        license: 'Stream Source Code License',
      ),
      LoopOpenSourceEntry(
        name: 'firebase_core / firebase_messaging',
        purpose: '推送通道',
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'flutter_secure_storage',
        purpose: '设备与会话记录的本地保管',
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'shared_preferences',
        purpose: '非敏感的本机显示偏好',
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'connectivity_plus',
        purpose: '网络可达性检测',
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'flutter_svg',
        purpose: '矢量图标渲染',
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'share_plus',
        purpose: '系统分享',
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(name: 'uuid', purpose: '本地生成的唯一标识', license: 'MIT'),
      LoopOpenSourceEntry(
        name: 'cupertino_icons',
        purpose: 'iOS 风格图标字体',
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'Sora / IBM Plex Mono / Noto Sans SC',
        purpose: '界面字体',
        license: 'SIL OFL 1.1',
      ),
    ];

/// The user-facing name of one published rule snapshot, or `null` when the rule
/// may not be named on screen.
///
/// An unknown key returns `null` rather than falling back to itself: a key the
/// client has never heard of is an internal identifier, and printing it is the
/// defect this function exists to close. `bscWriteCanary` is withheld by name —
/// it is the staged-rollout switch of a mechanism that has not been announced.
String? loopAboutModuleName(String module) => switch (module) {
  'productPolicy' => '产品规则',
  'clientPolicy' => '客户端规则',
  'sessionPolicy' => '登录与会话规则',
  'accountSettings' || 'accountSettingsPolicy' => '账号设置规则',
  'support' || 'supportPolicy' => '客服规则',
  'swapPolicy' => '兑换规则',
  'miningPolicy' => '挖矿规则',
  'launchPolicy' => 'Launch 规则',
  'communityPolicy' => '社区规则',
  'marketPolicy' => '行情规则',
  _ => null,
};

/// What each named rule decides, in one line.
String? loopAboutModuleDescription(String module) => switch (module) {
  'productPolicy' => '决定这个版本里哪些功能已经开放',
  'clientPolicy' => '决定这台设备上哪些功能可用',
  'sessionPolicy' => '决定登录状态与设备会话如何维持',
  'accountSettings' || 'accountSettingsPolicy' => '决定账号设置里可以改哪些项',
  'support' || 'supportPolicy' => '决定客服工单的提交与回复规则',
  'swapPolicy' => '决定兑换的可用范围与限制',
  'miningPolicy' => '决定算力与产出如何计算',
  'launchPolicy' => '决定 Launch 的参与规则',
  'communityPolicy' => '决定社区与成员的规则',
  'marketPolicy' => '决定行情数据的来源与展示',
  _ => null,
};
