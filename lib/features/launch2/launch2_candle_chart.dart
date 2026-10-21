import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// 项目页 K 线 (decision 0227)
// ---------------------------------------------------------------------------
//
// One card under the 内盘 (or, after graduation, 官方池) heading: the six
// interval capsules, then the shared token chart (`LoopMarketChart`) as
// candles with a volume strip. No second chart is written here — the card
// only feeds the shared one and says what it could not read.

/// What the card draws.
enum Launch2CandlePhase {
  /// The first read of this interval has not answered yet.
  loading,

  /// The series is held (possibly empty: no trade yet).
  ready,

  /// The first read failed for a reason a retry may fix.
  failed,

  /// The server or this build has no K line for the instance: the card is
  /// not drawn at all (decision 0227 §4).
  hidden,
}

/// The default capsule: 5 分 while the curve trades, 1 时 once graduated.
Launch2CandleInterval launch2DefaultCandleInterval(Launch2Stage stage) =>
    stage == Launch2Stage.graduated
    ? Launch2CandleInterval.oneHour
    : Launch2CandleInterval.fiveMinutes;

/// The empty state's line.
const String launch2CandlesEmptyText = '还没有成交，第一笔成交后出现 K 线';

/// The failure line; the whole block is the retry.
const String launch2CandlesFailedText = 'K 线暂时读不到，点按重试';

/// Whether a failure means "no K line here" rather than "try again".
bool launch2CandlesHiddenFor(LoopChainFailureKind kind) =>
    kind == LoopChainFailureKind.unavailable ||
    kind == LoopChainFailureKind.notFound;

/// One instance's K line for one interval at a time: the newest page, older
/// pages prepended as the reader pans back, and a silent re-read of the
/// newest page that keeps every older bucket already held.
final class Launch2CandleFeed extends ChangeNotifier {
  Launch2CandleFeed({
    required this._gateway,
    required this.instanceId,
    required this._interval,
    this.pageSize = launch2CandlePageSize,
  });

  final Launch2Gateway _gateway;
  final String instanceId;
  final int pageSize;

  Launch2CandleInterval _interval;
  Launch2CandlePhase _phase = Launch2CandlePhase.loading;
  List<Launch2Candle> _candles = const <Launch2Candle>[];
  Launch2CandleSource _source = Launch2CandleSource.unknown;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  bool _disposed = false;

  /// Bumped by every interval switch and full load: an answer for an older
  /// generation is dropped, never drawn under the wrong capsule.
  int _generation = 0;

  Launch2CandleInterval get interval => _interval;
  Launch2CandlePhase get phase => _phase;
  List<Launch2Candle> get candles => _candles;
  Launch2CandleSource get source => _source;
  bool get hasOlder => _hasOlder;
  bool get loadingOlder => _loadingOlder;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// The first page of the current interval, from nothing.
  Future<void> load() async {
    final generation = ++_generation;
    _phase = Launch2CandlePhase.loading;
    _candles = const <Launch2Candle>[];
    _hasOlder = false;
    _loadingOlder = false;
    _notify();
    try {
      final series = await _gateway.candles(
        instanceId,
        _interval,
        limit: pageSize,
      );
      if (generation != _generation || _disposed) return;
      _candles = series.candles;
      _source = series.source;
      _hasOlder = series.candles.length >= pageSize;
      _phase = Launch2CandlePhase.ready;
    } on LoopChainException catch (failure) {
      if (generation != _generation || _disposed) return;
      _phase = launch2CandlesHiddenFor(failure.kind)
          ? Launch2CandlePhase.hidden
          : Launch2CandlePhase.failed;
    } catch (_) {
      if (generation != _generation || _disposed) return;
      _phase = Launch2CandlePhase.failed;
    }
    _notify();
  }

  /// Another interval: starts over.
  Future<void> select(Launch2CandleInterval interval) {
    if (interval == _interval && _phase != Launch2CandlePhase.failed) {
      return Future<void>.value();
    }
    _interval = interval;
    return load();
  }

  /// The newest page again, merged over what is held: every held bucket
  /// older than the page's first stays, the rest is replaced. A failure
  /// keeps the chart as it was; the next interval tries again.
  Future<void> refresh() async {
    if (_phase != Launch2CandlePhase.ready) return;
    final generation = _generation;
    try {
      final series = await _gateway.candles(
        instanceId,
        _interval,
        limit: pageSize,
      );
      if (generation != _generation || _disposed) return;
      final fresh = series.candles;
      if (fresh.isEmpty) return;
      final first = fresh.first.openTime;
      _candles = List<Launch2Candle>.unmodifiable(<Launch2Candle>[
        for (final candle in _candles)
          if (candle.openTime.isBefore(first)) candle,
        ...fresh,
      ]);
      if (_candles.length == fresh.length) {
        _hasOlder = fresh.length >= pageSize;
      }
      _source = series.source;
      _notify();
    } catch (_) {
      // Silent: the chart already shows what was last read.
    }
  }

