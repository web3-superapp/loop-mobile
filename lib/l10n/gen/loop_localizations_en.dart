// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'loop_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LoopLocalizationsEn extends LoopLocalizations {
  LoopLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get betaFeedback_cameraFailed => 'Couldn\'t open the camera';

  @override
  String get betaFeedback_categoryOther => 'Other';

  @override
  String get betaFeedback_categorySuggestion => 'Suggestion';

  @override
  String get betaFeedback_copyBootstrapRequired =>
      'Your account isn\'t set up yet. Try again later.';

  @override
  String get betaFeedback_copyLoadFailed =>
      'Couldn\'t load feedback. Try again later.';

  @override
  String get betaFeedback_copyLoadMalformed => 'The response was incomplete.';

  @override
  String get betaFeedback_copyLoadOffline =>
      'No network; couldn\'t load feedback.';

  @override
  String get betaFeedback_copyRateLimited =>
      'Too many submissions. Try again later.';

  @override
  String get betaFeedback_copyRegionBlocked =>
      'This account can\'t send feedback.';

  @override
  String get betaFeedback_copySubmissionUnknown =>
      'The result isn\'t confirmed. Submitting again won\'t create a duplicate.';

  @override
  String get betaFeedback_copySubmitFailed =>
      'Feedback wasn\'t sent. Try again later.';

  @override
  String get betaFeedback_copySubmitMalformed =>
      'The response was incomplete; the result isn\'t confirmed.';

  @override
  String get betaFeedback_copySubmitOffline =>
      'No network; feedback wasn\'t sent.';

  @override
  String get betaFeedback_copyUnavailable =>
      'Feedback isn\'t available right now.';

  @override
  String get betaFeedback_copyValidationFailed =>
      'The text or images don\'t meet the requirements. Edit them and try again.';

  @override
  String get betaFeedback_description => 'Description';

  @override
  String get betaFeedback_envDevice => 'Device';

  @override
  String get betaFeedback_envPage => 'Page';

  @override
  String get betaFeedback_envSystem => 'OS';

  @override
  String get betaFeedback_envVersion => 'Version';

  @override
  String get betaFeedback_environment => 'Environment';

  @override
  String get betaFeedback_feedback => 'Feedback';

  @override
  String betaFeedback_imageLimit(Object? maximumImages) {
    return 'Up to $maximumImages images';
  }

  @override
  String get betaFeedback_imageUnusable => 'Some images can\'t be used';

  @override
  String get betaFeedback_images => 'Images';

  @override
  String get betaFeedback_mineEmpty => 'No feedback yet';

  @override
  String get betaFeedback_mineErrorTitle => 'Couldn\'t load feedback';

  @override
  String get betaFeedback_minePermissionTitle => 'No permission';

  @override
  String get betaFeedback_mineTitle => 'My feedback';

  @override
  String get betaFeedback_mineUnavailableMessage =>
      'Feedback history can\'t be loaded right now.';

  @override
  String get betaFeedback_mineUnavailableTitle => 'Feedback isn\'t available';

  @override
  String get betaFeedback_noCameraAccess => 'No camera access';

  @override
  String get betaFeedback_noPhotoAccess => 'No photo access';

  @override
  String get betaFeedback_notSent => 'Not sent';

  @override
  String get betaFeedback_photos => 'Photos';

  @override
  String get betaFeedback_photosFailed => 'Couldn\'t open Photos';

  @override
  String get betaFeedback_removeImage => 'Remove image';

  @override
  String get betaFeedback_send => 'Send feedback';

  @override
  String get betaFeedback_statusOpen => 'Open';

  @override
  String get betaFeedback_statusResolved => 'Resolved';

  @override
  String get betaFeedback_statusWontFix => 'Won\'t fix';

  @override
  String get betaFeedback_takePhoto => 'Take photo';

  @override
  String get betaFeedback_unavailableMessage =>
      'Feedback can\'t be sent right now.';

  @override
  String betaFeedback_uploading(Object? images, Object? uploaded) {
    return 'Uploading images $uploaded / $images';
  }

  @override
  String get chain_contractBootstrapRequired =>
      'Your account isn\'t set up yet. Try again later.';

  @override
  String get chain_contractCancelled =>
      'The request was cancelled and the result is unknown. Check the latest status before deciding whether to retry.';

  @override
  String get chain_contractChainMismatch =>
      'This chain isn\'t supported: Wallet, Market, Swap and approvals run on BNB Smart Chain; Launch runs on the Launch chain published by LOOP.';

  @override
  String get chain_contractDerived => 'Converted at trade price';

  @override
  String get chain_contractIdempotencyConflict =>
      'The same action was already submitted with different content. Check the latest status and try again.';

  @override
  String get chain_contractIndexingDelayed =>
      'On-chain records are still syncing. They can\'t be read right now; that doesn\'t mean there are none.';

  @override
  String get chain_contractInsufficientBalance =>
      'Balance doesn\'t cover this amount, the maximum network fee or the fee reserve. No transaction was submitted.';

  @override
  String get chain_contractInvalidData =>
      'The returned data was incomplete. Nothing on this page was used.';

  @override
  String get chain_contractLoopCurve => 'LOOP curve';

  @override
  String get chain_contractLoopIndexer => 'LOOP on-chain index';

  @override
  String get chain_contractNotFound =>
      'The target doesn\'t exist, isn\'t registered, or isn\'t visible to this account.';

  @override
  String get chain_contractOffline =>
      'This device is offline. Nothing was loaded on this page and no action was submitted.';

  @override
  String get chain_contractOutcomeUnknown =>
      'The returned data was incomplete and the result isn\'t confirmed. Refresh to see the latest status; don\'t submit again.';

  @override
  String get chain_contractPermissionDenied =>
      'This account doesn\'t have permission for this action.';

  @override
  String get chain_contractPoolSlot0 => 'Derived from pool';

  @override
  String get chain_contractProxied => 'Priced in WBNB';

  @override
  String get chain_contractQuoteExpired =>
      'The quote has expired. No swap was submitted. Get a new quote before confirming.';

  @override
  String get chain_contractRateLimited =>
      'Too many requests. Wait a moment and try again.';

  @override
  String get chain_contractReadFailed =>
      'This page can\'t be loaded right now. Nothing was submitted. Try again later.';

  @override
  String get chain_contractRegionBlocked =>
      'This action isn\'t available in your region right now. Nothing was changed. This isn\'t related to your account or assets, and switching won\'t change the result.';

  @override
  String get chain_contractSimulationFailed =>
      'This transaction didn\'t pass simulation and can\'t be signed. Go back to the confirmation page and prepare it again.';

  @override
  String get chain_contractStale => 'Data may be out of date';

  @override
  String get chain_contractStepUpCancelled => 'Cancelled. Nothing was changed.';

  @override
  String get chain_contractStepUpRequired =>
      'This step requires two-step verification, which isn\'t available yet. Nothing was changed.';

  @override
  String get chain_contractSubmissionUnknown =>
      'This action was already submitted once and the result is unknown, so it\'s locked. Only check the latest status; don\'t submit again.';

  @override
  String get chain_contractSwitch =>
      'On-chain data can\'t be loaded right now.';

  @override
  String get chain_contractSwitch10 =>
      'The balance wasn\'t loaded this time, so no number is shown.';

  @override
  String get chain_contractSwitch11 =>
      'Transfer history can\'t be loaded right now.';

  @override
  String get chain_contractSwitch12 =>
      'Trades and candlesticks can\'t be loaded right now.';

  @override
  String get chain_contractSwitch13 =>
      'BNB transfer history can\'t be loaded right now.';

  @override
  String get chain_contractSwitch14 =>
      'Bridge and mining claim history can\'t be loaded right now.';

  @override
  String get chain_contractSwitch15 =>
      'MEME records on the Launch chain haven\'t started syncing; only transfers are listed below.';

  @override
  String get chain_contractSwitch16 =>
      'MEME records weren\'t loaded this time; only transfers are listed below. Check back later.';

  @override
  String get chain_contractSwitch17 =>
      'This asset can\'t be reconciled with wallet records.';

  @override
  String get chain_contractSwitch18 =>
      'External wallets can\'t be reconciled with wallet records.';

  @override
  String get chain_contractSwitch19 =>
      'Balance reconciliation failed; on-chain figures aren\'t affected.';

  @override
  String get chain_contractSwitch2 =>
      'On-chain data isn\'t available right now. Try again later.';

  @override
  String get chain_contractSwitch20 =>
      'Swap isn\'t available yet; this page has no buy or sell entry.';

  @override
  String get chain_contractSwitch21 =>
      'This asset can no longer be loaded. The row is kept so you can remove it.';

  @override
  String get chain_contractSwitch22 =>
      'This address isn\'t in the LOOP asset catalog. The data below comes from a market data source and can\'t be traded.';

  @override
  String get chain_contractSwitch23 => 'This asset is blocked.';

  @override
  String get chain_contractSwitch24 =>
      'Market data isn\'t available right now. Try again later.';

  @override
  String get chain_contractSwitch25 =>
      'Price can\'t be loaded right now, so no value is shown.';

  @override
  String get chain_contractSwitch26 =>
      'DexScreener data is currently turned off.';

  @override
  String get chain_contractSwitch27 =>
      'Security info and holder count can\'t be loaded right now.';

  @override
  String get chain_contractSwitch28 =>
      'New token discovery and related market data can\'t be loaded right now.';

  @override
  String get chain_contractSwitch29 =>
      'The data service is rate limited; no new figures for now.';

  @override
  String get chain_contractSwitch3 =>
      'Checking the on-chain connection; on-chain figures are hidden for now.';

  @override
  String get chain_contractSwitch30 =>
      'The data service rejected this request. It isn\'t your network. Check back later.';

  @override
  String get chain_contractSwitch31 =>
      'Market data can\'t be loaded right now, so this item has no value. Check back later.';

  @override
  String get chain_contractSwitch32 =>
      'Market data can\'t be fetched right now. It isn\'t your network. Check back later.';

  @override
  String get chain_contractSwitch33 =>
      'The returned data was incomplete and was discarded.';

  @override
  String get chain_contractSwitch34 => 'No trading pair found for this asset.';

  @override
  String get chain_contractSwitch35 =>
      'The data source didn\'t report this item.';

  @override
  String get chain_contractSwitch36 =>
      'Native BNB has no contract address, so this item doesn\'t apply.';

  @override
  String get chain_contractSwitch37 =>
      'This asset has no PancakeSwap V3 pool yet.';

  @override
  String get chain_contractSwitch38 => 'No trades in the selected range.';

  @override
  String get chain_contractSwitch39 =>
      'This row\'s balance can\'t be loaded, so it can\'t be valued.';

  @override
  String get chain_contractSwitch4 =>
      'Can\'t reach the on-chain node right now. It isn\'t your network. Check back later.';

  @override
  String get chain_contractSwitch40 => 'No data';

  @override
  String get chain_contractSwitch5 =>
      'Not connected to BNB Smart Chain; this page is unavailable.';

  @override
  String get chain_contractSwitch6 =>
      'Launch chain data can\'t be loaded right now.';

  @override
  String get chain_contractSwitch7 =>
      'Checking the Launch chain connection; on-chain figures are hidden for now.';

  @override
  String get chain_contractSwitch8 =>
      'Can\'t reach the Launch chain node right now. It isn\'t your network. Check back later.';

  @override
  String get chain_contractSwitch9 =>
      'Not connected to the Launch chain; Launch content is unavailable.';

  @override
  String get chain_contractText =>
      'Holder distribution can\'t be loaded right now.';

  @override
  String get chain_contractText10 =>
      'Fund actions aren\'t available right now. Try again later.';

  @override
  String get chain_contractText11 =>
      'On-chain actions are currently turned off; view only for now.';

  @override
  String get chain_contractText12 =>
      'Swap isn\'t available right now. Try again later.';

  @override
  String get chain_contractText13 =>
      'Swap is still being verified. You can view quotes but can\'t execute.';

  @override
  String get chain_contractText14 =>
      'Swap can\'t be simulated right now, so it can\'t be executed.';

  @override
  String get chain_contractText15 =>
      'Can\'t check whether this address is on known scam lists right now. That doesn\'t mean it\'s safe.';

  @override
  String get chain_contractText16 =>
      'Approval risk info can\'t be loaded right now.';

  @override
  String get chain_contractText17 =>
      'This row\'s approval amount can\'t be loaded, so no number is shown.';

  @override
  String get chain_contractText18 =>
      'This transaction was rejected on-chain during simulation and can\'t be signed.';

  @override
  String get chain_contractText19 =>
      'Simulation returned no verifiable result, so it can\'t be signed.';

  @override
  String get chain_contractText2 =>
      'Smart money tracking isn\'t available yet.';

  @override
  String get chain_contractText20 =>
      'Can\'t estimate the network fee, so no signable transaction can be built.';

  @override
  String get chain_contractText21 =>
      'This action has expired. Prepare it again.';

  @override
  String get chain_contractText22 =>
      'This wallet has prepared a new action; this one was replaced and not submitted.';

  @override
  String get chain_contractText23 =>
      'You cancelled this action. No transaction was submitted.';

  @override
  String get chain_contractText24 =>
      'The transaction was submitted but isn\'t on-chain yet. LOOP will keep checking.';

  @override
  String get chain_contractText25 =>
      'The submitted transaction didn\'t match what was prepared and was rejected.';

  @override
  String get chain_contractText26 =>
      'The transaction is on-chain but failed; the network fee was spent.';

  @override
  String get chain_contractText27 =>
      'The transaction receipt can\'t be loaded right now; the result is pending.';

  @override
  String get chain_contractText28 =>
      'The wallet rejected this swap. Nothing was submitted on-chain.';

  @override
  String get chain_contractText29 =>
      'The result of this action isn\'t certain yet. Wait for confirmation; don\'t submit again.';

  @override
  String get chain_contractText3 =>
      'Push notifications aren\'t available yet; alerts only appear in the in-app notification list.';

  @override
  String get chain_contractText30 =>
      'Price impact is over 5%; this swap was blocked.';

  @override
  String get chain_contractText31 =>
      'Can\'t calculate the price impact of this swap, so it was blocked.';

  @override
  String get chain_contractText32 =>
      'This action can\'t go to wallet signing right now.';

  @override
  String get chain_contractText33 =>
      'This chain doesn\'t support this action: Send, approvals, revokes and Swap only work on mainnet.';

  @override
  String get chain_contractText34 => 'Security settings aren\'t available yet.';

  @override
  String get chain_contractText35 =>
      'Security settings aren\'t available right now. Try again later.';

  @override
  String get chain_contractText36 => 'Account settings aren\'t available yet.';

  @override
  String get chain_contractText37 =>
      'Settings aren\'t available right now. Try again later.';

  @override
  String get chain_contractText38 => 'Support isn\'t available yet.';

  @override
  String get chain_contractText39 =>
      'Support isn\'t available right now. Try again later.';

  @override
  String get chain_contractText4 => 'No community has linked this asset yet.';

  @override
  String get chain_contractText40 =>
      'The device list can\'t be loaded right now.';

  @override
  String get chain_contractText41 =>
      'Recent security events can\'t be loaded right now.';

  @override
  String get chain_contractText42 =>
      'Two-step verification is required, but it isn\'t available yet.';

  @override
  String get chain_contractText43 =>
      'Tickets can\'t take attachments right now.';

  @override
  String get chain_contractText44 =>
      'Legal document links can\'t be opened right now.';

  @override
  String get chain_contractText45 => 'The new terms haven\'t taken effect yet.';

  @override
  String get chain_contractText46 =>
      'Version and build number come from this device.';

  @override
  String get chain_contractText47 => 'No wallet selected yet.';

  @override
  String get chain_contractText48 =>
      'The approval list can\'t be loaded right now.';

  @override
  String get chain_contractText49 => 'The approval list isn\'t available yet.';

  @override
  String get chain_contractText5 =>
      'Per-asset mining figures aren\'t available yet; power and details are on the Mining page.';

  @override
  String get chain_contractText50 =>
      'On-chain records are still syncing; the approval list can\'t be loaded right now.';

  @override
  String get chain_contractText51 => 'This feature isn\'t available right now.';

  @override
  String get chain_contractText52 =>
      'Multi-factor authentication isn\'t available yet.';

  @override
  String get chain_contractText53 => 'Passkeys aren\'t available yet.';

  @override
  String get chain_contractText54 => 'Recovery password isn\'t available yet.';

  @override
  String get chain_contractText55 => 'Automatic recovery isn\'t available yet.';

  @override
  String get chain_contractText56 => 'Social recovery isn\'t available yet.';

  @override
  String get chain_contractText57 => 'Private key export isn\'t available yet.';

  @override
  String get chain_contractText58 =>
      'Scan to pay isn\'t available yet; the camera won\'t open and no payment code is generated here.';

  @override
  String get chain_contractText59 =>
      'Bridge isn\'t available yet; no bridge action is started here.';

  @override
  String get chain_contractText6 =>
      'Indicators and drawing tools aren\'t available yet.';

  @override
  String get chain_contractText60 =>
      'DApp connection and signing aren\'t available yet; this page only runs local checks.';

  @override
  String get chain_contractText61 => 'Community AI isn\'t available yet.';

  @override
  String get chain_contractText7 =>
      'Net value trend and 24h change can\'t be loaded right now.';

  @override
  String get chain_contractText8 =>
      'Custom networks aren\'t available yet; only networks LOOP supports are shown here.';

  @override
  String get chain_contractText9 =>
      'Security Center and DApp status aren\'t available yet.';

  @override
  String get chain_contractTimedOut =>
      'LOOP timed out. Nothing was loaded on this page and no action was submitted.';

  @override
  String get chain_contractUnavailable =>
      'On-chain data can\'t be loaded right now. Try again later.';

  @override
  String get chain_contractUnexpected =>
      'The action didn\'t finish. Try again later.';

  @override
  String get chain_contractValidationFailed =>
      'The input isn\'t valid (for example, an unregistered asset or an invalid threshold). Fix it and try again.';

  @override
  String get chain_contractVersionConflict =>
      'The data was changed on another device. Reload before submitting; nothing was overwritten this time.';

  @override
  String get chain_modelsBlocked => 'Blocked';

  @override
  String get chain_modelsErc20Transfer => 'ERC-20 transfer index';

  @override
  String get chain_modelsLoopProvenanceLabel => 'Unknown source';

  @override
  String chain_modelsLoopProvenanceLabel2(
    Object? observedAtLabel,
    Object? sourceLabel,
  ) {
    return '$sourceLabel · observed $observedAtLabel';
  }

  @override
  String get chain_modelsMismatched => 'Mismatch';

  @override
  String get chain_modelsPending => 'Pending check';

  @override
  String get chain_modelsPoolEvent => 'Pool event index';

  @override
  String chain_modelsS(Object? factSourceLabel) {
    return 'Source $factSourceLabel';
  }

  @override
  String get chain_modelsUnavailable => 'Can\'t load right now';

  @override
  String get chain_modelsUnreachable => 'Unreachable';

  @override
  String get chain_modelsUnregistered => 'Unregistered';

  @override
  String get chain_modelsVerified => 'Verified';

  @override
  String get chain_modelsVerified2 => 'Passed';

  @override
  String chain_widgetsChainPreviewNoticeBody(Object? resource) {
    return '$resource exists only in this development preview; it isn\'t written to your account or uploaded.';
  }

  @override
  String get chain_widgetsLabel => 'Source';

  @override
  String get chain_widgetsLoopFactProvenance => 'Source not labeled';

  @override
  String chain_widgetsLoopFactProvenance2(Object? label, Object? relativeTime) {
    return '$label · observed $relativeTime';
  }

  @override
  String get chain_widgetsLoopOfflineState => 'Switch wallet';

  @override
  String get chain_widgetsLoopOfflineState2 => 'Save to watchlist';

  @override
  String chain_widgetsLoopRelativeTime(Object? inSeconds) {
    return '${inSeconds}s ago';
  }

  @override
  String chain_widgetsLoopRelativeTime2(Object? inMinutes) {
    return '${inMinutes}m ago';
  }

  @override
  String chain_widgetsLoopRelativeTime3(Object? inHours) {
    return '${inHours}h ago';
  }

  @override
  String chain_widgetsLoopRelativeTime4(Object? inDays) {
    return '${inDays}d ago';
  }

  @override
  String chain_widgetsProvenanceFooterSemanticsLabel(
    Object? text,
    Object? title,
  ) {
    return '$text, view $title';
  }

  @override
  String chain_widgetsRegionBlocked(Object? chainFailureReason) {
    return '$chainFailureReason Content already loaded on this page isn\'t affected.';
  }

  @override
  String get chain_widgetsRetryLabel => 'Try again later';

  @override
  String chain_widgetsSemanticsLabel(Object? factProvenance) {
    return '$factProvenance, view data source notes';
  }

  @override
  String chain_widgetsStepUpRequired(Object? chainFailureReason) {
    return '$chainFailureReason Check the verification methods available in Security Center; content already loaded on this page isn\'t affected.';
  }

  @override
  String chain_widgetsSwitch(Object? chainFailureReason) {
    return '$chainFailureReason This permission can\'t be changed in the app. You can switch to an authorized account or asset; content already loaded on this page isn\'t affected.';
  }

  @override
  String get chain_widgetsTitle => 'This content isn\'t available right now';

  @override
  String get chain_widgetsTitle2 => 'This step requires two-step verification';

  @override
  String get chain_widgetsTitle3 =>
      'This action isn\'t available in your region';

  @override
  String get chatAttachments_streamTokenCardBuilderLoopTokenCardModel =>
      'LOOP hasn\'t received a live price or contract facts for this card yet. The message only stores the token ID, so price, risk, Buy and Watch aren\'t shown.';

  @override
  String chatAttachments_streamTokenCardBuilderLoopTokenCardModel2(
    Object? snapshotLabel,
  ) {
    return 'Snapshot $snapshotLabel';
  }

  @override
  String get chatAttachments_streamTokenCardBuilderLoopTokenCardModel3 =>
      'This attachment doesn\'t match LOOP token_card.v1, so no token facts or actions are shown.';

  @override
  String get chatAttachments_streamTokenCardBuilderPriceReason =>
      'Current facts unavailable';

  @override
  String get chatAttachments_streamTokenCardBuilderSymbol =>
      'Unrecognized token card';

  @override
  String
  get chatAttachments_streamTokenCardMessagePreviewFormatterMemberBuyLabel =>
      'Member bought';

  @override
  String chatCalls_audioRoomContractAudioRoomNotificationTitle(Object? name) {
    return 'In voice room · $name';
  }

  @override
  String get chatCalls_audioRoomContractAudioRoomOutputLabel => 'Audio output';

  @override
  String get chatCalls_audioRoomContractAudioRoomRestoredMicrophoneNote =>
      'Reconnected. Tap the mic to keep speaking';

  @override
  String get chatCalls_audioRoomContractDisconnected =>
      'Voice disconnected; count updates after reconnecting';

  @override
  String get chatCalls_audioRoomContractEarpiece => 'Earpiece';

  @override
  String get chatCalls_audioRoomContractExternalOutputLabel => 'Headphones';

  @override
  String get chatCalls_audioRoomContractReconnecting =>
      'Voice reconnecting; count updates after reconnecting';

  @override
  String get chatCalls_audioRoomContractSpeaker => 'Speaker';

  @override
  String get chatCalls_audioRoomContractText =>
      'Tap to return to the voice room';

  @override
  String get chatCalls_audioRoomContractTitle => 'In voice room';

  @override
  String get chatCalls_streamForegroundViewCallClosed =>
      'You can\'t speak in this call anymore. Leave and join again.';

  @override
  String get chatCalls_streamForegroundViewCanRequest =>
      'Counting people in the call';

  @override
  String get chatCalls_streamForegroundViewCommandError =>
      'Couldn\'t reconnect voice. Try again.';

  @override
  String get chatCalls_streamForegroundViewCommandError2 =>
      'Couldn\'t leave this call cleanly. Retry.';

  @override
  String get chatCalls_streamForegroundViewIf =>
      'Leaving this call. The mic won\'t start again; mute first if needed, then retry leaving.';

  @override
  String get chatCalls_streamForegroundViewIf2 =>
      'Your mic is on and people in the room can hear you. Tap Mute to turn it off anytime.';

  @override
  String get chatCalls_streamForegroundViewIf3 =>
      'You were moved off stage and can only listen now. Wait for the host to invite you again to speak.';

  @override
  String chatCalls_streamForegroundViewIf4(Object? speakAgainLabel) {
    return 'You\'re muted. To speak again, tap $speakAgainLabel to reconnect voice.';
  }

  @override
  String chatCalls_streamForegroundViewIf5(Object? speakLabel) {
    return 'You joined muted. Tap $speakLabel when you\'re ready; mic access is only requested when capture starts.';
  }

  @override
  String get chatCalls_streamForegroundViewLabel => 'Reconnect failed';

  @override
  String get chatCalls_streamForegroundViewLabel2 => 'Waiting';

  @override
  String get chatCalls_streamForegroundViewLabel3 => 'Joining';

  @override
  String get chatCalls_streamForegroundViewLabel4 => 'Connecting media';

  @override
  String get chatCalls_streamForegroundViewLabel5 => 'Connected';

  @override
  String get chatCalls_streamForegroundViewLabel6 => 'Reconnecting';

  @override
  String get chatCalls_streamForegroundViewLabel7 => 'Switching connection';

  @override
  String get chatCalls_streamForegroundViewLabel8 => 'Connecting';

  @override
  String get chatCalls_streamForegroundViewLabel9 => 'Call unavailable';

  @override
  String get chatCalls_streamForegroundViewMessage =>
      'This call dropped and is reconnecting. Member details reload once connected.';

  @override
  String get chatCalls_streamForegroundViewMessage2 =>
      'This call disconnected. Member details load after voice reconnects.';

  @override
  String get chatCalls_streamForegroundViewMessage3 =>
      'Not connected to this call yet. Member details load once connected.';

  @override
  String get chatCalls_streamForegroundViewMessage4 =>
      'This call just connected; the provider hasn\'t sent member details yet.';

  @override
  String get chatCalls_streamForegroundViewMicrophoneState => 'Speaking';

  @override
  String get chatCalls_streamForegroundViewMicrophoneState2 => 'Mic on';

  @override
  String get chatCalls_streamForegroundViewRoomPermission =>
      'This room hasn\'t let you speak yet; your mic is off.';

  @override
  String chatCalls_streamForegroundViewS(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people in the call now',
      one: '1 person in the call now',
    );
    return '$_temp0';
  }

  @override
  String get chatCalls_streamForegroundViewS2 =>
      'You\'re a listener in this room.';

  @override
  String get chatCalls_streamForegroundViewS3 => 'Speak again';

  @override
  String get chatCalls_streamForegroundViewS4 => 'Listen only';

  @override
  String get chatCalls_streamForegroundViewS5 => 'Switch to earpiece';

  @override
  String get chatCalls_streamForegroundViewSetState =>
      'Couldn\'t mute the mic. Retry, or leave this room.';

  @override
  String get chatCalls_streamForegroundViewSpeakAgainLabel =>
      'Reconnect to speak';

  @override
  String get chatCalls_streamForegroundViewSpeakLabel => 'Speak';

  @override
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel =>
      'Reconnecting';

  @override
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel2 =>
      'Switching';

  @override
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel3 =>
      'Leaving';

  @override
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel4 =>
      'Can\'t unmute';

  @override
  String get chatCalls_streamForegroundViewSwitch =>
      'Audio plays from the connected device';

  @override
  String get chatCalls_streamForegroundViewSwitch2 => 'Switch to speaker';

  @override
  String get chatCalls_streamForegroundViewSystemPermission =>
      'No mic access. Allow LOOP to use the microphone in system settings, then try again.';

  @override
  String get chatCalls_streamForegroundViewTitle => 'Reconnecting';

  @override
  String get chatCalls_streamForegroundViewTitle2 => 'Voice disconnected';

  @override
  String get chatCalls_streamForegroundViewTitle3 => 'Connecting voice';

  @override
  String get chatCalls_streamForegroundViewTitle4 => 'Loading call members';

  @override
  String get chatCalls_streamForegroundViewUnknown =>
      'Couldn\'t turn on the mic. Try again.';

  @override
  String get chatCalls_streamForegroundViewVoiceroomMediaAudioSuspended =>
      'Audio paused by the system';

  @override
  String get chatCalls_streamForegroundViewVoiceroomMediaDisconnectMessage =>
      'Disconnect voice';

  @override
  String get chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel =>
      'Switching mic';

  @override
  String get chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel2 =>
      'Retry leaving first';

  @override
  String get chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel3 =>
      'Can\'t unmute in this call';

  @override
  String chatCalls_streamForegroundViewVoiceroomMediaOutputLabel(
    Object? label,
  ) {
    return 'Audio output: $label';
  }

  @override
  String get chatCalls_streamForegroundViewVoiceroomMediaSpeakAgainLabel =>
      'Reconnecting voice';

  @override
  String get chatCalls_streamVoiceRoomAccountChanged =>
      'Your sign-in changed while connecting. Leave this page and come back.';

  @override
  String get chatCalls_streamVoiceRoomClient =>
      'Couldn\'t set up voice on this device. Try again.';

  @override
  String get chatCalls_streamVoiceRoomConnection =>
      'This device couldn\'t reach the voice service. Check your network and retry.';

  @override
  String get chatCalls_streamVoiceRoomCredential =>
      'The voice credential for this call wasn\'t issued. Check your network and retry.';

  @override
  String chatCalls_streamVoiceRoomHost(Object? speakLabel) {
    return 'You\'re the host and also join muted; mic access is only requested when you tap $speakLabel. The room doesn\'t end if voice can\'t connect; use End room below to end it.';
  }

  @override
  String get chatCalls_streamVoiceRoomIdentity =>
      'This device doesn\'t have a voice identity yet. Leave this page and come back.';

  @override
  String get chatCalls_streamVoiceRoomIf =>
      'You always join muted; mic access is only requested when you tap Speak. Voice continues in the background or when locked; only Leave disconnects.';

  @override
  String get chatCalls_streamVoiceRoomIf2 =>
      'Join muted · Continues in background';

  @override
  String get chatCalls_streamVoiceRoomIf3 =>
      'No demo members, presence or room activity are shown here.';

  @override
  String get chatCalls_streamVoiceRoomJoinError =>
      'Couldn\'t get this voice room ready. Check the conversation and retry.';

  @override
  String get chatCalls_streamVoiceRoomMessage =>
      'This call disconnected. Recording your exit in the LOOP room record.';

  @override
  String get chatCalls_streamVoiceRoomMessage10 =>
      'Requesting a voice identity and short-lived token. No call is joined meanwhile.';

  @override
  String get chatCalls_streamVoiceRoomMessage11 =>
      'Loading the authorized voice room. Your mic stays off.';

  @override
  String get chatCalls_streamVoiceRoomMessage12 =>
      'Couldn\'t load the authorized voice room. No other room is joined and no demo data is shown instead.';

  @override
  String get chatCalls_streamVoiceRoomMessage13 =>
      'This session doesn\'t have an authorized voice room yet. Enter from a community\'s voice room.';

  @override
  String get chatCalls_streamVoiceRoomMessage14 =>
      'The voice room is authorized, but the voice client for this account has expired. Re-authorize the session.';

  @override
  String get chatCalls_streamVoiceRoomMessage15 =>
      'Voice room authorized. You always join muted, and voice continues in the background.';

  @override
  String get chatCalls_streamVoiceRoomMessage16 =>
      'No local audio is published while connecting.';

  @override
  String get chatCalls_streamVoiceRoomMessage17 =>
      'Mic access is only requested after you tap Speak.';

  @override
  String get chatCalls_streamVoiceRoomMessage18 =>
      'Voice continues when you switch apps or lock the screen; only Leave disconnects.';

  @override
  String get chatCalls_streamVoiceRoomMessage2 =>
      'You\'re still in the room and will reconnect automatically when the network is back. Use Leave below to exit.';

  @override
  String get chatCalls_streamVoiceRoomMessage3 =>
      'Reloading this room and getting a new voice identity, then reconnecting.';

  @override
  String chatCalls_streamVoiceRoomMessage4(Object? joinError) {
    return '${joinError}You\'re still in this room and haven\'t been removed.';
  }

  @override
  String get chatCalls_streamVoiceRoomMessage5 =>
      'This call disconnected. LOOP still lists you as a member of this room.';

  @override
  String get chatCalls_streamVoiceRoomMessage6 =>
      'Joined the room, connecting voice. You joined muted as a listener.';

  @override
  String get chatCalls_streamVoiceRoomMessage7 =>
      'Voice only starts in a verified sign-in session; offline or unverified sessions don\'t connect.';

  @override
  String get chatCalls_streamVoiceRoomMessage8 =>
      'Can\'t connect again until the last call has turned off the mic and left.';

  @override
  String get chatCalls_streamVoiceRoomMessage9 =>
      'The last call didn\'t confirm leaving. Retry cleanup first, then connect voice.';

  @override
  String get chatCalls_streamVoiceRoomNetwork =>
      'This connection didn\'t go through. Check your network and retry.';

  @override
  String get chatCalls_streamVoiceRoomPermission =>
      'Listening isn\'t open in this room yet. Ask the host to reopen it.';

  @override
  String get chatCalls_streamVoiceRoomRoomUnavailable =>
      'This room can\'t be joined anymore. Check the community to see if it\'s still live.';

  @override
  String get chatCalls_streamVoiceRoomSession =>
      'This voice identity has expired. Leave this page and come back.';

  @override
  String chatCalls_streamVoiceRoomSpeaker(Object? speakLabel) {
    return 'You\'re a speaker and also join muted; mic access is only requested when you tap $speakLabel. Voice isn\'t connected but you\'re still in the room; tap Leave below to exit.';
  }

  @override
  String get chatCalls_streamVoiceRoomSwitch =>
      'This device couldn\'t set up a voice session. It stays disconnected and no call is created.';

  @override
  String get chatCalls_streamVoiceRoomSwitch2 =>
      'You joined muted as a listener and mic access isn\'t requested. Voice isn\'t connected but you\'re still in the room; tap Leave below to exit.';

  @override
  String get chatCalls_streamVoiceRoomTitle => 'Leaving voice room…';

  @override
  String get chatCalls_streamVoiceRoomTitle10 => 'Loading voice room';

  @override
  String get chatCalls_streamVoiceRoomTitle11 => 'Couldn\'t load voice room';

  @override
  String get chatCalls_streamVoiceRoomTitle12 => 'No voice room yet';

  @override
  String get chatCalls_streamVoiceRoomTitle13 => 'Voice client unavailable';

  @override
  String get chatCalls_streamVoiceRoomTitle14 => 'Connection failed';

  @override
  String get chatCalls_streamVoiceRoomTitle15 => 'Voice ready to connect';

  @override
  String get chatCalls_streamVoiceRoomTitle16 => 'Muted on entry';

  @override
  String get chatCalls_streamVoiceRoomTitle17 => 'Mic access on demand';

  @override
  String get chatCalls_streamVoiceRoomTitle18 => 'Continues in background';

  @override
  String get chatCalls_streamVoiceRoomTitle2 => 'Voice dropped, reconnecting';

  @override
  String get chatCalls_streamVoiceRoomTitle3 =>
      'Joined, voice connection failed';

  @override
  String get chatCalls_streamVoiceRoomTitle4 => 'Connecting voice…';

  @override
  String get chatCalls_streamVoiceRoomTitle5 => 'Sign-in verification required';

  @override
  String get chatCalls_streamVoiceRoomTitle6 =>
      'Confirming the last call ended';

  @override
  String get chatCalls_streamVoiceRoomTitle7 =>
      'The last call didn\'t end cleanly';

  @override
  String get chatCalls_streamVoiceRoomTitle8 => 'Preparing voice connection';

  @override
  String get chatCalls_streamVoiceRoomTitle9 =>
      'Voice session unavailable right now';

  @override
  String get chatCalls_streamVoiceRoomUnknown =>
      'Couldn\'t connect to this voice room. Try again later.';

  @override
  String get chatCalls_streamVoiceRoomVoiceroomMediaJoinLabel =>
      'Connecting muted';

  @override
  String get chatCalls_streamVoiceRoomVoiceroomMediaJoinLabel2 =>
      'Connect voice';

  @override
  String get chatCalls_streamVoiceRoomVoiceroomMediaReconnectLabel =>
      'Reconnect voice';

  @override
  String chatCalls_streamVoiceRoomVoiceroomMediaRestoredMessage(
    Object? vVoiceMediaPresentation,
  ) {
    return 'Your mic was on when the network dropped. It stays muted after reconnecting; tap $vVoiceMediaPresentation when you need it.';
  }

  @override
  String get chatCalls_streamVoiceRoomVoiceroomMediaRetryCleanupLabel =>
      'Retry cleanup';

  @override
  String get chatCalls_streamVoiceRoomVoiceroomMediaRetrySessionLabel =>
      'Retry session';

  @override
  String get chatCalls_streamVoiceRoomVoiceroomMediaRetryTargetLabel =>
      'Reload voice room';

  @override
  String get chatFriends_createMenuButtonChatCreateMenuLabel => 'New';

  @override
  String get chatFriends_createMenuButtonChatCreateMenuLabel2 => 'Add';

  @override
  String get chatFriends_createMenuButtonSubtitle =>
      'Find people by LOOP ID or nickname and send a message request';

  @override
  String get chatFriends_createMenuButtonSubtitle2 =>
      'Apply to list; goes live after review';

  @override
  String get chatFriends_createMenuButtonSubtitle3 =>
      'Start a small group with friends';

  @override
  String get chatFriends_createMenuButtonSubtitle4 =>
      'Scan a profile card, community code or wallet address';

  @override
  String get chatFriends_createMenuButtonTitle => 'Search / add users';

  @override
  String get chatFriends_createMenuButtonTitle2 => 'Create community';

  @override
  String get chatFriends_createMenuButtonTitle3 => 'Create group chat';

  @override
  String get chatFriends_screensAlreadyDecided =>
      'This friend request was already handled. Refresh the list.';

  @override
  String get chatFriends_screensAlreadyFriends => 'You\'re already friends.';

  @override
  String chatFriends_screensBody(Object? name, num receipt) {
    String _temp0 = intl.Intl.pluralLogic(
      receipt,
      locale: localeName,
      other: '$receipt members',
      one: '1 member',
    );
    return '$name · $_temp0. This result exists only in this run; no Stream channel was created.';
  }

  @override
  String chatFriends_screensBody2(Object? name, num receipt) {
    String _temp0 = intl.Intl.pluralLogic(
      receipt,
      locale: localeName,
      other: '$receipt members',
      one: '1 member',
    );
    return '$name · $_temp0. The channel was created and authorized by the LOOP backend.';
  }

  @override
  String get chatFriends_screensConflict =>
      'The friendship changed. Refresh and try again.';

  @override
  String get chatFriends_screensCooldown =>
      'This friend request is cooling down. Try again later.';

  @override
  String get chatFriends_screensCursorInvalid =>
      'The list page expired; reload from the first page.';

  @override
  String get chatFriends_screensFriendGroupCreateAnotherLabel =>
      'Create another';

  @override
  String chatFriends_screensFriendGroupCreateFailureBody(
    Object? friendFailureMessage,
  ) {
    return '$friendFailureMessage The draft is frozen and won\'t be resubmitted automatically.';
  }

  @override
  String get chatFriends_screensFriendGroupCreateFailureTitle =>
      'Group creation needs manual review';

  @override
  String get chatFriends_screensFriendGroupCreateFailureTitle2 =>
      'Group creation result pending';

  @override
  String get chatFriends_screensFriendGroupCreateFailureTitle3 =>
      'Group not created';

  @override
  String get chatFriends_screensFriendGroupCreateScreenTitle => 'Create group';

  @override
  String get chatFriends_screensFriendGroupCreateSubmitLabel => 'Creating…';

  @override
  String get chatFriends_screensFriendGroupFindFriendsLabel => 'Add friends';

  @override
  String get chatFriends_screensFriendGroupFolioCaption =>
      'Pick from accepted friends. The LOOP backend creates the group; it only appears in Chat once that succeeds.';

  @override
  String get chatFriends_screensFriendGroupFolioKicker => 'Group with friends';

  @override
  String get chatFriends_screensFriendGroupFolioStamp => 'Friends only';

  @override
  String get chatFriends_screensFriendGroupFriendsEmptyMessage =>
      'You can invite someone to a group after they accept your friend request.';

  @override
  String get chatFriends_screensFriendGroupFriendsEmptyTitle =>
      'No friends to choose';

  @override
  String get chatFriends_screensFriendGroupFriendsFailureTitle =>
      'Couldn\'t load friends right now';

  @override
  String get chatFriends_screensFriendGroupNameFieldFootnote =>
      'Up to 60 characters';

  @override
  String get chatFriends_screensFriendGroupNameFieldLabel => 'Group name';

  @override
  String get chatFriends_screensFriendGroupOpenChannelLabel =>
      'Open group chat';

  @override
  String get chatFriends_screensFriendGroupReconcileLabel => 'Check result';

  @override
  String get chatFriends_screensFriendGroupResumeEditingLabel => 'Edit draft';

  @override
  String chatFriends_screensFriendGroupSelectionLabel(
    Object? groupMaximumSelectedFriends,
    Object? selectedFriendRefs,
  ) {
    return 'Choose friends · $selectedFriendRefs/$groupMaximumSelectedFriends';
  }

  @override
  String get chatFriends_screensFriendGroupSetAliasLabel =>
      'Set group nickname';

  @override
  String get chatFriends_screensFriendGroupUnavailableMessage =>
      'No group is created and no members are added here.';

  @override
  String get chatFriends_screensFriendGroupUnavailableTitle =>
      'Group chat creation isn\'t available yet';

  @override
  String get chatFriends_screensFriendPreviewBannerBody =>
      'Friends, requests and new groups are kept in memory only and aren\'t written to the LOOP backend or Stream.';

  @override
  String get chatFriends_screensFriendPreviewBannerTitle =>
      'Development preview · This run only';

  @override
  String get chatFriends_screensIncomingRequestPending =>
      'They\'ve already sent you a request. Handle it in friend requests.';

  @override
  String get chatFriends_screensInvalidData =>
      'The input or server data doesn\'t meet current safety constraints.';

  @override
  String get chatFriends_screensLoopLabel => 'Result';

  @override
  String get chatFriends_screensNotFound =>
      'The target isn\'t available right now. Hidden and nonexistent accounts aren\'t distinguished.';

  @override
  String get chatFriends_screensNotSelected => 'Not selected';

  @override
  String get chatFriends_screensOperatorRequired =>
      'The channel needs manual review; a second channel won\'t be created automatically.';

  @override
  String get chatFriends_screensOutcomeUnknown =>
      'The request may have been received, but the final result can\'t be safely confirmed right now.';

  @override
  String get chatFriends_screensOutgoingRequestPending =>
      'Friend request sent, waiting for them to respond.';

  @override
  String get chatFriends_screensPermissionDenied =>
      'This account can\'t do that. No friendship or group was changed.';

  @override
  String get chatFriends_screensProfileRequired =>
      'Set your LOOP nickname in Profile first.';

  @override
  String get chatFriends_screensRateLimited =>
      'Too many attempts. Try again later.';

  @override
  String get chatFriends_screensSelected => 'Selected';

  @override
  String get chatFriends_screensSwitch =>
      'Couldn\'t complete the action right now.';

  @override
  String chatFriends_screensText(num groupMinimumSelectedFriends) {
    String _temp0 = intl.Intl.pluralLogic(
      groupMinimumSelectedFriends,
      locale: localeName,
      other: 'Choose at least $groupMinimumSelectedFriends friends',
      one: 'Choose at least 1 friend',
    );
    return '$_temp0';
  }

  @override
  String get chatFriends_screensTitle => 'Development preview group created';

  @override
  String get chatFriends_screensTitle2 => 'Group created';

  @override
  String get chatFriends_screensUnavailable =>
      'The friend service isn\'t available right now. No friendship or group was changed.';

  @override
  String get chatFriends_screensUnexpected =>
      'The service couldn\'t complete the request; no friendship or group was changed.';

  @override
  String get chatGroupAlias_neutralMember => 'Member';

  @override
  String get chatGroupAlias_screenBody =>
      'Your nickname is reserved; the group display is still syncing. Retry with the exact same nickname.';

  @override
  String get chatGroupAlias_screenBody2 =>
      'This nickname is permanently reserved in this group and can\'t be changed. It doesn\'t reveal your public profile or Stream user identity.';

  @override
  String get chatGroupAlias_screenGroupAliasBlockedTitle =>
      'Can\'t set group nickname';

  @override
  String get chatGroupAlias_screenGroupAliasBoundaryBody =>
      'Your group nickname only shows in this group and isn\'t linked to your public profile or wallet address.';

  @override
  String get chatGroupAlias_screenGroupAliasChannelInvalidMessage =>
      'This page didn\'t get a valid Stream group chat reference; no network request was made.';

  @override
  String get chatGroupAlias_screenGroupAliasChannelInvalidTitle =>
      'Invalid group chat reference';

  @override
  String get chatGroupAlias_screenGroupAliasFailureTitle =>
      'Group nickname not reserved';

  @override
  String get chatGroupAlias_screenGroupAliasFieldFootnote =>
      'Can\'t be changed after submitting; nicknames must be unique in a group.';

  @override
  String get chatGroupAlias_screenGroupAliasFieldLabel => 'Group nickname';

  @override
  String get chatGroupAlias_screenGroupAliasFolioCaption =>
      'You can use a different nickname in each group. It\'s permanent once reserved; the app doesn\'t link identities across groups, but this isn\'t a guarantee of anonymity.';

  @override
  String get chatGroupAlias_screenGroupAliasFolioKicker => 'Group nickname';

  @override
  String chatGroupAlias_screenGroupAliasOutcomeUnknownBody(
    Object? pendingAlias,
  ) {
    return '\"$pendingAlias\" may already be permanently reserved. To avoid locking a different value, you can only retry the exact same nickname.';
  }

  @override
  String get chatGroupAlias_screenGroupAliasOutcomeUnknownTitle =>
      'Reservation result pending';

  @override
  String get chatGroupAlias_screenGroupAliasPausedMessage =>
      'Group members show with their own avatar and username. No request was made here.';

  @override
  String get chatGroupAlias_screenGroupAliasPausedTitle =>
      'Group nicknames aren\'t available yet';

  @override
  String get chatGroupAlias_screenGroupAliasReloadLabel => 'Reload';

  @override
  String get chatGroupAlias_screenGroupAliasResolverRetryLabel => 'Retry check';

  @override
  String get chatGroupAlias_screenGroupAliasRetryPendingLabel =>
      'Retry with same nickname';

  @override
  String get chatGroupAlias_screenGroupAliasRetryProjectionLabel =>
      'Retry sync';

  @override
  String get chatGroupAlias_screenGroupAliasRouteInvalidMessage =>
      'This page didn\'t get a valid LOOP group_id; no network request was made.';

  @override
  String get chatGroupAlias_screenGroupAliasRouteInvalidTitle =>
      'Invalid group reference';

  @override
  String get chatGroupAlias_screenGroupAliasSearchEmptyMessage =>
      'Members still syncing, members who left, and you won\'t appear in results.';

  @override
  String get chatGroupAlias_screenGroupAliasSearchEmptyTitle =>
      'No matching nicknames';

  @override
  String chatGroupAlias_screenGroupAliasSearchFailureMessage(
    Object? groupAliasFailureMessage,
  ) {
    return 'Couldn\'t search the group: $groupAliasFailureMessage';
  }

  @override
  String get chatGroupAlias_screenGroupAliasSearchFieldFootnote =>
      'Enter at least 2 characters';

  @override
  String get chatGroupAlias_screenGroupAliasSearchSubmitLabel => 'Searching';

  @override
  String get chatGroupAlias_screenGroupAliasSearchSubmitLabel2 => 'Search';

  @override
  String get chatGroupAlias_screenGroupAliasSearchSubmitSemanticLabel =>
      'Search group nicknames';

  @override
  String get chatGroupAlias_screenGroupAliasSearchTruncatedBody =>
      'Keep typing a fuller nickname to narrow results.';

  @override
  String get chatGroupAlias_screenGroupAliasSearchTruncatedTitle =>
      'Results truncated';

  @override
  String get chatGroupAlias_screenGroupAliasSubmitLabel => 'Reserving…';

  @override
  String get chatGroupAlias_screenGroupAliasSubmitLabel2 =>
      'Reserve this nickname permanently';

  @override
  String get chatGroupAlias_screenGroupAliasTitle => 'Group nicknames';

  @override
  String get chatGroupAlias_screenGroupAliasUnavailableMessage =>
      'No demo nickname is shown, and your account nickname or wallet address isn\'t used as your group identity.';

  @override
  String get chatGroupAlias_screenGroupAliasUnavailableTitle =>
      'Group nickname service unavailable';

  @override
  String get chatGroupAlias_screenHint => '1–40 characters';

  @override
  String get chatGroupAlias_screenHint2 => 'Enter a nickname to search';

  @override
  String get chatGroupAlias_screenImmutable =>
      'This account already reserved a different nickname in this group; it can\'t be changed.';

  @override
  String get chatGroupAlias_screenInvalidData =>
      'This nickname isn\'t available. Try another.';

  @override
  String get chatGroupAlias_screenLoopBadge => 'Syncing';

  @override
  String get chatGroupAlias_screenLoopLabel => 'My group nickname';

  @override
  String get chatGroupAlias_screenLoopLabel2 => 'Find member nicknames';

  @override
  String get chatGroupAlias_screenNotFound => 'Group unavailable';

  @override
  String get chatGroupAlias_screenNotFound2 =>
      'This channel isn\'t a visible group, or this account is no longer a member; nickname actions aren\'t available.';

  @override
  String get chatGroupAlias_screenNotFound3 =>
      'No visible group nickname; you may no longer be a member of this Stream group.';

  @override
  String get chatGroupAlias_screenOffline =>
      'Device offline. Group nicknames weren\'t loaded and nothing was submitted.';

  @override
  String get chatGroupAlias_screenOutcomeUnknown =>
      'The request may have been submitted; you can only confirm with the exact same nickname.';

  @override
  String get chatGroupAlias_screenPreview =>
      'Development preview · This run only';

  @override
  String get chatGroupAlias_screenProduction => 'This group only';

  @override
  String get chatGroupAlias_screenProduction2 => 'LOOP group identity boundary';

  @override
  String get chatGroupAlias_screenResolved => 'Couldn\'t resolve group';

  @override
  String get chatGroupAlias_screenResolved2 =>
      'Couldn\'t load this group\'s info right now; the group nickname can\'t be changed yet.';

  @override
  String get chatGroupAlias_screenResolving => 'Confirming group';

  @override
  String get chatGroupAlias_screenResolving2 =>
      'LOOP is confirming this account is still a member of this Stream group chat.';

  @override
  String get chatGroupAlias_screenS => 'Permanently reserved';

  @override
  String get chatGroupAlias_screenSubtitle => 'Reserved · Syncing in group';

  @override
  String get chatGroupAlias_screenSubtitle2 => 'Current group nickname';

  @override
  String get chatGroupAlias_screenSwitch =>
      'Group nicknames aren\'t available right now.';

  @override
  String get chatGroupAlias_screenTaken =>
      'Another member of this group has permanently reserved this nickname. Try another.';

  @override
  String get chatGroupAlias_screenUnavailable =>
      'Group service unavailable right now';

  @override
  String get chatGroupAlias_screenUnavailable2 =>
      'Couldn\'t confirm group membership right now; nickname actions aren\'t available.';

  @override
  String get chatGroupAlias_screenUnavailable3 => 'Not connected';

  @override
  String get chatGroupAlias_screenUnavailable4 =>
      'Production connection unavailable';

  @override
  String get chatGroupAlias_screenUnavailable5 =>
      'The group nickname service isn\'t available right now; no nickname is shown as reserved.';

  @override
  String get chatGroupAlias_screenUnexpected =>
      'The group nickname action failed; no result is shown as confirmed.';

  @override
  String chatGroupAlias_streamMessageIdentityBuild(num replyCount) {
    String _temp0 = intl.Intl.pluralLogic(
      replyCount,
      locale: localeName,
      other: '$replyCount replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String get chatGroupAlias_streamMessageIdentityLoopChannelQuietLabel =>
      'No one has spoken yet';

  @override
  String
  get chatGroupAlias_streamMessageIdentityLoopDirectConversationNeutralInitial =>
      'D';

  @override
  String
  get chatGroupAlias_streamMessageIdentityLoopDirectDeactivatedPeerInitial =>
      'X';

  @override
  String
  get chatGroupAlias_streamMessageIdentityLoopDirectDeactivatedPeerLabel =>
      'Deleted account';

  @override
  String chatGroupAlias_streamMessageIdentityS(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String chatMemberBuy_cardBody(Object? loopMemberBuyPreviewLabel) {
    return '$loopMemberBuyPreviewLabel · Incomplete data';
  }

  @override
  String chatMemberBuy_cardLabel(Object? name) {
    return 'View $name\'s profile';
  }

  @override
  String get chatMemberBuy_cardLabel2 => 'Copy transaction hash';

  @override
  String get chatMemberBuy_cardMessage => 'Transaction hash copied';

  @override
  String get chatMemberBuy_cardText => 'Bought ';

  @override
  String chatMemberBuy_eventIf(Object? formatDecimal) {
    return '$formatDecimal × 10,000';
  }

  @override
  String chatMemberBuy_eventIf2(Object? formatDecimal) {
    return '$formatDecimal × 100,000,000';
  }

  @override
  String get chatMemberBuy_eventLoopMemberBuyNeutralBuyer => 'Member';

  @override
  String get chatMemberBuy_eventLoopMemberBuyNeutralInitial => 'M';

  @override
  String get chatMemberBuy_eventLoopMemberBuyPreviewLabel => 'Member bought';

  @override
  String chatTokenCard_cardChartRangeLabel(Object? loopSparklineWindow) {
    return '1H · Last $loopSparklineWindow closes';
  }

  @override
  String get chatTokenCard_cardDetail =>
      'This contract address isn\'t in the LOOP asset catalog, so there\'s no market data.';

  @override
  String chatTokenCard_cardDetail2(Object? chatTokenShortAddress) {
    return 'LOOP timed out · $chatTokenShortAddress';
  }

  @override
  String chatTokenCard_cardDetail3(Object? chatTokenShortAddress) {
    return 'Couldn\'t read this contract · $chatTokenShortAddress';
  }

  @override
  String get chatTokenCard_cardLoopChatTokenCardFailedMessage =>
      'Couldn\'t load. Tap to retry';

  @override
  String get chatTokenCard_cardLoopChatTokenCardKicker => 'Token detected';

  @override
  String get chatTokenCard_cardLoopTokenCardAction => 'Token page';

  @override
  String get chatTokenCard_cardLoopTokenMetric => 'Not listed';

  @override
  String chatTokenCard_cardMarketCommunityBound(
    Object? formatCompactFigure,
    Object? name,
  ) {
    return 'LOOP community $name · $formatCompactFigure members';
  }

  @override
  String get chatTokenCard_cardMarketCommunityUnavailable =>
      'No LOOP community';

  @override
  String chatTokenCard_cardMessage(Object? chatTokenShortAddress) {
    return 'Unlisted token · $chatTokenShortAddress';
  }

  @override
  String get chatTokenCard_cardMessage2 => 'Device offline; contract not read';

  @override
  String get chatTokenCard_cardPriceReason => 'No quote received';

  @override
  String chatTokenCard_cardReadCard(Object? label) {
    return 'Catalog status · $label';
  }

  @override
  String chatTokenCard_cardReadCard2(Object? riskFactCount) {
    return '$riskFactCount more contract facts on the token page';
  }

  @override
  String chatTokenCard_cardReadCard3(Object? tradeReason) {
    return 'Buy and sell unavailable · $tradeReason';
  }

  @override
  String chatTokenCard_cardReadCard4(Object? factSourceLabel) {
    return 'Identity from $factSourceLabel';
  }

  @override
  String chatTokenCard_cardReadCard5(Object? relativeTime) {
    return 'Observed $relativeTime';
  }

  @override
  String chatTokenCard_cardReadCard6(Object? factProvenance) {
    return 'Quote $factProvenance';
  }

  @override
  String get chatTokenCard_viewLoading => 'Detecting';

  @override
  String chatTokenCard_viewLoopTokenCardProvenanceSemanticsLabel(
    Object? provenance,
  ) {
    return '$provenance, view data source';
  }

  @override
  String get chatTokenCard_viewPartial => 'Data missing';

  @override
  String get chatTokenCard_viewRisk => 'Risk facts';

  @override
  String get chatTokenCard_viewSwitch => 'Detecting…';

  @override
  String chatTokenCard_viewText(Object? observedLabel, Object? source) {
    return ' — source $source, observed $observedLabel';
  }

  @override
  String chatV2_channelHeadingNull(num memberCount) {
    String _temp0 = intl.Intl.pluralLogic(
      memberCount,
      locale: localeName,
      other: '$memberCount members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get chatV2_communityCommunityChatNeutralTitle =>
      'Community group chat';

  @override
  String get chatV2_communityCommunityChatOpenProfileLabel => 'Community info';

  @override
  String get chatV2_communityCommunityChatOpenSearchLabel =>
      'Search this conversation';

  @override
  String get chatV2_communityCommunityChatOpenVoiceLabel => 'Join voice room';

  @override
  String get chatV2_communityCommunityChatPersonaSegment =>
      'Syncing your display name';

  @override
  String chatV2_communityCommunityChatSyncingBody(
    Object? communicationUnavailableReason,
  ) {
    return '${communicationUnavailableReason}LOOP has recorded your membership; the provider hasn\'t caught up yet. Retry later; you don\'t need to rejoin the community.';
  }

  @override
  String get chatV2_communityCommunityChatSyncingRetryLabel => 'Check again';

  @override
  String get chatV2_communityCommunityChatSyncingTitle => 'Syncing chat access';

  @override
  String chatV2_communityCommunityOnlineCountObserved(Object? count) {
    return '$count online';
  }

  @override
  String get chatV2_communityEmptyMessage => 'Community not found';

  @override
  String get chatV2_communityEmptyReason =>
      'It may have been removed or isn\'t visible to this account.';

  @override
  String get chatV2_communityMessage => 'Missing community ID';

  @override
  String get chatV2_communityMessage2 => 'Community chat unavailable';

  @override
  String get chatV2_communityMessage3 => 'Official group unavailable';

  @override
  String get chatV2_communityReason =>
      'Enter from the community list or community page; this page won\'t guess which community\'s official group to open.';

  @override
  String get chatV2_communityReason2 =>
      'Capabilities haven\'t loaded yet; this page doesn\'t request any channel.';

  @override
  String chatV2_communityS(Object? alias) {
    return 'You appear as $alias in this community';
  }

  @override
  String chatV2_communitySwitch(Object? communityCountLabel) {
    return '$communityCountLabel members';
  }

  @override
  String get chatV2_conversationLabelLoopCommunityConversationNeutralLabel =>
      'Community official group';

  @override
  String chatV2_conversationLabelNull(num memberCount) {
    String _temp0 = intl.Intl.pluralLogic(
      memberCount,
      locale: localeName,
      other: '$memberCount members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get chatV2_directMessageCaption =>
      'Direct messages show minimal identity by default; asset and signature requests are labelled separately.';

  @override
  String get chatV2_directMessageDmFriendshipRequiredMessage =>
      'Message request sent. The conversation appears here once they accept.';

  @override
  String get chatV2_directMessageDmFriendshipRequiredMessage2 =>
      'Direct messages need both of you to be friends, and the other person mustn\'t have turned off direct messages in Privacy Center. Send a message request first; the conversation opens once they accept. This doesn\'t mean the account exists.';

  @override
  String get chatV2_directMessageDmFriendshipRequiredTitle =>
      'Can\'t message directly yet';

  @override
  String get chatV2_directMessageDmMessageRequestFailedTitle =>
      'Message request not sent';

  @override
  String get chatV2_directMessageDmOperatorRequiredDetail =>
      'This request was received and needs manual handling to finish. There\'s no retry here: resubmitting opens a second action. Contact support, then come back to this conversation.';

  @override
  String get chatV2_directMessageDmOperatorRequiredMessage =>
      'Needs manual handling';

  @override
  String get chatV2_directMessageDmOperatorRequiredNoticeBody =>
      'This request is recorded. Sending it again won\'t be faster; it only adds another pending record.';

  @override
  String get chatV2_directMessageDmOperatorRequiredNoticeTitle =>
      'Don\'t resubmit';

  @override
  String get chatV2_directMessageDmSendMessageRequestLabel =>
      'Send message request';

  @override
  String get chatV2_directMessageDmSendMessageRequestLabel2 =>
      'Resend message request';

  @override
  String get chatV2_directMessageEmptyMessage =>
      'This direct message isn\'t open yet';

  @override
  String get chatV2_directMessageEmptyReason =>
      'This conversation can\'t be opened right now.';

  @override
  String get chatV2_directMessageHeading => 'One-on-one direct message';

  @override
  String chatV2_directMessageHeading2(Object? displayName) {
    return 'Direct message with $displayName';
  }

  @override
  String get chatV2_directMessageMessage => 'Direct messages unavailable';

  @override
  String get chatV2_directMessageMessage2 => 'Missing conversation ID';

  @override
  String get chatV2_directMessageMessage3 => 'Message request sent';

  @override
  String get chatV2_directMessageNotFound =>
      'They aren\'t discoverable, or this account doesn\'t exist. The message request wasn\'t sent.';

  @override
  String get chatV2_directMessageReason =>
      'Enter from Following, Message requests or a public profile; this page won\'t guess whose direct message to open.';

  @override
  String get chatV2_directMessageStamp => 'Private';

  @override
  String get chatV2_forwardScreensBody =>
      'Selected messages are sent as new messages labelled with their source conversation. Deleted or empty messages are skipped.';

  @override
  String chatV2_forwardScreensCaption(Object? chatForwardSelectionLimit) {
    return 'Forward up to $chatForwardSelectionLimit messages at a time, only to conversations you\'ve joined. Deleted or empty messages are skipped and counted.';
  }

  @override
  String chatV2_forwardScreensCaption2(Object? chatMergeAnonymousLabel) {
    return 'The merged preview only shows \"$chatMergeAnonymousLabel\", time and text, with no nickname, LOOP ID or wallet address.';
  }

  @override
  String get chatV2_forwardScreensChatForwardErrorReason =>
      'Couldn\'t load this conversation\'s messages and targets; nothing was forwarded.';

  @override
  String get chatV2_forwardScreensChatForwardMissingSourceDetail =>
      'Enter Forward from a conversation; this page won\'t guess which conversation to forward from.';

  @override
  String get chatV2_forwardScreensChatForwardMissingSourceMessage =>
      'Source conversation not found';

  @override
  String get chatV2_forwardScreensChatForwardNoMessagesMessage =>
      'Only text messages synced to this device can be forwarded.';

  @override
  String get chatV2_forwardScreensChatForwardNoMessagesTitle =>
      'No messages to forward in this conversation';

  @override
  String get chatV2_forwardScreensChatForwardNoTargetsMessage =>
      'Forward targets must be conversations you\'ve joined.';

  @override
  String get chatV2_forwardScreensChatForwardNoTargetsTitle =>
      'No target conversations';

  @override
  String get chatV2_forwardScreensChatForwardOpenMergeLabel =>
      'Preview merged image';

  @override
  String chatV2_forwardScreensChatForwardScreenSubtitle(Object? selectedCount) {
    return '$selectedCount selected · Choose a conversation';
  }

  @override
  String get chatV2_forwardScreensChatForwardScreenTitle => 'Forward messages';

  @override
  String get chatV2_forwardScreensChatMergeAnonymousLabel => 'Anonymous member';

  @override
  String get chatV2_forwardScreensChatMergeBackLabel => 'Back to chat';

  @override
  String chatV2_forwardScreensChatMergeEmptyMessage(
    Object? chatMergeSelectionLimit,
  ) {
    return 'Go back to Forward and pick up to $chatMergeSelectionLimit messages to merge.';
  }

  @override
  String get chatV2_forwardScreensChatMergeEmptyTitle => 'No messages selected';

  @override
  String get chatV2_forwardScreensChatMergeExportLabel => 'Create image';

  @override
  String get chatV2_forwardScreensChatMergePreviewScreenSubtitle =>
      'Show sender usernames';

  @override
  String get chatV2_forwardScreensChatMergePreviewScreenSubtitle2 =>
      'Anonymous by default';

  @override
  String get chatV2_forwardScreensChatMergePreviewScreenTitle =>
      'Merged image preview';

  @override
  String chatV2_forwardScreensChatMergeTruncatedBody(
    Object? chatMergeSelectionLimit,
  ) {
    return 'Merge up to $chatMergeSelectionLimit messages at a time; the rest won\'t appear in the preview.';
  }

  @override
  String get chatV2_forwardScreensChatMergeTruncatedTitle => 'Truncated';

  @override
  String get chatV2_forwardScreensEncode => 'Selected conversation';

  @override
  String get chatV2_forwardScreensEncode2 => 'Community signal summary';

  @override
  String get chatV2_forwardScreensHeading => '0 items';

  @override
  String get chatV2_forwardScreensKicker => 'Selected messages';

  @override
  String get chatV2_forwardScreensLoopBadge => 'Selected';

  @override
  String chatV2_forwardScreensLoopFolioPrimary(Object? count, Object? source) {
    return '$source · $count';
  }

  @override
  String chatV2_forwardScreensLoopFolioPrimary2(Object? count) {
    return '$count selected';
  }

  @override
  String get chatV2_forwardScreensLoopLabel => 'Select messages';

  @override
  String chatV2_forwardScreensLoopLabel2(Object? chatForwardTargetPageSize) {
    return 'Send to · Last $chatForwardTargetPageSize conversations';
  }

  @override
  String get chatV2_forwardScreensLoopOfflineState => 'Load messages';

  @override
  String get chatV2_forwardScreensLoopOfflineState2 => 'Choose target';

  @override
  String get chatV2_forwardScreensLoopOfflineState3 => 'Forward';

  @override
  String chatV2_forwardScreensMessage(Object? chatForwardSelectionLimit) {
    return 'Select up to $chatForwardSelectionLimit at a time';
  }

  @override
  String get chatV2_forwardScreensMessage2 => 'Nothing forwarded';

  @override
  String chatV2_forwardScreensMessage3(Object? sent) {
    return 'Forwarded $sent';
  }

  @override
  String chatV2_forwardScreensMessage4(Object? sent, Object? skipped) {
    return 'Forwarded $sent, skipped $skipped';
  }

  @override
  String chatV2_forwardScreensS(Object? sourceLabel) {
    return '$sourceLabel · Selected conversation';
  }

  @override
  String chatV2_forwardScreensStamp(Object? selectedCount) {
    return 'Selected $selectedCount';
  }

  @override
  String get chatV2_forwardScreensStamp2 => 'Anonymous';

  @override
  String get chatV2_forwardScreensSubtitle =>
      'Deleted or empty; skipped when forwarding.';

  @override
  String get chatV2_forwardScreensText => 'Output';

  @override
  String get chatV2_forwardScreensText2 =>
      'Wallet addresses, nicknames and internal IDs don\'t appear in the image, and the image isn\'t uploaded.';

  @override
  String get chatV2_forwardScreensTitle => 'This message can\'t be forwarded';

  @override
  String get chatV2_forwardScreensTitle2 => 'Forward to this conversation?';

  @override
  String get chatV2_forwardTargetSheetBarrierLabel => 'Close forward';

  @override
  String get chatV2_forwardTargetSheetChatForwardOutcomeMessage => 'Forwarded';

  @override
  String chatV2_forwardTargetSheetChatForwardOutcomeMessage2(Object? skipped) {
    return 'Skipped $skipped';
  }

  @override
  String chatV2_forwardTargetSheetChatForwardOutcomeMessage3(
    Object? unavailable,
  ) {
    return '$unavailable deleted or not on this device; not forwarded';
  }

  @override
  String chatV2_forwardTargetSheetContent(Object? chatForwardTargetPageSize) {
    return 'Last $chatForwardTargetPageSize joined conversations · Forwarded messages show their source';
  }

  @override
  String get chatV2_forwardTargetSheetForwardTargetSheetErrorReason =>
      'Couldn\'t load conversations to forward to; nothing was forwarded.';

  @override
  String get chatV2_forwardTargetSheetLoopOfflineState => 'Load conversations';

  @override
  String get chatV2_forwardTargetSheetLoopSheetHeading => 'Forward to';

  @override
  String chatV2_forwardTargetSheetS(Object? count) {
    return 'Forward $count one by one to';
  }

  @override
  String get chatV2_groupScreensBarrierLabel => 'Close group name editor';

  @override
  String get chatV2_groupScreensBody =>
      'You won\'t get messages from this group after leaving. The group creator can\'t leave.';

  @override
  String get chatV2_groupScreensCaption =>
      'Members, notifications and Leave are ordered from low to high risk. Only confirmed info is shown here.';

  @override
  String get chatV2_groupScreensErrorText =>
      'Group name must be 1–40 characters with no control characters';

  @override
  String get chatV2_groupScreensGroupInfoCapabilityUnavailableDetail =>
      'Capabilities haven\'t loaded yet; this page doesn\'t request any group resource.';

  @override
  String get chatV2_groupScreensGroupInfoMembersUnavailableLabel =>
      'Members and member management';

  @override
  String get chatV2_groupScreensGroupInfoMissingCidDetail =>
      'Enter from a group chat; this page won\'t guess which group\'s info to open.';

  @override
  String get chatV2_groupScreensGroupInfoNameSubtitle => 'Loading group name';

  @override
  String get chatV2_groupScreensGroupInfoNameSubtitle2 =>
      'Couldn\'t load group name';

  @override
  String get chatV2_groupScreensGroupInfoNameTitle => 'Group name';

  @override
  String get chatV2_groupScreensGroupInfoNameTrailingCaption => 'Edit';

  @override
  String get chatV2_groupScreensGroupInfoNameTrailingCaption2 => 'Owner only';

  @override
  String get chatV2_groupScreensGroupInfoResolveFailedReason =>
      'This group\'s info isn\'t confirmed yet, so you can\'t leave; no change was submitted.';

  @override
  String get chatV2_groupScreensGroupInfoSettingsUnavailableLabel =>
      'Notifications and pinned conversation';

  @override
  String get chatV2_groupScreensGroupInfoStateEmptyMessage =>
      'This group wasn\'t found, or you\'re no longer a member. This doesn\'t mean leaving failed.';

  @override
  String get chatV2_groupScreensGroupInfoStateEmptyTitle =>
      'No group membership to leave';

  @override
  String get chatV2_groupScreensGroupInfoStateUnavailableDetail =>
      'The group membership service isn\'t available right now; no change was submitted.';

  @override
  String get chatV2_groupScreensGroupInfoStateUnavailableMessage =>
      'Leave isn\'t available right now';

  @override
  String get chatV2_groupScreensGroupOpenInfoLabel => 'Group info';

  @override
  String get chatV2_groupScreensGroupScopeNoteText =>
      'Regular groups have no community token, no Mining Weight and no Community AI. Communities with tokens are under Community.';

  @override
  String get chatV2_groupScreensGroupScopeNoteTitle => 'Groups vs. communities';

  @override
  String get chatV2_groupScreensKicker => 'Group profile';

  @override
  String chatV2_groupScreensLabelText(Object? groupNameMaximumRunes) {
    return 'Group name (1–$groupNameMaximumRunes characters)';
  }

  @override
  String get chatV2_groupScreensLoopOfflineState => 'Leave group chat';

  @override
  String get chatV2_groupScreensLoopSheetHeading => 'Edit group name';

  @override
  String get chatV2_groupScreensMessage => 'Group chat unavailable';

  @override
  String get chatV2_groupScreensMessage2 => 'Missing group chat ID';

  @override
  String chatV2_groupScreensMessage3(Object? name) {
    return 'Group name changed to \"$name\"';
  }

  @override
  String get chatV2_groupScreensMessage4 => 'Left group chat';

  @override
  String get chatV2_groupScreensNotFound =>
      'The group doesn\'t exist or you\'re no longer in it.';

  @override
  String get chatV2_groupScreensPermissionDenied =>
      'Only the group owner can change the group name; nothing was changed.';

  @override
  String get chatV2_groupScreensReason =>
      'Enter from the conversation list or group info; this page won\'t guess which group to open.';

  @override
  String get chatV2_groupScreensTitle => 'Leave this group chat?';

  @override
  String get chatV2_groupScreensUnavailable =>
      'Renaming isn\'t available right now; the group name wasn\'t changed.';

  @override
  String get chatV2_groupScreensValidationFailed =>
      'Group name must be 1–40 characters with no control characters.';

  @override
  String get chatV2_mergeExportDismissed =>
      'Image created, but no share destination was chosen';

  @override
  String get chatV2_mergeExportFailed =>
      'Couldn\'t create the image; nothing left this device';

  @override
  String get chatV2_mergeExportShared =>
      'Image created. Choose where to share it';

  @override
  String get chatV2_mergeExportUnavailable =>
      'System sharing isn\'t available in this run; no image was created';

  @override
  String get chatV2_messageSelectionBody =>
      'Everyone in the conversation will see \"Message deleted\". This can\'t be undone.';

  @override
  String get chatV2_messageSelectionLabel => 'Message selected';

  @override
  String get chatV2_messageSelectionLabel2 => 'Select this message';

  @override
  String get chatV2_messageSelectionLoopMessageForwardActions => 'Select';

  @override
  String get chatV2_messageSelectionLoopSelectionForwardEachLabel =>
      'Forward one by one';

  @override
  String get chatV2_messageSelectionLoopSelectionMergeLabel => 'Forward as one';

  @override
  String chatV2_messageSelectionLoopSelectionTopbarSubtitle(
    Object? loopMessageSelectionLimit,
  ) {
    return 'Up to $loopMessageSelectionLimit';
  }

  @override
  String chatV2_messageSelectionLoopSelectionTopbarTitle(Object? count) {
    return '$count selected';
  }

  @override
  String chatV2_messageSelectionMessage(Object? loopMessageSelectionLimit) {
    return 'Select up to $loopMessageSelectionLimit at a time';
  }

  @override
  String chatV2_messageSelectionMessage2(Object? unavailable) {
    return '$unavailable deleted or not on this device; left out of the image';
  }

  @override
  String chatV2_messageSelectionShow(Object? deleted) {
    return 'Deleted $deleted';
  }

  @override
  String chatV2_messageSelectionShow2(Object? failed) {
    return '$failed couldn\'t be deleted';
  }

  @override
  String chatV2_messageSelectionShow3(Object? unavailable) {
    return '$unavailable no longer on this device; skipped';
  }

  @override
  String chatV2_messageSelectionTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete these $count messages?',
      one: 'Delete this message?',
    );
    return '$_temp0';
  }

  @override
  String get chatV2_modelsHost => 'Host';

  @override
  String get chatV2_modelsInviteSpeaker => 'Invite to speak';

  @override
  String get chatV2_modelsListener => 'Listener';

  @override
  String get chatV2_modelsRemoveSpeaker => 'Remove from stage';

  @override
  String get chatV2_modelsSpeaker => 'Speaker';

  @override
  String get chatV2_modelsSwitch =>
      'Only members with anonymous mode on show as anonymous; discoverability doesn\'t affect this row.';

  @override
  String get chatV2_modelsSwitch10 =>
      'The voice room is still being verified; this page won\'t start any voice connection until it passes.';

  @override
  String get chatV2_modelsSwitch11 =>
      'Couldn\'t load the online count, so no number is shown.';

  @override
  String get chatV2_modelsSwitch12 =>
      'Listening isn\'t open in this room yet. Refresh, or ask the host to reopen it.';

  @override
  String get chatV2_modelsSwitch13 =>
      'This room hasn\'t confirmed listening is open, so you may not hear anything. Refresh, or ask the host to reopen it.';

  @override
  String get chatV2_modelsSwitch14 =>
      'This voice room isn\'t set up on the provider yet, so you can\'t join.';

  @override
  String get chatV2_modelsSwitch15 =>
      'Your raised hand is recorded; the host may see it a bit later.';

  @override
  String get chatV2_modelsSwitch16 =>
      'The provider hasn\'t confirmed this mute yet.';

  @override
  String get chatV2_modelsSwitch17 =>
      'Community AI isn\'t available yet, so this page is unavailable.';

  @override
  String get chatV2_modelsSwitch2 =>
      'This community doesn\'t have an official group channel yet.';

  @override
  String get chatV2_modelsSwitch3 =>
      'Your channel membership is syncing; you can join shortly.';

  @override
  String get chatV2_modelsSwitch4 =>
      'The official group hit the provider\'s member limit, so you can\'t join right now. Your LOOP community membership isn\'t affected.';

  @override
  String get chatV2_modelsSwitch5 =>
      'The official group failed to create or sync and needs ops to fix it before you can join.';

  @override
  String get chatV2_modelsSwitch6 =>
      'Join this community first to enter its official group.';

  @override
  String get chatV2_modelsSwitch7 =>
      'Chat isn\'t available right now. Try again later.';

  @override
  String get chatV2_modelsSwitch8 =>
      'No live voice room in this community right now.';

  @override
  String get chatV2_modelsSwitch9 =>
      'Chat isn\'t available in this environment yet.';

  @override
  String get chatV2_modelsUnmuteSelf => 'Unmute me';

  @override
  String get chatV2_searchChatSearchEmptyMessage =>
      'Try another keyword or a wider scope.';

  @override
  String get chatV2_searchChatSearchEmptyTitle => 'No matching messages';

  @override
  String get chatV2_searchChatSearchErrorReason =>
      'This search didn\'t finish; no results are shown.';

  @override
  String get chatV2_searchChatSearchIdleMessage =>
      'Enter at least 2 characters. Results only come from conversations you\'ve joined.';

  @override
  String get chatV2_searchChatSearchIdleTitle => 'Enter a keyword to search';

  @override
  String get chatV2_searchChatSearchNotConnectedDetail =>
      'Chat search isn\'t available right now; this page made no request.';

  @override
  String get chatV2_searchChatSearchNotConnectedMessage =>
      'Chat search unavailable';

  @override
  String chatV2_searchChatSearchScreenSubtitle(Object? label) {
    return '$label · Not searched yet';
  }

  @override
  String chatV2_searchChatSearchScreenSubtitle2(num hits, Object? label) {
    String _temp0 = intl.Intl.pluralLogic(
      hits,
      locale: localeName,
      other: '$hits results',
      one: '1 result',
    );
    return '$label · $_temp0';
  }

  @override
  String get chatV2_searchChatSearchScreenTitle => 'Search messages';

  @override
  String get chatV2_searchCurrentConversation => 'This conversation';

  @override
  String get chatV2_searchLoopOfflineState => 'Search messages';

  @override
  String get chatV2_streamChannelSurfaceLoopChannelPinnedUnavailableTitle =>
      'Pinned notice';

  @override
  String get chatV2_streamChannelSurfaceLoopChatComposerHint =>
      'Type or paste CA';

  @override
  String get chatV2_streamChannelSurfaceLoopStreamChannelStateBlock =>
      'Open conversation';

  @override
  String get chatV2_streamChannelSurfaceLoopStreamChannelStateBlock2 =>
      'Send message';

  @override
  String get chatV2_streamChannelSurfaceMessage =>
      'This conversation link isn\'t a channel address LOOP supports; no connection was made.';

  @override
  String get chatV2_streamChannelSurfaceMessage2 => 'Restoring chat session…';

  @override
  String get chatV2_streamChannelSurfaceMessage3 =>
      'Device offline. Chat authorization wasn\'t restored and no message was sent.';

  @override
  String get chatV2_streamChannelSurfaceMessage4 =>
      'Couldn\'t restore chat authorization; no message action was taken.';

  @override
  String get chatV2_streamChannelSurfaceMessage5 =>
      'Confirming this channel and your membership…';

  @override
  String get chatV2_streamChannelSurfaceMessage6 =>
      'Device offline. Channel membership wasn\'t confirmed and no message was sent.';

  @override
  String get chatV2_streamChannelSurfaceMessage7 => 'Conversation unavailable';

  @override
  String get chatV2_streamChannelSurfaceNotConnected =>
      'Couldn\'t reach the chat service. Check your network and retry.';

  @override
  String get chatV2_streamChannelSurfaceNotConnectedMessage =>
      'This conversation can\'t be opened right now. Try again later.';

  @override
  String get chatV2_streamChannelSurfaceNotOpened =>
      'Couldn\'t open this channel\'s conversation. Try again later.';

  @override
  String get chatV2_streamChannelSurfaceRefused =>
      'You\'re not a member of this group yet; LOOP didn\'t open any conversation.';

  @override
  String get chatV2_streamChannelSurfaceSwitch =>
      'This channel hasn\'t synced to your account yet; LOOP didn\'t open any conversation.';

  @override
  String get chatV2_voiceRoomQueueInvited => 'Invited';

  @override
  String get chatV2_voiceRoomQueueWaiting => 'Waiting for invite';

  @override
  String chatV2_voiceRoomRosterListenersCount(Object? count) {
    return 'Listeners $count';
  }

  @override
  String get chatV2_voiceRoomRosterListenersEmpty => 'No listeners right now';

  @override
  String chatV2_voiceRoomRosterSpeakersCount(Object? count) {
    return 'Speakers $count';
  }

  @override
  String get chatV2_voiceRoomRosterSpeakersEmpty => 'No speakers right now';

  @override
  String get chatV2_voiceRoomScreensBody =>
      'Leaving exits this call and cancels your raised hand; to keep listening you\'ll need to rejoin.';

  @override
  String get chatV2_voiceRoomScreensBody2 =>
      'Ending disconnects everyone in the room right away; the room can\'t be entered again and the hand-raise queue is discarded. Hosts don\'t have Leave: the host decides whether the room continues. To step away from this page, use Back; the room collapses to the top and you can return anytime. The community can start a new one.';

  @override
  String get chatV2_voiceRoomScreensChooseVoiceRoomMemberCommand =>
      'The server sends the actions available for each row; only the ones you can actually use are listed.';

  @override
  String get chatV2_voiceRoomScreensConfirmLabel => 'Leave';

  @override
  String get chatV2_voiceRoomScreensConfirmLabel2 => 'End room';

  @override
  String chatV2_voiceRoomScreensConnecting(Object? part) {
    return '$part · Connecting voice';
  }

  @override
  String get chatV2_voiceRoomScreensDetail =>
      'No voice connection is started here. Refresh, or ask the host to reopen it.';

  @override
  String chatV2_voiceRoomScreensDisconnected(Object? part) {
    return '$part · Voice disconnected';
  }

  @override
  String get chatV2_voiceRoomScreensEmpty => 'No voice room right now';

  @override
  String get chatV2_voiceRoomScreensEmpty2 =>
      'This community has no live voice room right now.';

  @override
  String get chatV2_voiceRoomScreensEmptyMessage =>
      'No live voice room right now';

  @override
  String chatV2_voiceRoomScreensInviteSpeaker(Object? name) {
    return 'Target: $name. Once invited, they become a speaker and can talk in this call.';
  }

  @override
  String get chatV2_voiceRoomScreensKicker => 'Voice live';

  @override
  String get chatV2_voiceRoomScreensKicker2 => 'Voice lobby';

  @override
  String get chatV2_voiceRoomScreensLabel => 'Lower hand';

  @override
  String get chatV2_voiceRoomScreensLabel2 => 'Raise hand';

  @override
  String get chatV2_voiceRoomScreensLoading => 'Loading voice room';

  @override
  String get chatV2_voiceRoomScreensLoading2 =>
      'Loading this community\'s voice room.';

  @override
  String get chatV2_voiceRoomScreensLoopBadge => 'Speaking';

  @override
  String get chatV2_voiceRoomScreensLoopBadge2 => 'Hand raised';

  @override
  String chatV2_voiceRoomScreensLoopLabel(Object? handRaises) {
    return 'Hand-raise queue $handRaises';
  }

  @override
  String get chatV2_voiceRoomScreensLoopLabel2 => 'Host controls';

  @override
  String chatV2_voiceRoomScreensLoopLabel3(Object? speakerCount) {
    return 'Speakers $speakerCount';
  }

  @override
  String chatV2_voiceRoomScreensLoopLabel4(Object? listening) {
    return 'Listeners $listening';
  }

  @override
  String get chatV2_voiceRoomScreensLoopTopbarBackLabel =>
      'Minimize voice room';

  @override
  String get chatV2_voiceRoomScreensMessage => 'Couldn\'t open share';

  @override
  String get chatV2_voiceRoomScreensMessage10 =>
      'LOOP has no speakers recorded for this room yet. The host isn\'t in this list.';

  @override
  String get chatV2_voiceRoomScreensMessage11 =>
      'LOOP has no listeners recorded for this room yet. The host isn\'t in this list.';

  @override
  String get chatV2_voiceRoomScreensMessage2 =>
      'Listening isn\'t open in this room yet';

  @override
  String get chatV2_voiceRoomScreensMessage3 => 'Left stage, back to listening';

  @override
  String get chatV2_voiceRoomScreensMessage4 =>
      'Leaving stage isn\'t available right now';

  @override
  String get chatV2_voiceRoomScreensMessage5 =>
      'Room ended · The host ended this voice room';

  @override
  String get chatV2_voiceRoomScreensMessage6 => 'Left voice room';

  @override
  String get chatV2_voiceRoomScreensMessage7 =>
      'Left voice room; voice cleanup wasn\'t confirmed';

  @override
  String chatV2_voiceRoomScreensMessage8(Object? communityFailureReason) {
    return 'Mic is on, but the mute flag on the list couldn\'t be cleared: $communityFailureReason';
  }

  @override
  String get chatV2_voiceRoomScreensMessage9 =>
      'Hand raised, waiting for the host to invite you';

  @override
  String chatV2_voiceRoomScreensMute(Object? name) {
    return 'Target: $name. Mute is a LOOP-side intent; their device may still unmute itself. You can undo it on this row later.';
  }

  @override
  String get chatV2_voiceRoomScreensMute2 => 'Mute requested';

  @override
  String chatV2_voiceRoomScreensName(Object? named) {
    return 'Me · $named';
  }

  @override
  String chatV2_voiceRoomScreensPart(Object? count, Object? part) {
    return '$part · $count joined';
  }

  @override
  String chatV2_voiceRoomScreensReconnecting(Object? part) {
    return '$part · Voice reconnecting';
  }

  @override
  String chatV2_voiceRoomScreensRemoveSpeaker(Object? name) {
    return 'Target: $name. After removal they go back to listening and stay in the room.';
  }

  @override
  String get chatV2_voiceRoomScreensRemoveSpeaker2 => 'Removed from stage';

  @override
  String get chatV2_voiceRoomScreensRun => 'Mute all requested';

  @override
  String get chatV2_voiceRoomScreensRun2 => 'Invited to speak';

  @override
  String get chatV2_voiceRoomScreensRun3 => 'Joined, connecting voice';

  @override
  String get chatV2_voiceRoomScreensRun4 => 'Hand lowered';

  @override
  String get chatV2_voiceRoomScreensRun5 => 'Room ended';

  @override
  String get chatV2_voiceRoomScreensS => 'Hand-raise queue';

  @override
  String get chatV2_voiceRoomScreensS2 =>
      'Room ended; voice cleanup wasn\'t confirmed';

  @override
  String chatV2_voiceRoomScreensS3(Object? count, Object? part) {
    return '$part · $count in call';
  }

  @override
  String chatV2_voiceRoomScreensS4(Object? inRoom) {
    return '$inRoom in the room';
  }

  @override
  String get chatV2_voiceRoomScreensSubtitle => 'Tap this row to unmute';

  @override
  String get chatV2_voiceRoomScreensSubtitle2 => 'Muted by host in LOOP';

  @override
  String get chatV2_voiceRoomScreensSubtitle3 => 'Can speak';

  @override
  String get chatV2_voiceRoomScreensSubtitle4 =>
      'Waiting for the host to invite';

  @override
  String get chatV2_voiceRoomScreensSubtitle5 => 'Listening';

  @override
  String chatV2_voiceRoomScreensSubtitle6(Object? entries, Object? entries2) {
    return '#$entries · $entries2';
  }

  @override
  String get chatV2_voiceRoomScreensSubtitle7 => 'Invite to speak';

  @override
  String get chatV2_voiceRoomScreensSwitch =>
      'The voice room is recorded, but the call isn\'t set up yet. Tap Start voice room again to continue.';

  @override
  String get chatV2_voiceRoomScreensSwitch10 =>
      'Back collapses the room to the top; tap it to return anytime.';

  @override
  String get chatV2_voiceRoomScreensSwitch11 =>
      'Check the host, online count and recording notice before joining.';

  @override
  String get chatV2_voiceRoomScreensSwitch2 =>
      'The voice room is set up but listening isn\'t open yet. Tap Start voice room again to retry.';

  @override
  String get chatV2_voiceRoomScreensSwitch3 =>
      'The voice room isn\'t ready, so no one can join yet. Tap Start voice room again to retry.';

  @override
  String get chatV2_voiceRoomScreensSwitch4 =>
      'LOOP submitted this change; the provider hasn\'t confirmed it yet. Refresh later for the latest status.';

  @override
  String chatV2_voiceRoomScreensSwitch5(Object? alias) {
    return 'Me · $alias';
  }

  @override
  String chatV2_voiceRoomScreensSwitch6(Object? part) {
    return '$part · Counting';
  }

  @override
  String get chatV2_voiceRoomScreensSwitch7 =>
      'Couldn\'t load voice room status';

  @override
  String chatV2_voiceRoomScreensSwitch8(Object? speaking) {
    return '$speaking on mic';
  }

  @override
  String get chatV2_voiceRoomScreensSwitch9 =>
      'Couldn\'t load the voice room status this time; you can retry below.';

  @override
  String get chatV2_voiceRoomScreensText =>
      'Leaving exits this call and cancels your raised hand.';

  @override
  String get chatV2_voiceRoomScreensTitle => 'Leave voice room?';

  @override
  String get chatV2_voiceRoomScreensTitle2 => 'End voice room?';

  @override
  String chatV2_voiceRoomScreensUnmute(Object? name) {
    return 'Target: $name. This only withdraws the LOOP-side mute intent and won\'t turn on their mic; only their device can do that.';
  }

  @override
  String get chatV2_voiceRoomScreensUnmute2 => 'Mute intent withdrawn';

  @override
  String get chatV2_voiceRoomScreensUnmuteSelf =>
      'This is your own speaker row. It only clears the LOOP-side mute flag and won\'t turn on your mic; unmute yourself in the call.';

  @override
  String get chatV2_voiceRoomScreensUnmuteSelf2 => 'My mute flag cleared';

  @override
  String chatV2_voiceRoomScreensVoiceRoomBannerTitle(Object? communityName) {
    return 'In voice room · $communityName';
  }

  @override
  String chatV2_voiceRoomScreensVoiceRoomLiveLine(
    Object? inRoom,
    Object? liveVoiceRoomElapsedLabel,
  ) {
    return '$inRoom listening · $liveVoiceRoomElapsedLabel';
  }

  @override
  String chatV2_voiceRoomScreensVoiceRoomTopbarLine(
    Object? listening,
    Object? speaking,
  ) {
    return 'Live · Speaking $speaking · Listeners $listening';
  }

  @override
  String get chatV2_voiceRoomScreensVoiceroomBannerLeaveConfirmLabel =>
      'Leaving…';

  @override
  String get chatV2_voiceRoomScreensVoiceroomBannerLeaveConfirmLabel2 =>
      'Confirm leave';

  @override
  String get chatV2_voiceRoomScreensVoiceroomBannerOpenLabel => 'Reconnect';

  @override
  String get chatV2_voiceRoomScreensVoiceroomBannerOpenLabel2 =>
      'Return to room';

  @override
  String get chatV2_voiceRoomScreensVoiceroomCapabilityUnavailableDetail =>
      'This device couldn\'t load the voice room\'s availability. Check your network and retry.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomCapabilityUnavailableDetail2 =>
      'Couldn\'t load the voice room\'s availability yet. Try again later.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomEndedBackLabel =>
      'Back to community';

  @override
  String get chatV2_voiceRoomScreensVoiceroomEndedMessage =>
      'The host ended this voice room.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomEvidencePendingMessage =>
      'Voice room unavailable';

  @override
  String get chatV2_voiceRoomScreensVoiceroomHostNoLeaveDetail =>
      'Couldn\'t load End room this time. Try again later. Back collapses the room to the top.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomHostNoLeaveMessage =>
      'Can\'t end the room right now';

  @override
  String get chatV2_voiceRoomScreensVoiceroomInfoLabel =>
      'Room info, one item unconfirmed by the provider';

  @override
  String get chatV2_voiceRoomScreensVoiceroomInfoLabel2 => 'Room info';

  @override
  String get chatV2_voiceRoomScreensVoiceroomInviteEmptyMessage =>
      'Raised hands are listed here in order.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomInviteEmptyTitle =>
      'No raised hands to invite';

  @override
  String get chatV2_voiceRoomScreensVoiceroomJoinLabel => 'Join voice room';

  @override
  String get chatV2_voiceRoomScreensVoiceroomMediaBackstageRetryLabel =>
      'Refreshing…';

  @override
  String get chatV2_voiceRoomScreensVoiceroomMediaUnavailableDetail =>
      'This voice room can\'t be opened right now; no connection was made.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomMediaUnavailableMessage =>
      'Voice connection unavailable';

  @override
  String get chatV2_voiceRoomScreensVoiceroomMemberSheetBarrierLabel =>
      'Close member actions';

  @override
  String get chatV2_voiceRoomScreensVoiceroomMissingIdDetail =>
      'Enter from a community page or its official group; this page won\'t guess which community\'s voice room to open.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomMuteAllLabel => 'Mute all';

  @override
  String get chatV2_voiceRoomScreensVoiceroomNotJoinableDetail =>
      'The provider hasn\'t confirmed this room is ready, so joining would be refused. Refresh and try again later.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomNotJoinableMessage =>
      'This room can\'t be joined yet';

  @override
  String get chatV2_voiceRoomScreensVoiceroomQueueEmptyMessage =>
      'No one is waiting. Raised hands are listed here in order.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomQueueEmptyTitle =>
      'Hand-raise queue is empty';

  @override
  String get chatV2_voiceRoomScreensVoiceroomQueueSelfOnlyMessage =>
      'Only the host can see the full queue. Your position shows here after you raise your hand.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomQueueSelfOnlyTitle =>
      'You haven\'t raised your hand';

  @override
  String chatV2_voiceRoomScreensVoiceroomQueueSelfSubtitle(Object? sequence) {
    return '#$sequence · Waiting for invite';
  }

  @override
  String get chatV2_voiceRoomScreensVoiceroomShareLabel => 'Share voice room';

  @override
  String get chatV2_voiceRoomScreensVoiceroomSpeakerHostSubtitle =>
      'Host · Speaking';

  @override
  String get chatV2_voiceRoomScreensVoiceroomSpeakerHostSubtitle2 =>
      'Host · Mic on';

  @override
  String get chatV2_voiceRoomScreensVoiceroomStepDownUnavailableDetail =>
      'Only the host can change speakers. To leave the stage, ask the host or leave the room.';

  @override
  String get chatV2_voiceRoomScreensVoiceroomStepDownUnavailableMessage =>
      'Leaving stage yourself isn\'t available right now';

  @override
  String chatV2_voiceRoomShareLine(Object? communityName, Object? roomTitle) {
    return 'Join the \"$communityName\" voice room on LOOP: $roomTitle';
  }

  @override
  String chatV2_voiceRoomShareVoiceRoomTitle(Object? communityName) {
    return '$communityName voice room';
  }

  @override
  String get chatV2_voiceRoomStageBarrierLabel => 'Close go-live sheet';

  @override
  String get chatV2_voiceRoomStageBuild => 'Speaking';

  @override
  String get chatV2_voiceRoomStageBuild2 => 'Mic on';

  @override
  String get chatV2_voiceRoomStageBuild3 =>
      'The room is visible to community members right away and anyone can listen in. As host, you or other admins invite speakers, mute all and end the room; the mic is off by default.';

  @override
  String get chatV2_voiceRoomStageHintText =>
      'Leave blank to show \"Community name voice room\"';

  @override
  String chatV2_voiceRoomStageLabel(num count, Object? onTap) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more listeners',
      one: '1 more listener',
    );
    return '$_temp0$onTap';
  }

  @override
  String get chatV2_voiceRoomStageLabel2 => 'Go live';

  @override
  String get chatV2_voiceRoomStageLabel3 => 'People';

  @override
  String get chatV2_voiceRoomStageLabel4 => 'My role';

  @override
  String get chatV2_voiceRoomStageLabelText => 'Room title (optional)';

  @override
  String get chatV2_voiceRoomStageLoopOfflineState => 'View speakers';

  @override
  String get chatV2_voiceRoomStageLoopOfflineState2 => 'View listeners';

  @override
  String chatV2_voiceRoomStageSemanticLabel(Object? badge, Object? label) {
    return '$label, $badge hands raised';
  }

  @override
  String get chatV2_voiceRoomStageValue => 'Not joined';

  @override
  String get chatV2_voiceRoomStageViewFullList => ', view full list';

  @override
  String get chatV2_voiceRoomStageVoiceroomBarMicLabel => 'Not connected';

  @override
  String chatV2_voiceRoomStageVoiceroomHostLabel(
    Object? caption,
    Object? name,
  ) {
    return 'Host $name$caption';
  }

  @override
  String get chatV2_voiceRoomStageVoiceroomHostTag => 'Host';

  @override
  String get chatV2_voiceRoomStageVoiceroomInfoSheetBarrierLabel =>
      'Close room info';

  @override
  String get chatV2_voiceRoomStageVoiceroomInviteOpenLabel => 'Invite to speak';

  @override
  String get chatV2_voiceRoomStageVoiceroomListenersEmptyTitle =>
      'No listeners yet';

  @override
  String get chatV2_voiceRoomStageVoiceroomListenersErrorTitle =>
      'Couldn\'t load listeners';

  @override
  String get chatV2_voiceRoomStageVoiceroomListenersPermissionTitle =>
      'No permission to view listeners';

  @override
  String get chatV2_voiceRoomStageVoiceroomListenersUnavailableMessage =>
      'Listener list unavailable right now';

  @override
  String get chatV2_voiceRoomStageVoiceroomProviderUnconfirmedTitle =>
      'Unconfirmed by provider';

  @override
  String get chatV2_voiceRoomStageVoiceroomSpeakersEmptyTitle =>
      'No one on stage yet';

  @override
  String get chatV2_voiceRoomStageVoiceroomSpeakersErrorTitle =>
      'Couldn\'t load speakers';

  @override
  String get chatV2_voiceRoomStageVoiceroomSpeakersPermissionTitle =>
      'No permission to view speakers';

  @override
  String get chatV2_voiceRoomStageVoiceroomSpeakersUnavailableMessage =>
      'Speaker list unavailable right now';

  @override
  String get chatV2_voiceRoomStageVoiceroomStartPending =>
      'The last go-live didn\'t finish. Going live again finishes it and keeps the title you entered.';

  @override
  String get chatV2_voiceRoomStageVoiceroomStartSubmitLabel => 'Going live…';

  @override
  String get chatV2_voiceRoomStageVoiceroomStepDownLabel => 'Leave stage';

  @override
  String get chatWidgets_componentsBuild => 'Shared at 14:12 · Demo data';

  @override
  String get chatWidgets_componentsChange => '+8.4% · Demo data';

  @override
  String get chatWidgets_componentsChatSpotSnapshotSemanticsLabel =>
      'ETH Spot market snapshot · Development preview';

  @override
  String get chatWidgets_componentsFact => 'LP unlocks in 3 days';

  @override
  String get chatWidgets_componentsFact2 => 'Top 10 holders own 61%';

  @override
  String get chatWidgets_componentsLabel => 'Voice';

  @override
  String get chatWidgets_componentsLoopTokenCardModel =>
      'Development preview facts · Not a provider response · 14:06 UTC';

  @override
  String get chatWidgets_componentsLoopTokenCardModel2 =>
      'Demo data can\'t trigger trades or watchlist changes.';

  @override
  String get chatWidgets_componentsSource => 'Development preview facts';

  @override
  String get chat_inboxRowActionsChatInboxRowSheetBarrierLabel =>
      'Close conversation actions';

  @override
  String get chat_inboxRowActionsMarkRead => 'Mark as read';

  @override
  String get chat_inboxRowActionsPin => 'Pin';

  @override
  String get chat_inboxRowActionsUnpin => 'Unpin';

  @override
  String get chat_previewPagesEyebrow => 'Shared in chat · Development preview';

  @override
  String get chat_previewPagesMessage =>
      'Demo prices and facts aren\'t provider responses. In production, cards without fresh facts don\'t show price, Buy or Watch.';

  @override
  String get chat_previewPagesMessage2 =>
      'Reference price, 24h change, and volume are labelled Demo data. Opening Market loads a separate current public Spot snapshot.';

  @override
  String get chat_previewPagesSubtitle =>
      'Development preview: messages only store the asset ID; current price and facts are re-verified when shown.';

  @override
  String get chat_secondaryPagesLoopSectionLabel =>
      'Preferences · Development preview';

  @override
  String get chat_secondaryPagesS =>
      'Removed from Development preview only. No sender interaction occurred.';

  @override
  String get chat_secondaryPagesShowRequestNotice =>
      'Marked accepted in Development preview and removed locally. No Stream conversation was created.';

  @override
  String get chat_secondaryPagesShowRequestNotice2 =>
      'Removed from Development preview. No report was submitted.';

  @override
  String get chat_secondaryPagesTitle =>
      'Development Preview only · Development preview';

  @override
  String get chat_streamInboxBody =>
      'The conversation is removed from the list and comes back when there\'s a new message. Chat history isn\'t cleared.';

  @override
  String chat_streamInboxChatVoiceRoomReturnEntrySemanticLabel(
    Object? communityName,
  ) {
    return 'In voice room, $communityName, return to room';
  }

  @override
  String chat_streamInboxChatVoiceRoomReturnEntryTitle(Object? communityName) {
    return 'In voice room · $communityName';
  }

  @override
  String get chat_streamInboxLabel => 'Loading conversations';

  @override
  String get chat_streamInboxMessage =>
      'This build isn\'t connected to the chat service, so conversations won\'t show here.';

  @override
  String get chat_streamInboxMessage10 =>
      'Before resolving a LOOP group, we need to confirm you\'re still a member of this group chat.';

  @override
  String get chat_streamInboxMessage11 =>
      'LOOP is confirming you\'re a member of this group chat.';

  @override
  String get chat_streamInboxMessage12 =>
      'Couldn\'t confirm your membership in this group chat. No group was resolved.';

  @override
  String get chat_streamInboxMessage13 =>
      'LOOP is confirming this channel and your membership.';

  @override
  String get chat_streamInboxMessage14 =>
      'Couldn\'t confirm your membership in this channel. No channel was created or opened.';

  @override
  String chat_streamInboxMessage15(Object? label) {
    return '\"$label\" didn\'t finish. Try again later';
  }

  @override
  String get chat_streamInboxMessage2 =>
      'Couldn\'t restore the conversation. No message action was taken on this page.';

  @override
  String get chat_streamInboxMessage3 =>
      'The chat service isn\'t connected yet. Try again later.';

  @override
  String get chat_streamInboxMessage4 =>
      'This link doesn\'t point to a conversation LOOP supports. No channel was opened.';

  @override
  String get chat_streamInboxMessage5 =>
      'LOOP is restoring the server-authorized chat connection.';

  @override
  String get chat_streamInboxMessage6 =>
      'Couldn\'t restore chat authorization. No conversation was opened.';

  @override
  String get chat_streamInboxMessage7 =>
      'Opening this conversation needs a server-confirmed chat identity and a short-lived token.';

  @override
  String get chat_streamInboxMessage8 =>
      'This link doesn\'t point to a group chat LOOP supports. No group was resolved.';

  @override
  String get chat_streamInboxMessage9 =>
      'Couldn\'t restore chat authorization. No group was resolved.';

  @override
  String get chat_streamInboxPlaceholder => 'Search chats';

  @override
  String get chat_streamInboxStreamChatEmptyActionLabel => 'Find friends';

  @override
  String get chat_streamInboxStreamChatEmptyMessage => 'No conversations yet';

  @override
  String get chat_streamInboxStreamChatListErrorMessage =>
      'Couldn\'t load the conversation list on this page. Local history wasn\'t deleted.';

  @override
  String get chat_streamInboxStreamChatListErrorTitle =>
      'Couldn\'t load conversations';

  @override
  String get chat_streamInboxStreamChatUnavailableTitle =>
      'Conversations not connected yet';

  @override
  String get chat_streamInboxTitle => 'Invalid conversation link';

  @override
  String get chat_streamInboxTitle10 => 'Conversation unavailable';

  @override
  String get chat_streamInboxTitle11 => 'Conversation actions';

  @override
  String get chat_streamInboxTitle12 => 'Delete this conversation?';

  @override
  String get chat_streamInboxTitle2 => 'Restoring conversation';

  @override
  String get chat_streamInboxTitle3 => 'Chat isn\'t available right now';

  @override
  String get chat_streamInboxTitle4 => 'Chat service not connected yet';

  @override
  String get chat_streamInboxTitle5 => 'Invalid group chat link';

  @override
  String get chat_streamInboxTitle6 => 'Group identity unavailable';

  @override
  String get chat_streamInboxTitle7 => 'Confirming group chat';

  @override
  String get chat_streamInboxTitle8 => 'Group chat unavailable';

  @override
  String get chat_streamInboxTitle9 => 'Opening conversation';

  @override
  String get chat_voiceRoomLabel => 'Host';

  @override
  String get chat_voiceRoomText => 'Mock seat';

  @override
  String get common_about => 'Notes';

  @override
  String get common_aboutSection => 'About';

  @override
  String get common_actionIncomplete => 'The action didn\'t finish.';

  @override
  String get common_actions => 'Actions';

  @override
  String get common_all => 'All';

  @override
  String get common_amount => 'Amount';

  @override
  String get common_assets => 'Assets';

  @override
  String get common_awaitingSignature => 'Awaiting signature';

  @override
  String get common_back => 'Back';

  @override
  String get common_blockList => 'Block list';

  @override
  String get common_bridge => 'Bridge';

  @override
  String get common_broadcast => 'Broadcast';

  @override
  String get common_buy => 'Buy';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_cancelled => 'Cancelled';

  @override
  String get common_chart => 'Chart';

  @override
  String get common_chat => 'Chat';

  @override
  String get common_claim => 'Claim';

  @override
  String get common_close => 'Close';

  @override
  String get common_community => 'Community';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_confirmed => 'Confirmed';

  @override
  String get common_continueAction => 'Continue';

  @override
  String get common_contract => 'Contract';

  @override
  String get common_copied => 'Copied';

  @override
  String get common_copy => 'Copy';

  @override
  String get common_dataSource => 'Data source';

  @override
  String get common_dataUnavailable => 'Data unavailable';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_demoData => 'Demo data';

  @override
  String get common_details => 'Details';

  @override
  String get common_devPreview => 'Development preview';

  @override
  String get common_directMessage => 'Direct message';

  @override
  String get common_disconnected => 'Disconnected';

  @override
  String get common_done => 'Done';

  @override
  String get common_draft => 'Draft';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_ended => 'Ended';

  @override
  String get common_estimatedReceive => 'Estimated to receive';

  @override
  String get common_exit => 'Exit';

  @override
  String get common_expired => 'Expired';

  @override
  String get common_failed => 'Failed';

  @override
  String get common_feed => 'Feed';

  @override
  String get common_follow => 'Follow';

  @override
  String get common_followers => 'Followers';

  @override
  String get common_following => 'Following';

  @override
  String get common_gotIt => 'Got it';

  @override
  String get common_graduate => 'Graduate';

  @override
  String get common_graduated => 'Graduated';

  @override
  String get common_groupChat => 'Group chat';

  @override
  String get common_holders => 'Holders';

  @override
  String get common_holdings => 'Holdings';

  @override
  String get common_inProgress => 'In progress';

  @override
  String get common_inReview => 'In review';

  @override
  String get common_itemUnavailable => 'This item can\'t be loaded right now.';

  @override
  String get common_joining => 'Joining…';

  @override
  String get common_justNow => 'Just now';

  @override
  String get common_language => 'Language';

  @override
  String get common_lastActionIncomplete => 'The last action didn\'t finish';

  @override
  String get common_launchpad => 'Launchpad';

  @override
  String get common_learnMore => 'Learn more';

  @override
  String get common_link => 'Link';

  @override
  String get common_linkCopied => 'Link copied';

  @override
  String get common_liquidity => 'Liquidity';

  @override
  String get common_listSeparator => ', ';

  @override
  String get common_loading => 'Loading';

  @override
  String get common_loadingEllipsis => 'Loading…';

  @override
  String get common_market => 'Market';

  @override
  String get common_marketCap => 'Market cap';

  @override
  String get common_me => 'Me';

  @override
  String get common_members => 'Members';

  @override
  String get common_messageRequests => 'Message requests';

  @override
  String get common_minimumReceive => 'Minimum received';

  @override
  String get common_mining => 'Mining';

  @override
  String get common_more => 'More';

  @override
  String get common_mute => 'Mute';

  @override
  String get common_muted => 'Muted';

  @override
  String get common_name => 'Name';

  @override
  String get common_network => 'Network';

  @override
  String get common_next => 'Next';

  @override
  String get common_nextPageFailed => 'Couldn\'t load the next page';

  @override
  String get common_noPermission => 'This account doesn\'t have permission';

  @override
  String get common_noTradesYet => 'No trades yet';

  @override
  String get common_none => 'None';

  @override
  String get common_normal => 'Normal';

  @override
  String get common_notConfigured => 'Not configured';

  @override
  String get common_notOpenYet => 'Not available yet';

  @override
  String get common_nothingHereYet => 'Nothing here yet';

  @override
  String get common_notificationSettings => 'Notification settings';

  @override
  String get common_notifications => 'Notifications';

  @override
  String get common_ok => 'OK';

  @override
  String get common_on => 'On';

  @override
  String get common_openSecurityCenter => 'Go to Security Center';

  @override
  String get common_openSettings => 'Open Settings';

  @override
  String get common_paused => 'Paused';

  @override
  String get common_pay => 'Pay';

  @override
  String get common_pendingConfirmation => 'Pending confirmation';

  @override
  String get common_power => 'Power';

  @override
  String get common_priceAlerts => 'Price alerts';

  @override
  String get common_profile => 'Profile';

  @override
  String get common_receive => 'Receive';

  @override
  String get common_refresh => 'Refresh';

  @override
  String get common_rejected => 'Rejected';

  @override
  String get common_reload => 'Reload';

  @override
  String get common_report => 'Report';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_reverted => 'Reverted';

  @override
  String get common_save => 'Save';

  @override
  String get common_scan => 'Scan';

  @override
  String get common_search => 'Search';

  @override
  String get common_security => 'Security';

  @override
  String get common_securityCenter => 'Security Center';

  @override
  String get common_sell => 'Sell';

  @override
  String get common_send => 'Send';

  @override
  String get common_settings => 'Settings';

  @override
  String get common_share => 'Share';

  @override
  String get common_sign => 'Sign';

  @override
  String get common_simulationPassed => 'Simulation passed';

  @override
  String get common_simulationRejected => 'Simulation rejected';

  @override
  String get common_simulationResult => 'Simulation result';

  @override
  String get common_simulationUnavailable => 'Simulation unavailable';

  @override
  String get common_slippageLimit => 'Slippage limit';

  @override
  String get common_snapshotBlock => 'Snapshot block';

  @override
  String get common_submit => 'Submit';

  @override
  String get common_submitted => 'Submitted';

  @override
  String get common_submitting => 'Submitting';

  @override
  String get common_success => 'Success';

  @override
  String get common_swap => 'Swap';

  @override
  String get common_today => 'Today';

  @override
  String get common_token => 'Token';

  @override
  String get common_tokenApprovals => 'Token approvals';

  @override
  String get common_totalSupply => 'Total supply';

  @override
  String get common_trade => 'Trade';

  @override
  String get common_unavailable => 'Unavailable';

  @override
  String get common_unknown => 'Unknown';

  @override
  String get common_unmute => 'Unmute';

  @override
  String get common_unread => 'Unread';

  @override
  String get common_uploading => 'Uploading…';

  @override
  String get common_user => 'User';

  @override
  String get common_validUntil => 'Valid until';

  @override
  String get common_verifying => 'Verifying…';

  @override
  String get common_voiceRooms => 'Voice rooms';

  @override
  String get common_waitingForData => 'Waiting for data';

  @override
  String get common_watchlist => 'Watchlist';

  @override
  String get dapp_bridgeDappIntentBusyText => 'The wallet has a pending action';

  @override
  String get dapp_bridgeDappMainnetSigningText =>
      'Signing isn\'t supported on this network yet';

  @override
  String get dapp_bridgeInsufficientBalance =>
      'Not enough balance to pay for this transaction';

  @override
  String get dapp_bridgeTimedOut => 'Network unavailable. Try again later.';

  @override
  String get dapp_bridgeToast => 'This request didn\'t pass the checks';

  @override
  String get dapp_bridgeUnavailable =>
      'Signing isn\'t supported on this page yet';

  @override
  String get dapp_browserScreensBlocked => 'Blocked';

  @override
  String get dapp_browserScreensBuild => 'This address can\'t be opened';

  @override
  String get dapp_browserScreensDappBrowserClearRecentsLabel => 'Clear recents';

  @override
  String get dapp_browserScreensDappBrowserEmptyTitle => 'No history yet';

  @override
  String get dapp_browserScreensDappBrowserGoLabel => 'Open';

  @override
  String get dapp_browserScreensDappBrowserHomeTitle => 'DApp browser';

  @override
  String get dapp_browserScreensDappBrowserOmniboxHintText => 'Enter a URL';

  @override
  String get dapp_browserScreensDappFindingsOpenLabel => 'Open anyway';

  @override
  String get dapp_browserScreensDappMenuBookmarkAdd => 'Bookmark';

  @override
  String get dapp_browserScreensDappMenuBookmarkTitle => 'Remove bookmark';

  @override
  String get dapp_browserScreensDappMenuCopyTitle => 'Copy link';

  @override
  String get dapp_browserScreensDappMenuDisconnectTitle =>
      'Disconnect this site';

  @override
  String get dapp_browserScreensDappMenuExternalTitle =>
      'Open in external browser';

  @override
  String dapp_browserScreensDappWebAddressLabel(Object? host) {
    return 'View address $host';
  }

  @override
  String get dapp_browserScreensDappWebBackLabel => 'Back';

  @override
  String dapp_browserScreensDappWebChainLabel(Object? chainLabel) {
    return 'Switch network $chainLabel';
  }

  @override
  String get dapp_browserScreensDappWebErrorTitle => 'The page didn\'t open';

  @override
  String get dapp_browserScreensDappWebForwardLabel => 'Forward';

  @override
  String get dapp_browserScreensDappWebUnavailableTitle =>
      'DApp browser isn\'t available right now';

  @override
  String get dapp_browserScreensDappWebWallet => 'Wallet not connected';

  @override
  String get dapp_browserScreensFlagged => 'Caution';

  @override
  String get dapp_browserScreensIf => 'Clear';

  @override
  String get dapp_browserScreensLoopLabel => 'Bookmarks';

  @override
  String get dapp_browserScreensLoopLabel2 => 'Recent';

  @override
  String get dapp_browserScreensMessage => 'Signed';

  @override
  String get dapp_browserScreensMessage2 => 'Bookmark removed';

  @override
  String get dapp_browserScreensMessage3 => 'Bookmarked';

  @override
  String get dapp_browserScreensNormalized => 'Same origin';

  @override
  String get dapp_browserScreensToast => 'Only HTTPS addresses can be opened';

  @override
  String get dapp_browserScreensToast2 => 'Couldn\'t open the external browser';

  @override
  String get dapp_modelsApprovalForAll => 'Approval for all NFTs';

  @override
  String get dapp_modelsEoaSpender => 'Approval to a personal address';

  @override
  String get dapp_modelsFor => 'BSC Mainnet';

  @override
  String get dapp_modelsPermitSignature => 'Permit signature';

  @override
  String get dapp_modelsRawHashSignature => 'Raw hash signature';

  @override
  String get dapp_modelsSimulationFailed => 'Simulation failed';

  @override
  String get dapp_modelsUnlimitedApproval => 'Unlimited approval';

  @override
  String get dapp_modelsUnrecognizedTypedData =>
      'Unrecognized signature structure';

  @override
  String get dapp_modelsUnverifiedContract => 'Unverified contract';

  @override
  String get dapp_signingDappConnectConfirmLabel => 'Connect';

  @override
  String get dapp_signingDappSignSheetCancelLabel => 'Reject';

  @override
  String get dapp_signingDappSignSheetSigningTitle =>
      'Signing and broadcasting';

  @override
  String get dapp_signingDappSignSheetSigningTitle2 => 'Signing';

  @override
  String get dapp_signingLabel => 'Wallet address';

  @override
  String get dapp_signingLoopSignFact => 'Method';

  @override
  String get dapp_signingLoopSignFact2 => 'Transfer';

  @override
  String get dapp_signingLoopSignFact3 => 'Unknown method';

  @override
  String get dapp_signingLoopSignFact4 => 'Target contract';

  @override
  String get dapp_signingLoopSignFact5 => 'Data length';

  @override
  String dapp_signingLoopSignFact6(Object? dataLength) {
    return '$dataLength bytes';
  }

  @override
  String get dapp_signingLoopSignFact7 => 'Type';

  @override
  String get dapp_signingLoopSignFact8 => 'Structured data';

  @override
  String get dapp_signingMessage => 'Confirm signature';

  @override
  String get dapp_signingS => 'Contract call';

  @override
  String get dapp_signingS2 => 'Message';

  @override
  String get dapp_signingShowDappConnectSheet => 'Connect wallet';

  @override
  String get dapp_signingSwitch => 'Cancelled. Nothing changed.';

  @override
  String get dapp_signingSwitch2 =>
      'Verification didn\'t pass. Nothing changed.';

  @override
  String get dapp_signingSwitch3 =>
      'This request expired and wasn\'t signed. Go back to the page and try again.';

  @override
  String get dapp_signingSwitch4 =>
      'The content to sign doesn\'t match the page\'s request. Signing refused.';

  @override
  String get dapp_signingSwitch5 =>
      'This transaction failed simulation and wasn\'t signed.';

  @override
  String get dapp_signingSwitch6 =>
      'This transaction can\'t be simulated right now and wasn\'t signed.';

  @override
  String get dapp_signingSwitch7 =>
      'The wallet can\'t sign on this chain right now. Nothing was signed.';

  @override
  String get dapp_signingSwitch8 =>
      'The signed-in wallet isn\'t the wallet for this request. Nothing was signed.';

  @override
  String get dapp_signingSwitch9 =>
      'The wallet didn\'t finish signing. Nothing changed.';

  @override
  String get dapp_signingTransaction => 'Confirm transaction';

  @override
  String launch2Creator_figureWithNote(Object? figure, Object? note) {
    return '$figure ($note)';
  }

  @override
  String get launch2Creator_launch2AwaitingExecutor => 'Queued';

  @override
  String get launch2Creator_launch2BootstrapRequired =>
      'Your account is still being set up. Try again later.';

  @override
  String get launch2Creator_launch2Build => 'Bonding pool for sale';

  @override
  String get launch2Creator_launch2Build10 =>
      'Fixed by the platform template; can\'t be changed.';

  @override
  String get launch2Creator_launch2Build11 =>
      'The platform hasn\'t set a buyback recipient address yet, so you can\'t submit right now.';

  @override
  String get launch2Creator_launch2Build2 => 'Graduation reserve';

  @override
  String get launch2Creator_launch2Build3 => 'Bonding pool trade tax';

  @override
  String get launch2Creator_launch2Build4 => 'DEX pool trade tax';

  @override
  String get launch2Creator_launch2Build5 => 'DEX pool buy tax';

  @override
  String get launch2Creator_launch2Build6 => 'Per-address cap';

  @override
  String get launch2Creator_launch2Build7 => 'Mint price';

  @override
  String get launch2Creator_launch2Build8 => 'Mint period';

  @override
  String get launch2Creator_launch2Build9 => 'Set by the instance';

  @override
  String launch2Creator_launch2CapFigure(Object? launch2CurveCapFigure) {
    return '$launch2CurveCapFigure tokens';
  }

  @override
  String get launch2Creator_launch2Claimed => 'Preparing to deploy';

  @override
  String get launch2Creator_launch2Confirmed => 'Verifying';

  @override
  String get launch2Creator_launch2CreateBody =>
      'What you\'ve entered won\'t be saved.';

  @override
  String get launch2Creator_launch2CreateCancelLabel => 'Keep editing';

  @override
  String get launch2Creator_launch2CreateConfig => 'Saving configuration…';

  @override
  String get launch2Creator_launch2CreateConfirmLabel => 'Discard';

  @override
  String get launch2Creator_launch2CreateEmptyMessage =>
      'Couldn\'t find this project';

  @override
  String launch2Creator_launch2CreateFailed(Object? memeFailureText) {
    return 'Image upload failed: $memeFailureText';
  }

  @override
  String get launch2Creator_launch2CreateFor => 'X (optional)';

  @override
  String get launch2Creator_launch2CreateFor2 => 'Telegram (optional)';

  @override
  String get launch2Creator_launch2CreateFor3 => 'Website (optional)';

  @override
  String get launch2Creator_launch2CreateFor4 => 'Discord (optional)';

  @override
  String get launch2Creator_launch2CreateGroupTitle => 'Images';

  @override
  String get launch2Creator_launch2CreateGroupTitle2 => 'Basic info';

  @override
  String get launch2Creator_launch2CreateHint => 'Enter project name';

  @override
  String get launch2Creator_launch2CreateHint2 => 'Enter ticker';

  @override
  String get launch2Creator_launch2CreateHint3 => 'Describe your project';

  @override
  String get launch2Creator_launch2CreateIf =>
      'Only links starting with https:// are supported';

  @override
  String get launch2Creator_launch2CreateLabel => 'Retry submission';

  @override
  String get launch2Creator_launch2CreateLabel2 => 'Submit for review';

  @override
  String get launch2Creator_launch2CreateLabel3 => 'Ticker';

  @override
  String get launch2Creator_launch2CreateLabel4 => 'Description (optional)';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLinksCommunityHint =>
      'To bind a community, the community owner does it under Community management → Bind token.';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLinksHeading =>
      'External links';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLinksLine =>
      'The project\'s X / Telegram / website / Discord, all optional; reviewers and users will see them.';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLogoMissing => 'Avatar';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLogoMissing2 =>
      'A launch needs a square avatar';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing => 'NFT image';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing2 =>
      'NFT image (optional)';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing3 =>
      'A launch needs an NFT image';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateRejectionTitle =>
      'Review notes';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateSaleStartLabel =>
      'Choose mint start time';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateSaleStartMissingBody =>
      'Choose a mint start time first.';

  @override
  String launch2Creator_launch2CreateLaunch2CreateSaleTooEarlyBody(
    Object? leadLabel,
    Object? localTimestampLabel,
  ) {
    return 'The mint start time is too early: the platform needs at least $leadLabel of lead time, earliest $localTimestampLabel. Choose again.';
  }

  @override
  String get launch2Creator_launch2CreateLaunch2CreateScreenTitle =>
      'Edit details';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateScreenTitle2 =>
      'Start a v2 launch';

  @override
  String get launch2Creator_launch2CreateLaunch2NameInvisibleMessage =>
      'Name must contain visible characters';

  @override
  String get launch2Creator_launch2CreateLaunch2SaleStartHint =>
      'The platform sets the earliest time; too early gets sent back.';

  @override
  String launch2Creator_launch2CreateLaunch2SaleStartHint2(
    Object? leadLabel,
    Object? localTimestampLabel,
  ) {
    return 'Minting must start at least $leadLabel from now, earliest $localTimestampLabel.';
  }

  @override
  String get launch2Creator_launch2CreateLaunch2TickerInvisibleMessage =>
      'Ticker must contain visible characters';

  @override
  String launch2Creator_launch2CreateLeadLabel(Object? minutes) {
    return '${minutes}h';
  }

  @override
  String launch2Creator_launch2CreateLeadLabel2(Object? minutes) {
    return '$minutes min';
  }

  @override
  String get launch2Creator_launch2CreateLoopButton => 'Submitting for review…';

  @override
  String get launch2Creator_launch2CreateLoopLabel =>
      'Buyback recipient address';

  @override
  String get launch2Creator_launch2CreateLoopLabel2 => 'Launch template';

  @override
  String get launch2Creator_launch2CreateLoopSheetHeading => 'Mint start time';

  @override
  String get launch2Creator_launch2CreateNote =>
      'Square image; crop before upload';

  @override
  String get launch2Creator_launch2CreateProject => 'Saving details…';

  @override
  String get launch2Creator_launch2CreateText => 'Launch';

  @override
  String get launch2Creator_launch2CreateTitle => 'Discard this launch?';

  @override
  String get launch2Creator_launch2DeploymentAction => 'View project page';

  @override
  String get launch2Creator_launch2DeploymentAction2 => 'Sign again';

  @override
  String launch2Creator_launch2DeploymentBuild(Object? confirmations) {
    return 'Confirmations: $confirmations';
  }

  @override
  String launch2Creator_launch2DeploymentBuild2(Object? blockNumber) {
    return 'Block $blockNumber';
  }

  @override
  String get launch2Creator_launch2DeploymentLabel => 'Deploy transaction';

  @override
  String get launch2Creator_launch2DeploymentLabel2 => 'Activation transaction';

  @override
  String get launch2Creator_launch2DeploymentLabel3 => 'Copy BscScan link';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody =>
      'Activated. Creating the project page…';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody2 =>
      'Activated. You\'re this project\'s owner.';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentCancelledBody =>
      'This deployment was cancelled.';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentMissingMessage =>
      'The link has no valid project or job ID.';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentMissingTitle =>
      'Couldn\'t find this deployment';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentQueuedBody =>
      'Signature verified and recorded; waiting for the platform executor to deploy. Nothing is on-chain yet.';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentScreenTitle =>
      'Deployment progress';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentStaleBody =>
      'Couldn\'t load the latest progress. Showing the last status; retrying automatically.';

  @override
  String get launch2Creator_launch2DeploymentLoopLabel => 'Progress';

  @override
  String get launch2Creator_launch2DeploymentMessage => 'BscScan link copied';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserClassicSubtitle =>
      'Bonding curve token; moves to PancakeSwap when it fills';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserClassicTitle =>
      'Classic launch';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserV2Subtitle =>
      'NFT presale + priority buy + public pool, graduates to the official DEX pool';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserV2Title =>
      'v2 launch';

  @override
  String get launch2Creator_launch2EntryLaunch2CreatorEntryLabel =>
      'v2 launch (NFT presale + official DEX pool)';

  @override
  String get launch2Creator_launch2EntryLaunch2MyProjectsEntryLabel =>
      'My projects';

  @override
  String get launch2Creator_launch2IdempotencyConflict =>
      'This submission differs from the last one. Sign again.';

  @override
  String get launch2Creator_launch2InvalidData =>
      'The server didn\'t accept these details. Most often the mint start time is too early and leaves no time to deploy and activate. Move it later and submit again.';

  @override
  String launch2Creator_launch2Label(
    Object? current,
    Object? labels,
    Object? labels2,
  ) {
    return 'Step $current of $labels, $labels2';
  }

  @override
  String launch2Creator_launch2Label2(Object? semanticLabel) {
    return 'Upload $semanticLabel';
  }

  @override
  String launch2Creator_launch2Label3(Object? semanticLabel) {
    return '$semanticLabel, replace';
  }

  @override
  String get launch2Creator_launch2Launch2ConfigVersionUsedCode =>
      'Another project in your wallet already used this configuration version. Edit the details and save a new version.';

  @override
  String launch2Creator_launch2Launch2DurationLabel(Object? seconds) {
    return '${seconds}d';
  }

  @override
  String launch2Creator_launch2Launch2DurationLabel2(Object? seconds) {
    return '${seconds}h';
  }

  @override
  String launch2Creator_launch2Launch2DurationLabel3(Object? seconds) {
    return '$seconds min';
  }

  @override
  String get launch2Creator_launch2Launch2FixedRecipientAddress =>
      'Not configured yet';

  @override
  String get launch2Creator_launch2Launch2FixedRecipientAddressLabel =>
      'Buyback recipient address not configured yet';

  @override
  String launch2Creator_launch2Launch2FixedRecipientAddressLabel2(
    Object? value,
  ) {
    return 'Buyback recipient address $value, fixed by the platform, can\'t be changed';
  }

  @override
  String get launch2Creator_launch2Launch2NftImageHelp =>
      'Shown in wallets as the project NFT image';

  @override
  String get launch2Creator_launch2Launch2RecipientFixedCode =>
      'The buyback recipient address must be the platform\'s fixed address. This version uses another one. Edit the details and save a new version (needs review again).';

  @override
  String get launch2Creator_launch2Launch2RecipientUnavailableCode =>
      'The platform\'s buyback recipient address isn\'t configured, so you can\'t save or sign right now. Try again later.';

  @override
  String launch2Creator_launch2Launch2RejectedRowText(Object? label) {
    return 'Rejected · $label';
  }

  @override
  String launch2Creator_launch2Launch2RejectionTitle(Object? label) {
    return 'Review rejected: $label';
  }

  @override
  String launch2Creator_launch2Launch2SaleStartLabel(
    Object? inDays,
    Object? local,
  ) {
    return '$local (in ${inDays}d)';
  }

  @override
  String launch2Creator_launch2Launch2SaleStartLabel2(
    Object? inHours,
    Object? local,
  ) {
    return '$local (in ${inHours}h)';
  }

  @override
  String launch2Creator_launch2Launch2SaleStartLabel3(
    Object? inMinutes,
    Object? local,
  ) {
    return '$local (in $inMinutes min)';
  }

  @override
  String launch2Creator_launch2Launch2SupplyLabel(Object? formatDecimal) {
    return '$formatDecimal';
  }

  @override
  String launch2Creator_launch2Launch2SupplyLabel2(Object? formatDecimal) {
    return '$formatDecimal';
  }

  @override
  String get launch2Creator_launch2LoopBadge => 'Fixed by platform';

  @override
  String launch2Creator_launch2LoopNotice(Object? note) {
    return 'Review notes: $note';
  }

  @override
  String launch2Creator_launch2LoopNotice2(
    Object? configuration,
    Object? localTimestampLabel,
  ) {
    return '$configuration didn\'t pass review ($localTimestampLabel). Edit it and submit again.';
  }

  @override
  String get launch2Creator_launch2ModelsActive => 'Activated';

  @override
  String get launch2Creator_launch2ModelsDeployFailed => 'Deployment failed';

  @override
  String get launch2Creator_launch2ModelsDeployed => 'On-chain';

  @override
  String get launch2Creator_launch2ModelsDeploying => 'Deploying';

  @override
  String get launch2Creator_launch2ModelsIsFailure => 'Review';

  @override
  String get launch2Creator_launch2ModelsIsFailure2 => 'Deploy';

  @override
  String get launch2Creator_launch2ModelsIsFailure3 => 'Activate';

  @override
  String get launch2Creator_launch2ModelsSigning => 'Signing';

  @override
  String get launch2Creator_launch2ModelsVerified => 'Activating';

  @override
  String get launch2Creator_launch2NotFound =>
      'Couldn\'t find this project. It may not belong to this account.';

  @override
  String get launch2Creator_launch2PermissionDenied =>
      'This account can\'t do this step.';

  @override
  String get launch2Creator_launch2ProjectAction => 'Continue';

  @override
  String get launch2Creator_launch2ProjectAction2 => 'Edit and resubmit';

  @override
  String get launch2Creator_launch2ProjectAction3 => 'Sign to deploy';

  @override
  String get launch2Creator_launch2ProjectAction4 => 'View deployment progress';

  @override
  String get launch2Creator_launch2ProjectLabel => 'Configuration version';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectMissingMessage =>
      'The link has no valid project ID.';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextActiveBody =>
      'Activated. Creating the project page; pull down to refresh.';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDeployingBody =>
      'Deployment in progress.';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDraftBody =>
      'Details saved; the launch configuration is still missing.';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDraftBody2 =>
      'Not submitted for review yet.';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextFailedBody =>
      'The deployment didn\'t finish.';

  @override
  String
  get launch2Creator_launch2ProjectLaunch2ProjectNextRecipientOutdatedBody =>
      'This version\'s buyback recipient address isn\'t the platform\'s fixed address, so it can\'t be signed and deployed. Saving a new version needs review again.';

  @override
  String
  get launch2Creator_launch2ProjectLaunch2ProjectNextRecipientOutdatedTitle =>
      'Buyback recipient address needs updating';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextRejectedBody =>
      'This review didn\'t pass. Edit and submit again.';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextReviewBody =>
      'The platform is reviewing the launch configuration. The result shows here; pull down to refresh.';

  @override
  String launch2Creator_launch2ProjectLaunch2ProjectNextReviewBody2(
    Object? localTimestampLabel,
  ) {
    return 'Submitted $localTimestampLabel. The result shows here; pull down to refresh.';
  }

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextSignBody =>
      'Sign with your wallet and the platform will deploy and activate.';

  @override
  String launch2Creator_launch2ProjectLaunch2ProjectNextSignBody2(
    Object? localTimestampLabel,
  ) {
    return 'Approved $localTimestampLabel. Sign with your wallet and the platform will deploy and activate.';
  }

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextSignTitle =>
      'Approved';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectSaleStartLabel =>
      'Mint starts';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectScreenTitle =>
      'Project';

  @override
  String get launch2Creator_launch2ProjectLoopLabel => 'Launch configuration';

  @override
  String launch2Creator_launch2ProjectSemanticLabel(
    Object? label,
    Object? launch2CreatorMilestones,
  ) {
    return 'Progress: $launch2CreatorMilestones, $label';
  }

  @override
  String get launch2Creator_launch2ProjectsLaunch2ProjectsEmptyMessage =>
      'NFT presale + official DEX pool, in one launch.';

  @override
  String get launch2Creator_launch2ProjectsLaunch2ProjectsEmptyTitle =>
      'No projects yet';

  @override
  String launch2Creator_launch2ProjectsSemanticLabel(Object? name) {
    return '$name, launch configuration unavailable';
  }

  @override
  String get launch2Creator_launch2ProjectsSubtitle =>
      'Couldn\'t load the launch configuration. Pull to refresh or tap to retry';

  @override
  String get launch2Creator_launch2ProjectsSwitch => 'Rejected';

  @override
  String get launch2Creator_launch2ProjectsSwitch2 =>
      'No launch configuration yet';

  @override
  String launch2Creator_launch2ProjectsSwitch3(Object? localTimestampLabel) {
    return 'Mint starts $localTimestampLabel';
  }

  @override
  String get launch2Creator_launch2Reorged => 'Chain reorg, reconfirming';

  @override
  String get launch2Creator_launch2S =>
      'v2 launch isn\'t open yet. You can continue here once it opens.';

  @override
  String get launch2Creator_launch2S2 =>
      'The launch factory isn\'t available (or is computing addresses). Try again later.';

  @override
  String get launch2Creator_launch2S3 =>
      'The configuration is waiting for platform approval. Sign after it\'s approved.';

  @override
  String get launch2Creator_launch2S4 =>
      'The signing request expired. Renew it and sign again.';

  @override
  String launch2Creator_launch2S5(Object? confirmations) {
    return 'On-chain, confirmations: $confirmations';
  }

  @override
  String get launch2Creator_launch2S6 =>
      'Tokens bought back go to this address. The platform fixes it; it can\'t be changed.';

  @override
  String get launch2Creator_launch2S7 => 'Upload';

  @override
  String get launch2Creator_launch2S8 => 'Replace';

  @override
  String get launch2Creator_launch2SignIf =>
      'Preparing the signing request; the server may take a few seconds to compute addresses.';

  @override
  String launch2Creator_launch2SignLabel(Object? address) {
    return 'Token address $address';
  }

  @override
  String get launch2Creator_launch2SignLabel2 => 'Signature valid for';

  @override
  String get launch2Creator_launch2SignLaunch2SignExpiredBody =>
      'The signing request expired. Renewing gets a new request that you need to sign again.';

  @override
  String get launch2Creator_launch2SignLaunch2SignNoWalletBody =>
      'Loading wallet…';

  @override
  String get launch2Creator_launch2SignLaunch2SignNoWalletBody2 =>
      'No wallet available. Create or activate one in Wallet first.';

  @override
  String get launch2Creator_launch2SignLaunch2SignRefreshedBody =>
      'The configuration or nonce changed. The signing request was refreshed; sign again.';

  @override
  String get launch2Creator_launch2SignLaunch2SignRenewLabel =>
      'Renew signing request';

  @override
  String get launch2Creator_launch2SignLaunch2SignScreenTitle =>
      'Sign deployment';

  @override
  String get launch2Creator_launch2SignLaunch2SignSheetTitle =>
      'Authorize deployment';

  @override
  String get launch2Creator_launch2SignLoopButton => 'Sign and submit';

  @override
  String get launch2Creator_launch2SignLoopLabel => 'What you sign';

  @override
  String launch2Creator_launch2SignLoopSignFact(Object? tickerLabel) {
    return 'Authorize deploying $tickerLabel';
  }

  @override
  String get launch2Creator_launch2SignLoopSignFact2 => 'Signing wallet';

  @override
  String get launch2Creator_launch2SignLoopSignFact3 => 'Cost';

  @override
  String get launch2Creator_launch2SignLoopSignFact4 =>
      'None (signature only, no transaction)';

  @override
  String get launch2Creator_launch2SignReady => 'Token address';

  @override
  String get launch2Creator_launch2SignSigning =>
      'Waiting for wallet signature…';

  @override
  String get launch2Creator_launch2SignSubmitting => 'Submitting…';

  @override
  String get launch2Creator_launch2SignSwitch =>
      'You cancelled the signature in your wallet. Nothing was submitted.';

  @override
  String get launch2Creator_launch2SignSwitch2 =>
      'This signing request belongs to another wallet. Switch to the project owner\'s wallet.';

  @override
  String get launch2Creator_launch2SignSwitch3 =>
      'The signing request is for the wrong network. Nothing was signed.';

  @override
  String get launch2Creator_launch2SignSwitch4 =>
      'The embedded wallet isn\'t available. Sign in again and retry.';

  @override
  String get launch2Creator_launch2SignSwitch5 =>
      'The wallet didn\'t finish signing. Nothing was submitted.';

  @override
  String get launch2Creator_launch2SignText =>
      'This is an authorization signature and spends nothing. The platform deploys and activates once it receives it; progress is on the next page.';

  @override
  String launch2Creator_launch2SignValue(Object? minutes, Object? seconds) {
    return 'Expires in $minutes:$seconds';
  }

  @override
  String get launch2Creator_launch2Switch =>
      'The signature expired. Sign and submit again.';

  @override
  String get launch2Creator_launch2Switch10 =>
      'The platform is processing and will retry automatically.';

  @override
  String get launch2Creator_launch2Switch11 =>
      'The deployment didn\'t finish. Contact the platform.';

  @override
  String get launch2Creator_launch2Switch12 => 'Edit name or ticker';

  @override
  String get launch2Creator_launch2Switch13 => 'Edit mint start time';

  @override
  String get launch2Creator_launch2Switch14 =>
      'On-chain, awaiting confirmation';

  @override
  String get launch2Creator_launch2Switch15 => 'Retrying';

  @override
  String get launch2Creator_launch2Switch16 =>
      'Signature verified and recorded';

  @override
  String get launch2Creator_launch2Switch17 => 'Claimed by executor';

  @override
  String get launch2Creator_launch2Switch18 => 'Deploy transaction broadcast';

  @override
  String get launch2Creator_launch2Switch19 => 'Transaction included';

  @override
  String get launch2Creator_launch2Switch2 =>
      'The configuration was updated. Sign again.';

  @override
  String get launch2Creator_launch2Switch20 => 'Deployment confirmed';

  @override
  String get launch2Creator_launch2Switch21 => 'Module check passed';

  @override
  String get launch2Creator_launch2Switch22 =>
      'Activation transaction broadcast';

  @override
  String get launch2Creator_launch2Switch23 =>
      'Activation transaction included';

  @override
  String get launch2Creator_launch2Switch24 => 'Chain reorg, reconfirming';

  @override
  String get launch2Creator_launch2Switch25 => 'Status update';

  @override
  String get launch2Creator_launch2Switch3 =>
      'The configuration approval lapsed. Sign again after the platform approves.';

  @override
  String get launch2Creator_launch2Switch4 => 'Invalid signature. Sign again.';

  @override
  String get launch2Creator_launch2Switch5 =>
      'The wallet nonce changed. Sign again.';

  @override
  String get launch2Creator_launch2Switch6 =>
      'This version is already deployed on-chain. Contact the platform.';

  @override
  String get launch2Creator_launch2Switch7 =>
      'Too close to the mint start to activate. Change the mint start time and submit again.';

  @override
  String get launch2Creator_launch2Switch8 =>
      'The name or ticker isn\'t allowed. Edit and submit again.';

  @override
  String get launch2Creator_launch2Switch9 =>
      'The deployment check didn\'t match, so the project wasn\'t activated. Contact the platform.';

  @override
  String get launch2Creator_launch2VersionConflict =>
      'The details were changed elsewhere and have been reloaded. Check them and submit again.';

  @override
  String get launch2Creator_projectDetails => 'Project details';

  @override
  String get launch2_buybackExecuted => 'Filled';

  @override
  String get launch2_candlesCandles => 'candles';

  @override
  String get launch2_candlesGraduationMark => ', graduation marked';

  @override
  String get launch2_candlesLine => 'close-price line';

  @override
  String get launch2_intentAction => 'Action';

  @override
  String get launch2_intentNounBuy => 'buy';

  @override
  String get launch2_intentNounSell => 'sell';

  @override
  String get launch2_launch2AtmosphereActionLabel => 'Launch a token';

  @override
  String launch2_launch2AtmosphereBuild(Object? prefix) {
    return '${prefix}TBD';
  }

  @override
  String get launch2_launch2AtmosphereCountdown => 'Mint in ';

  @override
  String get launch2_launch2AtmosphereCountdown2 => 'Ends in ';

  @override
  String get launch2_launch2AtmosphereIf => 'Live trades, no trades yet';

  @override
  String get launch2_launch2AtmosphereLaunch2TickerAllLabel =>
      'All live trades';

  @override
  String get launch2_launch2AtmosphereLaunch2TickerEmpty => 'No trades yet';

  @override
  String get launch2_launch2AtmosphereMessage => 'No projects in the queue yet';

  @override
  String launch2_launch2AtmosphereS(Object? items) {
    return 'Live trades, $items';
  }

  @override
  String launch2_launch2AtmosphereSwitch(Object? soldCount) {
    return 'Minted $soldCount';
  }

  @override
  String get launch2_launch2AtmosphereSwitch2 => 'Building allowlist';

  @override
  String get launch2_launch2AtmosphereSwitch3 => 'Platform checking';

  @override
  String get launch2_launch2AtmosphereText => 'Live';

  @override
  String get launch2_launch2Build =>
      'Allowlist addresses aren\'t listed in the app; check them in the publish transaction.';

  @override
  String get launch2_launch2CampaignsLaunch2CampaignDefaultCta => 'View';

  @override
  String launch2_launch2CampaignsLaunch2CampaignKicker(
    Object? monthDay,
    Object? monthDay2,
  ) {
    return '$monthDay – $monthDay2';
  }

  @override
  String launch2_launch2CampaignsLaunch2CampaignStamp(Object? monthDay) {
    return 'Starts $monthDay';
  }

  @override
  String get launch2_launch2CampaignsLaunch2CampaignStamp2 => 'Ends today';

  @override
  String launch2_launch2CampaignsLaunch2CampaignStamp3(Object? inDays) {
    return '${inDays}d left';
  }

  @override
  String get launch2_launch2CampaignsMessage =>
      'Couldn\'t open the browser. Link copied';

  @override
  String get launch2_launch2CandleChartLaunch2CandlesEmptyText =>
      'No trades yet. Candles appear after the first trade';

  @override
  String get launch2_launch2CandleChartLaunch2CandlesExpandLabel =>
      'Open full-screen chart';

  @override
  String get launch2_launch2CandleChartLaunch2CandlesFailedText =>
      'Couldn\'t load candles. Tap to retry';

  @override
  String launch2_launch2CandleChartSemanticLabel(
    Object? candles,
    Object? label,
    Object? line,
    Object? mark,
  ) {
    return '$candles $label $line, in USD1$mark';
  }

  @override
  String get launch2_launch2CandleModelsFifteenMinutes => '15m';

  @override
  String get launch2_launch2CandleModelsFiveMinutes => '5m';

  @override
  String get launch2_launch2CandleModelsFourHours => '4h';

  @override
  String get launch2_launch2CandleModelsOneDay => '1D';

  @override
  String get launch2_launch2CandleModelsOneHour => '1h';

  @override
  String get launch2_launch2CandleModelsOneMinute => '1m';

  @override
  String get launch2_launch2Countdown => 'Mint ';

  @override
  String get launch2_launch2DynamicPoolImpact =>
      'DEX pool trading and rewards for this project aren\'t available right now.';

  @override
  String get launch2_launch2DynamicPoolLabel => 'Buy base tax total';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynProvenanceDetail =>
      'The drop is measured on 5-minute candles; buyback buys don\'t earn reward weight.';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynRewardsLink => 'This round';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynRewardsLinkLabel =>
      'My rewards';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicEndText =>
      'Ends on the first 5-minute candle that closes at or above its open (up, flat or no trades all count)';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicFeeRows =>
      'Dynamic tax total';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicFeeRows2 =>
      'Sell base tax total';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicIdleText =>
      'A drop of more than 10% within 5 minutes turns on dynamic tax and buy rewards';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows => 'Reward pool';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows2 =>
      'Current drop';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows3 =>
      'Candle closed, awaiting settlement';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows4 =>
      'My weight this round';

  @override
  String launch2_launch2DynamicPoolLaunch2DynamicRoundRows5(
    Object? formatDecimal,
    Object? launch2Usd1Label,
  ) {
    return '$launch2Usd1Label · $formatDecimal% share';
  }

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows6 =>
      'This candle ends';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows7 =>
      'End condition';

  @override
  String get launch2_launch2DynamicPoolLaunch2SectionLabel => 'Fees collected';

  @override
  String get launch2_launch2DynamicPoolLoopBadge => 'Active';

  @override
  String get launch2_launch2DynamicPoolNext => 'Tap Retry later to load again.';

  @override
  String get launch2_launch2DynamicPoolS => 'Inactive';

  @override
  String get launch2_launch2DynamicPoolTitle => 'DEX pool unavailable';

  @override
  String get launch2_launch2DynamicRewardsBuild =>
      'You haven\'t bought this round';

  @override
  String get launch2_launch2DynamicRewardsBuild2 =>
      'Buys while the round is open count toward its weight. Claim here after it ends.';

  @override
  String get launch2_launch2DynamicRewardsConfirmedText =>
      'DEX pool rewards claimed and confirmed on-chain.';

  @override
  String launch2_launch2DynamicRewardsConfirmedText2(
    Object? launch2ShortAddress,
  ) {
    return 'Claim submitted ($launch2ShortAddress), waiting for on-chain confirmation. Don\'t claim again.';
  }

  @override
  String get launch2_launch2DynamicRewardsLabel => 'Preparing…';

  @override
  String get launch2_launch2DynamicRewardsLabel2 => 'Claimed';

  @override
  String get launch2_launch2DynamicRewardsLabel3 => 'Confirming claim…';

  @override
  String get launch2_launch2DynamicRewardsLabel4 => 'Period';

  @override
  String get launch2_launch2DynamicRewardsLabel5 => 'My weight / total weight';

  @override
  String get launch2_launch2DynamicRewardsLabel6 => 'Round rewards';

  @override
  String get launch2_launch2DynamicRewardsLabel7 => 'Claimable';

  @override
  String get launch2_launch2DynamicRewardsLabel8 => 'Claimed so far';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsBlockedTitle =>
      'MEME v2 isn\'t available right now';

  @override
  String launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyMessage(
    Object? launch2DynamicIdleText,
  ) {
    return '$launch2DynamicIdleText. Once on, buys from any app count toward the round\'s weight. Claim here after it ends.';
  }

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyTitle =>
      'No DEX pool rewards yet';

  @override
  String
  get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityMessage =>
      'Nothing was requested and no other project was loaded instead.';

  @override
  String
  get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityTitle =>
      'The route has no usable project ID';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidRouteTitle =>
      'DEX pool rewards';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletMessage =>
      'DEX pool rewards are recorded per wallet. Activate a wallet to view and claim.';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletTitle =>
      'No wallet available';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoneMessage =>
      'Only projects with dynamic tax have per-round DEX pool rewards.';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoneTitle =>
      'This project has no DEX pool rewards';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsProvenanceDetail =>
      'Weight is each wallet\'s buy amount this round (USD1); buyback buys don\'t count. Claims follow on-chain confirmation.';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynamicNoRewardText =>
      'No rewards to claim this round';

  @override
  String launch2_launch2DynamicRewardsLaunch2SectionLabel(Object? id) {
    return 'Round $id';
  }

  @override
  String get launch2_launch2DynamicRewardsOpen =>
      'Claimable after the round ends';

  @override
  String get launch2_launch2DynamicRewardsPending =>
      'Broadcast, but no confirmation yet. It may still be confirming; check again later. Don\'t claim again.';

  @override
  String get launch2_launch2DynamicRewardsReason =>
      'The DEX pool is syncing. Try again later';

  @override
  String get launch2_launch2DynamicRewardsS => 'Nothing to claim';

  @override
  String get launch2_launch2DynamicRewardsS2 =>
      'You didn\'t buy this round, so you have no reward weight.';

  @override
  String launch2_launch2DynamicRewardsSpan(Object? start) {
    return 'From $start · in progress';
  }

  @override
  String launch2_launch2DynamicRewardsStart(Object? startCandle) {
    return 'Candle #$startCandle';
  }

  @override
  String launch2_launch2DynamicRewardsText(Object? text) {
    return 'Reporting $text failed; the on-chain result isn\'t affected. Don\'t claim again.';
  }

  @override
  String get launch2_launch2DynamicRewardsValue =>
      'Settled after the round ends';

  @override
  String get launch2_launch2FormatActivationMissing =>
      'No activation record on-chain yet; the platform is checking';

  @override
  String get launch2_launch2FormatBalance => 'Wallet balance';

  @override
  String get launch2_launch2FormatBroadcast => 'Publishing allowlist';

  @override
  String get launch2_launch2FormatClosed => 'Trading closed at this stage';

  @override
  String get launch2_launch2FormatClosedNoHolders => 'Closed';

  @override
  String get launch2_launch2FormatDeployedEventMismatch =>
      'The on-chain deploy record doesn\'t match the registration; the platform is checking';

  @override
  String get launch2_launch2FormatGraduated => 'Trading in the official pool';

  @override
  String get launch2_launch2FormatInventory => 'Bonding pool stock left';

  @override
  String launch2_launch2FormatLaunch2ActionFailure(Object? parts) {
    return 'Not enough USD1: $parts';
  }

  @override
  String launch2_launch2FormatLaunch2ActionFailure2(Object? parts) {
    return 'Sell amount exceeds holdings: $parts';
  }

  @override
  String get launch2_launch2FormatLaunch2AddressFrozenText =>
      'The USD1 issuer has restricted this project\'s contract address; trading and claims are unavailable';

  @override
  String get launch2_launch2FormatLaunch2BuybackHeldLine =>
      'Source: chain read · auto buyback';

  @override
  String get launch2_launch2FormatLaunch2ClosedNoHoldersText =>
      'No one minted, closed';

  @override
  String launch2_launch2FormatLaunch2CountdownText(
    Object? days,
    Object? two,
    Object? two2,
    Object? two3,
  ) {
    return '${days}d $two:$two2:$two3';
  }

  @override
  String launch2_launch2FormatLaunch2CurveCapSentence(
    Object? launch2CurveCapFigure,
  ) {
    return 'Each address can buy up to $launch2CurveCapFigure tokens';
  }

  @override
  String launch2_launch2FormatLaunch2GasFailureText(Object? bnb) {
    return 'this needs about $bnb';
  }

  @override
  String launch2_launch2FormatLaunch2GasFailureText2(Object? bnb) {
    return 'wallet has $bnb';
  }

  @override
  String launch2_launch2FormatLaunch2GasFailureText3(
    Object? loopLaunchNativeSymbolText,
    Object? parts,
  ) {
    return 'Not enough $loopLaunchNativeSymbolText for fees: $parts. Top up and retry';
  }

  @override
  String launch2_launch2FormatLaunch2GasShortText(
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchNativeSymbolText2,
  ) {
    return 'Not enough $loopLaunchNativeSymbolText for fees: your wallet\'s $loopLaunchNativeSymbolText2 can\'t cover this network fee. Top up and retry';
  }

  @override
  String get launch2_launch2FormatLaunch2KeeperLine => 'Auto buyback running';

  @override
  String get launch2_launch2FormatLaunch2KeeperLine2 =>
      'One on its way on-chain';

  @override
  String launch2_launch2FormatLaunch2KeeperLine3(Object? dateTimeLabel) {
    return 'Last $dateTimeLabel';
  }

  @override
  String launch2_launch2FormatLaunch2KeeperLine4(Object? reason) {
    return 'Buyback on hold: $reason';
  }

  @override
  String launch2_launch2FormatLaunch2KeeperLine5(Object? clockLabel) {
    return 'Retry at $clockLabel';
  }

  @override
  String get launch2_launch2FormatLaunch2NoMemeText =>
      'You don\'t hold this token yet';

  @override
  String get launch2_launch2FormatLaunch2NoUsd1Text =>
      'No USD1 in your wallet yet';

  @override
  String get launch2_launch2FormatLaunch2OpenedWithoutHoldersText =>
      'No NFT holders, public pool opened directly';

  @override
  String launch2_launch2FormatLaunch2QuotaExhaustedText(
    Object? launch2CurveCapFigure,
  ) {
    return 'Used up the per-address cap of $launch2CurveCapFigure tokens';
  }

  @override
  String get launch2_launch2FormatLaunch2QuoteZeroText =>
      'This amount can\'t buy the smallest unit. Try another amount';

  @override
  String launch2_launch2FormatLaunch2SaleDurationLabel(Object? hours) {
    return '${hours}d';
  }

  @override
  String launch2_launch2FormatLaunch2SaleDurationLabel2(Object? hours) {
    return '${hours}h';
  }

  @override
  String launch2_launch2FormatLaunch2SaleDurationLabel3(Object? minutes) {
    return '$minutes min';
  }

  @override
  String get launch2_launch2FormatLaunch2SnapshotPendingMessage =>
      'Waiting for the cutoff block; the 1-hour priority buy starts once the allowlist is published';

  @override
  String launch2_launch2FormatLaunch2SnapshotPendingMessage2(
    Object? groupedFigure,
  ) {
    return 'Cutoff block #$groupedFigure; the 1-hour priority buy starts once the allowlist is published';
  }

  @override
  String launch2_launch2FormatLaunch2SpokenDuration(
    Object? days,
    Object? hours,
  ) {
    return '${days}d ${hours}h';
  }

  @override
  String launch2_launch2FormatLaunch2SpokenDuration2(
    Object? hours,
    Object? minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String launch2_launch2FormatLaunch2SpokenDuration3(Object? minutes) {
    return '${minutes}m';
  }

  @override
  String get launch2_launch2FormatLaunch2SpokenDuration4 => 'Under 1m';

  @override
  String launch2_launch2FormatLaunch2TradingHoldSinceText(
    Object? localClockLabel,
  ) {
    return 'Since $localClockLabel';
  }

  @override
  String get launch2_launch2FormatLaunch2Usd1PausedText =>
      'The USD1 issuer has paused USD1; trading and claims are unavailable';

  @override
  String get launch2_launch2FormatMismatch =>
      'Allowlist publish issue; the platform is handling it';

  @override
  String get launch2_launch2FormatMismatch2 =>
      'Check mismatch; the platform is handling it';

  @override
  String get launch2_launch2FormatNftSale => 'Minting';

  @override
  String get launch2_launch2FormatNftSale2 => 'Time left';

  @override
  String get launch2_launch2FormatPaused => 'Paused';

  @override
  String get launch2_launch2FormatPending => 'Verifying';

  @override
  String get launch2_launch2FormatPriority => 'Priority buy';

  @override
  String get launch2_launch2FormatPriority2 => 'Holders first · time left';

  @override
  String get launch2_launch2FormatPublic => 'Public pool';

  @override
  String get launch2_launch2FormatPublic2 =>
      'Open to all; graduates when sold out';

  @override
  String launch2_launch2FormatQuota(Object? launch2CurveCapFigure) {
    return 'Per-address cap $launch2CurveCapFigure tokens';
  }

  @override
  String launch2_launch2FormatReason(Object? live) {
    return 'Next one on hold: $live';
  }

  @override
  String launch2_launch2FormatReason2(Object? live, Object? reason) {
    return 'Next one on hold: $live (on-chain read); $reason (auto buyback)';
  }

  @override
  String get launch2_launch2FormatReplaceAll => ', on hold';

  @override
  String get launch2_launch2FormatReplaceAll2 => ', runs shortly';

  @override
  String get launch2_launch2FormatS => 'taken from the MEME you receive';

  @override
  String launch2_launch2FormatS2(Object? localTimestampLabel) {
    return 'Since $localTimestampLabel';
  }

  @override
  String get launch2_launch2FormatS3 => 'Allowlist on-chain, syncing';

  @override
  String launch2_launch2FormatS4(Object? days) {
    return '${days}d';
  }

  @override
  String get launch2_launch2FormatSnapshotPending =>
      '1-hour priority buy starts once the allowlist is published';

  @override
  String get launch2_launch2FormatSoldSupply => 'Bonding pool sellable amount';

  @override
  String get launch2_launch2FormatSwitch =>
      'The platform is checking this project';

  @override
  String get launch2_launch2FormatSwitch10 =>
      'Legacy price protection active, on hold';

  @override
  String get launch2_launch2FormatSwitch11 => 'On hold';

  @override
  String get launch2_launch2FormatSwitch12 =>
      'Official pool principal protection: principal under 10,000 USD1 or one order over 1%';

  @override
  String get launch2_launch2FormatSwitch13 => 'Contract buyback paused';

  @override
  String get launch2_launch2FormatSwitch14 =>
      'The project hasn\'t graduated yet';

  @override
  String get launch2_launch2FormatSwitch15 =>
      'Buyback executor account isn\'t ready; the platform is handling it';

  @override
  String get launch2_launch2FormatSwitch16 =>
      'Escrow records don\'t match the chain; the platform is checking';

  @override
  String get launch2_launch2FormatSwitch17 =>
      'The trade received 0; the platform is handling it';

  @override
  String get launch2_launch2FormatSwitch18 => 'Legacy price protection active';

  @override
  String get launch2_launch2FormatSwitch19 => 'On-chain fees too high';

  @override
  String get launch2_launch2FormatSwitch2 => 'taken from the USD1 you pay';

  @override
  String get launch2_launch2FormatSwitch20 =>
      'The contract refused to execute; the platform is handling it';

  @override
  String get launch2_launch2FormatSwitch21 =>
      'The executor account is short on fees; the platform is handling it';

  @override
  String get launch2_launch2FormatSwitch22 =>
      'On-chain fees too high; retrying later';

  @override
  String get launch2_launch2FormatSwitch23 =>
      'The last one didn\'t execute; retrying later';

  @override
  String get launch2_launch2FormatSwitch24 => 'This project doesn\'t exist';

  @override
  String get launch2_launch2FormatSwitch25 =>
      'Trading isn\'t open at this stage; the project status was reloaded';

  @override
  String get launch2_launch2FormatSwitch26 =>
      'Priority buy is buy-only; selling opens with the public pool';

  @override
  String get launch2_launch2FormatSwitch27 => 'The bonding pool is sold out';

  @override
  String get launch2_launch2FormatSwitch28 => 'Used up the per-address buy cap';

  @override
  String get launch2_launch2FormatSwitch29 => 'The project is paused';

  @override
  String get launch2_launch2FormatSwitch3 => 'The next one can run';

  @override
  String get launch2_launch2FormatSwitch30 =>
      'This wallet already minted the NFT (1 per address, ever)';

  @override
  String get launch2_launch2FormatSwitch31 =>
      'The price changed and was refreshed';

  @override
  String get launch2_launch2FormatSwitch32 =>
      'The quote expired and was refreshed';

  @override
  String get launch2_launch2FormatSwitch33 => 'Not enough USD1';

  @override
  String get launch2_launch2FormatSwitch34 => 'Sell amount exceeds holdings';

  @override
  String launch2_launch2FormatSwitch35(Object? loopLaunchNativeSymbolText) {
    return 'Not enough $loopLaunchNativeSymbolText for fees. Top up and retry';
  }

  @override
  String get launch2_launch2FormatSwitch36 => 'Invalid amount';

  @override
  String get launch2_launch2FormatSwitch37 => 'Over the buy limit';

  @override
  String get launch2_launch2FormatSwitch38 =>
      'The quote changed. Get a new quote';

  @override
  String get launch2_launch2FormatSwitch39 =>
      'Only the LOOP built-in wallet can buy';

  @override
  String get launch2_launch2FormatSwitch4 => 'Buyback paused';

  @override
  String get launch2_launch2FormatSwitch40 =>
      'Priority buy is for allowlisted holders only';

  @override
  String get launch2_launch2FormatSwitch41 => 'Not available right now';

  @override
  String get launch2_launch2FormatSwitch42 =>
      'This transaction expired and nothing was submitted. Start again';

  @override
  String get launch2_launch2FormatSwitch43 =>
      'The simulation failed; this transaction would be rejected on-chain';

  @override
  String get launch2_launch2FormatSwitch44 =>
      'Approve first; the simulation can\'t run before approval';

  @override
  String get launch2_launch2FormatSwitch45 =>
      'Checking the allowlist; priority buy is unavailable';

  @override
  String get launch2_launch2FormatSwitch46 =>
      'The MEME v2 contract isn\'t configured yet';

  @override
  String get launch2_launch2FormatSwitch47 =>
      'The MEME v2 service isn\'t available right now';

  @override
  String get launch2_launch2FormatSwitch48 =>
      'Couldn\'t read on-chain data right now';

  @override
  String get launch2_launch2FormatSwitch49 =>
      'Couldn\'t load the wallet directory right now';

  @override
  String get launch2_launch2FormatSwitch5 => 'Buyback starts after graduation';

  @override
  String get launch2_launch2FormatSwitch50 => 'Trading is closed for now';

  @override
  String get launch2_launch2FormatSwitch51 => 'Mainnet signing isn\'t open yet';

  @override
  String get launch2_launch2FormatSwitch52 => 'MEME v2 isn\'t open yet';

  @override
  String get launch2_launch2FormatSwitch53 => 'Over the per-transaction limit';

  @override
  String get launch2_launch2FormatSwitch54 => 'Over today\'s limit';

  @override
  String get launch2_launch2FormatSwitch55 =>
      'This transaction isn\'t allowed right now';

  @override
  String launch2_launch2FormatSwitch56(Object? usd1) {
    return 'need $usd1';
  }

  @override
  String launch2_launch2FormatSwitch57(Object? usd1) {
    return 'have $usd1';
  }

  @override
  String launch2_launch2FormatSwitch58(Object? usd1) {
    return 'can pay up to $usd1';
  }

  @override
  String launch2_launch2FormatSwitch59(Object? meme) {
    return 'need $meme';
  }

  @override
  String get launch2_launch2FormatSwitch6 => 'Escrow balance below one order';

  @override
  String launch2_launch2FormatSwitch60(Object? meme) {
    return 'holding $meme';
  }

  @override
  String launch2_launch2FormatSwitch61(Object? meme) {
    return 'can sell up to $meme';
  }

  @override
  String get launch2_launch2FormatSwitch62 => 'NFT allowlist published';

  @override
  String get launch2_launch2FormatSwitch7 =>
      'Less than 10 seconds since the last one, runs shortly';

  @override
  String get launch2_launch2FormatSwitch8 =>
      'Official pool principal protection: principal under 10,000 USD1 or one order over 1%';

  @override
  String get launch2_launch2FormatSwitch9 =>
      'Couldn\'t read the contract quote, on hold';

  @override
  String get launch2_launch2FormatUpcoming => 'Minting soon';

  @override
  String get launch2_launch2FormatUpcoming2 => 'Mint countdown';

  @override
  String get launch2_launch2FormatVerified => 'Verified';

  @override
  String get launch2_launch2FullChartLaunch2ChartFullBlockedTitle =>
      'Full-screen chart';

  @override
  String get launch2_launch2FullChartLaunch2ChartFullInvalidTitle =>
      'Couldn\'t open this chart';

  @override
  String launch2_launch2Graduated(Object? launch2PriceLabel) {
    return 'Graduation price $launch2PriceLabel';
  }

  @override
  String launch2_launch2HeroLaunch2RecordFoot(
    Object? launch2HeroDetail,
    Object? past,
  ) {
    return '$past% of mint period passed · $launch2HeroDetail';
  }

  @override
  String get launch2_launch2HeroNftSale => 'Consensus medal minting';

  @override
  String launch2_launch2HeroNftSale2(Object? perNft, Object? soldCount) {
    return '$soldCount minted · $perNft';
  }

  @override
  String launch2_launch2HeroNftSale3(Object? perNft, Object? soldCount) {
    return '$soldCount minted · $perNft. Holders join the snapshot allowlist; a 1-hour priority buy follows its publication.';
  }

  @override
  String launch2_launch2HeroNftSale4(
    Object? launch2SaleDurationLabel,
    Object? launch2ShortDateTime,
  ) {
    return 'Mint period $launch2SaleDurationLabel · ends $launch2ShortDateTime';
  }

  @override
  String get launch2_launch2HeroNftSale5 => 'Mint ends in';

  @override
  String launch2_launch2HeroPerNft(Object? launch2Usd1Label) {
    return '$launch2Usd1Label each';
  }

  @override
  String get launch2_launch2HeroPriority => 'Priority buy live';

  @override
  String launch2_launch2HeroPriority2(
    Object? launch2BpsLabel,
    Object? launch2HeroPrice,
  ) {
    return 'Bonding pool $launch2BpsLabel sold · $launch2HeroPrice';
  }

  @override
  String launch2_launch2HeroPriority3(
    Object? launch2BpsLabel,
    Object? launch2HeroPrice,
    Object? soldCount,
  ) {
    return '$soldCount minted · bonding pool $launch2BpsLabel sold · $launch2HeroPrice';
  }

  @override
  String get launch2_launch2HeroPriority4 => 'Priority buy ends in';

  @override
  String launch2_launch2HeroPublic(Object? launch2HeroPrice) {
    return '$launch2HeroPrice · graduates when sold out';
  }

  @override
  String launch2_launch2HeroPublic2(Object? launch2HeroPrice) {
    return '$launch2HeroPrice · graduates at 800M sold';
  }

  @override
  String launch2_launch2HeroS(Object? left) {
    return 'Mint in $left';
  }

  @override
  String launch2_launch2HeroS2(Object? launch2ShortDateTime) {
    return 'Priority buy live · ends $launch2ShortDateTime';
  }

  @override
  String get launch2_launch2HeroSnapshotPending =>
      '1-hour priority buy after the allowlist is published';

  @override
  String get launch2_launch2HeroSwitch => 'Bonding pool sprint';

  @override
  String get launch2_launch2HeroSwitch2 => 'Mint time TBD';

  @override
  String launch2_launch2HeroSwitch3(Object? left) {
    return 'Ends in $left';
  }

  @override
  String launch2_launch2HeroSwitch4(Object? soldCount) {
    return '$soldCount minted';
  }

  @override
  String launch2_launch2HeroSwitch5(Object? launch2BpsLabel) {
    return 'Bonding pool $launch2BpsLabel sold';
  }

  @override
  String get launch2_launch2HeroSwitch6 => 'Bonding pool progress';

  @override
  String launch2_launch2HeroUpcoming(
    Object? launch2SaleDurationLabel,
    Object? perNft,
  ) {
    return '$perNft · mint period $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2HeroUpcoming2(
    Object? launch2SaleDurationLabel,
    Object? launch2ShortDateTime,
    Object? perNft,
  ) {
    return 'Mint starts $launch2ShortDateTime · $perNft · mint period $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2HeroUpcoming3(Object? launch2ShortDateTime) {
    return 'Mint starts $launch2ShortDateTime';
  }

  @override
  String get launch2_launch2HeroUpcoming4 => 'Mint in';

  @override
  String launch2_launch2InstanceAside(Object? launch2Usd1Label) {
    return '24h vol $launch2Usd1Label';
  }

  @override
  String get launch2_launch2InstanceBody =>
      'Every v2 project uses the same parameters; project owners can\'t change them.';

  @override
  String launch2_launch2InstanceBody2(
    Object? launch2MemeCompact,
    Object? launch2Usd1Label,
  ) {
    return 'Medal mint ($launch2Usd1Label each, 1 per address, ever) → snapshot allowlist and 1-hour priority buy → public pool. Selling out $launch2MemeCompact tokens in any round builds the official pool and graduates.';
  }

  @override
  String get launch2_launch2InstanceBody3 =>
      'Each address can mint only 1, ever. Addresses holding a medal when minting ends join the snapshot allowlist, with a 1-hour priority buy after it\'s published.';

  @override
  String launch2_launch2InstanceBody4(
    Object? launch2BpsLabel,
    Object? tickSpacing,
  ) {
    return 'LP fee $launch2BpsLabel, tickSpacing $tickSpacing';
  }

  @override
  String launch2_launch2InstanceBody5(
    Object? buybackMinIntervalSeconds,
    Object? launch2Usd1Label,
  ) {
    return '$launch2Usd1Label per order, at least $buybackMinIntervalSeconds seconds apart. Skipped when the official pool\'s USD1 principal is under 10,000 or an order exceeds 1% of it; refused attempts leave no record.';
  }

  @override
  String get launch2_launch2InstanceBuild => 'Mint progress';

  @override
  String get launch2_launch2InstanceBuild2 => 'Latest';

  @override
  String get launch2_launch2InstanceLabel => 'Bonding pool';

  @override
  String get launch2_launch2InstanceLabel2 => 'Graduation reserve';

  @override
  String get launch2_launch2InstanceLabel3 => 'Bonding pool trade tax';

  @override
  String get launch2_launch2InstanceLabel4 => 'DEX pool tax';

  @override
  String get launch2_launch2InstanceLabel5 => 'Per-address cap';

  @override
  String get launch2_launch2InstanceLabel6 => 'Price each';

  @override
  String get launch2_launch2InstanceLabel7 => 'Graduated at';

  @override
  String get launch2_launch2InstanceLabel8 => 'Graduation price';

  @override
  String get launch2_launch2InstanceLaunch2BuyNftLabel => 'Medal held';

  @override
  String get launch2_launch2InstanceLaunch2BuyNftLabel2 => 'Mint medal';

  @override
  String get launch2_launch2InstanceLaunch2BuybackEscrowLabel =>
      'Escrow balance';

  @override
  String get launch2_launch2InstanceLaunch2BuybackInfoLabel => 'About buybacks';

  @override
  String get launch2_launch2InstanceLaunch2BuybackLatestValue => 'None yet';

  @override
  String launch2_launch2InstanceLaunch2BuybackLiveUnavailableMessage(
    Object? launch2ReasonText,
  ) {
    return 'Couldn\'t read live on-chain data · $launch2ReasonText';
  }

  @override
  String get launch2_launch2InstanceLaunch2BuybackNextLabel => 'Next';

  @override
  String get launch2_launch2InstanceLaunch2BuybackNotBurnBody =>
      'Tokens bought back go to the project\'s registered recipient address; they aren\'t burned.';

  @override
  String get launch2_launch2InstanceLaunch2BuybackNotBurnTitle =>
      'Buyback isn\'t a burn';

  @override
  String get launch2_launch2InstanceLaunch2BuybackTotalLabel =>
      'Total bought back';

  @override
  String launch2_launch2InstanceLaunch2BuybackTotalValue(
    Object? executedCount,
    Object? launch2Usd1Label,
  ) {
    return '$launch2Usd1Label · orders: $executedCount';
  }

  @override
  String launch2_launch2InstanceLaunch2BuybackUnavailableMessage(
    Object? chainFailureReason,
  ) {
    return 'Couldn\'t load buyback details · $chainFailureReason';
  }

  @override
  String launch2_launch2InstanceLaunch2CurveSupply(
    Object? launch2MemeCompact,
    Object? launch2MemeCompact2,
  ) {
    return 'Sold $launch2MemeCompact / $launch2MemeCompact2; graduates to the official pool when sold out';
  }

  @override
  String get launch2_launch2InstanceLaunch2EvidencePendingMessage =>
      'Checking the contract; trading may be unavailable';

  @override
  String get launch2_launch2InstanceLaunch2InvalidRouteTitle =>
      'Couldn\'t open this project';

  @override
  String get launch2_launch2InstanceLaunch2MineOnlyToggle =>
      'My DEX pool trades';

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesEmptyMessage =>
      'Trades are still syncing. Refresh later';

  @override
  String launch2_launch2InstanceLaunch2MyPoolTradesFailedMessage(
    Object? chainFailureReason,
  ) {
    return 'Couldn\'t load my DEX pool trades · $chainFailureReason';
  }

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesNoWalletMessage =>
      'Activate a wallet to see only your trades';

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesNoneTitle =>
      'You have no DEX pool trades yet';

  @override
  String launch2_launch2InstanceLaunch2MyPoolTradesProvenanceDetail(
    Object? launch2MyPoolTradesShown,
  ) {
    return 'Only trades routed through the official pool, latest $launch2MyPoolTradesShown; amounts are after the 2% DEX pool tax.';
  }

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesUnsupportedMessage =>
      'Couldn\'t load my DEX pool trades';

  @override
  String launch2_launch2InstanceLaunch2NftEnd(Object? dateTimeLabel) {
    return 'Ends $dateTimeLabel';
  }

  @override
  String get launch2_launch2InstanceLaunch2NftHeldLabel => 'I hold';

  @override
  String get launch2_launch2InstanceLaunch2NftInfo => 'Project NFT';

  @override
  String get launch2_launch2InstanceLaunch2NftInfoLabel =>
      'About the project NFT';

  @override
  String get launch2_launch2InstanceLaunch2NftOpenLabel => 'Mint page';

  @override
  String launch2_launch2InstanceLaunch2OpenedWithoutHoldersBody(
    Object? launch2OpenedWithoutHoldersText,
  ) {
    return '$launch2OpenedWithoutHoldersText; priority buy skipped.';
  }

  @override
  String get launch2_launch2InstanceLaunch2PoolIdTitle =>
      'Pool ID (Uniswap v4, no pool address)';

  @override
  String get launch2_launch2InstanceLaunch2PoolInfo => 'Official pool';

  @override
  String get launch2_launch2InstanceLaunch2PoolInfoLabel =>
      'About the official pool';

  @override
  String get launch2_launch2InstanceLaunch2PoolTaxBody =>
      'Charged on every official pool buy and sell; the Hook adds it to buyback escrow for rule-based buybacks.';

  @override
  String launch2_launch2InstanceLaunch2PoolTaxTitle(Object? launch2BpsLabel) {
    return 'DEX pool tax $launch2BpsLabel';
  }

  @override
  String get launch2_launch2InstanceLaunch2PoolTradesEmptyTitle =>
      'No DEX pool trades yet';

  @override
  String launch2_launch2InstanceLaunch2PoolTradesFailedMessage(Object? state) {
    return 'Couldn\'t load DEX pool trades · $state';
  }

  @override
  String launch2_launch2InstanceLaunch2PoolTradesProvenanceDetail(
    Object? launch2RecentPoolTradesLimit,
  ) {
    return 'Latest $launch2RecentPoolTradesLimit official pool trades, excluding buybacks; sell amounts are received after tax.';
  }

  @override
  String get launch2_launch2InstanceLaunch2TemplateInfo => 'Launch rules';

  @override
  String get launch2_launch2InstanceLaunch2TemplateInfoLabel =>
      'About launch rules';

  @override
  String get launch2_launch2InstanceLaunch2TemplateRiskTitle => 'Risks';

  @override
  String get launch2_launch2InstanceLaunch2TradeSheetBarrierLabel =>
      'Close trade panel';

  @override
  String get launch2_launch2InstanceLaunch2TradesProvenanceDetail =>
      'Latest 20 bonding pool trades; amounts include the 10% tax.';

  @override
  String get launch2_launch2InstanceLoopBadge => 'You\'re the owner';

  @override
  String get launch2_launch2InstanceLoopLabel => 'Medal mint';

  @override
  String get launch2_launch2InstanceLoopLabel2 => 'Latest trades';

  @override
  String get launch2_launch2InstanceLoopProvenanceLine => 'LOOP on-chain index';

  @override
  String get launch2_launch2InstanceMessage => 'Token address copied';

  @override
  String get launch2_launch2InstanceMessage2 =>
      'No one minted during the mint period. This project uses a legacy contract, so no allowlist can be built and priority buy and the public pool won\'t start.';

  @override
  String launch2_launch2InstanceNftSale(Object? soldCount) {
    return '1 per address · $soldCount minted';
  }

  @override
  String get launch2_launch2InstancePartsBuild => 'Current price (USD1)';

  @override
  String get launch2_launch2InstancePartsBuild2 => 'My holdings';

  @override
  String launch2_launch2InstancePartsBuild3(
    Object? launch2PriceLabel,
    Object? launch2TradeTimeLabel,
  ) {
    return '$launch2TradeTimeLabel · price $launch2PriceLabel';
  }

  @override
  String get launch2_launch2InstancePartsBuyback => 'Buyback';

  @override
  String get launch2_launch2InstancePartsEmptyText => 'No trade price yet';

  @override
  String get launch2_launch2InstancePartsInfo => 'Info';

  @override
  String get launch2_launch2InstancePartsLabel => 'Value';

  @override
  String get launch2_launch2InstancePartsLabel2 => 'Cost price';

  @override
  String get launch2_launch2InstancePartsLabel3 => 'Mine only';

  @override
  String get launch2_launch2InstancePartsLaunch2CopyAddressLabel =>
      'Copy token address';

  @override
  String launch2_launch2InstancePartsLaunch2DynStripLineLabel(
    Object? line,
    Object? state,
  ) {
    return 'This round, $state, $line';
  }

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPartialNoteBody =>
      'Some holdings were transferred in on-chain without a cost record; cost price and P&L only cover the part with cost records.';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPartialNoteTitle =>
      'Some holdings have no cost record';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPnlInfoLabel => 'P&L';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPnlInfoTitle =>
      'Holding P&L';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingRealizedNoteTitle =>
      'Realized P&L';

  @override
  String launch2_launch2InstancePartsPot(Object? launch2Usd1Label) {
    return 'Reward pool $launch2Usd1Label';
  }

  @override
  String launch2_launch2InstancePartsS(Object? launch2BpsLabel) {
    return 'Drop $launch2BpsLabel';
  }

  @override
  String get launch2_launch2InstancePartsText => 'Anonymous';

  @override
  String get launch2_launch2InstancePartsTrades => 'Trades';

  @override
  String get launch2_launch2InstancePriority => 'Holders first';

  @override
  String get launch2_launch2InstanceRows => 'Mint starts';

  @override
  String get launch2_launch2InstanceRows2 => 'Mint price';

  @override
  String get launch2_launch2InstanceRows3 => 'Mint duration';

  @override
  String get launch2_launch2InstanceRows4 => 'Minted';

  @override
  String launch2_launch2InstanceRows5(Object? soldCount) {
    return '$soldCount';
  }

  @override
  String get launch2_launch2InstanceRows6 => 'My NFT';

  @override
  String get launch2_launch2InstanceRows7 => 'Wallet not activated';

  @override
  String get launch2_launch2InstanceRows8 => 'Cutoff block';

  @override
  String get launch2_launch2InstanceRows9 => 'Closed at';

  @override
  String launch2_launch2InstanceS(Object? elapsed) {
    return '$elapsed% passed';
  }

  @override
  String launch2_launch2InstanceSemanticLabel(Object? elapsedText) {
    return 'Mint time $elapsedText';
  }

  @override
  String launch2_launch2InstanceSemanticLabel2(Object? launch2BpsLabel) {
    return 'Bonding pool progress $launch2BpsLabel';
  }

  @override
  String get launch2_launch2InstanceSwitch =>
      'The last one is still confirming on-chain. Trade after it confirms';

  @override
  String launch2_launch2InstanceText(Object? noun) {
    return 'Your $noun is confirmed on-chain.';
  }

  @override
  String launch2_launch2InstanceText2(Object? noun) {
    return 'Your DEX pool $noun is confirmed on-chain.';
  }

  @override
  String launch2_launch2InstanceText3(Object? noun) {
    return 'The official pool recorded a new trade, so your DEX pool $noun should be confirmed; your wallet balance is the final amount.';
  }

  @override
  String launch2_launch2InstanceText4(Object? launch2IntentNoun) {
    return 'Broadcast, but no confirmation yet. It may still be confirming; check again later. Don\'t submit the $launch2IntentNoun again.';
  }

  @override
  String get launch2_launch2InstanceText5 =>
      'You\'re seeing the project page as users see it';

  @override
  String get launch2_launch2InstanceTitle => 'Fixed by the platform template';

  @override
  String get launch2_launch2InstanceTitle2 => 'Three-stage launch';

  @override
  String get launch2_launch2InstanceTitle3 => 'All DEX pool trades';

  @override
  String get launch2_launch2InstanceTitle4 => 'Fees';

  @override
  String get launch2_launch2InstanceTitle5 => 'Rules';

  @override
  String get launch2_launch2InstanceTitle6 => 'Recipient address';

  @override
  String launch2_launch2InstanceUpcoming(
    Object? launch2SaleDurationLabel,
    Object? launch2Usd1Label,
  ) {
    return '$launch2Usd1Label each · mint period $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2InstanceValue(
    Object? launch2BpsLabel,
    Object? launch2CurveCapFigure,
  ) {
    return '$launch2CurveCapFigure tokens ($launch2BpsLabel)';
  }

  @override
  String launch2_launch2InstanceZero(Object? groupedFigure) {
    return 'My DEX pool trades · $groupedFigure total';
  }

  @override
  String get launch2_launch2Label => 'Top up';

  @override
  String get launch2_launch2Label2 => 'Get funds';

  @override
  String get launch2_launch2Launch2SnapshotExplorerLabel =>
      'View publish transaction on BscScan';

  @override
  String get launch2_launch2Launch2SnapshotMembersLabel => 'Allowlist size';

  @override
  String launch2_launch2Launch2SnapshotMembersValue(Object? members) {
    return '$members';
  }

  @override
  String get launch2_launch2Launch2SnapshotPublishedAtLabel => 'Published';

  @override
  String get launch2_launch2Launch2SnapshotTxLabel => 'Publish transaction';

  @override
  String get launch2_launch2Launch2SnapshotVerificationLabel => 'Verification';

  @override
  String get launch2_launch2LaunchpadBuild => 'TBD';

  @override
  String launch2_launch2LaunchpadBuyback(Object? ticker, Object? usd1) {
    return 'Platform bought back $ticker$usd1';
  }

  @override
  String get launch2_launch2LaunchpadClosed => 'Paused / no mints';

  @override
  String launch2_launch2LaunchpadCurveBuy(
    Object? ticker,
    Object? usd1,
    Object? who,
  ) {
    return '${who}bought $ticker$usd1';
  }

  @override
  String launch2_launch2LaunchpadCurveSell(
    Object? ticker,
    Object? usd1,
    Object? who,
  ) {
    return '${who}sold $ticker$usd1';
  }

  @override
  String launch2_launch2LaunchpadGraduated(Object? ticker) {
    return '$ticker graduated';
  }

  @override
  String launch2_launch2LaunchpadLaunch2DeskKicker(
    Object? loopTestnetStampText,
  ) {
    return 'Launchpad · $loopTestnetStampText';
  }

  @override
  String launch2_launch2LaunchpadLaunch2RelativeTime(Object? inMinutes) {
    return '${inMinutes}m ago';
  }

  @override
  String get launch2_launch2LaunchpadLaunch2TapeActor => 'Someone';

  @override
  String get launch2_launch2LaunchpadLaunch2TapeFaceName => 'This user';

  @override
  String get launch2_launch2LaunchpadLoopLabel => 'Live trades';

  @override
  String launch2_launch2LaunchpadNftMint(Object? ticker, Object? who) {
    return '${who}minted the $ticker medal';
  }

  @override
  String launch2_launch2LaunchpadRewardClaimed(
    Object? ticker,
    Object? usd1,
    Object? who,
  ) {
    return '${who}claimed $ticker rewards$usd1';
  }

  @override
  String launch2_launch2LaunchpadRoundActivated(Object? ticker) {
    return 'New $ticker DEX pool round active';
  }

  @override
  String get launch2_launch2LaunchpadS => 'Launchpad · BSC';

  @override
  String get launch2_launch2LaunchpadSemantics => 'Campaigns';

  @override
  String get launch2_launch2LaunchpadTitle => 'No launches in progress';

  @override
  String get launch2_launch2LaunchpadUpcoming => 'Upcoming';

  @override
  String get launch2_launch2ListEmptyMessage => 'No v2 projects yet';

  @override
  String get launch2_launch2ListIf => 'Can\'t reach LOOP right now';

  @override
  String get launch2_launch2ListLabel => 'See live launches';

  @override
  String get launch2_launch2ListLabel2 => 'See classic launches';

  @override
  String get launch2_launch2ListLaunch2LiveEmptyMessage =>
      'No projects minting or in the bonding pool right now';

  @override
  String launch2_launch2ListMessage(Object? launch2CapabilityText) {
    return 'MEME v2 isn\'t available right now · $launch2CapabilityText';
  }

  @override
  String get launch2_launch2ListS => 'MEME v2 status not loaded yet';

  @override
  String get launch2_launch2ListTitle => 'v2 launch';

  @override
  String get launch2_launch2ListTitle2 => 'No graduated v2 projects yet';

  @override
  String get launch2_launch2NftBarrierLabel => 'Close NFT picker';

  @override
  String get launch2_launch2NftButtonLabel => 'Mint opens at start';

  @override
  String get launch2_launch2NftButtonLabel2 => 'Held · 1 per address';

  @override
  String launch2_launch2NftButtonLabel3(Object? launch2Usd1Label) {
    return 'Mint 1 · $launch2Usd1Label';
  }

  @override
  String get launch2_launch2NftButtonLabel4 => 'Activate a wallet to mint';

  @override
  String get launch2_launch2NftButtonLabel5 => 'Waiting for allowlist';

  @override
  String get launch2_launch2NftButtonLabel6 => 'Minting ended';

  @override
  String get launch2_launch2NftButtonLabel7 => 'Go to project page';

  @override
  String get launch2_launch2NftCardSemantics => 'Default image';

  @override
  String get launch2_launch2NftEntry => 'Join the snapshot allowlist';

  @override
  String get launch2_launch2NftEntry2 =>
      'Hold it when minting ends to join the snapshot allowlist, with a 1-hour bonding pool priority buy after it\'s published';

  @override
  String get launch2_launch2NftEntry3 => 'Escrow and buyback';

  @override
  String launch2_launch2NftEntry4(Object? launch2Usd1Label) {
    return 'Mint payments go to this project\'s escrow contract; after graduation the platform buys back MEME at $launch2Usd1Label per order';
  }

  @override
  String get launch2_launch2NftEntry5 => '1 per address';

  @override
  String launch2_launch2NftEntry6(Object? launch2Usd1Label) {
    return 'Each address can mint only 1, ever · $launch2Usd1Label each';
  }

  @override
  String launch2_launch2NftEntry7(Object? launch2SaleDurationLabel) {
    return 'Mint period $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2NftIf(Object? tokenId) {
    return '#$tokenId · on the snapshot allowlist';
  }

  @override
  String launch2_launch2NftIf2(Object? tokenId) {
    return '#$tokenId · on the candidate list';
  }

  @override
  String launch2_launch2NftLaunch2NftMedalPictureLabel(
    Object? bottomLabel,
    Object? ticker,
  ) {
    return '$ticker consensus medal, $bottomLabel';
  }

  @override
  String get launch2_launch2NftLaunch2NftMintedToast =>
      'Minted · joins the allowlist when minting ends';

  @override
  String get launch2_launch2NftLaunch2NftProvenanceDetail =>
      'Stages and countdowns come from the server on chain time and reload when due.';

  @override
  String get launch2_launch2NftLoopLabel => 'What this medal does';

  @override
  String get launch2_launch2NftLoopLabel2 => 'My medal';

  @override
  String get launch2_launch2NftLoopLabel3 => 'Choose an NFT to send';

  @override
  String launch2_launch2NftMintConfirmLabel(Object? noun) {
    return 'Continue to $noun';
  }

  @override
  String launch2_launch2NftMintHeading(Object? noun, Object? ticker) {
    return '$noun $ticker consensus medal';
  }

  @override
  String get launch2_launch2NftMintLaunch2ActionFailure =>
      'No wallet available. Activate a wallet before minting';

  @override
  String get launch2_launch2NftMintNoun => 'mint';

  @override
  String get launch2_launch2NftS => 'Consensus medal';

  @override
  String launch2_launch2NftSale(Object? left, Object? soldCount) {
    return 'Minted $soldCount$left';
  }

  @override
  String launch2_launch2NftStatus(Object? launch2SnapshotPendingTitle) {
    return 'Minting ended · $launch2SnapshotPendingTitle';
  }

  @override
  String get launch2_launch2NftStatus2 =>
      'No one minted during the mint period; went straight to the public round';

  @override
  String get launch2_launch2NftStatus3 => 'Bonding pool open';

  @override
  String get launch2_launch2NftStatus4 =>
      'No one minted during the mint period; the project is closed';

  @override
  String get launch2_launch2NftText =>
      'Broadcast, but no confirmation yet. It may still be confirming; check again later. Don\'t mint again.';

  @override
  String get launch2_launch2NftToProject => 'Trade on project page';

  @override
  String get launch2_launch2PoolTradePanelLaunch2DynPanelNote =>
      'Buys from any app count toward rewards, credited to the address receiving the MEME';

  @override
  String get launch2_launch2PoolTradePanelLaunch2GoSwapLabel =>
      'Or trade in Wallet Swap';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolMaxLabel =>
      'Fill max sellable';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolModeCaption =>
      'Input mode';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolSlippageCustomLabel =>
      'Custom';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolTaxLabel =>
      'DEX pool trade';

  @override
  String get launch2_launch2PoolTradePanelLoopProvenanceLine =>
      'Official pool router';

  @override
  String launch2_launch2PoolViewModelBase(Object? launch2BpsLabel) {
    return 'Base tax $launch2BpsLabel';
  }

  @override
  String get launch2_launch2PoolViewModelConfirmLabel => 'Confirming last one…';

  @override
  String get launch2_launch2PoolViewModelConfirmLabel2 => 'Confirm buy';

  @override
  String get launch2_launch2PoolViewModelConfirmLabel3 => 'Confirm sell';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText =>
      'Pay (incl. tax)';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText2 =>
      'Want to buy';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText3 =>
      'Want to receive';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText4 =>
      'Pay amount';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText5 =>
      'Buy amount';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText6 =>
      'Sell amount';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText7 =>
      'Get amount';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine => 'Estimated payment';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine2 => 'Maximum payment';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine3 => 'Average price';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolLine4(
    Object? launch2BuyFeeSideText,
    Object? rate,
  ) {
    return 'Base tax $rate ($launch2BuyFeeSideText)';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine5 =>
      'This trade earns reward weight';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine6 => 'Reward weight';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine7 =>
      'Not active now, no rewards';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolLine8(
    Object? base,
    Object? launch2BpsLabel,
  ) {
    return '$base + current dynamic tax $launch2BpsLabel (from USD1)';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine9 =>
      'Of which dynamic tax';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolSlippageFromInput(
    Object? launch2MemeLabel,
    Object? usd1,
  ) {
    return '$launch2MemeLabel · pay $usd1';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView =>
      'Official pool info is still syncing; trading isn\'t available yet';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView2 =>
      'DEX pool trading isn\'t open yet (router not configured)';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView3 =>
      'No wallet available. Activate a wallet to trade';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolTradeView4(
    Object? launch2MemeLabel,
  ) {
    return 'Sell amount exceeds sellable $launch2MemeLabel';
  }

  @override
  String launch2_launch2PoolViewModelLaunch2PoolTradeView5(
    Object? usd1,
    Object? usd12,
  ) {
    return 'Not enough USD1: needs up to $usd1, wallet has $usd12';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView6 =>
      'Getting a quote from the official pool…';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolTradeView7(
    Object? launch2MemeLabel,
  ) {
    return 'Holding $launch2MemeLabel';
  }

  @override
  String launch2_launch2PoolViewModelNull(Object? launch2PoolFailureText) {
    return 'Couldn\'t get a quote · $launch2PoolFailureText';
  }

  @override
  String launch2_launch2PoolViewModelProvenance(
    Object? quote,
    Object? quotedAtBlock,
  ) {
    return 'Based on the official pool at block $quotedAtBlock, $quote; re-quotes automatically when it expires.';
  }

  @override
  String launch2_launch2PoolViewModelProvenance2(
    Object? launch2BpsLabel,
    Object? quotedAtBlock,
  ) {
    return 'Based on the official pool at block $quotedAtBlock, after the $launch2BpsLabel DEX pool tax; re-quotes automatically when it expires.';
  }

  @override
  String get launch2_launch2PoolViewModelS =>
      'DEX pool router not configured; trading unavailable';

  @override
  String get launch2_launch2PoolViewModelS10 =>
      'The pool doesn\'t support this trade type';

  @override
  String get launch2_launch2PoolViewModelS11 =>
      'The pool is busy. Try again later';

  @override
  String get launch2_launch2PoolViewModelS12 =>
      'This round hasn\'t ended; claim after it ends';

  @override
  String get launch2_launch2PoolViewModelS13 =>
      'This round\'s rewards were already claimed';

  @override
  String get launch2_launch2PoolViewModelS14 =>
      'This claim already recorded another transaction';

  @override
  String get launch2_launch2PoolViewModelS15 =>
      'Couldn\'t find this claim request';

  @override
  String get launch2_launch2PoolViewModelS16 => 'Estimated to receive';

  @override
  String get launch2_launch2PoolViewModelS17 => 'Minimum received';

  @override
  String get launch2_launch2PoolViewModelS18 => 'Estimated sell';

  @override
  String get launch2_launch2PoolViewModelS19 => 'Maximum sell';

  @override
  String get launch2_launch2PoolViewModelS2 =>
      'DEX pool router check failed; trading unavailable';

  @override
  String launch2_launch2PoolViewModelS20(
    Object? launch2MemeLabel,
    Object? launch2MemeLabel2,
    Object? tickerLabel,
  ) {
    return 'Not enough $tickerLabel: needs up to $launch2MemeLabel, wallet has $launch2MemeLabel2';
  }

  @override
  String get launch2_launch2PoolViewModelS21 =>
      'Enter an amount to see a quote';

  @override
  String launch2_launch2PoolViewModelS22(
    Object? launch2MemeLabel,
    Object? launch2MemeLabel2,
  ) {
    return 'Holding $launch2MemeLabel · sellable $launch2MemeLabel2';
  }

  @override
  String launch2_launch2PoolViewModelS23(
    Object? launch2MemeLabel,
    Object? usd1,
  ) {
    return '$launch2MemeLabel · get $usd1';
  }

  @override
  String get launch2_launch2PoolViewModelS3 =>
      'DEX pool router doesn\'t match the pool; trading unavailable';

  @override
  String get launch2_launch2PoolViewModelS4 =>
      'DEX pool check failed; trading unavailable';

  @override
  String get launch2_launch2PoolViewModelS5 =>
      'The DEX pool isn\'t initialized yet';

  @override
  String get launch2_launch2PoolViewModelS6 =>
      'This pool only supports trading by payment amount';

  @override
  String get launch2_launch2PoolViewModelS7 =>
      'This project\'s DEX pool has no reward rounds';

  @override
  String get launch2_launch2PoolViewModelS8 => 'Invalid round number';

  @override
  String get launch2_launch2PoolViewModelS9 =>
      'The pool rejected this trade entry';

  @override
  String get launch2_launch2PoolViewModelSwitch =>
      'The official pool simulation failed. Try another amount';

  @override
  String get launch2_launch2PoolViewModelSwitch2 =>
      'The project hasn\'t graduated; the official pool isn\'t open yet';

  @override
  String get launch2_launch2PoolViewModelSwitch3 =>
      'Not enough liquidity in the official pool. Try a smaller amount';

  @override
  String get launch2_launch2PoolViewModelSwitch4 =>
      'This amount is too small and converts to 0';

  @override
  String get launch2_launch2PoolViewModelSwitch5 =>
      'DEX pool trading is closed while the platform checks the official pool';

  @override
  String get launch2_launch2PoolViewModelSwitch6 =>
      'Not enough USD1; no transaction was made';

  @override
  String get launch2_launch2PoolViewModelSwitch7 =>
      'Sell amount exceeds holdings; no transaction was made';

  @override
  String launch2_launch2PoolViewModelTaxLabel(Object? launch2BpsLabel) {
    return '$launch2BpsLabel + dyn. tax';
  }

  @override
  String get launch2_launch2PoolViewModelText =>
      'Couldn\'t load wallet balance · shown after quote';

  @override
  String launch2_launch2PoolViewModelText2(Object? launch2MemeLabel) {
    return 'Bonding pool net buys $launch2MemeLabel · wallet balance shown after quote';
  }

  @override
  String launch2_launch2Public(
    Object? launch2BpsLabel,
    Object? launch2PriceLabel,
  ) {
    return 'Bonding pool progress $launch2BpsLabel, current price $launch2PriceLabel';
  }

  @override
  String get launch2_launch2SigningActive => 'Confirm in your wallet';

  @override
  String get launch2_launch2SigningConfirmLabel => 'Continue to mint';

  @override
  String launch2_launch2SigningCurve(Object? noun) {
    return 'Confirm $noun';
  }

  @override
  String get launch2_launch2SigningFailed => 'Not completed';

  @override
  String launch2_launch2SigningHeading(Object? ticker) {
    return 'Mint $ticker consensus medal';
  }

  @override
  String launch2_launch2SigningIf(
    Object? launch2BpsLabel,
    Object? launch2BpsLabel2,
  ) {
    return 'Base tax $launch2BpsLabel + dynamic tax $launch2BpsLabel2';
  }

  @override
  String launch2_launch2SigningIf2(
    Object? launch2BpsLabel,
    Object? launch2BuyFeeSideText,
  ) {
    return 'Base tax $launch2BpsLabel ($launch2BuyFeeSideText)';
  }

  @override
  String launch2_launch2SigningIf3(Object? launch2ShortAddress, Object? noun) {
    return 'Approval broadcast ($launch2ShortAddress), but the wallet result of the $noun transaction is unknown, so it\'s locked. Don\'t sign again; refresh later.';
  }

  @override
  String launch2_launch2SigningIf4(Object? noun) {
    return 'The wallet result is unknown, so this $noun is locked. Don\'t sign again; refresh later.';
  }

  @override
  String launch2_launch2SigningIf5(Object? launch2ShortAddress) {
    return 'Broadcast ($launch2ShortAddress). Broadcast doesn\'t mean filled; this updates after on-chain confirmation.';
  }

  @override
  String launch2_launch2SigningIntentField(Object? meme) {
    return 'Buy $meme in the official pool';
  }

  @override
  String launch2_launch2SigningIntentField2(Object? meme) {
    return 'Sell $meme in the official pool';
  }

  @override
  String get launch2_launch2SigningIntentField3 =>
      'Can\'t simulate before approval';

  @override
  String get launch2_launch2SigningLabel => 'Maximum payment (incl. tax)';

  @override
  String get launch2_launch2SigningLabel2 => 'Approve first';

  @override
  String get launch2_launch2SigningLabel3 => 'Price';

  @override
  String launch2_launch2SigningLaunch2NftRisk(Object? launch2NftRiskSentence) {
    return 'I understand: $launch2NftRiskSentence.';
  }

  @override
  String get launch2_launch2SigningLaunch2NftRiskSentence =>
      'fills and allocation aren\'t guaranteed, and the public pool may not happen';

  @override
  String launch2_launch2SigningLaunch2NftRiskTickLabel(
    Object? launch2NftRiskSentence,
  ) {
    return 'I understand: $launch2NftRiskSentence';
  }

  @override
  String get launch2_launch2SigningLaunch2RefreshedText =>
      'Quote refreshed: the old quote was about to expire, so it was re-quoted at the latest block within the range you confirmed';

  @override
  String get launch2_launch2SigningLoopDynamicRewards =>
      'Confirm DEX pool reward claim';

  @override
  String launch2_launch2SigningNftMint(Object? noun, Object? ticker) {
    return '$noun $ticker consensus medal (1 per address)';
  }

  @override
  String launch2_launch2SigningOfficialPool(Object? noun) {
    return 'Confirm DEX pool $noun';
  }

  @override
  String get launch2_launch2SigningOfficialPool2 => 'Router';

  @override
  String launch2_launch2SigningReason(Object? noun) {
    return 'Your wallet opens twice: approve first, then $noun. The approval covers only this one.';
  }

  @override
  String get launch2_launch2SigningRefreshing => 'Refreshing quote';

  @override
  String get launch2_launch2SigningRewardClaim => 'reward claim';

  @override
  String launch2_launch2SigningRewardClaim2(Object? meme) {
    return 'Claim $meme DEX pool rewards';
  }

  @override
  String get launch2_launch2SigningS => 'Curve contract';

  @override
  String launch2_launch2SigningS2(Object? launch2BpsLabel) {
    return 'Tax $launch2BpsLabel';
  }

  @override
  String launch2_launch2SigningS3(Object? meme) {
    return 'Buy $meme';
  }

  @override
  String launch2_launch2SigningS4(Object? meme) {
    return 'Sell $meme';
  }

  @override
  String launch2_launch2SigningS5(Object? launch2PoolFailureText) {
    return 'couldn\'t get a new quote ($launch2PoolFailureText)';
  }

  @override
  String launch2_launch2SigningSetState(Object? noun, Object? noun2) {
    return 'Approval broadcast, but the $noun wasn\'t signed and no $noun2 transaction was submitted. Close and start again.';
  }

  @override
  String get launch2_launch2SigningShowLaunch2NftConfirmSheet =>
      'Addresses holding the NFT join the snapshot allowlist and can take part in the 1-hour priority buy.';

  @override
  String get launch2_launch2SigningSwitch => 'Rewards contract';

  @override
  String get launch2_launch2SigningSwitch10 =>
      'The wallet the server built this transaction for doesn\'t match the current wallet. Signing refused; nothing was submitted.';

  @override
  String get launch2_launch2SigningSwitch11 =>
      'Signing isn\'t allowed on this chain. Nothing was submitted.';

  @override
  String get launch2_launch2SigningSwitch12 =>
      'The wallet can\'t sign on this chain right now. Nothing was submitted.';

  @override
  String get launch2_launch2SigningSwitch13 =>
      'The signed-in wallet isn\'t this transaction\'s wallet. Nothing was submitted.';

  @override
  String get launch2_launch2SigningSwitch14 =>
      'The wallet didn\'t finish signing. Nothing was submitted.';

  @override
  String get launch2_launch2SigningSwitch15 =>
      'approval is still confirming on-chain';

  @override
  String get launch2_launch2SigningSwitch16 =>
      'the latest quote was outside the range you confirmed';

  @override
  String get launch2_launch2SigningSwitch17 => 'couldn\'t get a new quote';

  @override
  String get launch2_launch2SigningSwitch18 =>
      'the new transaction didn\'t pass the check';

  @override
  String launch2_launch2SigningSwitch19(
    Object? noun,
    Object? noun2,
    Object? why,
  ) {
    return 'Approval broadcast. The old quote was about to expire and on refresh $why, so the $noun wasn\'t signed and no $noun2 transaction was submitted. Start again later; with enough approval you only sign once.';
  }

  @override
  String get launch2_launch2SigningSwitch2 => 'NFT contract';

  @override
  String launch2_launch2SigningSwitch20(Object? noun) {
    return 'Approval broadcast, but the $noun wasn\'t signed. You can start again.';
  }

  @override
  String launch2_launch2SigningSwitch3(Object? spenderNoun) {
    return 'Approved for: $spenderNoun';
  }

  @override
  String get launch2_launch2SigningSwitch4 => 'Cancelled. Nothing changed.';

  @override
  String get launch2_launch2SigningSwitch5 =>
      'Verification failed. Nothing changed.';

  @override
  String get launch2_launch2SigningSwitch6 =>
      'This transaction expired and nothing was submitted. Start again.';

  @override
  String get launch2_launch2SigningSwitch7 =>
      'The simulation failed; this transaction would be rejected on-chain. Nothing was submitted.';

  @override
  String get launch2_launch2SigningSwitch8 =>
      'The transaction doesn\'t match what you confirmed. Signing refused; nothing was submitted.';

  @override
  String get launch2_launch2SigningSwitch9 =>
      'The wallet directory doesn\'t have this transaction\'s wallet. Nothing was submitted.';

  @override
  String get launch2_launch2SigningTitle => 'Approve';

  @override
  String get launch2_launch2SigningUnknown => 'Result unknown';

  @override
  String get launch2_launch2SigningValue => '1 per address, ever';

  @override
  String get launch2_launch2Switch => 'until mint';

  @override
  String get launch2_launch2TradePanelBuild =>
      'Priority buy is for allowlisted holders; buying opens with the public pool';

  @override
  String get launch2_launch2TradePanelBuild2 => 'Total quota';

  @override
  String launch2_launch2TradePanelIf(Object? launch2Usd1Label) {
    return 'Fill $launch2Usd1Label';
  }

  @override
  String get launch2_launch2TradePanelLabel => 'Refund';

  @override
  String launch2_launch2TradePanelLaunch2CurveMinOutNote(
    Object? launch2BpsLabel,
  ) {
    return 'Based on the current curve price with $launch2BpsLabel slippage protection; the on-chain fill is final';
  }

  @override
  String get launch2_launch2TradePanelLaunch2EligibilityBadge => 'Listed';

  @override
  String get launch2_launch2TradePanelLaunch2EligibilityBadge2 => 'Not listed';

  @override
  String launch2_launch2TradePanelLaunch2TradeExceeds(
    Object? launch2LimitedByText,
    Object? side,
  ) {
    return 'Over the $side limit ($launch2LimitedByText)';
  }

  @override
  String get launch2_launch2TradePanelLaunch2TradeMaxLabel =>
      'Fill max buyable';

  @override
  String get launch2_launch2TradePanelLaunch2TradeQuoteEmpty =>
      'Getting a quote…';

  @override
  String launch2_launch2TradePanelLaunch2TradeQuoteFailedMessage(
    Object? failureText,
  ) {
    return 'Couldn\'t get a quote · $failureText';
  }

  @override
  String launch2_launch2TradePanelLaunch2TradeQuoteProvenanceDetail(
    Object? basisBlockNumber,
    Object? launch2BpsLabel,
  ) {
    return 'Quoted on the curve at block $basisBlockNumber, incl. the 10% tax; slippage $launch2BpsLabel; re-quotes automatically when it expires.';
  }

  @override
  String launch2_launch2TradePanelLaunch2TradeTax(Object? launch2BpsLabel) {
    return 'Tax $launch2BpsLabel';
  }

  @override
  String get launch2_launch2TradePanelLoopProvenanceLine => 'On-chain curve';

  @override
  String launch2_launch2TradePanelS(Object? launch2MemeLabel) {
    return 'Fill $launch2MemeLabel';
  }

  @override
  String get launch2_launch2TradePanelSemanticLabel =>
      'Couldn\'t load total quota';

  @override
  String launch2_launch2TradePanelSemanticLabel2(
    Object? launch2CurveCapSentence,
    Object? launch2MemeFigure,
    Object? tickerLabel,
  ) {
    return 'Total quota used $launch2MemeFigure $tickerLabel, $launch2CurveCapSentence';
  }

  @override
  String get launch2_launch2WalletRowsLaunch2WalletChainLabel => 'Launch chain';

  @override
  String get launch2_launch2WalletRowsLaunch2WalletUnavailableMessage =>
      'Couldn\'t load MEME v2 holdings';

  @override
  String launch2_launch2WalletRowsSubtitle(Object? launch2WalletChainLabel) {
    return '$launch2WalletChainLabel · bonding pool holdings';
  }

  @override
  String get launch2_launchpadSomeoneWho => 'Someone ';

  @override
  String launch2_nftRiskBody(Object? sentence) {
    return '$sentence.';
  }

  @override
  String launch2_nftSaleLeft(Object? left) {
    return ', $left left';
  }

  @override
  String launch2_poolPanelTax(Object? bps) {
    return 'Tax $bps';
  }

  @override
  String get launch2_poolTradesRateLimited =>
      'Too many requests. Try again later';

  @override
  String launch2_provenanceBuyFeeFromUsd1(Object? bps) {
    return '$bps base tax taken from the USD1 paid';
  }

  @override
  String launch2_provenancePoolTax(Object? bps) {
    return 'after the $bps DEX pool tax';
  }

  @override
  String get launch2_provenanceSellPostSwap =>
      'after base and dynamic tax (simulated on the post-trade drop)';

  @override
  String get launch2_provenanceSellPreSwap =>
      'after base and dynamic tax (simulated on the pre-trade drop)';

  @override
  String get launch2_sideBuy => 'buy';

  @override
  String get launch2_sideSell => 'sell';

  @override
  String get launch2_tickerSeparator => '; ';

  @override
  String get launch_actionScreensBuild => 'Stake amount';

  @override
  String get launch_actionScreensBuild2 =>
      'The staking contract isn\'t live yet. This page accepts no amount and opens no signature.';

  @override
  String get launch_actionScreensBuild3 => 'Evaluate first, then launch';

  @override
  String get launch_actionScreensBuild4 =>
      'LOOP works with exchanges, KOLs and communities to pick projects with a narrative, reach and long-term operations.';

  @override
  String get launch_actionScreensBuild5 =>
      'Manual review, cap settings, liquidity plan';

  @override
  String get launch_actionScreensBuild6 =>
      'Details are read-only in this status. Only drafts and returned applications can be edited.';

  @override
  String get launch_actionScreensCaption =>
      'Staked amount, available balance and the unbonding period all need the staking contract. This page builds no transaction and opens no signature.';

  @override
  String get launch_actionScreensCaption2 =>
      'Only amounts LOOP can verify are shown here. Total supply, issuance and ecosystem tax can\'t be loaded yet.';

  @override
  String get launch_actionScreensCaption3 =>
      'Submitting doesn\'t mean approval. Review is manual; the result and listing time follow the latest status.';

  @override
  String get launch_actionScreensCell => 'Registered launches';

  @override
  String get launch_actionScreensCell2 => 'Total volume';

  @override
  String get launch_actionScreensCell3 => 'Total ecosystem tax';

  @override
  String get launch_actionScreensCell4 =>
      'Total raised (successful sales only)';

  @override
  String get launch_actionScreensCell5 => 'Registered sales';

  @override
  String get launch_actionScreensCell6 => 'LP locked';

  @override
  String get launch_actionScreensCurrentSuffix => ', current status';

  @override
  String get launch_actionScreensEmptyMessage =>
      'Couldn\'t load staking status';

  @override
  String get launch_actionScreensEmptyMessage2 =>
      'Couldn\'t load ledger counts';

  @override
  String get launch_actionScreensEmptyMessage3 => 'No applications yet';

  @override
  String get launch_actionScreensEmptyMessage4 =>
      'Couldn\'t load listing progress';

  @override
  String get launch_actionScreensEmptyReason => 'Staking isn\'t open yet.';

  @override
  String get launch_actionScreensEmptyReason2 =>
      'No verifiable amounts can be loaded right now.';

  @override
  String get launch_actionScreensEmptyReason3 =>
      'Fill in the form below to create your first draft.';

  @override
  String get launch_actionScreensEmptyReason4 =>
      'Progress is recorded by operations. This page infers no listing outcome.';

  @override
  String get launch_actionScreensHeading => 'Staking isn\'t open yet';

  @override
  String launch_actionScreensHeading2(num confirmedRoundCount) {
    String _temp0 = intl.Intl.pluralLogic(
      confirmedRoundCount,
      locale: localeName,
      other: '$confirmedRoundCount confirmed rounds',
      one: '1 confirmed round',
    );
    return '$_temp0';
  }

  @override
  String launch_actionScreensHeading3(Object? reviewPipeline) {
    return '$reviewPipeline-step review';
  }

  @override
  String get launch_actionScreensKicker => 'Staking position';

  @override
  String get launch_actionScreensKicker2 => 'Public economy';

  @override
  String get launch_actionScreensKicker3 => 'Curated launch';

  @override
  String get launch_actionScreensLabel => 'Wallet available balance';

  @override
  String get launch_actionScreensLabel2 => 'Stake';

  @override
  String get launch_actionScreensLabel3 => 'Unstake';

  @override
  String get launch_actionScreensLabel4 => 'My staking';

  @override
  String get launch_actionScreensLabel5 => 'Total distributed';

  @override
  String get launch_actionScreensLabel6 => 'Confirmed rounds';

  @override
  String get launch_actionScreensLabel7 => 'Approved applications';

  @override
  String get launch_actionScreensLabel8 => 'Attachments';

  @override
  String get launch_actionScreensLabelText => 'Project name (1–20 characters)';

  @override
  String get launch_actionScreensLabelText2 =>
      'Ticker (1–20 characters: Chinese, letters, digits, emoji)';

  @override
  String get launch_actionScreensLabelText3 => 'Narrative (optional, ≤2000)';

  @override
  String get launch_actionScreensLabelText4 => 'Website (optional, https://)';

  @override
  String get launch_actionScreensLabelText5 => 'X (optional, https://)';

  @override
  String get launch_actionScreensLabelText6 => 'Telegram (optional, https://)';

  @override
  String get launch_actionScreensLabelText7 => 'Discord (optional, https://)';

  @override
  String get launch_actionScreensLaunchApplyCapabilityUnavailableTitle =>
      'Applications aren\'t available right now';

  @override
  String get launch_actionScreensLaunchApplyKybMessage =>
      'Entity review isn\'t open yet';

  @override
  String get launch_actionScreensLaunchApplyLaunchIdSubtitle =>
      'A directory entry is created only after approval';

  @override
  String get launch_actionScreensLaunchApplyLaunchIdSubtitle2 =>
      'In the directory, awaiting schedule';

  @override
  String get launch_actionScreensLaunchApplyLaunchIdTitle => 'Directory entry';

  @override
  String get launch_actionScreensLaunchApplyLaunchIdTrailing => 'Created';

  @override
  String get launch_actionScreensLaunchApplyNewLabel => 'New application';

  @override
  String get launch_actionScreensLaunchApplyNoticeBody =>
      'Review is manual. Only approved projects enter the directory, then wait for a confirmed schedule.';

  @override
  String get launch_actionScreensLaunchApplyNoticeTitle =>
      'Submitting doesn\'t mean approval';

  @override
  String get launch_actionScreensLaunchApplyPrinciplesSummary =>
      'Screening principles and submission notes';

  @override
  String get launch_actionScreensLaunchApplyProvidersPendingDetail =>
      'Once open, upload materials and check review status here.';

  @override
  String get launch_actionScreensLaunchApplyProvidersPendingMessage =>
      'Attachment upload and entity review aren\'t open yet';

  @override
  String get launch_actionScreensLaunchApplyReturnedReasonTitle =>
      'Reason returned';

  @override
  String get launch_actionScreensLaunchApplyReviewedAtTitle => 'Reviewed';

  @override
  String get launch_actionScreensLaunchApplySaveLabel => 'Save draft';

  @override
  String get launch_actionScreensLaunchApplySaveLabel2 => 'Save changes';

  @override
  String get launch_actionScreensLaunchApplyScreenTitle => 'Apply to launch';

  @override
  String get launch_actionScreensLaunchApplySubmitLabel => 'Resubmit';

  @override
  String get launch_actionScreensLaunchApplySubmitLabel2 => 'Submit for review';

  @override
  String get launch_actionScreensLaunchApplySubmittedAtSubtitle =>
      'Only the applicant can see the review history';

  @override
  String get launch_actionScreensLaunchApplySubmittedAtSubtitle2 =>
      'Review history and versions belong to the applicant only';

  @override
  String get launch_actionScreensLaunchApplySubmittedAtTitle => 'Submitted';

  @override
  String get launch_actionScreensLaunchApplyWriteFailureTitle =>
      'This submission didn\'t finish';

  @override
  String get launch_actionScreensLoopBadge => 'Available';

  @override
  String get launch_actionScreensLoopBadge2 => 'Current';

  @override
  String get launch_actionScreensLoopEconomyCapabilityUnavailableTitle =>
      'The ecosystem ledger isn\'t available right now';

  @override
  String launch_actionScreensLoopEconomyOnchainBlock(Object? groupedFigure) {
    return 'Read at block $groupedFigure, LOOP on-chain event index';
  }

  @override
  String get launch_actionScreensLoopEconomyOnchainUnavailableMessage =>
      'The on-chain ledger can\'t be loaded right now';

  @override
  String get launch_actionScreensLoopEconomyScreenTitle =>
      'LOOP ecosystem ledger';

  @override
  String get launch_actionScreensLoopLabel => 'Launch';

  @override
  String get launch_actionScreensLoopLabel10 => 'Exchange listing progress';

  @override
  String get launch_actionScreensLoopLabel11 => 'Review status';

  @override
  String get launch_actionScreensLoopLabel2 => 'On-chain ledger';

  @override
  String get launch_actionScreensLoopLabel3 => 'Value flywheel';

  @override
  String get launch_actionScreensLoopLabel4 => 'Application status counts';

  @override
  String get launch_actionScreensLoopLabel5 => 'Schedule status counts';

  @override
  String get launch_actionScreensLoopLabel6 => 'Review history';

  @override
  String get launch_actionScreensLoopLabel7 => 'My applications';

  @override
  String get launch_actionScreensLoopLabel8 => 'Project details';

  @override
  String get launch_actionScreensLoopLabel9 => 'Attachments and entity review';

  @override
  String get launch_actionScreensLoopStakeCapabilityUnavailableTitle =>
      'LOOP staking isn\'t available right now';

  @override
  String get launch_actionScreensLoopStakeScreenTitle => 'LOOP staking';

  @override
  String get launch_actionScreensLoopStakeSubmitLabel => 'Confirm stake';

  @override
  String get launch_actionScreensLoopStakeSubmitSemanticLabel =>
      'Confirm stake, not available right now';

  @override
  String get launch_actionScreensMessage =>
      'Total supply, total distributed and total ecosystem tax have no values yet';

  @override
  String get launch_actionScreensProjectRow => 'Review result';

  @override
  String get launch_actionScreensS => 'Not available';

  @override
  String get launch_actionScreensSelectedSuffix => ', selected';

  @override
  String get launch_actionScreensStamp => 'LOOP records';

  @override
  String launch_actionScreensStamp2(Object? reviewPipeline) {
    return '$reviewPipeline steps';
  }

  @override
  String launch_actionScreensSubtitle(
    Object? launchTimestampLabel,
    Object? materialVersion,
    Object? ticker,
  ) {
    return '$ticker, version $materialVersion, updated $launchTimestampLabel';
  }

  @override
  String get launch_actionScreensSwitch =>
      'LOOP\'s on-chain event index hasn\'t started yet. The on-chain ledger will show up later.';

  @override
  String get launch_actionScreensSwitch2 =>
      'LOOP\'s on-chain event index is still catching up. The on-chain ledger will show up later.';

  @override
  String get launch_actionScreensText => 'Curated projects complete Launch';

  @override
  String get launch_actionScreensText2 =>
      'Community reach and bonding pool trading build liquidity';

  @override
  String get launch_actionScreensText3 =>
      'Hit the line, graduate and move to the DEX pool';

  @override
  String get launch_actionScreensText4 =>
      'After migration, external liquidity carries the trading';

  @override
  String get launch_actionScreensText5 => 'Value flows back to LOOP';

  @override
  String get launch_actionScreensText6 =>
      'More liquidity, mining appeal and the next round of distribution';

  @override
  String get launch_actionScreensTrailingLabel => 'Staked';

  @override
  String get launch_approvalFailedOnChain =>
      'The approval transaction didn\'t succeed on chain and the allowance didn\'t change. You can start the approval again.';

  @override
  String get launch_approvalPollTimedOut =>
      'The approval was submitted, but the allowance hasn\'t updated. It may still be confirming; check again later and don\'t approve again.';

  @override
  String launch_approvalPolling(Object? attempts) {
    return 'The approval went to the wallet. Waiting for the on-chain allowance to update (checked $attempts times). You can\'t buy until it lands; don\'t approve again.';
  }

  @override
  String get launch_approvalPreparing =>
      'Preparing the approval. The wallet hasn\'t opened yet.';

  @override
  String get launch_approvalSignRefused =>
      'The approval wasn\'t signed and no transaction was submitted. You can start the approval again.';

  @override
  String get launch_broadcastKindFilled => 'it was filled';

  @override
  String get launch_broadcastKindLanded => 'it landed';

  @override
  String get launch_chainModelsActive => 'Running normally';

  @override
  String get launch_chainModelsBody => 'Sale in progress';

  @override
  String get launch_chainModelsBody2 => 'Sale ended, awaiting finalization';

  @override
  String get launch_chainModelsCancelled => 'Cancelled';

  @override
  String get launch_chainModelsClaimed => 'Fully claimed';

  @override
  String get launch_chainModelsClaimed2 => 'Claimed';

  @override
  String get launch_chainModelsCompleted => 'Vesting schedule fully matured';

  @override
  String get launch_chainModelsCompleted2 => 'Lock period ended, LP withdrawn';

  @override
  String get launch_chainModelsCompleted3 => 'Graduated, LP lock period ended';

  @override
  String get launch_chainModelsCompleted4 => ', vesting fully matured';

  @override
  String get launch_chainModelsDone => 'Done';

  @override
  String get launch_chainModelsEnded =>
      'All rounds ended, awaiting finalization';

  @override
  String get launch_chainModelsEntries => 'Soft cap';

  @override
  String get launch_chainModelsEntries10 => 'Project token';

  @override
  String get launch_chainModelsEntries11 => 'Settlement token USD1';

  @override
  String get launch_chainModelsEntries2 => 'Hard cap';

  @override
  String get launch_chainModelsEntries3 => 'Per-wallet project cap';

  @override
  String get launch_chainModelsEntries4 => 'Minimum per purchase';

  @override
  String get launch_chainModelsEntries5 => 'Protocol fee';

  @override
  String get launch_chainModelsEntries6 => 'To liquidity';

  @override
  String get launch_chainModelsEntries7 => 'TGE unlock';

  @override
  String get launch_chainModelsEntries8 => 'Pool fee tier';

  @override
  String get launch_chainModelsEntries9 => 'LP lock';

  @override
  String get launch_chainModelsFailed => 'Finalized: soft cap not reached';

  @override
  String get launch_chainModelsFrozen =>
      'Allocation frozen, claims not open yet';

  @override
  String get launch_chainModelsFrozen2 => 'Frozen';

  @override
  String get launch_chainModelsIf => 'Graduating';

  @override
  String get launch_chainModelsLaunchAxisReading => 'Sale status';

  @override
  String get launch_chainModelsLaunchAxisReading2 => 'Entitlement status';

  @override
  String get launch_chainModelsLaunchAxisReading3 => 'Liquidity status';

  @override
  String get launch_chainModelsLaunchAxisReading4 => 'Operations status';

  @override
  String launch_chainModelsLaunchDurationLabel(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String launch_chainModelsLaunchDurationLabel2(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String launch_chainModelsLaunchDurationLabel3(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String launch_chainModelsLaunchDurationLabel4(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get launch_chainModelsLive => 'A round is within its window';

  @override
  String get launch_chainModelsLpLocked => 'LP NFT locked';

  @override
  String get launch_chainModelsLpLocked2 => 'Graduated, LP locked';

  @override
  String get launch_chainModelsNone => 'Not finalized yet';

  @override
  String get launch_chainModelsNotApplicable => 'Not applicable';

  @override
  String get launch_chainModelsNotStarted => 'Pool creation not started';

  @override
  String get launch_chainModelsNotStarted2 => 'Sale succeeded';

  @override
  String get launch_chainModelsPartiallyClaimed => 'Partially claimed';

  @override
  String get launch_chainModelsPartiallyRefunded => 'Partially refunded';

  @override
  String get launch_chainModelsPaused =>
      'Paused: buys, claims and refunds are all refused';

  @override
  String get launch_chainModelsPending => 'Pending';

  @override
  String get launch_chainModelsPreparing =>
      'Budget frozen, awaiting pool creation';

  @override
  String get launch_chainModelsPreparing2 =>
      'Sale succeeded, preparing liquidity';

  @override
  String get launch_chainModelsRefunded =>
      'Refund window closed or fully refunded';

  @override
  String get launch_chainModelsRefunded2 =>
      'Soft cap not reached, refund window closed';

  @override
  String get launch_chainModelsRefunded3 => 'Cancelled, refund window closed';

  @override
  String get launch_chainModelsRefunded4 => 'Fully refunded';

  @override
  String get launch_chainModelsRefunded5 => 'Refunded';

  @override
  String get launch_chainModelsRefunding =>
      'Refund liability frozen, refunds open';

  @override
  String get launch_chainModelsRefunding2 =>
      'Soft cap not reached, refunds open';

  @override
  String get launch_chainModelsRefunding3 => 'Cancelled, refunds open';

  @override
  String get launch_chainModelsReorged => 'Reorged';

  @override
  String get launch_chainModelsRetryScheduled =>
      'Pool creation or funding failed, retry scheduled';

  @override
  String get launch_chainModelsRetryScheduled2 =>
      'Sale succeeded, pool retry scheduled';

  @override
  String get launch_chainModelsRetrying => 'Retry scheduled';

  @override
  String get launch_chainModelsReverted => 'Reverted on chain';

  @override
  String get launch_chainModelsScheduled => 'Scheduled, not on sale';

  @override
  String get launch_chainModelsSubmitted =>
      'Submitted, awaiting on-chain index';

  @override
  String get launch_chainModelsSucceeded => 'Finalized: soft cap reached';

  @override
  String get launch_chainModelsSwitch => 'Soft cap not reached';

  @override
  String launch_chainModelsSwitch2(Object? body) {
    return 'Paused, $body';
  }

  @override
  String get launch_chainModelsUnknown => 'Result unknown (locked)';

  @override
  String get launch_chainModelsV3Live => 'V3 pool created and liquidity added';

  @override
  String get launch_chainModelsV3Live2 =>
      'Sale succeeded, V3 pool live, LP not locked';

  @override
  String get launch_chainModelsVesting => 'Claims open, vesting on schedule';

  @override
  String get launch_chainModelsVesting2 => ', claims open';

  @override
  String get launch_contractActivationRequired =>
      'Activate your LOOP ID first to do this.';

  @override
  String get launch_contractBootstrapRequired =>
      'Account setup isn\'t finished. Try again later.';

  @override
  String get launch_contractCancelled =>
      'The request was cancelled and the result is unknown. Check the latest status before deciding to retry.';

  @override
  String get launch_contractIdempotencyConflict =>
      'The same action was already submitted with different content. Check the latest status and try again.';

  @override
  String get launch_contractIf =>
      'This purchase didn\'t go through and there\'s no description for this reason yet. No transaction was submitted. The server\'s code is under \"Error code\" below.';

  @override
  String get launch_contractInsufficientBalance =>
      'The payment wallet\'s balance, allowance or network fee is too low. No transaction was submitted.';

  @override
  String get launch_contractInvalidData =>
      'The returned data is incomplete. This page used none of it.';

  @override
  String get launch_contractLaunchMissingHeading => 'No value';

  @override
  String get launch_contractLaunchMissingName => 'No name';

  @override
  String get launch_contractLaunchMissingResult => 'No result';

  @override
  String get launch_contractNotFound =>
      'The target doesn\'t exist, was removed, or isn\'t visible to this account.';

  @override
  String get launch_contractOffline =>
      'The device is offline. This page loaded no data and submitted nothing.';

  @override
  String get launch_contractOutcomeUnknown =>
      'The returned data is incomplete and the result is unconfirmed. Refresh to see the latest status; don\'t submit again.';

  @override
  String get launch_contractPermissionDenied =>
      'This account doesn\'t have permission for this action.';

  @override
  String get launch_contractPolicyBlocked =>
      'This action didn\'t pass the server\'s rule check. Nothing was submitted.';

  @override
  String get launch_contractStale =>
      'The current status doesn\'t allow this action. Refresh and decide again from the latest status.';

  @override
  String get launch_contractSwitch =>
      'The Launch contract isn\'t live yet. On-chain status, buying, refunds and claims aren\'t available yet.';

  @override
  String get launch_contractSwitch10 =>
      'This launch can\'t be found on the contract. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch11 =>
      'The on-chain config version doesn\'t match the record. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch12 =>
      'This launch\'s settlement token isn\'t the configured USD1. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch13 =>
      'Couldn\'t read the Launch contract. Refresh later.';

  @override
  String get launch_contractSwitch14 =>
      'The USD1 allowance isn\'t enough for this purchase. No transaction was submitted. Approve this amount first, then buy once it lands.';

  @override
  String get launch_contractSwitch15 =>
      'The payment wallet doesn\'t have enough USD1 on the Launch chain. No transaction was submitted. Send enough USD1 to this wallet first, or lower the amount.';

  @override
  String get launch_contractSwitch16 =>
      'The payment wallet doesn\'t have enough native coin on the Launch chain for the network fee. No transaction was submitted. Send a small amount of fee coin to this wallet and try again.';

  @override
  String get launch_contractSwitch17 =>
      'The Launch contract returned a value that can\'t be decoded. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch18 =>
      'A block reorg happened during the read. Refresh later.';

  @override
  String get launch_contractSwitch19 =>
      'The list doesn\'t read the chain per item. Open the details to see on-chain status.';

  @override
  String get launch_contractSwitch2 =>
      'The Launch contract is finishing on-chain checks. Refresh later.';

  @override
  String get launch_contractSwitch20 =>
      'This item has no confirmed configuration yet. Value pending.';

  @override
  String get launch_contractSwitch21 =>
      'Liquidity pool info can\'t be loaded yet. Graduation steps stay pending.';

  @override
  String get launch_contractSwitch22 =>
      'Total supply, issuance and ecosystem tax wait for the contract. Only amounts LOOP can verify are shown here.';

  @override
  String get launch_contractSwitch23 =>
      'Launch isn\'t available right now. Try again later.';

  @override
  String get launch_contractSwitch24 =>
      'You can only link a community you own. This community doesn\'t exist, was rejected, or you\'re no longer its owner. The details weren\'t saved.';

  @override
  String get launch_contractSwitch25 =>
      'The eligibility rules for this launch aren\'t configured yet. Eligibility doesn\'t depend on staking.';

  @override
  String get launch_contractSwitch26 =>
      'Staking isn\'t open yet. This page can\'t be used right now.';

  @override
  String get launch_contractSwitch27 =>
      'Review status will show here once it opens.';

  @override
  String get launch_contractSwitch28 =>
      'Attachments can\'t be uploaded right now.';

  @override
  String get launch_contractSwitch29 =>
      'The mining formula isn\'t approved yet. Power, output, rankings and invite boost aren\'t available yet.';

  @override
  String get launch_contractSwitch3 =>
      'There\'s no code at the configured Launch contract address. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch30 =>
      'The active formula version hasn\'t approved an invite boost. This item has no value yet.';

  @override
  String get launch_contractSwitch31 => 'No power snapshot yet.';

  @override
  String get launch_contractSwitch32 =>
      'The latest power snapshot used an old formula version. Check again after the next snapshot.';

  @override
  String get launch_contractSwitch33 =>
      'The graduated list can\'t be loaded right now';

  @override
  String get launch_contractSwitch34 =>
      'The on-chain index has no progress yet. The graduated list can\'t be loaded right now.';

  @override
  String get launch_contractSwitch35 =>
      'Total supply, issuance and ecosystem tax aren\'t open yet. Only amounts LOOP can verify are shown here.';

  @override
  String get launch_contractSwitch4 =>
      'This Launch contract version isn\'t supported. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch5 =>
      'The Launch chain has no available node yet. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch6 =>
      'The Launch node returned a different chain than configured. On-chain status isn\'t available right now.';

  @override
  String get launch_contractSwitch7 =>
      'Can\'t reach the Launch chain node right now. Refresh later.';

  @override
  String get launch_contractSwitch8 =>
      'This launch isn\'t registered on chain yet. Waiting for it to go on chain.';

  @override
  String get launch_contractSwitch9 =>
      'The contract registered for this launch doesn\'t match the current configuration. On-chain status isn\'t available right now.';

  @override
  String get launch_contractText =>
      'An asset in the latest calculation had no reference price, so it wasn\'t published. There\'s no complete snapshot to fall back on yet.';

  @override
  String get launch_contractText10 =>
      'This user made their mining power visible only to themselves.';

  @override
  String get launch_contractText11 =>
      'The reference price isn\'t fresh enough, so this asset wasn\'t counted.';

  @override
  String get launch_contractText12 =>
      'This asset\'s reference price comes from an unregistered token, so it wasn\'t counted.';

  @override
  String get launch_contractText13 =>
      'The current formula version gives this asset no weight.';

  @override
  String get launch_contractText14 =>
      'This community hasn\'t linked a token yet.';

  @override
  String get launch_contractText15 =>
      'Two communities linked this asset, so it wasn\'t counted.';

  @override
  String get launch_contractText16 =>
      'Mining isn\'t available right now. Try again later.';

  @override
  String get launch_contractText17 =>
      'Reward payouts aren\'t on yet. Claims aren\'t available.';

  @override
  String get launch_contractText18 =>
      'This community\'s mining weight is still in review.';

  @override
  String get launch_contractText19 =>
      'Invitations aren\'t available right now. Try again later.';

  @override
  String get launch_contractText2 =>
      'This wallet isn\'t in any complete power snapshot yet. It will show after the next snapshot.';

  @override
  String get launch_contractText20 =>
      'Activate your LOOP ID before binding an invite code.';

  @override
  String get launch_contractText3 =>
      'This asset has no usable quote right now and wasn\'t counted.';

  @override
  String get launch_contractText4 =>
      'That power snapshot was incomplete and has been voided.';

  @override
  String get launch_contractText5 =>
      'The latest power snapshot has no wallet balance for this account.';

  @override
  String get launch_contractText6 =>
      'Network power is 0, so shares can\'t be calculated yet.';

  @override
  String get launch_contractText7 =>
      'The current formula version has no daily output configured.';

  @override
  String get launch_contractText8 => 'Power is 0, so there\'s no rank yet.';

  @override
  String get launch_contractText9 =>
      'The community board doesn\'t show personal ranks.';

  @override
  String get launch_contractTimedOut =>
      'LOOP timed out. This page loaded no data and submitted nothing.';

  @override
  String get launch_contractUnavailable =>
      'This feature isn\'t available right now. Try again later.';

  @override
  String get launch_contractUnexpected =>
      'The action didn\'t finish. Try again later.';

  @override
  String get launch_contractValidationFailed =>
      'The input doesn\'t meet the requirements. Edit it and try again.';

  @override
  String get launch_contractVersionConflict =>
      'The details were changed on another device. Reload before submitting; nothing was overwritten.';

  @override
  String get launch_contractWhenLive => 'The graduated list isn\'t open yet';

  @override
  String get launch_controllersAwaitingSchedule => 'Awaiting schedule';

  @override
  String get launch_controllersLive => 'Live';

  @override
  String get launch_controllersUpcoming => 'Upcoming';

  @override
  String launch_detailScreensBaselineOnChain(Object? block, Object? digest) {
    return 'Axes, rounds and contract parameters are read at block $block, state digest $digest. ';
  }

  @override
  String get launch_detailScreensBuild => 'Allowlist round';

  @override
  String get launch_detailScreensBuild2 => 'Raised';

  @override
  String launch_detailScreensCaption(Object? groupedFigure) {
    return 'Rounds, windows, prices and caps are read from the contract at block $groupedFigure.';
  }

  @override
  String launch_detailScreensCaption10(Object? groupedFigure) {
    return 'Records come from the on-chain index, indexed to block $groupedFigure. P&L isn\'t shown.';
  }

  @override
  String get launch_detailScreensCaption2 =>
      'Rounds, times, prices, eligibility and caps are set by this launch\'s config. Anything unconfirmed shows as pending.';

  @override
  String get launch_detailScreensCaption3 =>
      'Graduation progress follows liquidity. There\'s no verifiable progress before the contract is live.';

  @override
  String launch_detailScreensCaption4(Object? launchStateProjection) {
    return '$launchStateProjection. Steps are derived only from the liquidity and entitlement axes.';
  }

  @override
  String get launch_detailScreensCaption5 =>
      'This round is public. Any wallet can take part.';

  @override
  String get launch_detailScreensCaption6 =>
      'This is the current eligibility result, not a tier. Conditions and snapshot time are shown together.';

  @override
  String get launch_detailScreensCaption7 =>
      'Participant count, concentration, my position and the per-address cap all need contract readings, and none are available right now.';

  @override
  String launch_detailScreensCaption8(Object? groupedFigure) {
    return 'Participants are distinct addresses that bought in the bonding pool, not current holders. From the on-chain index, indexed to block $groupedFigure.';
  }

  @override
  String get launch_detailScreensCaption9 =>
      'Purchase, entitlement and refund records need on-chain data, which can\'t be loaded right now, so no counts or P&L are shown.';

  @override
  String launch_detailScreensClaimAmount(Object? amount) {
    return 'Claim $amount';
  }

  @override
  String get launch_detailScreensCompleted =>
      'The vesting schedule has fully matured. Anything unclaimed can still be claimed in \"My allocation\".';

  @override
  String get launch_detailScreensEmptyMessage => 'Couldn\'t load this project';

  @override
  String get launch_detailScreensEmptyMessage2 => 'Couldn\'t load round config';

  @override
  String get launch_detailScreensEmptyMessage3 =>
      'Couldn\'t load graduation records';

  @override
  String get launch_detailScreensEmptyMessage4 =>
      'Couldn\'t load the eligibility result';

  @override
  String get launch_detailScreensEmptyMessage5 =>
      'Couldn\'t load holder records';

  @override
  String get launch_detailScreensEmptyMessage6 =>
      'Couldn\'t load participation records';

  @override
  String get launch_detailScreensEmptyReason =>
      'The project may not exist, or isn\'t visible to this account.';

  @override
  String get launch_detailScreensEntries => 'Start UTC';

  @override
  String get launch_detailScreensEntries2 => 'End UTC';

  @override
  String get launch_detailScreensEntries3 => 'Price USD1';

  @override
  String get launch_detailScreensEntries4 => 'Round cap USD1';

  @override
  String launch_detailScreensHeading(num chainRounds) {
    String _temp0 = intl.Intl.pluralLogic(
      chainRounds,
      locale: localeName,
      other: '$chainRounds rounds',
      one: '1 round',
    );
    return '$_temp0';
  }

  @override
  String launch_detailScreensHeading2(num rounds) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds rounds',
      one: '1 round',
    );
    return '$_temp0';
  }

  @override
  String launch_detailScreensHeading3(Object? done) {
    return '$done / 4 steps';
  }

  @override
  String get launch_detailScreensHeading4 => 'Not on the list';

  @override
  String get launch_detailScreensIf => 'Loading participants';

  @override
  String launch_detailScreensIf10(Object? block) {
    return 'No records (indexed to block $block)';
  }

  @override
  String launch_detailScreensIf11(Object? block) {
    return 'No purchases; entitlement or refund records exist (indexed to block $block)';
  }

  @override
  String get launch_detailScreensIf12 => 'Round ends';

  @override
  String launch_detailScreensIf13(Object? index) {
    return 'Round $index left';
  }

  @override
  String launch_detailScreensIf14(
    Object? launchMissingFigure,
    Object? launchMissingFigure2,
  ) {
    return 'Market cap $launchMissingFigure / graduation line $launchMissingFigure2';
  }

  @override
  String launch_detailScreensIf15(Object? launchUnitsFigure) {
    return 'Total claimed $launchUnitsFigure';
  }

  @override
  String get launch_detailScreensIf2 =>
      'Project details and round config come from LOOP. On-chain status, price and graduation progress can\'t be loaded right now.';

  @override
  String launch_detailScreensIf3(
    Object? groupedFigure,
    Object? launchStateProjection,
  ) {
    return '$launchStateProjection. Axes, rounds and parameters read at block $groupedFigure.';
  }

  @override
  String launch_detailScreensIf4(Object? launchPendingConfirmationLabel) {
    return 'Eligibility $launchPendingConfirmationLabel, set by this launch\'s eligibility mode';
  }

  @override
  String get launch_detailScreensIf5 => 'Public round, no eligibility required';

  @override
  String launch_detailScreensIf6(num purchases) {
    String _temp0 = intl.Intl.pluralLogic(
      purchases,
      locale: localeName,
      other: '$purchases purchases',
      one: '1 purchase',
    );
    return '$_temp0';
  }

  @override
  String launch_detailScreensIf7(num claimed) {
    String _temp0 = intl.Intl.pluralLogic(
      claimed,
      locale: localeName,
      other: '$claimed claims',
      one: '1 claim',
    );
    return '$_temp0';
  }

  @override
  String launch_detailScreensIf8(num refunded) {
    String _temp0 = intl.Intl.pluralLogic(
      refunded,
      locale: localeName,
      other: '$refunded refunds',
      one: '1 refund',
    );
    return '$_temp0';
  }

  @override
  String launch_detailScreensIf9(Object? launchTimestampLabel, Object? parts) {
    return '$parts, latest $launchTimestampLabel';
  }

  @override
  String get launch_detailScreensKicker => 'Launch record';

  @override
  String get launch_detailScreensKicker2 => 'Round config';

  @override
  String get launch_detailScreensKicker3 => 'Graduation progress';

  @override
  String get launch_detailScreensKicker4 => 'Eligibility';

  @override
  String get launch_detailScreensKicker5 => 'Holder distribution';

  @override
  String get launch_detailScreensKicker6 => 'Participation';

  @override
  String get launch_detailScreensLabel => 'Confirmed config version';

  @override
  String get launch_detailScreensLabel2 => 'Pool address and lock info';

  @override
  String get launch_detailScreensLabel3 => 'Top 10 total';

  @override
  String get launch_detailScreensLabel4 => 'Holder distribution';

  @override
  String get launch_detailScreensLabel5 => 'Participations';

  @override
  String get launch_detailScreensLabel6 =>
      'Purchase, entitlement and refund records';

  @override
  String get launch_detailScreensLabel7 => 'Claim';

  @override
  String get launch_detailScreensLabel8 => 'Refund';

  @override
  String get launch_detailScreensLaunchChainRoundPhaseLabel => 'Not started';

  @override
  String launch_detailScreensLaunchDetailBaselineNoticeBody(
    Object? launchTimestampLabel,
    Object? materialVersion,
    Object? onChain,
  ) {
    return '${onChain}Details version $materialVersion, registered $launchTimestampLabel.';
  }

  @override
  String get launch_detailScreensLaunchDetailBaselineNoticeTitle =>
      'Unproven figures aren\'t shown';

  @override
  String get launch_detailScreensLaunchDetailBaselineNoticeTitle2 =>
      'On-chain readings come from one block';

  @override
  String get launch_detailScreensLaunchDetailCapabilityUnavailableTitle =>
      'Project details aren\'t available right now';

  @override
  String get launch_detailScreensLaunchDetailCaption =>
      'Loading project details and on-chain status';

  @override
  String get launch_detailScreensLaunchDetailFactsSummary =>
      'On-chain axes and config';

  @override
  String get launch_detailScreensLaunchDetailHeading =>
      'Loading project details';

  @override
  String get launch_detailScreensLaunchDetailNoConfigMessage =>
      'Rounds, caps and fees have values only after a config version is confirmed.';

  @override
  String get launch_detailScreensLaunchDetailNoConfigTitle =>
      'No config version yet';

  @override
  String get launch_detailScreensLaunchDetailOpenHistoryTitle =>
      'My participation';

  @override
  String get launch_detailScreensLaunchDetailOpenHoldersTitle =>
      'Bonding pool holders';

  @override
  String get launch_detailScreensLaunchDetailRoundsActionLabel => 'Round rules';

  @override
  String get launch_detailScreensLaunchDetailScreenTitle => 'Project details';

  @override
  String launch_detailScreensLaunchGraduationBarSemanticLabel(
    Object? done,
    Object? steps,
  ) {
    return '$done of $steps steps done';
  }

  @override
  String get launch_detailScreensLaunchGraduationCapabilityUnavailableTitle =>
      'Graduation progress isn\'t available right now';

  @override
  String get launch_detailScreensLaunchGraduationNoticeBody =>
      '\"Ended\" only means the schedule ended, not that it graduated. Graduation depends on liquidity and the trading pool, and neither can be loaded right now. Migration is advanced by the server\'s authoritative status, one step at a time.';

  @override
  String get launch_detailScreensLaunchGraduationNoticeBody2 =>
      '\"Ended\" only means the schedule ended, not that it graduated. A live V3 pool doesn\'t mean the LP is locked; only LP_LOCKED or COMPLETED counts as graduated. Each step finishes before the next.';

  @override
  String get launch_detailScreensLaunchGraduationNoticeTitle =>
      'Graduation isn\'t a schedule status';

  @override
  String get launch_detailScreensLaunchHistoryCapabilityUnavailableTitle =>
      'Participation records aren\'t available right now';

  @override
  String launch_detailScreensLaunchHistoryEntitlementSubtitle(
    Object? launchUnitsFigure,
  ) {
    return 'Claimed $launchUnitsFigure';
  }

  @override
  String launch_detailScreensLaunchHistoryEntitlementTitle(
    Object? launchUnitsFigure,
  ) {
    return 'Entitlement $launchUnitsFigure';
  }

  @override
  String launch_detailScreensLaunchHistoryIndexedEmptyMessage(
    Object? groupedFigure,
  ) {
    return 'Indexed to block $groupedFigure, with no purchases, entitlements or refunds for this wallet.';
  }

  @override
  String get launch_detailScreensLaunchHistoryIndexedEmptyTitle =>
      'This wallet has no records in this launch';

  @override
  String launch_detailScreensLaunchHistoryRefundSubtitle(
    Object? launchUsd1Label,
  ) {
    return 'Refunded $launchUsd1Label';
  }

  @override
  String launch_detailScreensLaunchHistoryRefundTitle(Object? launchUsd1Label) {
    return 'Refundable $launchUsd1Label';
  }

  @override
  String get launch_detailScreensLaunchHoldersCapabilityUnavailableTitle =>
      'Holder distribution isn\'t available right now';

  @override
  String launch_detailScreensLaunchHoldersMeSemanticLabel(
    Object? launchReasonCodeText,
  ) {
    return 'My position, $launchReasonCodeText';
  }

  @override
  String launch_detailScreensLaunchHoldersMeSemanticLabel2(
    Object? snapshotBlockNumber,
  ) {
    return 'My position, snapshot block $snapshotBlockNumber';
  }

  @override
  String launch_detailScreensLaunchHoldersMeSubtitle(
    Object? launchMissingFigure,
    Object? launchMissingFigure2,
  ) {
    return 'Holding $launchMissingFigure, can still buy $launchMissingFigure2';
  }

  @override
  String launch_detailScreensLaunchHoldersMeSubtitle2(
    Object? launchUnitsFigure,
    Object? launchUnitsFigure2,
    Object? launchUnitsFigure3,
    Object? launchUsd1Label,
    Object? launchUsd1Label2,
  ) {
    return 'Bought $launchUnitsFigure, paid $launchUsd1Label in total\nClaimable $launchUnitsFigure2, claimed $launchUnitsFigure3, refundable $launchUsd1Label2';
  }

  @override
  String get launch_detailScreensLaunchHoldersMeTitle => 'My position';

  @override
  String get launch_detailScreensLaunchHoldersMeTrailingCaption =>
      'Frozen entitlement';

  @override
  String get launch_detailScreensLaunchRoundsCapabilityUnavailableTitle =>
      'Round rules aren\'t available right now';

  @override
  String get launch_detailScreensLaunchRoundsFactsSummary =>
      'Other contract parameters';

  @override
  String get launch_detailScreensLaunchRoundsNoConfigMessage =>
      'Caps and fees have values only after a config version is confirmed.';

  @override
  String get launch_detailScreensLaunchRoundsNoSubjectMessage =>
      'Round config belongs to a specific launch, not a site-wide rule. Go back to the Launch directory, open a project, then view its round config.';

  @override
  String get launch_detailScreensLaunchRoundsNoSubjectTitle =>
      'No launch selected';

  @override
  String launch_detailScreensLaunchRoundsNoticeBody(
    Object? launchReasonCodeText,
  ) {
    return 'This page writes no fixed round count, fee rate, holding cap or graduation market cap. $launchReasonCodeText';
  }

  @override
  String get launch_detailScreensLaunchRoundsNoticeBody2 =>
      'The figures on this page are the contract\'s readings at the snapshot block, not rules LOOP wrote. When buying, the reading re-checked before signing applies.';

  @override
  String get launch_detailScreensLaunchRoundsNoticeTitle =>
      'The final confirmed rules apply';

  @override
  String get launch_detailScreensLaunchRoundsNoticeTitle2 =>
      'The contract reading before signing applies';

  @override
  String get launch_detailScreensLaunchRoundsScreenTitle => 'Sale round rules';

  @override
  String get launch_detailScreensLaunchTierCapabilityUnavailableTitle =>
      'Eligibility check isn\'t available right now';

  @override
  String get launch_detailScreensLaunchTierConditionsLabel =>
      'Eligibility mode';

  @override
  String get launch_detailScreensLaunchTierConfigVersionSubtitle =>
      'Not in effect yet';

  @override
  String launch_detailScreensLaunchTierConfigVersionSubtitle2(
    Object? launchTimestampLabel,
  ) {
    return 'In effect from $launchTimestampLabel';
  }

  @override
  String get launch_detailScreensLaunchTierConfigVersionTitle =>
      'Eligibility rules';

  @override
  String get launch_detailScreensLaunchTierDependsOnStakingSubtitle =>
      'Set by this launch\'s eligibility mode';

  @override
  String get launch_detailScreensLaunchTierDependsOnStakingTitle =>
      'Depends on staking';

  @override
  String get launch_detailScreensLaunchTierDependsOnStakingTrailing => 'Yes';

  @override
  String get launch_detailScreensLaunchTierDependsOnStakingTrailing2 => 'No';

  @override
  String get launch_detailScreensLaunchTierOpenStakeLabel =>
      'View LOOP staking';

  @override
  String get launch_detailScreensLaunchTierProofSubtitle =>
      'Passed to the contract as-is when buying';

  @override
  String get launch_detailScreensLaunchTierProofTitle => 'Eligibility proof';

  @override
  String launch_detailScreensLaunchTierProofTrailing(num eligibilityProof) {
    String _temp0 = intl.Intl.pluralLogic(
      eligibilityProof,
      locale: localeName,
      other: '$eligibilityProof entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String launch_detailScreensLaunchTierResultBody(Object? eligibility) {
    return '${eligibility}Eligibility is this launch\'s access result and changes with config and snapshots. No threshold, fee or time window is shown here.';
  }

  @override
  String get launch_detailScreensLaunchTierResultTitle =>
      'Eligibility isn\'t a tier or an entitlement';

  @override
  String get launch_detailScreensLaunchTierRootSubtitle =>
      'This round has no eligibility requirement';

  @override
  String get launch_detailScreensLaunchTierRootSubtitle2 =>
      'Allowlist computed at the snapshot block';

  @override
  String get launch_detailScreensLaunchTierRootTitle => 'Allowlist root';

  @override
  String get launch_detailScreensLaunchTierRootTrailing => 'None';

  @override
  String get launch_detailScreensLaunchTierRoundTitle => 'Applicable round';

  @override
  String get launch_detailScreensLaunchTrackEmptyMessage =>
      'Each launch sets its own number of rounds.';

  @override
  String get launch_detailScreensLaunchTrackEmptyTitle =>
      'No rounds configured yet';

  @override
  String get launch_detailScreensLaunchTrackGraduationTitle =>
      'Graduation and migration';

  @override
  String get launch_detailScreensLaunchTrackOpenGraduationLabel =>
      'View graduation steps';

  @override
  String get launch_detailScreensLoopBadge => 'Invalidated';

  @override
  String get launch_detailScreensLoopCompositeDetailNote =>
      'Access opens in stages; contract rules don\'t change per user';

  @override
  String launch_detailScreensLoopCompositeDetailNote2(
    Object? launchMissingFigure,
    Object? launchMissingFigure2,
  ) {
    return 'Market cap $launchMissingFigure / graduation line $launchMissingFigure2. Migration triggers once the line is hit';
  }

  @override
  String get launch_detailScreensLoopCompositeDetailNote3 =>
      'The cap is enforced by LOOP\'s bonding pool contract';

  @override
  String get launch_detailScreensLoopCompositeDetailNote4 =>
      'Bonding pool and post-graduation records are archived together';

  @override
  String get launch_detailScreensLoopLabel => 'My eligibility';

  @override
  String get launch_detailScreensLoopLabel10 => 'Eligibility result';

  @override
  String get launch_detailScreensLoopLabel11 => 'Top holders';

  @override
  String get launch_detailScreensLoopLabel12 => 'My allowance';

  @override
  String get launch_detailScreensLoopLabel13 => 'Participation details';

  @override
  String get launch_detailScreensLoopLabel14 => 'Purchases and settlement';

  @override
  String get launch_detailScreensLoopLabel15 => 'Purchases';

  @override
  String get launch_detailScreensLoopLabel16 => 'Entitlement';

  @override
  String get launch_detailScreensLoopLabel17 => 'Refunds';

  @override
  String get launch_detailScreensLoopLabel2 => 'Launch track';

  @override
  String get launch_detailScreensLoopLabel3 => 'Records';

  @override
  String get launch_detailScreensLoopLabel4 => 'On-chain axes';

  @override
  String get launch_detailScreensLoopLabel5 => 'Config';

  @override
  String get launch_detailScreensLoopLabel6 => 'Access timeline';

  @override
  String get launch_detailScreensLoopLabel7 => 'Contract caps';

  @override
  String get launch_detailScreensLoopLabel8 => 'Migration steps';

  @override
  String get launch_detailScreensLoopLabel9 => 'Liquidity pool';

  @override
  String launch_detailScreensRefundAmount(Object? amount) {
    return 'Refund $amount';
  }

  @override
  String get launch_detailScreensRefunding => 'Refunding';

  @override
  String get launch_detailScreensRefunding2 =>
      'The sale didn\'t succeed. Request a refund in \"My allocation\".';

  @override
  String get launch_detailScreensS => 'Participants can\'t be loaded right now';

  @override
  String get launch_detailScreensS2 =>
      'The Launch contract isn\'t live yet. Participant count isn\'t available.';

  @override
  String get launch_detailScreensS3 => 'Couldn\'t load project details';

  @override
  String launch_detailScreensS4(Object? index) {
    return 'Round $index ends';
  }

  @override
  String launch_detailScreensS5(
    Object? launchUsd1Label,
    Object? launchUsd1Label2,
  ) {
    return 'Raised $launchUsd1Label / hard cap $launchUsd1Label2';
  }

  @override
  String get launch_detailScreensS6 => 'Public round';

  @override
  String launch_detailScreensS7(
    Object? groupedFigure,
    Object? wireName,
    Object? wireName2,
  ) {
    return 'Snapshot block $groupedFigure, liquidity $wireName, entitlement $wireName2';
  }

  @override
  String get launch_detailScreensS8 => 'Configured';

  @override
  String launch_detailScreensS9(Object? launchUsd1Label) {
    return 'Total refunded $launchUsd1Label';
  }

  @override
  String get launch_detailScreensSemanticLabel =>
      'Graduation progress can\'t be loaded right now';

  @override
  String get launch_detailScreensSemanticLabel2 => 'Share of hard cap raised';

  @override
  String launch_detailScreensSemanticLabel3(Object? badge) {
    return 'Graduation and migration, $badge';
  }

  @override
  String get launch_detailScreensSemanticLabel4 =>
      'Round progress can\'t be loaded right now';

  @override
  String get launch_detailScreensSemanticLabel5 => 'Share of round cap raised';

  @override
  String get launch_detailScreensShortTitle => 'End';

  @override
  String get launch_detailScreensStamp => 'On-chain';

  @override
  String get launch_detailScreensStamp2 => 'Indexed';

  @override
  String launch_detailScreensSubtitle(Object? launchUsd1Label) {
    return 'Used $launchUsd1Label';
  }

  @override
  String launch_detailScreensSubtitle2(
    Object? groupedFigure,
    Object? launchShortHex,
    Object? launchTimestampLabel,
    Object? launchUnitsFigure,
  ) {
    return 'Received $launchUnitsFigure, block $groupedFigure\nTx $launchShortHex, seen $launchTimestampLabel';
  }

  @override
  String launch_detailScreensSubtitle3(
    Object? groupedFigure,
    Object? label,
    Object? launchShortHex,
    Object? launchTimestampLabel,
    Object? total,
  ) {
    return '$total, $label, block $groupedFigure\nTx $launchShortHex, seen $launchTimestampLabel';
  }

  @override
  String launch_detailScreensSwitch(Object? groupedFigure) {
    return '$groupedFigure participants';
  }

  @override
  String get launch_detailScreensSwitch2 => 'Participant count isn\'t open yet';

  @override
  String get launch_detailScreensSwitch3 =>
      'Indexing on-chain records. Participant count will show later.';

  @override
  String get launch_detailScreensSwitch4 =>
      'Advanced by the server\'s authoritative status once graduation conditions are met';

  @override
  String get launch_detailScreensSwitch5 =>
      'LOOP has no record of this round. You can\'t buy here.';

  @override
  String get launch_detailScreensText =>
      'Eligibility for this launch doesn\'t depend on LOOP staking';

  @override
  String launch_detailScreensTitle(Object? launchUsd1Label) {
    return 'Paid $launchUsd1Label';
  }

  @override
  String launch_detailScreensTrackFooter(Object? groupedFigure) {
    return 'Read at block $groupedFigure';
  }

  @override
  String launch_detailScreensTrackFooter2(Object? launchUsd1Label) {
    return 'Wallet cap $launchUsd1Label';
  }

  @override
  String get launch_detailScreensTrailingCaption => 'Round cap';

  @override
  String get launch_detailScreensTrailingLabel => 'Graduation line';

  @override
  String get launch_detailScreensTrailingLabel2 => 'Per-address holding cap';

  @override
  String get launch_detailScreensTrailingLabel3 => 'Total result';

  @override
  String get launch_detailScreensUnread =>
      'An empty list doesn\'t mean you didn\'t take part';

  @override
  String get launch_detailScreensVesting => 'Claiming';

  @override
  String get launch_detailScreensVesting2 =>
      'Claims are open and vest on schedule. Claim in \"My allocation\".';

  @override
  String get launch_intentActionBuy => 'Buy';

  @override
  String get launch_intentActionRefund => 'Refund';

  @override
  String get launch_intentNounBuy => 'purchase';

  @override
  String get launch_intentNounClaim => 'claim';

  @override
  String get launch_intentNounRefund => 'refund';

  @override
  String get launch_modelsActivity => 'Activity';

  @override
  String get launch_modelsActivity2 =>
      'Eligibility is set by account activity.';

  @override
  String get launch_modelsAddAndLockLiquidity => 'Add and lock liquidity';

  @override
  String get launch_modelsAddAndLockLiquidity2 =>
      'Status becomes graduated only after adding and locking';

  @override
  String get launch_modelsApplied => 'Applied';

  @override
  String get launch_modelsApproved => 'Approved';

  @override
  String get launch_modelsApproved2 =>
      'Approved and in the directory. Details are now read-only.';

  @override
  String get launch_modelsBuybackRecipientInvalid =>
      'Buyback recipient address is invalid';

  @override
  String get launch_modelsCommunity =>
      'The linked community ID is invalid. Choose again.';

  @override
  String get launch_modelsCommunity2 =>
      'Eligibility is set by community membership.';

  @override
  String get launch_modelsCommunityBindingMismatch =>
      'Linked community doesn\'t match the project';

  @override
  String get launch_modelsDeferred => 'On hold';

  @override
  String get launch_modelsDelisted => 'Delisted';

  @override
  String get launch_modelsDraft => 'You can keep editing and submit.';

  @override
  String get launch_modelsEntries => 'Per-wallet round cap';

  @override
  String get launch_modelsEntries2 => 'Fee (bps)';

  @override
  String get launch_modelsEntries3 => 'Scheduled';

  @override
  String get launch_modelsEvidenceInvalid => 'Invalid materials';

  @override
  String get launch_modelsEvidencePending => 'Materials needed';

  @override
  String get launch_modelsFeatured => 'Featured';

  @override
  String get launch_modelsInReview =>
      'Review in progress. Details are read-only meanwhile.';

  @override
  String get launch_modelsIncompleteMaterials => 'Incomplete materials';

  @override
  String get launch_modelsListed => 'Listed';

  @override
  String get launch_modelsName =>
      'Project name must be 1–20 characters (emoji count as 2), with no line breaks or invisible characters.';

  @override
  String get launch_modelsNameOrTickerConflict =>
      'Name or ticker conflicts with an existing project';

  @override
  String get launch_modelsNarrative =>
      'Narrative is up to 2000 characters with no control characters. Leave it empty to skip it.';

  @override
  String get launch_modelsOfficialLinks =>
      'Official links must start with https:// and be at most 512 characters.';

  @override
  String get launch_modelsOpenExternalTrading => 'Open DEX pool trading';

  @override
  String get launch_modelsOpenExternalTrading2 =>
      'The bonding pool holding cap lifts as the DEX pool opens';

  @override
  String get launch_modelsOther => 'Other';

  @override
  String get launch_modelsPerpetual => 'Perpetual';

  @override
  String get launch_modelsPreparePool =>
      'Collect funds and create the liquidity pool';

  @override
  String get launch_modelsPreparePool2 =>
      'Collect funds and create the liquidity pool on the DEX';

  @override
  String get launch_modelsPreparing => 'Preparing';

  @override
  String get launch_modelsRejected =>
      'Rejected. Edit per the review notes and resubmit.';

  @override
  String get launch_modelsRejected2 => 'Rejected';

  @override
  String get launch_modelsReturned => 'Returned';

  @override
  String get launch_modelsReturned2 =>
      'Returned. Edit per the reason and resubmit.';

  @override
  String get launch_modelsSpot => 'Spot';

  @override
  String get launch_modelsStopInternalTrading => 'Stop bonding pool trading';

  @override
  String get launch_modelsStopInternalTrading2 =>
      'Bonding pool matching freezes the moment graduation conditions are met';

  @override
  String get launch_modelsSubmitted =>
      'Submitted, awaiting manual review. Submitting doesn\'t mean approval.';

  @override
  String get launch_modelsTicker =>
      'Ticker must be 1–20 characters: Chinese, letters, digits or emoji, with no line breaks or invisible characters.';

  @override
  String get launch_modelsUnavailable =>
      'This launch has no eligibility mode configured yet, so there\'s no eligibility result.';

  @override
  String get launch_modelsWhitelist => 'Allowlist';

  @override
  String get launch_modelsWhitelist2 =>
      'Eligibility is set by an allowlist maintained by operations.';

  @override
  String launch_roundComma(Object? index) {
    return 'Round $index, ';
  }

  @override
  String get launch_screenBody =>
      'Approved projects without a schedule show up here.';

  @override
  String get launch_screenBscMainnet => 'BSC Mainnet';

  @override
  String get launch_screenEmptyMessage =>
      'No approved projects in the directory yet';

  @override
  String get launch_screenEmptyReason => 'Approved projects show up here.';

  @override
  String get launch_screenHeading => 'Loading directory';

  @override
  String launch_screenHeading2(num total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total registered projects',
      one: '1 registered project',
    );
    return '$_temp0';
  }

  @override
  String get launch_screenLabel => 'Graduated projects';

  @override
  String get launch_screenLaunchCapabilityUnavailableTitle =>
      'Launch isn\'t available right now';

  @override
  String get launch_screenLaunchEvidenceNoticeTitle =>
      'Directory available, contract not ready';

  @override
  String get launch_screenLaunchGraduatedEmptyMessage =>
      'Projects show up here once their liquidity is locked.';

  @override
  String get launch_screenLaunchGraduatedEmptyTitle =>
      'No graduated projects yet';

  @override
  String get launch_screenLaunchOpenEconomySubtitle =>
      'Shows only counts the LOOP ledger can prove';

  @override
  String get launch_screenLaunchOpenEconomyTitle => 'Ecosystem economy panel';

  @override
  String launch_screenLaunchOverviewCaption(Object? testnet) {
    return 'Directory, applications and round config come from LOOP. On-chain status is read from $testnet.';
  }

  @override
  String get launch_screenLaunchOverviewCaption2 =>
      'Directory, applications and round config come from LOOP. On-chain status, price and graduation progress can\'t be loaded right now.';

  @override
  String get launch_screenLaunchRulesActionLabel => 'Launch rules';

  @override
  String get launch_screenLaunchSegmentEmptyBody =>
      'No projects in this segment yet. Segments follow on-chain sale status; projects without on-chain readings are grouped by schedule status.';

  @override
  String get launch_screenLaunchStakeActionLabel => 'Manage staking';

  @override
  String get launch_screenStamp => 'Off-chain';

  @override
  String launch_screenTitle(Object? launchSegmentLabel) {
    return '$launchSegmentLabel: no projects';
  }

  @override
  String launch_settlementBody(Object? landed, Object? noun, Object? tx) {
    return '${tx}This $noun is confirmed on chain. $landed.';
  }

  @override
  String launch_settlementBody2(Object? tx) {
    return '${tx}Execution was refused on chain and no funds moved. You can start again.';
  }

  @override
  String launch_settlementBody3(Object? tx) {
    return '${tx}This transaction still wasn\'t seen after the signing window ended. Holdings were reloaded; a late transaction may still succeed, so check before starting again.';
  }

  @override
  String launch_settlementBody4(Object? tx) {
    return '${tx}The on-chain transaction doesn\'t match what was reviewed at signing, so the server didn\'t record it. Check and start again, and contact support.';
  }

  @override
  String launch_settlementBody5(Object? noun, Object? tx) {
    return '${tx}Broadcast doesn\'t mean it landed; the on-chain index decides the result. Don\'t repeat the $noun.';
  }

  @override
  String get launch_settlementBuy => 'Purchase confirmed';

  @override
  String launch_settlementClaim(Object? launchUnitsFigure) {
    return 'Claim $launchUnitsFigure tokens';
  }

  @override
  String launch_settlementClaimRefund(Object? launchUnitsFigure) {
    return 'Request refund of $launchUnitsFigure USD1';
  }

  @override
  String get launch_settlementReplaceAll => 'payment wallet';

  @override
  String get launch_settlementReplaceAll2 => 'current wallet';

  @override
  String get launch_settlementS => 'The wallet balance is what counts';

  @override
  String launch_settlementS2(Object? launchShortHex) {
    return 'Tx $launchShortHex. ';
  }

  @override
  String get launch_settlementSectionBadge => 'Claimable';

  @override
  String get launch_settlementSectionBadge2 => 'Refundable';

  @override
  String launch_settlementSectionBody(Object? body) {
    return '${body}No on-chain result yet. You can check again later.';
  }

  @override
  String get launch_settlementSectionLabel => 'Preparing';

  @override
  String launch_settlementSectionLaunchSettlementEvidenceBody(
    Object? launchReasonCodeText,
  ) {
    return '${launchReasonCodeText}So this page builds no transaction and opens no signature.';
  }

  @override
  String get launch_settlementSectionLaunchSettlementEvidenceTitle =>
      'Not available right now';

  @override
  String get launch_settlementSectionLaunchSettlementPausedBody =>
      'The contract refuses claims and refunds while paused, so the buttons are off. They reopen here once it resumes.';

  @override
  String get launch_settlementSectionLaunchSettlementPollResumeLabel =>
      'Check again';

  @override
  String get launch_settlementSectionLaunchSettlementPreparingBody =>
      'Loading the allocation you can act on from the server. The signing review opens once it loads.';

  @override
  String launch_settlementSectionLaunchSettlementRefundClosedBody(
    Object? launchUsd1Label,
  ) {
    return 'The contract still records $launchUsd1Label unrefunded, but the refund window has closed and the contract no longer accepts refunds.';
  }

  @override
  String get launch_settlementSectionLaunchSettlementRefundClosedTitle =>
      'Refund window closed';

  @override
  String get launch_settlementSectionLaunchSettlementReportRetryLabel =>
      'Reporting again';

  @override
  String get launch_settlementSectionLaunchSettlementReportRetryLabel2 =>
      'Report again';

  @override
  String get launch_settlementSectionLaunchSettlementSignRefusedTitle =>
      'Not signed';

  @override
  String launch_settlementSectionLaunchSettlementUnreadBody(Object? view) {
    return '${view}Claim and refund buttons show only after it loads. Pull down to reload.';
  }

  @override
  String get launch_settlementSectionLaunchSettlementUnreadTitle =>
      'My allocation can\'t be loaded right now';

  @override
  String get launch_settlementSectionLoopLabel => 'My allocation';

  @override
  String get launch_settlementSectionNotice => 'Awaiting finalization';

  @override
  String get launch_settlementSectionNotice2 =>
      'The sale ended and is awaiting finalization. If the soft cap is reached, claims open on the vesting schedule; otherwise refunds open. Wallets that took part see the matching button here.';

  @override
  String get launch_settlementSectionNotice3 => 'Awaiting TGE';

  @override
  String launch_settlementSectionNotice4(Object? position) {
    return 'The sale succeeded and the allocation is frozen$position. Claims open once TGE arrives and the liquidity pool is live.';
  }

  @override
  String get launch_settlementSectionNotice5 => 'Preparing refunds';

  @override
  String get launch_settlementSectionNotice6 =>
      'The sale didn\'t succeed. Refunds open once the refund liability is frozen; wallets that took part see the button here.';

  @override
  String launch_settlementSectionPositionTokens(Object? amount) {
    return ' ($amount tokens)';
  }

  @override
  String launch_settlementSectionSemanticLabel(Object? label) {
    return '$label, not available right now';
  }

  @override
  String get launch_settlementSectionSubtitle =>
      'Claim and refund buttons show only after holdings load.';

  @override
  String launch_settlementSectionSubtitle2(
    Object? block,
    Object? launchUnitsFigure,
  ) {
    return 'Claimed $launchUnitsFigure tokens, $block\nThe contract executes the claim; tokens go straight to the current wallet.';
  }

  @override
  String launch_settlementSectionSubtitle3(
    Object? block,
    Object? launchUnitsFigure,
  ) {
    return 'Allocation $launchUnitsFigure tokens, claimable as it vests, $block';
  }

  @override
  String launch_settlementSectionSubtitle4(Object? block) {
    return 'Nothing claimable now. Come back after the next unlock, $block';
  }

  @override
  String launch_settlementSectionSubtitle5(
    Object? block,
    Object? launchUnitsFigure,
  ) {
    return 'Total claimed $launchUnitsFigure tokens, $block';
  }

  @override
  String launch_settlementSectionSubtitle6(
    Object? block,
    Object? launchUsd1Label,
  ) {
    return 'Refunded $launchUsd1Label, $block\nThe contract executes the refund all at once; USD1 goes straight to the current wallet.';
  }

  @override
  String launch_settlementSectionSubtitle7(
    Object? block,
    Object? launchUsd1Label,
  ) {
    return 'Total refunded $launchUsd1Label, $block';
  }

  @override
  String get launch_settlementSectionTitle => 'Loading my allocation';

  @override
  String launch_settlementSectionTitle2(Object? launchUnitsFigure) {
    return 'Claimable $launchUnitsFigure tokens';
  }

  @override
  String launch_settlementSectionTitle3(Object? launchUnitsFigure) {
    return 'Claimed $launchUnitsFigure tokens';
  }

  @override
  String get launch_settlementSectionTitle4 =>
      'Sent to the wallet, result unconfirmed';

  @override
  String get launch_settlementSectionTitle5 =>
      'Broadcast, not recorded by the server';

  @override
  String get launch_settlementSectionUnreadPosition =>
      'The current wallet\'s holdings didn\'t load this time. ';

  @override
  String get launch_settlementSwitch => 'Claims not open yet';

  @override
  String get launch_settlementSwitch10 =>
      'The current wallet didn\'t take part in this launch and has nothing to claim or refund. No transaction was submitted. If you took part with another wallet, switch to it in Wallet and come back.';

  @override
  String get launch_settlementSwitch11 =>
      'Claimable is 0: the next unlock hasn\'t arrived, or everything was claimed. No transaction was submitted. Come back after the next unlock.';

  @override
  String get launch_settlementSwitch12 =>
      'This wallet\'s USD1 has been fully refunded. No transaction was submitted.';

  @override
  String get launch_settlementSwitch13 =>
      '\"My participation\" is what counts for the allocation';

  @override
  String get launch_settlementSwitch2 => 'Refunds not available';

  @override
  String get launch_settlementSwitch3 => 'Contract paused';

  @override
  String get launch_settlementSwitch4 => 'This wallet didn\'t take part';

  @override
  String get launch_settlementSwitch5 => 'Nothing to claim';

  @override
  String get launch_settlementSwitch6 => 'This didn\'t go through';

  @override
  String get launch_settlementSwitch7 =>
      'The contract hasn\'t opened claims yet (TGE not reached, or the liquidity pool isn\'t live). No transaction was submitted. Details were reloaded; the claim button appears here once it opens.';

  @override
  String get launch_settlementSwitch8 =>
      'Refunds are only possible when the sale failed or was cancelled and the refund window is open. No transaction was submitted. Details were reloaded.';

  @override
  String get launch_settlementSwitch9 =>
      'Claims and refunds are refused while the contract is paused. No transaction was submitted. Try again later.';

  @override
  String get launch_settlementTitle => 'Transaction failed (gas only)';

  @override
  String get launch_settlementTitle2 => 'Not on chain, you can start again';

  @override
  String get launch_settlementTitle3 => 'Reported transaction doesn\'t match';

  @override
  String get launch_settlementTitle4 =>
      'Broadcast, awaiting on-chain confirmation';

  @override
  String launch_signingClaim(Object? launchUnitsFigure) {
    return 'Claim $launchUnitsFigure tokens to the current wallet';
  }

  @override
  String launch_signingClaimRefund(Object? launchUnitsFigure) {
    return 'Refund $launchUnitsFigure USD1 to the current wallet';
  }

  @override
  String launch_signingIf(Object? noun) {
    return 'The wallet\'s result is unknown and this $noun is locked. Check \"My participation\" and don\'t sign again.';
  }

  @override
  String launch_signingIf2(
    Object? kind,
    Object? label,
    Object? noun,
    Object? short,
  ) {
    return 'The wallet broadcast ($short) and the server recorded it. Current status: $label. Broadcast doesn\'t mean $kind; the on-chain index decides, and it will appear in \"My participation\". Don\'t repeat the $noun.';
  }

  @override
  String launch_signingIf3(
    Object? kind,
    Object? launchReportReasonTextFor,
    Object? short,
  ) {
    return 'The wallet broadcast ($short). Broadcast doesn\'t mean $kind. $launchReportReasonTextFor';
  }

  @override
  String get launch_signingLabel => 'Funds';

  @override
  String get launch_signingLabel10 => 'Wallet project cap';

  @override
  String get launch_signingLabel2 => 'Claimable now';

  @override
  String get launch_signingLabel3 => 'Refund now';

  @override
  String get launch_signingLabel4 => 'Wallet total purchased';

  @override
  String get launch_signingLabel5 => 'Signature valid until';

  @override
  String get launch_signingLabel6 => 'State digest';

  @override
  String get launch_signingLabel7 => 'Round';

  @override
  String get launch_signingLabel8 => 'Wallet total';

  @override
  String get launch_signingLabel9 => 'Wallet cap this round';

  @override
  String get launch_signingLaunchClaimTitle => 'Confirm claim';

  @override
  String get launch_signingLaunchPurchaseTitle => 'Confirm purchase';

  @override
  String get launch_signingLaunchRefundTitle => 'Confirm refund';

  @override
  String get launch_signingLaunchSettlementCustodyNote =>
      'Executed by the contract; LOOP never holds the funds';

  @override
  String get launch_signingSwitch => 'Cancelled. Nothing changed.';

  @override
  String get launch_signingSwitch10 =>
      'Simulation failed: this purchase would be refused on chain. No transaction was submitted. Adjust the amount or get a new quote later.';

  @override
  String get launch_signingSwitch11 =>
      'This purchase can\'t be simulated right now, so the server doesn\'t allow signing. No transaction was submitted. Get a new quote later.';

  @override
  String get launch_signingSwitch12 =>
      'This purchase was already submitted and can\'t be signed again. Check \"My participation\".';

  @override
  String get launch_signingSwitch13 =>
      'The wallet didn\'t finish signing. No transaction was submitted.';

  @override
  String launch_signingSwitch14(Object? noun) {
    return 'The signing window for this $noun has passed. No transaction was submitted. Start again.';
  }

  @override
  String launch_signingSwitch15(Object? noun) {
    return 'Simulation failed: this $noun would be refused on chain. No transaction was submitted. Refresh and try again.';
  }

  @override
  String launch_signingSwitch16(Object? noun) {
    return 'This $noun can\'t be simulated right now, so the server doesn\'t allow signing. No transaction was submitted. Start again later.';
  }

  @override
  String launch_signingSwitch17(Object? noun) {
    return 'This $noun was already submitted and can\'t be signed again. Check \"My participation\".';
  }

  @override
  String get launch_signingSwitch18 =>
      'Another transaction was already reported for this purchase, so this broadcast wasn\'t recorded. The transaction may be on chain; check \"My participation\" and don\'t sign again.';

  @override
  String get launch_signingSwitch19 =>
      'The server no longer accepts reports for this purchase; its status has changed. The wallet already broadcast and the transaction may be on chain; check \"My participation\" and don\'t sign again.';

  @override
  String get launch_signingSwitch2 =>
      'Verification didn\'t pass. Nothing changed.';

  @override
  String get launch_signingSwitch20 =>
      'This purchase expired and the transaction isn\'t visible on chain yet, so the report wasn\'t accepted. It may still be propagating; check \"My participation\" later and don\'t sign again.';

  @override
  String get launch_signingSwitch21 =>
      'The on-chain transaction doesn\'t match the purchase reviewed at signing, so the server didn\'t record it. Check \"My participation\", don\'t sign again, and contact support.';

  @override
  String get launch_signingSwitch22 =>
      'The wallet already broadcast, but the server didn\'t accept or didn\'t receive this report. The transaction may be on chain; you can report again later. Don\'t sign again.';

  @override
  String get launch_signingSwitch3 =>
      'This purchase expired. No transaction was submitted. Get a new quote.';

  @override
  String get launch_signingSwitch4 =>
      'The transaction doesn\'t match what was reviewed. Signing refused; no transaction was submitted.';

  @override
  String get launch_signingSwitch5 =>
      'The payment wallet for this purchase isn\'t in the wallet list. No transaction was submitted.';

  @override
  String get launch_signingSwitch6 =>
      'Signing isn\'t allowed on this chain. No transaction was submitted.';

  @override
  String get launch_signingSwitch7 =>
      'The wallet can\'t sign on this chain right now. No transaction was submitted.';

  @override
  String get launch_signingSwitch8 =>
      'The signed-in wallet isn\'t the payment wallet for this purchase. No transaction was submitted.';

  @override
  String get launch_signingSwitch9 =>
      'The wallet the server built the transaction for doesn\'t match the current payment wallet. Signing refused; no transaction was submitted.';

  @override
  String get launch_signingValue => 'Not provided';

  @override
  String get launch_tokensUnit => 'tokens';

  @override
  String get launch_tradeBody =>
      'No on-chain result yet. You can check again later.';

  @override
  String get launch_tradeBody2 =>
      'Loading this wallet\'s USD1 allowance on the Launch chain. You can\'t buy until it loads.';

  @override
  String launch_tradeBody3(Object? amount, Object? usd1) {
    return '${usd1}This purchase needs $amount USD1. The approval covers only this amount, not unlimited; you can buy once it lands.';
  }

  @override
  String launch_tradeBody4(Object? fact) {
    return '$fact. After sending funds, reload the balance and buy again.';
  }

  @override
  String get launch_tradeBuild => 'Not loaded';

  @override
  String launch_tradeBuild2(Object? payAsset) {
    return 'Pay $payAsset';
  }

  @override
  String get launch_tradeCaption =>
      'Pay, receive, fees and remaining allowance get a final review before signing. A server quote exists only after submitting.';

  @override
  String launch_tradeCaption2(Object? snapshotBlockNumber) {
    return 'Quote from contract readings at block $snapshotBlockNumber. The review below applies before signing.';
  }

  @override
  String launch_tradeCurrentAllowance(Object? allowance) {
    return 'Current allowance $allowance. ';
  }

  @override
  String get launch_tradeEmptyMessage =>
      'This Launch has no readable purchase info';

  @override
  String get launch_tradeFailedOnChain => 'Approval didn\'t take effect';

  @override
  String launch_tradeIf(Object? lockedRoundIndex) {
    return 'This purchase: Round $lockedRoundIndex';
  }

  @override
  String launch_tradeIf2(Object? round) {
    return '${round}This purchase is locked; don\'t sign again. The result will appear in \"My participation\".';
  }

  @override
  String get launch_tradeIf3 => 'Network fee balance not loaded';

  @override
  String get launch_tradeIf4 => 'USD1 balance not loaded';

  @override
  String get launch_tradeIf5 => 'Fixed price';

  @override
  String launch_tradeIf6(Object? hardCap, Object? raisedLabel) {
    return 'Raised $raisedLabel / hard cap $hardCap';
  }

  @override
  String get launch_tradeInsufficient =>
      'The USD1 allowance is too low. Approve this amount first, then buy once it lands.';

  @override
  String get launch_tradeKicker => 'Final buy quote';

  @override
  String get launch_tradeLaunchTradeAllowanceRereadLabel => 'Reload';

  @override
  String get launch_tradeLaunchTradeApproveLabel => 'Approve USD1 first';

  @override
  String launch_tradeLaunchTradeApproveSemanticLabel(
    Object? moneyCapabilityCheckingLabel,
  ) {
    return 'Approve USD1 first, $moneyCapabilityCheckingLabel';
  }

  @override
  String get launch_tradeLaunchTradeApproveSemanticLabel2 =>
      'Approve USD1 first, not available right now';

  @override
  String launch_tradeLaunchTradeBalance(
    Object? allowance,
    Object? balance,
    Object? launchMissingFigure,
  ) {
    return 'Includes round fee $launchMissingFigure, USD1 balance $balance, allowance $allowance';
  }

  @override
  String get launch_tradeLaunchTradeBuyOnlyBody =>
      'There\'s no sell in the bonding pool stage. After graduation and external liquidity, trading moves to Market.';

  @override
  String get launch_tradeLaunchTradeBuyOnlyTitle => 'Buy only until graduation';

  @override
  String get launch_tradeLaunchTradeCapabilityUnavailableTitle =>
      'Bonding pool purchases aren\'t available right now';

  @override
  String get launch_tradeLaunchTradeDiscardLabel => 'New quote';

  @override
  String get launch_tradeLaunchTradeFactsSummary =>
      'Fixed price and contract limits';

  @override
  String get launch_tradeLaunchTradeFundingRereadLabel => 'Loading balance';

  @override
  String get launch_tradeLaunchTradeFundingRereadLabel2 => 'Reload balance';

  @override
  String get launch_tradeLaunchTradeHoldersActionLabel => 'View holders';

  @override
  String get launch_tradeLaunchTradeNoRoundMessage =>
      'Round config isn\'t confirmed yet, so there\'s no price, eligibility or allowance to show.';

  @override
  String get launch_tradeLaunchTradeNoRoundTitle => 'No round to join';

  @override
  String get launch_tradeLaunchTradeRefusalCodeSummary => 'Error code';

  @override
  String get launch_tradeLaunchTradeRefusalTitle =>
      'This purchase didn\'t go through';

  @override
  String get launch_tradeLaunchTradeRefusalTitle2 =>
      'Purchases aren\'t available right now';

  @override
  String launch_tradeLaunchTradeScreenSubtitle(Object? launchMissingFigure) {
    return 'Bonding pool, buy only, fee $launchMissingFigure';
  }

  @override
  String get launch_tradeLaunchTradeScreenTitle => 'Launch purchase';

  @override
  String get launch_tradeLaunchTradeSettledDoneLabel => 'Buy again';

  @override
  String get launch_tradeLaunchTradeSignLabel => 'Sign purchase';

  @override
  String get launch_tradeLaunchTradeSubmitSemanticLabel =>
      'Buy, not available right now';

  @override
  String get launch_tradeLoopLabel => 'This round';

  @override
  String get launch_tradeLoopLabel2 => 'Review before signing';

  @override
  String get launch_tradeNull =>
      'On-chain status hasn\'t loaded yet. This page builds no transaction.';

  @override
  String get launch_tradePollTimedOut => 'Allowance hasn\'t updated';

  @override
  String get launch_tradePolling => 'Waiting for the approval to land';

  @override
  String get launch_tradeReading =>
      'Loading the USD1 allowance. You can\'t buy until it loads.';

  @override
  String launch_tradeS(Object? launchShortHex, Object? round) {
    return '${round}Tx $launchShortHex. Broadcast doesn\'t mean it was filled; the on-chain index decides, and it will appear in \"My participation\".';
  }

  @override
  String launch_tradeS2(Object? chainFailureReason) {
    return '${chainFailureReason}You can\'t buy until the allowance loads.';
  }

  @override
  String launch_tradeS3(Object? formatDecimal, Object? symbol) {
    return 'Network fee balance $formatDecimal $symbol';
  }

  @override
  String launch_tradeS4(Object? launchUsd1Label) {
    return 'USD1 balance $launchUsd1Label';
  }

  @override
  String get launch_tradeSemanticLabel =>
      'Raise progress can\'t be loaded right now';

  @override
  String get launch_tradeSemanticLabel2 => 'Raise progress';

  @override
  String get launch_tradeSignRefused => 'Approval not signed';

  @override
  String get launch_tradeStamp => 'Can buy';

  @override
  String get launch_tradeStamp2 => 'Can\'t buy';

  @override
  String get launch_tradeSufficient =>
      'Ready to submit. The status after submitting decides the result.';

  @override
  String launch_tradeSwitch(Object? launchStateProjection) {
    return 'Current on-chain status: $launchStateProjection. You can only buy while the sale is in progress and not paused.';
  }

  @override
  String get launch_tradeSwitch2 =>
      'No payment wallet yet. Choose one in Wallet first.';

  @override
  String get launch_tradeSwitch3 => 'Choose a round first.';

  @override
  String launch_tradeSwitch4(Object? launchTimestampLabel, Object? roundIndex) {
    return 'Round $roundIndex hasn\'t started. You can buy once it opens at $launchTimestampLabel.';
  }

  @override
  String launch_tradeSwitch5(Object? launchTimestampLabel, Object? roundIndex) {
    return 'Round $roundIndex ended at $launchTimestampLabel. Choose a round in progress.';
  }

  @override
  String get launch_tradeSwitch6 =>
      'Enter a valid amount to pay (up to 18 decimals).';

  @override
  String get launch_tradeSwitch7 => 'Preparing approval';

  @override
  String get launch_tradeSwitch8 =>
      'Couldn\'t load this wallet\'s USD1 allowance on the Launch chain. This page doesn\'t guess the allowance, so you can\'t buy yet.';

  @override
  String get launch_tradeTitle => 'Broadcast, awaiting on-chain index';

  @override
  String launch_tradeTitle2(Object? label) {
    return 'Broadcast, $label';
  }

  @override
  String get launch_tradeTitle3 => 'The approval wasn\'t prepared';

  @override
  String get launch_tradeTitle4 => 'Loading approval status';

  @override
  String get launch_tradeTitle5 => 'Approval status not loaded';

  @override
  String get launch_tradeTitle6 => 'Approve USD1 first';

  @override
  String get launch_tradeTitle7 => 'Add network fee first';

  @override
  String get launch_tradeTitle8 => 'Add USD1 first';

  @override
  String get launch_tradeUnread =>
      'Approval status not loaded. This page doesn\'t guess the allowance, so you can\'t buy yet.';

  @override
  String get launch_widgetsAdd => 'No records yet';

  @override
  String launch_widgetsAdd2(Object? launchTimestampLabel) {
    return 'Updated $launchTimestampLabel';
  }

  @override
  String launch_widgetsAdd3(Object? launchMissingFigure) {
    return 'Review recorded $launchMissingFigure';
  }

  @override
  String launch_widgetsAdd4(Object? launchMissingFigure) {
    return 'Platform-verifiable time $launchMissingFigure (not provided by the operator)';
  }

  @override
  String launch_widgetsAdd5(Object? reviewer) {
    return 'Reviewer $reviewer';
  }

  @override
  String get launch_widgetsAdd6 => 'No materials to check for this status';

  @override
  String get launch_widgetsAddressUnregistered => 'Not registered';

  @override
  String launch_widgetsBuild(
    Object? launchSourceLabel,
    Object? launchTimestampLabel,
  ) {
    return 'Source $launchSourceLabel, seen $launchTimestampLabel';
  }

  @override
  String launch_widgetsBuild2(Object? address) {
    return 'Contract $address';
  }

  @override
  String get launch_widgetsBuild3 =>
      'The cap applies only in the bonding pool stage and is enforced by the contract. This page writes no fixed ratio or amount; the confirmed config of this launch applies.';

  @override
  String launch_widgetsBuild4(Object? roundIndex) {
    return 'Round $roundIndex per-wallet cap';
  }

  @override
  String get launch_widgetsBuild5 =>
      'The contract enforces the cap on every purchase. This is the contract\'s reading at the snapshot block, not a fixed ratio or amount LOOP wrote.';

  @override
  String get launch_widgetsCatalog => 'LOOP directory';

  @override
  String get launch_widgetsEnded => 'Sale ended';

  @override
  String launch_widgetsLabel(Object? label, Object? launchMetricReasonLine) {
    return '$label, no value. $launchMetricReasonLine';
  }

  @override
  String get launch_widgetsLabel10 => 'Bonding pool ended, raise succeeded';

  @override
  String get launch_widgetsLabel11 =>
      'Bonding pool ended, soft cap not reached';

  @override
  String get launch_widgetsLabel12 => 'Bonding pool cancelled';

  @override
  String launch_widgetsLabel2(
    Object? address,
    Object? name,
    Object? narrative,
    Object? ticker,
  ) {
    return '$name, $ticker. ${narrative}Contract $address';
  }

  @override
  String get launch_widgetsLabel3 => 'Current price';

  @override
  String get launch_widgetsLabel4 => 'Volume';

  @override
  String get launch_widgetsLabel5 => 'Go to bonding pool trading';

  @override
  String get launch_widgetsLabel6 => 'Bonding pool paused';

  @override
  String get launch_widgetsLabel7 => 'Bonding pool not started';

  @override
  String get launch_widgetsLabel8 =>
      'Bonding pool ended, awaiting finalization';

  @override
  String get launch_widgetsLabel9 => 'Graduated, bonding pool closed';

  @override
  String launch_widgetsLaunchAxisSnapshot(
    Object? groupedFigure,
    Object? launchShortHex,
  ) {
    return 'Snapshot block $groupedFigure, state digest $launchShortHex';
  }

  @override
  String launch_widgetsLaunchChainRoundRow(
    Object? launchUsd1Label,
    Object? launchUsd1Label2,
  ) {
    return 'Round cap $launchUsd1Label, wallet cap $launchUsd1Label2';
  }

  @override
  String launch_widgetsLaunchChainRoundRow2(Object? launchUsd1Label) {
    return 'Raised $launchUsd1Label';
  }

  @override
  String launch_widgetsLaunchChainRowSemanticLabel(
    Object? loopLaunchTestnetChainId,
    Object? loopTestnetBadgeLabel,
  ) {
    return 'Launch runs on $loopTestnetBadgeLabel, $loopLaunchTestnetChainId; mainnet features are unaffected';
  }

  @override
  String launch_widgetsLaunchChainRowSubtitle(
    Object? loopLaunchTestnetChainId,
  ) {
    return '$loopLaunchTestnetChainId, Launch chain; wallet balances, market, swap and approvals stay on mainnet';
  }

  @override
  String get launch_widgetsLaunchOnChainUnavailable => 'On-chain pending';

  @override
  String get launch_widgetsLaunchPendingConfirmationLabel => 'Config confirmed';

  @override
  String launch_widgetsLaunchRoundRow(Object? pendingLabel) {
    return 'Eligibility $pendingLabel';
  }

  @override
  String launch_widgetsLaunchRoundRow2(Object? pendingLabel) {
    return 'Time $pendingLabel';
  }

  @override
  String launch_widgetsLaunchRoundRow3(Object? pendingLabel) {
    return 'Price $pendingLabel';
  }

  @override
  String launch_widgetsLaunchRoundRow4(Object? pendingLabel) {
    return 'Cap $pendingLabel';
  }

  @override
  String launch_widgetsLaunchTrackRow(Object? launchPendingConfirmationLabel) {
    return 'Opens $launchPendingConfirmationLabel';
  }

  @override
  String get launch_widgetsLedger => 'LOOP ledger';

  @override
  String get launch_widgetsLoopBadge => 'Selected';

  @override
  String get launch_widgetsLoopOfflineState => 'Apply';

  @override
  String get launch_widgetsLoopOfflineState2 => 'Bind';

  @override
  String get launch_widgetsMessage => 'This feature isn\'t available right now';

  @override
  String get launch_widgetsNoNarrative => 'No project summary yet. ';

  @override
  String get launch_widgetsOnChainPending => 'On-chain status pending';

  @override
  String launch_widgetsS(Object? launchTierLabel) {
    return 'Eligibility $launchTierLabel';
  }

  @override
  String launch_widgetsS2(Object? launchTimestampLabel) {
    return 'Starts $launchTimestampLabel';
  }

  @override
  String launch_widgetsS3(Object? priceUsd1) {
    return 'Price $priceUsd1 USD1';
  }

  @override
  String launch_widgetsS4(Object? walletRoundCapRaw) {
    return 'Cap $walletRoundCapRaw';
  }

  @override
  String launch_widgetsS5(Object? launchTimestampLabel) {
    return 'Review recorded $launchTimestampLabel';
  }

  @override
  String launch_widgetsS6(Object? launchTimestampLabel) {
    return 'Platform-verified $launchTimestampLabel';
  }

  @override
  String launch_widgetsS7(Object? launchTimestampLabel) {
    return 'Opens $launchTimestampLabel';
  }

  @override
  String get launch_widgetsSelectedSuffix => ', selected';

  @override
  String launch_widgetsSemanticLabel(Object? launchAxisLabels) {
    return '$launchAxisLabels, no provable on-chain status';
  }

  @override
  String launch_widgetsSemanticLabel2(
    Object? access,
    Object? lines,
    Object? price,
    Object? roundIndex,
    Object? selected,
  ) {
    return 'Round $roundIndex, $access, price $price, $lines$selected';
  }

  @override
  String launch_widgetsSemanticLabel3(
    Object? launchPendingConfirmationLabel,
    Object? subtitle,
    Object? title,
  ) {
    return '$title, $subtitle, fee $launchPendingConfirmationLabel';
  }

  @override
  String launch_widgetsSubjectsShared(Object? shared, Object? subjects) {
    return '$subjects: $shared';
  }

  @override
  String get launch_widgetsSubtitle => 'Contract reading';

  @override
  String get launch_widgetsTrailingCaption => 'Price';

  @override
  String get launch_widgetsTrailingCaption2 => 'Fee';

  @override
  String get launch_widgetsUnavailable =>
      'On-chain info can\'t be loaded right now, so this page shows no contract address, total supply, tax rate or cap.';

  @override
  String get launch_widgetsUnscheduled => 'Approved, awaiting schedule';

  @override
  String get notifications_applicationNoReason =>
      'No reason was given. Edit the community profile and submit again.';

  @override
  String notifications_applicationReason(Object? reason) {
    return 'Reason: $reason';
  }

  @override
  String notifications_applicationRejected(Object? subject) {
    return '$subject wasn\'t approved';
  }

  @override
  String get notifications_applicationSubject => 'Your community';

  @override
  String notifications_applicationSubjectNamed(Object? communityName) {
    return 'Your community \"$communityName\"';
  }

  @override
  String notifications_applicationVerified(Object? subject) {
    return '$subject was approved';
  }

  @override
  String get notifications_applicationVerifiedBody =>
      'The verified badge is showing; mining weight and the official group are open.';

  @override
  String get notifications_badgeMinted => 'Consensus badge minted';

  @override
  String notifications_bellUnread(Object? label) {
    return 'Notifications, $label unread';
  }

  @override
  String get notifications_categoryAnnouncement => 'Announcements';

  @override
  String get notifications_categoryCommunityAll => 'All messages';

  @override
  String get notifications_categoryCommunityAllDetail =>
      'Best kept off for large groups';

  @override
  String get notifications_categoryGraduation => 'Graduations';

  @override
  String get notifications_categoryLaunchRound =>
      'Eligibility snapshots and start reminders';

  @override
  String get notifications_categoryLaunchRoundDetail =>
      'Includes consensus badges, launch review results and on-chain progress';

  @override
  String get notifications_categoryMention => 'Mentions of me';

  @override
  String get notifications_categoryPriceAlertDetail =>
      'When off, price alerts are still recorded but no notification is sent';

  @override
  String get notifications_categorySecurityDetail => 'Can\'t be turned off';

  @override
  String get notifications_categorySettlement => 'Daily settlement complete';

  @override
  String get notifications_categoryTradeResult => 'Trade results';

  @override
  String get notifications_categoryWeight => 'Weight changes';

  @override
  String get notifications_categoryWeightDetail =>
      'When a held token\'s Mining Weight changes';

  @override
  String get notifications_deployFailed => 'Deployment failed';

  @override
  String get notifications_deviceSessionRevoked =>
      'A device session was revoked';

  @override
  String get notifications_earlier => 'Earlier';

  @override
  String get notifications_emptyMessage =>
      'Token graduations, badge mints, friend requests and security alerts show up here.';

  @override
  String get notifications_emptyTitle => 'No notifications yet';

  @override
  String get notifications_friendAccepted => 'Friend request accepted';

  @override
  String notifications_friendAcceptedBody(Object? name) {
    return 'You and $name are now friends';
  }

  @override
  String get notifications_friendRequest => 'New friend request';

  @override
  String notifications_friendRequestBody(Object? name) {
    return '$name wants to add you as a friend';
  }

  @override
  String get notifications_graduated => 'A project you joined graduated';

  @override
  String notifications_graduatedNamed(Object? subject) {
    return '$subject graduated';
  }

  @override
  String get notifications_launchApprovedBody => 'Sign to deploy the launch';

  @override
  String get notifications_launchDeployFailed => 'Launch deployment failed';

  @override
  String get notifications_launchOnChain => 'Your launch is on-chain';

  @override
  String get notifications_launchReviewApproved => 'Launch approved';

  @override
  String get notifications_launchReviewRejected => 'Launch not approved';

  @override
  String notifications_launchSaleStart(Object? saleStartAt) {
    return 'Sale starts $saleStartAt';
  }

  @override
  String get notifications_onChain => 'On-chain';

  @override
  String notifications_priceAlertBody(Object? observed, Object? threshold) {
    return 'Target $threshold · Observed $observed';
  }

  @override
  String get notifications_priceAlertTriggered => 'Price alert triggered';

  @override
  String notifications_priceAlertTriggeredNamed(Object? symbol) {
    return '$symbol price alert triggered';
  }

  @override
  String get notifications_readAll => 'Mark all read';

  @override
  String get notifications_readAllDone => 'All marked as read';

  @override
  String get notifications_readAllFailed =>
      'Couldn\'t mark as read. Try again later';

  @override
  String get notifications_reviewApproved => 'Approved';

  @override
  String get notifications_reviewRejected => 'Not approved';

  @override
  String get notifications_securityEvent => 'Security event';

  @override
  String get notifications_settingsSubtitle =>
      'Choose which notifications you get';

  @override
  String notifications_source(Object? factSourceLabel) {
    return 'Source: $factSourceLabel';
  }

  @override
  String notifications_unreadCount(Object? unreadCount) {
    return '$unreadCount unread';
  }

  @override
  String get profileSettings_aboutAndLegal => 'About and legal';

  @override
  String get profileSettings_appLock => 'App lock';

  @override
  String get profileSettings_appLockCapabilityUnknown =>
      'This device\'s screen lock hasn\'t been read yet';

  @override
  String profileSettings_appLockNotPersisted(Object? appLockFactorText) {
    return '$appLockFactorText · Applies now; won\'t be remembered after the app restarts';
  }

  @override
  String get profileSettings_appLockOff => 'Off';

  @override
  String profileSettings_appLockSemantic(Object? appLockLabel) {
    return 'App lock, $appLockLabel. Tap and verify to change';
  }

  @override
  String profileSettings_appLockUnavailableSemantic(Object? appLockDetail) {
    return 'App lock, unavailable: $appLockDetail';
  }

  @override
  String get profileSettings_capabilityBlocked =>
      'Account settings aren\'t available right now';

  @override
  String get profileSettings_currency => 'Currency';

  @override
  String get profileSettings_displaySavedLocally =>
      'Saved on this device only; never written to your account or sent to the server';

  @override
  String get profileSettings_displaySaving => 'Applied; saving to this device';

  @override
  String get profileSettings_displaySessionOnly =>
      'Applies for this session; saving on this device isn\'t available';

  @override
  String get profileSettings_empty => 'No account settings yet';

  @override
  String get profileSettings_fixedThemeNote =>
      'Theme is fixed in this version.';

  @override
  String get profileSettings_fixedValuesNote =>
      'Currency and theme are fixed in this version.';

  @override
  String get profileSettings_general => 'General';

  @override
  String get profileSettings_helpAndSupport => 'Help and support';

  @override
  String get profileSettings_reduceMotion => 'Reduce motion';

  @override
  String profileSettings_reduceMotionSemantic(Object? preferences) {
    return 'Reduce motion, $preferences';
  }

  @override
  String get profileSettings_storageUnavailableBody =>
      'Reduce motion still applies for this session. Retry only reads this device\'s storage again; it doesn\'t use your account or the server.';

  @override
  String get profileSettings_storageUnavailableTitle =>
      'Can\'t save on this device';

  @override
  String get profileSettings_theme => 'Theme';

  @override
  String get profileSettings_themeDark => 'Dark';

  @override
  String profileSettings_updatedAt(Object? relativeTime) {
    return 'Updated $relativeTime';
  }

  @override
  String get profileSettings_usingDefaults => 'Using default settings';

  @override
  String get scan_cameraDeniedBody =>
      'Scanning is unavailable. Turn it back on in Settings → LOOP → Camera.';

  @override
  String get scan_cameraErrorReason =>
      'The camera didn\'t open. Retry, or use Photos below.';

  @override
  String get scan_cameraNoAccess => 'No camera access';

  @override
  String get scan_cameraOpening => 'Opening camera…';

  @override
  String get scan_cameraUnsupported => 'This device has no available camera';

  @override
  String get scan_cameraUnsupportedDetail =>
      'Use Photos below to read a QR code from an image.';

  @override
  String get scan_contentCopied => 'QR code content copied';

  @override
  String get scan_hint =>
      'Point at a LOOP profile card, invite poster, community QR code or wallet address QR code.';

  @override
  String get scan_imageNoCode => 'No QR code found in this image';

  @override
  String get scan_imageNoPhotoAccess =>
      'No photo access. Allow LOOP to access Photos in Settings, then try again';

  @override
  String get scan_imageUnreadable =>
      'Couldn\'t read the image. Try another one';

  @override
  String get scan_keepScanning => 'Keep scanning';

  @override
  String get scan_pickImageLabel => 'Photos';

  @override
  String get scan_pickImageReading => 'Reading…';

  @override
  String get scan_pickImageSemantic => 'Choose from Photos';

  @override
  String get scan_torch => 'Flashlight';

  @override
  String get scan_torchOff => 'Turn off flashlight';

  @override
  String get scan_unavailable => 'Scanning isn\'t available right now';

  @override
  String get scan_unavailableDetail =>
      'This build doesn\'t include camera scanning; this page won\'t open the camera.';

  @override
  String get scan_unknownBody =>
      'LOOP won\'t open this content; it\'s only shown below.';

  @override
  String get scan_unknownTitle => 'Not a LOOP QR code';

  @override
  String get securityAppLock_controllerReason =>
      'Verify your identity to turn on App lock';

  @override
  String get securityAppLock_controllerReason2 =>
      'Verify your identity to turn off App lock';

  @override
  String get securityAppLock_controllerReason3 =>
      'Verify your identity to open LOOP';

  @override
  String get securityAppLock_gateBiometric =>
      'Unlock with this device\'s biometrics; falls back to the device passcode if not recognized';

  @override
  String get securityAppLock_gateCanceled => 'You cancelled this verification.';

  @override
  String get securityAppLock_gateDeviceCredential =>
      'Unlock with this device\'s screen lock passcode';

  @override
  String get securityAppLock_gateFailed =>
      'Verification didn\'t pass. Try again.';

  @override
  String get securityAppLock_gateLockedOut =>
      'The system has paused verification for now. Wait a moment and try again, or use the device passcode.';

  @override
  String get securityAppLock_gateLoopAppLockUnlockLabel => 'Verifying…';

  @override
  String get securityAppLock_gateLoopAppLockUnlockLabel2 => 'Verify identity';

  @override
  String get securityAppLock_gateLoopAppLockUnlockSemanticLabel =>
      'LOOP is locked';

  @override
  String get securityAppLock_gateNoCredentialSet =>
      'This device has no screen lock passcode or biometrics yet. Add one in system Settings first';

  @override
  String securityAppLock_gateS(Object? systemMessage) {
    return 'Verification didn\'t finish · System message: $systemMessage';
  }

  @override
  String get securityAppLock_gateSucceeded => 'Verified.';

  @override
  String get securityAppLock_gateSwitch => 'Verification didn\'t finish.';

  @override
  String get securityAppLock_gateSwitch2 =>
      'Haven\'t read this device\'s screen lock capability yet';

  @override
  String get securityAppLock_gateUnavailable =>
      'This device has no screen lock verification available right now.';

  @override
  String get securityAppLock_gateUnsupportedPlatform =>
      'This device doesn\'t support screen lock verification';

  @override
  String get securityAppLock_promptAppLockPromptEnableLabel => 'Turn on';

  @override
  String get securityAppLock_promptAppLockPromptLaterLabel => 'Not now';

  @override
  String get securityAppLock_promptLoopAppLockPromptBody =>
      'Require Face ID / fingerprint when you return after 60 seconds in the background, keeping your wallet and chats safer';

  @override
  String get securityAppLock_promptLoopSheetHeading => 'Turn on App lock';

  @override
  String get securityMfa_controllerConfirmOwnerPresent =>
      'Verify your identity once before unlinking the passkey';

  @override
  String get securityMfa_modelsSms => 'SMS';

  @override
  String get securityMfa_modelsTotp => 'Authenticator app';

  @override
  String get securityMfa_passkeySheetBuild =>
      'The passkey is kept by this device\'s system; the login service only records its public key. On a new phone, a passkey synced through the same system account gets you back in.';

  @override
  String get securityMfa_passkeySheetCancelled => 'This didn\'t finish';

  @override
  String get securityMfa_passkeySheetLoopLabel => 'Linked';

  @override
  String get securityMfa_passkeySheetPasskeySheetConfirmBody =>
      'The device verifies your identity once before unlinking. The passkey stored in the system is managed by the system; LOOP can\'t delete it, the login service just stops accepting it.';

  @override
  String get securityMfa_passkeySheetPasskeySheetConfirmTitle =>
      'After unlinking, this way back is gone';

  @override
  String get securityMfa_passkeySheetPasskeySheetEmptyMessage =>
      'Once linked, this device\'s face or fingerprint is a separate way back in.';

  @override
  String get securityMfa_passkeySheetPasskeySheetEmptyTitle =>
      'This account has no passkey yet';

  @override
  String get securityMfa_passkeySheetPasskeySheetLinkLabel => 'Link passkey';

  @override
  String get securityMfa_passkeySheetPasskeySheetLinkLabel2 =>
      'Link another passkey';

  @override
  String get securityMfa_passkeySheetPasskeySheetUnknownTitle =>
      'No response from the login service yet';

  @override
  String get securityMfa_passkeySheetPasskeySheetUnlinkLabel => 'Unlinking…';

  @override
  String get securityMfa_passkeySheetPasskeySheetUnlinkLabel2 =>
      'Confirm unlink';

  @override
  String securityMfa_passkeySheetSemanticLabel(Object? passkey) {
    return '$passkey, set up, tap to unlink';
  }

  @override
  String get securityMfa_passkeySheetSubtitle =>
      'Also used for two-step verification';

  @override
  String get securityMfa_passkeySheetSubtitle2 =>
      'Used for sign-in and recovery';

  @override
  String get securityMfa_passkeySheetText =>
      'The login service hasn\'t responded during this session yet.';

  @override
  String get securityMfa_passkeySheetTitle => 'Passkeys on this account';

  @override
  String get securityMfa_passkeySheetTrailing => 'Set up';

  @override
  String get securityMfa_sheetBuild =>
      'Both methods are kept by the login service. LOOP doesn\'t store the secret key or the passkey.';

  @override
  String get securityMfa_sheetBuild2 =>
      'Once turned off, the login service won\'t ask you for a code when it requires two-step verification.';

  @override
  String get securityMfa_sheetCancelled =>
      'System verification didn\'t finish. Nothing was changed.';

  @override
  String get securityMfa_sheetDeviceUnsupported =>
      'This device has no passkey available; the system offers no place to create one.';

  @override
  String get securityMfa_sheetInvalidCode =>
      'The code is wrong or has expired. Enter it again.';

  @override
  String get securityMfa_sheetLoopLabel => 'Manual entry key';

  @override
  String get securityMfa_sheetLoopLabel2 =>
      '6-digit code from your authenticator';

  @override
  String get securityMfa_sheetLoopPasskeyDomainPending =>
      'LOOP needs domain credentials for passkeys first; this version doesn\'t have them yet';

  @override
  String get securityMfa_sheetMessage => 'Key copied';

  @override
  String get securityMfa_sheetMfaSheetBeginLabel => 'Get key';

  @override
  String get securityMfa_sheetMfaSheetFailureTitle =>
      'The login service hasn\'t enabled MFA yet';

  @override
  String get securityMfa_sheetMfaSheetFailureTitle2 =>
      'This step didn\'t finish';

  @override
  String get securityMfa_sheetMfaSheetPasskeyLabel =>
      'Waiting for system verification…';

  @override
  String get securityMfa_sheetMfaSheetPasskeyLabel2 =>
      'Turn off passkey verification';

  @override
  String get securityMfa_sheetMfaSheetPasskeyLabel3 =>
      'Use passkey for two-step verification';

  @override
  String get securityMfa_sheetMfaSheetPasskeyStatus =>
      'On · Passkey. When the login service requires two-step verification, the system shows a passkey prompt.';

  @override
  String get securityMfa_sheetMfaSheetPasskeyStatus2 =>
      'This account already has a passkey; you can also use it for two-step verification.';

  @override
  String get securityMfa_sheetMfaSheetPasskeyStatus3 =>
      'Create a passkey on this device and use it as your two-step verification method.';

  @override
  String get securityMfa_sheetMfaSheetPasskeyUnavailableTitle =>
      'Passkey not available right now';

  @override
  String get securityMfa_sheetMfaSheetRemoveLabel => 'Turning off…';

  @override
  String get securityMfa_sheetMfaSheetRemoveLabel2 => 'Turn off MFA';

  @override
  String get securityMfa_sheetMfaSheetSubmitLabel => 'Verifying…';

  @override
  String get securityMfa_sheetMfaSheetSubmitLabel2 => 'Verify and turn on';

  @override
  String get securityMfa_sheetMfaSheetTitle => 'Two-step verification';

  @override
  String get securityMfa_sheetNotAuthenticated =>
      'Your sign-in has expired. Sign in again and retry.';

  @override
  String get securityMfa_sheetNotEnabled =>
      'The login service hasn\'t enabled MFA yet. This isn\'t a problem with this device or your account.';

  @override
  String get securityMfa_sheetPasskeyDomainUnconfigured =>
      'LOOP needs domain credentials for passkeys first; this version doesn\'t have them yet.';

  @override
  String get securityMfa_sheetRejected => 'This didn\'t finish.';

  @override
  String get securityMfa_sheetS =>
      'An authenticator app generates 6-digit codes on your phone, such as Google Authenticator, Microsoft Authenticator or 1Password. Scan the code or enter the key with it. The key is issued by the login service; LOOP doesn\'t store it.';

  @override
  String get securityMfa_sheetUnavailable =>
      'Can\'t reach the login service right now.';

  @override
  String get securityMfa_sheetUnknown =>
      'Didn\'t finish; the login service gave no reason.';

  @override
  String get securityStepUp_controllerAsk =>
      'Verify your identity to turn on large-amount verification';

  @override
  String get securityStepUp_controllerAsk2 =>
      'Verify your identity to raise the large-amount verification threshold';

  @override
  String get securityStepUp_controllerAsk3 =>
      'Verify your identity to sign this large transaction';

  @override
  String get securityStepUp_controllerAsk4 =>
      'Verify your identity to sign this request';

  @override
  String get securityStepUp_controllerS =>
      'Verify your identity to turn off large-amount verification';

  @override
  String get securityStepUp_modelsIf =>
      'Amount must be between 1 and 1,000,000 USD1';

  @override
  String get securityStepUp_modelsLoopStepUpAfterApprovalText =>
      'Approval sent; the transaction wasn\'t started.';

  @override
  String securityStepUp_modelsLoopStepUpSubtitle(Object? stepUpThresholdLabel) {
    return 'Verify again at $stepUpThresholdLabel USD1 or more';
  }

  @override
  String get securityStepUp_modelsLoopStepUpThresholdError =>
      'Enter a whole number';

  @override
  String get securityStepUp_modelsSwitch => 'Cancelled. Nothing was changed.';

  @override
  String get securityStepUp_modelsSwitch2 =>
      'Identity verification didn\'t pass. Nothing was changed.';

  @override
  String get securityStepUp_widgetsActive => 'Confirm in your wallet';

  @override
  String get securityStepUp_widgetsBuild =>
      'Valid this time only; not remembered after reopening the app';

  @override
  String get securityStepUp_widgetsBuild2 =>
      'When a signed amount reaches or exceeds this value, this device verifies your identity first.';

  @override
  String get securityStepUp_widgetsDone => 'Verified';

  @override
  String get securityStepUp_widgetsError =>
      'Verification didn\'t pass. The amount wasn\'t changed.';

  @override
  String get securityStepUp_widgetsFailed => 'Not completed';

  @override
  String get securityStepUp_widgetsHint => 'e.g. 1000';

  @override
  String get securityStepUp_widgetsLabel => 'Verify identity';

  @override
  String get securityStepUp_widgetsLoopBadge => 'Loading…';

  @override
  String get securityStepUp_widgetsLoopSheetHeading =>
      'Large-amount verification threshold';

  @override
  String get securityStepUp_widgetsRefreshing => 'Verifying';

  @override
  String get securityStepUp_widgetsRefreshing2 => 'Refreshing quote';

  @override
  String get securityStepUp_widgetsS => 'Signing and broadcasting';

  @override
  String get securityStepUp_widgetsSX => 'Off';

  @override
  String securityStepUp_widgetsSecurityStepUpInfoBodyBody(
    Object? stepUpSubtitle,
  ) {
    return '$stepUpSubtitle. Tap this row to change the amount.';
  }

  @override
  String securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel(
    Object? capability,
    Object? stepUpTitle,
  ) {
    return '$stepUpTitle, unavailable: $capability';
  }

  @override
  String securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel2(
    Object? base,
    Object? on,
    Object? stepUpTitle,
  ) {
    return '$stepUpTitle, $on, $base, tap to change the amount';
  }

  @override
  String securityStepUp_widgetsSemanticLabel(Object? stepUpTitle) {
    return '$stepUpTitle, unavailable: no device verification available in this session';
  }

  @override
  String get securityStepUp_widgetsStepUpSigningTitle => 'Verifying identity';

  @override
  String get securityStepUp_widgetsStepUpThresholdFieldFootnote =>
      'Whole number, 1 to 1,000,000';

  @override
  String get securityStepUp_widgetsStepUpThresholdFieldLabel => 'Amount (USD1)';

  @override
  String get securityStepUp_widgetsStepUpTitle => 'Large-amount verification';

  @override
  String get securityStepUp_widgetsSubtitle =>
      'No device verification available in this session';

  @override
  String get securityStepUp_widgetsUnknown => 'Result unknown';

  @override
  String get securityStepUp_widgetsWaiting => 'Pending verification';

  @override
  String get shell_payUnavailableHeadline => 'Pay isn\'t available';

  @override
  String get shell_payUnavailableMessage =>
      'Pay isn\'t open yet. This page doesn\'t scan codes, ask for camera access, collect payment details or submit any transaction.';

  @override
  String get shell_pendingBackToCommunity => 'Back to community';

  @override
  String get shell_pendingHeadline => 'This page isn\'t open yet';

  @override
  String shell_pendingMessage(Object? title) {
    return '\"$title\" isn\'t open yet. Nothing is shown here and no action can be taken.';
  }

  @override
  String shell_pendingSourceLine(Object? label) {
    return 'Module: $label';
  }

  @override
  String get shell_tabChat => 'Chat';

  @override
  String get shell_tabIntel => 'Intel';

  @override
  String get shell_tabMe => 'Me';

  @override
  String shell_tabNewMessages(Object? label) {
    return '$label, new messages';
  }

  @override
  String get shell_tabSquare => 'Square';

  @override
  String get square_communityListBarrierLabel => 'Close sorting rules';

  @override
  String get square_communityListBarrierLabel2 => 'Close sorting';

  @override
  String get square_communityListBuild => 'Discover communities';

  @override
  String get square_communityListBuild2 =>
      'Sorting uses only verifiable numbers: members, creation time, power and 7-day discussion count. Popular doesn\'t mean recommended.';

  @override
  String get square_communityListBuild3 => 'How to list a community';

  @override
  String get square_communityListBuild4 =>
      'Any community can apply. After applying the status is \"In review\"; only communities verified by operations show a verified mark. This page doesn\'t imply any Mining weight.';

  @override
  String get square_communityListJoin => ', not joined';

  @override
  String get square_communityListJoined => 'Joined';

  @override
  String get square_communityListJoined2 => ', joined';

  @override
  String get square_communityListLoopSheetHeading => 'Sort';

  @override
  String get square_communityListLoopSheetHeading2 => 'Sorting rules';

  @override
  String get square_communityListMessage => 'Joined';

  @override
  String square_communityListMessage2(Object? label) {
    return '\"$label\" isn\'t available right now';
  }

  @override
  String get square_communityListMine => ', my community';

  @override
  String get square_communityListPending => ', in review';

  @override
  String get square_communityListPlaceholder => 'Search communities';

  @override
  String get square_communityListResource => 'Community directory';

  @override
  String get square_communityListSquareCommunityApplyLabel => 'Apply to list';

  @override
  String get square_communityListSquareCommunityCapabilityUnavailableTitle =>
      'Communities aren\'t available right now';

  @override
  String get square_communityListSquareCommunityJoinedEmptyAllLabel =>
      'View all';

  @override
  String get square_communityListSquareCommunityJoinedEmptyTitle =>
      'No joined communities yet';

  @override
  String get square_communityListSquareCommunityOrderingBackLabel =>
      'Sort by most members';

  @override
  String get square_communityListSquareCommunityRuleLine =>
      'Sorted by members / power / discussions / newest. Popular doesn\'t mean recommended.';

  @override
  String get square_communityListSquareCommunityRulesLabel =>
      'Rules and listing';

  @override
  String square_communityListSquareCommunitySortLabel(Object? label) {
    return 'Sort, $label';
  }

  @override
  String get square_communityListSquareCommunityStateEmptyMessage =>
      'No matching communities';

  @override
  String square_communityListSquareCommunitySubline(num memberCount) {
    String _temp0 = intl.Intl.pluralLogic(
      memberCount,
      locale: localeName,
      other: '$memberCount members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get square_communityListSquareMiningLabel => 'Power community';

  @override
  String get square_communityListSwitch => 'Join';

  @override
  String get square_communityListSwitch2 => 'Mine';

  @override
  String get square_communityListSwitch3 => 'Joining';

  @override
  String get square_feedCancelled =>
      'Result unconfirmed. Pull to refresh to check whether it was posted.';

  @override
  String get square_feedGlobal => 'Global';

  @override
  String get square_feedIdempotencyConflict =>
      'This was already submitted. Pull to refresh to check.';

  @override
  String get square_feedSwitch =>
      'Posting too fast. Wait a minute and try again.';

  @override
  String get square_feedSwitch2 => 'Write something before posting';

  @override
  String get square_feedSwitch3 =>
      '500 characters max. Shorten it and post again.';

  @override
  String get square_feedSwitch4 =>
      'The text has unsupported characters. Remove them and post again.';

  @override
  String get square_feedSwitch5 =>
      'The quoted token can\'t be loaded. Pick another or post without a token.';

  @override
  String get square_feedSwitch6 => 'Finish account setup before posting';

  @override
  String get square_feedSwitch7 => 'Not posted. Try again later.';

  @override
  String get square_feedTimedOut => 'No network connection. Not posted.';

  @override
  String get square_feedUnavailable =>
      'The feed isn\'t available right now. Try again later.';

  @override
  String get square_feedViewBuild => 'LOOP Official';

  @override
  String get square_feedViewBuild2 => 'Show more';

  @override
  String get square_feedViewBuild3 =>
      'Once deleted, no one can see it and it can\'t be restored.';

  @override
  String square_feedViewClaimHeadJoined(Object? got, Object? where) {
    return '$got $where';
  }

  @override
  String square_feedViewClaimHeadSpaced(Object? got, Object? where) {
    return '$got $where';
  }

  @override
  String square_feedViewClaimSentence(Object? head) {
    return '$head.';
  }

  @override
  String get square_feedViewHint => 'Search by ticker or name';

  @override
  String get square_feedViewHint2 => 'Say something…';

  @override
  String get square_feedViewLoopLabel => 'Linked token (optional)';

  @override
  String get square_feedViewLoopSheetHeading => 'Delete this post?';

  @override
  String square_feedViewMarketCapCompact(Object? memeCapLabel) {
    return 'Mcap $memeCapLabel';
  }

  @override
  String get square_feedViewMessage => 'Posted';

  @override
  String get square_feedViewMessage2 => 'Couldn\'t unlike. Try again later.';

  @override
  String get square_feedViewMessage3 => 'Couldn\'t like. Try again later.';

  @override
  String get square_feedViewMessage4 => 'Deleted';

  @override
  String get square_feedViewMessage5 => 'Couldn\'t delete. Try again later.';

  @override
  String square_feedViewS(Object? named) {
    return '$named filled the bonding pool. The official pool is live and buybacks have started.';
  }

  @override
  String square_feedViewS2(Object? amount, Object? named) {
    return 'Bought $amount of $named.';
  }

  @override
  String square_feedViewS3(Object? amount) {
    return 'Claimed $amount';
  }

  @override
  String square_feedViewS4(Object? formatDecimal, Object? head) {
    return '$head, weight $formatDecimal%.';
  }

  @override
  String get square_feedViewSquareComposerFieldLabel => 'Content';

  @override
  String get square_feedViewSquareComposerSendLabel => 'Posting…';

  @override
  String get square_feedViewSquareComposerSendLabel2 => 'Post';

  @override
  String get square_feedViewSquareComposerTokenEmpty => 'Loading tokens…';

  @override
  String get square_feedViewSquareComposerTokenEmpty2 =>
      'Tokens can\'t be loaded right now. Try again later.';

  @override
  String square_feedViewSquareComposerTokenMoreLabel(Object? hidden) {
    return '$hidden more';
  }

  @override
  String get square_feedViewSquareComposerTokenNoMatch => 'No matching tokens';

  @override
  String get square_feedViewSquareComposerTokenNoneLabel => 'No token';

  @override
  String get square_feedViewSquareComposerTokenSearchLabel => 'Search tokens';

  @override
  String square_feedViewSquareFeedAgeLabel(Object? day, Object? month) {
    return '$month $day';
  }

  @override
  String get square_feedViewSquareFeedComposeLabel => 'Post';

  @override
  String get square_feedViewSquareFeedEmptyTitle => 'No posts yet';

  @override
  String get square_feedViewSquareFeedUnavailableMessage =>
      'The feed can\'t be loaded right now';

  @override
  String get square_feedViewSquarePostBadgeClaim => 'Claim';

  @override
  String get square_feedViewSquarePostBadgeOpinion => 'Opinion';

  @override
  String get square_feedViewSquarePostBadgePinned => 'Pinned';

  @override
  String get square_feedViewSquarePostLikeLabel => 'Unlike';

  @override
  String get square_feedViewSquarePostLikeLabel2 => 'Like';

  @override
  String get square_feedViewSquarePostOwnOnLongPressHint => 'Delete this post';

  @override
  String get square_feedViewSwitch =>
      'This token filled the bonding pool. The official pool is live and buybacks have started.';

  @override
  String square_feedViewSwitch2(Object? amount) {
    return 'Bought $amount.';
  }

  @override
  String square_feedViewSwitch3(Object? named) {
    return 'in $named';
  }

  @override
  String square_feedViewSwitch4(Object? round) {
    return 'round $round';
  }

  @override
  String get square_feedViewSwitch5 => 'Claimed a reward';

  @override
  String get square_liveVoiceRoomsLiveVoiceRoomElapsedLabel => 'Just started';

  @override
  String square_liveVoiceRoomsLiveVoiceRoomElapsedLabel2(Object? inMinutes) {
    return 'Live ${inMinutes}m';
  }

  @override
  String square_liveVoiceRoomsLiveVoiceRoomElapsedLabel3(Object? inHours) {
    return 'Live ${inHours}h';
  }

  @override
  String square_liveVoiceRoomsLiveVoiceRoomElapsedLabel4(Object? inDays) {
    return 'Live ${inDays}d';
  }

  @override
  String square_screenListening(Object? room) {
    return '$room listening';
  }

  @override
  String get square_screenLoopBadge => 'Live';

  @override
  String get square_screenLoopBadge2 => 'Join first';

  @override
  String square_screenMessage(Object? communityName) {
    return 'Join \"$communityName\" to enter the voice room';
  }

  @override
  String get square_screenResource => 'Voice room list';

  @override
  String get square_screenSquareScreenTitle => 'Square';

  @override
  String get square_screenSquareVoiceRoomBrowseLabel => 'Browse communities';

  @override
  String get square_screenSquareVoiceRoomEmptyMessage =>
      'Communities show up here when they go live';

  @override
  String get square_screenSquareVoiceRoomEmptyTitle => 'No one is live yet';

  @override
  String get square_screenSquareVoiceRoomInRoom => 'In room';

  @override
  String get square_screenSquareVoiceRoomStateEmptyMessage =>
      'No voice rooms are live now';

  @override
  String get square_screenSquareVoiceRoomStateEmptyReason =>
      'Rooms show up here when a community goes live.';

  @override
  String square_screenSquareVoiceRoomTitleLabel(
    Object? communityName,
    Object? elapsed,
    Object? host,
    Object? inRoom,
    Object? listening,
    Object? room,
    Object? title,
  ) {
    return '$title, $communityName, host $host, $listening, $elapsed$inRoom$room';
  }

  @override
  String square_screenText(Object? host) {
    return 'Host $host';
  }

  @override
  String get square_screenVoiceRoomInRoomSuffix => ', you are in the room';

  @override
  String get square_screenVoiceRoomJoinFirstSuffix =>
      ', join the community to enter';

  @override
  String get walletTestnetFaucet_sheetBarrierLabel => 'Close Get funds';

  @override
  String get walletTestnetFaucet_sheetBusy =>
      'Sending to someone else. Try again in a few seconds';

  @override
  String get walletTestnetFaucet_sheetChainReadFailed =>
      'On-chain figures can\'t be fetched right now. Try again later';

  @override
  String walletTestnetFaucet_sheetCooldown(Object? testnetFaucetClaimedText) {
    return '$testnetFaucetClaimedText. Come back later';
  }

  @override
  String get walletTestnetFaucet_sheetDisabled => 'Claiming is closed';

  @override
  String walletTestnetFaucet_sheetIf(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchNativeSymbolText was sent but isn\'t confirmed yet; $loopLaunchUsd1SymbolText wasn\'t sent this time. $again';
  }

  @override
  String walletTestnetFaucet_sheetIf2(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchNativeSymbolText was sent; $loopLaunchUsd1SymbolText wasn\'t sent this time. $again';
  }

  @override
  String walletTestnetFaucet_sheetIf3(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchUsd1SymbolText arrived; $loopLaunchNativeSymbolText didn\'t go through this time. $again';
  }

  @override
  String walletTestnetFaucet_sheetIf4(Object? again) {
    return 'Only part of it was sent this time. $again';
  }

  @override
  String walletTestnetFaucet_sheetIf5(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchNativeSymbolText arrived; $loopLaunchUsd1SymbolText didn\'t go through this time. $again';
  }

  @override
  String get walletTestnetFaucet_sheetIf6 => 'Loading claim status…';

  @override
  String get walletTestnetFaucet_sheetLabel => 'Claimed recently';

  @override
  String walletTestnetFaucet_sheetLabel2(Object? testnetFaucetCooldownText) {
    return 'Claimed in the last $testnetFaucetCooldownText';
  }

  @override
  String walletTestnetFaucet_sheetLabel3(Object? testnetFaucetNextLabel) {
    return 'Next claim $testnetFaucetNextLabel';
  }

  @override
  String walletTestnetFaucet_sheetLabel4(Object? label) {
    return 'Copy $label transaction hash';
  }

  @override
  String walletTestnetFaucet_sheetLabel5(Object? label) {
    return 'Copy $label BscScan link';
  }

  @override
  String get walletTestnetFaucet_sheetMessage => 'Transaction hash copied';

  @override
  String get walletTestnetFaucet_sheetMessage2 => 'BscScan link copied';

  @override
  String get walletTestnetFaucet_sheetRuntimeUnavailable =>
      'Claiming isn\'t available right now. Try again later';

  @override
  String walletTestnetFaucet_sheetS(Object? testnetFaucetCooldownText) {
    return 'You can claim again in $testnetFaucetCooldownText';
  }

  @override
  String walletTestnetFaucet_sheetS2(Object? testnetFaucetCooldownText) {
    return 'This wallet already claimed in the last $testnetFaucetCooldownText';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetAddressLabel =>
      'Receiving wallet';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetBusyLabel =>
      'Sending… (about 30 seconds)';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText => '24 hours';

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText2(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText3(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText4(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText5(num seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText6 =>
      'You can claim again later';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText7 =>
      'This wallet claimed recently';

  @override
  String walletTestnetFaucet_sheetTestnetFaucetGranted(
    Object? formatDecimal,
    Object? formatDecimal2,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return 'Sent $formatDecimal $loopLaunchNativeSymbolText and $formatDecimal2 $loopLaunchUsd1SymbolText. Arrival is final once confirmed on-chain; your balance refreshes automatically.';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetInFlightLaterText =>
      'Check the result here later';

  @override
  String walletTestnetFaucet_sheetTestnetFaucetIntro(
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return 'Claim $loopLaunchNativeSymbolText and $loopLaunchUsd1SymbolText to the current wallet for fees and trading, once every 24 hours.';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetIntro2(
    Object? formatDecimal,
    Object? formatDecimal2,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
    Object? testnetFaucetCooldownText,
  ) {
    return 'This sends $formatDecimal $loopLaunchNativeSymbolText and $formatDecimal2 $loopLaunchUsd1SymbolText to the current wallet; you can claim once every $testnetFaucetCooldownText.';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetNextLabel(Object? time) {
    return 'Tomorrow $time';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetNextLabel2(
    Object? day,
    Object? month,
    Object? time,
  ) {
    return '$month $day, $time';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetNotOwnedText =>
      'Only the built-in wallet you\'re signed in with can claim';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetOperatorLowText =>
      'The funding pool is low right now. Try again later';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetTimedOutLaterText =>
      'Still sending. Check back later';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetTitle => 'Get funds';

  @override
  String walletTestnetFaucet_sheetText(
    Object? testnetFaucetClaimedText,
    Object? testnetFaucetNextLabel,
  ) {
    return '$testnetFaucetClaimedText. Next claim $testnetFaucetNextLabel';
  }

  @override
  String get walletTestnetFaucet_sheetTitle =>
      'Claim status can\'t be loaded right now';

  @override
  String get walletTestnetFaucet_sheetTransferFailed =>
      'Nothing was sent this time. You can retry';

  @override
  String walletTestnetFaucet_sheetUsd1Unavailable(
    Object? loopLaunchUsd1SymbolText,
  ) {
    return 'The $loopLaunchUsd1SymbolText contract isn\'t available right now. Try again later';
  }

  @override
  String get walletTestnetFaucet_sheetWrongChain =>
      'Claiming isn\'t supported on the current network';

  @override
  String get wallet_activityExportDismissed =>
      'CSV created, but no share destination was chosen';

  @override
  String get wallet_activityExportEmpty => 'No records in this range to export';

  @override
  String get wallet_activityExportFailed =>
      'Export didn\'t finish; nothing left this device';

  @override
  String get wallet_activityExportIncoming => 'Received';

  @override
  String get wallet_activityExportOutgoing => 'Sent';

  @override
  String get wallet_activityExportSelf => 'Self-transfer';

  @override
  String get wallet_activityExportShared =>
      'Records exported. Choose a destination in the share sheet';

  @override
  String get wallet_activityExportSwitch => 'Time (UTC)';

  @override
  String get wallet_activityExportSwitch2 => 'Direction';

  @override
  String get wallet_activityExportSwitch3 => 'Asset ID';

  @override
  String get wallet_activityExportSwitch4 => 'Amount (base units)';

  @override
  String get wallet_activityExportSwitch5 => 'Counterparty address';

  @override
  String get wallet_activityExportSwitch6 => 'Log index';

  @override
  String get wallet_activityExportSwitch7 => 'Block';

  @override
  String get wallet_activityExportSwitch8 => 'Status';

  @override
  String get wallet_activityExportUnavailable =>
      'System sharing isn\'t set up in this session; nothing was exported';

  @override
  String get wallet_approvalScreensApprovalActionLimitLabel =>
      'Switch to limited approval';

  @override
  String get wallet_approvalScreensApprovalActionRevokeLabel =>
      'Revoke approval (approve 0)';

  @override
  String get wallet_approvalScreensApprovalDecodedUnavailableLabel =>
      'Call can\'t be decoded';

  @override
  String get wallet_approvalScreensApprovalGuardCapabilityBlockTitle =>
      'Approvals aren\'t available right now';

  @override
  String get wallet_approvalScreensApprovalGuardErrorTitle =>
      'The approval couldn\'t be prepared';

  @override
  String get wallet_approvalScreensApprovalGuardExactLabel =>
      'Approve a limited amount';

  @override
  String wallet_approvalScreensApprovalGuardExactLabel2(
    Object? symbol,
    Object? wire,
  ) {
    return 'Approve a limit of $wire $symbol';
  }

  @override
  String get wallet_approvalScreensApprovalGuardFolioCaption =>
      'Token, spender, amount and the decoded call are shown in full before signing.';

  @override
  String wallet_approvalScreensApprovalGuardFolioHeading(Object? symbol) {
    return '$symbol approval';
  }

  @override
  String wallet_approvalScreensApprovalGuardFolioHeading2(Object? symbol) {
    return 'Unlimited $symbol approval';
  }

  @override
  String wallet_approvalScreensApprovalGuardFolioHeading3(
    Object? display,
    Object? symbol,
  ) {
    return '$display $symbol limit';
  }

  @override
  String get wallet_approvalScreensApprovalGuardFolioKicker =>
      'Approval request';

  @override
  String get wallet_approvalScreensApprovalGuardFolioStamp => 'Protected';

  @override
  String get wallet_approvalScreensApprovalGuardRestartLabel =>
      'Switch back to limited approval';

  @override
  String get wallet_approvalScreensApprovalGuardScreenTitle => 'Approval guard';

  @override
  String get wallet_approvalScreensApprovalGuardSignLabel =>
      'Facts expired · Prepare again';

  @override
  String wallet_approvalScreensApprovalGuardSignLabel2(
    Object? moneyCountdownLabel,
  ) {
    return 'Confirm approval ($moneyCountdownLabel)';
  }

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedConfirmedBody =>
      'You\'ve confirmed twice. Once signed, this spender can keep using this token\'s entire balance, and the permission stays valid after you leave their interface until you revoke it in Token approvals.';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedConfirmedTitle =>
      'This is an unlimited approval';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedLabel =>
      'Approve unlimited anyway';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedWarningBody =>
      'A contract with an unlimited allowance can move this token\'s entire balance at any time until you revoke it. LOOP\'s default is to approve only the amount needed this time.';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedWarningTitle =>
      'Unlimited approval means ongoing access to your entire balance';

  @override
  String get wallet_approvalScreensApprovalUnlimitedAcceptLabel =>
      'I understand, approve unlimited anyway';

  @override
  String get wallet_approvalScreensApprovalUnlimitedCancelLabel =>
      'Use a limit instead';

  @override
  String get wallet_approvalScreensApprovalsBatchActionLabel =>
      'Revoke in batch';

  @override
  String get wallet_approvalScreensApprovalsCapabilityBlockTitle =>
      'Token approvals aren\'t available right now';

  @override
  String wallet_approvalScreensApprovalsFreshnessText(
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? groupedFigure3,
    Object? relativeTime,
  ) {
    return 'Approvals since block $groupedFigure · Indexed $groupedFigure2 / head $groupedFigure3 · observed $relativeTime';
  }

  @override
  String get wallet_approvalScreensApprovalsPageBlockMessage =>
      'The approval list isn\'t available right now';

  @override
  String get wallet_approvalScreensApprovalsRevokeErrorTitle =>
      'The revoke couldn\'t be prepared';

  @override
  String get wallet_approvalScreensBuild => 'Approval check';

  @override
  String get wallet_approvalScreensConfirmUnlimited =>
      'An unlimited allowance doesn\'t expire over time or when this transaction ends. This spender can later move this token\'s entire balance without asking you again. It\'s only taken back when you send approve(spender, 0) from Token approvals.';

  @override
  String get wallet_approvalScreensEmptyMessage =>
      'This wallet has no active approvals';

  @override
  String get wallet_approvalScreensLabel => 'Function';

  @override
  String get wallet_approvalScreensLabel2 => 'Unlimited approval';

  @override
  String get wallet_approvalScreensLabel3 => 'Limited approval';

  @override
  String wallet_approvalScreensLabelText(Object? symbol) {
    return 'Approval amount ($symbol)';
  }

  @override
  String get wallet_approvalScreensLoopBadge => 'Can\'t load';

  @override
  String get wallet_approvalScreensLoopBadge2 => 'Unlimited';

  @override
  String get wallet_approvalScreensLoopBadge3 => 'Limited';

  @override
  String get wallet_approvalScreensLoopLabel => 'Limited approval (default)';

  @override
  String get wallet_approvalScreensLoopLabel2 => 'Decoded call';

  @override
  String get wallet_approvalScreensLoopLabel3 => 'Sorted by amount';

  @override
  String get wallet_approvalScreensLoopSheetHeading =>
      'Confirm unlimited approval';

  @override
  String get wallet_approvalScreensMessage =>
      'Batch revoke isn\'t available yet. Each revoke is a separate signature.';

  @override
  String get wallet_approvalScreensMoneyOfflinePause => 'Prepare approval';

  @override
  String get wallet_approvalScreensMoneyOfflinePause2 => 'Revoke approval';

  @override
  String get wallet_approvalScreensMoneyOfflinePause3 => 'Change amount';

  @override
  String wallet_approvalScreensS(Object? display) {
    return 'Allowance $display';
  }

  @override
  String wallet_approvalScreensSubtitle(
    Object? groupedFigure,
    Object? truncatedAddress,
    Object? unlimited,
  ) {
    return '$truncatedAddress · $unlimited · block $groupedFigure';
  }

  @override
  String get wallet_approvalScreensText =>
      'Approve only the amount this transaction needs.';

  @override
  String get wallet_approvalScreensValue => 'Native assets have no approvals';

  @override
  String get wallet_deferredScreensBlocked => 'Blocked';

  @override
  String get wallet_deferredScreensBody =>
      'A scan result never starts signing directly; amount, network and recipient are shown again.';

  @override
  String get wallet_deferredScreensBody2 =>
      'Choose the source chain, destination chain and amount first; then estimated fees and arrival time are shown.';

  @override
  String get wallet_deferredScreensBody3 =>
      'Source chain confirmation, bridging and destination arrival are three separate states.';

  @override
  String get wallet_deferredScreensBody4 =>
      'The check runs entirely on this device: it won\'t open this URL, follow redirects or connect a wallet.';

  @override
  String get wallet_deferredScreensBridgeFolioHeading =>
      'Bridge isn\'t available yet';

  @override
  String get wallet_deferredScreensBridgeFolioKicker => 'Bridge intent';

  @override
  String get wallet_deferredScreensBridgeFolioStamp => 'Review';

  @override
  String get wallet_deferredScreensBridgeFromCaption => 'From';

  @override
  String get wallet_deferredScreensBridgeOpenStatusLabel =>
      'View bridge progress';

  @override
  String get wallet_deferredScreensBridgeScopeNoticeBody =>
      'Bridge fees, received amount and estimated time can only come from a real route. Without a route there are no such numbers, and this page won\'t substitute sample data.';

  @override
  String get wallet_deferredScreensBridgeScopeNoticeTitle => 'About Bridge';

  @override
  String get wallet_deferredScreensBridgeScopeNoticeTitle2 =>
      'No estimates appear here';

  @override
  String get wallet_deferredScreensBridgeStartLabel => 'Start bridge';

  @override
  String get wallet_deferredScreensBridgeStatusBackToWalletLabel =>
      'Back to Wallet';

  @override
  String get wallet_deferredScreensBridgeStatusFolioHeading =>
      'Bridge progress isn\'t available yet';

  @override
  String get wallet_deferredScreensBridgeStatusLeaveNoticeBody =>
      'Once Bridge is available, it continues in the background, notifies you when done, and can be viewed in transaction history.';

  @override
  String get wallet_deferredScreensBridgeStatusLeaveNoticeTitle =>
      'About bridge progress';

  @override
  String get wallet_deferredScreensBridgeStatusLeaveNoticeTitle2 =>
      'You can leave this page';

  @override
  String get wallet_deferredScreensBridgeStatusPageBlockMessage =>
      'No bridge to track yet';

  @override
  String get wallet_deferredScreensBridgeStatusScreenTitle => 'Bridge progress';

  @override
  String get wallet_deferredScreensBridgeToCaption => 'To';

  @override
  String wallet_deferredScreensDappConfusableNoticeBody(
    Object? confusableReading,
  ) {
    return 'It looks like $confusableReading, but it contains look-alike characters that aren\'t Latin letters. This is the most common phishing trick, so it was blocked.';
  }

  @override
  String get wallet_deferredScreensDappConfusableNoticeTitle =>
      'This domain is impersonating another domain';

  @override
  String get wallet_deferredScreensDappExecutionUnavailableLabel =>
      'Wallet connection and signing aren\'t available yet';

  @override
  String get wallet_deferredScreensDappFindingsEmptyMessage =>
      'This only means the address itself is well-formed; it doesn\'t mean the site is trustworthy.';

  @override
  String get wallet_deferredScreensDappFindingsEmptyTitle => 'No issues found';

  @override
  String get wallet_deferredScreensDappFolioKicker => 'DApp check · Read only';

  @override
  String get wallet_deferredScreensDappNoFetchNoticeBody =>
      'The check is purely local: no requests, no DNS lookups and no redirects, so the domain you see is exactly the one you typed.';

  @override
  String get wallet_deferredScreensDappNoFetchNoticeTitle =>
      'This page won\'t open the URL';

  @override
  String get wallet_deferredScreensDappOmniboxHintText =>
      'Search assets / communities / users / Launch / DApps / URLs';

  @override
  String get wallet_deferredScreensDappReputationUnavailableLabel =>
      'Domain reputation can\'t be loaded';

  @override
  String get wallet_deferredScreensDappReviewCanonicalSubtitle =>
      'Couldn\'t normalize; blocked';

  @override
  String get wallet_deferredScreensDappReviewCanonicalTitle =>
      'Normalized result';

  @override
  String get wallet_deferredScreensDappReviewEmptyMessage =>
      'Enter a URL to see the normalized result and any issues here.';

  @override
  String get wallet_deferredScreensDappReviewTypedTitle => 'What you typed';

  @override
  String get wallet_deferredScreensDappScreenTitle => 'DApp check';

  @override
  String get wallet_deferredScreensFlagged => 'Check origin';

  @override
  String get wallet_deferredScreensFlagged2 => 'Needs attention';

  @override
  String get wallet_deferredScreensLoopFolioPrimary => 'No URL to check yet';

  @override
  String get wallet_deferredScreensLoopLabel => 'Steps';

  @override
  String get wallet_deferredScreensLoopLabel2 => 'Local check';

  @override
  String get wallet_deferredScreensLoopLabel3 => 'Findings';

  @override
  String get wallet_deferredScreensLoopLabel4 => 'Domain reputation';

  @override
  String get wallet_deferredScreensLoopLabel5 => 'Connection and signing';

  @override
  String get wallet_deferredScreensNormalized => 'Origin matches';

  @override
  String get wallet_deferredScreensNormalized2 => 'Normalized';

  @override
  String get wallet_deferredScreensNormalized3 => 'Readable';

  @override
  String get wallet_deferredScreensPayFolioHeading => 'Scan to pay';

  @override
  String get wallet_deferredScreensPayFolioStamp => 'Camera';

  @override
  String get wallet_deferredScreensPayWhyNoticeBody =>
      'Payments involve compliance and payment provider approval and need a separate review. Community, Mining and Launch come first.';

  @override
  String get wallet_deferredScreensPayWhyNoticeTitle => 'About Scan to pay';

  @override
  String get wallet_deferredScreensPayWhyNoticeTitle2 => 'Why not now';

  @override
  String get wallet_deferredScreensS => 'This URL can\'t be used';

  @override
  String wallet_deferredScreensSemanticsLabel(Object? title) {
    return 'View $title';
  }

  @override
  String get wallet_deferredScreensSubtitle => 'Block';

  @override
  String get wallet_deferredScreensSubtitle2 => 'Notice';

  @override
  String get wallet_homeBarrierLabel => 'Close total assets notes';

  @override
  String get wallet_homeBuild => 'Holdings breakdown';

  @override
  String get wallet_homeBuild2 => 'Manage';

  @override
  String wallet_homeIf(Object? hidden) {
    return 'Pending $hidden';
  }

  @override
  String get wallet_homeIf2 => 'Data sources don\'t match yet';

  @override
  String wallet_homeLabel(Object? address) {
    return '$address, copy wallet address';
  }

  @override
  String get wallet_homeLabel10 => 'Snapshot observed';

  @override
  String get wallet_homeLabel11 => 'Fee reserve';

  @override
  String wallet_homeLabel12(Object? label) {
    return '$label, not available right now';
  }

  @override
  String wallet_homeLabel13(Object? symbol) {
    return '$symbol, balance can\'t be loaded';
  }

  @override
  String get wallet_homeLabel14 => 'Other';

  @override
  String wallet_homeLabel15(
    Object? amount,
    Object? changeText,
    Object? subtitle,
    Object? symbol,
    Object? valueText,
  ) {
    return '$symbol, $subtitle, balance $amount, value $valueText$changeText';
  }

  @override
  String get wallet_homeLabel16 => 'Wallet management';

  @override
  String get wallet_homeLabel2 => 'Show amounts';

  @override
  String get wallet_homeLabel3 => 'Hide amounts';

  @override
  String get wallet_homeLabel4 => 'Price source';

  @override
  String get wallet_homeLabel5 => 'Observed';

  @override
  String get wallet_homeLabel6 => 'Not included';

  @override
  String get wallet_homeLabel7 => '24h change';

  @override
  String get wallet_homeLabel8 => 'Balance block';

  @override
  String get wallet_homeLabel9 => 'Net value snapshot source';

  @override
  String get wallet_homeLoopBadge => 'Earns power';

  @override
  String get wallet_homeLoopNetWorthChangeAvailable =>
      'Calculated from the same price read';

  @override
  String get wallet_homeLoopNetWorthChangeUnavailable =>
      'Some assets have no 24h price change, so it\'s hidden for now';

  @override
  String get wallet_homeLoopSheetHeading => 'About total assets';

  @override
  String get wallet_homeLoopSheetHeading2 => 'Holdings that earn power';

  @override
  String get wallet_homeMessage => 'Wallet address copied';

  @override
  String wallet_homeMessage2(Object? reasonCodeText) {
    return 'Balance can\'t be loaded · $reasonCodeText';
  }

  @override
  String wallet_homeS(Object? valueText, Object? walletRowChangeText) {
    return 'Value $valueText, 24h $walletRowChangeText';
  }

  @override
  String wallet_homeSX(Object? changeText) {
    return ', 24h $changeText';
  }

  @override
  String wallet_homeSemanticLabel(
    Object? amount,
    Object? symbol,
    Object? valueLabel,
  ) {
    return '$symbol, balance $amount, $valueLabel';
  }

  @override
  String get wallet_homeShowWalletPowerSheet =>
      'Registered assets in your wallet earn mining power by their weights, and power decides how much LOOP you get each day. Community tokens count only after you join an approved linked community. See each asset\'s weight and power on the Mining page.';

  @override
  String get wallet_homeShowWalletTotalInfoSheet =>
      'Total assets is the value of registered assets at current prices, for display only; it isn\'t an available balance. The usable amount is the \"Usable\" figure on each asset page.';

  @override
  String wallet_homeSwitch(Object? valueText) {
    return 'Value $valueText';
  }

  @override
  String get wallet_homeText => 'Total assets';

  @override
  String get wallet_homeUnreadText => 'Not available right now';

  @override
  String wallet_homeValue(num unavailableCount) {
    String _temp0 = intl.Intl.pluralLogic(
      unavailableCount,
      locale: localeName,
      other: '$unavailableCount assets have no price yet',
      one: '1 asset has no price yet',
    );
    return '$_temp0';
  }

  @override
  String get wallet_homeValueText => 'No value yet';

  @override
  String wallet_homeWalletDistributionBarLabel(Object? label) {
    return 'Holdings breakdown, $label';
  }

  @override
  String get wallet_homeWalletPowerSheetBarrierLabel => 'Close power notes';

  @override
  String get wallet_homeWalletPowerTagLabel =>
      'Holdings earn power, view notes';

  @override
  String wallet_homeWalletRowChangeUsd(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assets have no price yet, not included',
      one: '1 asset has no price yet, not included',
    );
    return '$_temp0';
  }

  @override
  String get wallet_miningHooksFor => 'No weight';

  @override
  String wallet_miningHooksLoopPowerHint(Object? power) {
    return '$power power';
  }

  @override
  String get wallet_miningHooksLoopPowerHint2 => 'No estimate for today yet';

  @override
  String wallet_miningHooksLoopPowerHint3(Object? powerFigure) {
    return '$powerFigure power';
  }

  @override
  String wallet_miningHooksLoopPowerHint4(Object? weight) {
    return 'Weight $weight×';
  }

  @override
  String wallet_miningHooksS(Object? daily) {
    return 'Est. today $daily LOOP';
  }

  @override
  String get wallet_miningHooksWalletAssetPowerHintText =>
      'This asset\'s mining contribution';

  @override
  String wallet_miningHooksWalletAssetPowerText(Object? loopFigureDash) {
    return 'Power $loopFigureDash';
  }

  @override
  String wallet_miningHooksWalletAssetPowerText2(Object? powerFigure) {
    return 'Power $powerFigure';
  }

  @override
  String get wallet_miningHooksWalletPowerHintText =>
      'Wallet holdings are earning power';

  @override
  String get wallet_miningHooksWalletPowerHintText2 =>
      'Wallet holdings earn power by weight';

  @override
  String get wallet_moneyActionNameApprove => 'Approval';

  @override
  String get wallet_moneyActionNameRevoke => 'Revoke';

  @override
  String get wallet_moneyActionNameSend => 'Send';

  @override
  String get wallet_moneyActionNameSendNft => 'NFT send';

  @override
  String get wallet_moneyActionNameSwap => 'Swap';

  @override
  String get wallet_moneyActionsAssetBlocked =>
      'This asset is blocked; no fund actions are allowed.';

  @override
  String get wallet_moneyActionsAssetNotInAllowlist =>
      'This asset isn\'t in the current range of supported assets, so this action didn\'t pass. LOOP maintains the range and it can\'t be changed in the app; use an asset within the range.';

  @override
  String wallet_moneyActionsBuild(Object? moneyActionTitle) {
    return '$moneyActionTitle · Final confirmation';
  }

  @override
  String wallet_moneyActionsBuild2(Object? symbol) {
    return 'Unlimited $symbol';
  }

  @override
  String get wallet_moneyActionsBuild3 =>
      'No fresh market data this time, so no value is shown.';

  @override
  String wallet_moneyActionsCanaryCeilingExceeded(Object? figures) {
    return '${figures}This action exceeds the per-transaction limit. No transaction was submitted. LOOP sets the limit; lower the amount and try again.';
  }

  @override
  String wallet_moneyActionsCanaryDailyCeilingExceeded(
    Object? budget,
    Object? figures,
  ) {
    return '$figures${budget}This action would exceed the 24-hour cumulative limit. No transaction was submitted. LOOP sets the limit; lower the amount, or wait until the 24-hour window rolls over.';
  }

  @override
  String get wallet_moneyActionsCounterpartyNotInAllowlist =>
      'This recipient address isn\'t on the current allowed list, so this action didn\'t pass and no transaction was submitted. LOOP maintains the list and it can\'t be changed in the app; use an address on the list.';

  @override
  String get wallet_moneyActionsMoneyCapabilityCheckingLabel =>
      'Checking availability';

  @override
  String wallet_moneyActionsMoneyFactsFooterText(
    Object? groupedFigure,
    Object? observed,
  ) {
    return 'Block $groupedFigure · $observed';
  }

  @override
  String wallet_moneyActionsMoneyPolicyRefusalText(
    Object? ceilingUsd,
    Object? exposureUsd,
  ) {
    return 'This time \$$exposureUsd · limit \$$ceilingUsd. ';
  }

  @override
  String wallet_moneyActionsMoneyPolicyRefusalText2(
    Object? remainingUsd,
    Object? spentUsd,
  ) {
    return 'Used \$$spentUsd in 24 hours · \$$remainingUsd left. ';
  }

  @override
  String get wallet_moneyActionsNativeAssetNotApprovable =>
      'Native BNB has no approvals: it isn\'t ERC-20 and has no allowance to approve or revoke. This step doesn\'t apply to native assets.';

  @override
  String wallet_moneyActionsObserved(Object? relativeTime) {
    return 'Facts observed $relativeTime';
  }

  @override
  String get wallet_moneyActionsPriceImpactBlocked =>
      'The price impact of this swap is too high, so it was blocked. Lower the amount or try again later.';

  @override
  String get wallet_moneyActionsPurpose =>
      'This step requires two-step verification, which isn\'t available yet. Nothing was signed, broadcast or submitted. Check the verification methods available in Security Center.';

  @override
  String get wallet_moneyActionsReason =>
      'Submitted, waiting for the on-chain receipt. A success message doesn\'t mean it\'s done on-chain.';

  @override
  String get wallet_moneyActionsReason2 =>
      'This action was submitted and the result is unknown, so it\'s locked. Check the result page; don\'t submit again.';

  @override
  String wallet_moneyActionsS(Object? txHash) {
    return 'The wallet broadcast it ($txHash), but this report wasn\'t accepted. The transaction may already be on-chain. Check the result page and report again later; don\'t sign again.';
  }

  @override
  String wallet_moneyActionsS2(Object? formatUsd, Object? intent) {
    return 'Estimated value $formatUsd · source $intent';
  }

  @override
  String get wallet_moneyActionsSetState =>
      'The wallet signed, but this submission hasn\'t been recorded yet. Check the status on the result page; don\'t sign again.';

  @override
  String get wallet_moneyActionsSetState2 =>
      'The wallet didn\'t finish signing. No transaction was submitted.';

  @override
  String get wallet_moneyActionsSigningApprove => 'Confirm approval';

  @override
  String get wallet_moneyActionsSigningLabel => 'Recipient';

  @override
  String get wallet_moneyActionsSigningLabel2 => 'Allowance';

  @override
  String get wallet_moneyActionsSigningLabel3 => 'Max network fee';

  @override
  String get wallet_moneyActionsSigningRevoke => 'Confirm revoke';

  @override
  String get wallet_moneyActionsSigningSend => 'Confirm send';

  @override
  String get wallet_moneyActionsSigningSendNft => 'Confirm NFT send';

  @override
  String get wallet_moneyActionsSigningSwap => 'Confirm swap';

  @override
  String get wallet_moneyActionsSigningValue => 'Unlimited allowance';

  @override
  String get wallet_moneyActionsSwitch =>
      'The current policy doesn\'t allow this action. No transaction was submitted. We won\'t guess which rule applies.';

  @override
  String get wallet_moneyActionsTitle =>
      'This step requires two-step verification; no transaction was submitted';

  @override
  String get wallet_moneyActionsTitle2 =>
      'This action isn\'t available in your region; no transaction was submitted';

  @override
  String get wallet_moneyActionsTitle3 => 'Native assets can\'t be approved';

  @override
  String get wallet_moneyActionsTitle4 =>
      'Rejected by policy; no transaction was submitted';

  @override
  String get wallet_moneyActionsUnknown => 'Unknown (locked)';

  @override
  String wallet_moneyActionsUnlimitedExposureExceedsCeiling(Object? figures) {
    return '${figures}An unlimited approval\'s exposure is based on the current balance and exceeds the per-transaction limit. Use a limited approval, or lower this asset\'s balance first.';
  }

  @override
  String get wallet_moneyActionsWalletMoneyActionsS2 => 'Not labeled';

  @override
  String get wallet_moneyAssetPickerHintText => 'Search name or symbol';

  @override
  String wallet_moneyAssetPickerLoopBalanceAvailable(
    Object? formatDecimal,
    Object? name,
  ) {
    return '$name · Usable $formatDecimal';
  }

  @override
  String wallet_moneyAssetPickerSummary(Object? folded) {
    return 'Zero-balance assets · $folded';
  }

  @override
  String get wallet_moneyAssetPickerTitle => 'Choose asset';

  @override
  String get wallet_moneyAssetPickerTitle2 =>
      'This wallet has no readable assets yet';

  @override
  String get wallet_moneyAssetPickerTitle3 => 'No matching assets';

  @override
  String get wallet_moneyAssetPickerTitle4 => 'No assets with a usable balance';

  @override
  String get wallet_networthBuild => 'Collapse net value trend';

  @override
  String get wallet_networthBuild2 => 'Today\'s P&L';

  @override
  String get wallet_networthDetail =>
      'The trend is the USD value the server records hourly for this wallet, for display only; it isn\'t an available balance.';

  @override
  String wallet_networthIf(
    Object? observed,
    Object? published,
    Object? rate,
    Object? stale,
    Object? walletFxSourceLabel,
  ) {
    return 'CNY converted at $walletFxSourceLabel 1 USD = $rate CNY (published $published, observed $observed)$stale';
  }

  @override
  String wallet_networthLabel(Object? action, Object? value) {
    return 'Today\'s P&L $value, $action';
  }

  @override
  String get wallet_networthS => 'Expand net value trend';

  @override
  String get wallet_networthSource => 'LOOP net value snapshot';

  @override
  String get wallet_networthSwitch => 'ECB reference rate';

  @override
  String get wallet_networthSwitch2 => 'Reference rate';

  @override
  String get wallet_networthWalletNetworthChartEmptyMessage =>
      'No net value records in this range yet · recorded hourly; the line starts once you have assets';

  @override
  String wallet_networthWalletNetworthChartLabel(
    Object? highText,
    Object? label,
    Object? lowText,
  ) {
    return '$label net value trend, high $highText, low $lowText';
  }

  @override
  String get wallet_networthWalletNetworthChartUnavailableMessage =>
      'Net value trend can\'t be loaded right now';

  @override
  String get wallet_networthWalletNetworthChevronLabel => 'Collapse';

  @override
  String get wallet_networthWalletNetworthChevronLabel2 => 'Net value trend';

  @override
  String get wallet_networthWalletNetworthRangesSemanticLabel =>
      'Net value trend range';

  @override
  String get wallet_nftSendContractUnsupported =>
      'Sending this NFT isn\'t supported yet';

  @override
  String get wallet_nftSendIdempotencyConflict =>
      'This send was already submitted. Check the latest status';

  @override
  String wallet_nftSendInsufficientBalance(Object? loopLaunchNativeSymbolText) {
    return 'Not enough $loopLaunchNativeSymbolText for fees. Top up and try again';
  }

  @override
  String get wallet_nftSendNftSendDisabledText =>
      'Sending NFTs isn\'t supported yet';

  @override
  String get wallet_nftSendNotOwned =>
      'This NFT is no longer in your wallet. Go back and choose again';

  @override
  String get wallet_nftSendRecipientRejects =>
      'The recipient address doesn\'t accept this NFT';

  @override
  String get wallet_nftSendRecipientSelf => 'You can\'t send to yourself';

  @override
  String get wallet_nftSendSimulationFailed =>
      'This send didn\'t pass simulation. Try again later';

  @override
  String wallet_readBuild(Object? hidden) {
    return 'Usable $hidden';
  }

  @override
  String wallet_readBuyback(Object? ticker) {
    return 'Buyback · $ticker';
  }

  @override
  String get wallet_readCreating =>
      'Requesting an embedded wallet from Privy; the list refreshes automatically when done.';

  @override
  String wallet_readFailed(Object? provisioning) {
    return 'The last creation didn\'t finish: $provisioning Your sign-in is unchanged; you can try again.';
  }

  @override
  String get wallet_readIf => 'Only the sum of valued assets, not total assets';

  @override
  String wallet_readIf2(Object? valuationCurrency) {
    return 'Net value ($valuationCurrency)';
  }

  @override
  String get wallet_readLabel => 'Creating…';

  @override
  String get wallet_readLabel2 => 'Create wallet';

  @override
  String get wallet_readLabel3 => 'Loading list';

  @override
  String get wallet_readLabel4 => 'Loading receiving address';

  @override
  String wallet_readLoopBalanceAvailable(Object? formatDecimal) {
    return 'Usable $formatDecimal';
  }

  @override
  String wallet_readLoopBalanceAvailable2(Object? formatDecimal) {
    return 'Fee reserve $formatDecimal';
  }

  @override
  String wallet_readLoopBalanceUnavailable(Object? reasonCodeText) {
    return 'Usable $reasonCodeText';
  }

  @override
  String wallet_readLoopBalanceUnavailable2(Object? reasonCodeText) {
    return 'Fee reserve $reasonCodeText';
  }

  @override
  String get wallet_readMessage =>
      'Development preview doesn\'t create a real wallet or call Privy.';

  @override
  String get wallet_readMessage2 =>
      'This session isn\'t verified, so a wallet can\'t be created right now. Sign in again and retry.';

  @override
  String get wallet_readMessage3 => 'Wallet created';

  @override
  String get wallet_readModelsDay => '1D';

  @override
  String get wallet_readModelsHalfYear => '180D';

  @override
  String get wallet_readModelsMonth => '30D';

  @override
  String get wallet_readModelsSwitch =>
      'Only receives assets on the BNB Smart Chain (BSC) network. Assets sent to this address from other networks may be lost permanently.';

  @override
  String get wallet_readModelsSwitch2 =>
      'Make sure the sender\'s network matches the one shown here.';

  @override
  String get wallet_readModelsWeek => '7D';

  @override
  String get wallet_readModelsYear => '360D';

  @override
  String wallet_readNftMint(Object? ticker) {
    return 'Mint badge · $ticker';
  }

  @override
  String wallet_readPoolBuy(Object? ticker) {
    return 'Buy $ticker';
  }

  @override
  String wallet_readPoolSell(Object? ticker) {
    return 'Sell $ticker';
  }

  @override
  String wallet_readRewardClaim(Object? ticker) {
    return 'Claim rewards · $ticker';
  }

  @override
  String wallet_readRowBalance(Object? amount) {
    return 'Balance $amount';
  }

  @override
  String get wallet_readRowBalanceMissing => 'Balance can\'t be loaded';

  @override
  String wallet_readS(Object? formatDecimal) {
    return 'Pending $formatDecimal';
  }

  @override
  String get wallet_readScreensBalancesFailureLine =>
      'This account doesn\'t have permission to read balances';

  @override
  String get wallet_readScreensBuild => 'Native transfers';

  @override
  String get wallet_readScreensBuild2 => 'Bridge / Mining';

  @override
  String get wallet_readScreensCopy => 'Address copied';

  @override
  String get wallet_readScreensEmptyMessage =>
      'The wallet list hasn\'t loaded yet';

  @override
  String get wallet_readScreensEmptyMessage2 =>
      'This wallet doesn\'t have this row';

  @override
  String get wallet_readScreensEmptyMessage3 =>
      'No transfers for this asset yet';

  @override
  String get wallet_readScreensEmptyMessage4 =>
      'No receiving address available';

  @override
  String get wallet_readScreensEmptyMessage5 => 'No embedded wallet';

  @override
  String get wallet_readScreensEmptyMessage6 => 'No connected external wallets';

  @override
  String get wallet_readScreensEmptyMessage7 => 'No on-chain activity yet';

  @override
  String get wallet_readScreensEmptyMessage8 => 'No networks to show';

  @override
  String get wallet_readScreensEmptyReason =>
      'This isn\'t \"no wallet\"; the list just wasn\'t loaded this time.';

  @override
  String get wallet_readScreensEmptyReason2 =>
      'The indexer has read this range, but it has no transfers for this wallet.';

  @override
  String get wallet_readScreensExternalWalletKind => 'External wallet';

  @override
  String wallet_readScreensFor(Object? best) {
    return 'Latency ${best}ms';
  }

  @override
  String get wallet_readScreensFor2 => 'Latency unknown';

  @override
  String wallet_readScreensIf(Object? ticker) {
    return '$ticker · balance not loaded yet';
  }

  @override
  String get wallet_readScreensIf2 =>
      'Name and decimals come only from on-chain calls';

  @override
  String wallet_readScreensIf3(Object? groupedFigure) {
    return 'Block height $groupedFigure';
  }

  @override
  String wallet_readScreensIf4(Object? relativeTime) {
    return 'Checked $relativeTime';
  }

  @override
  String get wallet_readScreensLabel => 'On-chain balance';

  @override
  String wallet_readScreensLabel10(Object? decimals) {
    return 'Balance in base units (integer, $decimals decimals)';
  }

  @override
  String get wallet_readScreensLabel11 => 'Registration status';

  @override
  String get wallet_readScreensLabel12 => 'Contract address';

  @override
  String wallet_readScreensLabel13(Object? name) {
    return 'Network $name';
  }

  @override
  String get wallet_readScreensLabel14 => 'Native BNB transfers unavailable';

  @override
  String get wallet_readScreensLabel15 =>
      'Bridge and mining claim history unavailable';

  @override
  String get wallet_readScreensLabel16 =>
      'MEME records not available right now';

  @override
  String get wallet_readScreensLabel2 => 'Usable';

  @override
  String get wallet_readScreensLabel3 => 'Current price';

  @override
  String get wallet_readScreensLabel4 => 'Value';

  @override
  String get wallet_readScreensLabel5 => 'Available';

  @override
  String get wallet_readScreensLabel6 => 'Usable (after fee reserve)';

  @override
  String get wallet_readScreensLabel7 =>
      'Pending incoming (not included in available)';

  @override
  String get wallet_readScreensLabel8 => 'Unit price';

  @override
  String get wallet_readScreensLabel9 => 'Decimals';

  @override
  String wallet_readScreensLaunchChainTitle(Object? name) {
    return '$name (Launch)';
  }

  @override
  String get wallet_readScreensLoopBadge => 'Data may be out of date';

  @override
  String get wallet_readScreensLoopBadge2 => 'In use';

  @override
  String get wallet_readScreensLoopBadge3 => 'Archived';

  @override
  String get wallet_readScreensLoopBadge4 => 'Off';

  @override
  String get wallet_readScreensLoopBadge5 => 'Running';

  @override
  String get wallet_readScreensLoopFolioPrimary => 'Balance not loaded yet';

  @override
  String get wallet_readScreensLoopLabel => 'Mining contribution';

  @override
  String get wallet_readScreensLoopLabel2 => 'On-chain breakdown';

  @override
  String get wallet_readScreensLoopLabel3 => 'Transfers';

  @override
  String get wallet_readScreensLoopLabel4 => 'Embedded wallet';

  @override
  String get wallet_readScreensLoopLabel5 => 'External wallets';

  @override
  String get wallet_readScreensLoopLabel6 => 'Enabled';

  @override
  String get wallet_readScreensLoopLabel7 => 'RPC endpoints';

  @override
  String get wallet_readScreensLoopLabel8 => 'Indexer';

  @override
  String get wallet_readScreensLoopOfflineState => 'Switch active wallet';

  @override
  String get wallet_readScreensLoopOfflineState2 => 'Load more';

  @override
  String get wallet_readScreensLoopProvenanceFooter =>
      'Holdings in all linked wallets count toward power, no need to move them. LOOP ID is your identity; wallets are replaceable credentials and addresses aren\'t account identifiers.';

  @override
  String wallet_readScreensLoopProvenanceFooter2(Object? groupedFigure) {
    return 'Indexed height $groupedFigure';
  }

  @override
  String wallet_readScreensLoopProvenanceFooter3(Object? groupedFigure) {
    return 'Data $groupedFigure blocks behind';
  }

  @override
  String get wallet_readScreensLoopProvenanceLine => 'LOOP on-chain index';

  @override
  String wallet_readScreensLoopRecordRow(Object? groupedFigure) {
    return 'Height $groupedFigure';
  }

  @override
  String wallet_readScreensLoopRecordRow2(Object? groupedFigure) {
    return '$groupedFigure blocks behind';
  }

  @override
  String wallet_readScreensLoopRecordRow3(num reorgCount) {
    String _temp0 = intl.Intl.pluralLogic(
      reorgCount,
      locale: localeName,
      other: '$reorgCount reorgs',
      one: '1 reorg',
    );
    return '$_temp0';
  }

  @override
  String wallet_readScreensLoopRecordRow4(Object? index) {
    return 'Endpoint $index';
  }

  @override
  String wallet_readScreensLoopRecordRow5(Object? latencyMs) {
    return 'Latency ${latencyMs}ms';
  }

  @override
  String wallet_readScreensLoopRecordRow6(Object? label) {
    return 'Checked $label';
  }

  @override
  String wallet_readScreensLoopSheetHeading(Object? limit) {
    return 'Link up to $limit external wallets';
  }

  @override
  String get wallet_readScreensLoopSheetHeading2 => 'Connect external wallet';

  @override
  String wallet_readScreensLoopSheetHeading3(Object? truncatedAddress) {
    return 'External wallet $truncatedAddress';
  }

  @override
  String get wallet_readScreensLoopSheetHeading4 => 'Unlink external wallet';

  @override
  String get wallet_readScreensLoopSheetHeading5 => 'Transaction details';

  @override
  String get wallet_readScreensMeTradesCapabilityBlockTitle =>
      'Wallet activity isn\'t available right now';

  @override
  String get wallet_readScreensMessage =>
      'This device can\'t open the share sheet. Copy the address instead';

  @override
  String get wallet_readScreensMessage10 => 'External wallet unlinked';

  @override
  String get wallet_readScreensMessage11 => 'Active wallet switched';

  @override
  String get wallet_readScreensMessage12 =>
      'Records haven\'t loaded yet; there\'s nothing to export.';

  @override
  String wallet_readScreensMessage13(Object? what) {
    return '$what copied';
  }

  @override
  String get wallet_readScreensMessage2 =>
      'The wallet list isn\'t available right now, so external wallets can\'t be connected.';

  @override
  String get wallet_readScreensMessage3 =>
      'The wallet list hasn\'t loaded yet. Connect an external wallet once it loads.';

  @override
  String get wallet_readScreensMessage4 =>
      'Wallet linking didn\'t finish. Retry.';

  @override
  String wallet_readScreensMessage5(Object? limit) {
    return 'You\'ve reached the limit of $limit external wallets. Unlink one first';
  }

  @override
  String get wallet_readScreensMessage6 =>
      'External wallet linked; the wallet list will refresh shortly';

  @override
  String get wallet_readScreensMessage7 => 'External wallet linked';

  @override
  String get wallet_readScreensMessage8 =>
      'Unlinking didn\'t finish. Try again later.';

  @override
  String get wallet_readScreensMessage9 =>
      'External wallet unlinked; the wallet list will refresh shortly';

  @override
  String get wallet_readScreensNetworksCapabilityBlockTitle =>
      'On-chain reads aren\'t available right now';

  @override
  String get wallet_readScreensNetworksChainMismatchLabel =>
      'The endpoint didn\'t return BNB Smart Chain';

  @override
  String wallet_readScreensNetworksChainParametersText(
    Object? chainId,
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? status,
  ) {
    return '$status$chainId · $groupedFigure confirmations · reorg tracking $groupedFigure2 blocks';
  }

  @override
  String wallet_readScreensNetworksChainRowTrailing(
    Object? endpoints,
    Object? healthyCount,
  ) {
    return '$healthyCount / $endpoints healthy';
  }

  @override
  String get wallet_readScreensNetworksCustomRpcTitle => 'Custom RPC';

  @override
  String wallet_readScreensNetworksLaunchChainRowSubtitle(
    Object? chainId,
    Object? groupedFigure,
    Object? groupedFigure2,
  ) {
    return '$chainId · $groupedFigure confirmations · reorg tracking $groupedFigure2 blocks';
  }

  @override
  String wallet_readScreensNetworksLaunchChainUnavailableLabel(Object? name) {
    return '$name (Launch) has no RPC configured';
  }

  @override
  String get wallet_readScreensNetworksNoEndpointsLabel =>
      'No RPC endpoints configured';

  @override
  String get wallet_readScreensNetworksOperatorDisclosureSummary =>
      'Endpoints, indexer and chain parameters';

  @override
  String wallet_readScreensNetworksRegistryText(
    Object? readableAssetCount,
    Object? registeredPoolCount,
  ) {
    return '$readableAssetCount readable assets · $registeredPoolCount registered pools';
  }

  @override
  String get wallet_readScreensNetworksScreenTitle => 'Networks and RPC';

  @override
  String wallet_readScreensNetworksTestnetSubtitle(Object? name) {
    return '$name · Used by Launch only';
  }

  @override
  String get wallet_readScreensOffline =>
      'Network disconnected; balance not loaded';

  @override
  String wallet_readScreensOpenExternalWallet(Object? truncatedAddress) {
    return 'Wallet $truncatedAddress becomes the current wallet for balances, activity and Receive.';
  }

  @override
  String get wallet_readScreensRateLimited =>
      'Too many requests. Try again later';

  @override
  String get wallet_readScreensReceiveCopyAddressLabel => 'Copy address';

  @override
  String get wallet_readScreensReceiveNoNetworkDetail =>
      'Receivable networks can\'t be loaded right now.';

  @override
  String get wallet_readScreensReceiveNoNetworkMessage =>
      'No receivable network';

  @override
  String wallet_readScreensReceiveQrLabel(Object? name) {
    return '$name receive QR code';
  }

  @override
  String wallet_readScreensReceiveQrUnavailableMessage(Object? reasonCodeText) {
    return 'QR code unavailable · $reasonCodeText';
  }

  @override
  String get wallet_readScreensReceiveWarningTitle =>
      'Only receive assets on this network';

  @override
  String get wallet_readScreensS => 'Error';

  @override
  String get wallet_readScreensS2 => 'Published';

  @override
  String wallet_readScreensS2X(Object? blockDelta) {
    return ' ($blockDelta blocks apart)';
  }

  @override
  String get wallet_readScreensS3 => 'Not running';

  @override
  String wallet_readScreensS3X(Object? groupedFigure) {
    return 'Block $groupedFigure · ';
  }

  @override
  String wallet_readScreensSX(Object? groupedFigure) {
    return 'Launch chain balances are read from block $groupedFigure and aren\'t included in total assets.';
  }

  @override
  String wallet_readScreensSubject(Object? name) {
    return '$name receiving address';
  }

  @override
  String get wallet_readScreensSwitch => 'Balance can\'t be loaded right now';

  @override
  String wallet_readScreensSwitch2(Object? factSourceLabel) {
    return 'Source $factSourceLabel';
  }

  @override
  String wallet_readScreensSwitch3(Object? relativeTime) {
    return 'Observed $relativeTime';
  }

  @override
  String wallet_readScreensSwitch4(Object? truncatedAssetId) {
    return 'Proxy asset $truncatedAssetId';
  }

  @override
  String get wallet_readScreensSwitch5 => 'Pending check';

  @override
  String wallet_readScreensText(Object? address, Object? name) {
    return '$name receiving address\n$address';
  }

  @override
  String get wallet_readScreensTimedOut => 'Read timed out; balance not loaded';

  @override
  String get wallet_readScreensTitle => 'This page didn\'t finish loading';

  @override
  String get wallet_readScreensTitle2 => 'No records in this range';

  @override
  String get wallet_readScreensTxEntrySheetCopyHashLabel => 'Copy hash';

  @override
  String get wallet_readScreensTxEntrySheetCopyLinkLabel => 'Copy BscScan link';

  @override
  String get wallet_readScreensTxEntrySheetExplorerNoticeBody =>
      'LOOP can\'t open an external browser directly yet. Copy the link and open it in a browser to see the same transaction on-chain.';

  @override
  String get wallet_readScreensTxEntrySheetExplorerNoticeTitle =>
      'Paste it into a browser yourself';

  @override
  String get wallet_readScreensTxHistoryExportActionLabel => 'Exporting';

  @override
  String get wallet_readScreensTxHistoryExportActionLabel2 => 'Export';

  @override
  String get wallet_readScreensUnavailable =>
      'On-chain balance can\'t be loaded right now';

  @override
  String get wallet_readScreensUnreachable => 'Unreachable';

  @override
  String get wallet_readScreensWalletAssetActivityEmptyMessage =>
      'The indexer has read this range, but it has no transfers for this asset.';

  @override
  String get wallet_readScreensWalletAssetBalanceMissingLabel =>
      'On-chain balance can\'t be loaded';

  @override
  String wallet_readScreensWalletAssetCrosscheckBody(Object? crossCheck) {
    return 'The on-chain reading doesn\'t match the value reported by Privy$crossCheck. This page always shows the on-chain reading; the cross-check doesn\'t change it.';
  }

  @override
  String get wallet_readScreensWalletAssetCrosscheckUnavailableLabel =>
      'Cross-check with Privy unavailable';

  @override
  String get wallet_readScreensWalletAssetFactsDisclosureSummary =>
      'Balance notes and asset facts';

  @override
  String get wallet_readScreensWalletAssetFolioKicker => 'Wallet asset';

  @override
  String get wallet_readScreensWalletAssetHistoryEntrySubtitle =>
      'All ERC-20 transfers for this wallet, from the on-chain index';

  @override
  String get wallet_readScreensWalletAssetHistoryEntryTitle =>
      'Transaction history';

  @override
  String get wallet_readScreensWalletAssetInvalidIdentityMessage =>
      'This page only accepts a canonical CAIP assetId; no balance was requested.';

  @override
  String get wallet_readScreensWalletAssetInvalidIdentityTitle =>
      'No usable asset ID in the route';

  @override
  String get wallet_readScreensWalletAssetInvalidTitle =>
      'Can\'t open this asset';

  @override
  String wallet_readScreensWalletAssetMarketActionTitle(Object? asset) {
    return 'Wallet asset · $asset';
  }

  @override
  String get wallet_readScreensWalletAssetMissingRowDetail =>
      'Only registered assets show a balance.';

  @override
  String get wallet_readScreensWalletAssetMissingRowMessage =>
      'This asset isn\'t on the readable list';

  @override
  String get wallet_readScreensWalletAssetPendingMissingLabel =>
      'Pending amount unavailable';

  @override
  String get wallet_readScreensWalletAssetProxied => 'Priced in WBNB';

  @override
  String get wallet_readScreensWalletAssetValuationUnavailableLabel =>
      'Value unavailable';

  @override
  String get wallet_readScreensWalletBalancesEmptyTitle => 'No assets yet';

  @override
  String get wallet_readScreensWalletCapabilityBlockTitle =>
      'Wallet reads aren\'t available right now';

  @override
  String get wallet_readScreensWalletDirectoryNoActiveTitle =>
      'No current wallet selected yet';

  @override
  String get wallet_readScreensWalletFolioUnreadText => 'No wallet yet';

  @override
  String get wallet_readScreensWalletFolioUnreadText2 => 'No wallet selected';

  @override
  String get wallet_readScreensWalletFolioUnreadText3 => 'Offline';

  @override
  String get wallet_readScreensWalletNftEmptyTitle => 'No NFTs yet';

  @override
  String get wallet_readScreensWalletNftUnavailableMessage =>
      'MEME v2 isn\'t available yet, so project NFTs can\'t be loaded right now';

  @override
  String get wallet_readScreensWalletScreenTitle => 'Me';

  @override
  String wallet_readScreensWalletSnapshotFooterDetail(
    Object? formatDecimal,
    Object? groupedFigure,
    Object? launchSnapshot,
  ) {
    return 'Every balance row is read from the same block ($groupedFigure confirmations). Native BNB keeps $formatDecimal BNB as a fee reserve, not included in usable. $launchSnapshot';
  }

  @override
  String wallet_readScreensWalletSnapshotFooterPrefix(Object? groupedFigure) {
    return 'Block $groupedFigure';
  }

  @override
  String get wallet_readScreensWalletsActivateConfirmLabel => 'Switch';

  @override
  String get wallet_readScreensWalletsAddActionLabel => 'Add';

  @override
  String get wallet_readScreensWalletsAddSheetContinueLabel =>
      'Continue connecting';

  @override
  String get wallet_readScreensWalletsAddSheetNetworkBody =>
      'Networks in mainland China need a VPN to connect external wallets.';

  @override
  String get wallet_readScreensWalletsAddSheetNetworkTitle =>
      'Mainland China networks need a VPN';

  @override
  String get wallet_readScreensWalletsAddSheetReasonBody =>
      'External wallets are only used to calculate power; you can\'t trade or claim rewards with them in LOOP. LOOP never gets your private key.';

  @override
  String get wallet_readScreensWalletsAddSheetReasonTitle =>
      'External wallets only count toward power';

  @override
  String get wallet_readScreensWalletsAddSheetScopeBody =>
      'Community tokens in every linked wallet count toward power; no need to move assets into one wallet.';

  @override
  String get wallet_readScreensWalletsAddSheetScopeTitle =>
      'Holdings in all linked wallets count toward power';

  @override
  String get wallet_readScreensWalletsCapabilityBlockTitle =>
      'The wallet list isn\'t available right now';

  @override
  String wallet_readScreensWalletsLimitSheetBody(Object? limit) {
    return 'You can link up to $limit external wallets. Unlink one before connecting a new wallet.';
  }

  @override
  String get wallet_readScreensWalletsScreenTitle => 'My wallets';

  @override
  String wallet_readScreensWalletsSourceText(Object? relativeTime) {
    return 'Source Privy · observed $relativeTime';
  }

  @override
  String get wallet_readScreensWalletsSourceTitle => 'About linked wallets';

  @override
  String get wallet_readScreensWalletsSwitchErrorTitle =>
      'Active wallet wasn\'t switched';

  @override
  String get wallet_readScreensWalletsUnlinkActionLabel => 'Unlink this wallet';

  @override
  String get wallet_readScreensWalletsUnlinkConfirmLabel => 'Unlink';

  @override
  String wallet_readScreensWalletsUnlinkSheetBody(Object? truncatedAddress) {
    return 'After unlinking, this wallet\'s holdings stop counting toward power from the next hour. Assets in wallet $truncatedAddress aren\'t affected, and you can link it again later.';
  }

  @override
  String get wallet_readScreensWhat => 'Explorer link';

  @override
  String wallet_readSemanticLabel(Object? symbol) {
    return 'Usable, power and fee reserve for $symbol';
  }

  @override
  String wallet_readSwitch(Object? launch2Usd1Label) {
    return 'Spent $launch2Usd1Label';
  }

  @override
  String get wallet_readSwitch2 =>
      'LOOP will create a Privy embedded wallet for this account. The address is a public on-chain fact, not an account identifier.';

  @override
  String get wallet_readTitle => 'This account has no wallet yet';

  @override
  String wallet_readTransferFrom(Object? address) {
    return 'From $address';
  }

  @override
  String wallet_readTransferTo(Object? address) {
    return 'To $address';
  }

  @override
  String get wallet_readWalletActivityDayLabel => 'Yesterday';

  @override
  String wallet_readWalletActivityDayLabel2(Object? day, Object? month) {
    return '$month $day';
  }

  @override
  String wallet_readWalletActivityDayLabel3(
    Object? day,
    Object? month,
    Object? year,
  ) {
    return '$month $day, $year';
  }

  @override
  String get wallet_readWalletLaunch2ActivityRow => 'Launch chain';

  @override
  String get wallet_readWalletLaunch2ActivityRow2 => 'Confirming';

  @override
  String wallet_readWalletLaunchChainUnavailableLabel(Object? name) {
    return '$name balance unavailable';
  }

  @override
  String get wallet_readWalletLaunchUsd1Failed => 'Couldn\'t load';

  @override
  String get wallet_readWalletNetworthNotSpendable =>
      'Not an available balance';

  @override
  String wallet_readWalletNetworthPartial(Object? unavailableCount) {
    return 'Partial value · $unavailableCount without price';
  }

  @override
  String get wallet_readWalletNetworthUnavailableLabel =>
      'Net value unavailable';

  @override
  String get wallet_readWalletReadFailed => 'Unknown reason';

  @override
  String wallet_readWalletSnapshotFooterText(
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? relativeTime,
  ) {
    return 'Block $groupedFigure · $groupedFigure2 confirmations · observed $relativeTime';
  }

  @override
  String wallet_sendScreensBody(
    Object? moneyActionTitle,
    Object? moneyIntentStateLabel,
  ) {
    return '$moneyActionTitle · $moneyIntentStateLabel. Preparing a new one will invalidate it; if it\'s already signed and broadcast, report or cancel it first.';
  }

  @override
  String get wallet_sendScreensBuild => 'First transfer to this address';

  @override
  String get wallet_sendScreensBuild2 => 'Recipient is a contract address';

  @override
  String get wallet_sendScreensBuild3 =>
      'Malicious address screening unavailable';

  @override
  String get wallet_sendScreensBuild4 => 'Not filled in yet';

  @override
  String get wallet_sendScreensBuild5 => 'Not loaded yet';

  @override
  String get wallet_sendScreensBuild6 =>
      'These two rows are what you entered in the previous step, not server facts yet. Network fee, balance and simulation appear together once this transfer is prepared.';

  @override
  String get wallet_sendScreensBuild7 =>
      'There\'s no source for arrival time, so no made-up seconds here. After submitting, track it by confirmations on the result page; that\'s the only progress.';

  @override
  String get wallet_sendScreensEmptyMessage =>
      'This account has no wallet that can send yet';

  @override
  String get wallet_sendScreensEmptyReason =>
      'Only the Privy embedded wallet can sign and broadcast from this device.';

  @override
  String get wallet_sendScreensLabel => 'Recipient address';

  @override
  String get wallet_sendScreensLabel2 => 'Amount and asset';

  @override
  String get wallet_sendScreensLabel3 => 'Confirm and sign';

  @override
  String wallet_sendScreensLoopBalanceAvailable(
    Object? formatDecimal,
    Object? symbol,
  ) {
    return 'Usable $formatDecimal $symbol (after fee reserve)';
  }

  @override
  String get wallet_sendScreensMissing =>
      'One more step: waiting for address check.';

  @override
  String get wallet_sendScreensMoneyOfflinePause => 'Check address';

  @override
  String get wallet_sendScreensMoneyPendingCancelLabel =>
      'Cancel and prepare again';

  @override
  String get wallet_sendScreensMoneyPendingOpenLabel => 'View that transaction';

  @override
  String wallet_sendScreensRecipientHint(Object? chainName) {
    return '0x… ($chainName)';
  }

  @override
  String get wallet_sendScreensRecipientStep => 'Checking address…';

  @override
  String wallet_sendScreensRecipientStep2(Object? chainName) {
    return 'Address checked · $chainName';
  }

  @override
  String get wallet_sendScreensRecipientStep3 =>
      'Invalid address format: starts with 0x, 42 characters';

  @override
  String get wallet_sendScreensSendAddressNextMissing =>
      'One more step: enter the full recipient address (starts with 0x, 42 characters).';

  @override
  String get wallet_sendScreensSendAddressScreenTitle => 'Send NFT';

  @override
  String get wallet_sendScreensSendAmountMaxErrorText =>
      'Exceeds usable balance';

  @override
  String get wallet_sendScreensSendAmountMaxHintText => 'Enter amount';

  @override
  String get wallet_sendScreensSendAmountNextMissing =>
      'One more step: choose the asset to send.';

  @override
  String get wallet_sendScreensSendAmountNextMissing2 =>
      'One more step: enter the amount to send.';

  @override
  String get wallet_sendScreensSendAmountNextMissing3 =>
      'The amount exceeds your usable balance. Lower it.';

  @override
  String get wallet_sendScreensSendAmountRecipientSubtitle =>
      'Recipient address · Checked';

  @override
  String get wallet_sendScreensSendAmountRecipientTrailingCaption => 'Change';

  @override
  String get wallet_sendScreensSendAmountTitle => 'Amount to send';

  @override
  String wallet_sendScreensSendAmountTitle2(Object? symbol) {
    return 'Amount to send ($symbol)';
  }

  @override
  String wallet_sendScreensSendAssetSelectorSubtitle(num candidates) {
    String _temp0 = intl.Intl.pluralLogic(
      candidates,
      locale: localeName,
      other: '$candidates assets can be sent',
      one: '1 asset can be sent',
    );
    return '$_temp0';
  }

  @override
  String get wallet_sendScreensSendAssetsEmptyMessage =>
      'Once assets are registered, each one always keeps a row here.';

  @override
  String get wallet_sendScreensSendAssetsEmptyTitle => 'No readable assets yet';

  @override
  String get wallet_sendScreensSendCapabilityBlockTitle =>
      'Send isn\'t available right now';

  @override
  String get wallet_sendScreensSendConfirmDraftArrivalLabel =>
      'Estimated arrival';

  @override
  String get wallet_sendScreensSendConfirmDraftArrivalValue => 'Not estimated';

  @override
  String get wallet_sendScreensSendConfirmDraftFeeLabel => 'Network fee';

  @override
  String get wallet_sendScreensSendConfirmExpiredBody =>
      'Prepare it again before signing.';

  @override
  String get wallet_sendScreensSendConfirmExpiredBody2 =>
      'Balance, fees and simulation all come from the same moment. Prepare it again before signing.';

  @override
  String get wallet_sendScreensSendConfirmExpiredTitle => 'Facts expired';

  @override
  String get wallet_sendScreensSendConfirmPowerBody =>
      'Power drops with your holdings after sending. The exact figure can\'t be loaded right now, so no estimate is made here.';

  @override
  String get wallet_sendScreensSendConfirmPowerTitle =>
      'Power drops with your holdings';

  @override
  String wallet_sendScreensSendConfirmSignLabel(Object? moneyCountdownLabel) {
    return 'Confirm send ($moneyCountdownLabel)';
  }

  @override
  String get wallet_sendScreensSendConfirmSigningExitText =>
      'Signing is done on this device by the Privy embedded wallet; every fund action goes through the same signing sheet, the only signing exit in the product.';

  @override
  String get wallet_sendScreensSendConfirmSigningExitTitle =>
      'Unified signing exit';

  @override
  String get wallet_sendScreensSendConfirmSimulationFailedTitle =>
      'Simulation didn\'t pass; can\'t sign';

  @override
  String get wallet_sendScreensSendPowerNoticeBody =>
      'After sending a weighted community token, power drops with your holdings. The exact figure can\'t be loaded right now, so no estimate is made here.';

  @override
  String get wallet_sendScreensSendPowerNoticeTitle =>
      'Sending lowers your power';

  @override
  String get wallet_sendScreensSendRecipientBasisText =>
      'First-time recipient is judged by your own ERC-20 transfer history indexed in LOOP';

  @override
  String get wallet_sendScreensSendRecipientBasisTitle => 'Basis';

  @override
  String wallet_sendScreensSendRecipientChecksSummary(
    Object? first,
    Object? headlines,
  ) {
    return 'Address check · $headlines to confirm · $first';
  }

  @override
  String get wallet_sendScreensSendRecipientContractBody =>
      'Sending directly to a contract address may lose this asset permanently. Make sure this contract actually accepts direct transfers.';

  @override
  String get wallet_sendScreensSendRecipientFirstTimeBody =>
      'This address isn\'t in your own indexed transfer history. Check the full address character by character before continuing.';

  @override
  String get wallet_sendScreensSendRecipientPasteLabel => 'Paste';

  @override
  String get wallet_sendScreensSendRecipientPrefill =>
      'Recipient address from scan, checked automatically';

  @override
  String get wallet_sendScreensSendRecipientPreflightErrorTitle =>
      'Address check didn\'t succeed';

  @override
  String get wallet_sendScreensSendRecipientScanLabel => 'Scan';

  @override
  String wallet_sendScreensSendStepBarLabel(
    Object? label,
    Object? step,
    Object? total,
  ) {
    return 'Step $step of $total, $label';
  }

  @override
  String get wallet_sendScreensTitle => 'This wallet has an unfinished action';

  @override
  String get wallet_swapScreensBalanceLineFor =>
      'Choose the asset to pay with first; its usable balance shows here.';

  @override
  String get wallet_swapScreensBalanceLineFor2 => 'Balance not loaded yet.';

  @override
  String get wallet_swapScreensBalanceLineFor3 =>
      'This wallet doesn\'t have this row, so its balance can\'t be read.';

  @override
  String get wallet_swapScreensEmptyMessage =>
      'This account has no wallet that can swap yet';

  @override
  String get wallet_swapScreensIf => 'Can\'t price';

  @override
  String get wallet_swapScreensLabel => 'Price impact';

  @override
  String get wallet_swapScreensLabel2 => 'Platform fee';

  @override
  String get wallet_swapScreensLabel3 => 'Per-transaction limit';

  @override
  String get wallet_swapScreensLabel4 => 'Estimated network fee';

  @override
  String get wallet_swapScreensLabel5 => 'LOOP service fee';

  @override
  String get wallet_swapScreensLabel6 => 'Market value';

  @override
  String wallet_swapScreensLoopBalanceAvailable(
    Object? formatDecimal,
    Object? symbol,
  ) {
    return 'Usable $formatDecimal $symbol';
  }

  @override
  String get wallet_swapScreensLoopLabel => 'Fee breakdown';

  @override
  String get wallet_swapScreensLoopProvenanceFooter =>
      'Only the final quote is shown: per-hop details appear only when the quote provider supplies a path, and it didn\'t this time.';

  @override
  String get wallet_swapScreensMoneyOfflinePause => 'Quote';

  @override
  String get wallet_swapScreensS => 'Shown after quote';

  @override
  String get wallet_swapScreensSwapCapabilityBlockLabel =>
      'Swap isn\'t available right now';

  @override
  String get wallet_swapScreensSwapConfirmActionLabel =>
      'Quote expired · Get new quote';

  @override
  String get wallet_swapScreensSwapConfirmActionLabel2 =>
      'Swap is still being verified';

  @override
  String wallet_swapScreensSwapConfirmActionLabel3(
    Object? moneyCountdownLabel,
  ) {
    return 'Swap ($moneyCountdownLabel)';
  }

  @override
  String get wallet_swapScreensSwapDestinationBlockedCaption => 'Receive';

  @override
  String get wallet_swapScreensSwapFlipLabel => 'Swap pay and receive';

  @override
  String get wallet_swapScreensSwapImpactBlockedTitle =>
      'Price impact exceeds the hard block line';

  @override
  String get wallet_swapScreensSwapImpactConfirmBody =>
      'This swap will noticeably move the price. Slippage and price impact are different: slippage is the limit you set, price impact is the shift this trade itself causes.';

  @override
  String get wallet_swapScreensSwapImpactConfirmTitle =>
      'Price impact is between 1% and 5%';

  @override
  String get wallet_swapScreensSwapInfoActionLabel => 'About Swap';

  @override
  String get wallet_swapScreensSwapPowerNoticeBody =>
      'The power change after buying can\'t be loaded right now, so no estimate is made here.';

  @override
  String get wallet_swapScreensSwapPowerNoticeTitle =>
      'Power impact unavailable';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel => 'Quoting…';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel2 =>
      'Choose assets to pay and receive';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel3 =>
      'Enter an amount to get a quote';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel4 => 'Get new quote';

  @override
  String get wallet_swapScreensSwapQuoteErrorTitle => 'Couldn\'t get a quote';

  @override
  String wallet_swapScreensSwapQuoteProvenanceText(
    Object? provider,
    Object? quote,
    Object? relativeTime,
  ) {
    return 'Quoted by $provider · $relativeTime$quote';
  }

  @override
  String get wallet_swapScreensSwapRouteActionLabel => 'Quote and fee details';

  @override
  String get wallet_swapScreensSwapRouteBackLabel => 'Back to Swap to confirm';

  @override
  String get wallet_swapScreensSwapRouteEntryLabel => 'Quote details and fees';

  @override
  String wallet_swapScreensSwapRouteProvenanceText(
    Object? priceImpact,
    Object? provider,
    Object? quoteTtlSeconds,
  ) {
    return 'Quoted by $provider · pricing source $priceImpact · valid for ${quoteTtlSeconds}s';
  }

  @override
  String get wallet_swapScreensSwapRouteScreenTitle => 'Quote and fees';

  @override
  String get wallet_swapScreensSwapRoutingNoticeBody =>
      'LOOP doesn\'t build its own routes or split hops. Only the final quote returned by Privy is shown here; swapped assets go straight into this wallet.';

  @override
  String get wallet_swapScreensSwapRoutingNoticeTitle =>
      'The provider chooses the route';

  @override
  String get wallet_swapScreensText =>
      'I understand the price impact is between 1% and 5% and want to continue';

  @override
  String get wallet_swapScreensTitle => 'Choose asset to pay';

  @override
  String get wallet_swapScreensTitle2 => 'Choose asset to receive';

  @override
  String get wallet_swapScreensValue => 'Not set';

  @override
  String wallet_swapScreensValue2(
    Object? display,
    Object? moneySlippageLabel,
    Object? symbol,
  ) {
    return '$display $symbol (slippage $moneySlippageLabel)';
  }

  @override
  String get wallet_swapScreensWalletSwapScreensSwapQuoteProvenanceText =>
      ' · Pending product confirmation';

  @override
  String wallet_txResultCancelled(Object? action) {
    return '$action cancelled';
  }

  @override
  String wallet_txResultConfirmed(Object? action) {
    return '$action confirmed';
  }

  @override
  String get wallet_txResultEmptyMessage =>
      'This action has no readable status';

  @override
  String wallet_txResultExpired(Object? action) {
    return '$action expired';
  }

  @override
  String wallet_txResultFailed(Object? action) {
    return '$action failed';
  }

  @override
  String get wallet_txResultIf =>
      'Result, transaction hash and next steps are all here; no new quotes are mixed in.';

  @override
  String wallet_txResultIf2(Object? groupedFigure, Object? receipt) {
    return 'Block $groupedFigure · $receipt';
  }

  @override
  String get wallet_txResultMessage => 'Transaction confirmed';

  @override
  String wallet_txResultReverted(Object? action) {
    return '$action reverted';
  }

  @override
  String wallet_txResultS(Object? groupedFigure) {
    return '$groupedFigure confirmations';
  }

  @override
  String wallet_txResultSwitch(Object? action) {
    return '$action in progress';
  }

  @override
  String get wallet_txResultSwitch2 => 'Waiting';

  @override
  String get wallet_txResultSwitch3 => 'Latest status.';

  @override
  String get wallet_txResultTxResultActionIdLabel => 'Provider action';

  @override
  String get wallet_txResultTxResultCapabilityBlockTitle =>
      'Transaction status can\'t be read right now';

  @override
  String get wallet_txResultTxResultConfirmationsLabel => 'Confirmations';

  @override
  String get wallet_txResultTxResultConfirmationsValue => 'No receipt yet';

  @override
  String get wallet_txResultTxResultConfirmationsValue2 =>
      'Chain head can\'t be loaded';

  @override
  String get wallet_txResultTxResultEmptyMessage =>
      'When you come here from a Send, approval or Swap signing page, this page shows that transaction\'s status.';

  @override
  String get wallet_txResultTxResultEmptyTitle => 'No action to show here yet';

  @override
  String get wallet_txResultTxResultFolioCaption =>
      'The result page shows one specific action and needs to know which one.';

  @override
  String get wallet_txResultTxResultFolioCaption2 =>
      'The result follows the on-chain check; this page doesn\'t decide success on its own.';

  @override
  String get wallet_txResultTxResultFolioHeading => 'No result to show';

  @override
  String get wallet_txResultTxResultFolioHeading2 => 'Loading result';

  @override
  String get wallet_txResultTxResultForwardLabel => 'Forward message';

  @override
  String get wallet_txResultTxResultGasLabel => 'Gas used';

  @override
  String get wallet_txResultTxResultHashLabel => 'Transaction hash';

  @override
  String get wallet_txResultTxResultHashValue => 'Not reported yet';

  @override
  String get wallet_txResultTxResultMergeLabel => 'Merge into long image';

  @override
  String get wallet_txResultTxResultPendingBody =>
      'A successful submission doesn\'t mean it\'s done on-chain; it still needs 15 block confirmations.';

  @override
  String get wallet_txResultTxResultPendingTitle =>
      'Submitted, waiting for receipt';

  @override
  String wallet_txResultTxResultPollingStoppedBody(
    Object? maximumPollFailures,
  ) {
    return '$maximumPollFailures reads failed in a row, so this page has stopped retrying automatically. This action\'s status hasn\'t changed; retry manually.';
  }

  @override
  String get wallet_txResultTxResultPollingStoppedTitle =>
      'Auto-refresh stopped';

  @override
  String get wallet_txResultTxResultScreenTitle => 'Transaction result';

  @override
  String wallet_txResultTxResultUnknownLockBody(Object? reasonCodeText) {
    return '$reasonCodeText This page will only keep checking and won\'t submit again; don\'t sign again.';
  }

  @override
  String get wallet_txResultTxResultUnknownLockTitle =>
      'Result unknown, locked';

  @override
  String get wallet_txResultTxResultUnreportedBody =>
      'If the wallet already broadcast this transaction, it may be on-chain and only the report failed. Come back and retry later; don\'t sign again until the submission is accepted.';

  @override
  String get wallet_txResultTxResultUnreportedTitle =>
      'This submission hasn\'t been recorded yet';

  @override
  String get wallet_txResultTxResultUpdatedLabel => 'Updated';

  @override
  String wallet_txResultUnknown(Object? action) {
    return '$action result unknown';
  }

  @override
  String get wallet_txResultWalletMoneyActionsMoneyFactsFooterText =>
      'Confirmations can\'t be loaded';
}
