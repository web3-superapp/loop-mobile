import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';

// ---------------------------------------------------------------------------
// 发射台 · the prototype's Launch Desk (decision 0164; data since 0163,
// docs/32 §7)
// ---------------------------------------------------------------------------
//
// The frozen prototype's Launch page, part for part: one ledger card for
// the main event, the segment counts, a record card for its progress, then
// `.label` groups of rows, the 战绩 stat figures and the curation notice.
// S241b (decision 0210): the ledger card is the flat looplabs card — `#111114`
// behind a 1px `#38333E` edge — with the ticker in Yellow and the stage line
// in Purple; Yellow is otherwise kept for figures and the one text action.

// ---- the live tape's words ---------------------------------------------

/// 「刚刚」, 「N 分钟前」, then the local 「HH:mm」.
String launch2RelativeTime(DateTime at, DateTime now) {
  final age = now.difference(at);
  if (age < const Duration(minutes: 1)) return LoopL10n.current.common_justNow;
  if (age < const Duration(hours: 1)) {
    return LoopL10n.current.launch2_launch2LaunchpadLaunch2RelativeTime(
      age.inMinutes,
    );
  }
  return loopLocalClockLabel(at);
}

/// 「0x1d2f…9b」: the actor as the tape prints it.
String launch2TapeActor(String? actor) {
  if (actor == null) {
    return LoopL10n.current.launch2_launch2LaunchpadLaunch2TapeActor;
  }
  if (actor.length <= 10) return actor;
  return '${actor.substring(0, 6)}…${actor.substring(actor.length - 2)}';
}

/// Who did it, as the tape names them: the LOOP account's name when the
/// server attached one (loop-api decision 0162 §A, S239), else the short
/// address, else 「有人」.
String launch2ActivityWho(Launch2Activity item) {
  final name = item.account?.displayName;
  if (name != null && name.trim().isNotEmpty) return '$name ';
  // 「有人买入」 runs on; an address takes a space before the verb.
  return item.actor == null
      ? LoopL10n.current.launch2_launchpadSomeoneWho
      : '${launch2TapeActor(item.actor)} ';
}

/// One tape item's sentence, without its time.
String launch2ActivityText(Launch2Activity item) {
  final who = launch2ActivityWho(item);
  final ticker = item.ticker;
  final amount = item.amountUsd1;
  final usd1 = amount == null ? '' : ' ${launch2Usd1Label(amount)}';
  return switch (item.kind) {
    Launch2ActivityKind.curveBuy =>
      LoopL10n.current.launch2_launch2LaunchpadCurveBuy(ticker, usd1, who),
    Launch2ActivityKind.curveSell =>
      LoopL10n.current.launch2_launch2LaunchpadCurveSell(ticker, usd1, who),
    Launch2ActivityKind.nftMint =>
      LoopL10n.current.launch2_launch2LaunchpadNftMint(ticker, who),
    Launch2ActivityKind.graduated =>
      LoopL10n.current.launch2_launch2LaunchpadGraduated(ticker),
    Launch2ActivityKind.buyback =>
      LoopL10n.current.launch2_launch2LaunchpadBuyback(ticker, usd1),
    Launch2ActivityKind.roundActivated =>
      LoopL10n.current.launch2_launch2LaunchpadRoundActivated(ticker),
    Launch2ActivityKind.rewardClaimed =>
      LoopL10n.current.launch2_launch2LaunchpadRewardClaimed(ticker, usd1, who),
  };
}

/// The whole line: 「刚刚 0x1d2f…9b 买入 DOGE 20 USD1」.
String launch2ActivityLine(Launch2Activity item, DateTime now) =>
    '${launch2RelativeTime(item.at, now)} ${launch2ActivityText(item)}';

// ---- the stage groups ------------------------------------------------------

/// The groups of the 「v2 发射」 list (docs/32 §7.4), in order.
enum Launch2StageGroup {
  minting(),
  priority(),
  curve(),
  snapshot(),
  upcoming(),
  graduated(),
  closed();

  const Launch2StageGroup();

  String get title => switch (this) {
    Launch2StageGroup.minting => LoopL10n.current.launch2_launch2FormatNftSale,

    Launch2StageGroup.priority =>
      LoopL10n.current.launch2_launch2FormatPriority,

    Launch2StageGroup.curve => LoopL10n.current.launch2_launch2InstanceLabel,

    Launch2StageGroup.snapshot =>
      LoopL10n.current.launch2_launch2AtmosphereSwitch2,

    Launch2StageGroup.upcoming =>
      LoopL10n.current.launch2_launch2LaunchpadUpcoming,

    Launch2StageGroup.graduated => LoopL10n.current.common_graduated,

    Launch2StageGroup.closed => LoopL10n.current.launch2_launch2LaunchpadClosed,
  };

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

// ---- the desk's segment counts ---------------------------------------------

/// The four counts under the ledger card, each the groups it stands for.
enum Launch2DeskSegment {
  minting(<Launch2StageGroup>[Launch2StageGroup.minting]),
  curve(<Launch2StageGroup>[
    Launch2StageGroup.priority,
    Launch2StageGroup.curve,
  ]),
  upcoming(<Launch2StageGroup>[Launch2StageGroup.upcoming]),
  graduated(<Launch2StageGroup>[Launch2StageGroup.graduated]);