  /// The page before the oldest bucket held, prepended.
  Future<void> loadOlder() async {
    if (_phase != Launch2CandlePhase.ready ||
        !_hasOlder ||
        _loadingOlder ||
        _candles.isEmpty) {
      return;
    }
    final generation = _generation;
    _loadingOlder = true;
    _notify();
    try {
      final series = await _gateway.candles(
        instanceId,
        _interval,
        limit: pageSize,
        before: _candles.first.openTime,
      );
      if (generation != _generation || _disposed) return;
      final first = _candles.first.openTime;
      final older = <Launch2Candle>[
        for (final candle in series.candles)
          if (candle.openTime.isBefore(first)) candle,
      ];
      _hasOlder = series.candles.length >= pageSize && older.isNotEmpty;
      if (older.isNotEmpty) {
        _candles = List<Launch2Candle>.unmodifiable(<Launch2Candle>[
          ...older,
          ..._candles,
        ]);
      }
    } catch (_) {
      // The next pan to the left edge asks again.
    } finally {
      if (generation == _generation && !_disposed) {
        _loadingOlder = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Where the 毕业 rule goes, or `null` when it does not belong on the
/// chart: only a graduated instance, only a series that crosses from the
/// curve into the pool, and only when the moment lies within the buckets
/// held.
DateTime? launch2CandleGraduationMark({
  required Launch2Stage stage,
  required DateTime? graduatedAt,
  required Launch2CandleSource source,
  required List<Launch2Candle> candles,
  required Launch2CandleInterval interval,
}) {
  if (stage != Launch2Stage.graduated || graduatedAt == null) return null;
  if (source == Launch2CandleSource.curve ||
      source == Launch2CandleSource.pool) {
    return null;
  }
  if (candles.isEmpty) return null;
  if (graduatedAt.isBefore(candles.first.openTime)) return null;
  if (!graduatedAt.isBefore(candles.last.openTime.add(interval.width))) {
    return null;
  }
  return graduatedAt;
}

/// The K line card (decision 0227).
class Launch2CandleCard extends ConsumerStatefulWidget {
  const Launch2CandleCard({
    required this.detail,
    super.key,
    this.refreshInterval = const Duration(seconds: 15),
  });

  final Launch2InstanceDetail detail;

  /// How often the newest page is read again while the page is in view.
  final Duration refreshInterval;

  /// The chart's height (decision 0227: 220).
  static const double chartHeight = 220;

  @override
  ConsumerState<Launch2CandleCard> createState() => _Launch2CandleCardState();
}

class _Launch2CandleCardState extends ConsumerState<Launch2CandleCard> {
  late final Launch2CandleFeed _feed;
  late final LoopForegroundPoll _poll;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _feed = Launch2CandleFeed(
      gateway: ref.read(launch2GatewayProvider),
      instanceId: widget.detail.instanceId,
      interval: launch2DefaultCandleInterval(widget.detail.stage),
    )..addListener(_changed);
    _poll = LoopForegroundPoll(
      interval: widget.refreshInterval,
      read: _feed.refresh,
    );
  }

  /// The first read starts from the first build that finds the `launch2`
  /// reads open; a closed capability never sends one.
  bool _started = false;

  void _changed() {
    if (!mounted) return;
    final wantPoll = _feed.phase == Launch2CandlePhase.ready;
    if (wantPoll && !_polling) {
      _polling = true;
      _poll.start();
    } else if (!wantPoll && _polling) {
      _polling = false;
      _poll.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _poll.stop();
    _feed
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _poll.setVisible(LoopForegroundPoll.pageVisible(context));
    final blocked = launch2ReadsBlocked(ref);
    if (!blocked && !_started) {
      _started = true;
      scheduleMicrotask(() {
        if (mounted) unawaited(_feed.load());
      });
    }
    if (blocked || _feed.phase == Launch2CandlePhase.hidden) {
      return const SizedBox.shrink(key: ValueKey<String>('launch2-candles'));
    }
    final intervals = Launch2CandleInterval.values;
    return LoopRecordCard(
      key: const ValueKey<String>('launch2-candles'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopSegBar(
            key: const ValueKey<String>('launch2-candles-intervals'),
            labels: <String>[for (final i in intervals) i.label],
            selectedIndex: intervals.indexOf(_feed.interval),
            padding: const EdgeInsets.only(bottom: 8),
            onSelected: (index) => unawaited(_feed.select(intervals[index])),
          ),
          SizedBox(height: Launch2CandleCard.chartHeight, child: _body()),
        ],
      ),
    );
  }

  Widget _body() => switch (_feed.phase) {
    Launch2CandlePhase.loading ||
    Launch2CandlePhase.hidden => const LoopSkeletonBlock(
      key: ValueKey<String>('launch2-candles-loading'),
      height: Launch2CandleCard.chartHeight,
      radius: LoopRadius.innerValue,
    ),
    Launch2CandlePhase.failed => _Failed(
      onRetry: () => unawaited(_feed.load()),
    ),
    Launch2CandlePhase.ready when _feed.candles.isEmpty => const _Empty(),
    Launch2CandlePhase.ready => _chart(),
  };

  Widget _chart() {
    final detail = widget.detail;
    final interval = _feed.interval;
    final now = ref.read(launch2ClockProvider)();
    final candles = <LoopCandle>[
      for (final candle in _feed.candles) candle.toChart(interval.width, now),
    ];
    final mark = launch2CandleGraduationMark(
      stage: detail.stage,
      graduatedAt: detail.graduation?.graduatedAt ?? detail.row.graduatedAt,
      source: _feed.source,
      candles: _feed.candles,
      interval: interval,
    );
    return LoopMarketChart(
      key: ValueKey<String>('launch2-candles-chart-${interval.wireName}'),
      candles: candles,
      interval: interval.axis,
      style: LoopChartStyle.candles,
      height: Launch2CandleCard.chartHeight,
      priceFormatter: launch2PriceLabel,
      axisStyle: LoopType.figureXs.copyWith(color: LoopColors.text3),
      priceAxisWidth: 66,
      retainViewport: true,
      onReachStart: () => unawaited(_feed.loadOlder()),
      markers: <LoopChartMarker>[
        if (mark != null)
          LoopChartMarker(
            at: mark,
            label: '毕业',
            color: LoopColors.purple,
            keyName: 'launch2-candles-graduation',
          ),
      ],
      semanticLabel:
          '${candles.length} 根${interval.label} K 线，单位 USD1'
          '${mark == null ? '' : '，含毕业时刻'}',
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: launch2CandlesFailedText,
    excludeSemantics: true,
    child: LoopPressable(
      key: const ValueKey<String>('launch2-candles-retry'),
      onTap: onRetry,
      scale: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            launch2CandlesFailedText,
            textAlign: TextAlign.center,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      ),
    ),
  );
}

/// No trade yet: grey ghost candles behind one line of copy.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey<String>('launch2-candles-empty'),
    fit: StackFit.expand,
    children: <Widget>[
      const ExcludeSemantics(
        child: CustomPaint(painter: _GhostCandlesPainter()),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            launch2CandlesEmptyText,
            textAlign: TextAlign.center,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      ),
    ],
  );
}

/// A fixed, quiet silhouette of a K line: placeholder geometry only, no
/// figure, no colour of rise or fall.
class _GhostCandlesPainter extends CustomPainter {
  const _GhostCandlesPainter();

