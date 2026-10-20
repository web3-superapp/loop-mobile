import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

// ---------------------------------------------------------------------------
// 发射台 · the prototype's Launch Desk (decision 0164; data since 0163,
// docs/32 §7)
// ---------------------------------------------------------------------------
//
// The frozen prototype's Launch page, part for part: one full-Lime ledger
// card for the main event, the segment counts, a record card for its
// progress, then `.label` groups of rows, the 战绩 stat grid and the curation
// notice. Lime is the ledger card and the progress; nothing on this page is
// Brass (the medal keeps it on its own page).

// ---- the live tape's words ---------------------------------------------

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

// ---- the stage groups ------------------------------------------------------

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

// ---- the desk's segment counts ---------------------------------------------

/// The four counts under the ledger card, each the groups it stands for.
enum Launch2DeskSegment {
  minting('铸造中', <Launch2StageGroup>[Launch2StageGroup.minting]),
  curve('内盘', <Launch2StageGroup>[
    Launch2StageGroup.priority,
    Launch2StageGroup.curve,
  ]),
  upcoming('预告', <Launch2StageGroup>[Launch2StageGroup.upcoming]),
  graduated('已毕业', <Launch2StageGroup>[Launch2StageGroup.graduated]);

  const Launch2DeskSegment(this.title, this.groups);

  final String title;
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
  if (chainId == null) return 'LAUNCH DESK';
  return loopTestnetBadgeFor(chainId) != null
      ? 'LAUNCH DESK · $loopTestnetStampText'
      : 'LAUNCH DESK · BSC';
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

/// The pager's fixed height at text scale 1: two heading lines and a
/// four-line caption at 360 dp. 256 since decision 0210 (Anton heading,
/// 20 card padding, 1.6 caption leading).
const double launch2DeskHeight = 256;

/// `.ledger-card.folio-primary` as a sideways pager: one full-Lime card per
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

  Widget _card(Launch2DeskPage? page, int index) {
    final count = widget.pages.length;
    // The dots ride the kicker line of each card, from two pages on: ink on
    // the full-Lime event card, Lime on the quiet campaign card.
    Widget? dots({required bool quiet}) => count >= 2
        ? _DeskDots(count: count, current: index, quiet: quiet)
        : null;
    return switch (page) {
      null => Launch2DeskFolio(row: null, chainId: widget.chainId),
      Launch2DeskEventPage(:final row) => Launch2DeskFolio(
        key: ValueKey<String>('launch2-desk-page-${row.instanceId}'),
        row: row,
        chainId: widget.chainId,
        dots: dots(quiet: false),
        onTap: () => widget.onNavigate(launch2HeroLocation(row)),
        onElapsed: widget.onElapsed,
      ),
      Launch2DeskCampaignPage(:final campaign) => Launch2DeskCampaignCard(
        key: ValueKey<String>('launch2-desk-page-${page.id}'),
        campaign: campaign,
        dots: dots(quiet: true),
        onNavigate: widget.onNavigate,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    final height = MediaQuery.textScalerOf(context).scale(launch2DeskHeight);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: LoopSpacing.group),
      child: SizedBox(
        height: height,
        child: PageView.builder(
          key: const ValueKey<String>('launch2-desk-pages'),
          controller: _controller,
          itemCount: pages.isEmpty ? 1 : pages.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: _card(pages.isEmpty ? null : pages[index], index),
          ),
        ),
      ),
    );
  }
}

class _DeskDots extends StatelessWidget {
  const _DeskDots({
    required this.count,
    required this.current,
    this.quiet = false,
  });

  final int count;
  final int current;

  /// On the quiet (dark) ledger: Lime dots instead of ink.
  final bool quiet;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      key: const ValueKey<String>('launch2-desk-dots'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Container(
            key: ValueKey<String>('launch2-desk-dot-$i'),
            width: 6,
            height: 6,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (quiet ? LoopColors.lime : LoopColors.ink).withValues(
                alpha: i == current ? 1 : 0.3,
              ),
            ),
          ),
      ],
    ),
  );
}

/// One ledger card of the pager: the event's ticker over its stage
/// sentence, one caption of figures and the countdown in the stamp; with no
/// event, the empty desk in the same card.
class Launch2DeskFolio extends ConsumerWidget {
  const Launch2DeskFolio({
    required this.row,
    required this.chainId,
    super.key,
    this.onTap,
    this.onElapsed,
    this.dots,
  });

  /// The pager's dots at the end of the kicker line.
  final Widget? dots;

  /// The event; `null` draws the empty desk.
  final Launch2InstanceRow? row;
  final String? chainId;
  final VoidCallback? onTap;

