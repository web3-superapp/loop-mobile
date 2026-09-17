// Lime Ledger appearance for the official Stream Chat UI (10.3.0).
//
// Stream 10.3 moved its palette into `StreamTheme`, a Material
// `ThemeExtension` that `StreamChat` reads from the ambient theme and
// republishes to every descendant widget. Nothing below invents a colour, a
// radius or a type size: each value is a token from `lib/core/theme`, mapped
// onto the Stream field that renders it. See decision 0065.
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Lime, as Stream's brand ladder reads it.
///
/// Stream uses `brand.shade100` as the ground of an outgoing ("end") surface
/// and `brand.shade900` as the text on it, so the ladder is written to hold
/// the prototype's pairing — Lime ground, Ink text — at every rung a message,
/// a quote, a reply preview or a link card can land on.
const StreamColorSwatch loopStreamBrandSwatch = StreamColorSwatch(
  0xFFB8FF20,
  <int, Color>{
    0: LoopColors.ink,
    50: LoopColors.limeSoft,
    100: LoopColors.lime,
    150: LoopColors.limeHighlight,
    200: LoopColors.limeHighlight,
    300: LoopColors.ink,
    400: LoopColors.ink,
    500: LoopColors.lime,
    600: LoopColors.lime,
    700: LoopColors.ink,
    800: LoopColors.ink,
    900: LoopColors.ink,
    1000: LoopColors.ink,
  },
);

/// The Ink → Chalk ladder. Low rungs are grounds, high rungs are text.
const StreamColorSwatch loopStreamChromeSwatch = StreamColorSwatch(
  0xFF7F897B,
  <int, Color>{
    0: LoopColors.ink,
    50: LoopColors.panel,
    100: LoopColors.card,
    150: LoopColors.card2,
    200: LoopColors.elevated,
    300: LoopColors.line2,
    400: LoopColors.muted,
    500: LoopColors.muted,
    600: LoopColors.text3,
    700: LoopColors.text2,
    800: LoopColors.text2,
    900: LoopColors.chalk,
    1000: LoopColors.chalk,
  },
);

/// The Lime Ledger colour scheme for every official Stream widget.
StreamColorScheme loopStreamColorScheme() => StreamColorScheme.dark(
  brand: loopStreamBrandSwatch,
  chrome: loopStreamChromeSwatch,
  // Lime is the only accent; the send button and every primary control take
  // it, with Ink as the text on top.
  accentPrimary: LoopColors.lime,
  accentNeutral: LoopColors.muted,
  accentError: LoopColors.danger,
  accentWarning: LoopColors.warning,
  accentSuccess: LoopColors.lime,
  textPrimary: LoopColors.chalk,
  textSecondary: LoopColors.text2,
  textTertiary: LoopColors.text3,
  textDisabled: LoopColors.muted,
  textLink: LoopColors.lime,
  textOnAccent: LoopColors.ink,
  textOnInverse: LoopColors.ink,
  backgroundApp: LoopColors.ink,
  backgroundSurface: LoopColors.card,
  backgroundSurfaceSubtle: LoopColors.panel,
  backgroundSurfaceStrong: LoopColors.card2,
  backgroundSurfaceCard: LoopColors.card,
  backgroundOnAccent: LoopColors.ink,
  backgroundHighlight: LoopColors.limeSoft,
  backgroundScrim: LoopColors.veil,
  backgroundDisabled: LoopColors.card,
  backgroundInverse: LoopColors.chalk,
  backgroundElevation0: LoopColors.ink,
  // The composer's input field takes elevation 1; the prototype's
  // `.composer input` ground is `--card`.
  backgroundElevation1: LoopColors.card,
  backgroundElevation2: LoopColors.card,
  backgroundElevation3: LoopColors.elevated,
  backgroundSelected: LoopColors.limeSoft,
  borderDefault: LoopColors.line,
  borderSubtle: LoopColors.line,
  borderStrong: LoopColors.line2,
  borderOnAccent: LoopColors.ink,
  borderOnInverse: LoopColors.ink,
  borderOnSurface: LoopColors.line2,
  borderFocus: LoopColors.lime,
  borderActive: LoopColors.lime,
  borderSelected: LoopColors.lime,
  borderDisabled: LoopColors.line,
  borderDisabledOnSurface: LoopColors.line,
  borderError: LoopColors.danger,
  borderWarning: LoopColors.warning,
  borderSuccess: LoopColors.lime,
  systemText: LoopColors.chalk,
  systemScrollbar: LoopColors.line2,
);

