import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

/// Rebuilds [builder] every second with the time left until [target], read
/// against the one [launch2ClockProvider].
///
/// Only what [builder] returns redraws; the row or the page around it does
/// not. When the time passes it calls [onElapsed] once — the page re-reads
/// the server, it never moves the stage itself — and holds at zero.
class Launch2CountdownBuilder extends ConsumerStatefulWidget {
  const Launch2CountdownBuilder({
    required this.target,
    required this.builder,
    super.key,
    this.onElapsed,
  });

  final DateTime target;

  /// [text] is [launch2CountdownText] of the time left.
  final Widget Function(BuildContext context, String text) builder;
  final VoidCallback? onElapsed;

  @override
  ConsumerState<Launch2CountdownBuilder> createState() =>
      _Launch2CountdownBuilderState();
}

class _Launch2CountdownBuilderState
    extends ConsumerState<Launch2CountdownBuilder> {
  Timer? _ticker;
  bool _elapsedReported = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(Launch2CountdownBuilder old) {
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
  Widget build(BuildContext context) =>
      widget.builder(context, launch2CountdownText(_remaining));
}

/// A countdown to a server time (`nextChangeAt`) as one line of tabular
/// figures ([Launch2CountdownBuilder]).
class Launch2Countdown extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // R6 by default (decision 0190).
    final style = this.style ?? LoopType.figure;
    return Launch2CountdownBuilder(
      target: target,
      onElapsed: onElapsed,
      builder: (context, text) => Text(
        '$prefix$text',
        key: const ValueKey<String>('launch2-countdown'),
        maxLines: 1,
        softWrap: false,
        style: style.copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The stage in the quote row's fixed 96 × 44 slot. Lime only marks the two
/// stages that take orders and the graduated one; every waiting stage sits on
/// the card ground in grey (S121 §1.1.1 rule 3). Decision 0166: 已暂停 is
/// grey like them (was the v1 warning yellow) and the corner is
/// [LoopRadius.inner].
class Launch2StagePill extends StatelessWidget {
  const Launch2StagePill({required this.stage, super.key});

  final Launch2Stage stage;

  @override
  Widget build(BuildContext context) {
    final size = loopChangePillSize;
    // S241b (decision 0210): the stages that take orders are a Yellow frame
    // with a Yellow word, 已毕业 a Purple tag, every waiting stage grey.
    final tone = switch (stage) {
      Launch2Stage.priority || Launch2Stage.public => MemeTagTone.live,
      Launch2Stage.graduated => MemeTagTone.done,
      _ => MemeTagTone.idle,
    };
    final ink = memeTagInk(tone);
    return Container(
      key: ValueKey<String>('launch2-stage-pill-${stage.wireName}'),
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: memeTagDecoration(tone),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (stage == Launch2Stage.graduated) ...<Widget>[
            const LoopIcon('graduate', size: 16, color: LoopColors.purple),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                launch2StageLabel(stage),
                maxLines: 1,
                style: LoopTypography.withWeight(
                  LoopType.titleSm,
                  FontWeight.w600,
                ).copyWith(color: ink),
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
    '${row.name} ${loopTickerLabel(row.ticker)}',
    launch2StageLabel(row.stage),
    switch (row.stage) {
      Launch2Stage.upcoming => left == null ? '铸造时间待定' : '距铸造 $left',
      Launch2Stage.nftSale =>
        '已铸 ${row.nftSale.soldCount}${left == null ? '' : '，剩余 $left'}',
      Launch2Stage.snapshotPending => '已铸 ${row.nftSale.soldCount}',
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

/// A project-page section's `.label` (decision 0166, replacing decision
/// 0149's 20 / 700 headings): [LoopLabel] with, at its end, one quiet
/// [trailing] widget (a badge, a tax, a count) and/or an (i) [info] button.
/// Without either it is exactly [LoopLabel].
class Launch2SectionLabel extends StatelessWidget {
  const Launch2SectionLabel(this.title, {super.key, this.info, this.trailing});

  final String title;

  /// A 44 dp icon button at the end of the label's line.
  final Widget? info;
  final Widget? trailing;

  /// With [info], the label stands this much higher in the row so the 48 dp
  /// box's centre sits on the 10 px label's centre (24 = 9 + 8 + 7).
  static const double _infoLift = 9;

  /// Android's minimum tap target.
  static const double _infoBox = 48;

  @override
  Widget build(BuildContext context) {
    final info = this.info;
    final trailing = this.trailing;
    if (info == null && trailing == null) return LoopLabel(title);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: info == null
              ? LoopLabel(title)
              : Padding(
                  padding: const EdgeInsets.only(bottom: _infoLift),
                  child: LoopLabel(title),
                ),
        ),
        if (trailing != null)
          Padding(
            padding: EdgeInsets.only(
              right: info == null ? LoopSpacing.page : 0,
              bottom: info == null ? LoopSpacing.tight : 15,
            ),
            child: trailing,
          ),
        if (info != null)
          // The 44 dp control in a box of at least 48 dp that answers for
          // it, so the label's (i) meets the Android tap-target size.
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: MergeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _infoBox,
                  minHeight: _infoBox,
                ),
                child: Align(child: info),
              ),
            ),
          ),
      ],
    );
  }
}

/// One warning line inside a block (decision 0166): the warn glyph in the
/// accent (Lime then, Yellow since decision 0210 — the v1 warning colour
/// stays out of features, decision 0172) and the sentence in Text2. It replaces
/// the v1 warning-yellow glyph and text of the trade panels and the failure
/// line above a button.
class Launch2WarnLine extends StatelessWidget {
  const Launch2WarnLine(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: LoopIcon('warn', size: 15, color: LoopColors.yellow),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          message,
          style: LoopType.caption.copyWith(color: LoopColors.text2),
        ),
      ),
    ],
  );
}

