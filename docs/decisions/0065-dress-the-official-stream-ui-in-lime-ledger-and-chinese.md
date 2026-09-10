# 0065 · Dress the official Stream UI in Lime Ledger and Chinese

## Status

Accepted 2026-09-10. Presentation only. It changes no transport, no backend
contract, no Stream request and no state machine; decisions 0047, 0055 and
0059 are untouched.

## Context

The 2026-09-10 simulator acceptance run opened `community-chat` on the server's
own channel. Everything LOOP draws was Lime Ledger and Chinese — the topbar,
「在线人数」, 「置顶公告」, the 「发消息」 placeholder — and everything the official
Stream widgets draw was Stream's own default English theme: a deep-blue own
bubble, a blue send button, a `Today` day separator, a `3:39 PM` timestamp and
「Send a message to start the conversation」 on the empty channel.

Two separate causes:

**(a) The theme was written and never installed.** `loopStreamChatThemeData()`
existed in `lib/features/chat/v2/loop_stream_channel_surface.dart` and had no
caller. `lib/app.dart` mounted `StreamChat(configData: …, componentBuilders: …)`
with no `themeData:` at all. It would not have been enough on its own:
stream_chat_flutter 10.3 moved the palette out of `StreamChatThemeData` (which
now holds only fifteen component themes — headers, the message list, polls,
threads, quoted messages, the channel-list item) and into `StreamTheme`, a
Material `ThemeExtension` from `stream_core_flutter`. `StreamChat.build` reads
`StreamTheme.of(context)` from the **ambient** theme and republishes it to its
subtree, so a Stream palette can only be changed by putting a `StreamTheme`
into the enclosing `ThemeData.extensions`. Nothing did, so every widget fell
back to `StreamTheme(brightness: dark)` — Stream's blue brand ladder.

**(b) There was no localization delegate.** `MaterialApp.router` declared no
`localizationsDelegates`, so `StreamChatLocalizations.of(context)` returned
`null` and `context.translations` fell through to `DefaultTranslations` —
English. `stream_chat_localizations` is **not** in `pubspec.lock` (neither
direct nor transitive; it is not in the pub cache either), and adding it is a
dependency decision, not a styling one.

## Decision

### 1. One injection point, above every official widget

`lib/app.dart` wraps the existing `StreamChat` in a `Theme` that carries the
LOOP `StreamTheme` extension, and now also passes `themeData:`:

```dart
final theme = Theme.of(context);
content = Theme(
  data: theme.copyWith(
    extensions: [...theme.extensions.values, loopStreamTheme(platform: theme.platform)],
  ),
  child: StreamChat(… themeData: loopStreamChatThemeData() …),
);
```

`MaterialApp`'s `builder` runs below `AnimatedTheme`, so `Theme.of(context)`
there is already `LoopTheme.dark` and the copy keeps every existing extension.
Because the injection sits at the single `StreamChat` in the application root,
it reaches `community-chat`, `chat`, `chat-dm`, `chat-group`, the group Alias
screens, `chat-search`, `chat-forward` and the voice-room surfaces without any
page opting in. `_loopStreamComponentBuilders` keeps its existing
`messageComposer` / `messageItem` / `mentionItem` entries.

The mapping lives in `lib/integrations/communication/stream_chat_appearance.dart`
and reads only from `lib/core/theme/loop_theme.dart`. No colour and no type
size is introduced; one radius token is added — `LoopRadius.bubbleTailValue`
(5), which is the prototype's own `.msg-txt` tail corner.

### 2. Prototype → token → Stream field

Source of truth is `docs/prototype/style-v2.css` (`.msg`, `.msg-txt`,
`.msg.me .msg-txt`, `.msg-who`, `.composer`) and
`docs/prototype/screens/community-chat.html`.