/// Whether a message is drawn on the sender's own side of the list.
bool _isOutgoing(StreamMessageLayoutData layout) =>
    layout.alignment == StreamMessageAlignment.end;

/// The prototype's `.msg-txt` bubble, on band 4. `.msg-txt` carries no
/// `data-primary-body` tag only because it predates that contract layer: a
/// message *is* the primary body of the chat page, and it is set at the same
/// 14px as the in-house bubble in `chat_components.dart`. Ink on Lime for the
/// sender's own message, Chalk on Card for everyone else's.
TextStyle _bubbleTextStyle(Color color) =>
    LoopTypography.body(14, color: color);

/// The Lime Ledger message row: bubble, text and metadata.
///
/// The prototype (`docs/prototype/style-v2.css`, `.msg-txt` / `.msg.me
/// .msg-txt`) gives the own message a Lime ground with Ink text and the other
/// message the translucent Card ground with Chalk text, each with a 5px tail
/// corner on its own side and 16px elsewhere.
StreamMessageItemThemeData
loopStreamMessageItemTheme() => StreamMessageItemThemeData(
  bubble: StreamMessageBubbleStyle(
    backgroundColor: StreamMessageLayoutProperty.resolveWith(
      (layout) => switch (layout.contentKind) {
        StreamMessageContentKind.jumbomoji => Colors.transparent,
        _ => _isOutgoing(layout) ? LoopColors.lime : LoopColors.card,
      },
    ),
    // The prototype draws no outline on either bubble: the own bubble is a
    // solid Lime fill and the other one is `--card` over the Ink page.
    // Stream's default hairline on the incoming bubble is dropped rather than
    // restated in a LOOP colour.
    side: StreamMessageLayoutBorderSide.all(BorderSide.none),
    shape: StreamMessageLayoutProperty.resolveWith(
      (layout) => RoundedRectangleBorder(
        borderRadius: switch ((layout.alignment, layout.stackPosition)) {
          (
            StreamMessageAlignment.start,
            StreamMessageStackPosition.single || StreamMessageStackPosition.top,
          ) =>
            const BorderRadiusDirectional.only(
              topStart: Radius.circular(LoopRadius.bubbleTailValue),
              topEnd: Radius.circular(LoopRadius.controlValue),
              bottomStart: Radius.circular(LoopRadius.controlValue),
              bottomEnd: Radius.circular(LoopRadius.controlValue),
            ),
          (
            StreamMessageAlignment.end,
            StreamMessageStackPosition.single || StreamMessageStackPosition.top,
          ) =>
            const BorderRadiusDirectional.only(
              topStart: Radius.circular(LoopRadius.controlValue),
              topEnd: Radius.circular(LoopRadius.bubbleTailValue),
              bottomStart: Radius.circular(LoopRadius.controlValue),
              bottomEnd: Radius.circular(LoopRadius.controlValue),
            ),
          _ => const BorderRadius.all(Radius.circular(LoopRadius.controlValue)),
        },
      ),
    ),
    padding: StreamMessageLayoutProperty.resolveWith(
      (layout) => switch (layout.contentKind) {
        StreamMessageContentKind.singleAttachment => EdgeInsets.zero,
        _ => const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      },
    ),
  ),
  text: StreamMessageTextStyle(
    textStyle: StreamMessageLayoutProperty.resolveWith(
      (layout) => _bubbleTextStyle(
        _isOutgoing(layout) ? LoopColors.ink : LoopColors.chalk,
      ),
    ),
    textColor: StreamMessageLayoutProperty.resolveWith(
      (layout) => _isOutgoing(layout) ? LoopColors.ink : LoopColors.chalk,
    ),
    linkColor: StreamMessageLayoutProperty.resolveWith(
      (layout) => _isOutgoing(layout) ? LoopColors.ink : LoopColors.lime,
    ),
    mentionColor: StreamMessageLayoutProperty.all(LoopColors.lime),
    mentionBackgroundColor: StreamMessageLayoutProperty.all(
      LoopColors.limeSoft,
    ),
  ),
  metadata: StreamMessageMetadataStyle(
    usernameTextStyle: StreamMessageLayoutProperty.all(
      LoopTypography.caption(11),
    ),
    usernameColor: StreamMessageLayoutProperty.all(LoopColors.text3),
    // Every timestamp in LOOP is tabular mono (`LoopMono.stamp`).
    timestampTextStyle: StreamMessageLayoutProperty.all(LoopMono.stamp),
    timestampColor: StreamMessageLayoutProperty.all(LoopColors.text3),
    editedTextStyle: StreamMessageLayoutProperty.all(LoopMono.stamp),
    editedColor: StreamMessageLayoutProperty.all(LoopColors.text3),
    statusTextStyle: StreamMessageLayoutProperty.all(LoopMono.stamp),
    statusColor: StreamMessageLayoutProperty.all(LoopColors.text3),
  ),
);