/// One v2 row in the OKX quote shape (S121 §1.1.1): logo 36 · ticker over
/// name · two stage lines on the right · the stage pill in the fixed slot.
///
/// The right two lines follow the stage: 铸造倒计时 while upcoming, NFT 已售
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
    // The quote row's steps (decision 0190 M22): its value `figureMd`, a
    // figure under it `figureSm`, a word under it R5 `caption`.
    final figure = LoopType.figureMd.copyWith(color: LoopGround.inkOf(context));
    final words = LoopType.caption.copyWith(color: LoopColors.text2);
    Widget countdown(String prefix) => next == null
        ? Text('$prefix待定', style: words)
        : Launch2Countdown(
            target: next,
            prefix: prefix,
            onElapsed: onElapsed,
            style: LoopType.figureSm,
          );
    final (String? value, Widget caption) = switch (row.stage) {
      Launch2Stage.upcoming => (
        null,
        next == null
            ? countdown('铸造 ')
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
                  Text('后开始铸造', style: words),
                ],
              ),
      ),
      Launch2Stage.nftSale => ('已铸 ${row.nftSale.soldCount}', countdown('剩 ')),
      Launch2Stage.snapshotPending => (
        '已铸 ${row.nftSale.soldCount}',
        Text('名单生成中', style: words),
      ),
      // Grey like every waiting stage; no figure, nothing counts down.
      Launch2Stage.closedNoHolders => (
        null,
        Text(
          launch2ClosedNoHoldersText,
          key: const ValueKey<String>('launch2-row-closed'),
          style: words,
        ),
      ),
      Launch2Stage.priority || Launch2Stage.public => (
        launch2BpsLabel(row.curve.soldBps),
        Text(
          launch2PriceLabel(row.curve.priceUsd1),
          key: const ValueKey<String>('launch2-row-price'),
          style: LoopType.figureSm,
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
          style: words,
        ),
      ),
      Launch2Stage.paused => ('已暂停', Text('平台核对中', style: words)),
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

/// The chain guard's hold above the trade panels (decision 0161): USD1 is
/// paused by its issuer or our contract address is frozen by it, so nothing
/// that moves USD1 can succeed on chain. Two lines may be taken so the
/// frozen sentence is never cut at 360 dp; the second says since when.
class Launch2TradingHoldBanner extends StatelessWidget {
  const Launch2TradingHoldBanner({
    required this.hold,
    super.key = const ValueKey<String>('launch2-trading-hold'),
  });

  final Launch2TradingHold hold;

  @override
  Widget build(BuildContext context) => LoopInlineUnavailable(
    message: launch2TradingHoldText(hold.kind),
    maxLines: 2,
    detail: switch (hold.since) {
      final DateTime since => launch2TradingHoldSinceText(since),
      null => null,
    },
  );
}

/// The same sentence under a disabled confirm key (decision 0161).
class Launch2TradingHoldLine extends StatelessWidget {
  const Launch2TradingHoldLine({
    required this.hold,
    super.key,
    this.padding = const EdgeInsets.only(top: 8),
  });

  final Launch2TradingHold hold;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      launch2TradingHoldText(hold.kind),
      style: LoopType.caption.copyWith(color: LoopColors.text2),
    ),
  );
}

