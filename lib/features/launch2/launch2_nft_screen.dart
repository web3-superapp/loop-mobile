import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_mint.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

// ---------------------------------------------------------------------------
// `launch2-nft` · 共识勋章 (decision 0163, docs/32 §4)
// ---------------------------------------------------------------------------
//
// One instance's NFT as a page of its own: the medal, the stage line with
// its countdown, what the medal does, the rules, what this wallet holds and
// the one button. The page reads the project page's own instance read
// (`launch2InstanceControllerProvider`), and its 「铸造」 is the project
// page's own trip ([launch2MintNft]). Brass marks the NFT here and nowhere
// else; Lime stays the trading accent.

/// What the main button does.
enum Launch2NftAction {
  /// The NFT mint trip.
  mint,

  /// The project page, where the curve and the pool trade.
  openProject,

  /// Nothing now: the button is drawn disabled.
  none,
}

/// The page's state line, button and medal for one instance read
/// (docs/32 §4.2).
@immutable
final class Launch2NftView {
  const Launch2NftView({
    required this.status,
    required this.statusLit,
    required this.buttonLabel,
    required this.action,
    required this.brassRing,
    required this.medalLabel,
    this.countdownTo,
    this.statusDetail,
  });

  /// The state line; when [countdownTo] is set, the words before it.
  final String status;
  final DateTime? countdownTo;

  /// Lime: the stage takes orders or mints now. Chalk otherwise.
  final bool statusLit;

  /// The quiet line under it (「已铸 N 枚」, a hold reason).
  final String? statusDetail;
  final String buttonLabel;
  final Launch2NftAction action;

  /// A Brass ring; otherwise the greyed one.
  final bool brassRing;

  /// The medal's lower arc: 「#tokenId」 once held, 「共识勋章」 before.
  final String medalLabel;
}

/// The view of [detail] (docs/32 §4.2). [walletActive]: the account has a
/// wallet the mint can be paid from.
Launch2NftView launch2NftView(
  Launch2InstanceDetail detail, {
  required bool walletActive,
}) {
  final row = detail.row;
  final viewer = detail.viewer;
  final held = (viewer?.nftHeld ?? 0) > 0;
  final tokenId = viewer?.mintedTokenId;
  final medal = held && tokenId != null ? '#$tokenId' : '共识勋章';
  final minted = '已铸 ${row.nftSale.soldCount} 枚';
  final next = row.nextChangeAt;
  const toProject = '去项目页交易';
  switch (row.stage) {
    case Launch2Stage.upcoming:
      return Launch2NftView(
        status: next == null ? '开售时间待定' : '开售倒计时 ',
        countdownTo: next,
        statusLit: false,
        statusDetail:
            '${launch2Usd1Label(row.nftSale.priceUsd1)} / 枚 · '
            '发售 ${launch2SaleDurationLabel(row.nftSale)}',
        buttonLabel: '开售后可铸造',
        action: Launch2NftAction.none,
        brassRing: false,
        medalLabel: medal,
      );
    case Launch2Stage.nftSale:
      return Launch2NftView(
        status: next == null ? 'NFT 铸造中' : 'NFT 铸造中 · 剩 ',
        countdownTo: next,
        statusLit: true,
        statusDetail: minted,
        buttonLabel: held
            ? '已持有 · 每地址 1 枚'
            : walletActive
            ? '铸造 1 枚 · ${launch2Usd1Label(row.nftSale.priceUsd1)}'
            : '激活钱包后可铸造',
        action: held || !walletActive
            ? Launch2NftAction.none
            : Launch2NftAction.mint,
        brassRing: true,
        medalLabel: medal,
      );
    case Launch2Stage.snapshotPending:
      return Launch2NftView(
        status: '铸造已结束 · 名单生成中',
        statusLit: false,
        statusDetail: minted,
        buttonLabel: held ? '等待名单发布' : '铸造已结束',
        action: Launch2NftAction.none,
        brassRing: true,
        medalLabel: medal,
      );
    case Launch2Stage.priority:
      return Launch2NftView(
        status: next == null ? '提前购进行中' : '提前购进行中 · 剩 ',
        countdownTo: next,
        statusLit: true,
        statusDetail: minted,
        buttonLabel: toProject,
        action: Launch2NftAction.openProject,
        brassRing: held,
        medalLabel: medal,
      );
    case Launch2Stage.public:
      return Launch2NftView(
        status: detail.snapshot.openedWithoutHolders != null
            ? '发售结束时无人铸造，已直接进入公开轮'
            : '内盘已开放',
        statusLit: true,
        statusDetail: minted,
        buttonLabel: toProject,
        action: Launch2NftAction.openProject,
        brassRing: held,
        medalLabel: medal,
      );
    case Launch2Stage.graduated:
      return Launch2NftView(
        status: '已毕业',
        statusLit: false,
        statusDetail: minted,
        buttonLabel: toProject,
        action: Launch2NftAction.openProject,
        brassRing: held,
        medalLabel: medal,
      );
    case Launch2Stage.closedNoHolders:
      // Decision 0120 / 0142: a legacy sale with no holder is closed for
      // good — neither round opens, so the page does not say it did.
      return Launch2NftView(
        status: '发售结束时无人铸造，项目已关闭',
        statusLit: false,
        buttonLabel: '去项目页',
        action: Launch2NftAction.openProject,
        brassRing: false,
        medalLabel: medal,
      );
    case Launch2Stage.paused:
      return Launch2NftView(
        status: '项目已暂停',
        statusLit: false,
        statusDetail: launch2HoldReasonText(row.holdReason),
        buttonLabel: '去项目页',
        action: Launch2NftAction.openProject,
        brassRing: false,
        medalLabel: medal,
      );
  }
}

