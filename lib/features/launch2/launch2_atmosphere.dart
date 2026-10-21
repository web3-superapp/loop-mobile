import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// MEME 主页 · 氛围层 (S264, decision 0220 — the S262 design A, plus the
// preview empty state, the chrome default avatar and the drip bar)
// ---------------------------------------------------------------------------
//
// Everything here draws on the MEME home alone: the still wall under the
// page, the crown behind the title, the chrome hand's sheen, the Purple live
// trade band, the stage chips, the numbered section headings, the project
// board and its rows. Data comes from the same reads the desk already makes.

/// Whether the home's looping motion (the trade band, the hand's sheen) runs
/// at all. The system's reduced-motion setting always stops it too; widget
/// tests turn it off so a settling pump has an end.
final launch2AmbientMotionProvider = Provider<bool>((ref) => true);

/// Whether looping motion may run in [context].
bool launch2AmbientMotion(BuildContext context, WidgetRef ref) =>
    ref.watch(launch2AmbientMotionProvider) && !LoopMotion.reduced(context);

/// Decodes every atmosphere piece ahead of the home's first frame, so none of
/// them pops in after the page.
void launch2PrecacheAtmosphere(BuildContext context) =>
    loopPrecacheAtmosphere(context);

/// A decorative asset image: no semantics, no gap while it loads.
Widget _art(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  Key? key,
}) => loopAtmoArt(path, width: width, height: height, fit: fit, key: key);

// ---- the wall -------------------------------------------------------------

/// The still layer under the MEME home (decision 0220): the shared
/// [LoopWallBackdrop] with the MEME fog — Purple top left, Yellow bottom
/// right.
class Launch2AtmosphereBackdrop extends StatelessWidget {
  const Launch2AtmosphereBackdrop({
    super.key = const ValueKey<String>('launch2-atmo-backdrop'),
  });

  /// The design's reference width; the fog sizes scale with the screen.
  static const double referenceWidth = LoopWallBackdrop.referenceWidth;

  @override
  Widget build(BuildContext context) =>
      const LoopWallBackdrop(keyPrefix: 'launch2-atmo');
}

/// The MEME title with the wall crown peeking out behind it (60 %, −8°).
class Launch2AtmoTitle extends StatelessWidget {
  const Launch2AtmoTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => LoopAtmoTitle(
    title: title,
    crownKey: const ValueKey<String>('launch2-atmo-title-crown'),
  );
}

// ---- the chrome hand ------------------------------------------------------

/// The banner's chrome hand; every 6 s a light band sweeps across it (the
/// first 35 % of the cycle), never under reduced motion.
class Launch2ChromeHand extends ConsumerStatefulWidget {
  const Launch2ChromeHand({super.key});

  static const Duration cycle = Duration(seconds: 6);

  @override
  ConsumerState<Launch2ChromeHand> createState() => _Launch2ChromeHandState();
}

class _Launch2ChromeHandState extends ConsumerState<Launch2ChromeHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: Launch2ChromeHand.cycle,
  );

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = launch2AmbientMotion(context, ref);
    if (moving && !_sheen.isAnimating) {
      unawaited(_sheen.repeat());
    } else if (!moving && _sheen.isAnimating) {
      _sheen.stop();
    }
    final hand = DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 10),
            spreadRadius: -18,
          ),
        ],
      ),
      child: _art(LoopAtmoAssets.handChrome, fit: BoxFit.contain),
    );
    if (!moving) {
      return KeyedSubtree(
        key: const ValueKey<String>('launch2-atmo-hand'),
        child: hand,
      );
    }
    return AnimatedBuilder(
      key: const ValueKey<String>('launch2-atmo-hand'),
      animation: _sheen,
      child: hand,
      builder: (context, child) {
        final t = _sheen.value / 0.35;
        if (t >= 1) return child!;
        // 120 % → −20 % of a 300 %-wide band, eased like the design.
        final p = 1.2 - 1.4 * Curves.easeInOut.transform(t);
        return ShaderMask(
          key: const ValueKey<String>('launch2-atmo-hand-sheen'),
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) =>
              const LinearGradient(
                colors: <Color>[
                  Color(0x00FFFFFF),
                  Color(0x8CFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: <double>[0.42, 0.5, 0.58],
                transform: GradientRotation(15 * math.pi / 180),
              ).createShader(
                Rect.fromLTWH(
                  bounds.left - 2 * bounds.width * p,
                  bounds.top,
                  3 * bounds.width,
                  bounds.height,
                ),
              ),
          child: child,
        );
      },
    );
  }
}

