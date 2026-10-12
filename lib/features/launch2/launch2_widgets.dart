import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

/// A countdown to a server time (`nextChangeAt`), read against the one
/// [launch2ClockProvider].
///
/// Only this text rebuilds every second; the row or the page around it does
/// not. When the time passes it calls [onElapsed] once — the page re-reads
/// the server, it never moves the stage itself — and holds at `00:00`.
class Launch2Countdown extends ConsumerStatefulWidget {
  const Launch2Countdown({
    required this.target,
    super.key,
    this.style,
    this.prefix = '',
    this.onElapsed,
  });

  final DateTime target;
  final TextStyle? style;
  final String prefix;
  final VoidCallback? onElapsed;

  @override
  ConsumerState<Launch2Countdown> createState() => _Launch2CountdownState();
}

class _Launch2CountdownState extends ConsumerState<Launch2Countdown> {
  Timer? _ticker;
  bool _elapsedReported = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(Launch2Countdown old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _elapsedReported = false;
      _arm();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _remaining =>
      widget.target.difference(ref.read(launch2ClockProvider)());

  void _arm() {
    _ticker?.cancel();
    _ticker = null;
    if (_remaining.isNegative || _remaining == Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _remaining;
      if (left.isNegative || left == Duration.zero) {
        _ticker?.cancel();
        _ticker = null;
        _report();
      }
      setState(() {});
    });
  }

