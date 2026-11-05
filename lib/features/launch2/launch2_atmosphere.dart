import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';

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
/// at all — since decision 0224 the shared [loopAmbientMotionProvider], so
/// the chrome plates follow the same switch. The system's reduced-motion
/// setting always stops it too.
final launch2AmbientMotionProvider = loopAmbientMotionProvider;

/// Whether looping motion may run in [context].
bool launch2AmbientMotion(BuildContext context, WidgetRef ref) =>
    loopAmbientMotion(context, ref);

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

/// The still layer under the MEME home. S367 · decision 0291: plain Ink —
/// the shared [LoopWallBackdrop] without its wall and fogs, and without the
/// Figma's Purple ambient glow (decision 0279) that lay over it.
class Launch2AtmosphereBackdrop extends StatelessWidget {
  const Launch2AtmosphereBackdrop({
    super.key = const ValueKey<String>('launch2-atmo-backdrop'),
  });

  /// The design's reference width.
  static const double referenceWidth = LoopWallBackdrop.referenceWidth;

  @override
  Widget build(BuildContext context) =>
      const LoopWallBackdrop(keyPrefix: 'launch2-atmo');
}

/// The MEME title over the Purple doodle; the wall crown that peeked out
/// behind it is gone (decision 0291).
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
/// first 35 % of the cycle), never under reduced motion — the shared
/// [LoopSheen] since decision 0224.
class Launch2ChromeHand extends StatelessWidget {
  const Launch2ChromeHand({super.key});

  static const Duration cycle = LoopSheen.cycle;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const ValueKey<String>('launch2-atmo-hand'),
    child: LoopSheen(
      sheenKey: const ValueKey<String>('launch2-atmo-hand-sheen'),
      child: DecoratedBox(
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
      ),
    ),
  );
}

// ---- the live trade band ----------------------------------------------------

