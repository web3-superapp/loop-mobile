import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';

// ---------------------------------------------------------------------------
// 发射台顶部 Banner (decision 0163, docs/32 §3)
// ---------------------------------------------------------------------------
//
// Time and progress are the card: what is happening now and what opens next,
// how long is left and how far it has gone. Chosen from the rows the list has
// already read — no request of its own — and drawn as a sideways pager that
// never moves by itself and has no entry animation. Only the countdown text
// redraws every second.

/// The rows of the list's first page (`limit=30`, loop_v2_launch2_api): the
/// merged list keeps them first, deeper pages only follow, so the hero picks
/// from these and a page read further down never reshuffles it.
const int launch2HeroFirstPageRows = 30;

/// The most cards the hero shows.
const int launch2HeroLimit = 5;

/// 内盘冲刺: a public curve this far sold (bps) earns a card.
const int launch2HeroSprintBps = 7000;

/// The hero card's height at the 390 baseline (docs/32 §3.2).
const double launch2HeroHeight = 196;

/// The rows the hero shows, in its order (docs/32 §3.1): activities first —
/// NFT 铸造中, then 白名单提前购, then a public curve at ≥ 70 % (内盘冲刺) —
/// then the previews (`upcoming`), nearest sale start first; at most
/// [launch2HeroLimit]. Within an activity group the row that ends soonest
/// (the NFT sale, the early round) or the curve sold furthest comes first;
/// rows the server did not time keep its own order after the timed ones.
/// Nothing else is shown: an empty answer draws no hero at all.
List<Launch2InstanceRow> launch2HeroRows(List<Launch2InstanceRow> rows) {
  int bySoonest(Launch2InstanceRow a, Launch2InstanceRow b) {
    final x = a.nextChangeAt;
    final y = b.nextChangeAt;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }

  List<Launch2InstanceRow> stage(
    Launch2Stage value,
    int Function(Launch2InstanceRow, Launch2InstanceRow) order, {
    bool Function(Launch2InstanceRow row)? where,
  }) {
    final picked = <Launch2InstanceRow>[
      for (final row in rows)
        if (row.stage == value && (where?.call(row) ?? true)) row,
    ];
    // `List.sort` is not stable; the index keeps the server's order on ties.
    final index = <String, int>{
      for (var i = 0; i < picked.length; i++) picked[i].instanceId: i,
    };
    picked.sort((a, b) {
      final first = order(a, b);
      return first != 0
          ? first
          : index[a.instanceId]!.compareTo(index[b.instanceId]!);
    });
    return picked;
  }

  return <Launch2InstanceRow>[
    ...stage(Launch2Stage.nftSale, bySoonest),
    ...stage(Launch2Stage.priority, bySoonest),
    ...stage(
      Launch2Stage.public,
      (a, b) => b.curve.soldBps.compareTo(a.curve.soldBps),
      where: (row) => row.curve.soldBps >= launch2HeroSprintBps,
    ),
    ...stage(
      Launch2Stage.upcoming,
      (a, b) => a.nftSale.startAt.compareTo(b.nftSale.startAt),
    ),
  ].take(launch2HeroLimit).toList(growable: false);
}

/// Where a hero card opens (docs/32 §3.2): the NFT mint page while the NFT is
/// the thing to do (`upcoming`, `nft_sale`), the project page otherwise.
String launch2HeroLocation(Launch2InstanceRow row) => switch (row.stage) {
  Launch2Stage.upcoming ||
  Launch2Stage.nftSale => Launch2Route.nft(row.instanceId),
  _ => Launch2Route.instance(row.instanceId),
};

/// The card's first line (状态句).
String launch2HeroHeadline(Launch2Stage stage, {required bool sprint}) =>
    switch (stage) {
      Launch2Stage.upcoming => '开售倒计时',
      Launch2Stage.nftSale => 'NFT 铸造中',
      Launch2Stage.snapshotPending => '名单生成中',
      Launch2Stage.priority => '白名单提前购',
      Launch2Stage.public => sprint ? '内盘冲刺' : '公开内盘',
      _ => launch2StageLabel(stage),
    };

/// Whether the card's first line and figure are Lime: only what is open now.
bool launch2HeroLit(Launch2Stage stage) =>
    stage == Launch2Stage.nftSale ||
    stage == Launch2Stage.priority ||
    stage == Launch2Stage.public;

