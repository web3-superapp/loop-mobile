import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// 发射台整页 · second phase (decision 0163, docs/32 §7)
// ---------------------------------------------------------------------------
//
// The page moves because the data does: a tape of what just happened, the
// hero, the stage counts, the list grouped by stage with a fuse under each
// live row, and the platform's figures at the foot. Ink ground, Lime for
// trading, Brass for the NFT — nothing else.

// ---- §7.1 the live tape ----------------------------------------------------

/// 「刚刚」, 「N 分钟前」, then the local 「HH:mm」.
String launch2RelativeTime(DateTime at, DateTime now) {
  final age = now.difference(at);
  if (age < const Duration(minutes: 1)) return '刚刚';
  if (age < const Duration(hours: 1)) return '${age.inMinutes} 分钟前';
  return loopLocalClockLabel(at);
}

/// 「0x1d2f…9b」: the actor as the tape prints it.
String launch2TapeActor(String? actor) {
  if (actor == null) return '有人';
  if (actor.length <= 10) return actor;
  return '${actor.substring(0, 6)}…${actor.substring(actor.length - 2)}';
}

/// One tape item's sentence, without its time.
String launch2ActivityText(Launch2Activity item) {
  // 「有人买入」 runs on; an address takes a space before the verb.
  final who = item.actor == null ? '有人' : '${launch2TapeActor(item.actor)} ';
  final ticker = item.ticker;
  final amount = item.amountUsd1;
  final usd1 = amount == null ? '' : ' ${launch2Usd1Label(amount)}';
  return switch (item.kind) {
    Launch2ActivityKind.curveBuy => '$who买入 $ticker$usd1',
    Launch2ActivityKind.curveSell => '$who卖出 $ticker$usd1',
    Launch2ActivityKind.nftMint => '$who铸造 $ticker 勋章',
    Launch2ActivityKind.graduated => '$ticker 毕业了',
    Launch2ActivityKind.buyback => '平台回购 $ticker$usd1',
    Launch2ActivityKind.roundActivated => '$ticker 外盘新一轮激活',
    Launch2ActivityKind.rewardClaimed => '$who领取 $ticker 奖励$usd1',
  };
}

/// The whole line: 「刚刚 0x1d2f…9b 买入 DOGE 20 USD1」.
String launch2ActivityLine(Launch2Activity item, DateTime now) =>
    '${launch2RelativeTime(item.at, now)} ${launch2ActivityText(item)}';

/// The mark before an item: Brass for the NFT, Lime for a buy, a graduation,
/// a buyback, a new round and a claim, quiet for a sell.
Color launch2ActivityMark(Launch2ActivityKind kind) => switch (kind) {
  Launch2ActivityKind.nftMint => LoopColors.brass,
  Launch2ActivityKind.curveSell => LoopColors.text3,
  _ => LoopColors.lime,
};

/// 「战壕电报」 (docs/32 §7.1): one 32 dp line that drifts left at
/// [speed] while nobody touches it, can be dragged, and resumes on release.
/// Items that arrive later join the end of the queue — nothing on screen
/// moves or flashes. With motion reduced it is a still, sideways-scrollable
/// row of the newest three. Empty: nothing is drawn (the caller checks).
class Launch2ActivityTape extends StatefulWidget {
  const Launch2ActivityTape({
    required this.items,
    required this.now,
    required this.onNavigate,
    super.key = const ValueKey<String>('launch2-tape'),
    this.speed = 40,
  });

  /// Newest first, as the server sends them.
  final List<Launch2Activity> items;
  final DateTime Function() now;
  final void Function(String location) onNavigate;

  /// dp per second.
  final double speed;

  static const double height = 32;

  /// What the still tape shows.
  static const int reducedCount = 3;

  @override
  State<Launch2ActivityTape> createState() => _Launch2ActivityTapeState();
}