/// The trade band under the banner (replaces the three-line 实时 card): the
/// newest trades run left in one line; 「● 实时」 holds the left end and the
/// 「›」 to the full list the right, behind a fade. With no trade the band
/// says 「暂无成交」 and stands still.
///
/// S326 · decision 0256 (UX-004 ①–⑤): the solid Purple ground is gone — the
/// band is the quiet card ground with a hairline edge inside the page
/// gutters; 「实时」 is Purple and 「买入」 green, so the two no longer read as
/// one colour; the amount sits 2 from its unit; 「全部」 is the chevron alone;
/// the band numbers nothing.
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

  /// The band's height inside its 44 dp tap row (docs/58 §5.5: 35).
  static const double bandHeight = 35;

  /// How far the line moves per second.
  static const double speed = 24;

  /// The band's ground: white 3 % glass (docs/58 §5.5, decision 0279).
  static const Color ground = LoopColors.surfaceGlass;

  /// What the right end fades into before the chevron (Figma `#0e0f10`).
  static const Color fade = LoopColors.searchBg;

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
        ? context.l10n.launch2_launch2AtmosphereIf
        : context.l10n.launch2_launch2AtmosphereS(
            items
                .map(launch2ActivityText)
                .take(3)
                .join(LoopL10n.current.launch2_tickerSeparator),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: SizedBox(
        height: 44,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: (44 - Launch2TradeTicker.bandHeight) / 2,
              height: Launch2TradeTicker.bandHeight,
              child: DecoratedBox(
                key: const ValueKey<String>('launch2-ticker-band'),
                decoration: BoxDecoration(
                  color: Launch2TradeTicker.ground,
                  borderRadius: LoopRadius.chip,
                  border: Border.all(color: LoopColors.white3),
                  boxShadow: LoopDepth.ticker,
                ),
                child: ClipRRect(
                  borderRadius: LoopRadius.chip,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 8),
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
                                      context
                                          .l10n
                                          .launch2_launch2AtmosphereLaunch2TickerEmpty,
                                      key: const ValueKey<String>(
                                        'launch2-ticker-empty',
                                      ),
                                      style: LoopTypography.withWeight(
                                        LoopType.bodySm,
                                        FontWeight.w500,
                                      ).copyWith(color: LoopColors.text2),
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
            ),
            if (items.isNotEmpty)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Semantics(
                  button: true,
                  label: context
                      .l10n
                      .launch2_launch2AtmosphereLaunch2TickerAllLabel,
                  excludeSemantics: true,
                  child: LoopPressable(
                    key: const ValueKey<String>('launch2-ticker-all'),
                    onTap: widget.onOpenAll,
                    scale: false,
                    child: Center(
                      child: Container(
                        height: Launch2TradeTicker.bandHeight - 2,
                        constraints: const BoxConstraints(
                          minWidth: LoopTouch.minimum,
                        ),
                        margin: const EdgeInsets.only(right: 1),
                        padding: const EdgeInsets.fromLTRB(22, 0, 12, 0),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(LoopRadius.chipValue),
                          ),
                          gradient: LinearGradient(
                            colors: <Color>[
                              Launch2TradeTicker.fade.withValues(alpha: 0),
                              Launch2TradeTicker.fade,
                            ],
                            stops: const <double>[0, 0.55],
                          ),
                        ),
                        alignment: Alignment.centerRight,
                        child: const LoopIcon(
                          'chevron',
                          size: 16,
                          color: LoopColors.text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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

/// 「● 实时」 fixed at the band's left end (docs/58 §5.5): a 5 Purple dot
/// and, 6 after it, the Purple word at 12 / 600 — no capsule; never the rise
/// green the 「买入」 tag wears (decision 0256).
class _LiveLabel extends StatelessWidget {
  const _LiveLabel();

  /// The dot and the word.
  static const Color ink = LoopColors.purple;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('launch2-ticker-live'),
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        key: const ValueKey<String>('launch2-ticker-live-dot'),
        width: 5,
        height: 5,
        decoration: const BoxDecoration(color: ink, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        context.l10n.launch2_launch2AtmosphereText,
        style: LoopType.tickerFigure.copyWith(color: ink),
      ),
    ],
  );
}

/// One trade on the band: who, the verb on its own soft rise / fall ground,
/// the ticker, the amount and, 2 after it, USD1. Every other kind is its one
/// sentence. No index (decision 0256).
class _TickerItem extends StatelessWidget {
  const _TickerItem({required this.item});

  final Launch2Activity item;

  @override
  Widget build(BuildContext context) {
    // docs/58 §5.5: the name 12 / 500 textSecondary.
    final words = LoopType.meta.copyWith(color: LoopColors.text2);
    final verb = switch (item.kind) {
      Launch2ActivityKind.curveBuy => (
        context.l10n.common_buy,
        LoopColors.rise,
        LoopColors.riseSoft,
      ),
      Launch2ActivityKind.curveSell => (
        context.l10n.common_sell,
        LoopColors.fall,
        LoopColors.fallSoft,
      ),
      _ => null,
    };
    final amount = item.amountUsd1;
    final children = verb == null
        ? <Widget>[Text(launch2ActivityText(item), style: words)]
        : <Widget>[
            Text(launch2ActivityWho(item).trim(), style: words),
            Container(
              key: ValueKey<String>('launch2-ticker-verb-${item.kind.name}'),
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: verb.$3,
                borderRadius: LoopRadius.stage,
              ),
              child: Text(
                verb.$1,
                style: LoopType.buyTag.copyWith(color: verb.$2),
              ),
            ),
            Text(
              item.ticker,
              style: LoopType.tickerFigure.copyWith(color: LoopColors.chalk),
            ),
            if (amount != null)
              Row(
                key: const ValueKey<String>('launch2-ticker-amount'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    launch2Usd1Label(amount).replaceAll(' USD1', ''),
                    style: LoopType.tickerFigure.copyWith(
                      color: LoopColors.chalk,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'USD1',
                    style: LoopTypography.withWeight(
                      LoopType.figureXs,
                      FontWeight.w600,
                    ).copyWith(color: LoopColors.text3),
                  ),
                ],
              ),
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
/// (its splat gone, decision 0291).
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
            child: Container(
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
                      style: LoopTypography.withWeight(
                        LoopType.figureSm,
                        FontWeight.w600,
                      ).copyWith(color: ink),
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
          ),
        ),
      ),
    );
  }
}

// ---- the home's tab bar (S279) -------------------------------------------------

/// One tab of the home's tab bar: its id, words, count and whether it is on.
typedef Launch2DeskTabSpec = ({
  String id,
  String title,
  int count,
  bool selected,
});

