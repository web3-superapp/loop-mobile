import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// 情报 · 算力 (decision 0272, S344): where the retired 挖矿 / 算力明细 /
/// 邀请中心 locations land, and the deep links into it.
///
/// `/intel?tab=power` opens the 算力 segment, `/intel?tab=market` the 行情
/// segment; `sub=nft|token|invite` picks the tab under 我的总算力, and
/// `code` carries an invite link's code into 邀请.
abstract final class IntelPowerRoute {
  static const String intelPath = '/intel';
  static const String tabKey = 'tab';
  static const String subKey = 'sub';
  static const String codeKey = 'code';
  static const String power = 'power';
  static const String market = 'market';

  /// `/intel?tab=power`.
  static String powerLocation([IntelPowerTab? sub]) => Uri(
    path: intelPath,
    queryParameters: <String, String>{
      tabKey: power,
      if (sub != null) subKey: sub.wireName,
    },
  ).toString();

  /// `/intel?tab=power&sub=invite`, with an invite link's code when given.
  static String inviteLocation({String? code}) => Uri(
    path: intelPath,
    queryParameters: <String, String>{
      tabKey: power,
      subKey: IntelPowerTab.invite.wireName,
      codeKey: ?code,
    },
  ).toString();

  /// The segment index a `tab` value names (0 算力, 1 行情), or null.
  static int? segmentOf(String? tab) => switch (tab) {
    power => 0,
    market => 1,
    _ => null,
  };
}

/// The three tabs under 我的总算力, in the order they are drawn.
enum IntelPowerTab {
  // S350b · decision 0275: 代币 first, the tab most accounts hold power in.
  token('token', '代币'),
  nft('nft', 'NFT'),
  invite('invite', '邀请');

  const IntelPowerTab(this.wireName, this.label);

  final String wireName;
  final String label;

  static IntelPowerTab? tryParse(String? value) {
    for (final tab in values) {
      if (tab.wireName == value) return tab;
    }
    return null;
  }
}

/// Which tab 我的总算力 shows. It outlives the page, like the segment memory;
/// 代币 first, where most accounts hold their power.
final class IntelPowerTabMemory extends Notifier<IntelPowerTab> {
  @override
  IntelPowerTab build() => IntelPowerTab.token;

  void select(IntelPowerTab tab) {
    if (state != tab) state = tab;
  }
}

final intelPowerTabProvider =
    NotifierProvider<IntelPowerTabMemory, IntelPowerTab>(
      IntelPowerTabMemory.new,
    );

/// An invite link's code waiting for the 邀请 tab to offer it once.
final class IntelPendingInviteCode extends Notifier<String?> {
  @override
  String? build() => null;

  void hold(String code) => state = code;

  void clear() {
    if (state != null) state = null;
  }
}

final intelPendingInviteCodeProvider =
    NotifierProvider<IntelPendingInviteCode, String?>(
      IntelPendingInviteCode.new,
    );

/// A retired page's route (decision 0272): it draws the bare ground for one
/// frame and then `go`es to [target].
///
/// A route-level `redirect` would do for a `go`, but a `push` whose redirect
/// lands inside the tab shell builds a second shell and fails on duplicate
/// page keys; every host that pushed these locations keeps working through
/// this hop, and the tab replaces the stack the way a tab does.
class LoopRouteForward extends StatefulWidget {
  const LoopRouteForward({required this.target, super.key});

  final String target;

  @override
  State<LoopRouteForward> createState() => _LoopRouteForwardState();
}

class _LoopRouteForwardState extends State<LoopRouteForward> {
  Animation<double>? _animation;
  bool _sent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animation != null || _sent) return;
    final animation = ModalRoute.of(context)?.animation;
    // Leaving before this page has finished arriving would bring the tab
    // shell back while the page it replaced is still on its way out, and
    // the shell's navigator key would be in the tree twice.
    if (animation == null || animation.status == AnimationStatus.completed) {
      _schedule();
    } else {
      _animation = animation..addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _animation?.removeStatusListener(_onStatus);
    _animation = null;
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sent) return;
      _sent = true;
      GoRouter.maybeOf(context)?.go(widget.target);
    });
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(
    key: ValueKey<String>('loop-route-forward'),
    color: LoopColors.ink,
    child: SizedBox.expand(),
  );
}

/// The page a forwarding route is drawn on: no transition of its own, so the
/// hop is one frame.
Page<void> loopRouteForwardPage(GoRouterState state, String target) =>
    NoTransitionPage<void>(
      key: state.pageKey,
      child: LoopRouteForward(target: target),
    );
