import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/member_buy/member_buy_event.dart';
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

/// The buyer from the profile route, cached for the session.
///
/// A failure is the answer `null` — the card falls back to 「群友」 — and is
/// cached too, so a list of fifty cards for one unreadable account asks once.
/// Nothing is thrown, so Riverpod's automatic retry never re-asks in a loop.
final memberBuyBuyerProvider =
    FutureProvider.family<LoopMemberBuyBuyer?, String>((
      ref,
      publicProfileId,
    ) async {
      // A different account may get a different answer (a block reads as a
      // 404), so the cache is per account.
      ref.watch(loopAccountScopeProvider);
      try {
        final record = await ref
            .read(publicProfileGatewayProvider)
            .load(PublicProfileById(publicProfileId));
        return LoopMemberBuyBuyer(
          name: record.displayName,
          avatarRef: record.avatarRef,
        );
      } catch (_) {
        return null;
      }
    });

/// The buyer as the loaded Stream state already knows them, or `null`.
///
/// Since S107 every activated account is a Stream user carrying its real
/// name, image and `publicProfileId` (decision 0112). The channel's own
/// members are read first, then every user the client has seen; a match costs
/// no request.
@visibleForTesting
LoopMemberBuyBuyer? loopMemberBuyBuyerFromStream(
  Channel? channel,
  String publicProfileId,
) {
  if (channel == null) return null;
  LoopMemberBuyBuyer? from(User? user) {
    final identity = loopStreamRealIdentityOf(user);
    if (identity == null || identity.publicProfileId != publicProfileId) {
      return null;
    }
    return LoopMemberBuyBuyer(name: identity.name, imageUrl: identity.imageUrl);
  }

  for (final member in channel.state?.members ?? const <Member>[]) {
    final found = from(member.user);
    if (found != null) return found;
  }
  for (final user in channel.client.state.users.values) {
    final found = from(user);
    if (found != null) return found;
  }
  return null;
}

/// 「群友买入」: one member of this community bought its bound token.
///
/// The message is the backend feed bot's, not a member's, so it is not a
/// bubble: it is a full-width ledger row naming the buyer, what they bought,
/// what they paid and the transaction. Every figure is an on-chain fact the
/// payload carries; the name and the picture are read live from the buyer's
/// own account. A payload LOOP cannot fully read is 「动态数据不完整」 — never a
/// zero and never the fallback text pretending to be a message.
class LoopMemberBuyCard extends ConsumerWidget {
  const LoopMemberBuyCard({required this.message, super.key});

  final Message message;

  static const Key cardKey = ValueKey<String>('loop-member-buy-card');
  static const Key incompleteKey = ValueKey<String>(
    'loop-member-buy-card-incomplete',
  );
  static const Key avatarKey = ValueKey<String>('loop-member-buy-avatar');
  static const Key txKey = ValueKey<String>('loop-member-buy-tx');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = LoopMemberBuyEvent.tryParse(message);
    if (event == null) return const _IncompleteCard();
    final channel = StreamChannel.maybeOf(context)?.channel;
    final fromStream = loopMemberBuyBuyerFromStream(
      channel,
      event.publicProfileId,
    );
    final buyer =
        fromStream ??
        ref
            .watch(memberBuyBuyerProvider(event.publicProfileId))
            .maybeWhen(data: (value) => value, orElse: () => null);
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