  /// The stamp's countdown reached zero: the list re-reads the server.
  final VoidCallback? onElapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kicker = launch2DeskKicker(chainId);
    final event = row;
    if (event == null) {
      return LoopFolioPrimary(
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.listing,
        ring: false,
        margin: EdgeInsets.zero,
        kicker: kicker,
        heading: '暂无进行中的发射',
        caption: 'NFT 预售开始后会出现在这里',
      );
    }
    Widget folio(String? stamp) => LoopFolioPrimary(
      variant: LoopFolioVariant.lime,
      archetype: LoopFolioArchetype.listing,
      ring: false,
      margin: EdgeInsets.zero,
      kicker: kicker,
      kickerTrailing: dots,
      heading:
          '${launch2HeroTicker(event.ticker)}\n${launch2DeskStatus(event)}',
      caption: launch2DeskCaption(event),
      stamp: stamp,
    );
    final next = event.nextChangeAt;
    final card = next == null || !launch2RecordCountsDown(event.stage)
        ? folio(null)
        : Launch2CountdownBuilder(
            target: next,
            onElapsed: onElapsed,
            builder: (context, text) =>
                folio('${launch2DeskStampPrefix(event.stage)}$text'),
          );
    return Semantics(
      button: true,
      label: launch2HeroSpokenLabel(event, ref.read(launch2ClockProvider)()),
      excludeSemantics: true,
      child: LoopPressable(onTap: onTap, scale: false, child: card),
    );
  }
}

/// The campaign page (decision 0165): the quiet ledger (`.ledger-quiet`,
/// the same card as the top of the NFT page) with the cover on its right
/// edge — kicker 「活动 · MM-dd → MM-dd」, the title in at most two lines, the
/// subtitle when there is one, the button words under it and the stamp
/// 「剩 N 天」 / 「今天结束」 / 「MM-dd 开始」. A cover that does not load is no
/// cover: the text takes the whole card. The whole card is one tap.
class Launch2DeskCampaignCard extends ConsumerStatefulWidget {
  const Launch2DeskCampaignCard({
    required this.campaign,
    required this.onNavigate,
    super.key,
    this.dots,
  });

  final Launch2DeskCampaign campaign;

  /// Pushes an in-app route.
  final void Function(String location) onNavigate;
  final Widget? dots;

  @override
  ConsumerState<Launch2DeskCampaignCard> createState() =>
      _Launch2DeskCampaignCardState();
}