  const Launch2DeskSegment(this.groups);

  String get title => switch (this) {
    Launch2DeskSegment.minting => LoopL10n.current.launch2_launch2FormatNftSale,

    Launch2DeskSegment.curve => LoopL10n.current.launch2_launch2InstanceLabel,

    Launch2DeskSegment.upcoming =>
      LoopL10n.current.launch2_launch2LaunchpadUpcoming,

    Launch2DeskSegment.graduated => LoopL10n.current.common_graduated,
  };
  final List<Launch2StageGroup> groups;

  static Launch2DeskSegment? of(Launch2Stage stage) {
    final group = Launch2StageGroup.of(stage);
    for (final segment in values) {
      if (segment.groups.contains(group)) return segment;
    }
    return null;
  }
}

/// How many projects each segment holds: the overview's platform figures
/// when they were read, else the rows read so far. A zero is kept.
List<(Launch2DeskSegment, int)> launch2DeskCounts(
  List<Launch2InstanceRow> rows,
  Launch2Stats? stats,
) {
  int counted(Launch2DeskSegment segment) => rows
      .where((row) => segment.groups.contains(Launch2StageGroup.of(row.stage)))
      .length;
  return <(Launch2DeskSegment, int)>[
    for (final segment in Launch2DeskSegment.values)
      (
        segment,
        stats == null
            ? counted(segment)
            : switch (segment) {
                Launch2DeskSegment.minting => stats.mintingCount,
                Launch2DeskSegment.curve =>
                  stats.priorityCount + stats.curveCount,
                Launch2DeskSegment.upcoming => stats.upcomingCount,
                Launch2DeskSegment.graduated => stats.graduatedTotal,
              },
      ),
  ];
}

// ---- the home's tabs (S279) --------------------------------------------------

/// The MEME home's three tabs (S279 · decision 0237, 需求方 2026-10-22 第 15
/// 条): one list on screen at a time instead of every group stacked.
///
/// 「内盘」 holds every project that is running or stopped before its pool —
/// 铸造中, 提前购, 内盘, 名单生成中 and 已暂停 — each row wearing its own stage
/// capsule; 「预告」 the queued ones; 「已毕业」 the `stage=graduated` list.
enum Launch2DeskTab {
  live(<Launch2StageGroup>[
    Launch2StageGroup.minting,
    Launch2StageGroup.priority,
    Launch2StageGroup.curve,
    Launch2StageGroup.snapshot,
    Launch2StageGroup.closed,
  ]),
  upcoming(<Launch2StageGroup>[Launch2StageGroup.upcoming]),
  graduated(<Launch2StageGroup>[Launch2StageGroup.graduated]);

  const Launch2DeskTab(this.groups);

  String get title => switch (this) {
    Launch2DeskTab.live => LoopL10n.current.launch2_launch2InstanceLabel,

    Launch2DeskTab.upcoming =>
      LoopL10n.current.launch2_launch2LaunchpadUpcoming,

    Launch2DeskTab.graduated => LoopL10n.current.common_graduated,
  };
  final List<Launch2StageGroup> groups;

  static Launch2DeskTab of(Launch2Stage stage) {
    final group = Launch2StageGroup.of(stage);
    return values.firstWhere((tab) => tab.groups.contains(group));
  }

  /// Whether [row] belongs on this tab.
  bool holds(Launch2InstanceRow row) =>
      groups.contains(Launch2StageGroup.of(row.stage));
}

/// Each tab's count from the desk's segment counts: 内盘 is 铸造中 + 内盘.
List<(Launch2DeskTab, int)> launch2DeskTabCounts(
  List<(Launch2DeskSegment, int)> counts,
) {
  int of(Launch2DeskSegment segment) =>
      counts.firstWhere((entry) => entry.$1 == segment).$2;
  return <(Launch2DeskTab, int)>[
    (
      Launch2DeskTab.live,
      of(Launch2DeskSegment.minting) + of(Launch2DeskSegment.curve),
    ),
    (Launch2DeskTab.upcoming, of(Launch2DeskSegment.upcoming)),
    (Launch2DeskTab.graduated, of(Launch2DeskSegment.graduated)),
  ];
}

/// The tab the home opens on before the reader picks one: the main event's,
/// else the first holding projects, else 内盘.
Launch2DeskTab launch2DefaultDeskTab(
  Launch2InstanceRow? main,
  List<(Launch2DeskTab, int)> counts,
) {
  if (main != null) return Launch2DeskTab.of(main.stage);
  for (final (tab, count) in counts) {
    if (count > 0) return tab;
  }
  return Launch2DeskTab.live;
}

/// The rows the desk gives a record card: the main event, and a second one
/// only when it is open now too (it mints or takes orders).
List<Launch2InstanceRow> launch2DeskRecordRows(List<Launch2InstanceRow> hero) =>
    <Launch2InstanceRow>[
      if (hero.isNotEmpty) hero.first,
      if (hero.length > 1 && launch2HeroLit(hero[1].stage)) hero[1],
    ];

/// `LAUNCH DESK · BSC` (decision 0204: the testnet stamp is a test-only
/// hint, drawn only while the test-hints switch is on).
String launch2DeskKicker(String? chainId) {
  if (chainId == null) return LoopL10n.current.common_launchpad;
  return loopTestnetBadgeFor(chainId) != null
      ? LoopL10n.current.launch2_launch2LaunchpadLaunch2DeskKicker(
          loopTestnetStampText,
        )
      : LoopL10n.current.launch2_launch2LaunchpadS;
}

// ---- the desk's pages ---------------------------------------------------------

/// One page of the desk's pager (decision 0164, user addendum 2026-10-14):
/// a live or upcoming event, or — later — an operations campaign card.
sealed class Launch2DeskPage {
  const Launch2DeskPage();