  void _report() {
    if (_elapsedReported) return;
    _elapsedReported = true;
    widget.onElapsed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final text = launch2CountdownText(_remaining);
    final style =
        widget.style ??
        LoopTypography.figure(14, weight: FontWeight.w600, height: 1.2);
    return Text(
      '${widget.prefix}$text',
      key: const ValueKey<String>('launch2-countdown'),
      maxLines: 1,
      softWrap: false,
      style: style.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The stage in the quote row's fixed 96 × 44 slot. Lime only marks the two
/// stages that take orders and the graduated one; every waiting stage sits on
/// the card ground in grey (S121 §1.1.1 rule 3).
class Launch2StagePill extends StatelessWidget {
  const Launch2StagePill({required this.stage, super.key});

  final Launch2Stage stage;

  @override
  Widget build(BuildContext context) {
    final size = loopChangePillSize;
    final lit =
        stage == Launch2Stage.priority ||
        stage == Launch2Stage.public ||
        stage == Launch2Stage.graduated;
    final paused = stage == Launch2Stage.paused;
    return Container(
      key: ValueKey<String>('launch2-stage-pill-${stage.wireName}'),
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: lit ? LoopColors.limeSoft : LoopColors.card2,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (stage == Launch2Stage.graduated) ...<Widget>[
            const LoopIcon('graduate', size: 16, color: LoopColors.lime),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                launch2StageLabel(stage),
                maxLines: 1,
                style: LoopTypography.title(
                  14,
                  color: lit
                      ? LoopColors.lime
                      : paused
                      ? LoopColors.warning
                      : LoopColors.text2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a v2 list row says aloud.
String launch2RowSpokenLabel(Launch2InstanceRow row, DateTime now) {
  final next = row.nextChangeAt;
  final left = next == null ? null : launch2CountdownText(next.difference(now));
  return <String>[
    '${row.name} \$${row.ticker}',
    launch2StageLabel(row.stage),
    switch (row.stage) {
      Launch2Stage.upcoming => left == null ? '开售时间待定' : '距开售 $left',
      Launch2Stage.nftSale =>
        'NFT 已售 ${row.nftSale.soldCount}${left == null ? '' : '，剩余 $left'}',
      Launch2Stage.snapshotPending => 'NFT 已售 ${row.nftSale.soldCount}',
      Launch2Stage.closedNoHolders => launch2ClosedNoHoldersText,
      Launch2Stage.priority || Launch2Stage.public =>
        '内盘进度 ${launch2BpsLabel(row.curve.soldBps)}，'
            '当前价 ${launch2PriceLabel(row.curve.priceUsd1)}',
      Launch2Stage.graduated => '毕业价 ${launch2PriceLabel(row.curve.priceUsd1)}',
      Launch2Stage.paused => launch2HoldReasonText(row.holdReason),
    },
  ].join('，');
}

/// Eight ticker characters at the quote row's 18 px Sora title (decision 0146;
/// Sora caps and digits advance about 0.62 em).
const double launch2TickerMinWidth = 92;

/// The project page's section heading (官方池 / 回购 / 发射规则 and the
/// two trade panels): one size for every section of the page (decision 0149;
/// the panels were 18 / 600 between 20 / 700 neighbours).
TextStyle get launch2PanelHeadingStyle =>
    LoopTypography.title(20, weight: FontWeight.w700);

/// Distance above a trade panel's heading: a section's break from the
/// figures before it (decision 0149; was 4, the readings ran into the
/// heading).
const double launch2PanelTopGap = 24;

/// One v2 row in the OKX quote shape (S121 §1.1.1): logo 36 · ticker over
/// name · two stage lines on the right · the stage pill in the fixed slot.
///
/// The right two lines follow the stage: 开售倒计时 while upcoming, NFT 已售
/// and the sale's countdown, the curve's progress and price while it trades,
/// the last curve price over 毕业价 once graduated. Only the countdown text
/// redraws every second.
class Launch2InstanceTile extends ConsumerWidget {
  const Launch2InstanceTile({
    required this.row,
    super.key,
    this.onTap,
    this.onElapsed,
  });

  final Launch2InstanceRow row;
  final VoidCallback? onTap;

  /// The row's countdown reached zero: the list re-reads the server.
  final VoidCallback? onElapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(launch2ClockProvider)();
    final next = row.nextChangeAt;
    final figure = LoopTypography.figure(
      18,
      weight: FontWeight.w700,
      color: LoopGround.inkOf(context),
    );
    Widget countdown(String prefix) => next == null
        ? Text(
            '$prefix待定',
            style: LoopTypography.body(14, color: LoopColors.text2),
          )
        : Launch2Countdown(
            target: next,
            prefix: prefix,
            onElapsed: onElapsed,
            style: LoopTypography.body(14, color: LoopColors.text2),
          );
    final (String? value, Widget caption) = switch (row.stage) {
      Launch2Stage.upcoming => (
        null,
        next == null
            ? countdown('开售 ')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Launch2Countdown(
                    target: next,
                    onElapsed: onElapsed,
                    style: figure,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '后开售',
                    style: LoopTypography.body(14, color: LoopColors.text2),
                  ),
                ],
              ),
      ),
      Launch2Stage.nftSale => (
        'NFT 已售 ${row.nftSale.soldCount}',
        countdown('剩 '),
      ),
      Launch2Stage.snapshotPending => (
        'NFT 已售 ${row.nftSale.soldCount}',
        Text('名单生成中', style: LoopTypography.body(14, color: LoopColors.text2)),
      ),
      // Grey like every waiting stage; no figure, nothing counts down.
      Launch2Stage.closedNoHolders => (
        null,
        Text(
          launch2ClosedNoHoldersText,
          key: const ValueKey<String>('launch2-row-closed'),
          style: LoopTypography.body(14, color: LoopColors.text2),
        ),
      ),
      Launch2Stage.priority || Launch2Stage.public => (
        launch2BpsLabel(row.curve.soldBps),
        Text(
          launch2PriceLabel(row.curve.priceUsd1),
          key: const ValueKey<String>('launch2-row-price'),
          style: LoopTypography.body(14, color: LoopColors.text2),
        ),
      ),
      // Decision 0146: the pill already says 已毕业, so the figure column
      // carries the graduation price over its caption and gives way to the
      // ticker (titleMinWidth below).
      Launch2Stage.graduated => (
        launch2PriceLabel(row.curve.priceUsd1),
        Text(
          '毕业价',
          key: const ValueKey<String>('launch2-row-price'),
          style: LoopTypography.body(14, color: LoopColors.text2),
        ),
      ),
      Launch2Stage.paused => (
        '已暂停',
        Text('平台核对中', style: LoopTypography.body(14, color: LoopColors.text2)),
      ),
    };
    return LoopQuoteRow(
      tapKey: ValueKey<String>('launch2-row-${row.instanceId}'),
      leading: MemeLogo(
        symbol: row.ticker,
        imageUrl: row.logoUrl,
        identity: row.instanceId,
        size: memeCardLogoSize,
        radius: memeCardLogoSize / 2,
      ),
      title: row.ticker,
      subtitle: row.name,
      value: value,
      valueKey: ValueKey<String>('launch2-row-value-${row.instanceId}'),
      valueCaption: caption,
      trailing: Launch2StagePill(stage: row.stage),
      // Decision 0146: a graduated row keeps eight ticker characters; the
      // other stages are drawn as before.
      titleMinWidth: row.stage == Launch2Stage.graduated
          ? launch2TickerMinWidth
          : null,
      onTap: onTap,
      semanticLabel: launch2RowSpokenLabel(row, now),
    );
  }
}

/// The luminance-preserving greyscale every greyed MEME v2 block is drawn
/// through (Rec. 709 weights).
const List<double> _greyscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// A block that is shown but not usable: drained of colour (Lime included)
/// and deaf to touches, its text left at full contrast so the reader still
/// reads what opens later. Fading it instead pushed the grey copy below the
/// legibility floor.
class Launch2Greyed extends StatelessWidget {
  const Launch2Greyed({required this.greyed, required this.child, super.key});

  final bool greyed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!greyed) return child;
    return IgnorePointer(
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscale),
        child: child,
      ),
    );
  }
}

/// One failed action, right above the button that started it (client
/// decision 0153): the reason with its figures, wrapping instead of
/// truncating, and 「去充值」 under a balance refusal.
///
/// It is a live region, so a screen reader says it the moment it appears —
/// the button under it went back to its label and would say nothing.
class Launch2ActionFailureLine extends StatelessWidget {
  const Launch2ActionFailureLine({
    required this.message,
    super.key,
    this.onTopUp,
    this.topUpKey = const ValueKey<String>('launch2-topup'),
    this.padding = EdgeInsets.zero,
  });

  final String message;

  /// Opens the wallet's receive page. `null` shows no link.
  final VoidCallback? onTopUp;
  final Key topUpKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final topUp = onTopUp;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            container: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: LoopIcon('warn', size: 15, color: LoopColors.warning),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: LoopType.caption.copyWith(color: LoopColors.warning),
                  ),
                ),
              ],
            ),
          ),
          if (topUp != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: '去充值',
                excludeSemantics: true,
                child: LoopPressable(
                  key: topUpKey,
                  onTap: topUp,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: LoopTouch.minimum,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 23, right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '去充值',
                            style: LoopType.caption.copyWith(
                              color: LoopColors.text2,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const LoopIcon(
                            'chevron',
                            size: 14,
                            color: LoopColors.text3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