/// The Lime Ledger [StreamTheme] injected above every official Stream widget.
StreamTheme loopStreamTheme({TargetPlatform? platform}) {
  final colorScheme = loopStreamColorScheme();
  return StreamTheme(
    brightness: Brightness.dark,
    platform: platform,
    colorScheme: colorScheme,
    textTheme: StreamTextTheme(platform: platform).apply(
      color: LoopColors.chalk,
      fontFamily: LoopFonts.body,
      fontFamilyFallback: LoopFonts.cjkFallback,
    ),
    messageItemTheme: loopStreamMessageItemTheme(),
    appBarTheme: const StreamAppBarThemeData(
      style: StreamAppBarStyle(backgroundColor: LoopColors.ink),
    ),
  );
}

/// Chat-level surfaces Stream keeps outside [StreamTheme].
StreamChatThemeData loopStreamChatThemeData() => StreamChatThemeData(
  messageListViewTheme: const StreamMessageListViewThemeData(
    backgroundColor: LoopColors.ink,
    messageHighlightColor: LoopColors.limeSoft,
  ),
  channelHeaderTheme: const StreamAppBarThemeData(
    style: StreamAppBarStyle(backgroundColor: LoopColors.ink),
  ),
  channelListHeaderTheme: const StreamAppBarThemeData(
    style: StreamAppBarStyle(backgroundColor: LoopColors.ink),
  ),
  threadHeaderTheme: const StreamAppBarThemeData(
    style: StreamAppBarStyle(backgroundColor: LoopColors.ink),
  ),
  quotedMessageTheme: StreamQuotedMessageThemeData(
    backgroundColor: LoopColors.card,
    indicatorColor: LoopColors.lime,
    side: const BorderSide(color: LoopColors.line),
    titleTextStyle: LoopTypography.label(12, color: LoopColors.text2),
    subtitleTextStyle: LoopTypography.caption(11),
  ),
);

/// The prototype's `.msg-who`: the sender's name, above the bubble.
///
/// `.msg-body` stacks `.msg-who` over `.msg-txt`, so the name is the first
/// line of the message column and the avatar beside it reads as the author of
/// what follows. Stream's default puts the name in the metadata row *under*
/// the bubble (C-15), where it lands next to the clock and away from the
/// avatar. The header slot is the symmetric one above the bubble
/// (`DefaultStreamMessageContent` stacks header, body, footer), so the name
/// moves there and Stream's own annotations — pinned, saved, reminder,
/// show-in-channel — keep their place under it.
///
/// The name is still drawn from the metadata username tokens
/// (`loopStreamMessageItemTheme`), because it is the same name in the same
/// voice; only its position changes.
Widget loopStreamMessageHeaderBuilder(
  BuildContext context,
  StreamMessageHeaderProps props,
) => _LoopStreamMessageHeader(props: props);