// ---- the live trade band ----------------------------------------------------

/// The Purple band under the banner (replaces the three-line 实时 card): the
/// newest trades run left in one line; 「● 实时」 holds the left end and
/// 「全部 ›」 the right, behind a Purple fade. With no trade the band says
/// 「暂无成交」 and stands still.
class Launch2TradeTicker extends ConsumerStatefulWidget {
  const Launch2TradeTicker({
    required this.items,
    required this.onOpenAll,
    super.key = const ValueKey<String>('launch2-ticker'),
  });

  /// Newest first, already cut to what the band shows.
  final List<Launch2Activity> items;

  /// 「全部」: the full list of recent trades.
  final VoidCallback onOpenAll;

  /// The band's height inside its 44 dp tap row.
  static const double bandHeight = 36;

  /// How far the line moves per second.
  static const double speed = 24;

  @override
  ConsumerState<Launch2TradeTicker> createState() => _Launch2TradeTickerState();
}

class _Launch2TradeTickerState extends ConsumerState<Launch2TradeTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this);
  final GlobalKey _setKey = GlobalKey(debugLabel: 'launch2-ticker-set');
  double? _setWidth;

  @override
  void didUpdateWidget(covariant Launch2TradeTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameItems(oldWidget.items, widget.items)) {
      _setWidth = null;
      _run.stop();
      _run.value = 0;
    }
  }

  static bool _sameItems(List<Launch2Activity> a, List<Launch2Activity> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].transactionHash != b[i].transactionHash ||
          a[i].kind != b[i].kind ||
          a[i].at != b[i].at) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final box = _setKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final width = box.size.width;
    if (width <= 0) return;
    if (_setWidth == width) return;
    setState(() => _setWidth = width);
  }

  void _drive(bool moving) {
    final width = _setWidth;
    if (!moving || width == null) {
      if (_run.isAnimating) _run.stop();
      return;
    }
    final duration = Duration(
      milliseconds: (width / Launch2TradeTicker.speed * 1000).round(),
    );
    if (_run.duration != duration) {
      _run.duration = duration;
      if (_run.isAnimating) _run.stop();
    }
    if (!_run.isAnimating) unawaited(_run.repeat());
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final moving = items.isNotEmpty && launch2AmbientMotion(context, ref);
    if (items.isNotEmpty && _setWidth == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
    }
    _drive(moving);
    final now = ref.read(launch2ClockProvider)();
    final spoken = items.isEmpty
        ? '实时成交，暂无成交'
        : '实时成交，${items.map(launch2ActivityText).take(3).join('；')}';
    return SizedBox(
      height: 44,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: (44 - Launch2TradeTicker.bandHeight) / 2,
            height: Launch2TradeTicker.bandHeight,
            child: ColoredBox(
              key: const ValueKey<String>('launch2-ticker-band'),
              color: LoopColors.purple,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 12),
                  const _LiveLabel(),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Semantics(
                      label: spoken,
                      excludeSemantics: true,
                      child: items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '暂无成交',
                                  key: const ValueKey<String>(
                                    'launch2-ticker-empty',
                                  ),
                                  style: LoopTypography.withWeight(
                                    LoopType.bodySm,
                                    FontWeight.w500,
                                  ).copyWith(color: LoopColors.onPurple),
                                ),
                              ),
                            )
                          : _rail(items, now),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (items.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Semantics(
                button: true,
                label: '全部实时成交',
                excludeSemantics: true,
                child: LoopPressable(
                  key: const ValueKey<String>('launch2-ticker-all'),
                  onTap: widget.onOpenAll,
                  scale: false,
                  child: Center(
                    child: Container(
                      height: Launch2TradeTicker.bandHeight,
                      constraints: const BoxConstraints(
                        minWidth: LoopTouch.minimum,
                      ),
                      padding: const EdgeInsets.fromLTRB(34, 0, 10, 0),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0x009C36FF), LoopColors.purple],
                          stops: <double>[0, 0.4],
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '全部',
                            style: LoopTypography.withWeight(
                              LoopType.label,
                              FontWeight.w600,
                            ).copyWith(color: LoopColors.onPurple),
                          ),
                          const SizedBox(width: 1),
                          const LoopIcon(
                            'chevron',
                            size: 14,
                            color: LoopColors.onPurple,
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

  Widget _rail(List<Launch2Activity> items, DateTime now) => LayoutBuilder(
    builder: (context, constraints) {
      final setWidth = _setWidth;
      final copies = setWidth == null
          ? 2
          : (constraints.maxWidth / setWidth).ceil() + 1;
      Widget set({Key? key}) => Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final item in items) ...<Widget>[
            _TickerItem(item: item),
            const _TickerStar(),
          ],
        ],
      );
      final line = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          set(key: _setKey),
          for (var i = 1; i < copies; i++) ExcludeSemantics(child: set()),
        ],
      );
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: const <Color>[Color(0x00000000), Color(0xFF000000)],
          stops: <double>[0, (18 / bounds.width).clamp(0.0, 1.0)],
        ).createShader(bounds),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              key: const ValueKey<String>('launch2-ticker-rail'),
              animation: _run,
              child: line,
              builder: (context, child) => Transform.translate(
                offset: Offset(-(setWidth ?? 0) * _run.value, 0),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 「● 实时」: the Ink capsule fixed at the band's left end.
class _LiveLabel extends StatelessWidget {
  const _LiveLabel();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('launch2-ticker-live'),
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      color: LoopColors.ink,
      borderRadius: LoopRadius.pill,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: LoopColors.rise,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: Color(0x3822C55E), spreadRadius: 3),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text('实时', style: LoopType.label.copyWith(color: LoopColors.chalk)),
      ],
    ),
  );
}

