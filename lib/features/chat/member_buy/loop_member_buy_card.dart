import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/member_buy/member_buy_event.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_display_identity.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Who bought, as far as LOOP could tell.
///
/// [name] is `null` when neither Stream nor the profile route named them; the
/// card then reads 「群友」. [imageUrl] is an absolute address Stream carried;
/// [avatarRef] is the profile's own media reference, resolved at draw time.
@immutable
final class LoopMemberBuyBuyer {
  const LoopMemberBuyBuyer({this.name, this.imageUrl, this.avatarRef});

  final String? name;
  final String? imageUrl;
  final String? avatarRef;
}

/// What the profile route said about one buyer.
sealed class LoopMemberBuyProfileAnswer {
  const LoopMemberBuyProfileAnswer();
}

/// The profile exists and this reader may see it.
final class LoopMemberBuyProfileFound extends LoopMemberBuyProfileAnswer {
  const LoopMemberBuyProfileFound(this.buyer);

  final LoopMemberBuyBuyer buyer;
}

/// `404 PROFILE_NOT_FOUND`: no such account, or one that blocked the reader —
/// deliberately indistinguishable. The card reads 「群友」 whatever Stream
/// knows about the account.
final class LoopMemberBuyProfileHidden extends LoopMemberBuyProfileAnswer {
  const LoopMemberBuyProfileHidden();
}

/// The route did not answer (offline, `503`, an unreadable body). Nothing
/// was learned; the next card that mounts asks again.
final class LoopMemberBuyProfileUnknown extends LoopMemberBuyProfileAnswer {
  const LoopMemberBuyProfileUnknown();
}

/// Profile answers for member-buy cards, per account.
///
/// Only an answer the server actually gave is kept for the session — the
/// profile, or its `404` — because those are facts about this reader and that
/// account (a block reads as a `404` to one reader and not to another, hence
/// one cache per account). A transport failure, a `503` or an unreadable body
/// is handed to the card that asked and forgotten, so the next card asks
/// again. Concurrent cards for one buyer share one request.
final class LoopMemberBuyProfileCache {
  LoopMemberBuyProfileCache(this._gateway);

  final PublicProfileGateway _gateway;
  final Map<String, LoopMemberBuyProfileAnswer> _settled =
      <String, LoopMemberBuyProfileAnswer>{};
  final Map<String, Future<LoopMemberBuyProfileAnswer>> _inFlight =
      <String, Future<LoopMemberBuyProfileAnswer>>{};

  /// The kept answer for [publicProfileId], or `null`.
  LoopMemberBuyProfileAnswer? settled(String publicProfileId) =>
      _settled[publicProfileId];

  Future<LoopMemberBuyProfileAnswer> load(String publicProfileId) {
    final kept = _settled[publicProfileId];
    if (kept != null) return Future<LoopMemberBuyProfileAnswer>.value(kept);
    return _inFlight[publicProfileId] ??= _fetch(publicProfileId)
        .whenComplete(() {
          // A block body: the removed value is this very future, and
          // returning it would make the future wait on itself.
          _inFlight.remove(publicProfileId);
        });
  }

  Future<LoopMemberBuyProfileAnswer> _fetch(String publicProfileId) async {
    try {
      final record = await _gateway.load(PublicProfileById(publicProfileId));
      return _settled[publicProfileId] = LoopMemberBuyProfileFound(
        LoopMemberBuyBuyer(
          name: record.displayName,
          avatarRef: record.avatarRef,
        ),
      );
    } on CommunityGatewayException catch (error) {
      if (error.kind == CommunityFailureKind.notFound) {
        return _settled[publicProfileId] = const LoopMemberBuyProfileHidden();
      }
      return const LoopMemberBuyProfileUnknown();
    } catch (_) {
      return const LoopMemberBuyProfileUnknown();
    }
  }
}

/// The session's [LoopMemberBuyProfileCache]; a different account gets a new
/// one.
final memberBuyProfileCacheProvider = Provider<LoopMemberBuyProfileCache>((
  ref,
) {
  ref.watch(loopAccountScopeProvider);
  return LoopMemberBuyProfileCache(ref.watch(publicProfileGatewayProvider));
});

/// Which Stream user carries which `publicProfileId`, per client.
final Expando<_StreamBuyerIndex> _streamBuyerIndexes =
    Expando<_StreamBuyerIndex>('loop-member-buy-stream-index');

