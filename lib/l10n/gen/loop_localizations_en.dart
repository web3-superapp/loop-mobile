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