/// One trade on the band: who, the verb on a small Ink ground (Purple would
/// swallow the rise / fall colour), the ticker, the amount and USD1. Every
/// other kind is its one sentence.
class _TickerItem extends StatelessWidget {
  const _TickerItem({required this.item});

  final Launch2Activity item;

  @override
  Widget build(BuildContext context) {
    final words = LoopTypography.withWeight(
      LoopType.bodySm,
      FontWeight.w500,
    ).copyWith(color: LoopColors.onPurple);
    final verb = switch (item.kind) {
      Launch2ActivityKind.curveBuy => ('买入', LoopColors.rise),
      Launch2ActivityKind.curveSell => ('卖出', LoopColors.fall),
      _ => null,
    };
    final amount = item.amountUsd1;
    final children = verb == null
        ? <Widget>[Text(launch2ActivityText(item), style: words)]
        : <Widget>[
            Text(launch2ActivityWho(item).trim(), style: words),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: const BoxDecoration(
                color: LoopColors.ink,
                borderRadius: LoopRadius.badge,
              ),
              child: Text(
                verb.$1,
                style: LoopType.kicker.copyWith(color: verb.$2, height: 1),
              ),
            ),
            Text(
              item.ticker,
              style: LoopTypography.withWeight(
                LoopType.figure,
                FontWeight.w600,
              ).copyWith(color: LoopColors.onPurple),
            ),
            if (amount != null) ...<Widget>[
              Text(
                launch2Usd1Label(amount).replaceAll(' USD1', ''),
                style: LoopType.tickerFigure.copyWith(
                  color: LoopColors.onPurple,
                ),
              ),
              Text(
                'USD1',
                style: LoopTypography.withWeight(
                  LoopType.figureXs,
                  FontWeight.w600,
                ).copyWith(color: const Color(0xCCFFFFFF)),
              ),
            ],
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The small Yellow star between two trades.
class _TickerStar extends StatelessWidget {
  const _TickerStar();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 2),
    child: CustomPaint(size: Size(12, 12), painter: _StarPainter()),
  );
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  static const List<Offset> _points = <Offset>[
    Offset(12, 1.5),
    Offset(14.2, 8.6),
    Offset(21.5, 7),
    Offset(16.4, 12.5),
    Offset(21.5, 18),
    Offset(14.2, 16.4),
    Offset(12, 22.5),
    Offset(9.8, 15.4),
    Offset(2.5, 17),
    Offset(7.6, 11.5),
    Offset(2.5, 6.9),
    Offset(9.8, 8.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final path = Path()
      ..addPolygon(<Offset>[for (final p in _points) p * k], true);
    canvas.drawPath(path, Paint()..color = LoopColors.yellow);
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => false;
}

// ---- the stage chips ----------------------------------------------------------

/// One stage chip of the home: its words, its count and whether it is on.
typedef Launch2ChipSpec = ({String id, String title, int count, bool selected});

/// The stage chips under the band: the chosen one Purple with white words
/// and a small Yellow splat on its top-left corner.
class Launch2StageChips extends StatelessWidget {
  const Launch2StageChips({
    required this.chips,
    required this.onSelected,
    super.key = const ValueKey<String>('launch2-desk-segs'),
  });

  final List<Launch2ChipSpec> chips;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      10,
      LoopSpacing.page,
      0,
    ),
    child: Row(
      children: <Widget>[
        for (final (index, chip) in chips.indexed) ...<Widget>[
          if (index > 0) const SizedBox(width: 8),
          _StageChip(chip: chip, onTap: () => onSelected(index)),
        ],
      ],
    ),
  );
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.chip, required this.onTap});

  final Launch2ChipSpec chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = chip.selected;
    final ink = on ? LoopColors.onPurple : LoopColors.text2;
    return Semantics(
      button: true,
      selected: on,
      label: '${chip.title} ${chip.count}',
      excludeSemantics: true,
      child: LoopPressable(
        key: ValueKey<String>('launch2-desk-seg-${chip.id}'),
        onTap: onTap,
        scale: false,
        child: SizedBox(
          height: LoopTouch.minimum,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? LoopColors.purple : null,
                    borderRadius: LoopRadius.pill,
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: chip.title),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: '${chip.count}',
                          style: LoopType.figure.copyWith(color: ink),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    style: LoopTypography.withWeight(
                      LoopType.titleSm,
                      FontWeight.w600,
                    ).copyWith(color: ink),
                  ),
                ),
                if (on)
                  Positioned(
                    left: -7,
                    top: -8,
                    width: 24,
                    child: LoopSplatSticker(
                      key: ValueKey<String>(
                        'launch2-desk-seg-splat-${chip.id}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- section headings -----------------------------------------------------------

/// 「01 内盘 … 全部 ›」: the shared [LoopSprayHeading] with its number.
class Launch2SectionHeading extends StatelessWidget {
  const Launch2SectionHeading({
    required this.index,
    required this.title,
    super.key,
    this.onMore,
  });

  final int index;
  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => LoopSprayHeading(
    index: index,
    title: title,
    onMore: onMore,
    moreKey: ValueKey<String>('launch2-section-more-$title'),
  );
}

// ---- the board -------------------------------------------------------------------

/// One card-ground board, 16 radius, its rows split by 1 px lines.
class Launch2Board extends LoopAtmoBoard {
  const Launch2Board({required super.children, super.key});
}

/// A project's 44 round face: its own logo when it has one, else the chrome
/// medal with the small crown (decision 0220 — no letter tiles any more).
class Launch2ProjectAvatar extends StatelessWidget {
  const Launch2ProjectAvatar({
    required this.identity,
    super.key,
    this.logoUrl,
    this.size = 44,
  });

  final String identity;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) => LoopChromeAvatar(
    size: size,
    logoUrl: logoUrl,
    medalKey: ValueKey<String>('launch2-avatar-chrome-$identity'),
    logoKey: ValueKey<String>('launch2-avatar-logo-$identity'),
  );
}

/// The 6 px Yellow progress bar; past 0 a Yellow drip hangs from its end.
class Launch2DripBar extends StatelessWidget {
  const Launch2DripBar({
    required this.fraction,
    required this.identity,
    super.key,
    this.width = 96,
  });

  final double fraction;
  final String identity;
  final double width;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey<String>('launch2-bar-$identity'),
    child: LoopDripBar(
      fraction: fraction,
      width: width,
      dripKey: ValueKey<String>('launch2-drip-$identity'),
    ),
  );
}

/// The stage capsule at a board row's right: Yellow on Yellow-soft while it
/// takes orders, Purple-soft with a light Purple word once graduated, grey
/// while it waits.
class Launch2BoardStage extends StatelessWidget {
  const Launch2BoardStage({required this.stage, super.key});

  final Launch2Stage stage;

  @override
  Widget build(BuildContext context) {
    final (Color ground, Color ink) = switch (stage) {
      Launch2Stage.priority ||
      Launch2Stage.public ||
      Launch2Stage.nftSale => (LoopColors.yellowSoft, LoopColors.yellow),
      Launch2Stage.graduated => (
        LoopColors.purpleCapsule,
        LoopColors.purpleInk,
      ),
      _ => (LoopColors.card2, LoopColors.text2),
    };
    return Container(
      key: ValueKey<String>('launch2-stage-pill-${stage.wireName}'),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ground, borderRadius: LoopRadius.pill),
      child: Text(
        launch2StageLabel(stage),
        maxLines: 1,
        style: LoopTypography.withWeight(
          LoopType.label,
          FontWeight.w600,
        ).copyWith(color: ink),
      ),
    );
  }
}