final class _StreamBuyerIndex {
  /// `publicProfileId` → Stream user id, for every id already found.
  final Map<String, String> hits = <String, String>{};

  /// `publicProfileId` → how many users the client knew when a scan found
  /// nothing. A scan is repeated only once the client has met more users.
  final Map<String, int> misses = <String, int>{};
}

/// The buyer as the loaded Stream state already knows them, or `null`.
///
/// Since S107 every activated account is a Stream user carrying its real
/// name, image and `publicProfileId` (decision 0112). The channel's own
/// members are read first, then every user the client has seen. The answer is
/// remembered per client by id, so fifty cards for one buyer scan once. It
/// supplies a name and a picture only: whether the reader may see the buyer
/// at all is the profile route's answer.
@visibleForTesting
LoopMemberBuyBuyer? loopMemberBuyBuyerFromStream(
  Channel? channel,
  String publicProfileId,
) {
  if (channel == null) return null;
  final client = channel.client;
  final index = _streamBuyerIndexes[client] ??= _StreamBuyerIndex();
  final members = channel.state?.members ?? const <Member>[];

  LoopMemberBuyBuyer? from(User? user) {
    final identity = loopStreamRealIdentityOf(user);
    if (identity == null || identity.publicProfileId != publicProfileId) {
      return null;
    }
    return LoopMemberBuyBuyer(name: identity.name, imageUrl: identity.imageUrl);
  }

  User? byId(String userId) {
    for (final member in members) {
      if (member.user?.id == userId) return member.user;
    }
    return client.state.users[userId];
  }

  final known = index.hits[publicProfileId];
  if (known != null) {
    final found = from(byId(known));
    if (found != null) return found;
    index.hits.remove(publicProfileId);
  }
  final population = client.state.users.length + members.length;
  if (index.misses[publicProfileId] == population) return null;
  for (final user in <User?>[
    for (final member in members) member.user,
    ...client.state.users.values,
  ]) {
    final found = from(user);
    if (found != null) {
      index.hits[publicProfileId] = user!.id;
      index.misses.remove(publicProfileId);
      return found;
    }
  }
  index.misses[publicProfileId] = population;
  return null;
}

/// The buyer a card draws: Stream's name and picture when it has them, the
/// profile's otherwise, and nobody once the profile route answered `404`.
@visibleForTesting
LoopMemberBuyBuyer? loopMemberBuyResolveBuyer({
  required LoopMemberBuyBuyer? fromStream,
  required LoopMemberBuyProfileAnswer? profile,
}) => switch (profile) {
  LoopMemberBuyProfileHidden() => null,
  LoopMemberBuyProfileFound(:final buyer) => LoopMemberBuyBuyer(
    name: fromStream?.name ?? buyer.name,
    imageUrl: fromStream?.imageUrl,
    avatarRef: buyer.avatarRef,
  ),
  LoopMemberBuyProfileUnknown() || null => fromStream,
};

/// 「群友买入」: one member of this community bought its bound token.
///
/// The message is the backend feed bot's, not a member's, so it is not a
/// bubble: it is a full-width ledger row naming the buyer, what they bought,
/// what they paid and the transaction. Every figure is an on-chain fact the
/// payload carries; the name and the picture are read live from the buyer's
/// own account. A payload LOOP cannot fully read is 「动态数据不完整」 — never a
/// zero and never the fallback text pretending to be a message.
class LoopMemberBuyCard extends ConsumerStatefulWidget {
  const LoopMemberBuyCard({required this.message, super.key});

  final Message message;

  static const Key cardKey = ValueKey<String>('loop-member-buy-card');
  static const Key incompleteKey = ValueKey<String>(
    'loop-member-buy-card-incomplete',
  );
  static const Key avatarKey = ValueKey<String>('loop-member-buy-avatar');
  static const Key txKey = ValueKey<String>('loop-member-buy-tx');

  @override
  ConsumerState<LoopMemberBuyCard> createState() => _LoopMemberBuyCardState();
}

class _LoopMemberBuyCardState extends ConsumerState<LoopMemberBuyCard> {
  /// What this card asked, so one card asks once per buyer and cache.
  (LoopMemberBuyProfileCache, String)? _asked;
  LoopMemberBuyProfileAnswer? _answer;