class _LoopStreamMessageHeader extends StatelessWidget {
  const _LoopStreamMessageHeader({required this.props});

  final StreamMessageHeaderProps props;

  @override
  Widget build(BuildContext context) {
    final layout = StreamMessageLayout.of(context);
    final user = props.message.user;
    final currentUser = StreamChat.of(context).currentUser;

    Widget? usernameWidget;
    // The same test the official footer applies: a group channel names every
    // author but the reader themself.
    if (user != null &&
        layout.channelKind == StreamMessageChannelKind.group &&
        user.id != currentUser?.id) {
      final metadata = StreamMessageItemTheme.of(context).metadata;
      final style =
          metadata?.usernameTextStyle?.resolve(layout) ??
          LoopTypography.caption(11);
      final color = metadata?.usernameColor?.resolve(layout);
      usernameWidget = Text(
        user.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: color == null ? style : style.copyWith(color: color),
      );
    }

    return StreamColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: StreamMessageLayout.crossAxisAlignmentOf(context),
      children: <Widget>[
        ?usernameWidget,
        DefaultStreamMessageHeader(props: props),
      ],
    );
  }
}

/// The Chinese, 24-hour footer under a message bubble.
///
/// It restates Stream's own default footer minus the author name, which the
/// prototype puts above the bubble (`loopStreamMessageHeaderBuilder`): sending
/// status on the user's own message, timestamp, edited marker. Only the clock
/// changes — `HH:mm` instead of Stream's Jiffy-formatted `h:mm a`.
Widget loopStreamMessageFooterBuilder(
  BuildContext context,
  StreamMessageFooterProps props,
) => _LoopStreamMessageFooter(props: props);

class _LoopStreamMessageFooter extends StatelessWidget {
  const _LoopStreamMessageFooter({required this.props});

  final StreamMessageFooterProps props;

  @override
  Widget build(BuildContext context) {
    final message = props.message;
    final currentUser = StreamChat.of(context).currentUser;
    final user = message.user;

    Widget? statusWidget;
    if (user != null && user.id == currentUser?.id) {
      statusWidget = _LoopStreamSendingStatus(message: message);
    }

    Widget? editedWidget;
    if (message.messageTextUpdatedAt != null) {
      editedWidget = Text(context.translations.editedMessageLabel);
    }

    return StreamMessageMetadata(
      status: statusWidget,
      timestamp: StreamTimestamp(
        date: message.createdAt.toLocal(),
        formatter: (context, date) => loopStreamClockLabel(date),
      ),
      edited: editedWidget,
    );
  }
}