/// The card's third line.
String launch2HeroDetail(Launch2InstanceRow row) {
  final sale = row.nftSale;
  final perNft = '${launch2Usd1Label(sale.priceUsd1)} / 枚';
  return switch (row.stage) {
    Launch2Stage.upcoming => '$perNft · 发售 ${launch2SaleDurationLabel(sale)}',
    Launch2Stage.nftSale => '已铸 ${sale.soldCount} 枚 · $perNft',
    Launch2Stage.snapshotPending => '名单发布后 1 小时提前购',
    Launch2Stage.priority =>
      '内盘已售 ${launch2BpsLabel(row.curve.soldBps)} · '
          '${launch2HeroPrice(row.curve.priceUsd1)}',
    Launch2Stage.public => '${launch2HeroPrice(row.curve.priceUsd1)} · 卖满自动毕业',
    _ => launch2StageCaption(row.stage),
  };
}

/// A curve price in USD1 at the list's precision: 「0.0₄4167 USD1」 (the
/// list column's `$` dropped — the unit is said once, after the figure).
String launch2HeroPrice(Decimal price) {
  final label = launch2PriceLabel(price);
  return '${label.startsWith(r'$') ? label.substring(1) : label} USD1';
}

/// How far the card's fuse (引线) has burnt, or `null` when it draws none
/// (docs/32 §3.2): the share of the NFT sale's time already past, or the
/// curve sold out of 8 亿.
double? launch2HeroFuse(Launch2InstanceRow row, DateTime now) {
  switch (row.stage) {
    case Launch2Stage.nftSale:
      final sale = row.nftSale;
      final whole = sale.endAt.difference(sale.startAt).inMilliseconds;
      if (whole <= 0) return 1;
      final past = now.difference(sale.startAt).inMilliseconds;
      return (past / whole).clamp(0.0, 1.0);
    case Launch2Stage.priority:
    case Launch2Stage.public:
      return launch2Fraction(row.curve.soldBps);
    case Launch2Stage.upcoming:
    case Launch2Stage.snapshotPending:
    case Launch2Stage.closedNoHolders:
    case Launch2Stage.graduated:
    case Launch2Stage.paused:
      return null;
  }
}

/// The ticker as the hero prints it: eight characters, then 「…」.
String launch2HeroTicker(String ticker) =>
    ticker.length > 8 ? '${ticker.substring(0, 8)}…' : ticker;

/// What a hero card says aloud, in one sentence.
String launch2HeroSpokenLabel(Launch2InstanceRow row, DateTime now) {
  final next = row.nextChangeAt;
  final left = next == null
      ? null
      : launch2SpokenDuration(next.difference(now));
  final sprint = row.curve.soldBps >= launch2HeroSprintBps;
  return <String>[
    row.ticker,
    launch2HeroHeadline(row.stage, sprint: sprint),
    ...switch (row.stage) {
      Launch2Stage.upcoming => <String>[left == null ? '开售时间待定' : '距开售 $left'],
      Launch2Stage.nftSale => <String>[
        if (left != null) '剩 $left',
        '已铸 ${row.nftSale.soldCount} 枚',
      ],
      Launch2Stage.snapshotPending => <String>['已铸 ${row.nftSale.soldCount} 枚'],
      Launch2Stage.priority => <String>[
        if (left != null) '剩 $left',
        '内盘已售 ${launch2BpsLabel(row.curve.soldBps)}',
      ],
      Launch2Stage.public => <String>[
        '内盘已售 ${launch2BpsLabel(row.curve.soldBps)}',
      ],
      _ => const <String>[],
    },
  ].join('，');
}

/// The pager over the v2 list (docs/32 §3): one card per row of [rows] (the
/// caller passes [launch2HeroRows]' answer and draws nothing when it is
/// empty), dots in the top right corner from two cards on.
class Launch2HeroPager extends StatefulWidget {
  const Launch2HeroPager({
    required this.rows,
    required this.onNavigate,
    super.key = const ValueKey<String>('launch2-hero'),
    this.onElapsed,
  });

  final List<Launch2InstanceRow> rows;
  final void Function(String location) onNavigate;

