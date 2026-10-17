import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';

// ---------------------------------------------------------------------------
// 发射台的主事件 (decision 0163 docs/32 §3, drawn since decision 0164 as the
// prototype's Launch Desk — `launch2_launchpad.dart`)
// ---------------------------------------------------------------------------
//
// What is happening now and what opens next, chosen from the rows the list
// has already read — no request of its own. The first row is the desk's
// main event: the Lime ledger card and its record card. These are the words
// and the figures; the widgets live with the rest of the desk.

/// The rows of the list's first page (`limit=30`, loop_v2_launch2_api): the
/// merged list keeps them first, deeper pages only follow, so the hero picks
/// from these and a page read further down never reshuffles it.
const int launch2HeroFirstPageRows = 30;

/// The most rows the hero picks.
const int launch2HeroLimit = 5;

/// 内盘冲刺: a public curve this far sold (bps) earns a place.
const int launch2HeroSprintBps = 7000;

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

/// Where the desk opens a row (docs/32 §3.2): the NFT mint page while the NFT is
/// the thing to do (`upcoming`, `nft_sale`), the project page otherwise.
String launch2HeroLocation(Launch2InstanceRow row) => switch (row.stage) {
  Launch2Stage.upcoming ||
  Launch2Stage.nftSale => Launch2Route.nft(row.instanceId),
  _ => Launch2Route.instance(row.instanceId),
};

/// The stage sentence (状态句).
String launch2HeroHeadline(Launch2Stage stage, {required bool sprint}) =>
    switch (stage) {
      Launch2Stage.upcoming => '铸造倒计时',
      Launch2Stage.nftSale => '共识勋章铸造中',
      Launch2Stage.snapshotPending => '名单生成中',
      Launch2Stage.priority => '白名单提前购',
      Launch2Stage.public => sprint ? '内盘冲刺' : '公开内盘',
      _ => launch2StageLabel(stage),
    };

/// Whether the stage is open now (it mints or takes orders): only such a
/// row earns the desk's second record card.
bool launch2HeroLit(Launch2Stage stage) =>
    stage == Launch2Stage.nftSale ||
    stage == Launch2Stage.priority ||
    stage == Launch2Stage.public;

/// The record card's foot line.
String launch2HeroDetail(Launch2InstanceRow row) {
  final sale = row.nftSale;
  final perNft = '${launch2Usd1Label(sale.priceUsd1)} / 枚';
  return switch (row.stage) {
    Launch2Stage.upcoming => '$perNft · 铸造期 ${launch2SaleDurationLabel(sale)}',
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

/// How far the record card's `.bar` is filled, or `null` when it draws none
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

/// What the desk says aloud about a row, in one sentence.
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
      Launch2Stage.upcoming => <String>[left == null ? '铸造时间待定' : '距铸造 $left'],
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

// ---- the desk's words (decision 0164) ---------------------------------------

/// 「10-18 17:32」: a sale time on the reader's own clock, month first.
String launch2ShortDateTime(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// The ledger card's second heading line: 共识勋章铸造中 / 白名单提前购 /
/// 内盘冲刺 82% / 铸造倒计时.
String launch2DeskStatus(Launch2InstanceRow row) {
  final sprint = row.curve.soldBps >= launch2HeroSprintBps;
  final headline = launch2HeroHeadline(row.stage, sprint: sprint);
  if (row.stage == Launch2Stage.public && sprint) {
    return '$headline ${launch2BpsLabel(row.curve.soldBps)}';
  }
  return headline;
}

/// The ledger card's caption: one sentence of figures.
String launch2DeskCaption(Launch2InstanceRow row) {
  final sale = row.nftSale;
  final perNft = '${launch2Usd1Label(sale.priceUsd1)} / 枚';
  return switch (row.stage) {
    Launch2Stage.nftSale =>
      '已铸 ${sale.soldCount} 枚 · $perNft。'
          '持有即进快照名单，名单发布后 1 小时提前购。',
    // The list row carries no snapshot size; the minted count is the
    // figure it does carry.
    Launch2Stage.priority =>
      '已铸 ${sale.soldCount} 枚 · '
          '内盘已售 ${launch2BpsLabel(row.curve.soldBps)} · '
          '${launch2HeroPrice(row.curve.priceUsd1)}',
    Launch2Stage.public =>
      '${launch2HeroPrice(row.curve.priceUsd1)} · 卖满 8 亿自动毕业',
    Launch2Stage.upcoming =>
      '${launch2ShortDateTime(sale.startAt)} 开始铸造 · $perNft · '
          '铸造期 ${launch2SaleDurationLabel(sale)}',
    _ => launch2HeroDetail(row),
  };
}

/// The words before the stamp's countdown: 「剩」 while it runs, 「距铸造」
/// before it opens.
String launch2DeskStampPrefix(Launch2Stage stage) =>
    stage == Launch2Stage.upcoming ? '距铸造 ' : '剩 ';

/// The record card's second line, after the name.
String launch2RecordSubtitle(Launch2InstanceRow row) {
  final sale = row.nftSale;
  final next = row.nextChangeAt;
  final tail = switch (row.stage) {
    Launch2Stage.nftSale =>
      '铸造期 ${launch2SaleDurationLabel(sale)} · '
          '截止 ${launch2ShortDateTime(sale.endAt)}',
    Launch2Stage.priority =>
      next == null ? '白名单提前购' : '白名单提前购 · 截止 ${launch2ShortDateTime(next)}',
    Launch2Stage.public => '公开内盘 · 人人可买，卖满即毕业',
    Launch2Stage.upcoming => '${launch2ShortDateTime(sale.startAt)} 开始铸造',
    _ => launch2StageLabel(row.stage),
  };
  return '${row.name} · $tail';
}

/// What the record card's right-hand figure measures.
String launch2RecordFigureCaption(Launch2Stage stage) => switch (stage) {
  Launch2Stage.nftSale => '铸造剩余',
  Launch2Stage.priority => '提前购剩余',
  Launch2Stage.upcoming => '距铸造',
  _ => '内盘进度',
};

/// Whether the record card's figure is a countdown (else the share sold).
bool launch2RecordCountsDown(Launch2Stage stage) =>
    stage == Launch2Stage.nftSale ||
    stage == Launch2Stage.priority ||
    stage == Launch2Stage.upcoming;

/// The record card's foot line: how far the bar is, then the figures.
String launch2RecordFoot(Launch2InstanceRow row, DateTime now) {
  if (row.stage != Launch2Stage.nftSale) return launch2HeroDetail(row);
  final past = ((launch2HeroFuse(row, now) ?? 0) * 100).round();
  return '铸造期已过 $past% · ${launch2HeroDetail(row)}';
}