  /// Stable across re-reads, for the page's key.
  String get id;
}

/// A row of [launch2HeroRows]: one page per event, in that order.
final class Launch2DeskEventPage extends Launch2DeskPage {
  const Launch2DeskEventPage(this.row);

  final Launch2InstanceRow row;

  @override
  String get id => 'event-${row.instanceId}';
}

final class Launch2DeskCampaignPage extends Launch2DeskPage {
  const Launch2DeskCampaignPage(this.campaign);

  final Launch2DeskCampaign campaign;

  @override
  String get id => 'campaign-${campaign.campaignId}';
}

/// The most pages the desk shows (decision 0165).
const int launch2DeskPageLimit = 5;

/// An upcoming campaign this close to its start earns a page.
const Duration launch2CampaignHorizon = Duration(days: 7);

/// The desk's pages (decision 0165): the events running now (every
/// [launch2HeroRows] row but the previews), then the pinned campaigns, then
/// the previews (`upcoming`), then the other campaigns running at [now],
/// then the campaigns that start within [launch2CampaignHorizon]; at most
/// [launch2DeskPageLimit], the rest cut. Campaigns keep the server's order
/// (pinned, `sortOrder`, `startsAt`) inside each step; one that is over at
/// [now], or starts further out, has no page — pinned or not. Empty: the
/// desk draws its one empty page.
List<Launch2DeskPage> launch2DeskPages(
  List<Launch2InstanceRow> hero, {
  List<Launch2DeskCampaign> campaigns = const <Launch2DeskCampaign>[],
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final shown = <Launch2DeskCampaign>[
    for (final campaign in campaigns)
      if (at.isBefore(campaign.endsAt) &&
          !campaign.startsAt.isAfter(at.add(launch2CampaignHorizon)))
        campaign,
  ];
  bool preview(Launch2InstanceRow row) => row.stage == Launch2Stage.upcoming;
  return <Launch2DeskPage>[
    for (final row in hero)
      if (!preview(row)) Launch2DeskEventPage(row),
    for (final campaign in shown)
      if (campaign.pinned) Launch2DeskCampaignPage(campaign),
    for (final row in hero)
      if (preview(row)) Launch2DeskEventPage(row),
    for (final campaign in shown)
      if (!campaign.pinned && campaign.liveAt(at))
        Launch2DeskCampaignPage(campaign),
    for (final campaign in shown)
      if (!campaign.pinned && !campaign.liveAt(at))
        Launch2DeskCampaignPage(campaign),
  ].take(launch2DeskPageLimit).toList(growable: false);
}

/// Every banner page's height at text scale 1 (S264, decision 0220: the
/// atmosphere banner; 200 before). Since decision 0223 the event pages share
/// it — 232 before. S326 · decision 0256 (UX-004 ⑧): 180 (220 before) —
/// the words sit closer and the banner gives the list more of the screen.
/// S353b · decision 0279 (docs/58 §5.5): the Figma's 162 (353 × 162).
const double launch2DeskCampaignHeight = 162;

/// The height of the dot row under the pager (decision 0211).
const double launch2DeskDotsHeight = 18;

/// From two pages on, the dot row under the card: 8 above the dots, the
/// dots 6 high (S361 · decision 0286 — nothing hangs past the card any more).
const double launch2DeskDotsRow = 14;

/// docs/58 §9 (S361 · decision 0286): the banner's foot to the trade band's
/// top, 16.
const double launch2DeskBandGap = 16;

/// `.ledger-card.folio-primary` as a sideways pager: one flat card per
/// page, the page width the screen less the two 16 gutters, dots at the
/// right end of the kicker line from two pages on. It never moves by itself. One page looks
/// exactly like the card alone.
class Launch2DeskPager extends StatefulWidget {
  const Launch2DeskPager({
    required this.pages,
    required this.chainId,
    required this.onNavigate,
    super.key = const ValueKey<String>('launch2-desk'),
    this.onElapsed,
  });

  final List<Launch2DeskPage> pages;
  final String? chainId;
  final void Function(String location) onNavigate;

  /// A page's countdown reached zero: the list re-reads the server.
  final VoidCallback? onElapsed;

  @override
  State<Launch2DeskPager> createState() => _Launch2DeskPagerState();
}

class _Launch2DeskPagerState extends State<Launch2DeskPager> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _current = 0;

  Widget _card(Launch2DeskPage? page) {
    return switch (page) {
      null => Launch2DeskFolio(row: null, chainId: widget.chainId),
      Launch2DeskEventPage(:final row) => Launch2DeskFolio(
        key: ValueKey<String>('launch2-desk-page-${row.instanceId}'),
        row: row,
        chainId: widget.chainId,
        onTap: () => widget.onNavigate(launch2HeroLocation(row)),
        onElapsed: widget.onElapsed,
      ),
      Launch2DeskCampaignPage(:final campaign) => Launch2DeskCampaignCard(
        key: ValueKey<String>('launch2-desk-page-${page.id}'),
        campaign: campaign,
        onNavigate: widget.onNavigate,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    // Decision 0223: every page — event, campaign or the empty desk — is
    // the same 220 high banner on the same art.
    final height = MediaQuery.textScalerOf(context)
        .scale(launch2DeskCampaignHeight);
    final count = pages.length;
    final current = _current.clamp(0, count == 0 ? 0 : count - 1);
    // S361 · decision 0286: the pager is the card's height (plus the dot
    // row from two pages on); the band's top stands 16 under it — the band
    // sits centred in its 44 tap row, so the pager keeps the rest.
    final dots = count >= 2 ? launch2DeskDotsRow : 0.0;
    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: launch2DeskBandGap - (44 - Launch2TradeTicker.bandHeight) / 2,
      ),
      child: SizedBox(
        height: height + dots,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: PageView.builder(
                key: const ValueKey<String>('launch2-desk-pages'),
                controller: _controller,
                itemCount: pages.isEmpty ? 1 : pages.length,
                onPageChanged: (index) => setState(() => _current = index),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    LoopSpacing.page,
                    0,
                    LoopSpacing.page,
                    dots,
                  ),
                  child: _card(pages.isEmpty ? null : pages[index]),
                ),
              ),
            ),
            // Decision 0211: small dots under the pager, from two pages on —
            // the current one a 16 wide Purple capsule, the others Chalk 28 %.
            if (count >= 2)
              Positioned(
                left: 0,
                right: 0,
                top: height + launch2DeskDotsRow - 6,
                child: Center(
                  child: _DeskDots(count: count, current: current),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeskDots extends StatelessWidget {
  const _DeskDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      key: const ValueKey<String>('launch2-desk-dots'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Container(
            key: ValueKey<String>('launch2-desk-dot-$i'),
            // docs/42 附C §5: 6 px round dots, the current one Purple.
            width: i == current ? 16 : 6,
            height: 6,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            decoration: BoxDecoration(
              color: i == current
                  ? LoopColors.purple
                  : LoopColors.chalk.withValues(alpha: 0.28),
              borderRadius: LoopRadius.round,
            ),
          ),
      ],
    ),
  );
}

/// One event page of the pager (decision 0223): the same default art as a
/// campaign page, with the event's words in the left column — the kicker,
/// the ticker over the Purple brush, the stage line in light Purple, one
/// caption of figures and, at the column's foot where a campaign has its
/// button, the countdown on a small Ink capsule. With no event, the empty
/// desk on the same art. The whole card is one tap; there is no button.
class Launch2DeskFolio extends ConsumerWidget {
  const Launch2DeskFolio({
    required this.row,
    required this.chainId,
    super.key,
    this.onTap,
    this.onElapsed,
  });

  /// The event; `null` draws the empty desk.
  final Launch2InstanceRow? row;
  final String? chainId;
  final VoidCallback? onTap;

  /// The countdown reached zero: the list re-reads the server.
  final VoidCallback? onElapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kicker = launch2DeskKicker(chainId);
    final event = row;
    if (event == null) {
      // S350b · decision 0275: the empty desk says the fact and nothing
      // about what will appear (需求方 10-26, decision 0248).
      return Launch2DeskEventFace(
        kicker: kicker,
        title: context.l10n.launch2_launch2LaunchpadTitle,
        // S353b: a sentence, not a ticker — it wraps instead of shrinking.
        titleWraps: true,
      );
    }
    final ticker = launch2HeroTicker(event.ticker);
    final status = launch2DeskStatus(event);
    Widget face(String? stamp) => Launch2DeskEventFace(
      kicker: kicker,
      title: ticker,
      status: status,
      caption: launch2DeskCaption(event),
      stamp: stamp,
    );
    final next = event.nextChangeAt;
    final card = next == null || !launch2RecordCountsDown(event.stage)
        ? face(null)
        : Launch2CountdownBuilder(
            target: next,
            onElapsed: onElapsed,
            builder: (context, text) =>
                face('${launch2DeskStampPrefix(event.stage)}$text'),
          );
    return Semantics(
      button: true,
      label: launch2HeroSpokenLabel(event, ref.read(launch2ClockProvider)()),
      excludeSemantics: true,
      child: LoopPressable(onTap: onTap, scale: false, child: card),
    );
  }
}

/// The words of an event page over [Launch2BannerBackdrop] (decision 0223).
class Launch2DeskEventFace extends StatelessWidget {
  const Launch2DeskEventFace({
    required this.kicker,
    required this.title,
    super.key,
    this.status,
    this.caption,
    this.stamp,
    this.titleWraps = false,
  });

