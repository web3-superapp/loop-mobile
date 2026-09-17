/// The open-source components **this app** ships, and the Chinese name of each
/// rule snapshot the server publishes.
///
/// 关于 used to print the server's own register: the card title was the
/// repository path `docs/open-source-attribution.md`, the body was an English
/// paragraph about `pnpm-lock.yaml`, and the rows were Fastify and
/// `@privy-io/node` — the backend's dependencies, which no reader of a phone
/// screen has any relationship with. The same page printed the raw rule keys
/// `productPolicy` / `clientPolicy` / `bscWriteCanary` as titles.
///
/// So the register rendered here is the client's own, maintained beside
/// `docs/open-source-attribution.md` in this repository and matching the direct
/// dependencies pinned in `pubspec.yaml` / `pubspec.lock`; and the rule list is
/// translated through [loopAboutModuleName], whose table is
/// `loop-api/docs/frontend-v2-meta-api.md` (decision 0049).
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

/// The name under which a rule the client has never heard of is listed.
///
/// The published key is a module identifier, not a name, and the number of
/// rows is the server's to decide (decision 0049): a key this client cannot
/// translate is still a rule that is in force, so the row stays and carries
/// everything except the identifier.
const String loopAboutUnknownModuleName = '其他规则';

/// The user-facing name of one published rule snapshot, or `null` when this
/// client has no name for the key.
///
/// The table is the one in `loop-api/docs/frontend-v2-meta-api.md`. An unknown
/// key returns `null` rather than falling back to itself: printing an internal
/// identifier is the defect this function exists to close.
String? loopAboutModuleName(String module) => switch (module) {
  'productPolicy' => '产品策略',
  'clientPolicy' => '客户端策略',
  'sessionPolicy' => '登录会话规则',
  'community' => '社区规则',
  'marketTrending' => '行情热榜规则',
  'deviceRisk' => '设备风险提示规则',
  'accountSettings' => '账号设置规则',
  'support' => '客服工单规则',
  'swapPolicy' => '兑换规则',
  'bscWriteCanary' => '链上写入灰度规则',
  _ => null,
};

/// What each named rule decides, in one line.
String? loopAboutModuleDescription(String module) => switch (module) {
  'productPolicy' => '五个 Tab、默认落地页与整体产品规则的版本',
  'clientPolicy' => '运营对这个客户端的版本、地区与条款要求的覆盖版本',
  'sessionPolicy' => '设备会话如何创建、限额与撤销',
  'community' => '社区创建、成员、角色与治理的规则',
  'marketTrending' => '行情页热门排序怎么算',
  'deviceRisk' => '新设备提示的阈值',
  'accountSettings' => '账号设置里可以改哪些项',
  'support' => '工单分类、字数与答复时限',
  'swapPolicy' => '兑换的报价、滑点与手续费规则',
  'bscWriteCanary' => '链上写入放量的资产范围与单笔上限',
  _ => null,
};