/// 「我的持有」 (docs/32 §4.1).
String launch2NftHoldingText(Launch2InstanceDetail detail) {
  final viewer = detail.viewer;
  if (viewer == null) return '未激活钱包';
  if (viewer.nftHeld <= 0) return '0 / 1';
  final tokenId = viewer.mintedTokenId;
  if (tokenId == null) return '${viewer.nftHeld} / 1';
  if (detail.snapshot.published) {
    return viewer.snapshotMember ? '#$tokenId · 已在快照名单' : '#$tokenId';
  }
  return '#$tokenId · 已在候选名单';
}

/// The toast once a mint shows up in the read model (docs/32 §4.3).
const String launch2NftMintedToast = '已铸造 · 等待发售结束进入名单';

class Launch2NftScreen extends ConsumerStatefulWidget {
  const Launch2NftScreen({
    required this.instanceId,
    super.key,
    this.onBack,
    this.onNavigate,
  });

  final String? instanceId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<Launch2NftScreen> createState() => _Launch2NftScreenState();
}

/// Our own mint, until the read model shows it.
@immutable
final class _Pending {
  const _Pending({required this.text, required this.locked});

  final String text;

  /// Broadcast: no second mint until the lane shows it.
  final bool locked;
}

class _Launch2NftScreenState extends ConsumerState<Launch2NftScreen> {
  Timer? _poll;
  _Pending? _pending;
  Launch2ActionFailure? _failure;
  bool _preparing = false;
  int _settleReads = 0;