  /// The title is a sentence (the empty desk): two lines at 19 / 700
  /// rather than one line shrunk to fit (S353b, English copy).
  final bool titleWraps;

  /// 「发射台 · BSC TESTNET」: 12, Text2.
  final String kicker;

  /// The ticker (or the empty desk's sentence): 26 / 700 Chalk on one line,
  /// over the Purple brush.
  final String title;

  /// The stage line (「提前购进行中」): 14, light Purple.
  final String? status;

  /// The figures (「已铸 3 枚 · 内盘已售 0% · …」): 12, Text2, two lines.
  final String? caption;

  /// The countdown (「剩 38:04」) on the Ink capsule at the column's foot.
  final String? stamp;

  /// The title and the stage line as one heading, for reading back.
  String get heading => status == null ? title : '$title\n$status';

  @override
  Widget build(BuildContext context) {
    final line = status;
    final figures = caption;
    final left = stamp;
    return Stack(
      key: const ValueKey<String>('launch2-desk-event-card'),
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: <Widget>[
        const Launch2BannerBackdrop(),
        Positioned(
          left: Launch2BannerBackdrop.textLeft,
          top: Launch2BannerBackdrop.textTop,
          bottom: 0,
          right: 0,
          child: _BannerColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  kicker,
                  key: const ValueKey<String>('launch2-desk-event-kicker'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
                const SizedBox(height: 4),
                Launch2BannerTitle(
                  text: title,
                  textKey: const ValueKey<String>('launch2-desk-event-title'),
                  wraps: titleWraps,
                ),
                // S353b · decision 0279: the 162 banner (docs/58 §5.5) holds
                // the stage line at 14 and, beside a countdown, one line of
                // figures.
                const SizedBox(height: 4),
                if (line != null)
                  Text(
                    line,
                    key: const ValueKey<String>('launch2-desk-event-status'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.withWeight(
                      LoopType.body1,
                      FontWeight.w600,
                    ).copyWith(color: LoopColors.purpleInk),
                  ),
                if (figures != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    figures,
                    key: const ValueKey<String>('launch2-desk-event-caption'),
                    maxLines: left == null ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (left != null)
          Positioned(
            left: Launch2BannerBackdrop.textLeft,
            bottom: Launch2BannerBackdrop.footInset,
            child: Container(
              key: const ValueKey<String>('launch2-desk-event-countdown'),
              height: 28,
              // Inside the words' column and short of the hand, however long
              // the countdown reads.
              constraints: const BoxConstraints(maxWidth: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                color: LoopColors.ink,
                borderRadius: LoopRadius.pill,
              ),
              child: Center(
                widthFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    left,
                    maxLines: 1,
                    style: LoopTypography.withWeight(
                      LoopType.figureSm,
                      FontWeight.w600,
                    ).copyWith(color: LoopColors.chalk),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The banner's default art (decisions 0220 §4, 0222, 0223) under every
/// page of the desk — campaign, event or the empty desk alike: a dark ground
/// (the wall and the fogs went in decision 0291), the left-to-right Ink
/// wash, the chrome hand
/// in the card's bottom right corner (its sheen every 6 s), its Yellow crown
/// and the tilted 「IN THE LOOP」 tag. S361 · decision 0286 (docs/58 §5.5):
/// all of it inside the card's 8 corner — nothing hangs past its edges. A
/// page lays its words over the left column,
/// [Launch2BannerBackdrop.textWidth] wide.
class Launch2BannerBackdrop extends StatelessWidget {
  const Launch2BannerBackdrop({super.key});

  /// Where the words start, and how wide their column is: the right of the
  /// card is the hand's.
  static const double textLeft = 20;
  static const double textTop = 16;

  /// How far a page's foot control (the countdown, 「去参与」) sits from
  /// the card's bottom edge.
  static const double footInset = 14;

  /// The words' column at its widest (a 350 wide card and up).
  static const double textWidth = 186;

  /// The narrowest the words' column gets.
  static const double textMinWidth = 140;

  /// The chrome hand's box in the card's bottom right corner (S361 ·
  /// decision 0286): about 45 % of a 353 card's width, its art's 171 : 170
  /// shape, short of the 162 card's height.
  static const double handWidth = 158;
  static const double handHeight = 157;

  /// S350b · decision 0275: the words' column for a card [cardWidth] wide —
  /// it stops short of the chrome hand, which keeps its size, so on a 360
  /// screen the words wrap instead of running under the hand.
  static double textWidthFor(double cardWidth) =>
      (cardWidth - textLeft - 160).clamp(textMinWidth, textWidth);

  @override
  Widget build(BuildContext context) {
    Widget art(String path, {double? width}) => Image.asset(
      path,
      width: width,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => SizedBox(width: width),
    );
    return ClipRRect(
      key: const ValueKey<String>('launch2-campaign-default-art'),
      borderRadius: LoopRadius.chip,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // S367 · decision 0291: no wall, no fogs — the card's own dark
          // ground under the hand.
          const ColoredBox(color: Color(0xFF0E0D12)),
          const DecoratedBox(
            key: ValueKey<String>('launch2-campaign-scrim'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xD1070809),
                  Color(0x8C070809),
                  Color(0x00070809),
                ],
                stops: <double>[0, 0.52, 0.75],
              ),
            ),
          ),
          // S361 · decision 0286: the hand sits in the bottom right corner,
          // inside the card.
          const Positioned(
            right: 0,
            bottom: 0,
            width: handWidth,
            height: handHeight,
            child: Launch2ChromeHand(),
          ),
          Positioned(
            right: 118,
            top: 28,
            width: 62,
            child: Transform.rotate(
              key: const ValueKey<String>('launch2-banner-crown'),
              angle: -14 * math.pi / 180,
              child: art(LoopAtmoAssets.crownYellow, width: 62),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            width: 42,
            child: Transform.rotate(
              key: const ValueKey<String>('launch2-banner-tag'),
              angle: -5 * math.pi / 180,
              child: Opacity(
                opacity: 0.95,
                child: art(LoopAtmoAssets.tagInLoop, width: 42),
              ),
            ),
          ),
          // docs/58 §5.5: an 8 corner and a 1 px white 15 % edge, over all.
          const DecoratedBox(
            key: ValueKey<String>('launch2-banner-edge'),
            decoration: BoxDecoration(
              borderRadius: LoopRadius.chip,
              border: Border.fromBorderSide(
                BorderSide(color: LoopColors.bannerEdge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The title of a banner page: 26 / 700 Chalk on one line, over the Purple
/// brush stroke (the same on every page).
class Launch2BannerTitle extends StatelessWidget {
  const Launch2BannerTitle({
    required this.text,
    super.key,
    this.textKey,
    this.wraps = false,
  });

  final String text;
  final Key? textKey;

  /// Two lines at [LoopType.headline] instead of one shrunk line.
  final bool wraps;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      Positioned(
        left: -6,
        top: 25,
        width: 150,
        child: Image.asset(
          LoopAtmoAssets.brushPurple,
          width: 150,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox(width: 150),
        ),
      ),
      // S350b: a title wider than the column is set a little smaller, not
      // cut to 「暂无进行中…」.
      if (wraps)
        Text(
          text,
          key: textKey,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: LoopType.headline.copyWith(height: 1.3),
        )
      else
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            key: textKey,
            maxLines: 1,
            style: LoopType.display.copyWith(height: 1.2),
          ),
        ),
    ],
  );
}

/// The words' column of a banner page: [Launch2BannerBackdrop.textWidthFor]
/// the card's width, from the top left.
class _BannerColumn extends StatelessWidget {
  const _BannerColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: Launch2BannerBackdrop.textWidthFor(
          box.maxWidth + Launch2BannerBackdrop.textLeft,
        ),
        child: child,
      ),
    ),
  );
}

/// The campaign page (decision 0165; redrawn by decision 0212, then by S264
/// — decision 0220, the atmosphere banner). A 220 high, 16 radius card that
/// always stands on the default art (decision 0222): the wall under Purple
/// and Yellow fog and a left-to-right Ink wash, the chrome hand (it hangs
/// 14 / 16 past the card's right and bottom edges, its sheen sweeping every
/// 6 s) wearing the Yellow crown, and the tilted 「IN THE LOOP」 tag at the top
/// right. Only the words change per campaign: on the left the title (26 /
/// 700, Chalk) over a Purple brush stroke, the subtitle, the foot line
/// 「10-19 至 10-26 · 剩 6 天」 and a solid Yellow 「去参与」 40 high. A cover the
/// admin set is not requested. The whole card is one tap.
class Launch2DeskCampaignCard extends ConsumerStatefulWidget {
  const Launch2DeskCampaignCard({
    required this.campaign,
    required this.onNavigate,
    super.key,
  });

  final Launch2DeskCampaign campaign;

  /// Pushes an in-app route.
  final void Function(String location) onNavigate;

  /// The 「去参与」 button's height: the Figma's 36 medium button (S353b).
  static const double ctaHeight = LoopTouch.buttonMedium;

  @override
  ConsumerState<Launch2DeskCampaignCard> createState() =>
      _Launch2DeskCampaignCardState();
}

class _Launch2DeskCampaignCardState
    extends ConsumerState<Launch2DeskCampaignCard> {
  void _open() {
    final opener = ref.read(launch2ExternalLinkOpenerProvider);
    launch2OpenCampaign(
      widget.campaign,
      push: widget.onNavigate,
      openExternal: (uri) => unawaited(opener(context, uri)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final now = ref.read(launch2ClockProvider)();
    final stamp = launch2CampaignStamp(campaign, now);
    final id = campaign.campaignId;
    final subtitle = campaign.subtitle;
    // Decision 0222: every campaign stands on the default art; only the
    // words change. A cover the admin set is neither requested nor drawn.
    const ground = Launch2BannerBackdrop();
    return Semantics(
      button: true,
      label: <String>[
        context.l10n.launch2_launch2LaunchpadSemantics,
        campaign.title,
        ?subtitle,
        launch2CampaignKicker(campaign),
        stamp,
        campaign.ctaLabel,
      ].join(LoopL10n.current.common_listSeparator),
      excludeSemantics: true,
      child: LoopPressable(
        onTap: _open,
        scale: false,
        child: Stack(
          key: ValueKey<String>('launch2-campaign-card-$id'),
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: <Widget>[
            ground,
            Positioned(
              left: Launch2BannerBackdrop.textLeft,
              top: Launch2BannerBackdrop.textTop,
              bottom: 0,
              right: 0,
              child: _BannerColumn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Launch2BannerTitle(
                      text: campaign.title,
                      textKey: ValueKey<String>('launch2-campaign-title-$id'),
                    ),
                    // S353b · decision 0279: two caption lines fit the 162
                    // banner above its button.
                    const SizedBox(height: 4),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        key: ValueKey<String>('launch2-campaign-subtitle-$id'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.caption.copyWith(
                          color: LoopColors.chalk,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      launch2CampaignFootLine(campaign, now),
                      key: ValueKey<String>('launch2-campaign-stamp-$id'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: Launch2BannerBackdrop.textLeft,
              bottom: Launch2BannerBackdrop.footInset,
              child: Launch2YellowButton(
                key: ValueKey<String>('launch2-campaign-cta-$id'),
                label: campaign.ctaLabel,
                height: Launch2DeskCampaignCard.ctaHeight,
                maxWidth: 150,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- the record card ---------------------------------------------------------

/// `.record-card` of one live row: the row icon, the ticker over its line,
/// the countdown (or the share sold) on the right, the 6 px `.bar` and one
/// foot line under it.
class Launch2DeskRecordCard extends ConsumerWidget {
  const Launch2DeskRecordCard({
    required this.row,
    required this.onTap,
    super.key,
    this.onElapsed,
  });

  final Launch2InstanceRow row;
  final VoidCallback onTap;
  final VoidCallback? onElapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(launch2ClockProvider)();
    final id = row.instanceId;
    final fraction = launch2HeroFuse(row, now);
    final next = row.nextChangeAt;
    // R4 / R5 / R6, the same steps as the list's rows (decision 0190 M23).
    final figureStyle = LoopType.figure.copyWith(color: LoopColors.yellow);
    final figure = !launch2RecordCountsDown(row.stage)
        ? Text(
            launch2BpsLabel(row.curve.soldBps),
            maxLines: 1,
            style: figureStyle,
          )
        : next == null
        ? Text(
            context.l10n.launch2_launch2LaunchpadBuild,
            maxLines: 1,
            style: figureStyle,
          )
        : Launch2Countdown(
            target: next,
            onElapsed: onElapsed,
            style: figureStyle,
          );
    final minting = row.stage == Launch2Stage.nftSale;
    return Semantics(
      button: true,
      label: launch2HeroSpokenLabel(row, now),
      excludeSemantics: true,
      child: LoopRecordCard(
        key: ValueKey<String>('launch2-desk-record-$id'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (minting)
                  LoopMonoTile(label: _monogram(row.ticker), accent: true)
                else
                  MemeLogo(
                    symbol: row.ticker,
                    imageUrl: row.logoUrl,
                    identity: id,
                    size: 44,
                    radius: 15,
                  ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        launch2HeroTicker(row.ticker),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.title,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        launch2RecordSubtitle(row),
                        key: ValueKey<String>('launch2-desk-record-sub-$id'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.caption.copyWith(
                          color: LoopColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // S355a: the English caption is longer; it gives way.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      KeyedSubtree(
                        key: ValueKey<String>('launch2-desk-record-figure-$id'),
                        child: figure,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        launch2RecordFigureCaption(row.stage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.captionSm.copyWith(
                          color: LoopColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (fraction != null) ...<Widget>[
              const SizedBox(height: 11),
              LoopProgressBar(
                key: ValueKey<String>('launch2-desk-bar-$id'),
                value: fraction,
                semanticLabel: launch2RecordFoot(row, now),
              ),
            ],
            const SizedBox(height: 7),
            Text(
              launch2RecordFoot(row, now),
              key: ValueKey<String>('launch2-desk-record-foot-$id'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ],
        ),
      ),
    );
  }

  /// The `.row-ico` monogram: the ticker's first two characters.
  static String _monogram(String ticker) =>
      ticker.length <= 2 ? ticker : ticker.substring(0, 2);
}

// ---- the live tape -----------------------------------------------------------

/// The full list of recent trades behind the band's 「全部」 (S264: the band
/// replaced the three still lines; decision 0220): up to [expanded] lines on
/// the card ground, newest first; a line opens its project, a face its
/// owner's page.
class Launch2DeskTape extends StatelessWidget {
  const Launch2DeskTape({
    required this.items,
    required this.now,
    required this.onNavigate,
    super.key = const ValueKey<String>('launch2-tape'),
  });

  /// Newest first, as the server sends them.
  final List<Launch2Activity> items;
  final DateTime Function() now;
  final void Function(String location) onNavigate;

  /// How many trades the band and this list show.
  static const int expanded = 10;

  @override
  Widget build(BuildContext context) {
    final lines = items.take(expanded).toList(growable: false);
    final at = now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoopLabel(context.l10n.launch2_launch2LaunchpadLoopLabel),
        Container(
          key: const ValueKey<String>('launch2-tape-card'),
          margin: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          decoration: const BoxDecoration(
            color: LoopColors.card,
            borderRadius: LoopRadius.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final (index, item) in lines.indexed)
                _TapeLine(
                  key: ValueKey<String>('launch2-tape-line-$index'),
                  item: item,
                  now: at,
                  last: index == lines.length - 1,
                  onTap: () =>
                      onNavigate(Launch2Route.instance(item.instanceId)),
                  onOpenProfile: onNavigate,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens [Launch2DeskTape] in a sheet; a tap inside closes the sheet first.
Future<void> launch2ShowTradesSheet(
  BuildContext context, {
  required List<Launch2Activity> items,
  required DateTime Function() now,
  required void Function(String location) onNavigate,
}) => showLoopSheet<void>(
  context,
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.only(bottom: LoopSpacing.page),
    child: Launch2DeskTape(
      items: items,
      now: now,
      onNavigate: (location) {
        Navigator.of(sheetContext).pop();
        onNavigate(location);
      },
    ),
  ),
);

class _TapeLine extends StatelessWidget {
  const _TapeLine({
    required this.item,
    required this.now,
    required this.last,
    required this.onTap,
    required this.onOpenProfile,
    super.key,
  });

  final Launch2Activity item;
  final DateTime now;
  final bool last;
  final VoidCallback onTap;

  /// S239: the account's face opens its page; the rest of the line opens
  /// the project.
  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final time = launch2RelativeTime(item.at, now);
    final text = launch2ActivityText(item);
    final account = item.account;
    return Semantics(
      button: true,
      label: '$time $text',
      excludeSemantics: true,
      child: LoopPressable(
        onTap: onTap,
        scale: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
          // The face's 44 hit box sets the line's height on its own.
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: account == null ? 11 : 0,
          ),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: LoopColors.line)),
          ),
          child: Row(
            children: <Widget>[
              // docs/42 附C §4: the time is a quiet Text3 figure.
              Text(
                time,
                style: LoopType.figureXs.copyWith(color: LoopColors.text3),
              ),
              const SizedBox(width: 10),
              if (account != null)
                LoopProfileFaceLink(
                  key: const ValueKey<String>('launch2-tape-face'),
                  publicProfileId: account.publicProfileId,
                  name:
                      account.displayName ??
                      context.l10n.launch2_launch2LaunchpadLaunch2TapeFaceName,
                  onOpen: onOpenProfile,
                  child: LoopProfileAvatar(
                    avatarRef: account.avatarRef,
                    alias: account.displayName,
                    size: 22,
                  ),
                ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: launch2TapeSpans(item)),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tape line as spans (docs/42 附C §4 实时成交行): the address in Text2,
/// 「买入」 in rise and 「卖出」 in fall, the ticker in Chalk and the amount in
/// Chalk 600. Every other kind reads as one Text2 sentence with its amount in
/// Chalk 600.
List<InlineSpan> launch2TapeSpans(Launch2Activity item) {
  final amount = item.amountUsd1;
  final figure = amount == null ? null : launch2Usd1Label(amount);
  final figureStyle = LoopTypography.withWeight(
    LoopType.figureSm,
    FontWeight.w600,
  ).copyWith(color: LoopColors.chalk);
  const tickerStyle = TextStyle(color: LoopColors.chalk);
  final verb = switch (item.kind) {
    Launch2ActivityKind.curveBuy => (
      LoopL10n.current.common_buy,
      LoopColors.rise,
    ),
    Launch2ActivityKind.curveSell => (
      LoopL10n.current.common_sell,
      LoopColors.fall,
    ),
    _ => null,
  };
  if (verb != null) {
    final who = launch2ActivityWho(item);
    return <InlineSpan>[
      TextSpan(text: who),
      TextSpan(
        text: verb.$1,
        style: LoopTypography.withWeight(
          LoopType.caption,
          FontWeight.w600,
        ).copyWith(color: verb.$2),
      ),
      TextSpan(text: ' ${item.ticker}', style: tickerStyle),
      if (figure != null) TextSpan(text: ' $figure', style: figureStyle),
    ];
  }
  final text = launch2ActivityText(item);
  final split = figure != null && text.endsWith(' $figure');
  return <InlineSpan>[
    TextSpan(
      text: split ? text.substring(0, text.length - figure.length) : text,
    ),
    if (split) TextSpan(text: figure, style: figureStyle),
  ];
}
