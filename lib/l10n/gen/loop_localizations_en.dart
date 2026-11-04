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