  LoopMemberBuyProfileAnswer? _profileFor(
    LoopMemberBuyProfileCache cache,
    String publicProfileId,
  ) {
    final kept = cache.settled(publicProfileId);
    if (kept != null) return kept;
    final key = (cache, publicProfileId);
    if (_asked != key) {
      _asked = key;
      _answer = null;
      unawaited(
        cache.load(publicProfileId).then((answer) {
          if (mounted && _asked == key) setState(() => _answer = answer);
        }),
      );
    }
    return _answer;
  }

  @override
  Widget build(BuildContext context) {
    final event = LoopMemberBuyEvent.tryParse(widget.message);
    if (event == null) return const _IncompleteCard();
    final channel = StreamChannel.maybeOf(context)?.channel;
    final buyer = loopMemberBuyResolveBuyer(
      fromStream: loopMemberBuyBuyerFromStream(channel, event.publicProfileId),
      profile: _profileFor(
        ref.watch(memberBuyProfileCacheProvider),
        event.publicProfileId,
      ),
    );
    return _Card(event: event, buyer: buyer);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.event, required this.buyer});

  final LoopMemberBuyEvent event;
  final LoopMemberBuyBuyer? buyer;

  @override
  Widget build(BuildContext context) {
    final name = buyer?.name ?? loopMemberBuyNeutralBuyer;
    final open = LoopChatAvatarTapScope.maybeOf(context);
    final showQuote = event.quoteAmount > Decimal.zero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        key: LoopMemberBuyCard.cardKey,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: LoopColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LoopColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              button: open != null,
              label: '查看 $name 的资料',
              child: GestureDetector(
                key: LoopMemberBuyCard.avatarKey,
                behavior: HitTestBehavior.opaque,
                onTap: open == null ? null : () => open(event.publicProfileId),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: _avatar(context, name)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopTypography.label(
                            13,
                            color: LoopColors.text2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loopStreamClockLabel(event.occurredAt),
                        style: LoopTypography.figure(
                          11,
                          weight: FontWeight.w400,
                          color: LoopColors.text3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: '买入 ', style: LoopTypography.title(15)),
                        TextSpan(
                          text: loopFormatMemberBuyAmount(event.amount),
                          style: LoopTypography.figure(
                            15,
                            color: LoopColors.lime,
                          ),
                        ),
                        TextSpan(
                          text: ' ${event.symbol}',
                          style: LoopTypography.title(15),
                        ),
                      ],
                    ),
                    key: const ValueKey<String>('loop-member-buy-amount'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      if (showQuote) ...<Widget>[
                        Flexible(
                          child: Text(
                            loopFormatMemberBuyQuote(event),
                            key: const ValueKey<String>(
                              'loop-member-buy-quote',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LoopTypography.figure(
                              12,
                              weight: FontWeight.w500,
                              color: LoopColors.text2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _TxHash(event: event),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context, String name) {
    final initials = LoopInitialsAvatar(
      key: const ValueKey<String>('loop-member-buy-avatar-initials'),
      label: buyer?.name == null ? loopMemberBuyNeutralInitial : name,
      size: 36,
    );
    final url = buyer?.imageUrl ?? loopMediaUrlFor(context, buyer?.avatarRef);
    if (url == null) return initials;
    return LoopRemoteAvatar(url: url, size: 36, fallback: initials);
  }
}

/// The transaction, shortened, and a tap that copies all of it.
class _TxHash extends StatelessWidget {
  const _TxHash({required this.event});

  final LoopMemberBuyEvent event;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '复制交易哈希',
    child: InkWell(
      key: LoopMemberBuyCard.txKey,
      borderRadius: BorderRadius.circular(8),
      onTap: () => unawaited(_copy(context)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              event.shortTxHash,
              style: LoopTypography.code(11, color: LoopColors.text3),
            ),
            const SizedBox(width: 4),
            const LoopIcon('copy', size: 13, color: LoopColors.text3),
          ],
        ),
      ),
    ),
  );

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: event.txHash));
    if (!context.mounted) return;
    LoopToast.show(context, message: '已复制交易哈希');
  }
}

/// A member-buy message LOOP could not read in full.
class _IncompleteCard extends StatelessWidget {
  const _IncompleteCard();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    child: Container(
      key: LoopMemberBuyCard.incompleteKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LoopColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LoopColors.line),
      ),
      child: Row(
        children: <Widget>[
          const LoopIcon('info', size: 15, color: LoopColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$loopMemberBuyPreviewLabel · 动态数据不完整',
              style: LoopTypography.caption(12),
            ),
          ),
        ],
      ),
    ),
  );
}