class _Launch2ActivityTapeState extends State<Launch2ActivityTape>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_tick);

  /// Every item read so far, once each, in the order it joined.
  final List<Launch2Activity> _queue = <Launch2Activity>[];
  final Set<String> _seen = <String>{};

  /// What the tape lays out: the queue repeated as the drift reaches its end.
  /// Grows only at the end, so nothing already laid out moves.
  final List<Launch2Activity> _sequence = <Launch2Activity>[];

  Duration _last = Duration.zero;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    _absorb(widget.items);
    _sequence.addAll(_queue);
  }

  @override
  void didUpdateWidget(Launch2ActivityTape old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) _absorb(widget.items);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = LoopMotion.reduced(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// New items join the queue's end; one already queued is not repeated.
  void _absorb(List<Launch2Activity> items) {
    final fresh = <Launch2Activity>[
      for (final item in items.reversed)
        if (_seen.add(item.identity)) item,
    ];
    // The first answer keeps the server's newest-first order; later
    // arrivals, oldest of them first, wait at the end.
    if (_queue.isEmpty) {
      _queue.addAll(fresh.reversed);
    } else {
      _queue.addAll(fresh);
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_touching || !_scroll.hasClients || dt <= 0 || dt > 0.5) return;
    final position = _scroll.position;
    final next = position.pixels + widget.speed * dt;
    // Two screens from the end: lay out the queue once more behind it.
    if (position.maxScrollExtent - next < position.viewportDimension * 2 &&
        _sequence.length < 2000) {
      setState(() => _sequence.addAll(_queue));
    }
    if (next <= position.maxScrollExtent) _scroll.jumpTo(next);
  }

  void _open(Launch2Activity item) =>
      widget.onNavigate(Launch2Route.instance(item.instanceId));

  @override
  Widget build(BuildContext context) {
    final still = LoopMotion.reduced(context);
    final now = widget.now();
    final items = still
        ? _queue.take(Launch2ActivityTape.reducedCount).toList()
        : _sequence;
    return SizedBox(
      height: Launch2ActivityTape.height,
      child: Listener(
        onPointerDown: (_) => _touching = true,
        onPointerUp: (_) => _touching = false,
        onPointerCancel: (_) => _touching = false,
        child: ListView.builder(
          key: ValueKey<String>(
            still ? 'launch2-tape-still' : 'launch2-tape-drift',
          ),
          controller: still ? null : _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          itemCount: items.length,
          itemBuilder: (context, index) => _TapeItem(
            key: ValueKey<String>('launch2-tape-item-$index'),
            item: items[index],
            now: now,
            onTap: () => _open(items[index]),
          ),
        ),
      ),
    );
  }
}

class _TapeItem extends StatelessWidget {
  const _TapeItem({
    required this.item,
    required this.now,
    required this.onTap,
    super.key,
  });

  final Launch2Activity item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final line = launch2ActivityLine(item, now);
    return Semantics(
      button: true,
      label: line,
      excludeSemantics: true,
      child: LoopPressable(
        onTap: onTap,
        scale: false,
        child: Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 3,
                height: 12,
                color: launch2ActivityMark(item.kind),
              ),
              const SizedBox(width: 6),
              Text(
                line,
                maxLines: 1,
                softWrap: false,
                style: LoopType.figureSm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- §7.3 / §7.4 the stage groups -----------------------------------------

/// The groups of the 「v2 发射」 list (docs/32 §7.4), in order.
enum Launch2StageGroup {
  minting('铸造中'),
  priority('提前购'),
  curve('内盘'),
  snapshot('名单生成中'),
  upcoming('预告'),
  graduated('已毕业'),
  closed('已暂停 / 无人铸造');

  const Launch2StageGroup(this.title);

  final String title;

  static Launch2StageGroup of(Launch2Stage stage) => switch (stage) {
    Launch2Stage.nftSale => minting,
    Launch2Stage.priority => priority,
    Launch2Stage.public => curve,
    Launch2Stage.snapshotPending => snapshot,
    Launch2Stage.upcoming => upcoming,
    Launch2Stage.graduated => graduated,
    Launch2Stage.paused || Launch2Stage.closedNoHolders => closed,
  };
}

/// [rows] in their groups, each group in the server's order; empty groups
/// are left out.
List<(Launch2StageGroup, List<Launch2InstanceRow>)> launch2GroupRows(
  List<Launch2InstanceRow> rows,
) => <(Launch2StageGroup, List<Launch2InstanceRow>)>[
  for (final group in Launch2StageGroup.values)
    if (rows.where((row) => Launch2StageGroup.of(row.stage) == group).toList()
        case final List<Launch2InstanceRow> members when members.isNotEmpty)
      (group, members),
];

/// The four counted groups of §7.3, with how many rows each holds now.
List<(Launch2StageGroup, int)> launch2StageCounts(
  List<Launch2InstanceRow> rows,
) => <(Launch2StageGroup, int)>[
  for (final group in const <Launch2StageGroup>[
    Launch2StageGroup.minting,
    Launch2StageGroup.priority,
    Launch2StageGroup.curve,
    Launch2StageGroup.upcoming,
  ])
    if (rows.where((row) => Launch2StageGroup.of(row.stage) == group).length
        case final int count when count > 0)
      (group, count),
];

/// A list row's fuse (§7.4): the NFT sale's time past, the curve's share
/// sold; nothing for any other stage.
double? launch2RowFuse(Launch2InstanceRow row, DateTime now) =>
    switch (row.stage) {
      Launch2Stage.nftSale ||
      Launch2Stage.priority ||
      Launch2Stage.public => launch2HeroFuse(row, now),
      _ => null,
    };

/// A group's heading: the name in the title weight, its count in grey.
class Launch2GroupHeading extends StatelessWidget {
  const Launch2GroupHeading({
    required this.group,
    required this.count,
    super.key,
  });

  final Launch2StageGroup group;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      LoopSpacing.group - 4,
      LoopSpacing.page,
      4,
    ),
    child: Semantics(
      header: true,
      label: '${group.title}，$count 个',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              group.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.title,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            key: ValueKey<String>('launch2-group-count-${group.name}'),
            style: LoopType.figure.copyWith(color: LoopColors.text3),
          ),
        ],
      ),
    ),
  );
}