/// The MEME home's tab bar (S279 · decision 0237): 「内盘 / 预告 / 已毕业」
/// across the page, each tab a third of it. S353b · decision 0279 (docs/58
/// §5.2): the Figma's first-level [LoopTabStrip] — the chosen word white
/// 16 / 600 over a 2 px Yellow line the width of its cell, the others
/// textSecondary, a count chip after each word, a 1 px white 10 % rule across
/// the page. The Purple ground and the Yellow splat are gone.
class Launch2DeskTabs extends StatelessWidget {
  const Launch2DeskTabs({
    required this.tabs,
    required this.onSelected,
    super.key = const ValueKey<String>('launch2-desk-tabs'),
  });

  final List<Launch2DeskTabSpec> tabs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    // Figma: the ticker → 16 → the strip.
    padding: const EdgeInsets.only(top: LoopSpacing.bannerGap - 4),
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      child: LoopTabStrip(
        labels: <String>[for (final tab in tabs) tab.title],
        counts: <int?>[for (final tab in tabs) tab.count],
        keys: <Key>[
          for (final tab in tabs)
            ValueKey<String>('launch2-desk-tab-${tab.id}'),
        ],
        selectedIndex: math.max(0, tabs.indexWhere((tab) => tab.selected)),
        onSelected: onSelected,
        scaleDownLabels: true,
      ),
    ),
  );
}

// ---- the board -------------------------------------------------------------------

/// The list under the home's tabs. S353b · decision 0279 (docs/58 §5.4,
/// §9.4): no card ground any more — the rows stand on the page between its
/// 20 margins, each closed by a 1 px white 5 % line across the content.
class Launch2Board extends StatelessWidget {
  const Launch2Board({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    // A row's ink splash paints on this.
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final child in children) ...<Widget>[
            child,
            const Divider(height: 1, thickness: 1, color: LoopColors.divider),
          ],
        ],
      ),
    ),
  );
}

/// A board row's progress (docs/58 §5.4): a 4 high track in
/// [LoopColors.progressTrack], round-ended (the Figma's 2.5 corner on a 4
/// high bar), filled white 80 %.
class Launch2ProgressBar extends StatelessWidget {
  const Launch2ProgressBar({
    required this.fraction,
    required this.identity,
    super.key,
    this.width = Launch2ProgressBar.figmaWidth,
  });

  final double fraction;
  final String identity;
  final double width;

  /// The Figma's track width.
  static const double figmaWidth = 142;

  /// The track's height.
  static const double height = 4;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey<String>('launch2-bar-$identity'),
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: LoopColors.progressTrack,
        borderRadius: LoopRadius.round,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          heightFactor: 1,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: LoopColors.progressFill,
              borderRadius: LoopRadius.round,
            ),
          ),
        ),
      ),
    ),
  );
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

/// The stage capsule at a board row's right (docs/58 §5.4): 19 high, a 4
/// corner, the word 11 / 400 — Yellow on Yellow-soft while it takes orders,
/// the Purple tag once graduated, grey while it waits.
class Launch2BoardStage extends StatelessWidget {
  const Launch2BoardStage({required this.stage, super.key});

  final Launch2Stage stage;

  /// The capsule's height.
  static const double height = 19;

  @override
  Widget build(BuildContext context) {
    final (Color ground, Color ink) = switch (stage) {
      Launch2Stage.priority ||
      Launch2Stage.public ||
      Launch2Stage.nftSale => (LoopColors.yellowSoft, LoopColors.yellow),
      Launch2Stage.graduated => (LoopColors.tagPurpleBg, LoopColors.tagPurple),
      _ => (LoopColors.white8, LoopColors.text2),
    };
    return Container(
      key: ValueKey<String>('launch2-stage-pill-${stage.wireName}'),
      height: Launch2BoardStage.height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: ground, borderRadius: LoopRadius.stage),
      // Sized by its word, never by the column it stands in.
      child: Center(
        widthFactor: 1,
        child: Text(
          launch2StageLabel(stage),
          maxLines: 1,
          style: LoopType.stageTag.copyWith(color: ink),
        ),
      ),
    );
  }
}