  /// Body top / bottom as fractions of the plot height, left to right.
  static const List<(double, double)> _bodies = <(double, double)>[
    (0.62, 0.74),
    (0.55, 0.66),
    (0.58, 0.70),
    (0.48, 0.60),
    (0.50, 0.57),
    (0.40, 0.52),
    (0.44, 0.50),
    (0.34, 0.46),
    (0.38, 0.48),
    (0.30, 0.40),
    (0.33, 0.44),
    (0.26, 0.36),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final grid = Paint()
      ..color = LoopColors.chalk.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row += 1) {
      final y = size.height * 0.78 * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final body = Paint()..color = LoopColors.text3.withValues(alpha: 0.14);
    final wick = Paint()
      ..color = LoopColors.text3.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final slot = size.width / _bodies.length;
    final width = math.min(10.0, slot * 0.5);
    for (var index = 0; index < _bodies.length; index += 1) {
      final (top, bottom) = _bodies[index];
      final x = slot * (index + 0.5);
      canvas.drawLine(
        Offset(x, size.height * (top - 0.05)),
        Offset(x, size.height * (bottom + 0.05)),
        wick,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          x - width / 2,
          size.height * top,
          x + width / 2,
          size.height * bottom,
        ),
        body,
      );
      final volume = 0.06 + 0.08 * ((index * 7) % 5) / 4;
      canvas.drawRect(
        Rect.fromLTRB(
          x - width / 2,
          size.height * (1 - volume),
          x + width / 2,
          size.height,
        ),
        body,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GhostCandlesPainter oldDelegate) => false;
}
