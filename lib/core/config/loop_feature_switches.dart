import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product switches that hide a finished surface without removing it
/// (decision 0110).
///
/// A switch only decides whether an entry is drawn and which branch a page
/// renders. It never changes the route table, a request or the backend: a
/// hidden page stays mounted and reachable by its own location.
abstract final class LoopFeatureSwitches {
  /// 需求方 2026-10-08：IDO Launch 保留代码、UI 隐藏；改 true 即恢复。
  static const bool idoLaunchVisible = false;

  /// S102 群内昵称：UI 隐藏、不移除（第二批接入）。
  static const bool groupAliasVisible = false;

  /// S107 §2：社区群聊以真实 Stream 用户（头像 + 用户名）展示，社区化名退场。
  /// 与后端 `COMMUNITY_CHAT_REAL_IDENTITY` 同名同义；改 false 即回到化名提示。
  static const bool communityChatRealIdentity = true;

  /// S107 §2：隐私页「匿名模式」开关 UI 下线（后端字段保留）；改 true 即恢复。
  static const bool anonymousModeVisible = false;

  /// S113 · 决策 0118：行情里的「新币」「聪明钱」入口隐藏（它们把读者带出
  /// LOOP，且数据源未开放）；页面与路由保留，改 true 即恢复入口。
  static const bool outboundMarketListsVisible = false;

  /// S121a · 决策 0121：搜索里的 Launch、DApp 两个域隐藏（两域都没有可搜的
  /// 目录，用户 2026-10-09：「不能搜就别放」）；枚举与探测逻辑保留，改 true
  /// 即恢复两个 chips。
  static const bool searchOutboundDomainsVisible = false;
}

/// The switch values one build runs with.
///
/// Pages read the switches through [loopFeatureSwitchesProvider] instead of
/// the constants, so a test can render both branches of the same page.
@immutable
final class LoopFeatureSwitchValues {
  const LoopFeatureSwitchValues({
    this.idoLaunchVisible = LoopFeatureSwitches.idoLaunchVisible,
    this.groupAliasVisible = LoopFeatureSwitches.groupAliasVisible,
    this.communityChatRealIdentity =
        LoopFeatureSwitches.communityChatRealIdentity,
    this.anonymousModeVisible = LoopFeatureSwitches.anonymousModeVisible,
    this.outboundMarketListsVisible =
        LoopFeatureSwitches.outboundMarketListsVisible,
    this.searchOutboundDomainsVisible =
        LoopFeatureSwitches.searchOutboundDomainsVisible,
  });

  final bool idoLaunchVisible;
  final bool groupAliasVisible;
  final bool communityChatRealIdentity;
  final bool anonymousModeVisible;
  final bool outboundMarketListsVisible;
  final bool searchOutboundDomainsVisible;

  /// Whether a channel draws its members as their real Stream user (name,
  /// image, tap to the public profile) rather than as a channel-scoped name.
  ///
  /// A community's official group follows [communityChatRealIdentity]; a
  /// small group follows the inverse of [groupAliasVisible] — with the group
  /// Alias hidden, the only name left to draw is the account's own.
  bool realIdentityFor({required bool communityChannel}) =>
      communityChannel ? communityChatRealIdentity : !groupAliasVisible;
}

/// The switches for a widget that has no `ref` of its own — the Stream
/// component builders are plain functions.
///
/// It reads the enclosing [ProviderScope] when there is one and falls back to
/// the build's constants when there is not (a bare widget test), so a builder
/// never throws for want of a scope.
LoopFeatureSwitchValues loopFeatureSwitchesOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(loopFeatureSwitchesProvider);
  } catch (_) {
    return const LoopFeatureSwitchValues();
  }
}

/// The build's switches. Production never overrides it; tests override it to
/// cover the other value of a switch.
final loopFeatureSwitchesProvider = Provider<LoopFeatureSwitchValues>(
  (ref) => const LoopFeatureSwitchValues(),
);
