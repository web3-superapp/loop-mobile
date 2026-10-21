import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
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
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
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

/// Who did it, as the tape names them: the LOOP account's name when the
/// server attached one (loop-api decision 0162 §A, S239), else the short
/// address, else 「有人」.
String launch2ActivityWho(Launch2Activity item) {
  final name = item.account?.displayName;
  if (name != null && name.trim().isNotEmpty) return '$name ';
  // 「有人买入」 runs on; an address takes a space before the verb.
  return item.actor == null ? '有人' : '${launch2TapeActor(item.actor)} ';
}

/// One tape item's sentence, without its time.
String launch2ActivityText(Launch2Activity item) {
  final who = launch2ActivityWho(item);
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
  if (chainId == null) return '发射台';
  return loopTestnetBadgeFor(chainId) != null
      ? '发射台 · $loopTestnetStampText'
      : '发射台 · BSC';
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
/// four-line caption at 360 dp. 232 since decision 0211 (a bold sans
/// heading, a 1.5 caption leading).
const double launch2DeskHeight = 232;

/// The campaign banner's height at text scale 1 (S264, decision 0220: the
/// atmosphere banner; 200 before).
const double launch2DeskCampaignHeight = 220;

/// The height of the dot row under the pager (decision 0211).
const double launch2DeskDotsHeight = 18;

/// How far the banner's chrome hand may hang below its card (S264); the
/// pager keeps this much room under every page.
const double launch2DeskOverhang = 16;

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
    // docs/42 附C §5: a pager of campaign banners only is 200 high; one
    // that also carries an event folio keeps the folio's height.
    final allCampaigns =
        pages.isNotEmpty && pages.every((p) => p is Launch2DeskCampaignPage);
    final height = MediaQuery.textScalerOf(context).scale(
      allCampaigns
          ? launch2DeskCampaignHeight
          : math.max(launch2DeskHeight, launch2DeskCampaignHeight),
    );
    final count = pages.length;
    final current = _current.clamp(0, count == 0 ? 0 : count - 1);
    // S264: the pager is the card's height plus the hand's overhang; the
    // dots sit in that overhang, 12 under the card.
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SizedBox(
        height: height + launch2DeskOverhang + (count >= 2 ? 6 : 0),
        child: Stack(
          clipBehavior: Clip.none,
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
                    launch2DeskOverhang + (count >= 2 ? 6 : 0),
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
                top: height + 12,
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
              borderRadius: LoopRadius.pill,
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
  });

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
        archetype: LoopFolioArchetype.listing,
        ring: false,
        margin: EdgeInsets.zero,
        kicker: kicker,
        headingTone: LoopFolioHeadingTone.neutral,
        heading: '暂无进行中的发射',
        caption: 'NFT 预售开始后会出现在这里',
      );
    }
    final ticker = launch2HeroTicker(event.ticker);
    final status = launch2DeskStatus(event);
    Widget folio(String? stamp) => LoopFolioPrimary(
      archetype: LoopFolioArchetype.listing,
      ring: false,
      margin: EdgeInsets.zero,
      kicker: kicker,
      heading: '$ticker\n$status',
      // S241b: the ticker in Yellow, the stage line in Purple (the site's
      // two-colour heading), on the flat dark card.
      headingBuilder: (heading) =>
          memeTwoToneHeading(heading, first: ticker, second: status),
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

  /// The 「去参与」 button's height.
  static const double ctaHeight = 40;

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

  /// The default art (decision 0220 §4): the wall at 90 %, Purple and
  /// Yellow fog, the left-to-right Ink wash, the chrome hand hanging past
  /// the card's right and bottom edges, its Yellow crown and the tilted
  /// 「IN THE LOOP」 tag.
  Widget _defaultArt(Widget Function(String path, {double? width}) art) =>
      Stack(
        key: const ValueKey<String>('launch2-campaign-default-art'),
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: LoopRadius.card,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const ColoredBox(color: Color(0xFF0E0D12)),
                const _CampaignGround(),
                Positioned(
                  left: -60,
                  top: -110,
                  width: 420,
                  height: 420,
                  child: Opacity(
                    opacity: 0.55,
                    child: art(LoopAtmoAssets.sprayPurple),
                  ),
                ),
                Positioned(
                  right: -140,
                  bottom: -200,
                  width: 360,
                  height: 360,
                  child: Opacity(
                    opacity: 0.12,
                    child: art(LoopAtmoAssets.sprayYellow),
                  ),
                ),
                const DecoratedBox(
                  key: ValueKey<String>('launch2-campaign-scrim'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Color(0xD109090B),
                        Color(0x8C09090B),
                        Color(0x0009090B),
                      ],
                      stops: <double>[0, 0.52, 0.75],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: LoopRadius.card,
                    border: Border(top: BorderSide(color: Color(0x24F0F0F3))),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: -14,
            bottom: -16,
            width: 171,
            height: 170,
            child: Launch2ChromeHand(),
          ),
          Positioned(
            right: 118,
            top: 28,
            width: 62,
            child: Transform.rotate(
              angle: -14 * math.pi / 180,
              child: art(LoopAtmoAssets.crownYellow, width: 62),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            width: 42,
            child: Transform.rotate(
              angle: -5 * math.pi / 180,
              child: Opacity(
                opacity: 0.95,
                child: art(LoopAtmoAssets.tagInLoop, width: 42),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final now = ref.read(launch2ClockProvider)();
    final stamp = launch2CampaignStamp(campaign, now);
    final id = campaign.campaignId;
    final subtitle = campaign.subtitle;
    Widget art(String path, {double? width}) => Image.asset(
      path,
      width: width,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => SizedBox(width: width),
    );
    // Decision 0222: every campaign stands on the default art; only the
    // words change. A cover the admin set is neither requested nor drawn.
    final ground = _defaultArt(art);
    return Semantics(
      button: true,
      label: <String>[
        '活动',
        campaign.title,
        ?subtitle,
        launch2CampaignKicker(campaign),
        stamp,
        campaign.ctaLabel,
      ].join('，'),
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
              left: 20,
              top: 24,
              width: 186,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        left: -6,
                        top: 25,
                        width: 150,
                        child: art(LoopAtmoAssets.brushPurple, width: 150),
                      ),
                      Text(
                        campaign.title,
                        key: ValueKey<String>('launch2-campaign-title-$id'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.display.copyWith(height: 1.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 35),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      key: ValueKey<String>('launch2-campaign-subtitle-$id'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.bodySm.copyWith(color: LoopColors.chalk),
                    ),
                  const SizedBox(height: 6),
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
            Positioned(
              left: 20,
              bottom: 20,
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

/// The campaign card's ground: the wall texture at 90 % (S264).
class _CampaignGround extends StatelessWidget {
  const _CampaignGround();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    key: ValueKey<String>('launch2-campaign-ground'),
    decoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage(LoopAtmoAssets.wall),
        fit: BoxFit.cover,
        alignment: Alignment(-0.4, -0.2),
        opacity: 0.9,
      ),
    ),
    child: SizedBox.expand(),
  );
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
        const LoopLabel('实时成交'),
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
                  name: account.displayName ?? '这位用户',
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
    Launch2ActivityKind.curveBuy => ('买入', LoopColors.rise),
    Launch2ActivityKind.curveSell => ('卖出', LoopColors.fall),
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