class _Launch2DeskCampaignCardState
    extends ConsumerState<Launch2DeskCampaignCard> {
  /// The cover address that failed to load; it is not tried again.
  String? _failedCover;

  void _open() {
    final opener = ref.read(launch2ExternalLinkOpenerProvider);
    launch2OpenCampaign(
      widget.campaign,
      push: widget.onNavigate,
      openExternal: (uri) => unawaited(opener(context, uri)),
    );
  }

  void _coverFailed(String url) {
    if (_failedCover == url) return;
    // The error arrives during a build of the image; the card redraws
    // without it on the next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failedCover = url);
    });
  }

  Widget _cover(String url) {
    final source = loopRemoteImageSource(url);
    const ground = ColoredBox(color: LoopColors.card2);
    return SizedBox.expand(
      child: Image(
        key: ValueKey<String>(
          'launch2-campaign-cover-${widget.campaign.campaignId}',
        ),
        image: source,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, synchronous) =>
            synchronous || frame != null ? child : ground,
        errorBuilder: (context, error, stackTrace) {
          _coverFailed(url);
          return ground;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final now = ref.read(launch2ClockProvider)();
    final stamp = launch2CampaignStamp(campaign, now);
    final cover = campaign.coverUrl;
    final id = campaign.campaignId;
    return Semantics(
      button: true,
      label: <String>[
        '活动',
        campaign.title,
        ?campaign.subtitle,
        stamp,
        campaign.ctaLabel,
      ].join('，'),
      excludeSemantics: true,
      child: LoopPressable(
        onTap: _open,
        scale: false,
        child: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.listing,
          ring: false,
          margin: EdgeInsets.zero,
          kicker: launch2CampaignKicker(campaign),
          kickerTrailing: widget.dots,
          heading: campaign.title,
          headingMaxLines: 2,
          caption: campaign.subtitle,
          captionMaxLines: 2,
          stamp: stamp,
          aside: cover == null || cover == _failedCover ? null : _cover(cover),
          footer: Row(
            key: ValueKey<String>('launch2-campaign-cta-$id'),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  campaign.ctaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // R17 the folio's text action.
                  style: LoopTypography.withWeight(
                    LoopType.label,
                    FontWeight.w600,
                  ).copyWith(color: LoopColors.lime),
                ),
              ),
              const SizedBox(width: 2),
              const LoopIcon('chevron', size: 12, color: LoopColors.lime),
            ],
          ),
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
    final figureStyle = LoopType.figure.copyWith(color: LoopColors.lime);
    final figure = !launch2RecordCountsDown(row.stage)
        ? Text(
            launch2BpsLabel(row.curve.soldBps),
            maxLines: 1,
            style: figureStyle,
          )
        : next == null
        ? Text('待定', maxLines: 1, style: figureStyle)
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
                Column(
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
                      style: LoopType.captionSm.copyWith(
                        color: LoopColors.text3,
                      ),
                    ),
                  ],
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

/// `.tape`: the newest [shown] items as still lines on the card ground, the
/// time in Lime; 「全部」 opens it to [expanded]. Empty: nothing is drawn (the
/// caller checks).
class Launch2DeskTape extends StatefulWidget {
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

  static const int shown = 3;
  static const int expanded = 10;

  @override
  State<Launch2DeskTape> createState() => _Launch2DeskTapeState();
}

class _Launch2DeskTapeState extends State<Launch2DeskTape> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final more = items.length > Launch2DeskTape.shown;
    final lines = items
        .take(_open ? Launch2DeskTape.expanded : Launch2DeskTape.shown)
        .toList(growable: false);
    final now = widget.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            const Expanded(child: LoopLabel('实时')),
            if (more)
              Semantics(
                button: true,
                label: _open ? '收起实时动态' : '展开全部实时动态',
                excludeSemantics: true,
                child: LoopPressable(
                  key: const ValueKey<String>('launch2-tape-more'),
                  onTap: () => setState(() => _open = !_open),
                  scale: false,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: LoopTouch.minimum,
                      minHeight: LoopTouch.minimum,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        8,
                        0,
                        LoopSpacing.page,
                        LoopSpacing.tight,
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          _open ? '收起' : '全部',
                          // R17 inline text action (decision 0190 L22).
                          style: LoopTypography.withWeight(
                            LoopType.label,
                            FontWeight.w600,
                          ).copyWith(color: LoopColors.text2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Container(
          key: const ValueKey<String>('launch2-tape-card'),
          margin: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          decoration: BoxDecoration(
            color: LoopColors.card,
            borderRadius: LoopRadius.control,
            border: Border.all(color: LoopColors.line),
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
                  now: now,
                  last: index == lines.length - 1,
                  onTap: () =>
                      widget.onNavigate(Launch2Route.instance(item.instanceId)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TapeLine extends StatelessWidget {
  const _TapeLine({
    required this.item,
    required this.now,
    required this.last,
    required this.onTap,
    super.key,
  });

  final Launch2Activity item;
  final DateTime now;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = launch2RelativeTime(item.at, now);
    final text = launch2ActivityText(item);
    final amount = item.amountUsd1;
    final figure = amount == null ? null : launch2Usd1Label(amount);
    // `.tape-line b`: the amount, when the sentence ends on one, in Chalk.
    final split = figure != null && text.endsWith(' $figure');
    final mono = LoopType.figureXs;
    return Semantics(
      button: true,
      label: '$time $text',
      excludeSemantics: true,
      child: LoopPressable(
        onTap: onTap,
        scale: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: LoopColors.line)),
          ),
          child: Row(
            children: <Widget>[
              Text(
                time,
                style: LoopTypography.withWeight(
                  LoopType.figureXs,
                  FontWeight.w600,
                ).copyWith(color: LoopColors.lime),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: split
                            ? text.substring(0, text.length - figure.length)
                            : text,
                      ),
                      if (split)
                        TextSpan(
                          text: figure,
                          style: LoopTypography.withWeight(
                            LoopType.figureXs,
                            FontWeight.w600,
                          ).copyWith(color: LoopColors.chalk),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: mono,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- 战绩 ---------------------------------------------------------------------

/// `.stat-grid.stat-grid-4`: 本周毕业 · 累计回购 · 勋章已铸 · 进行中.
List<LoopStat> launch2DeskStats(Launch2Stats stats) => <LoopStat>[
  LoopStat(
    statKey: const ValueKey<String>('launch2-stats-graduated'),
    value: '${stats.graduatedThisWeek}',
    label: '本周毕业 · 累计 ${stats.graduatedTotal}',
  ),
  LoopStat(
    statKey: const ValueKey<String>('launch2-stats-buyback'),
    value: launch2Usd1Label(stats.buybackUsd1Total),
    label: '累计回购',
  ),
  LoopStat(
    statKey: const ValueKey<String>('launch2-stats-minted'),
    value: '${stats.nftMintedTotal} 枚',
    label: '勋章已铸',
  ),
  LoopStat(
    statKey: const ValueKey<String>('launch2-stats-live'),
    value: '${stats.liveCount}',
    label: '进行中',
  ),
];

/// The curation notice the prototype's Launch page ends on.
const LoopNotice launch2CurationNotice = LoopNotice(
  key: ValueKey<String>('launch2-curation-notice'),
  icon: 'target',
  title: '精品发射，不是每天几万个',
  body:
      'LOOP 只联合交易所、KOL、社区与 IP 孵化有故事、有传播、有持续运营的 MEME。'
      '统一 10 亿总量，USD1 报价。',
  margin: EdgeInsets.fromLTRB(16, 22, 16, 0),
);