/// §7.3: one pill per counted group that holds a row; a tap brings that
/// group's heading into view. Nothing is drawn when every count is zero.
class Launch2StageCountBar extends StatelessWidget {
  const Launch2StageCountBar({
    required this.counts,
    required this.headingKeyOf,
    super.key = const ValueKey<String>('launch2-stage-counts'),
  });

  final List<(Launch2StageGroup, int)> counts;
  final GlobalKey Function(Launch2StageGroup group) headingKeyOf;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: LoopTouch.minimum,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      children: <Widget>[
        for (final (group, count) in counts)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CountPill(
              key: ValueKey<String>('launch2-stage-count-${group.name}'),
              label: group.title,
              count: count,
              onTap: () =>
                  unawaited(launch2RevealGroup(context, headingKeyOf(group))),
            ),
          ),
      ],
    ),
  );
}

/// Scrolls the page until [target] is built, then brings it to the top.
/// The list is lazy, so a far heading may not exist yet: the page is moved a
/// screen at a time until it does.
Future<void> launch2RevealGroup(BuildContext context, GlobalKey target) async {
  final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
  final reduced = LoopMotion.reduced(context);
  const duration = Duration(milliseconds: 300);
  for (var i = 0; i < 40 && target.currentContext == null; i++) {
    final position = scrollable?.position;
    if (position == null || position.pixels >= position.maxScrollExtent) break;
    position.jumpTo(
      (position.pixels + position.viewportDimension).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await SchedulerBinding.instance.endOfFrame;
  }
  final found = target.currentContext;
  if (found == null || !found.mounted) return;
  await Scrollable.ensureVisible(
    found,
    duration: reduced ? Duration.zero : duration,
    curve: Curves.easeOutCubic,
    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.count,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label $count 个',
    excludeSemantics: true,
    child: Material(
      color: LoopColors.card,
      shape: const StadiumBorder(side: BorderSide(color: LoopColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: LoopType.body.copyWith(color: LoopColors.text2),
              ),
              const SizedBox(width: 6),
              Text('$count', style: LoopType.figureMd),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---- §7.5 the figures --------------------------------------------------------

/// 本周毕业 N（累计 M）· 累计回购 X USD1 · 铸造 N 枚 — one line of three.
class Launch2StatsStrip extends StatelessWidget {
  const Launch2StatsStrip({
    required this.stats,
    super.key = const ValueKey<String>('launch2-stats'),
  });

  final Launch2Stats stats;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      LoopSpacing.group,
      LoopSpacing.page,
      8,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _Figure(
            keyName: 'launch2-stats-graduated',
            figure: '${stats.graduatedThisWeek}',
            label: '本周毕业',
            detail: '累计 ${stats.graduatedTotal}',
          ),
        ),
        Expanded(
          child: _Figure(
            keyName: 'launch2-stats-buyback',
            figure: launch2Usd1Label(stats.buybackUsd1Total),
            label: '累计回购',
          ),
        ),
        Expanded(
          child: _Figure(
            keyName: 'launch2-stats-minted',
            figure: '${stats.nftMintedTotal} 枚',
            label: '铸造',
          ),
        ),
      ],
    ),
  );
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.keyName,
    required this.figure,
    required this.label,
    this.detail,
  });

  final String keyName;
  final String figure;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $figure${detail == null ? '' : '，$detail'}',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            figure,
            key: ValueKey<String>(keyName),
            maxLines: 1,
            style: LoopType.figureMd,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail == null ? label : '$label · $detail',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LoopType.captionSm,
        ),
      ],
    ),
  );
}