  /// The project page's limit: how many re-reads a broadcast waits for.
  static const int _settleLimit = 36;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    unawaited(context.push(location));
  }

  Launch2InstanceController _controller(String id) =>
      ref.read(launch2InstanceControllerProvider(id).notifier);

  void _armPoll(String id, Launch2InstanceDetail detail) {
    if (_poll != null || detail.stage.terminal) return;
    final polling = ref.read(launch2PollingProvider);
    final fast = _pending?.locked ?? false;
    _poll = Timer(fast ? polling.tradingInterval : polling.detailInterval, () {
      _poll = null;
      if (!mounted) return;
      unawaited(_controller(id).reload());
    });
  }

  void _settle(Launch2InstanceDetail detail) {
    final pending = _pending;
    if (pending == null || !pending.locked) return;
    if ((detail.viewer?.nftHeld ?? 0) > 0) {
      setState(() {
        _pending = null;
        _settleReads = 0;
      });
      LoopToast.show(context, message: launch2NftMintedToast);
      return;
    }
    _settleReads += 1;
    if (_settleReads >= _settleLimit) {
      setState(() {
        _pending = const _Pending(
          text:
              '已广播，但还没有读到确认。它可能仍在确认中，请稍后再查；'
              '不要重复铸造。',
          locked: false,
        );
      });
    }
  }

  Future<void> _mint(Launch2InstanceDetail detail) async {
    final result = await launch2MintNft(
      context,
      ref,
      detail,
      onPreparing: () {
        if (!mounted) return;
        setState(() {
          _preparing = true;
          _failure = null;
        });
      },
      onPrepared: () {
        if (mounted) setState(() => _preparing = false);
      },
      entry: Launch2NftMintEntry.mintPage,
    );
    if (!mounted) return;
    switch (result) {
      case Launch2NftMintCancelled():
        return;
      case Launch2NftMintRefused(:final failure):
        setState(() {
          _preparing = false;
          _failure = failure;
        });
      case Launch2NftMintSigned(:final intent, :final outcome):
        setState(() {
          _settleReads = 0;
          _pending = _Pending(
            text: launch2OutcomeText(
              outcome,
              intent.kind,
              noun: Launch2NftMintEntry.mintPage.noun,
            ),
            locked: outcome.broadcast,
          );
        });
        if (outcome.broadcast) {
          _poll?.cancel();
          _poll = null;
          unawaited(_controller(detail.instanceId).reload());
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.instanceId;
    if (!Launch2Route.isInstanceId(id)) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-nft-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: '共识勋章',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('launch2-nft-invalid-identity'),
            icon: 'warn',
            message: '路由中没有可用的项目标识',
            reason: '没有请求任何数据，也没有回退到其他项目。',
          ),
        ],
      );
    }
    final instanceId = id!;
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch2),
    );
    final blocked = launch2ReadsBlocked(ref);
    final provider = launch2InstanceControllerProvider(instanceId);
    final state = blocked ? null : ref.watch(provider);
    if (state != null) {
      launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    }
    ref.listen<LoopChainResourceState<Launch2InstanceDetail>>(provider, (
      previous,
      next,
    ) {
      final value = next.value;
      if (value != null && !identical(previous?.value, value)) {
        _settle(value);
      }
    });
    final detail = state?.value;
    final wallet = detail == null ? null : memeActiveWallet(ref);
    if (detail != null) _armPoll(instanceId, detail);
    final view = detail == null
        ? null
        : launch2NftView(
            detail,
            walletActive: wallet?.walletId != null || detail.viewer != null,
          );
    return LoopDashboardPage(
      key: const ValueKey<String>('launch2-nft-screen'),
      archetype: LoopPageArchetype.record,
      title: '共识勋章',
      onBack: widget.onBack,
      updating: state?.refreshing ?? false,
      onRefresh: blocked ? null : () => ref.read(provider.notifier).reload(),
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('launch2-nft-blocked'),
              title: 'MEME v2 暂时不可用',
              message: launch2CapabilityText(capability),
            )
          : null,
      bottomBar: detail == null || view == null
          ? null
          : _bottomBar(detail, view),
      sections: <Widget>[
        if (state == null || detail == null || view == null)
          LoopChainStateBlock(
            keyPrefix: 'launch2-nft',
            phase: state?.phase ?? LoopChainViewPhase.unavailable,
            failureKind: state?.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '项目不存在',
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          )
        else
          ..._sections(detail, view),
      ],
    );
  }

  Widget _bottomBar(Launch2InstanceDetail detail, Launch2NftView view) {
    final hold = detail.tradingHold;
    final mint = view.action == Launch2NftAction.mint;
    final locked = _pending?.locked ?? false;
    final enabled = switch (view.action) {
      Launch2NftAction.mint => hold == null && !_preparing && !locked,
      Launch2NftAction.openProject => true,
      Launch2NftAction.none => false,
    };
    final failure = mint && hold == null && !_preparing ? _failure : null;
    return Launch2BarShell(
      failure: mint && hold != null
          ? Launch2TradingHoldLine(
              key: const ValueKey<String>('launch2-nft-bar-hold'),
              hold: hold,
              padding: EdgeInsets.zero,
            )
          : failure == null
          ? null
          : Launch2ActionFailureLine(
              key: const ValueKey<String>('launch2-nft-bar-failure'),
              message: failure.text,
            ),
      child: LoopButton(
        key: const ValueKey<String>('launch2-nft-mint'),
        label: mint && _preparing ? '正在准备…' : view.buttonLabel,
        primary: true,
        block: true,
        tone: LoopButtonTone.brass,
        onPressed: !enabled
            ? null
            : switch (view.action) {
                Launch2NftAction.mint => () => unawaited(_mint(detail)),
                Launch2NftAction.openProject => () => _open(
                  Launch2Route.instance(detail.instanceId),
                ),
                Launch2NftAction.none => null,
              },
      ),
    );
  }

  List<Widget> _sections(Launch2InstanceDetail detail, Launch2NftView view) {
    final row = detail.row;
    final pending = _pending;
    final summary = row.summary;
    final failure = _failure;
    return <Widget>[
      // Decision 0161: the chain guard's hold, above everything that pays.
      if (detail.tradingHold case final Launch2TradingHold hold)
        Launch2TradingHoldBanner(hold: hold),
      if (pending != null)
        LoopNotice(
          key: const ValueKey<String>('launch2-nft-pending'),
          icon: pending.locked ? 'clock' : 'info',
          body: pending.text,
        ),
      if (failure != null && !_preparing)
        LoopInlineUnavailable(
          key: const ValueKey<String>('launch2-nft-action-failed'),
          icon: 'warn',
          message: failure.text,
        ),
      _MedalHeader(detail: detail, view: view),
      _StatusLines(
        view: view,
        onElapsed: () => unawaited(_controller(detail.instanceId).reload()),
      ),
      if (summary != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            LoopSpacing.group,
            LoopSpacing.page,
            0,
          ),
          child: Text(
            summary,
            key: const ValueKey<String>('launch2-nft-summary'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: LoopType.body.copyWith(color: LoopColors.text2),
          ),
        ),
      _Bullets(
        keyName: 'launch2-nft-benefits',
        title: '这枚勋章能做什么',
        lines: <String>[
          '发售结束时持有，进入快照名单；名单发布后有 1 小时提前购内盘',
          '铸造款进入本项目的托管合约，毕业后由平台按每笔 '
              '${launch2Usd1Label(detail.template.buybackOrderUsd1)} 回购 MEME',
        ],
      ),
      _Bullets(
        keyName: 'launch2-nft-rules',
        title: '规则',
        lines: <String>[
          '每个地址终身只能铸 1 枚 · '
              '${launch2Usd1Label(row.nftSale.priceUsd1)} / 枚',
          '发售 ${launch2SaleDurationLabel(row.nftSale)}，'
              '截止 ${loopDateTimeLabel(row.nftSale.endAt)}',
          '$launch2NftRiskSentence。',
        ],
      ),
      const SizedBox(height: 8),
      LoopKeyValue(
        key: const ValueKey<String>('launch2-nft-held'),
        label: '我的持有',
        value: launch2NftHoldingText(detail),
      ),
      LoopKeyValue(
        key: const ValueKey<String>('launch2-nft-sold'),
        label: '已铸',
        value: '${row.nftSale.soldCount} 枚',
      ),
      LoopProvenanceLine(
        key: const ValueKey<String>('launch2-nft-provenance'),
        sources: const <String>['LOOP 链上索引'],
        observedAt: detail.projectedAt,
        padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 6, 16, 4),
        detail: '阶段与倒计时由服务端按链上时间给出，到点后重新读取。',
      ),
    ];
  }
}