| Prototype | LOOP token | Stream field |
| --- | --- | --- |
| `.msg.me .msg-txt` background `var(--lime)` | `LoopColors.lime` | `StreamMessageItemThemeData.bubble.backgroundColor` at `alignment: end`, and `colorScheme.brand.shade100` |
| `.msg.me .msg-txt` colour `var(--ink)` | `LoopColors.ink` | `…bubble` sibling `text.textColor` at `end`, and `colorScheme.brand.shade900` |
| `.msg-txt` background `var(--card)` | `LoopColors.card` | `…bubble.backgroundColor` at `alignment: start`, and `colorScheme.backgroundSurface` |
| `.msg-txt` colour (body text) | `LoopColors.chalk` | `…text.textColor` at `start`, and `colorScheme.textPrimary` |
| `.msg-txt` `border-radius:5px 16px 16px 16px` (mirrored for `.me`) | `LoopRadius.bubbleTailValue` / `LoopRadius.controlValue` | `…bubble.shape`, tail on the sender's side |
| `.msg-txt` `padding:10px 12px`, `font-size:11px`, `line-height:1.55` | `LoopTypography.sora(size: 11, height: 1.55)` | `…bubble.padding`, `…text.textStyle` |
| `.msg-who` `color:var(--tx3)` | `LoopColors.text3` | `…metadata.usernameTextStyle` / `usernameColor` |
| timestamp (LOOP renders every time in tabular mono) | `LoopMono.stamp` | `…metadata.timestampTextStyle`, `editedTextStyle`, `statusTextStyle` |
| `.composer button` `background:var(--lime)`, `color:var(--ink)` | `LoopColors.lime` / `LoopColors.ink` | `colorScheme.accentPrimary` / `textOnAccent` — the primary-solid `StreamButton` the composer's send key is |
| `.composer input` `background:var(--card)`, `border:1px solid var(--line)` | `LoopColors.card` / `LoopColors.line` | `colorScheme.backgroundElevation1` / `borderDefault` |
| neither bubble carries an outline | — | `…bubble.side` is `BorderSide.none` for both alignments; Stream's default hairline on the incoming bubble is dropped rather than restated |
| page ground `var(--ink)` | `LoopColors.ink` | `colorScheme.backgroundApp`, `backgroundElevation0`, `StreamMessageListViewThemeData.backgroundColor`, the three `StreamAppBarThemeData`s |
| highlighted (jumped-to) message | `LoopColors.limeSoft` | `colorScheme.backgroundHighlight`, `StreamMessageListViewThemeData.messageHighlightColor` |
| read receipt ✓✓ | `LoopColors.lime` (read) / `LoopColors.text2` (sent, delivered, pending) | `colorScheme.accentPrimary` / `textSecondary`, read by `StreamSendingIndicator` |
| quoted / reply preview | `LoopColors.card`, `LoopColors.line`, `LoopColors.lime` | `StreamQuotedMessageThemeData` background / side / indicator |
| system message, separators, secondary labels | `LoopColors.text2` / `text3` / `line` | `colorScheme.textSecondary` / `textTertiary` / `borderDefault` |
| body font | `LoopFonts.body` + `LoopFonts.cjkFallback` | `StreamTextTheme.apply(fontFamily:, fontFamilyFallback:)` |

The two ladders (`loopStreamBrandSwatch`, `loopStreamChromeSwatch`) are the
leverage that makes this complete rather than piecemeal. Stream reads
`brand.shade100` as the ground of **every** outgoing surface — bubble, quoted
message, reply attachment, link-preview card, poll option — and
`brand.shade900` as the text on it, so writing Lime at 100 and Ink at 900
carries the prototype's pairing everywhere at once instead of one widget at a
time. The Lime ladder is deliberately **not** monotone: the prototype inverts
Stream's convention (a bright own bubble with dark text where Stream expects a
dark tint with bright text), and the ladder encodes that inversion rather than
fighting it at each call site.