  /// A card's countdown reached zero: the list re-reads the server.
  final VoidCallback? onElapsed;

  @override
  State<Launch2HeroPager> createState() => _Launch2HeroPagerState();
}

class _Launch2HeroPagerState extends State<Launch2HeroPager> {
  final PageController _controller = PageController();
  final ValueNotifier<int> _page = ValueNotifier<int>(0);

  /// Cards whose fuse already drew itself in (§7.2: once, on first sight).
  final Set<String> _introduced = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Launch2HeroPager old) {
    super.didUpdateWidget(old);
    // A shorter list after a re-read: the dot follows the page it lands on.
    if (_page.value >= widget.rows.length && widget.rows.isNotEmpty) {
      _page.value = widget.rows.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final dots = rows.length >= 2;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: LoopSpacing.group - 2),
      child: SizedBox(
        height: launch2HeroHeight,
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              itemCount: rows.length,
              onPageChanged: (index) => _page.value = index,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LoopSpacing.page,
                ),
                child: Launch2HeroCard(
                  row: rows[index],
                  reserveDots: dots,
                  introduceFuse: _introduced.add(rows[index].instanceId),
                  onTap: () =>
                      widget.onNavigate(launch2HeroLocation(rows[index])),
                  onElapsed: widget.onElapsed,
                ),
              ),
            ),
            if (dots)
              Positioned(
                top: 24,
                right: LoopSpacing.page + 20,
                child: ExcludeSemantics(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _page,
                    builder: (context, page, _) => _HeroDots(
                      key: const ValueKey<String>('launch2-hero-dots'),
                      count: rows.length,
                      current: page,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.count, required this.current, super.key});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (var i = 0; i < count; i++)
        Container(
          key: ValueKey<String>('launch2-hero-dot-$i'),
          width: 6,
          height: 6,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == current ? LoopColors.chalk : LoopColors.line2,
          ),
        ),
    ],
  );
}

/// One hero card (docs/32 §3.2): the state sentence, the ticker over the
/// name with the logo on the right, the leading figure (a countdown or the
/// curve's share), the third line and the 2 px fuse along the bottom edge.
class Launch2HeroCard extends ConsumerWidget {
  const Launch2HeroCard({
    required this.row,
    required this.onTap,
    super.key,
    this.reserveDots = false,
    this.introduceFuse = false,
    this.onElapsed,
  });

  final Launch2InstanceRow row;
  final VoidCallback onTap;

  /// The fuse draws itself in (§7.2); the pager asks for it once per card.
  final bool introduceFuse;