/// The medal and the ticker beside it.
class _MedalHeader extends StatelessWidget {
  const _MedalHeader({required this.detail, required this.view});

  final Launch2InstanceDetail detail;
  final Launch2NftView view;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        12,
        LoopSpacing.page,
        LoopSpacing.group,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Launch2NftMedal(
            key: const ValueKey<String>('launch2-nft-medal'),
            ticker: row.ticker,
            logoUrl: row.logoUrl,
            identity: row.instanceId,
            bottomLabel: view.medalLabel,
            brass: view.brassRing,
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  launch2HeroTicker(row.ticker),
                  key: const ValueKey<String>('launch2-nft-ticker'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.display,
                ),
                const SizedBox(height: 2),
                Text(
                  row.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.body.copyWith(color: LoopColors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLines extends StatelessWidget {
  const _StatusLines({required this.view, required this.onElapsed});

  final Launch2NftView view;
  final VoidCallback onElapsed;

  @override
  Widget build(BuildContext context) {
    final color = view.statusLit ? LoopColors.lime : LoopColors.chalk;
    final style = LoopType.titleLg.copyWith(color: color);
    final target = view.countdownTo;
    final detail = view.statusDetail;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (target == null)
            Text(
              view.status,
              key: const ValueKey<String>('launch2-nft-status'),
              style: style,
            )
          else
            Row(
              key: const ValueKey<String>('launch2-nft-status'),
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(view.status, style: style),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Launch2Countdown(
                      target: target,
                      onElapsed: onElapsed,
                      style: LoopType.figureLg.copyWith(color: color),
                    ),
                  ),
                ),
              ],
            ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              detail,
              key: const ValueKey<String>('launch2-nft-status-detail'),
              style: LoopType.body.copyWith(color: LoopColors.text2),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({
    required this.keyName,
    required this.title,
    required this.lines,
  });

  final String keyName;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey<String>(keyName),
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      LoopSpacing.group,
      LoopSpacing.page,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: LoopType.headingSm),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: LoopColors.text3,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: LoopType.body.copyWith(color: LoopColors.text2),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// 共识勋章 (docs/32 §4.1): a perfect circle — a 2 px outer ring (Brass, or
/// the greyed tone), a Graphite face, the logo (56) in the middle, the
/// ticker along the upper arc in mono and [bottomLabel] along the lower one.
class Launch2NftMedal extends StatelessWidget {
  const Launch2NftMedal({
    required this.ticker,
    required this.bottomLabel,
    required this.brass,
    super.key,
    this.logoUrl,
    this.identity,
    this.size = 152,
  });

  final String ticker;
  final String? logoUrl;
  final String? identity;

  /// 「#tokenId」 or 「共识勋章」.
  final String bottomLabel;
  final bool brass;
  final double size;

  static const double logoSize = 56;

  @override
  Widget build(BuildContext context) {
    final tone = brass ? LoopColors.brass : LoopColors.text3;
    return Semantics(
      image: true,
      label: '$ticker 共识勋章，$bottomLabel',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MedalPainter(
            tone: tone,
            top: launch2HeroTicker(ticker),
            bottom: bottomLabel,
          ),
          child: Center(
            child: MemeLogo(
              symbol: ticker,
              imageUrl: logoUrl,
              identity: identity,
              size: logoSize,
              radius: logoSize / 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter({
    required this.tone,
    required this.top,
    required this.bottom,
  });

  final Color tone;
  final String top;
  final String bottom;

  /// Where the arc text runs, inside the outer ring.
  static const double _band = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas
      ..drawCircle(center, radius - 1, Paint()..color = LoopColors.graphite)
      ..drawCircle(
        center,
        radius - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = tone,
      )
      ..drawCircle(
        center,
        radius - _band * 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = tone.withValues(alpha: 0.35),
      );
    final style = LoopTypography.figure(
      11,
      weight: FontWeight.w600,
      color: tone,
    ).copyWith(letterSpacing: 0);
    final textRadius = radius - _band;
    _arc(canvas, center, textRadius, top, style, upper: true);
    _arc(canvas, center, textRadius, bottom, style, upper: false);
  }

  /// Lays [text] along the circle of [radius], centred on the top or the
  /// bottom, upright and reading left to right on both arcs.
  static void _arc(
    Canvas canvas,
    Offset center,
    double radius,
    String text,
    TextStyle style, {
    required bool upper,
  }) {
    if (text.isEmpty) return;
    const gap = 1.5;
    final glyphs = <TextPainter>[
      for (final rune in text.runes)
        TextPainter(
          text: TextSpan(text: String.fromCharCode(rune), style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final length =
        glyphs.fold<double>(0, (sum, glyph) => sum + glyph.width) +
        gap * (glyphs.length - 1);
    final sweep = length / radius;
    var angle = upper ? -math.pi / 2 - sweep / 2 : math.pi / 2 + sweep / 2;
    for (final glyph in glyphs) {
      final step = glyph.width / radius;
      final mid = upper ? angle + step / 2 : angle - step / 2;
      canvas
        ..save()
        ..translate(
          center.dx + radius * math.cos(mid),
          center.dy + radius * math.sin(mid),
        )
        ..rotate(upper ? mid + math.pi / 2 : mid - math.pi / 2);
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
      final advance = (glyph.width + gap) / radius;
      angle = upper ? angle + advance : angle - advance;
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.tone != tone || old.top != top || old.bottom != bottom;
}