**One accepted deviation.** The prototype's `.composer` bar is `var(--ink)`
with a `var(--line)` top edge, and the field inside it is `var(--card)`. Stream
10.3 gives the composer bar no colour of its own — the field is the only
painted surface, drawn with `backgroundElevation1` — so LOOP sets that token to
`--card` and lets the field's `--line` outline do the separating. The bar
itself therefore reads as the page ground rather than as a distinct strip.
This is a deliberate, recorded deviation: matching the prototype exactly would
mean wrapping the official composer in a LOOP-drawn container, which is chrome
LOOP does not own on this surface.

The remark in the S12 brief that the other party's bubble is "Graphite" is
resolved to the prototype's `--card` (`rgba(243,245,239,.06)`), which over the
Ink page ground renders within a hair of Graphite `#171A16` while staying the
exact token the prototype uses.

### 3. Chinese comes from a LOOP delegate, not a new package

`stream_chat_localizations` is not in the lockfile, and the ruling forbids
changing it. `lib/integrations/communication/stream_chat_localizations_zh.dart`
therefore implements `StreamChatLocalizations` directly — all 226 members of
`Translations` — and `LoopStreamChatLocalizationsDelegate` is registered on
`MaterialApp.router`. The 68 accessibility labels are a second class that
**`implements AccessibilityTranslations`** rather than extending
`DefaultAccessibilityTranslations`: extending would let a member added upstream
fall through to English silently, and a screen-reader label is exactly the
place where that would go unnoticed. Implementing the interface makes the
compiler the check.

The delegate answers `isSupported` for **every** locale. This is deliberate:
LOOP ships one language, and switching the application locale to `zh` would
resolve `MaterialLocalizations` to nothing, because `flutter_localizations` is
not a declared dependency and the built-in `DefaultMaterialLocalizations`
supports `en` only. Answering for all locales gives the Stream widgets Chinese
while `MaterialLocalizations` stays the framework default and every Material
widget keeps working. **No dependency was added and `pubspec.lock` is
unchanged**; `pub get --enforce-lockfile` still resolves byte-identically.

Covered, among the rest: the empty channel
(「发条消息，开始这段对话」), 「还没有消息」, 「还没有会话」, the composer
placeholder 「发消息」, 「今天」/「昨天」, 「已连接」/「正在重连…」/「已断开」/「离线…」,
「已读」/「发送中」/「已发送」/「已送达」, 「图片」/「文件」/「视频」/「语音」/「链接」,
「回复」/「编辑消息」/「删除消息」/「复制消息」/「已编辑」, 「重试」, the flag/mute/block
sheets and the whole poll surface.

### 4. The clock is 24-hour, and it is not Jiffy's

Two Stream call sites format time without going through the translations:
`DefaultStreamMessageFooter` hardcodes `Jiffy.parseFromDateTime(date).jm`
(12-hour), and `StreamDateDivider` falls back to Jiffy for anything older than
yesterday. Jiffy's locale is set inside `StreamChat.didChangeDependencies` from
`Localizations.localeOf(context)`, which — per §3 — stays `en`. Setting the
global Jiffy locale from LOOP would be overwritten by that call.

A third is the `/chat` inbox: `ChannelLastMessageDate` falls back to Stream's
`formatDate`, whose today bucket is Jiffy's 12-hour `jm`, whose within-a-week
bucket is Jiffy's English weekday and whose older bucket is `M/d/yyyy`. Only
its 「昨天」 comes from the localizations.

All three are formatted by LOOP instead:

- `loopStreamClockLabel` returns `HH:mm`, always. It is installed globally as
  the `messageFooter` component builder, which is Stream's own documented
  extension point. The custom footer restates the default one exactly — author
  name in a group, sending status on the user's own message, timestamp, edited
  marker — and re-implements the sending status only because
  `StreamMessageSendingStatus` is not exported; the read receipt still resolves
  its colour from the injected scheme.
- `loopStreamDayLabel` returns 今天 / 昨天 / 周一…周日 / `M月d日` / `y年M月d日`,
  and is passed as `dateDivider` and `floatingDateDivider` to every
  `StreamMessageListView` LOOP mounts. A test walks **every** `.dart` file
  under `lib/` and requires the count of `StreamMessageListView(` in a file to
  equal the count of `builders: loopStreamMessageListViewBuilders()`, so a list
  mounted by a page added later cannot silently fall back.