/// One 72 high board row: face, name and ticker over the bar (or the stage's
/// line), the stage capsule at the right.
class Launch2BoardRow extends ConsumerWidget {
  const Launch2BoardRow({
    required this.row,
    super.key,
    this.onTap,
    this.onElapsed,
  });

  final Launch2InstanceRow row;
  final VoidCallback? onTap;
  final VoidCallback? onElapsed;

  static const double height = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(launch2ClockProvider)();
    final id = row.instanceId;
    final next = row.nextChangeAt;
    final words = LoopType.caption.copyWith(color: LoopColors.text2);
    final pct = LoopTypography.withWeight(
      LoopType.figureSm,
      FontWeight.w700,
    ).copyWith(color: LoopColors.chalk);
    Widget countdown(String prefix) => next == null
        ? Text('$prefix待定', style: words)
        : Launch2Countdown(
            target: next,
            prefix: prefix,
            onElapsed: onElapsed,
            style: LoopType.figureSm,
          );
    final List<Widget> meta = switch (row.stage) {
      Launch2Stage.priority || Launch2Stage.public => <Widget>[
        Launch2DripBar(
          fraction: launch2Fraction(row.curve.soldBps),
          identity: id,
        ),
        Text(
          launch2BpsLabel(row.curve.soldBps),
          key: ValueKey<String>('launch2-row-value-$id'),
          style: pct,
        ),
        Flexible(
          child: Text(
            launch2PriceLabel(row.curve.priceUsd1),
            key: const ValueKey<String>('launch2-row-price'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopType.figureSm,
          ),
        ),
      ],
      Launch2Stage.graduated => <Widget>[
        Launch2DripBar(
          fraction: launch2Fraction(row.curve.soldBps),
          identity: id,
        ),
        Text(
          launch2BpsLabel(row.curve.soldBps),
          key: ValueKey<String>('launch2-row-value-$id'),
          style: pct,
        ),
      ],
      Launch2Stage.upcoming => <Widget>[Flexible(child: countdown('距铸造 '))],
      Launch2Stage.nftSale => <Widget>[
        Text('已铸 ${row.nftSale.soldCount}', style: pct),
        Flexible(child: countdown('剩 ')),
      ],
      Launch2Stage.snapshotPending => <Widget>[
        Text('已铸 ${row.nftSale.soldCount}', style: pct),
        Flexible(child: Text('名单生成中', style: words)),
      ],
      Launch2Stage.closedNoHolders => <Widget>[
        Flexible(
          child: Text(
            launch2ClosedNoHoldersText,
            key: const ValueKey<String>('launch2-row-closed'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: words,
          ),
        ),
      ],
      Launch2Stage.paused => <Widget>[
        Flexible(child: Text('平台核对中', style: words)),
      ],
    };
    final showTicker = row.ticker.trim().isNotEmpty && row.ticker != row.name;
    return Semantics(
      button: onTap != null,
      label: launch2RowSpokenLabel(row, now),
      excludeSemantics: true,
      child: LoopPressable(
        key: ValueKey<String>('launch2-row-$id'),
        onTap: onTap,
        scale: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Launch2ProjectAvatar(identity: id, logoUrl: row.logoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LoopTypography.withWeight(
                                LoopType.title,
                                FontWeight.w600,
                              ),
                            ),
                          ),
                          if (showTicker) ...<Widget>[
                            const SizedBox(width: 6),
                            Text(
                              row.ticker,
                              maxLines: 1,
                              style: LoopType.caption.copyWith(
                                color: LoopColors.text3,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          for (var i = 0; i < meta.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: 8),
                            meta[i],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Launch2BoardStage(stage: row.stage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 预告 with nothing queued: the grey crown, one sentence, and 「我要发射」
/// into the create flow (when the create entry is open).
class Launch2UpcomingEmpty extends StatelessWidget {
  const Launch2UpcomingEmpty({
    super.key = const ValueKey<String>('launch2-upcoming-empty'),
    this.onLaunch,
  });

  /// 「我要发射」; `null` draws no button.
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) => LoopAtmoEmpty(
    message: '还没有排队中的项目，第一个发射的就是你',
    crownKey: const ValueKey<String>('launch2-upcoming-empty-crown'),
    actionLabel: '我要发射',
    actionKey: const ValueKey<String>('launch2-upcoming-empty-launch'),
    onAction: onLaunch,
  );
}

/// The home's solid Yellow button: 12 radius, Ink 14 / 700, a soft Yellow
/// glow under it.
class Launch2YellowButton extends LoopYellowButton {
  const Launch2YellowButton({
    required super.label,
    super.key,
    super.onTap,
    super.height,
    super.maxWidth,
  });
}