  /// The pager draws its dots over this card's top right corner.
  final bool reserveDots;
  final VoidCallback? onElapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(launch2ClockProvider)();
    final id = row.instanceId;
    final lit = launch2HeroLit(row.stage);
    final accent = lit ? LoopColors.lime : LoopColors.chalk;
    final sprint = row.curve.soldBps >= launch2HeroSprintBps;
    final fuse = launch2HeroFuse(row, now);
    final nft = row.stage == Launch2Stage.nftSale;
    return Semantics(
      button: true,
      label: launch2HeroSpokenLabel(row, now),
      excludeSemantics: true,
      child: Material(
        color: LoopColors.graphite,
        borderRadius: LoopRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('launch2-hero-page-$id'),
          onTap: onTap,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(right: reserveDots ? 64 : 0),
                      child: Text(
                        launch2HeroHeadline(row.stage, sprint: sprint),
                        key: ValueKey<String>('launch2-hero-headline-$id'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.body.copyWith(color: accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                launch2HeroTicker(row.ticker),
                                key: ValueKey<String>(
                                  'launch2-hero-ticker-$id',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LoopType.display,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LoopType.body.copyWith(
                                  color: LoopColors.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _HeroLogo(row: row, ringed: nft),
                      ],
                    ),
                    const Spacer(),
                    _HeroFigure(row: row, color: accent, onElapsed: onElapsed),
                    const SizedBox(height: 4),
                    Text(
                      launch2HeroDetail(row),
                      key: ValueKey<String>('launch2-hero-detail-$id'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.figureSm,
                    ),
                  ],
                ),
              ),
              if (fuse != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Launch2HeroFuse(
                    key: ValueKey<String>('launch2-hero-fuse-$id'),
                    fraction: fuse,
                    introduce: introduceFuse,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo, 64; during the NFT sale inside a Brass ring (the NFT accent).
class _HeroLogo extends StatelessWidget {
  const _HeroLogo({required this.row, required this.ringed});

  final Launch2InstanceRow row;
  final bool ringed;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final logo = MemeLogo(
      symbol: row.ticker,
      imageUrl: row.logoUrl,
      identity: row.instanceId,
      size: ringed ? _size - 8 : _size,
      radius: (ringed ? _size - 8 : _size) / 2,
    );
    if (!ringed) return logo;
    return Container(
      key: ValueKey<String>('launch2-hero-ring-${row.instanceId}'),
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: LoopColors.brass, width: 2),
        ),
      ),
      child: logo,
    );
  }
}

/// The card's leading figure: the countdown (with 「距开售」 / 「剩」 in front),
/// 已铸 N 枚 while the list is generated, or the curve's share.
class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.row, required this.color, this.onElapsed});

  final Launch2InstanceRow row;
  final Color color;
  final VoidCallback? onElapsed;

  @override
  Widget build(BuildContext context) {
    final style = LoopType.figureXl.copyWith(color: color);
    final next = row.nextChangeAt;
    final key = ValueKey<String>('launch2-hero-figure-${row.instanceId}');
    Widget countdown(String label) => Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            label,
            style: LoopType.body.copyWith(color: LoopColors.text2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: next == null
                ? Text('待定', style: style)
                : Launch2Countdown(
                    target: next,
                    onElapsed: onElapsed,
                    style: style,
                  ),
          ),
        ),
      ],
    );
    Widget figure(String text) => Text(
      text,
      key: key,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return switch (row.stage) {
      Launch2Stage.upcoming => countdown('距开售'),
      Launch2Stage.nftSale || Launch2Stage.priority => countdown('剩'),
      Launch2Stage.snapshotPending => figure('已铸 ${row.nftSale.soldCount} 枚'),
      _ => figure(launch2BpsLabel(row.curve.soldBps)),
    };
  }
}

/// The fuse (引线): a 2 px Lime line from the left edge to [fraction] of the
/// width, over a quiet track.
///
/// Decision 0163 §7.2: with [introduce] the line draws itself from 0 to its
/// value over 600 ms the first time it appears — the page's one choreographed
/// motion. After that, and always with motion reduced, a new value is drawn
/// at once.
class Launch2HeroFuse extends StatefulWidget {
  const Launch2HeroFuse({
    required this.fraction,
    super.key,
    this.introduce = false,
  });

  final double fraction;
  final bool introduce;

  static const Duration introDuration = Duration(milliseconds: 600);

  @override
  State<Launch2HeroFuse> createState() => Launch2HeroFuseState();
}

class Launch2HeroFuseState extends State<Launch2HeroFuse>
    with SingleTickerProviderStateMixin {
  AnimationController? _intro;

  /// The fraction drawn this frame (the intro's progress times the value).
  @visibleForTesting
  double get drawnFraction {
    final target = widget.fraction.clamp(0.0, 1.0);
    final intro = _intro;
    if (intro == null || intro.isCompleted) return target;
    return target * Curves.easeOutCubic.transform(intro.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro != null || !widget.introduce) return;
    if (LoopMotion.reduced(context)) return;
    _intro = AnimationController(
      vsync: this,
      duration: Launch2HeroFuse.introDuration,
    )..forward();
  }

  @override
  void dispose() {
    _intro?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.fraction.clamp(0.0, 1.0);
    final intro = _intro;
    Widget paint(double value) => SizedBox(
      height: 2,
      width: double.infinity,
      child: CustomPaint(painter: _FusePainter(value)),
    );
    if (intro == null || intro.isCompleted) return paint(target);
    return AnimatedBuilder(
      animation: intro,
      builder: (context, _) =>
          paint(target * Curves.easeOutCubic.transform(intro.value)),
    );
  }
}

class _FusePainter extends CustomPainter {
  const _FusePainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = LoopColors.card2)
      ..drawRect(
        Offset.zero & Size(size.width * fraction, size.height),
        Paint()..color = LoopColors.lime,
      );
  }

  @override
  bool shouldRepaint(_FusePainter old) => old.fraction != fraction;
}
