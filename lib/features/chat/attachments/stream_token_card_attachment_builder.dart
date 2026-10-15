import 'package:flutter/widgets.dart'
    show BuildContext, EdgeInsets, StatelessWidget, ValueKey, Widget;
import 'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_policy.dart';
import 'package:loop_mobile/features/chat/attachments/token_card_attachment.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart'
    show LoopTokenCard, LoopTokenCardModel, LoopTokenCardState;
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show Attachment, Message, StreamAttachmentWidgetBuilder;

/// Renders LOOP's identifier-only token reference inside official Stream UI.
///
/// This builder performs no network request and never mirrors Stream message
/// history. A separately designed bounded facts projection may enrich visible
/// cards later; until then valid references remain explicitly unavailable.
///
/// Both states are the prototype's `.tcard` in its 数据缺失 shape (decision
/// 0168): the card names what the message carries and why nothing else is
/// shown, and it offers no action — the message stores identifiers only, so
/// there is no price, risk claim, 买入 or 自选 to put behind one.
final class LoopStreamTokenCardAttachmentBuilder
    extends StreamAttachmentWidgetBuilder {
  const LoopStreamTokenCardAttachmentBuilder();

  @override
  bool canHandle(Message message, Map<String, List<Attachment>> attachments) {
    return LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard(
      message.attachments,
    );
  }

  @override
  Widget build(
    BuildContext context,
    Message message,
    Map<String, List<Attachment>> attachments,
  ) {
    final reference = LoopStreamTokenCardAttachmentPolicy.tryParse(
      message.attachments,
    );
    if (reference == null) return const LoopMalformedTokenCard();
    return LoopUnavailableTokenCard(reference: reference);
  }
}

/// A `token_card.v1` reference whose current facts LOOP has not received.
class LoopUnavailableTokenCard extends StatelessWidget {
  const LoopUnavailableTokenCard({required this.reference, super.key});

  final LoopTokenCardAttachment reference;

  /// The snapshot instant the message carries, in UTC.
  static String snapshotLabel(DateTime value) {
    final utc = value.toUtc();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)} UTC';
  }

  @override
  Widget build(BuildContext context) => LoopTokenCard(
    key: const ValueKey<String>('token-card-unavailable'),
    state: LoopTokenCardState.partial,
    margin: EdgeInsets.zero,
    model: LoopTokenCardModel(
      symbol: reference.assetId,
      identifier: '${reference.chainId} · ${reference.compactContract}',
      priceReason: '当前事实不可得',
      footnotes: <String>[
        'LOOP 还没有收到这张卡的实时价格与合约事实；消息只保存代币标识，所以不显示价格、风险结论、买入或自选。',
        '引用快照 ${snapshotLabel(reference.snapshotAt)}',
      ],
    ),
  );
}

/// An attachment that claims to be a token card but is not `token_card.v1`.
///
/// Nothing it carries is shown: not its symbol, not its contract, not any
/// figure — a malformed card is exactly where a forged price would sit.
class LoopMalformedTokenCard extends StatelessWidget {
  const LoopMalformedTokenCard({super.key});

  @override
  Widget build(BuildContext context) => const LoopTokenCard(
    key: ValueKey<String>('token-card-malformed'),
    state: LoopTokenCardState.partial,
    margin: EdgeInsets.zero,
    model: LoopTokenCardModel(
      symbol: '无法识别的代币卡',
      identifier: 'token_card.v1',
      footnotes: <String>['这条附件不符合 LOOP token_card.v1，没有显示任何代币事实或操作。'],
    ),
  );
}