/// One board row (v3, decision 0229; S353b · decision 0279, docs/58 §5.4:
/// 71 high plus its 1 px line, the face 44).
///
/// Left: the face, the name (body1 17) with its ticker (caption 13), and
/// under it the bar with the share sold (or the stage's own caption line).
/// Right: the price as the row's one figure (17 / 600) over the stage
/// capsule; a row with no curve price yet keeps only the capsule. Before v3
/// the price sat third on the caption line, behind the bar and the share,
/// and was cut to 「$0.0₄…」 on a 390 screen.
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

  /// The Figma's 71, less the 1 px line the board draws under it.
  static const double height = 70;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(launch2ClockProvider)();
    final id = row.instanceId;
    final next = row.nextChangeAt;
    final words = LoopType.caption.copyWith(color: LoopColors.text2);
    // docs/58 §5.4: the share sold is the bar's reading at 10 / 300.
    final pct = LoopType.progress;
    Widget countdown(String prefix) => next == null
        ? Text(
            context.l10n.launch2_launch2AtmosphereBuild(prefix),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: words,
          )
        : Launch2Countdown(
            target: next,
            prefix: prefix,
            onElapsed: onElapsed,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          );
    final trading =
        row.stage == Launch2Stage.priority || row.stage == Launch2Stage.public;
    final List<Widget> meta = switch (row.stage) {
      Launch2Stage.priority ||
      Launch2Stage.public ||
      Launch2Stage.graduated => <Widget>[
        // The bar gives way first on a narrow screen; the share stays.
        Flexible(
          child: LayoutBuilder(
            builder: (context, box) => Launch2ProgressBar(
              fraction: launch2Fraction(row.curve.soldBps),
              identity: id,
              width: math.min(Launch2ProgressBar.figmaWidth, box.maxWidth),
            ),
          ),
        ),
        Text(
          launch2BpsLabel(row.curve.soldBps),
          key: ValueKey<String>('launch2-row-value-$id'),
          style: pct,
        ),
      ],
      Launch2Stage.upcoming => <Widget>[
        Flexible(
          child: countdown(context.l10n.launch2_launch2AtmosphereCountdown),
        ),
      ],
      Launch2Stage.nftSale => <Widget>[
        Flexible(
          child: Text(
            context.l10n.launch2_launch2AtmosphereSwitch(row.nftSale.soldCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: pct,
          ),
        ),
        Flexible(
          child: countdown(context.l10n.launch2_launch2AtmosphereCountdown2),
        ),
      ],
      Launch2Stage.snapshotPending => <Widget>[
        Flexible(
          child: Text(
            context.l10n.launch2_launch2AtmosphereSwitch(row.nftSale.soldCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: pct,
          ),
        ),
        Flexible(
          child: Text(
            context.l10n.launch2_launch2AtmosphereSwitch2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: words,
          ),
        ),
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
        Flexible(
          child: Text(
            context.l10n.launch2_launch2AtmosphereSwitch3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: words,
          ),
        ),
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
          child: KeyedSubtree(
            child: Row(
              children: <Widget>[
                Launch2ProjectAvatar(identity: id, logoUrl: row.logoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // S350b · decision 0275: the ticker gives way first,
                      // whole — the name is never cut to make room for it.
                      _BoardRowName(
                        name: row.name,
                        ticker: showTicker ? row.ticker : null,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: <Widget>[
                          for (var i = 0; i < meta.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: 9),
                            meta[i],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      if (trading) ...<Widget>[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            launch2PriceLabel(row.curve.priceUsd1),
                            key: const ValueKey<String>('launch2-row-price'),
                            maxLines: 1,
                            style: LoopType.figure,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Launch2BoardStage(stage: row.stage),
                    ],
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

/// A board row's first line: the name (body1) and, when the line holds both,
/// the ticker (caption) after it.
class _BoardRowName extends StatelessWidget {
  const _BoardRowName({required this.name, this.ticker});

  final String name;
  final String? ticker;

  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: LoopType.body1,
    );
    final mark = ticker;
    if (mark == null) return nameText;
    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        double width(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final value = painter.width;
          painter.dispose();
          return value;
        }

        final fits =
            width(name, LoopType.body1) +
                _gap +
                width(mark, LoopType.caption) <=
            box.maxWidth;
        if (!fits) return nameText;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            nameText,
            const SizedBox(width: _gap),
            Text(mark, maxLines: 1, style: LoopType.caption),
          ],
        );
      },
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
    // S350b · decision 0275: the fact alone; 我要发射 is the invitation.
    message: context.l10n.launch2_launch2AtmosphereMessage,
    crownKey: const ValueKey<String>('launch2-upcoming-empty-crown'),
    actionLabel: context.l10n.launch2_launch2AtmosphereActionLabel,
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