/// The sending / delivered / read state under the user's own message.
///
/// It repeats what the official `StreamMessageSendingStatus` renders — Stream
/// does not export that widget — so the read receipt keeps taking its colour
/// from the injected scheme: Lime once read, Muted while sent or pending.
class _LoopStreamSendingStatus extends StatelessWidget {
  const _LoopStreamSendingStatus({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final attachments = message.attachments;
    final hasNonUrlAttachments = attachments.any(
      (attachment) => attachment.type != AttachmentType.urlPreview,
    );
    if (hasNonUrlAttachments && message.state.isOutgoing) {
      final uploaded = attachments
          .where((attachment) => attachment.uploadState.isSuccess)
          .length;
      if (uploaded < attachments.length) {
        return Text(
          context.translations.attachmentsUploadProgressText(
            total: attachments.length,
            completed: uploaded,
          ),
        );
      }
    }

    final channel = StreamChannel.maybeOf(context)?.channel;
    final iconColor = switch (StreamMessageLayout.presentationOf(context)) {
      StreamMessagePresentation.preview =>
        context.streamColorScheme.textOnAccent,
      StreamMessagePresentation.standard => null,
    };

    return BetterStreamBuilder<List<Read>>(
      stream: channel?.state?.readStream,
      initialData: channel?.state?.read,
      builder: (context, data) => StreamSendingIndicator(
        message: message,
        isMessageRead: data.readsOf(message: message).isNotEmpty,
        isMessageDelivered: data.deliveriesOf(message: message).isNotEmpty,
        color: iconColor,
      ),
      noDataBuilder: (context) =>
          StreamSendingIndicator(message: message, color: iconColor),
    );
  }
}

/// The Chinese date separator between two days of messages.
Widget loopStreamDateDivider(DateTime dateTime) => StreamDateDivider(
  dateTime: dateTime,
  formatter: (context, date) => loopStreamDayLabel(date),
);

/// The builders every LOOP [StreamMessageListView] passes.
///
/// Stream reads `todayLabel` / `yesterdayLabel` from the localizations, but
/// falls back to Jiffy for older days, and Jiffy's locale follows the
/// application locale rather than LOOP's copy. Formatting the separator here
/// keeps every day label Chinese.
StreamMessageListViewBuilders loopStreamMessageListViewBuilders() =>
    StreamMessageListViewBuilders(
      dateDivider: loopStreamDateDivider,
      floatingDateDivider: loopStreamDateDivider,
    );

/// The prototype's `.msg-txt`, read back out of Stream's markdown pipeline.
///
/// `StreamMessageText` hands `core.StreamMessageText` a markdown document:
/// every newline is doubled into a paragraph break
/// (`stream_chat_flutter-10.3.0/lib/src/message_widget/components/
/// stream_message_text.dart:75`) and every mention is wrapped as
/// `[@name](mention:id)`. LOOP's chat has no formatting affordance — the
/// composer sends what the member typed — so this reverses both transforms
/// and returns the literal text the member sent. `|`, `*`, `_` and `#` then
/// reach the screen instead of being eaten by the markdown parser.
@visibleForTesting
String loopStreamPlainMessageText(String markdown) {
  // Undo `[@name](mention[-type]:id)` — the shape `Message.replaceMentions`
  // writes — back to the `@name` that `linkify: false` would have produced.
  final unlinked = markdown.replaceAllMapped(
    RegExp(
      r'\[(@[^\]\n]+)\]\(mention(?:-(?:user|channel|here|role|group))?:'
      r'[^)\s]+\)',
    ),
    (match) => match.group(1)!,
  );
  // Undo the paragraph inflation: every original newline arrived doubled, so
  // an even run of n newlines is n ÷ 2 newlines of the member's own text.
  return unlinked.replaceAllMapped(
    RegExp(r'\n+'),
    (match) => '\n' * (match.group(0)!.length ~/ 2).clamp(1, 1 << 20),
  );
}

/// Renders one message as plain text on the band-4 ladder.
///
/// Registered on [StreamComponentBuilders.messageText] so every official
/// surface that prints message text — the bubble, a quoted reply — takes it.
/// An emoji-only message keeps Stream's own renderer: the jumbomoji sizes
/// live in that widget and an emoji run carries no markdown to eat.
Widget loopStreamMessageTextBuilder(
  BuildContext context,
  StreamMessageTextProps props,
) => _LoopStreamMessageText(props: props);

class _LoopStreamMessageText extends StatelessWidget {
  const _LoopStreamMessageText({required this.props});

  final StreamMessageTextProps props;

  @override
  Widget build(BuildContext context) {
    final layout = StreamMessageLayout.of(context);
    if (layout.contentKind == StreamMessageContentKind.jumbomoji) {
      return DefaultStreamMessageText(props: props);
    }

    final themeStyle = StreamMessageItemTheme.of(context).text;
    final fallback = _bubbleTextStyle(
      _isOutgoing(layout) ? LoopColors.ink : LoopColors.chalk,
    );
    final style =
        props.style?.textStyle?.resolve(layout) ??
        themeStyle?.textStyle?.resolve(layout) ??
        fallback;
    final color =
        props.style?.textColor?.resolve(layout) ??
        themeStyle?.textColor?.resolve(layout);
    final padding =
        props.padding ??
        props.style?.padding?.resolve(layout) ??
        themeStyle?.padding?.resolve(layout) ??
        EdgeInsets.zero;

    return Padding(
      padding: padding,
      child: Text(
        loopStreamPlainMessageText(props.text),
        style: color == null ? style : style.copyWith(color: color),
      ),
    );
  }
}