/// One failed action, right above the button that started it (client
/// decision 0153): the reason with its figures, wrapping instead of
/// truncating, and 「去充值」 under a balance refusal.
///
/// It is a live region, so a screen reader says it the moment it appears —
/// the button under it went back to its label and would say nothing.
///
/// Decision 0154: next to 「去充值」 a 「领取测试币」 link opens the testnet
/// faucet sheet. The caller passes [onFaucet] only while the server publishes
/// `testnetFaucet` as available; it is never drawn without 「去充值」.
class Launch2ActionFailureLine extends StatelessWidget {
  const Launch2ActionFailureLine({
    required this.message,
    super.key,
    this.onTopUp,
    this.topUpKey = const ValueKey<String>('launch2-topup'),
    this.onFaucet,
    this.faucetKey = const ValueKey<String>('launch2-faucet'),
    this.padding = EdgeInsets.zero,
  });

  final String message;

  /// Opens the wallet's receive page. `null` shows no link.
  final VoidCallback? onTopUp;
  final Key topUpKey;

  /// Opens the testnet faucet sheet. `null` shows no link.
  final VoidCallback? onFaucet;
  final Key faucetKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final topUp = onTopUp;
    final faucet = topUp == null ? null : onFaucet;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            container: true,
            child: Launch2WarnLine(message),
          ),
          if (topUp != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 23),
                child: Wrap(
                  children: <Widget>[
                    _FailureLink(key: topUpKey, label: '去充值', onTap: topUp),
                    if (faucet != null)
                      _FailureLink(
                        key: faucetKey,
                        label: '获取资金',
                        onTap: faucet,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One secondary link under a failure line: label + chevron, 44 dp tall.
class _FailureLink extends StatelessWidget {
  const _FailureLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: LoopPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // R17 inline text action (decision 0190 L23).
              Text(
                label,
                style: LoopTypography.withWeight(
                  LoopType.label,
                  FontWeight.w600,
                ).copyWith(color: LoopColors.text2),
              ),
              const SizedBox(width: 2),
              const LoopIcon('chevron', size: 14, color: LoopColors.text3),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The bar pinned under a MEME v2 page's one action (project page
/// 「购买 NFT」, 共识勋章 「铸造」): Ink with a hairline over it, the last refusal
/// right above the button.
class Launch2BarShell extends StatelessWidget {
  const Launch2BarShell({required this.child, super.key, this.failure});

  final Widget child;

  /// The last refusal of [child]'s action, directly above it, so it shows
  /// wherever the page is scrolled (decision 0153).
  final Widget? failure;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: LoopColors.ink,
      border: Border(top: BorderSide(color: LoopColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (failure case final Widget line) ...<Widget>[
              line,
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}

/// 名单已发布 (decision 0202): what the published snapshot list says without
/// its addresses (loop-api decision 0118 never sends them) — how many are on
/// it, when it was published, whether it was verified, and its publication
/// transaction on BscScan, opened in the system browser. Drawn on the
/// project page and the 共识勋章 page from 提前购 on.
class Launch2SnapshotPublishedBlock extends ConsumerWidget {
  const Launch2SnapshotPublishedBlock({required this.detail, super.key});

  final Launch2InstanceDetail detail;

  static const EdgeInsets _kvPadding = EdgeInsets.symmetric(vertical: 6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = detail.snapshot;
    final publication = snapshot.publication;
    final members = snapshot.memberCount ?? publication?.memberCount;
    final at = snapshot.publishedAt;
    final verification = launch2SnapshotVerificationText(snapshot.verification);
    final hash = publication?.txHash;
    final explorer = launch2ExplorerTxUri(detail.row.chainId, hash);
    return Column(
      key: const ValueKey<String>('launch2-snapshot-published'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const LoopLabel('名单已发布'),
        LoopRecordCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (members != null)
                LoopKeyValue(
                  key: const ValueKey<String>('launch2-snapshot-members'),
                  padding: _kvPadding,
                  label: '名单人数',
                  value: '$members 人',
                ),
              if (at != null)
                LoopKeyValue(
                  key: const ValueKey<String>('launch2-snapshot-published-at'),
                  padding: _kvPadding,
                  label: '发布时间',
                  value: loopDateTimeLabel(at),
                ),
              if (verification != null)
                LoopKeyValue(
                  key: const ValueKey<String>('launch2-snapshot-verification'),
                  padding: _kvPadding,
                  label: '核验',
                  value: verification,
                ),
              if (hash != null)
                LoopKeyValue(
                  key: const ValueKey<String>('launch2-snapshot-tx'),
                  padding: _kvPadding,
                  label: '发布交易',
                  value: launch2ShortAddress(hash),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '名单地址不在 App 内列出，可在发布交易里核对。',
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
              ),
            ],
          ),
        ),
        if (explorer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              LoopSpacing.card,
            ),
            child: LoopButton(
              key: const ValueKey<String>('launch2-snapshot-explorer'),
              label: '在 BscScan 查看发布交易',
              icon: 'link',
              block: true,
              onPressed: () => unawaited(
                ref.read(launch2ExternalLinkOpenerProvider)(context, explorer),
              ),
            ),
          ),
      ],
    );
  }
}