- `loopStreamChannelListDateLabel` is the same ladder with the clock in the
  today slot — `15:39`, then 昨天 / 周X / `M月d日` / `y年M月d日` — and is passed
  through `loopStreamChannelListTimestamp` to **both** branches of
  `loopStreamChannelListIdentityItem`. The direct branch used to return the
  official cell untouched; `StreamChannelListItem.copyWith` exposes no
  timestamp slot and `_DefaultStreamChannelListItem` is private, so the direct
  cell is now composed from Stream's own public sub-widgets —
  `StreamChannelAvatar`, `StreamChannelName`, `ChannelListTileSubtitle` with
  its typing indicator and delivery status, `StreamChannelListTile` — with only
  the timestamp replaced. The same recursive scan requires every
  `ChannelLastMessageDate(` in `lib/` to pass a `formatter:`.

All three share one bucket function, so the day ladders cannot drift apart.

`intl` was considered for all three and rejected: its non-`en` `DateFormat`
needs `initializeDateFormatting`, it is only a transitive package here, and the
formats LOOP needs are exact and fully testable without it.

## Consequences

- Every official Stream surface in the app is Lime Ledger and Chinese, from one
  place, without a per-page opt-in. Every date and time an official widget
  prints — the message footer, the day separator, the inbox row — is LOOP's
  Chinese 24-hour ladder; no Jiffy-formatted English label survives on a
  mounted surface.
- Adding a new page that mounts official Stream widgets inherits the theme and
  the copy for free. Two things still need wiring, and both are locked by
  recursive scans over `lib/`: a new `StreamMessageListView` needs
  `builders: loopStreamMessageListViewBuilders()`, and a new
  `ChannelLastMessageDate` needs a `formatter:`.
- The remaining Jiffy-formatted strings in the SDK are `fromNow()` in
  `StreamUserListTile` and `ChannelInfo` (「最后在线」). Neither widget is
  mounted by LOOP today and neither has a formatter hook; mounting one would
  need its own decision.
- `pubspec.yaml` and `pubspec.lock` are unchanged.
- `loopStreamChatThemeData()` moves out of the feature module into
  `lib/integrations/communication/`, next to the rest of the Stream adapter.
- The five reviewed states, the membership proof before any channel mounts, the
  disabled attachments and voice recording, and every LOOP-owned string are
  untouched. This decision cannot change what a page claims.

## Alternatives rejected

- **Add `stream_chat_localizations`.** It is not in the lockfile, so it is a
  dependency decision with its own resolution risk, and it would still leave
  the 12-hour footer and the Jiffy day labels in place.
- **Set the application locale to `zh_CN`.** `flutter_localizations` is not a
  declared dependency; `DefaultMaterialLocalizations` supports `en` only, so
  `MaterialLocalizations.of` would fail its assertion across the whole app.
- **Promote `intl` / `flutter_localizations` from transitive to direct.** `pub
  get --enforce-lockfile` reports "Would change 2 dependencies" and refuses to
  write, leaving `pubspec.yaml` and `pubspec.lock` disagreeing. Neither is
  needed for the two exact formats.
- **Put the `StreamTheme` extension into `LoopTheme.dark`.** It would make
  `lib/core/theme` depend on stream_chat_flutter for a provider-specific
  mapping. The extension is built in the Stream adapter and injected at the one
  `StreamChat` mount instead.
- **Restyle each Stream widget through a component builder.** Stream 10.3's
  theme extension already reaches every widget; hand-wrapping them would drift
  the moment the SDK adds a surface.
- **`Jiffy.setLocale('zh_cn')` at startup.** `StreamChat.didChangeDependencies`
  sets the Jiffy locale from the ambient `Localizations` and would overwrite it
  whenever it re-runs.
