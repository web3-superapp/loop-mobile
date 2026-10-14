import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';

// ---------------------------------------------------------------------------
// 发射台 · 运营活动卡 · `GET /v2/launch2/campaigns` (decision 0165, loop-api
// S183)
// ---------------------------------------------------------------------------
//
// The back office publishes campaign cards; the desk's pager shows them
// between its events. Like the overview the read is an extra: a 404, a 503
// or an unreadable body is 「没有活动」 and the rest of the page never
// notices.

/// The server's view of a campaign when it answered.
enum Launch2CampaignState {
  live('live'),
  upcoming('upcoming');

  const Launch2CampaignState(this.wireName);

  final String wireName;

  static Launch2CampaignState? tryParse(Object? value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

/// Where a campaign card leads.
enum Launch2CampaignLinkKind {
  /// An in-app location (`/launch2/nft?id=…`).
  route('route'),

  /// An `https` page outside the app.
  url('url');

  const Launch2CampaignLinkKind(this.wireName);

  final String wireName;

  static Launch2CampaignLinkKind? tryParse(Object? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

@immutable
final class Launch2CampaignLink {
  const Launch2CampaignLink({required this.kind, required this.value});

  const Launch2CampaignLink.route(this.value)
    : kind = Launch2CampaignLinkKind.route;

  const Launch2CampaignLink.url(this.value)
    : kind = Launch2CampaignLinkKind.url;

  final Launch2CampaignLinkKind kind;
  final String value;
}

/// The card's button words when the console left them out.
const String launch2CampaignDefaultCta = '查看';

/// An operations campaign the back office configures (decision 0165).
@immutable
final class Launch2DeskCampaign {
  const Launch2DeskCampaign({
    required this.campaignId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.link,
    this.subtitle,
    this.coverUrl,
    this.ctaLabel = launch2CampaignDefaultCta,
    this.pinned = false,
    this.sortOrder = 0,
    this.state = Launch2CampaignState.live,
  });

  final String campaignId;
  final String title;
  final String? subtitle;

  /// An address the codec already accepted; `null` draws no cover.
  final String? coverUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final String ctaLabel;
  final Launch2CampaignLink link;
  final bool pinned;
  final int sortOrder;
  final Launch2CampaignState state;

  /// Whether it runs at [now]: started and not yet over. The server's
  /// [state] is a reading at `observedAt`; the clock decides between reads.
  bool liveAt(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);
}

@immutable
final class Launch2Campaigns {
  const Launch2Campaigns({required this.items, this.observedAt});

  /// In the server's order: pinned, then `sortOrder`, then `startsAt`.
  final List<Launch2DeskCampaign> items;
  final DateTime? observedAt;
}

/// Feature-facing port for the campaign read. Every failure is a
/// [LoopChainException]; the desk then shows no campaign.
abstract interface class Launch2CampaignsGateway {
  LoopChainGatewayMode get mode;

  Future<Launch2Campaigns> loadCampaigns();
}

/// Production default until the composition root mounts the V2 adapter.
final class UnavailableLaunch2CampaignsGateway
    implements Launch2CampaignsGateway {
  const UnavailableLaunch2CampaignsGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<Launch2Campaigns> loadCampaigns() => Future<Launch2Campaigns>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launch2CampaignsGatewayProvider = Provider<Launch2CampaignsGateway>(
  (ref) => const UnavailableLaunch2CampaignsGateway(),
);

/// The campaign read. Like the overview it has no timer of its own: the v2
/// list loads it with the first page and refreshes it with every 60 s poll,
/// every return to the list and every pull.
final class Launch2CampaignsController
    extends LoopChainReadController<Launch2Campaigns> {
  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(launch2CampaignsGatewayProvider.select((g) => g.mode));

  @override
  Future<Launch2Campaigns> fetch() =>
      ref.read(launch2CampaignsGatewayProvider).loadCampaigns();
}

final launch2CampaignsControllerProvider =
    NotifierProvider.autoDispose<
      Launch2CampaignsController,
      LoopChainResourceState<Launch2Campaigns>
    >(Launch2CampaignsController.new);

// ---- the card's words ---------------------------------------------------------

String _monthDay(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)}';
}

/// 「活动 · 10-15 → 10-22」, on the reader's own calendar.
String launch2CampaignKicker(Launch2DeskCampaign campaign) =>
    '活动 · ${_monthDay(campaign.startsAt)} → ${_monthDay(campaign.endsAt)}';

/// The stamp: 「剩 N 天」 while it runs (「今天结束」 under a day),
/// 「MM-dd 开始」 before it starts.
String launch2CampaignStamp(Launch2DeskCampaign campaign, DateTime now) {
  if (now.isBefore(campaign.startsAt)) {
    return '${_monthDay(campaign.startsAt)} 开始';
  }
  final left = campaign.endsAt.difference(now);
  if (left < const Duration(days: 1)) return '今天结束';
  return '剩 ${left.inDays} 天';
}

// ---- where a card leads -------------------------------------------------------

/// Opens an `https` page outside the app. Decision 0165: LOOP has no
/// in-app browser and no launcher dependency; an outside page is handed
/// over the way every other outside address in the app is (the block
/// explorer rows): the link is copied and the toast says so.
typedef Launch2ExternalLinkOpener = Future<void> Function(
  BuildContext context,
  Uri uri,
);

Future<void> _copyExternalLink(BuildContext context, Uri uri) =>
    LoopCopy.text(context, uri.toString(), message: '链接已复制，可在浏览器打开');

final launch2ExternalLinkOpenerProvider = Provider<Launch2ExternalLinkOpener>(
  (ref) => _copyExternalLink,
);

/// An in-app location the card may open: one leading slash, never `//host`,
/// no scheme. Anything else is `null`.
String? launch2CampaignRoute(String value) {
  if (!value.startsWith('/') || value.startsWith('//')) return null;
  if (value.contains('\\') || value.contains(RegExp(r'\s'))) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return value;
}

/// An outside page the card may hand over: `https`, a host, no user info.
Uri? launch2CampaignUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

/// What a tap on [campaign] does: push its in-app route through [push], or
/// hand its page to [openExternal]. A link the client cannot follow is
/// ignored and logged; the card stays where it is.
void launch2OpenCampaign(
  Launch2DeskCampaign campaign, {
  required void Function(String location) push,
  required void Function(Uri uri) openExternal,
}) {
  final link = campaign.link;
  switch (link.kind) {
    case Launch2CampaignLinkKind.route:
      final route = launch2CampaignRoute(link.value);
      if (route == null) {
        debugPrint(
          'LOOP launch2 campaign ${campaign.campaignId}: '
          'route ignored (${link.value})',
        );
        return;
      }
      push(route);
    case Launch2CampaignLinkKind.url:
      final uri = launch2CampaignUrl(link.value);
      if (uri == null) {
        debugPrint(
          'LOOP launch2 campaign ${campaign.campaignId}: '
          'url ignored (${link.value})',
        );
        return;
      }
      openExternal(uri);
  }
}
