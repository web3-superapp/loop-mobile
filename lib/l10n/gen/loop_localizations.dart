import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'loop_localizations_en.dart';
import 'loop_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LoopLocalizations
/// returned by `LoopLocalizations.of(context)`.
///
/// Applications need to include `LoopLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/loop_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LoopLocalizations.localizationsDelegates,
///   supportedLocales: LoopLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the LoopLocalizations.supportedLocales
/// property.
abstract class LoopLocalizations {
  LoopLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LoopLocalizations of(BuildContext context) {
    return Localizations.of<LoopLocalizations>(context, LoopLocalizations)!;
  }

  static const LocalizationsDelegate<LoopLocalizations> delegate =
      _LoopLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// lib/features/beta_feedback/beta_feedback_screen.dart:90, lib/features/beta_feedback/beta_feedback_screen.dart:94
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera'**
  String get betaFeedback_cameraFailed;

  /// lib/features/beta_feedback/beta_feedback_models.dart:13
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get betaFeedback_categoryOther;

  /// lib/features/beta_feedback/beta_feedback_models.dart:12
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get betaFeedback_categorySuggestion;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:20
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t set up yet. Try again later.'**
  String get betaFeedback_copyBootstrapRequired;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:22
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load feedback. Try again later.'**
  String get betaFeedback_copyLoadFailed;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:21
  ///
  /// In en, this message translates to:
  /// **'The response was incomplete.'**
  String get betaFeedback_copyLoadMalformed;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:11
  ///
  /// In en, this message translates to:
  /// **'No network; couldn\'t load feedback.'**
  String get betaFeedback_copyLoadOffline;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:18
  ///
  /// In en, this message translates to:
  /// **'Too many submissions. Try again later.'**
  String get betaFeedback_copyRateLimited;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:17
  ///
  /// In en, this message translates to:
  /// **'This account can\'t send feedback.'**
  String get betaFeedback_copyRegionBlocked;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:14
  ///
  /// In en, this message translates to:
  /// **'The result isn\'t confirmed. Submitting again won\'t create a duplicate.'**
  String get betaFeedback_copySubmissionUnknown;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:22
  ///
  /// In en, this message translates to:
  /// **'Feedback wasn\'t sent. Try again later.'**
  String get betaFeedback_copySubmitFailed;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:21
  ///
  /// In en, this message translates to:
  /// **'The response was incomplete; the result isn\'t confirmed.'**
  String get betaFeedback_copySubmitMalformed;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:11
  ///
  /// In en, this message translates to:
  /// **'No network; feedback wasn\'t sent.'**
  String get betaFeedback_copySubmitOffline;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:15
  ///
  /// In en, this message translates to:
  /// **'Feedback isn\'t available right now.'**
  String get betaFeedback_copyUnavailable;

  /// lib/features/beta_feedback/beta_feedback_copy.dart:19
  ///
  /// In en, this message translates to:
  /// **'The text or images don\'t meet the requirements. Edit them and try again.'**
  String get betaFeedback_copyValidationFailed;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:172
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get betaFeedback_description;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:413
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get betaFeedback_envDevice;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:415
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get betaFeedback_envPage;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:414
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get betaFeedback_envSystem;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:408
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get betaFeedback_envVersion;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:199
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get betaFeedback_environment;

  /// lib/features/beta_feedback/beta_feedback_entry.dart:83, lib/features/beta_feedback/beta_feedback_screen.dart:137
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get betaFeedback_feedback;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:79
  ///
  /// In en, this message translates to:
  /// **'Up to {maximumImages} images'**
  String betaFeedback_imageLimit(Object? maximumImages);

  /// lib/features/beta_feedback/beta_feedback_screen.dart:83
  ///
  /// In en, this message translates to:
  /// **'Some images can\'t be used'**
  String get betaFeedback_imageUnusable;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:188
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get betaFeedback_images;

  /// lib/features/beta_feedback/beta_feedback_mine_screen.dart:86
  ///
  /// In en, this message translates to:
  /// **'No feedback yet'**
  String get betaFeedback_mineEmpty;

  /// lib/features/beta_feedback/beta_feedback_mine_screen.dart:128
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load feedback'**
  String get betaFeedback_mineErrorTitle;

  /// lib/features/beta_feedback/beta_feedback_mine_screen.dart:122
  ///
  /// In en, this message translates to:
  /// **'No permission'**
  String get betaFeedback_minePermissionTitle;

  /// lib/features/beta_feedback/beta_feedback_mine_screen.dart:61, lib/features/beta_feedback/beta_feedback_screen.dart:144
  ///
  /// In en, this message translates to:
  /// **'My feedback'**
  String get betaFeedback_mineTitle;

  /// lib/features/beta_feedback/beta_feedback_mine_screen.dart:71
  ///
  /// In en, this message translates to:
  /// **'Feedback history can\'t be loaded right now.'**
  String get betaFeedback_mineUnavailableMessage;

  /// lib/features/beta_feedback/beta_feedback_mine_screen.dart:70, lib/features/beta_feedback/beta_feedback_screen.dart:151
  ///
  /// In en, this message translates to:
  /// **'Feedback isn\'t available'**
  String get betaFeedback_mineUnavailableTitle;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:89
  ///
  /// In en, this message translates to:
  /// **'No camera access'**
  String get betaFeedback_noCameraAccess;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:89
  ///
  /// In en, this message translates to:
  /// **'No photo access'**
  String get betaFeedback_noPhotoAccess;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:112, lib/features/beta_feedback/beta_feedback_screen.dart:206
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get betaFeedback_notSent;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:258
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get betaFeedback_photos;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:90, lib/features/beta_feedback/beta_feedback_screen.dart:94
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Photos'**
  String get betaFeedback_photosFailed;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:315
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get betaFeedback_removeImage;

  /// lib/features/beta_feedback/beta_feedback_mine_screen.dart:116
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get betaFeedback_send;

  /// lib/features/beta_feedback/beta_feedback_models.dart:29
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get betaFeedback_statusOpen;

  /// lib/features/beta_feedback/beta_feedback_models.dart:31
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get betaFeedback_statusResolved;

  /// lib/features/beta_feedback/beta_feedback_models.dart:32
  ///
  /// In en, this message translates to:
  /// **'Won\'t fix'**
  String get betaFeedback_statusWontFix;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:264
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get betaFeedback_takePhoto;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:152
  ///
  /// In en, this message translates to:
  /// **'Feedback can\'t be sent right now.'**
  String get betaFeedback_unavailableMessage;

  /// lib/features/beta_feedback/beta_feedback_screen.dart:129
  ///
  /// In en, this message translates to:
  /// **'Uploading images {uploaded} / {images}'**
  String betaFeedback_uploading(Object? images, Object? uploaded);

  /// lib/features/chain/chain_contract.dart:311
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t set up yet. Try again later.'**
  String get chain_contractBootstrapRequired;

  /// lib/features/chain/chain_contract.dart:299
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled and the result is unknown. Check the latest status before deciding whether to retry.'**
  String get chain_contractCancelled;

  /// lib/features/chain/chain_contract.dart:314
  ///
  /// In en, this message translates to:
  /// **'This chain isn\'t supported: Wallet, Market, Swap and approvals run on BNB Smart Chain; Launch runs on the Launch chain published by LOOP.'**
  String get chain_contractChainMismatch;

  /// lib/features/chain/chain_contract.dart:289
  ///
  /// In en, this message translates to:
  /// **'Converted at trade price'**
  String get chain_contractDerived;

  /// lib/features/chain/chain_contract.dart:317
  ///
  /// In en, this message translates to:
  /// **'The same action was already submitted with different content. Check the latest status and try again.'**
  String get chain_contractIdempotencyConflict;

  /// lib/features/chain/chain_contract.dart:302
  ///
  /// In en, this message translates to:
  /// **'On-chain records are still syncing. They can\'t be read right now; that doesn\'t mean there are none.'**
  String get chain_contractIndexingDelayed;

  /// lib/features/chain/chain_contract.dart:319
  ///
  /// In en, this message translates to:
  /// **'Balance doesn\'t cover this amount, the maximum network fee or the fee reserve. No transaction was submitted.'**
  String get chain_contractInsufficientBalance;

  /// lib/features/chain/chain_contract.dart:324
  ///
  /// In en, this message translates to:
  /// **'The returned data was incomplete. Nothing on this page was used.'**
  String get chain_contractInvalidData;

  /// lib/features/chain/chain_contract.dart:207
  ///
  /// In en, this message translates to:
  /// **'LOOP curve'**
  String get chain_contractLoopCurve;

  /// lib/features/chain/chain_contract.dart:206
  ///
  /// In en, this message translates to:
  /// **'LOOP on-chain index'**
  String get chain_contractLoopIndexer;

  /// lib/features/chain/chain_contract.dart:309
  ///
  /// In en, this message translates to:
  /// **'The target doesn\'t exist, isn\'t registered, or isn\'t visible to this account.'**
  String get chain_contractNotFound;

  /// lib/features/chain/chain_contract.dart:297
  ///
  /// In en, this message translates to:
  /// **'This device is offline. Nothing was loaded on this page and no action was submitted.'**
  String get chain_contractOffline;

  /// lib/features/chain/chain_contract.dart:300
  ///
  /// In en, this message translates to:
  /// **'The returned data was incomplete and the result isn\'t confirmed. Refresh to see the latest status; don\'t submit again.'**
  String get chain_contractOutcomeUnknown;

  /// lib/features/chain/chain_contract.dart:303
  ///
  /// In en, this message translates to:
  /// **'This account doesn\'t have permission for this action.'**
  String get chain_contractPermissionDenied;

  /// lib/features/chain/chain_contract.dart:208
  ///
  /// In en, this message translates to:
  /// **'Derived from pool'**
  String get chain_contractPoolSlot0;

  /// lib/features/chain/chain_contract.dart:290
  ///
  /// In en, this message translates to:
  /// **'Priced in WBNB'**
  String get chain_contractProxied;

  /// lib/features/chain/chain_contract.dart:321
  ///
  /// In en, this message translates to:
  /// **'The quote has expired. No swap was submitted. Get a new quote before confirming.'**
  String get chain_contractQuoteExpired;

  /// lib/features/chain/chain_contract.dart:316
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a moment and try again.'**
  String get chain_contractRateLimited;

  /// lib/features/chain/chain_contract.dart:325
  ///
  /// In en, this message translates to:
  /// **'This page can\'t be loaded right now. Nothing was submitted. Try again later.'**
  String get chain_contractReadFailed;

  /// lib/features/chain/chain_contract.dart:305
  ///
  /// In en, this message translates to:
  /// **'This action isn\'t available in your region right now. Nothing was changed. This isn\'t related to your account or assets, and switching won\'t change the result.'**
  String get chain_contractRegionBlocked;

  /// lib/features/chain/chain_contract.dart:320
  ///
  /// In en, this message translates to:
  /// **'This transaction didn\'t pass simulation and can\'t be signed. Go back to the confirmation page and prepare it again.'**
  String get chain_contractSimulationFailed;

  /// lib/features/chain/chain_contract.dart:288
  ///
  /// In en, this message translates to:
  /// **'Data may be out of date'**
  String get chain_contractStale;

  /// lib/features/chain/chain_contract.dart:308
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing was changed.'**
  String get chain_contractStepUpCancelled;

  /// lib/features/chain/chain_contract.dart:307
  ///
  /// In en, this message translates to:
  /// **'This step requires two-step verification, which isn\'t available yet. Nothing was changed.'**
  String get chain_contractStepUpRequired;

  /// lib/features/chain/chain_contract.dart:323
  ///
  /// In en, this message translates to:
  /// **'This action was already submitted once and the result is unknown, so it\'s locked. Only check the latest status; don\'t submit again.'**
  String get chain_contractSubmissionUnknown;

  /// lib/features/chain/chain_contract.dart:353
  ///
  /// In en, this message translates to:
  /// **'On-chain data can\'t be loaded right now.'**
  String get chain_contractSwitch;

  /// lib/features/chain/chain_contract.dart:364
  ///
  /// In en, this message translates to:
  /// **'The balance wasn\'t loaded this time, so no number is shown.'**
  String get chain_contractSwitch10;

  /// lib/features/chain/chain_contract.dart:365
  ///
  /// In en, this message translates to:
  /// **'Transfer history can\'t be loaded right now.'**
  String get chain_contractSwitch11;

  /// lib/features/chain/chain_contract.dart:366
  ///
  /// In en, this message translates to:
  /// **'Trades and candlesticks can\'t be loaded right now.'**
  String get chain_contractSwitch12;

  /// lib/features/chain/chain_contract.dart:367
  ///
  /// In en, this message translates to:
  /// **'BNB transfer history can\'t be loaded right now.'**
  String get chain_contractSwitch13;

  /// lib/features/chain/chain_contract.dart:368
  ///
  /// In en, this message translates to:
  /// **'Bridge and mining claim history can\'t be loaded right now.'**
  String get chain_contractSwitch14;

  /// lib/features/chain/chain_contract.dart:370
  ///
  /// In en, this message translates to:
  /// **'MEME records on the Launch chain haven\'t started syncing; only transfers are listed below.'**
  String get chain_contractSwitch15;

  /// lib/features/chain/chain_contract.dart:371
  ///
  /// In en, this message translates to:
  /// **'MEME records weren\'t loaded this time; only transfers are listed below. Check back later.'**
  String get chain_contractSwitch16;

  /// lib/features/chain/chain_contract.dart:372
  ///
  /// In en, this message translates to:
  /// **'This asset can\'t be reconciled with wallet records.'**
  String get chain_contractSwitch17;

  /// lib/features/chain/chain_contract.dart:373
  ///
  /// In en, this message translates to:
  /// **'External wallets can\'t be reconciled with wallet records.'**
  String get chain_contractSwitch18;

  /// lib/features/chain/chain_contract.dart:374
  ///
  /// In en, this message translates to:
  /// **'Balance reconciliation failed; on-chain figures aren\'t affected.'**
  String get chain_contractSwitch19;

  /// lib/features/chain/chain_contract.dart:354
  ///
  /// In en, this message translates to:
  /// **'On-chain data isn\'t available right now. Try again later.'**
  String get chain_contractSwitch2;

  /// lib/features/chain/chain_contract.dart:376
  ///
  /// In en, this message translates to:
  /// **'Swap isn\'t available yet; this page has no buy or sell entry.'**
  String get chain_contractSwitch20;

  /// lib/features/chain/chain_contract.dart:377
  ///
  /// In en, this message translates to:
  /// **'This asset can no longer be loaded. The row is kept so you can remove it.'**
  String get chain_contractSwitch21;

  /// lib/features/chain/chain_contract.dart:380
  ///
  /// In en, this message translates to:
  /// **'This address isn\'t in the LOOP asset catalog. The data below comes from a market data source and can\'t be traded.'**
  String get chain_contractSwitch22;

  /// lib/features/chain/chain_contract.dart:381
  ///
  /// In en, this message translates to:
  /// **'This asset is blocked.'**
  String get chain_contractSwitch23;

  /// lib/features/chain/chain_contract.dart:383
  ///
  /// In en, this message translates to:
  /// **'Market data isn\'t available right now. Try again later.'**
  String get chain_contractSwitch24;

  /// lib/features/chain/chain_contract.dart:384
  ///
  /// In en, this message translates to:
  /// **'Price can\'t be loaded right now, so no value is shown.'**
  String get chain_contractSwitch25;

  /// lib/features/chain/chain_contract.dart:385
  ///
  /// In en, this message translates to:
  /// **'DexScreener data is currently turned off.'**
  String get chain_contractSwitch26;

  /// lib/features/chain/chain_contract.dart:386
  ///
  /// In en, this message translates to:
  /// **'Security info and holder count can\'t be loaded right now.'**
  String get chain_contractSwitch27;

  /// lib/features/chain/chain_contract.dart:387
  ///
  /// In en, this message translates to:
  /// **'New token discovery and related market data can\'t be loaded right now.'**
  String get chain_contractSwitch28;

  /// lib/features/chain/chain_contract.dart:388
  ///
  /// In en, this message translates to:
  /// **'The data service is rate limited; no new figures for now.'**
  String get chain_contractSwitch29;

  /// lib/features/chain/chain_contract.dart:355
  ///
  /// In en, this message translates to:
  /// **'Checking the on-chain connection; on-chain figures are hidden for now.'**
  String get chain_contractSwitch3;

  /// lib/features/chain/chain_contract.dart:389
  ///
  /// In en, this message translates to:
  /// **'The data service rejected this request. It isn\'t your network. Check back later.'**
  String get chain_contractSwitch30;

  /// lib/features/chain/chain_contract.dart:390
  ///
  /// In en, this message translates to:
  /// **'Market data can\'t be loaded right now, so this item has no value. Check back later.'**
  String get chain_contractSwitch31;

  /// lib/features/chain/chain_contract.dart:391
  ///
  /// In en, this message translates to:
  /// **'Market data can\'t be fetched right now. It isn\'t your network. Check back later.'**
  String get chain_contractSwitch32;

  /// lib/features/chain/chain_contract.dart:392
  ///
  /// In en, this message translates to:
  /// **'The returned data was incomplete and was discarded.'**
  String get chain_contractSwitch33;

  /// lib/features/chain/chain_contract.dart:393
  ///
  /// In en, this message translates to:
  /// **'No trading pair found for this asset.'**
  String get chain_contractSwitch34;

  /// lib/features/chain/chain_contract.dart:394
  ///
  /// In en, this message translates to:
  /// **'The data source didn\'t report this item.'**
  String get chain_contractSwitch35;

  /// lib/features/chain/chain_contract.dart:395
  ///
  /// In en, this message translates to:
  /// **'Native BNB has no contract address, so this item doesn\'t apply.'**
  String get chain_contractSwitch36;

  /// lib/features/chain/chain_contract.dart:396
  ///
  /// In en, this message translates to:
  /// **'This asset has no PancakeSwap V3 pool yet.'**
  String get chain_contractSwitch37;

  /// lib/features/chain/chain_contract.dart:397
  ///
  /// In en, this message translates to:
  /// **'No trades in the selected range.'**
  String get chain_contractSwitch38;

  /// lib/features/chain/chain_contract.dart:398
  ///
  /// In en, this message translates to:
  /// **'This row\'s balance can\'t be loaded, so it can\'t be valued.'**
  String get chain_contractSwitch39;

  /// lib/features/chain/chain_contract.dart:356
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the on-chain node right now. It isn\'t your network. Check back later.'**
  String get chain_contractSwitch4;

  /// lib/features/chain/chain_contract.dart:499
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get chain_contractSwitch40;

  /// lib/features/chain/chain_contract.dart:357
  ///
  /// In en, this message translates to:
  /// **'Not connected to BNB Smart Chain; this page is unavailable.'**
  String get chain_contractSwitch5;

  /// lib/features/chain/chain_contract.dart:360
  ///
  /// In en, this message translates to:
  /// **'Launch chain data can\'t be loaded right now.'**
  String get chain_contractSwitch6;

  /// lib/features/chain/chain_contract.dart:361
  ///
  /// In en, this message translates to:
  /// **'Checking the Launch chain connection; on-chain figures are hidden for now.'**
  String get chain_contractSwitch7;

  /// lib/features/chain/chain_contract.dart:362
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the Launch chain node right now. It isn\'t your network. Check back later.'**
  String get chain_contractSwitch8;

  /// lib/features/chain/chain_contract.dart:363
  ///
  /// In en, this message translates to:
  /// **'Not connected to the Launch chain; Launch content is unavailable.'**
  String get chain_contractSwitch9;

  /// lib/features/chain/chain_contract.dart:400
  ///
  /// In en, this message translates to:
  /// **'Holder distribution can\'t be loaded right now.'**
  String get chain_contractText;

  /// lib/features/chain/chain_contract.dart:410
  ///
  /// In en, this message translates to:
  /// **'Fund actions aren\'t available right now. Try again later.'**
  String get chain_contractText10;

  /// lib/features/chain/chain_contract.dart:411
  ///
  /// In en, this message translates to:
  /// **'On-chain actions are currently turned off; view only for now.'**
  String get chain_contractText11;

  /// lib/features/chain/chain_contract.dart:412
  ///
  /// In en, this message translates to:
  /// **'Swap isn\'t available right now. Try again later.'**
  String get chain_contractText12;

  /// lib/features/chain/chain_contract.dart:413
  ///
  /// In en, this message translates to:
  /// **'Swap is still being verified. You can view quotes but can\'t execute.'**
  String get chain_contractText13;

  /// lib/features/chain/chain_contract.dart:414
  ///
  /// In en, this message translates to:
  /// **'Swap can\'t be simulated right now, so it can\'t be executed.'**
  String get chain_contractText14;

  /// lib/features/chain/chain_contract.dart:415
  ///
  /// In en, this message translates to:
  /// **'Can\'t check whether this address is on known scam lists right now. That doesn\'t mean it\'s safe.'**
  String get chain_contractText15;

  /// lib/features/chain/chain_contract.dart:416
  ///
  /// In en, this message translates to:
  /// **'Approval risk info can\'t be loaded right now.'**
  String get chain_contractText16;

  /// lib/features/chain/chain_contract.dart:417
  ///
  /// In en, this message translates to:
  /// **'This row\'s approval amount can\'t be loaded, so no number is shown.'**
  String get chain_contractText17;

  /// lib/features/chain/chain_contract.dart:418
  ///
  /// In en, this message translates to:
  /// **'This transaction was rejected on-chain during simulation and can\'t be signed.'**
  String get chain_contractText18;

  /// lib/features/chain/chain_contract.dart:419
  ///
  /// In en, this message translates to:
  /// **'Simulation returned no verifiable result, so it can\'t be signed.'**
  String get chain_contractText19;

  /// lib/features/chain/chain_contract.dart:401
  ///
  /// In en, this message translates to:
  /// **'Smart money tracking isn\'t available yet.'**
  String get chain_contractText2;

  /// lib/features/chain/chain_contract.dart:420
  ///
  /// In en, this message translates to:
  /// **'Can\'t estimate the network fee, so no signable transaction can be built.'**
  String get chain_contractText20;

  /// lib/features/chain/chain_contract.dart:421
  ///
  /// In en, this message translates to:
  /// **'This action has expired. Prepare it again.'**
  String get chain_contractText21;

  /// lib/features/chain/chain_contract.dart:422
  ///
  /// In en, this message translates to:
  /// **'This wallet has prepared a new action; this one was replaced and not submitted.'**
  String get chain_contractText22;

  /// lib/features/chain/chain_contract.dart:423
  ///
  /// In en, this message translates to:
  /// **'You cancelled this action. No transaction was submitted.'**
  String get chain_contractText23;

  /// lib/features/chain/chain_contract.dart:424
  ///
  /// In en, this message translates to:
  /// **'The transaction was submitted but isn\'t on-chain yet. LOOP will keep checking.'**
  String get chain_contractText24;

  /// lib/features/chain/chain_contract.dart:425
  ///
  /// In en, this message translates to:
  /// **'The submitted transaction didn\'t match what was prepared and was rejected.'**
  String get chain_contractText25;

  /// lib/features/chain/chain_contract.dart:426
  ///
  /// In en, this message translates to:
  /// **'The transaction is on-chain but failed; the network fee was spent.'**
  String get chain_contractText26;

  /// lib/features/chain/chain_contract.dart:427
  ///
  /// In en, this message translates to:
  /// **'The transaction receipt can\'t be loaded right now; the result is pending.'**
  String get chain_contractText27;

  /// lib/features/chain/chain_contract.dart:428
  ///
  /// In en, this message translates to:
  /// **'The wallet rejected this swap. Nothing was submitted on-chain.'**
  String get chain_contractText28;

  /// lib/features/chain/chain_contract.dart:429
  ///
  /// In en, this message translates to:
  /// **'The result of this action isn\'t certain yet. Wait for confirmation; don\'t submit again.'**
  String get chain_contractText29;

  /// lib/features/chain/chain_contract.dart:402
  ///
  /// In en, this message translates to:
  /// **'Push notifications aren\'t available yet; alerts only appear in the in-app notification list.'**
  String get chain_contractText3;

  /// lib/features/chain/chain_contract.dart:430
  ///
  /// In en, this message translates to:
  /// **'Price impact is over 5%; this swap was blocked.'**
  String get chain_contractText30;

  /// lib/features/chain/chain_contract.dart:431
  ///
  /// In en, this message translates to:
  /// **'Can\'t calculate the price impact of this swap, so it was blocked.'**
  String get chain_contractText31;

  /// lib/features/chain/chain_contract.dart:432
  ///
  /// In en, this message translates to:
  /// **'This action can\'t go to wallet signing right now.'**
  String get chain_contractText32;

  /// lib/features/chain/chain_contract.dart:433
  ///
  /// In en, this message translates to:
  /// **'This chain doesn\'t support this action: Send, approvals, revokes and Swap only work on mainnet.'**
  String get chain_contractText33;

  /// lib/features/chain/chain_contract.dart:435
  ///
  /// In en, this message translates to:
  /// **'Security settings aren\'t available yet.'**
  String get chain_contractText34;

  /// lib/features/chain/chain_contract.dart:436
  ///
  /// In en, this message translates to:
  /// **'Security settings aren\'t available right now. Try again later.'**
  String get chain_contractText35;

  /// lib/features/chain/chain_contract.dart:437
  ///
  /// In en, this message translates to:
  /// **'Account settings aren\'t available yet.'**
  String get chain_contractText36;

  /// lib/features/chain/chain_contract.dart:438
  ///
  /// In en, this message translates to:
  /// **'Settings aren\'t available right now. Try again later.'**
  String get chain_contractText37;

  /// lib/features/chain/chain_contract.dart:439
  ///
  /// In en, this message translates to:
  /// **'Support isn\'t available yet.'**
  String get chain_contractText38;

  /// lib/features/chain/chain_contract.dart:440
  ///
  /// In en, this message translates to:
  /// **'Support isn\'t available right now. Try again later.'**
  String get chain_contractText39;

  /// lib/features/chain/chain_contract.dart:403
  ///
  /// In en, this message translates to:
  /// **'No community has linked this asset yet.'**
  String get chain_contractText4;

  /// lib/features/chain/chain_contract.dart:441
  ///
  /// In en, this message translates to:
  /// **'The device list can\'t be loaded right now.'**
  String get chain_contractText40;

  /// lib/features/chain/chain_contract.dart:442
  ///
  /// In en, this message translates to:
  /// **'Recent security events can\'t be loaded right now.'**
  String get chain_contractText41;

  /// lib/features/chain/chain_contract.dart:443
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is required, but it isn\'t available yet.'**
  String get chain_contractText42;

  /// lib/features/chain/chain_contract.dart:444
  ///
  /// In en, this message translates to:
  /// **'Tickets can\'t take attachments right now.'**
  String get chain_contractText43;

  /// lib/features/chain/chain_contract.dart:445
  ///
  /// In en, this message translates to:
  /// **'Legal document links can\'t be opened right now.'**
  String get chain_contractText44;

  /// lib/features/chain/chain_contract.dart:446
  ///
  /// In en, this message translates to:
  /// **'The new terms haven\'t taken effect yet.'**
  String get chain_contractText45;

  /// lib/features/chain/chain_contract.dart:447
  ///
  /// In en, this message translates to:
  /// **'Version and build number come from this device.'**
  String get chain_contractText46;

  /// lib/features/chain/chain_contract.dart:448
  ///
  /// In en, this message translates to:
  /// **'No wallet selected yet.'**
  String get chain_contractText47;

  /// lib/features/chain/chain_contract.dart:449
  ///
  /// In en, this message translates to:
  /// **'The approval list can\'t be loaded right now.'**
  String get chain_contractText48;

  /// lib/features/chain/chain_contract.dart:450
  ///
  /// In en, this message translates to:
  /// **'The approval list isn\'t available yet.'**
  String get chain_contractText49;

  /// lib/features/chain/chain_contract.dart:404
  ///
  /// In en, this message translates to:
  /// **'Per-asset mining figures aren\'t available yet; power and details are on the Mining page.'**
  String get chain_contractText5;

  /// lib/features/chain/chain_contract.dart:451
  ///
  /// In en, this message translates to:
  /// **'On-chain records are still syncing; the approval list can\'t be loaded right now.'**
  String get chain_contractText50;

  /// lib/features/chain/chain_contract.dart:452
  ///
  /// In en, this message translates to:
  /// **'This feature isn\'t available right now.'**
  String get chain_contractText51;

  /// lib/features/chain/chain_contract.dart:454
  ///
  /// In en, this message translates to:
  /// **'Multi-factor authentication isn\'t available yet.'**
  String get chain_contractText52;

  /// lib/features/chain/chain_contract.dart:455
  ///
  /// In en, this message translates to:
  /// **'Passkeys aren\'t available yet.'**
  String get chain_contractText53;

  /// lib/features/chain/chain_contract.dart:456
  ///
  /// In en, this message translates to:
  /// **'Recovery password isn\'t available yet.'**
  String get chain_contractText54;

  /// lib/features/chain/chain_contract.dart:457
  ///
  /// In en, this message translates to:
  /// **'Automatic recovery isn\'t available yet.'**
  String get chain_contractText55;

  /// lib/features/chain/chain_contract.dart:458
  ///
  /// In en, this message translates to:
  /// **'Social recovery isn\'t available yet.'**
  String get chain_contractText56;

  /// lib/features/chain/chain_contract.dart:459
  ///
  /// In en, this message translates to:
  /// **'Private key export isn\'t available yet.'**
  String get chain_contractText57;

  /// lib/features/chain/chain_contract.dart:461
  ///
  /// In en, this message translates to:
  /// **'Scan to pay isn\'t available yet; the camera won\'t open and no payment code is generated here.'**
  String get chain_contractText58;

  /// lib/features/chain/chain_contract.dart:462
  ///
  /// In en, this message translates to:
  /// **'Bridge isn\'t available yet; no bridge action is started here.'**
  String get chain_contractText59;

  /// lib/features/chain/chain_contract.dart:405
  ///
  /// In en, this message translates to:
  /// **'Indicators and drawing tools aren\'t available yet.'**
  String get chain_contractText6;

  /// lib/features/chain/chain_contract.dart:463
  ///
  /// In en, this message translates to:
  /// **'DApp connection and signing aren\'t available yet; this page only runs local checks.'**
  String get chain_contractText60;

  /// lib/features/chain/chain_contract.dart:464
  ///
  /// In en, this message translates to:
  /// **'Community AI isn\'t available yet.'**
  String get chain_contractText61;

  /// lib/features/chain/chain_contract.dart:406
  ///
  /// In en, this message translates to:
  /// **'Net value trend and 24h change can\'t be loaded right now.'**
  String get chain_contractText7;

  /// lib/features/chain/chain_contract.dart:407
  ///
  /// In en, this message translates to:
  /// **'Custom networks aren\'t available yet; only networks LOOP supports are shown here.'**
  String get chain_contractText8;

  /// lib/features/chain/chain_contract.dart:408
  ///
  /// In en, this message translates to:
  /// **'Security Center and DApp status aren\'t available yet.'**
  String get chain_contractText9;

  /// lib/features/chain/chain_contract.dart:298
  ///
  /// In en, this message translates to:
  /// **'LOOP timed out. Nothing was loaded on this page and no action was submitted.'**
  String get chain_contractTimedOut;

  /// lib/features/chain/chain_contract.dart:301
  ///
  /// In en, this message translates to:
  /// **'On-chain data can\'t be loaded right now. Try again later.'**
  String get chain_contractUnavailable;

  /// lib/features/chain/chain_contract.dart:326
  ///
  /// In en, this message translates to:
  /// **'The action didn\'t finish. Try again later.'**
  String get chain_contractUnexpected;

  /// lib/features/chain/chain_contract.dart:312
  ///
  /// In en, this message translates to:
  /// **'The input isn\'t valid (for example, an unregistered asset or an invalid threshold). Fix it and try again.'**
  String get chain_contractValidationFailed;

  /// lib/features/chain/chain_contract.dart:310
  ///
  /// In en, this message translates to:
  /// **'The data was changed on another device. Reload before submitting; nothing was overwritten this time.'**
  String get chain_contractVersionConflict;

  /// lib/features/chain/chain_models.dart:44
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get chain_modelsBlocked;

  /// lib/features/chain/chain_models.dart:411
  ///
  /// In en, this message translates to:
  /// **'ERC-20 transfer index'**
  String get chain_modelsErc20Transfer;

  /// lib/features/chain/chain_models.dart:575
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get chain_modelsLoopProvenanceLabel;

  /// lib/features/chain/chain_models.dart:578
  ///
  /// In en, this message translates to:
  /// **'{sourceLabel} · observed {observedAtLabel}'**
  String chain_modelsLoopProvenanceLabel2(
    Object? observedAtLabel,
    Object? sourceLabel,
  );

  /// lib/features/chain/chain_models.dart:289
  ///
  /// In en, this message translates to:
  /// **'Mismatch'**
  String get chain_modelsMismatched;

  /// lib/features/chain/chain_models.dart:42
  ///
  /// In en, this message translates to:
  /// **'Pending check'**
  String get chain_modelsPending;

  /// lib/features/chain/chain_models.dart:412
  ///
  /// In en, this message translates to:
  /// **'Pool event index'**
  String get chain_modelsPoolEvent;

  /// lib/features/chain/chain_models.dart:576, lib/features/chain/chain_widgets.dart:231
  ///
  /// In en, this message translates to:
  /// **'Source {factSourceLabel}'**
  String chain_modelsS(Object? factSourceLabel);

  /// lib/features/chain/chain_models.dart:62
  ///
  /// In en, this message translates to:
  /// **'Can\'t load right now'**
  String get chain_modelsUnavailable;

  /// lib/features/chain/chain_models.dart:290
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get chain_modelsUnreachable;

  /// lib/features/chain/chain_models.dart:51
  ///
  /// In en, this message translates to:
  /// **'Unregistered'**
  String get chain_modelsUnregistered;

  /// lib/features/chain/chain_models.dart:43
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get chain_modelsVerified;

  /// lib/features/chain/chain_models.dart:288
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get chain_modelsVerified2;

  /// lib/features/chain/chain_widgets.dart:445
  ///
  /// In en, this message translates to:
  /// **'{resource} exists only in this development preview; it isn\'t written to your account or uploaded.'**
  String chain_widgetsChainPreviewNoticeBody(Object? resource);

  /// lib/features/chain/chain_widgets.dart:817
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get chain_widgetsLabel;

  /// lib/features/chain/chain_widgets.dart:230
  ///
  /// In en, this message translates to:
  /// **'Source not labeled'**
  String get chain_widgetsLoopFactProvenance;

  /// lib/features/chain/chain_widgets.dart:233
  ///
  /// In en, this message translates to:
  /// **'{label} · observed {relativeTime}'**
  String chain_widgetsLoopFactProvenance2(Object? label, Object? relativeTime);

  /// lib/features/chain/chain_widgets.dart:316
  ///
  /// In en, this message translates to:
  /// **'Switch wallet'**
  String get chain_widgetsLoopOfflineState;

  /// lib/features/chain/chain_widgets.dart:316
  ///
  /// In en, this message translates to:
  /// **'Save to watchlist'**
  String get chain_widgetsLoopOfflineState2;

  /// lib/features/chain/chain_widgets.dart:220
  ///
  /// In en, this message translates to:
  /// **'{inSeconds}s ago'**
  String chain_widgetsLoopRelativeTime(Object? inSeconds);

  /// lib/features/chain/chain_widgets.dart:221
  ///
  /// In en, this message translates to:
  /// **'{inMinutes}m ago'**
  String chain_widgetsLoopRelativeTime2(Object? inMinutes);

  /// lib/features/chain/chain_widgets.dart:222
  ///
  /// In en, this message translates to:
  /// **'{inHours}h ago'**
  String chain_widgetsLoopRelativeTime3(Object? inHours);

  /// lib/features/chain/chain_widgets.dart:223
  ///
  /// In en, this message translates to:
  /// **'{inDays}d ago'**
  String chain_widgetsLoopRelativeTime4(Object? inDays);

  /// lib/features/chain/chain_widgets.dart:865
  ///
  /// In en, this message translates to:
  /// **'{text}, view {title}'**
  String chain_widgetsProvenanceFooterSemanticsLabel(
    Object? text,
    Object? title,
  );

  /// lib/features/chain/chain_widgets.dart:471
  ///
  /// In en, this message translates to:
  /// **'{chainFailureReason} Content already loaded on this page isn\'t affected.'**
  String chain_widgetsRegionBlocked(Object? chainFailureReason);

  /// lib/features/chain/chain_widgets.dart:416
  ///
  /// In en, this message translates to:
  /// **'Try again later'**
  String get chain_widgetsRetryLabel;

  /// lib/features/chain/chain_widgets.dart:785
  ///
  /// In en, this message translates to:
  /// **'{factProvenance}, view data source notes'**
  String chain_widgetsSemanticsLabel(Object? factProvenance);

  /// lib/features/chain/chain_widgets.dart:466
  ///
  /// In en, this message translates to:
  /// **'{chainFailureReason} Check the verification methods available in Security Center; content already loaded on this page isn\'t affected.'**
  String chain_widgetsStepUpRequired(Object? chainFailureReason);

  /// lib/features/chain/chain_widgets.dart:473
  ///
  /// In en, this message translates to:
  /// **'{chainFailureReason} This permission can\'t be changed in the app. You can switch to an authorized account or asset; content already loaded on this page isn\'t affected.'**
  String chain_widgetsSwitch(Object? chainFailureReason);

  /// lib/features/chain/chain_widgets.dart:323
  ///
  /// In en, this message translates to:
  /// **'This content isn\'t available right now'**
  String get chain_widgetsTitle;

  /// lib/features/chain/chain_widgets.dart:337, lib/features/chain/chain_widgets.dart:514
  ///
  /// In en, this message translates to:
  /// **'This step requires two-step verification'**
  String get chain_widgetsTitle2;

  /// lib/features/chain/chain_widgets.dart:339, lib/features/chain/chain_widgets.dart:516
  ///
  /// In en, this message translates to:
  /// **'This action isn\'t available in your region'**
  String get chain_widgetsTitle3;

  /// lib/features/chat/attachments/stream_token_card_attachment_builder.dart:69
  ///
  /// In en, this message translates to:
  /// **'LOOP hasn\'t received a live price or contract facts for this card yet. The message only stores the token ID, so price, risk, Buy and Watch aren\'t shown.'**
  String get chatAttachments_streamTokenCardBuilderLoopTokenCardModel;

  /// lib/features/chat/attachments/stream_token_card_attachment_builder.dart:70
  ///
  /// In en, this message translates to:
  /// **'Snapshot {snapshotLabel}'**
  String chatAttachments_streamTokenCardBuilderLoopTokenCardModel2(
    Object? snapshotLabel,
  );

  /// lib/features/chat/attachments/stream_token_card_attachment_builder.dart:91
  ///
  /// In en, this message translates to:
  /// **'This attachment doesn\'t match LOOP token_card.v1, so no token facts or actions are shown.'**
  String get chatAttachments_streamTokenCardBuilderLoopTokenCardModel3;

  /// lib/features/chat/attachments/stream_token_card_attachment_builder.dart:67
  ///
  /// In en, this message translates to:
  /// **'Current facts unavailable'**
  String get chatAttachments_streamTokenCardBuilderPriceReason;

  /// lib/features/chat/attachments/stream_token_card_attachment_builder.dart:89
  ///
  /// In en, this message translates to:
  /// **'Unrecognized token card'**
  String get chatAttachments_streamTokenCardBuilderSymbol;

  /// lib/features/chat/attachments/stream_token_card_message_preview_formatter.dart:148
  ///
  /// In en, this message translates to:
  /// **'Member bought'**
  String
  get chatAttachments_streamTokenCardMessagePreviewFormatterMemberBuyLabel;

  /// lib/features/chat/calls/audio_room_contract.dart:601
  ///
  /// In en, this message translates to:
  /// **'In voice room · {name}'**
  String chatCalls_audioRoomContractAudioRoomNotificationTitle(Object? name);

  /// lib/features/chat/calls/audio_room_contract.dart:445
  ///
  /// In en, this message translates to:
  /// **'Audio output'**
  String get chatCalls_audioRoomContractAudioRoomOutputLabel;

  /// lib/features/chat/calls/audio_room_contract.dart:547
  ///
  /// In en, this message translates to:
  /// **'Reconnected. Tap the mic to keep speaking'**
  String get chatCalls_audioRoomContractAudioRoomRestoredMicrophoneNote;

  /// lib/features/chat/calls/audio_room_contract.dart:222
  ///
  /// In en, this message translates to:
  /// **'Voice disconnected; count updates after reconnecting'**
  String get chatCalls_audioRoomContractDisconnected;

  /// lib/features/chat/calls/audio_room_contract.dart:448
  ///
  /// In en, this message translates to:
  /// **'Earpiece'**
  String get chatCalls_audioRoomContractEarpiece;

  /// lib/features/chat/calls/audio_room_contract.dart:455
  ///
  /// In en, this message translates to:
  /// **'Headphones'**
  String get chatCalls_audioRoomContractExternalOutputLabel;

  /// lib/features/chat/calls/audio_room_contract.dart:221
  ///
  /// In en, this message translates to:
  /// **'Voice reconnecting; count updates after reconnecting'**
  String get chatCalls_audioRoomContractReconnecting;

  /// lib/features/chat/calls/audio_room_contract.dart:447
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get chatCalls_audioRoomContractSpeaker;

  /// lib/features/chat/calls/audio_room_contract.dart:573
  ///
  /// In en, this message translates to:
  /// **'Tap to return to the voice room'**
  String get chatCalls_audioRoomContractText;

  /// lib/features/chat/calls/audio_room_contract.dart:572, lib/features/chat/calls/audio_room_contract.dart:600
  ///
  /// In en, this message translates to:
  /// **'In voice room'**
  String get chatCalls_audioRoomContractTitle;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:427
  ///
  /// In en, this message translates to:
  /// **'You can\'t speak in this call anymore. Leave and join again.'**
  String get chatCalls_streamForegroundViewCallClosed;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:221, lib/features/chat/calls/stream_foreground_call_view.dart:236
  ///
  /// In en, this message translates to:
  /// **'Counting people in the call'**
  String get chatCalls_streamForegroundViewCanRequest;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:981
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reconnect voice. Try again.'**
  String get chatCalls_streamForegroundViewCommandError;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1035
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t leave this call cleanly. Retry.'**
  String get chatCalls_streamForegroundViewCommandError2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:379
  ///
  /// In en, this message translates to:
  /// **'Leaving this call. The mic won\'t start again; mute first if needed, then retry leaving.'**
  String get chatCalls_streamForegroundViewIf;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:381
  ///
  /// In en, this message translates to:
  /// **'Your mic is on and people in the room can hear you. Tap Mute to turn it off anytime.'**
  String get chatCalls_streamForegroundViewIf2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:384
  ///
  /// In en, this message translates to:
  /// **'You were moved off stage and can only listen now. Wait for the host to invite you again to speak.'**
  String get chatCalls_streamForegroundViewIf3;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:387
  ///
  /// In en, this message translates to:
  /// **'You\'re muted. To speak again, tap {speakAgainLabel} to reconnect voice.'**
  String chatCalls_streamForegroundViewIf4(Object? speakAgainLabel);

  /// lib/features/chat/calls/stream_foreground_call_view.dart:388
  ///
  /// In en, this message translates to:
  /// **'You joined muted. Tap {speakLabel} when you\'re ready; mic access is only requested when capture starts.'**
  String chatCalls_streamForegroundViewIf5(Object? speakLabel);

  /// lib/features/chat/calls/stream_foreground_call_view.dart:78
  ///
  /// In en, this message translates to:
  /// **'Reconnect failed'**
  String get chatCalls_streamForegroundViewLabel;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:79
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get chatCalls_streamForegroundViewLabel2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:80
  ///
  /// In en, this message translates to:
  /// **'Joining'**
  String get chatCalls_streamForegroundViewLabel3;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:81
  ///
  /// In en, this message translates to:
  /// **'Connecting media'**
  String get chatCalls_streamForegroundViewLabel4;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:82
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get chatCalls_streamForegroundViewLabel5;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:83
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get chatCalls_streamForegroundViewLabel6;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:84
  ///
  /// In en, this message translates to:
  /// **'Switching connection'**
  String get chatCalls_streamForegroundViewLabel7;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:85
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get chatCalls_streamForegroundViewLabel8;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:87
  ///
  /// In en, this message translates to:
  /// **'Call unavailable'**
  String get chatCalls_streamForegroundViewLabel9;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1116
  ///
  /// In en, this message translates to:
  /// **'This call dropped and is reconnecting. Member details reload once connected.'**
  String get chatCalls_streamForegroundViewMessage;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1121
  ///
  /// In en, this message translates to:
  /// **'This call disconnected. Member details load after voice reconnects.'**
  String get chatCalls_streamForegroundViewMessage2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1126
  ///
  /// In en, this message translates to:
  /// **'Not connected to this call yet. Member details load once connected.'**
  String get chatCalls_streamForegroundViewMessage3;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1134
  ///
  /// In en, this message translates to:
  /// **'This call just connected; the provider hasn\'t sent member details yet.'**
  String get chatCalls_streamForegroundViewMessage4;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:332
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get chatCalls_streamForegroundViewMicrophoneState;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:333
  ///
  /// In en, this message translates to:
  /// **'Mic on'**
  String get chatCalls_streamForegroundViewMicrophoneState2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:426
  ///
  /// In en, this message translates to:
  /// **'This room hasn\'t let you speak yet; your mic is off.'**
  String get chatCalls_streamForegroundViewRoomPermission;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:221
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person in the call now} other{{count} people in the call now}}'**
  String chatCalls_streamForegroundViewS(num count);

  /// lib/features/chat/calls/stream_foreground_call_view.dart:385
  ///
  /// In en, this message translates to:
  /// **'You\'re a listener in this room.'**
  String get chatCalls_streamForegroundViewS2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:403, lib/features/chat/calls/stream_foreground_call_view.dart:776
  ///
  /// In en, this message translates to:
  /// **'Speak again'**
  String get chatCalls_streamForegroundViewS3;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:408, lib/features/chat/calls/stream_foreground_call_view.dart:930
  ///
  /// In en, this message translates to:
  /// **'Listen only'**
  String get chatCalls_streamForegroundViewS4;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1080
  ///
  /// In en, this message translates to:
  /// **'Switch to earpiece'**
  String get chatCalls_streamForegroundViewS5;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1018
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mute the mic. Retry, or leave this room.'**
  String get chatCalls_streamForegroundViewSetState;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:401
  ///
  /// In en, this message translates to:
  /// **'Reconnect to speak'**
  String get chatCalls_streamForegroundViewSpeakAgainLabel;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:400, lib/features/chat/calls/stream_voice_room_page.dart:547, lib/features/chat/calls/stream_voice_room_page.dart:1599
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get chatCalls_streamForegroundViewSpeakLabel;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:403
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:404
  ///
  /// In en, this message translates to:
  /// **'Switching'**
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:407
  ///
  /// In en, this message translates to:
  /// **'Leaving'**
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel3;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:408
  ///
  /// In en, this message translates to:
  /// **'Can\'t unmute'**
  String get chatCalls_streamForegroundViewStreamBarMicrophoneLabel4;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1077
  ///
  /// In en, this message translates to:
  /// **'Audio plays from the connected device'**
  String get chatCalls_streamForegroundViewSwitch;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1079
  ///
  /// In en, this message translates to:
  /// **'Switch to speaker'**
  String get chatCalls_streamForegroundViewSwitch2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:425
  ///
  /// In en, this message translates to:
  /// **'No mic access. Allow LOOP to use the microphone in system settings, then try again.'**
  String get chatCalls_streamForegroundViewSystemPermission;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1115
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get chatCalls_streamForegroundViewTitle;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1120, lib/features/chat/calls/stream_voice_room_page.dart:1394
  ///
  /// In en, this message translates to:
  /// **'Voice disconnected'**
  String get chatCalls_streamForegroundViewTitle2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1125
  ///
  /// In en, this message translates to:
  /// **'Connecting voice'**
  String get chatCalls_streamForegroundViewTitle3;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1133
  ///
  /// In en, this message translates to:
  /// **'Loading call members'**
  String get chatCalls_streamForegroundViewTitle4;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:428
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn on the mic. Try again.'**
  String get chatCalls_streamForegroundViewUnknown;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:756
  ///
  /// In en, this message translates to:
  /// **'Audio paused by the system'**
  String get chatCalls_streamForegroundViewVoiceroomMediaAudioSuspended;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:949, lib/features/chat/calls/stream_foreground_call_view.dart:957
  ///
  /// In en, this message translates to:
  /// **'Disconnect voice'**
  String get chatCalls_streamForegroundViewVoiceroomMediaDisconnectMessage;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:919
  ///
  /// In en, this message translates to:
  /// **'Switching mic'**
  String get chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:927
  ///
  /// In en, this message translates to:
  /// **'Retry leaving first'**
  String get chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel2;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:929
  ///
  /// In en, this message translates to:
  /// **'Can\'t unmute in this call'**
  String get chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel3;

  /// lib/features/chat/calls/stream_foreground_call_view.dart:1083
  ///
  /// In en, this message translates to:
  /// **'Audio output: {label}'**
  String chatCalls_streamForegroundViewVoiceroomMediaOutputLabel(Object? label);

  /// lib/features/chat/calls/stream_foreground_call_view.dart:894, lib/features/chat/calls/stream_voice_room_page.dart:1363
  ///
  /// In en, this message translates to:
  /// **'Reconnecting voice'**
  String get chatCalls_streamForegroundViewVoiceroomMediaSpeakAgainLabel;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1540
  ///
  /// In en, this message translates to:
  /// **'Your sign-in changed while connecting. Leave this page and come back.'**
  String get chatCalls_streamVoiceRoomAccountChanged;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1538
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set up voice on this device. Try again.'**
  String get chatCalls_streamVoiceRoomClient;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1539
  ///
  /// In en, this message translates to:
  /// **'This device couldn\'t reach the voice service. Check your network and retry.'**
  String get chatCalls_streamVoiceRoomConnection;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1537
  ///
  /// In en, this message translates to:
  /// **'The voice credential for this call wasn\'t issued. Check your network and retry.'**
  String get chatCalls_streamVoiceRoomCredential;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1574
  ///
  /// In en, this message translates to:
  /// **'You\'re the host and also join muted; mic access is only requested when you tap {speakLabel}. The room doesn\'t end if voice can\'t connect; use End room below to end it.'**
  String chatCalls_streamVoiceRoomHost(Object? speakLabel);

  /// lib/features/chat/calls/stream_voice_room_page.dart:1536
  ///
  /// In en, this message translates to:
  /// **'This device doesn\'t have a voice identity yet. Leave this page and come back.'**
  String get chatCalls_streamVoiceRoomIdentity;

  /// lib/features/chat/calls/stream_voice_room_page.dart:733
  ///
  /// In en, this message translates to:
  /// **'You always join muted; mic access is only requested when you tap Speak. Voice continues in the background or when locked; only Leave disconnects.'**
  String get chatCalls_streamVoiceRoomIf;

  /// lib/features/chat/calls/stream_voice_room_page.dart:777
  ///
  /// In en, this message translates to:
  /// **'Join muted · Continues in background'**
  String get chatCalls_streamVoiceRoomIf2;

  /// lib/features/chat/calls/stream_voice_room_page.dart:789
  ///
  /// In en, this message translates to:
  /// **'No demo members, presence or room activity are shown here.'**
  String get chatCalls_streamVoiceRoomIf3;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1014
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get this voice room ready. Check the conversation and retry.'**
  String get chatCalls_streamVoiceRoomJoinError;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1344
  ///
  /// In en, this message translates to:
  /// **'This call disconnected. Recording your exit in the LOOP room record.'**
  String get chatCalls_streamVoiceRoomMessage;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1456
  ///
  /// In en, this message translates to:
  /// **'Requesting a voice identity and short-lived token. No call is joined meanwhile.'**
  String get chatCalls_streamVoiceRoomMessage10;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1476
  ///
  /// In en, this message translates to:
  /// **'Loading the authorized voice room. Your mic stays off.'**
  String get chatCalls_streamVoiceRoomMessage11;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1484
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the authorized voice room. No other room is joined and no demo data is shown instead.'**
  String get chatCalls_streamVoiceRoomMessage12;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1493
  ///
  /// In en, this message translates to:
  /// **'This session doesn\'t have an authorized voice room yet. Enter from a community\'s voice room.'**
  String get chatCalls_streamVoiceRoomMessage13;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1502
  ///
  /// In en, this message translates to:
  /// **'The voice room is authorized, but the voice client for this account has expired. Re-authorize the session.'**
  String get chatCalls_streamVoiceRoomMessage14;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1519
  ///
  /// In en, this message translates to:
  /// **'Voice room authorized. You always join muted, and voice continues in the background.'**
  String get chatCalls_streamVoiceRoomMessage15;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1600
  ///
  /// In en, this message translates to:
  /// **'No local audio is published while connecting.'**
  String get chatCalls_streamVoiceRoomMessage16;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1606
  ///
  /// In en, this message translates to:
  /// **'Mic access is only requested after you tap Speak.'**
  String get chatCalls_streamVoiceRoomMessage17;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1612
  ///
  /// In en, this message translates to:
  /// **'Voice continues when you switch apps or lock the screen; only Leave disconnects.'**
  String get chatCalls_streamVoiceRoomMessage18;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1355
  ///
  /// In en, this message translates to:
  /// **'You\'re still in the room and will reconnect automatically when the network is back. Use Leave below to exit.'**
  String get chatCalls_streamVoiceRoomMessage2;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1364
  ///
  /// In en, this message translates to:
  /// **'Reloading this room and getting a new voice identity, then reconnecting.'**
  String get chatCalls_streamVoiceRoomMessage3;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1385
  ///
  /// In en, this message translates to:
  /// **'{joinError}You\'re still in this room and haven\'t been removed.'**
  String chatCalls_streamVoiceRoomMessage4(Object? joinError);

  /// lib/features/chat/calls/stream_voice_room_page.dart:1395
  ///
  /// In en, this message translates to:
  /// **'This call disconnected. LOOP still lists you as a member of this room.'**
  String get chatCalls_streamVoiceRoomMessage5;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1404
  ///
  /// In en, this message translates to:
  /// **'Joined the room, connecting voice. You joined muted as a listener.'**
  String get chatCalls_streamVoiceRoomMessage6;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1431
  ///
  /// In en, this message translates to:
  /// **'Voice only starts in a verified sign-in session; offline or unverified sessions don\'t connect.'**
  String get chatCalls_streamVoiceRoomMessage7;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1438
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect again until the last call has turned off the mic and left.'**
  String get chatCalls_streamVoiceRoomMessage8;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1447
  ///
  /// In en, this message translates to:
  /// **'The last call didn\'t confirm leaving. Retry cleanup first, then connect voice.'**
  String get chatCalls_streamVoiceRoomMessage9;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1554
  ///
  /// In en, this message translates to:
  /// **'This connection didn\'t go through. Check your network and retry.'**
  String get chatCalls_streamVoiceRoomNetwork;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1552
  ///
  /// In en, this message translates to:
  /// **'Listening isn\'t open in this room yet. Ask the host to reopen it.'**
  String get chatCalls_streamVoiceRoomPermission;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1553
  ///
  /// In en, this message translates to:
  /// **'This room can\'t be joined anymore. Check the community to see if it\'s still live.'**
  String get chatCalls_streamVoiceRoomRoomUnavailable;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1555
  ///
  /// In en, this message translates to:
  /// **'This voice identity has expired. Leave this page and come back.'**
  String get chatCalls_streamVoiceRoomSession;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1577
  ///
  /// In en, this message translates to:
  /// **'You\'re a speaker and also join muted; mic access is only requested when you tap {speakLabel}. Voice isn\'t connected but you\'re still in the room; tap Leave below to exit.'**
  String chatCalls_streamVoiceRoomSpeaker(Object? speakLabel);

  /// lib/features/chat/calls/stream_voice_room_page.dart:1541
  ///
  /// In en, this message translates to:
  /// **'This device couldn\'t set up a voice session. It stays disconnected and no call is created.'**
  String get chatCalls_streamVoiceRoomSwitch;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1580
  ///
  /// In en, this message translates to:
  /// **'You joined muted as a listener and mic access isn\'t requested. Voice isn\'t connected but you\'re still in the room; tap Leave below to exit.'**
  String get chatCalls_streamVoiceRoomSwitch2;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1343
  ///
  /// In en, this message translates to:
  /// **'Leaving voice room…'**
  String get chatCalls_streamVoiceRoomTitle;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1475
  ///
  /// In en, this message translates to:
  /// **'Loading voice room'**
  String get chatCalls_streamVoiceRoomTitle10;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1483
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load voice room'**
  String get chatCalls_streamVoiceRoomTitle11;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1492
  ///
  /// In en, this message translates to:
  /// **'No voice room yet'**
  String get chatCalls_streamVoiceRoomTitle12;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1501
  ///
  /// In en, this message translates to:
  /// **'Voice client unavailable'**
  String get chatCalls_streamVoiceRoomTitle13;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1510
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get chatCalls_streamVoiceRoomTitle14;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1518
  ///
  /// In en, this message translates to:
  /// **'Voice ready to connect'**
  String get chatCalls_streamVoiceRoomTitle15;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1599
  ///
  /// In en, this message translates to:
  /// **'Muted on entry'**
  String get chatCalls_streamVoiceRoomTitle16;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1605
  ///
  /// In en, this message translates to:
  /// **'Mic access on demand'**
  String get chatCalls_streamVoiceRoomTitle17;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1611
  ///
  /// In en, this message translates to:
  /// **'Continues in background'**
  String get chatCalls_streamVoiceRoomTitle18;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1354
  ///
  /// In en, this message translates to:
  /// **'Voice dropped, reconnecting'**
  String get chatCalls_streamVoiceRoomTitle2;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1384, lib/features/chat/calls/stream_voice_room_page.dart:1413
  ///
  /// In en, this message translates to:
  /// **'Joined, voice connection failed'**
  String get chatCalls_streamVoiceRoomTitle3;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1403
  ///
  /// In en, this message translates to:
  /// **'Connecting voice…'**
  String get chatCalls_streamVoiceRoomTitle4;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1430
  ///
  /// In en, this message translates to:
  /// **'Sign-in verification required'**
  String get chatCalls_streamVoiceRoomTitle5;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1437
  ///
  /// In en, this message translates to:
  /// **'Confirming the last call ended'**
  String get chatCalls_streamVoiceRoomTitle6;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1446
  ///
  /// In en, this message translates to:
  /// **'The last call didn\'t end cleanly'**
  String get chatCalls_streamVoiceRoomTitle7;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1455
  ///
  /// In en, this message translates to:
  /// **'Preparing voice connection'**
  String get chatCalls_streamVoiceRoomTitle8;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1464
  ///
  /// In en, this message translates to:
  /// **'Voice session unavailable right now'**
  String get chatCalls_streamVoiceRoomTitle9;

  /// lib/features/chat/calls/stream_voice_room_page.dart:1556
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to this voice room. Try again later.'**
  String get chatCalls_streamVoiceRoomUnknown;

  /// lib/features/chat/calls/stream_voice_room_page.dart:680
  ///
  /// In en, this message translates to:
  /// **'Connecting muted'**
  String get chatCalls_streamVoiceRoomVoiceroomMediaJoinLabel;

  /// lib/features/chat/calls/stream_voice_room_page.dart:680
  ///
  /// In en, this message translates to:
  /// **'Connect voice'**
  String get chatCalls_streamVoiceRoomVoiceroomMediaJoinLabel2;

  /// lib/features/chat/calls/stream_voice_room_page.dart:702
  ///
  /// In en, this message translates to:
  /// **'Reconnect voice'**
  String get chatCalls_streamVoiceRoomVoiceroomMediaReconnectLabel;

  /// lib/features/chat/calls/stream_voice_room_page.dart:544
  ///
  /// In en, this message translates to:
  /// **'Your mic was on when the network dropped. It stays muted after reconnecting; tap {vVoiceMediaPresentation} when you need it.'**
  String chatCalls_streamVoiceRoomVoiceroomMediaRestoredMessage(
    Object? vVoiceMediaPresentation,
  );

  /// lib/features/chat/calls/stream_voice_room_page.dart:667
  ///
  /// In en, this message translates to:
  /// **'Retry cleanup'**
  String get chatCalls_streamVoiceRoomVoiceroomMediaRetryCleanupLabel;

  /// lib/features/chat/calls/stream_voice_room_page.dart:651
  ///
  /// In en, this message translates to:
  /// **'Retry session'**
  String get chatCalls_streamVoiceRoomVoiceroomMediaRetrySessionLabel;

  /// lib/features/chat/calls/stream_voice_room_page.dart:660
  ///
  /// In en, this message translates to:
  /// **'Reload voice room'**
  String get chatCalls_streamVoiceRoomVoiceroomMediaRetryTargetLabel;

  /// lib/features/chat/friends/chat_create_menu_button.dart:33
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get chatFriends_createMenuButtonChatCreateMenuLabel;

  /// lib/features/chat/friends/chat_create_menu_button.dart:60
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get chatFriends_createMenuButtonChatCreateMenuLabel2;

  /// lib/features/chat/friends/chat_create_menu_button.dart:79
  ///
  /// In en, this message translates to:
  /// **'Find people by LOOP ID or nickname and send a message request'**
  String get chatFriends_createMenuButtonSubtitle;

  /// lib/features/chat/friends/chat_create_menu_button.dart:88
  ///
  /// In en, this message translates to:
  /// **'Apply to list; goes live after review'**
  String get chatFriends_createMenuButtonSubtitle2;

  /// lib/features/chat/friends/chat_create_menu_button.dart:96
  ///
  /// In en, this message translates to:
  /// **'Start a small group with friends'**
  String get chatFriends_createMenuButtonSubtitle3;

  /// lib/features/chat/friends/chat_create_menu_button.dart:104
  ///
  /// In en, this message translates to:
  /// **'Scan a profile card, community code or wallet address'**
  String get chatFriends_createMenuButtonSubtitle4;

  /// lib/features/chat/friends/chat_create_menu_button.dart:78
  ///
  /// In en, this message translates to:
  /// **'Search / add users'**
  String get chatFriends_createMenuButtonTitle;

  /// lib/features/chat/friends/chat_create_menu_button.dart:87
  ///
  /// In en, this message translates to:
  /// **'Create community'**
  String get chatFriends_createMenuButtonTitle2;

  /// lib/features/chat/friends/chat_create_menu_button.dart:95
  ///
  /// In en, this message translates to:
  /// **'Create group chat'**
  String get chatFriends_createMenuButtonTitle3;

  /// lib/features/chat/friends/friend_screens.dart:439
  ///
  /// In en, this message translates to:
  /// **'This friend request was already handled. Refresh the list.'**
  String get chatFriends_screensAlreadyDecided;

  /// lib/features/chat/friends/friend_screens.dart:437
  ///
  /// In en, this message translates to:
  /// **'You\'re already friends.'**
  String get chatFriends_screensAlreadyFriends;

  /// lib/features/chat/friends/friend_screens.dart:388
  ///
  /// In en, this message translates to:
  /// **'{name} · {receipt, plural, =1{1 member} other{{receipt} members}}. This result exists only in this run; no Stream channel was created.'**
  String chatFriends_screensBody(Object? name, num receipt);

  /// lib/features/chat/friends/friend_screens.dart:389
  ///
  /// In en, this message translates to:
  /// **'{name} · {receipt, plural, =1{1 member} other{{receipt} members}}. The channel was created and authorized by the LOOP backend.'**
  String chatFriends_screensBody2(Object? name, num receipt);

  /// lib/features/chat/friends/friend_screens.dart:432
  ///
  /// In en, this message translates to:
  /// **'The friendship changed. Refresh and try again.'**
  String get chatFriends_screensConflict;

  /// lib/features/chat/friends/friend_screens.dart:438
  ///
  /// In en, this message translates to:
  /// **'This friend request is cooling down. Try again later.'**
  String get chatFriends_screensCooldown;

  /// lib/features/chat/friends/friend_screens.dart:440
  ///
  /// In en, this message translates to:
  /// **'The list page expired; reload from the first page.'**
  String get chatFriends_screensCursorInvalid;

  /// lib/features/chat/friends/friend_screens.dart:396
  ///
  /// In en, this message translates to:
  /// **'Create another'**
  String get chatFriends_screensFriendGroupCreateAnotherLabel;

  /// lib/features/chat/friends/friend_screens.dart:298
  ///
  /// In en, this message translates to:
  /// **'{friendFailureMessage} The draft is frozen and won\'t be resubmitted automatically.'**
  String chatFriends_screensFriendGroupCreateFailureBody(
    Object? friendFailureMessage,
  );

  /// lib/features/chat/friends/friend_screens.dart:293
  ///
  /// In en, this message translates to:
  /// **'Group creation needs manual review'**
  String get chatFriends_screensFriendGroupCreateFailureTitle;

  /// lib/features/chat/friends/friend_screens.dart:295
  ///
  /// In en, this message translates to:
  /// **'Group creation result pending'**
  String get chatFriends_screensFriendGroupCreateFailureTitle2;

  /// lib/features/chat/friends/friend_screens.dart:296
  ///
  /// In en, this message translates to:
  /// **'Group not created'**
  String get chatFriends_screensFriendGroupCreateFailureTitle3;

  /// lib/features/chat/friends/friend_screens.dart:90, lib/features/chat/friends/friend_screens.dart:99, lib/features/chat/friends/friend_screens.dart:174
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get chatFriends_screensFriendGroupCreateScreenTitle;

  /// lib/features/chat/friends/friend_screens.dart:173
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get chatFriends_screensFriendGroupCreateSubmitLabel;

  /// lib/features/chat/friends/friend_screens.dart:239
  ///
  /// In en, this message translates to:
  /// **'Add friends'**
  String get chatFriends_screensFriendGroupFindFriendsLabel;

  /// lib/features/chat/friends/friend_screens.dart:100
  ///
  /// In en, this message translates to:
  /// **'Pick from accepted friends. The LOOP backend creates the group; it only appears in Chat once that succeeds.'**
  String get chatFriends_screensFriendGroupFolioCaption;

  /// lib/features/chat/friends/friend_screens.dart:98
  ///
  /// In en, this message translates to:
  /// **'Group with friends'**
  String get chatFriends_screensFriendGroupFolioKicker;

  /// lib/features/chat/friends/friend_screens.dart:101
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get chatFriends_screensFriendGroupFolioStamp;

  /// lib/features/chat/friends/friend_screens.dart:235
  ///
  /// In en, this message translates to:
  /// **'You can invite someone to a group after they accept your friend request.'**
  String get chatFriends_screensFriendGroupFriendsEmptyMessage;

  /// lib/features/chat/friends/friend_screens.dart:234
  ///
  /// In en, this message translates to:
  /// **'No friends to choose'**
  String get chatFriends_screensFriendGroupFriendsEmptyTitle;

  /// lib/features/chat/friends/friend_screens.dart:215
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load friends right now'**
  String get chatFriends_screensFriendGroupFriendsFailureTitle;

  /// lib/features/chat/friends/friend_screens.dart:138
  ///
  /// In en, this message translates to:
  /// **'Up to 60 characters'**
  String get chatFriends_screensFriendGroupNameFieldFootnote;

  /// lib/features/chat/friends/friend_screens.dart:137, lib/features/chat/friends/friend_screens.dart:147
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get chatFriends_screensFriendGroupNameFieldLabel;

  /// lib/features/chat/friends/friend_screens.dart:414
  ///
  /// In en, this message translates to:
  /// **'Open group chat'**
  String get chatFriends_screensFriendGroupOpenChannelLabel;

  /// lib/features/chat/friends/friend_screens.dart:274
  ///
  /// In en, this message translates to:
  /// **'Check result'**
  String get chatFriends_screensFriendGroupReconcileLabel;

  /// lib/features/chat/friends/friend_screens.dart:282
  ///
  /// In en, this message translates to:
  /// **'Edit draft'**
  String get chatFriends_screensFriendGroupResumeEditingLabel;

  /// lib/features/chat/friends/friend_screens.dart:154
  ///
  /// In en, this message translates to:
  /// **'Choose friends · {selectedFriendRefs}/{groupMaximumSelectedFriends}'**
  String chatFriends_screensFriendGroupSelectionLabel(
    Object? groupMaximumSelectedFriends,
    Object? selectedFriendRefs,
  );

  /// lib/features/chat/friends/friend_screens.dart:407
  ///
  /// In en, this message translates to:
  /// **'Set group nickname'**
  String get chatFriends_screensFriendGroupSetAliasLabel;

  /// lib/features/chat/friends/friend_screens.dart:108
  ///
  /// In en, this message translates to:
  /// **'No group is created and no members are added here.'**
  String get chatFriends_screensFriendGroupUnavailableMessage;

  /// lib/features/chat/friends/friend_screens.dart:107
  ///
  /// In en, this message translates to:
  /// **'Group chat creation isn\'t available yet'**
  String get chatFriends_screensFriendGroupUnavailableTitle;

  /// lib/features/chat/friends/friend_screens.dart:352
  ///
  /// In en, this message translates to:
  /// **'Friends, requests and new groups are kept in memory only and aren\'t written to the LOOP backend or Stream.'**
  String get chatFriends_screensFriendPreviewBannerBody;

  /// lib/features/chat/friends/friend_screens.dart:351
  ///
  /// In en, this message translates to:
  /// **'Development preview · This run only'**
  String get chatFriends_screensFriendPreviewBannerTitle;

  /// lib/features/chat/friends/friend_screens.dart:435
  ///
  /// In en, this message translates to:
  /// **'They\'ve already sent you a request. Handle it in friend requests.'**
  String get chatFriends_screensIncomingRequestPending;

  /// lib/features/chat/friends/friend_screens.dart:429
  ///
  /// In en, this message translates to:
  /// **'The input or server data doesn\'t meet current safety constraints.'**
  String get chatFriends_screensInvalidData;

  /// lib/features/chat/friends/friend_screens.dart:383
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get chatFriends_screensLoopLabel;

  /// lib/features/chat/friends/friend_screens.dart:430
  ///
  /// In en, this message translates to:
  /// **'The target isn\'t available right now. Hidden and nonexistent accounts aren\'t distinguished.'**
  String get chatFriends_screensNotFound;

  /// lib/features/chat/friends/friend_screens.dart:364
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get chatFriends_screensNotSelected;

  /// lib/features/chat/friends/friend_screens.dart:441
  ///
  /// In en, this message translates to:
  /// **'The channel needs manual review; a second channel won\'t be created automatically.'**
  String get chatFriends_screensOperatorRequired;

  /// lib/features/chat/friends/friend_screens.dart:442
  ///
  /// In en, this message translates to:
  /// **'The request may have been received, but the final result can\'t be safely confirmed right now.'**
  String get chatFriends_screensOutcomeUnknown;

  /// lib/features/chat/friends/friend_screens.dart:436
  ///
  /// In en, this message translates to:
  /// **'Friend request sent, waiting for them to respond.'**
  String get chatFriends_screensOutgoingRequestPending;

  /// lib/features/chat/friends/friend_screens.dart:431
  ///
  /// In en, this message translates to:
  /// **'This account can\'t do that. No friendship or group was changed.'**
  String get chatFriends_screensPermissionDenied;

  /// lib/features/chat/friends/friend_screens.dart:434
  ///
  /// In en, this message translates to:
  /// **'Set your LOOP nickname in Profile first.'**
  String get chatFriends_screensProfileRequired;

  /// lib/features/chat/friends/friend_screens.dart:433
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get chatFriends_screensRateLimited;

  /// lib/features/chat/friends/friend_screens.dart:364
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get chatFriends_screensSelected;

  /// lib/features/chat/friends/friend_screens.dart:444
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the action right now.'**
  String get chatFriends_screensSwitch;

  /// lib/features/chat/friends/friend_screens.dart:183
  ///
  /// In en, this message translates to:
  /// **'{groupMinimumSelectedFriends, plural, =1{Choose at least 1 friend} other{Choose at least {groupMinimumSelectedFriends} friends}}'**
  String chatFriends_screensText(num groupMinimumSelectedFriends);

  /// lib/features/chat/friends/friend_screens.dart:386
  ///
  /// In en, this message translates to:
  /// **'Development preview group created'**
  String get chatFriends_screensTitle;

  /// lib/features/chat/friends/friend_screens.dart:386
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get chatFriends_screensTitle2;

  /// lib/features/chat/friends/friend_screens.dart:428
  ///
  /// In en, this message translates to:
  /// **'The friend service isn\'t available right now. No friendship or group was changed.'**
  String get chatFriends_screensUnavailable;

  /// lib/features/chat/friends/friend_screens.dart:443
  ///
  /// In en, this message translates to:
  /// **'The service couldn\'t complete the request; no friendship or group was changed.'**
  String get chatFriends_screensUnexpected;

  /// lib/features/chat/group_alias/group_alias_stream_message_identity.dart:40
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get chatGroupAlias_neutralMember;

  /// lib/features/chat/group_alias/group_alias_screen.dart:313
  ///
  /// In en, this message translates to:
  /// **'Your nickname is reserved; the group display is still syncing. Retry with the exact same nickname.'**
  String get chatGroupAlias_screenBody;

  /// lib/features/chat/group_alias/group_alias_screen.dart:314
  ///
  /// In en, this message translates to:
  /// **'This nickname is permanently reserved in this group and can\'t be changed. It doesn\'t reveal your public profile or Stream user identity.'**
  String get chatGroupAlias_screenBody2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:420
  ///
  /// In en, this message translates to:
  /// **'Can\'t set group nickname'**
  String get chatGroupAlias_screenGroupAliasBlockedTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:591
  ///
  /// In en, this message translates to:
  /// **'Your group nickname only shows in this group and isn\'t linked to your public profile or wallet address.'**
  String get chatGroupAlias_screenGroupAliasBoundaryBody;

  /// lib/features/chat/group_alias/group_alias_screen.dart:120
  ///
  /// In en, this message translates to:
  /// **'This page didn\'t get a valid Stream group chat reference; no network request was made.'**
  String get chatGroupAlias_screenGroupAliasChannelInvalidMessage;

  /// lib/features/chat/group_alias/group_alias_screen.dart:119
  ///
  /// In en, this message translates to:
  /// **'Invalid group chat reference'**
  String get chatGroupAlias_screenGroupAliasChannelInvalidTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:365
  ///
  /// In en, this message translates to:
  /// **'Group nickname not reserved'**
  String get chatGroupAlias_screenGroupAliasFailureTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:390
  ///
  /// In en, this message translates to:
  /// **'Can\'t be changed after submitting; nicknames must be unique in a group.'**
  String get chatGroupAlias_screenGroupAliasFieldFootnote;

  /// lib/features/chat/group_alias/group_alias_screen.dart:389
  ///
  /// In en, this message translates to:
  /// **'Group nickname'**
  String get chatGroupAlias_screenGroupAliasFieldLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:239
  ///
  /// In en, this message translates to:
  /// **'You can use a different nickname in each group. It\'s permanent once reserved; the app doesn\'t link identities across groups, but this isn\'t a guarantee of anonymity.'**
  String get chatGroupAlias_screenGroupAliasFolioCaption;

  /// lib/features/chat/group_alias/group_alias_screen.dart:237
  ///
  /// In en, this message translates to:
  /// **'Group nickname'**
  String get chatGroupAlias_screenGroupAliasFolioKicker;

  /// lib/features/chat/group_alias/group_alias_screen.dart:343
  ///
  /// In en, this message translates to:
  /// **'\"{pendingAlias}\" may already be permanently reserved. To avoid locking a different value, you can only retry the exact same nickname.'**
  String chatGroupAlias_screenGroupAliasOutcomeUnknownBody(
    Object? pendingAlias,
  );

  /// lib/features/chat/group_alias/group_alias_screen.dart:340
  ///
  /// In en, this message translates to:
  /// **'Reservation result pending'**
  String get chatGroupAlias_screenGroupAliasOutcomeUnknownTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:90
  ///
  /// In en, this message translates to:
  /// **'Group members show with their own avatar and username. No request was made here.'**
  String get chatGroupAlias_screenGroupAliasPausedMessage;

  /// lib/features/chat/group_alias/group_alias_screen.dart:89
  ///
  /// In en, this message translates to:
  /// **'Group nicknames aren\'t available yet'**
  String get chatGroupAlias_screenGroupAliasPausedTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:374
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get chatGroupAlias_screenGroupAliasReloadLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:186
  ///
  /// In en, this message translates to:
  /// **'Retry check'**
  String get chatGroupAlias_screenGroupAliasResolverRetryLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:348
  ///
  /// In en, this message translates to:
  /// **'Retry with same nickname'**
  String get chatGroupAlias_screenGroupAliasRetryPendingLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:320
  ///
  /// In en, this message translates to:
  /// **'Retry sync'**
  String get chatGroupAlias_screenGroupAliasRetryProjectionLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:70
  ///
  /// In en, this message translates to:
  /// **'This page didn\'t get a valid LOOP group_id; no network request was made.'**
  String get chatGroupAlias_screenGroupAliasRouteInvalidMessage;

  /// lib/features/chat/group_alias/group_alias_screen.dart:69
  ///
  /// In en, this message translates to:
  /// **'Invalid group reference'**
  String get chatGroupAlias_screenGroupAliasRouteInvalidTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:522
  ///
  /// In en, this message translates to:
  /// **'Members still syncing, members who left, and you won\'t appear in results.'**
  String get chatGroupAlias_screenGroupAliasSearchEmptyMessage;

  /// lib/features/chat/group_alias/group_alias_screen.dart:521
  ///
  /// In en, this message translates to:
  /// **'No matching nicknames'**
  String get chatGroupAlias_screenGroupAliasSearchEmptyTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:555
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search the group: {groupAliasFailureMessage}'**
  String chatGroupAlias_screenGroupAliasSearchFailureMessage(
    Object? groupAliasFailureMessage,
  );

  /// lib/features/chat/group_alias/group_alias_screen.dart:483
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters'**
  String get chatGroupAlias_screenGroupAliasSearchFieldFootnote;

  /// lib/features/chat/group_alias/group_alias_screen.dart:486
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get chatGroupAlias_screenGroupAliasSearchSubmitLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:486
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatGroupAlias_screenGroupAliasSearchSubmitLabel2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:488
  ///
  /// In en, this message translates to:
  /// **'Search group nicknames'**
  String get chatGroupAlias_screenGroupAliasSearchSubmitSemanticLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:533
  ///
  /// In en, this message translates to:
  /// **'Keep typing a fuller nickname to narrow results.'**
  String get chatGroupAlias_screenGroupAliasSearchTruncatedBody;

  /// lib/features/chat/group_alias/group_alias_screen.dart:532
  ///
  /// In en, this message translates to:
  /// **'Results truncated'**
  String get chatGroupAlias_screenGroupAliasSearchTruncatedTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:408
  ///
  /// In en, this message translates to:
  /// **'Reserving…'**
  String get chatGroupAlias_screenGroupAliasSubmitLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:408
  ///
  /// In en, this message translates to:
  /// **'Reserve this nickname permanently'**
  String get chatGroupAlias_screenGroupAliasSubmitLabel2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:21, lib/features/chat/group_alias/group_alias_screen.dart:482
  ///
  /// In en, this message translates to:
  /// **'Group nicknames'**
  String get chatGroupAlias_screenGroupAliasTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:279
  ///
  /// In en, this message translates to:
  /// **'No demo nickname is shown, and your account nickname or wallet address isn\'t used as your group identity.'**
  String get chatGroupAlias_screenGroupAliasUnavailableMessage;

  /// lib/features/chat/group_alias/group_alias_screen.dart:278
  ///
  /// In en, this message translates to:
  /// **'Group nickname service unavailable'**
  String get chatGroupAlias_screenGroupAliasUnavailableTitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:399
  ///
  /// In en, this message translates to:
  /// **'1–40 characters'**
  String get chatGroupAlias_screenHint;

  /// lib/features/chat/group_alias/group_alias_screen.dart:501
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname to search'**
  String get chatGroupAlias_screenHint2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:602
  ///
  /// In en, this message translates to:
  /// **'This account already reserved a different nickname in this group; it can\'t be changed.'**
  String get chatGroupAlias_screenImmutable;

  /// lib/features/chat/group_alias/group_alias_screen.dart:604
  ///
  /// In en, this message translates to:
  /// **'This nickname isn\'t available. Try another.'**
  String get chatGroupAlias_screenInvalidData;

  /// lib/features/chat/group_alias/group_alias_screen.dart:301
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get chatGroupAlias_screenLoopBadge;

  /// lib/features/chat/group_alias/group_alias_screen.dart:248
  ///
  /// In en, this message translates to:
  /// **'My group nickname'**
  String get chatGroupAlias_screenLoopLabel;

  /// lib/features/chat/group_alias/group_alias_screen.dart:251
  ///
  /// In en, this message translates to:
  /// **'Find member nicknames'**
  String get chatGroupAlias_screenLoopLabel2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:158
  ///
  /// In en, this message translates to:
  /// **'Group unavailable'**
  String get chatGroupAlias_screenNotFound;

  /// lib/features/chat/group_alias/group_alias_screen.dart:166
  ///
  /// In en, this message translates to:
  /// **'This channel isn\'t a visible group, or this account is no longer a member; nickname actions aren\'t available.'**
  String get chatGroupAlias_screenNotFound2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:601
  ///
  /// In en, this message translates to:
  /// **'No visible group nickname; you may no longer be a member of this Stream group.'**
  String get chatGroupAlias_screenNotFound3;

  /// lib/features/chat/group_alias/group_alias_screen.dart:598
  ///
  /// In en, this message translates to:
  /// **'Device offline. Group nicknames weren\'t loaded and nothing was submitted.'**
  String get chatGroupAlias_screenOffline;

  /// lib/features/chat/group_alias/group_alias_screen.dart:605
  ///
  /// In en, this message translates to:
  /// **'The request may have been submitted; you can only confirm with the exact same nickname.'**
  String get chatGroupAlias_screenOutcomeUnknown;

  /// lib/features/chat/group_alias/group_alias_screen.dart:587
  ///
  /// In en, this message translates to:
  /// **'Development preview · This run only'**
  String get chatGroupAlias_screenPreview;

  /// lib/features/chat/group_alias/group_alias_screen.dart:242
  ///
  /// In en, this message translates to:
  /// **'This group only'**
  String get chatGroupAlias_screenProduction;

  /// lib/features/chat/group_alias/group_alias_screen.dart:588
  ///
  /// In en, this message translates to:
  /// **'LOOP group identity boundary'**
  String get chatGroupAlias_screenProduction2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:161
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resolve group'**
  String get chatGroupAlias_screenResolved;

  /// lib/features/chat/group_alias/group_alias_screen.dart:169
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this group\'s info right now; the group nickname can\'t be changed yet.'**
  String get chatGroupAlias_screenResolved2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:157
  ///
  /// In en, this message translates to:
  /// **'Confirming group'**
  String get chatGroupAlias_screenResolving;

  /// lib/features/chat/group_alias/group_alias_screen.dart:165
  ///
  /// In en, this message translates to:
  /// **'LOOP is confirming this account is still a member of this Stream group chat.'**
  String get chatGroupAlias_screenResolving2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:301
  ///
  /// In en, this message translates to:
  /// **'Permanently reserved'**
  String get chatGroupAlias_screenS;

  /// lib/features/chat/group_alias/group_alias_screen.dart:299
  ///
  /// In en, this message translates to:
  /// **'Reserved · Syncing in group'**
  String get chatGroupAlias_screenSubtitle;

  /// lib/features/chat/group_alias/group_alias_screen.dart:299, lib/features/chat/group_alias/group_alias_screen.dart:544
  ///
  /// In en, this message translates to:
  /// **'Current group nickname'**
  String get chatGroupAlias_screenSubtitle2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:607
  ///
  /// In en, this message translates to:
  /// **'Group nicknames aren\'t available right now.'**
  String get chatGroupAlias_screenSwitch;

  /// lib/features/chat/group_alias/group_alias_screen.dart:603
  ///
  /// In en, this message translates to:
  /// **'Another member of this group has permanently reserved this nickname. Try another.'**
  String get chatGroupAlias_screenTaken;

  /// lib/features/chat/group_alias/group_alias_screen.dart:159
  ///
  /// In en, this message translates to:
  /// **'Group service unavailable right now'**
  String get chatGroupAlias_screenUnavailable;

  /// lib/features/chat/group_alias/group_alias_screen.dart:167
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm group membership right now; nickname actions aren\'t available.'**
  String get chatGroupAlias_screenUnavailable2;

  /// lib/features/chat/group_alias/group_alias_screen.dart:243
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get chatGroupAlias_screenUnavailable3;

  /// lib/features/chat/group_alias/group_alias_screen.dart:589
  ///
  /// In en, this message translates to:
  /// **'Production connection unavailable'**
  String get chatGroupAlias_screenUnavailable4;

  /// lib/features/chat/group_alias/group_alias_screen.dart:599
  ///
  /// In en, this message translates to:
  /// **'The group nickname service isn\'t available right now; no nickname is shown as reserved.'**
  String get chatGroupAlias_screenUnavailable5;

  /// lib/features/chat/group_alias/group_alias_screen.dart:606
  ///
  /// In en, this message translates to:
  /// **'The group nickname action failed; no result is shown as confirmed.'**
  String get chatGroupAlias_screenUnexpected;

  /// lib/features/chat/group_alias/group_alias_stream_message_identity.dart:1261
  ///
  /// In en, this message translates to:
  /// **'{replyCount, plural, =1{1 reply} other{{replyCount} replies}}'**
  String chatGroupAlias_streamMessageIdentityBuild(num replyCount);

  /// lib/features/chat/group_alias/group_alias_stream_message_identity.dart:670
  ///
  /// In en, this message translates to:
  /// **'No one has spoken yet'**
  String get chatGroupAlias_streamMessageIdentityLoopChannelQuietLabel;

  /// lib/features/chat/group_alias/group_alias_stream_message_identity.dart:64
  ///
  /// In en, this message translates to:
  /// **'D'**
  String
  get chatGroupAlias_streamMessageIdentityLoopDirectConversationNeutralInitial;

  /// lib/features/chat/group_alias/group_alias_stream_message_identity.dart:74
  ///
  /// In en, this message translates to:
  /// **'X'**
  String
  get chatGroupAlias_streamMessageIdentityLoopDirectDeactivatedPeerInitial;

  /// lib/features/chat/group_alias/group_alias_stream_message_identity.dart:71
  ///
  /// In en, this message translates to:
  /// **'Deleted account'**
  String get chatGroupAlias_streamMessageIdentityLoopDirectDeactivatedPeerLabel;

  /// lib/features/chat/group_alias/group_alias_stream_message_identity.dart:1212
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String chatGroupAlias_streamMessageIdentityS(num count);

  /// lib/features/chat/member_buy/loop_member_buy_card.dart:444
  ///
  /// In en, this message translates to:
  /// **'{loopMemberBuyPreviewLabel} · Incomplete data'**
  String chatMemberBuy_cardBody(Object? loopMemberBuyPreviewLabel);

  /// lib/features/chat/member_buy/loop_member_buy_card.dart:293
  ///
  /// In en, this message translates to:
  /// **'View {name}\'s profile'**
  String chatMemberBuy_cardLabel(Object? name);

  /// lib/features/chat/member_buy/loop_member_buy_card.dart:408
  ///
  /// In en, this message translates to:
  /// **'Copy transaction hash'**
  String get chatMemberBuy_cardLabel2;

  /// lib/features/chat/member_buy/loop_member_buy_card.dart:431
  ///
  /// In en, this message translates to:
  /// **'Transaction hash copied'**
  String get chatMemberBuy_cardMessage;

  /// lib/features/chat/member_buy/loop_member_buy_card.dart:338
  ///
  /// In en, this message translates to:
  /// **'Bought '**
  String get chatMemberBuy_cardText;

  /// lib/features/chat/member_buy/member_buy_event.dart:238
  ///
  /// In en, this message translates to:
  /// **'{formatDecimal} × 10,000'**
  String chatMemberBuy_eventIf(Object? formatDecimal);

  /// lib/features/chat/member_buy/member_buy_event.dart:240
  ///
  /// In en, this message translates to:
  /// **'{formatDecimal} × 100,000,000'**
  String chatMemberBuy_eventIf2(Object? formatDecimal);

  /// lib/features/chat/member_buy/member_buy_event.dart:23
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get chatMemberBuy_eventLoopMemberBuyNeutralBuyer;

  /// lib/features/chat/member_buy/member_buy_event.dart:26
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get chatMemberBuy_eventLoopMemberBuyNeutralInitial;

  /// lib/features/chat/member_buy/member_buy_event.dart:29
  ///
  /// In en, this message translates to:
  /// **'Member bought'**
  String get chatMemberBuy_eventLoopMemberBuyPreviewLabel;

  /// lib/features/chat/token_card/chat_token_card.dart:451
  ///
  /// In en, this message translates to:
  /// **'1H · Last {loopSparklineWindow} closes'**
  String chatTokenCard_cardChartRangeLabel(Object? loopSparklineWindow);

  /// lib/features/chat/token_card/chat_token_card.dart:228
  ///
  /// In en, this message translates to:
  /// **'This contract address isn\'t in the LOOP asset catalog, so there\'s no market data.'**
  String get chatTokenCard_cardDetail;

  /// lib/features/chat/token_card/chat_token_card.dart:256
  ///
  /// In en, this message translates to:
  /// **'LOOP timed out · {chatTokenShortAddress}'**
  String chatTokenCard_cardDetail2(Object? chatTokenShortAddress);

  /// lib/features/chat/token_card/chat_token_card.dart:257
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this contract · {chatTokenShortAddress}'**
  String chatTokenCard_cardDetail3(Object? chatTokenShortAddress);

  /// lib/features/chat/token_card/chat_token_card.dart:99
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Tap to retry'**
  String get chatTokenCard_cardLoopChatTokenCardFailedMessage;

  /// lib/features/chat/token_card/chat_token_card.dart:27
  ///
  /// In en, this message translates to:
  /// **'Token detected'**
  String get chatTokenCard_cardLoopChatTokenCardKicker;

  /// lib/features/chat/token_card/chat_token_card.dart:338
  ///
  /// In en, this message translates to:
  /// **'Token page'**
  String get chatTokenCard_cardLoopTokenCardAction;

  /// lib/features/chat/token_card/chat_token_card.dart:434
  ///
  /// In en, this message translates to:
  /// **'Not listed'**
  String get chatTokenCard_cardLoopTokenMetric;

  /// lib/features/chat/token_card/chat_token_card.dart:440
  ///
  /// In en, this message translates to:
  /// **'LOOP community {name} · {formatCompactFigure} members'**
  String chatTokenCard_cardMarketCommunityBound(
    Object? formatCompactFigure,
    Object? name,
  );

  /// lib/features/chat/token_card/chat_token_card.dart:443
  ///
  /// In en, this message translates to:
  /// **'No LOOP community'**
  String get chatTokenCard_cardMarketCommunityUnavailable;

  /// lib/features/chat/token_card/chat_token_card.dart:227
  ///
  /// In en, this message translates to:
  /// **'Unlisted token · {chatTokenShortAddress}'**
  String chatTokenCard_cardMessage(Object? chatTokenShortAddress);

  /// lib/features/chat/token_card/chat_token_card.dart:236
  ///
  /// In en, this message translates to:
  /// **'Device offline; contract not read'**
  String get chatTokenCard_cardMessage2;

  /// lib/features/chat/token_card/chat_token_card.dart:322
  ///
  /// In en, this message translates to:
  /// **'No quote received'**
  String get chatTokenCard_cardPriceReason;

  /// lib/features/chat/token_card/chat_token_card.dart:376
  ///
  /// In en, this message translates to:
  /// **'Catalog status · {label}'**
  String chatTokenCard_cardReadCard(Object? label);

  /// lib/features/chat/token_card/chat_token_card.dart:382
  ///
  /// In en, this message translates to:
  /// **'{riskFactCount} more contract facts on the token page'**
  String chatTokenCard_cardReadCard2(Object? riskFactCount);

  /// lib/features/chat/token_card/chat_token_card.dart:383
  ///
  /// In en, this message translates to:
  /// **'Buy and sell unavailable · {tradeReason}'**
  String chatTokenCard_cardReadCard3(Object? tradeReason);

  /// lib/features/chat/token_card/chat_token_card.dart:393
  ///
  /// In en, this message translates to:
  /// **'Identity from {factSourceLabel}'**
  String chatTokenCard_cardReadCard4(Object? factSourceLabel);

  /// lib/features/chat/token_card/chat_token_card.dart:395
  ///
  /// In en, this message translates to:
  /// **'Observed {relativeTime}'**
  String chatTokenCard_cardReadCard5(Object? relativeTime);

  /// lib/features/chat/token_card/chat_token_card.dart:397
  ///
  /// In en, this message translates to:
  /// **'Quote {factProvenance}'**
  String chatTokenCard_cardReadCard6(Object? factProvenance);

  /// lib/features/chat/token_card/chat_token_card_view.dart:58, lib/features/chat/token_card/chat_token_card_view.dart:233
  ///
  /// In en, this message translates to:
  /// **'Detecting'**
  String get chatTokenCard_viewLoading;

  /// lib/features/chat/token_card/chat_token_card_view.dart:510
  ///
  /// In en, this message translates to:
  /// **'{provenance}, view data source'**
  String chatTokenCard_viewLoopTokenCardProvenanceSemanticsLabel(
    Object? provenance,
  );

  /// lib/features/chat/token_card/chat_token_card_view.dart:60
  ///
  /// In en, this message translates to:
  /// **'Data missing'**
  String get chatTokenCard_viewPartial;

  /// lib/features/chat/token_card/chat_token_card_view.dart:61
  ///
  /// In en, this message translates to:
  /// **'Risk facts'**
  String get chatTokenCard_viewRisk;

  /// lib/features/chat/token_card/chat_token_card_view.dart:200
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get chatTokenCard_viewSwitch;

  /// lib/features/chat/token_card/chat_token_card_view.dart:344
  ///
  /// In en, this message translates to:
  /// **' — source {source}, observed {observedLabel}'**
  String chatTokenCard_viewText(Object? observedLabel, Object? source);

  /// lib/features/chat/v2/loop_channel_heading.dart:45
  ///
  /// In en, this message translates to:
  /// **'{memberCount, plural, =1{1 member} other{{memberCount} members}}'**
  String chatV2_channelHeadingNull(num memberCount);

  /// lib/features/chat/v2/community_chat_screen.dart:384
  ///
  /// In en, this message translates to:
  /// **'Community group chat'**
  String get chatV2_communityCommunityChatNeutralTitle;

  /// lib/features/chat/v2/community_chat_screen.dart:163
  ///
  /// In en, this message translates to:
  /// **'Community info'**
  String get chatV2_communityCommunityChatOpenProfileLabel;

  /// lib/features/chat/v2/community_chat_screen.dart:141, lib/features/chat/v2/group_screens.dart:98
  ///
  /// In en, this message translates to:
  /// **'Search this conversation'**
  String get chatV2_communityCommunityChatOpenSearchLabel;

  /// lib/features/chat/v2/community_chat_screen.dart:152
  ///
  /// In en, this message translates to:
  /// **'Join voice room'**
  String get chatV2_communityCommunityChatOpenVoiceLabel;

  /// lib/features/chat/v2/community_chat_screen.dart:436
  ///
  /// In en, this message translates to:
  /// **'Syncing your display name'**
  String get chatV2_communityCommunityChatPersonaSegment;

  /// lib/features/chat/v2/community_chat_screen.dart:456
  ///
  /// In en, this message translates to:
  /// **'{communicationUnavailableReason}LOOP has recorded your membership; the provider hasn\'t caught up yet. Retry later; you don\'t need to rejoin the community.'**
  String chatV2_communityCommunityChatSyncingBody(
    Object? communicationUnavailableReason,
  );

  /// lib/features/chat/v2/community_chat_screen.dart:474
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get chatV2_communityCommunityChatSyncingRetryLabel;

  /// lib/features/chat/v2/community_chat_screen.dart:454
  ///
  /// In en, this message translates to:
  /// **'Syncing chat access'**
  String get chatV2_communityCommunityChatSyncingTitle;

  /// lib/features/chat/v2/community_chat_screen.dart:398
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String chatV2_communityCommunityOnlineCountObserved(Object? count);

  /// lib/features/chat/v2/community_chat_screen.dart:238
  ///
  /// In en, this message translates to:
  /// **'Community not found'**
  String get chatV2_communityEmptyMessage;

  /// lib/features/chat/v2/community_chat_screen.dart:239
  ///
  /// In en, this message translates to:
  /// **'It may have been removed or isn\'t visible to this account.'**
  String get chatV2_communityEmptyReason;

  /// lib/features/chat/v2/community_chat_screen.dart:214, lib/features/chat/v2/voice_room_screens.dart:427
  ///
  /// In en, this message translates to:
  /// **'Missing community ID'**
  String get chatV2_communityMessage;

  /// lib/features/chat/v2/community_chat_screen.dart:221
  ///
  /// In en, this message translates to:
  /// **'Community chat unavailable'**
  String get chatV2_communityMessage2;

  /// lib/features/chat/v2/community_chat_screen.dart:255
  ///
  /// In en, this message translates to:
  /// **'Official group unavailable'**
  String get chatV2_communityMessage3;

  /// lib/features/chat/v2/community_chat_screen.dart:215
  ///
  /// In en, this message translates to:
  /// **'Enter from the community list or community page; this page won\'t guess which community\'s official group to open.'**
  String get chatV2_communityReason;

  /// lib/features/chat/v2/community_chat_screen.dart:223, lib/features/chat/v2/direct_message_screen.dart:155, lib/features/chat/v2/group_screens.dart:118
  ///
  /// In en, this message translates to:
  /// **'Capabilities haven\'t loaded yet; this page doesn\'t request any channel.'**
  String get chatV2_communityReason2;

  /// lib/features/chat/v2/community_chat_screen.dart:436
  ///
  /// In en, this message translates to:
  /// **'You appear as {alias} in this community'**
  String chatV2_communityS(Object? alias);

  /// lib/features/chat/v2/community_chat_screen.dart:401
  ///
  /// In en, this message translates to:
  /// **'{communityCountLabel} members'**
  String chatV2_communitySwitch(Object? communityCountLabel);

  /// lib/features/chat/v2/chat_conversation_label.dart:8, lib/features/chat/v2/chat_search_screen.dart:236, lib/features/chat/v2/community_chat_screen.dart:310
  ///
  /// In en, this message translates to:
  /// **'Community official group'**
  String get chatV2_conversationLabelLoopCommunityConversationNeutralLabel;

  /// lib/features/chat/v2/chat_conversation_label.dart:59
  ///
  /// In en, this message translates to:
  /// **'{memberCount, plural, =1{1 member} other{{memberCount} members}}'**
  String chatV2_conversationLabelNull(num memberCount);

  /// lib/features/chat/v2/direct_message_screen.dart:51
  ///
  /// In en, this message translates to:
  /// **'Direct messages show minimal identity by default; asset and signature requests are labelled separately.'**
  String get chatV2_directMessageCaption;

  /// lib/features/chat/v2/direct_message_screen.dart:340
  ///
  /// In en, this message translates to:
  /// **'Message request sent. The conversation appears here once they accept.'**
  String get chatV2_directMessageDmFriendshipRequiredMessage;

  /// lib/features/chat/v2/direct_message_screen.dart:345
  ///
  /// In en, this message translates to:
  /// **'Direct messages need both of you to be friends, and the other person mustn\'t have turned off direct messages in Privacy Center. Send a message request first; the conversation opens once they accept. This doesn\'t mean the account exists.'**
  String get chatV2_directMessageDmFriendshipRequiredMessage2;

  /// lib/features/chat/v2/direct_message_screen.dart:338
  ///
  /// In en, this message translates to:
  /// **'Can\'t message directly yet'**
  String get chatV2_directMessageDmFriendshipRequiredTitle;

  /// lib/features/chat/v2/direct_message_screen.dart:359
  ///
  /// In en, this message translates to:
  /// **'Message request not sent'**
  String get chatV2_directMessageDmMessageRequestFailedTitle;

  /// lib/features/chat/v2/direct_message_screen.dart:191
  ///
  /// In en, this message translates to:
  /// **'This request was received and needs manual handling to finish. There\'s no retry here: resubmitting opens a second action. Contact support, then come back to this conversation.'**
  String get chatV2_directMessageDmOperatorRequiredDetail;

  /// lib/features/chat/v2/direct_message_screen.dart:189
  ///
  /// In en, this message translates to:
  /// **'Needs manual handling'**
  String get chatV2_directMessageDmOperatorRequiredMessage;

  /// lib/features/chat/v2/direct_message_screen.dart:201
  ///
  /// In en, this message translates to:
  /// **'This request is recorded. Sending it again won\'t be faster; it only adds another pending record.'**
  String get chatV2_directMessageDmOperatorRequiredNoticeBody;

  /// lib/features/chat/v2/direct_message_screen.dart:200
  ///
  /// In en, this message translates to:
  /// **'Don\'t resubmit'**
  String get chatV2_directMessageDmOperatorRequiredNoticeTitle;

  /// lib/features/chat/v2/direct_message_screen.dart:378
  ///
  /// In en, this message translates to:
  /// **'Send message request'**
  String get chatV2_directMessageDmSendMessageRequestLabel;

  /// lib/features/chat/v2/direct_message_screen.dart:378
  ///
  /// In en, this message translates to:
  /// **'Resend message request'**
  String get chatV2_directMessageDmSendMessageRequestLabel2;

  /// lib/features/chat/v2/direct_message_screen.dart:219
  ///
  /// In en, this message translates to:
  /// **'This direct message isn\'t open yet'**
  String get chatV2_directMessageEmptyMessage;

  /// lib/features/chat/v2/direct_message_screen.dart:220
  ///
  /// In en, this message translates to:
  /// **'This conversation can\'t be opened right now.'**
  String get chatV2_directMessageEmptyReason;

  /// lib/features/chat/v2/direct_message_screen.dart:50
  ///
  /// In en, this message translates to:
  /// **'One-on-one direct message'**
  String get chatV2_directMessageHeading;

  /// lib/features/chat/v2/direct_message_screen.dart:50
  ///
  /// In en, this message translates to:
  /// **'Direct message with {displayName}'**
  String chatV2_directMessageHeading2(Object? displayName);

  /// lib/features/chat/v2/direct_message_screen.dart:153
  ///
  /// In en, this message translates to:
  /// **'Direct messages unavailable'**
  String get chatV2_directMessageMessage;

  /// lib/features/chat/v2/direct_message_screen.dart:162
  ///
  /// In en, this message translates to:
  /// **'Missing conversation ID'**
  String get chatV2_directMessageMessage2;

  /// lib/features/chat/v2/direct_message_screen.dart:279
  ///
  /// In en, this message translates to:
  /// **'Message request sent'**
  String get chatV2_directMessageMessage3;

  /// lib/features/chat/v2/direct_message_screen.dart:302
  ///
  /// In en, this message translates to:
  /// **'They aren\'t discoverable, or this account doesn\'t exist. The message request wasn\'t sent.'**
  String get chatV2_directMessageNotFound;

  /// lib/features/chat/v2/direct_message_screen.dart:163
  ///
  /// In en, this message translates to:
  /// **'Enter from Following, Message requests or a public profile; this page won\'t guess whose direct message to open.'**
  String get chatV2_directMessageReason;

  /// lib/features/chat/v2/direct_message_screen.dart:52, lib/features/chat/v2/group_screens.dart:335
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get chatV2_directMessageStamp;

  /// lib/features/chat/v2/chat_forward_screens.dart:689
  ///
  /// In en, this message translates to:
  /// **'Selected messages are sent as new messages labelled with their source conversation. Deleted or empty messages are skipped.'**
  String get chatV2_forwardScreensBody;

  /// lib/features/chat/v2/chat_forward_screens.dart:522
  ///
  /// In en, this message translates to:
  /// **'Forward up to {chatForwardSelectionLimit} messages at a time, only to conversations you\'ve joined. Deleted or empty messages are skipped and counted.'**
  String chatV2_forwardScreensCaption(Object? chatForwardSelectionLimit);

  /// lib/features/chat/v2/chat_forward_screens.dart:762
  ///
  /// In en, this message translates to:
  /// **'The merged preview only shows \"{chatMergeAnonymousLabel}\", time and text, with no nickname, LOOP ID or wallet address.'**
  String chatV2_forwardScreensCaption2(Object? chatMergeAnonymousLabel);

  /// lib/features/chat/v2/chat_forward_screens.dart:554
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this conversation\'s messages and targets; nothing was forwarded.'**
  String get chatV2_forwardScreensChatForwardErrorReason;

  /// lib/features/chat/v2/chat_forward_screens.dart:531
  ///
  /// In en, this message translates to:
  /// **'Enter Forward from a conversation; this page won\'t guess which conversation to forward from.'**
  String get chatV2_forwardScreensChatForwardMissingSourceDetail;

  /// lib/features/chat/v2/chat_forward_screens.dart:530
  ///
  /// In en, this message translates to:
  /// **'Source conversation not found'**
  String get chatV2_forwardScreensChatForwardMissingSourceMessage;

  /// lib/features/chat/v2/chat_forward_screens.dart:568
  ///
  /// In en, this message translates to:
  /// **'Only text messages synced to this device can be forwarded.'**
  String get chatV2_forwardScreensChatForwardNoMessagesMessage;

  /// lib/features/chat/v2/chat_forward_screens.dart:567
  ///
  /// In en, this message translates to:
  /// **'No messages to forward in this conversation'**
  String get chatV2_forwardScreensChatForwardNoMessagesTitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:587, lib/features/chat/v2/forward_target_sheet.dart:279
  ///
  /// In en, this message translates to:
  /// **'Forward targets must be conversations you\'ve joined.'**
  String get chatV2_forwardScreensChatForwardNoTargetsMessage;

  /// lib/features/chat/v2/chat_forward_screens.dart:586, lib/features/chat/v2/forward_target_sheet.dart:278
  ///
  /// In en, this message translates to:
  /// **'No target conversations'**
  String get chatV2_forwardScreensChatForwardNoTargetsTitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:606
  ///
  /// In en, this message translates to:
  /// **'Preview merged image'**
  String get chatV2_forwardScreensChatForwardOpenMergeLabel;

  /// lib/features/chat/v2/chat_forward_screens.dart:507
  ///
  /// In en, this message translates to:
  /// **'{selectedCount} selected · Choose a conversation'**
  String chatV2_forwardScreensChatForwardScreenSubtitle(Object? selectedCount);

  /// lib/features/chat/v2/chat_forward_screens.dart:502
  ///
  /// In en, this message translates to:
  /// **'Forward messages'**
  String get chatV2_forwardScreensChatForwardScreenTitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:41, lib/features/chat/v2/chat_v2_models.dart:671
  ///
  /// In en, this message translates to:
  /// **'Anonymous member'**
  String get chatV2_forwardScreensChatMergeAnonymousLabel;

  /// lib/features/chat/v2/chat_forward_screens.dart:803
  ///
  /// In en, this message translates to:
  /// **'Back to chat'**
  String get chatV2_forwardScreensChatMergeBackLabel;

  /// lib/features/chat/v2/chat_forward_screens.dart:781
  ///
  /// In en, this message translates to:
  /// **'Go back to Forward and pick up to {chatMergeSelectionLimit} messages to merge.'**
  String chatV2_forwardScreensChatMergeEmptyMessage(
    Object? chatMergeSelectionLimit,
  );

  /// lib/features/chat/v2/chat_forward_screens.dart:780
  ///
  /// In en, this message translates to:
  /// **'No messages selected'**
  String get chatV2_forwardScreensChatMergeEmptyTitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:808
  ///
  /// In en, this message translates to:
  /// **'Create image'**
  String get chatV2_forwardScreensChatMergeExportLabel;

  /// lib/features/chat/v2/chat_forward_screens.dart:745
  ///
  /// In en, this message translates to:
  /// **'Show sender usernames'**
  String get chatV2_forwardScreensChatMergePreviewScreenSubtitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:745, lib/features/chat/v2/chat_forward_screens.dart:759
  ///
  /// In en, this message translates to:
  /// **'Anonymous by default'**
  String get chatV2_forwardScreensChatMergePreviewScreenSubtitle2;

  /// lib/features/chat/v2/chat_forward_screens.dart:742
  ///
  /// In en, this message translates to:
  /// **'Merged image preview'**
  String get chatV2_forwardScreensChatMergePreviewScreenTitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:791
  ///
  /// In en, this message translates to:
  /// **'Merge up to {chatMergeSelectionLimit} messages at a time; the rest won\'t appear in the preview.'**
  String chatV2_forwardScreensChatMergeTruncatedBody(
    Object? chatMergeSelectionLimit,
  );

  /// lib/features/chat/v2/chat_forward_screens.dart:790
  ///
  /// In en, this message translates to:
  /// **'Truncated'**
  String get chatV2_forwardScreensChatMergeTruncatedTitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:909
  ///
  /// In en, this message translates to:
  /// **'Selected conversation'**
  String get chatV2_forwardScreensEncode;

  /// lib/features/chat/v2/chat_forward_screens.dart:916
  ///
  /// In en, this message translates to:
  /// **'Community signal summary'**
  String get chatV2_forwardScreensEncode2;

  /// lib/features/chat/v2/chat_forward_screens.dart:760
  ///
  /// In en, this message translates to:
  /// **'0 items'**
  String get chatV2_forwardScreensHeading;

  /// lib/features/chat/v2/chat_forward_screens.dart:516
  ///
  /// In en, this message translates to:
  /// **'Selected messages'**
  String get chatV2_forwardScreensKicker;

  /// lib/features/chat/v2/chat_forward_screens.dart:630
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get chatV2_forwardScreensLoopBadge;

  /// lib/features/chat/v2/chat_forward_screens.dart:518
  ///
  /// In en, this message translates to:
  /// **'{source} · {count}'**
  String chatV2_forwardScreensLoopFolioPrimary(Object? count, Object? source);

  /// lib/features/chat/v2/chat_forward_screens.dart:519
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String chatV2_forwardScreensLoopFolioPrimary2(Object? count);

  /// lib/features/chat/v2/chat_forward_screens.dart:562
  ///
  /// In en, this message translates to:
  /// **'Select messages'**
  String get chatV2_forwardScreensLoopLabel;

  /// lib/features/chat/v2/chat_forward_screens.dart:581
  ///
  /// In en, this message translates to:
  /// **'Send to · Last {chatForwardTargetPageSize} conversations'**
  String chatV2_forwardScreensLoopLabel2(Object? chatForwardTargetPageSize);

  /// lib/features/chat/v2/chat_forward_screens.dart:544
  ///
  /// In en, this message translates to:
  /// **'Load messages'**
  String get chatV2_forwardScreensLoopOfflineState;

  /// lib/features/chat/v2/chat_forward_screens.dart:544
  ///
  /// In en, this message translates to:
  /// **'Choose target'**
  String get chatV2_forwardScreensLoopOfflineState2;

  /// lib/features/chat/v2/chat_forward_screens.dart:544, lib/features/chat/v2/chat_forward_screens.dart:690, lib/features/chat/v2/forward_target_sheet.dart:258, lib/features/chat/v2/loop_message_selection.dart:341, lib/features/chat/v2/loop_stream_channel_surface.dart:146, lib/features/chat/v2/loop_stream_channel_surface.dart:477
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatV2_forwardScreensLoopOfflineState3;

  /// lib/features/chat/v2/chat_forward_screens.dart:645
  ///
  /// In en, this message translates to:
  /// **'Select up to {chatForwardSelectionLimit} at a time'**
  String chatV2_forwardScreensMessage(Object? chatForwardSelectionLimit);

  /// lib/features/chat/v2/chat_forward_screens.dart:699, lib/features/chat/v2/forward_target_sheet.dart:137
  ///
  /// In en, this message translates to:
  /// **'Nothing forwarded'**
  String get chatV2_forwardScreensMessage2;

  /// lib/features/chat/v2/chat_forward_screens.dart:706, lib/features/chat/v2/forward_target_sheet.dart:141
  ///
  /// In en, this message translates to:
  /// **'Forwarded {sent}'**
  String chatV2_forwardScreensMessage3(Object? sent);

  /// lib/features/chat/v2/chat_forward_screens.dart:707
  ///
  /// In en, this message translates to:
  /// **'Forwarded {sent}, skipped {skipped}'**
  String chatV2_forwardScreensMessage4(Object? sent, Object? skipped);

  /// lib/features/chat/v2/chat_forward_screens.dart:909
  ///
  /// In en, this message translates to:
  /// **'{sourceLabel} · Selected conversation'**
  String chatV2_forwardScreensS(Object? sourceLabel);

  /// lib/features/chat/v2/chat_forward_screens.dart:524
  ///
  /// In en, this message translates to:
  /// **'Selected {selectedCount}'**
  String chatV2_forwardScreensStamp(Object? selectedCount);

  /// lib/features/chat/v2/chat_forward_screens.dart:764
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get chatV2_forwardScreensStamp2;

  /// lib/features/chat/v2/chat_forward_screens.dart:628
  ///
  /// In en, this message translates to:
  /// **'Deleted or empty; skipped when forwarding.'**
  String get chatV2_forwardScreensSubtitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:943
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get chatV2_forwardScreensText;

  /// lib/features/chat/v2/chat_forward_screens.dart:982
  ///
  /// In en, this message translates to:
  /// **'Wallet addresses, nicknames and internal IDs don\'t appear in the image, and the image isn\'t uploaded.'**
  String get chatV2_forwardScreensText2;

  /// lib/features/chat/v2/chat_forward_screens.dart:625
  ///
  /// In en, this message translates to:
  /// **'This message can\'t be forwarded'**
  String get chatV2_forwardScreensTitle;

  /// lib/features/chat/v2/chat_forward_screens.dart:688
  ///
  /// In en, this message translates to:
  /// **'Forward to this conversation?'**
  String get chatV2_forwardScreensTitle2;

  /// lib/features/chat/v2/forward_target_sheet.dart:105
  ///
  /// In en, this message translates to:
  /// **'Close forward'**
  String get chatV2_forwardTargetSheetBarrierLabel;

  /// lib/features/chat/v2/forward_target_sheet.dart:139
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get chatV2_forwardTargetSheetChatForwardOutcomeMessage;

  /// lib/features/chat/v2/forward_target_sheet.dart:142
  ///
  /// In en, this message translates to:
  /// **'Skipped {skipped}'**
  String chatV2_forwardTargetSheetChatForwardOutcomeMessage2(Object? skipped);

  /// lib/features/chat/v2/forward_target_sheet.dart:143
  ///
  /// In en, this message translates to:
  /// **'{unavailable} deleted or not on this device; not forwarded'**
  String chatV2_forwardTargetSheetChatForwardOutcomeMessage3(
    Object? unavailable,
  );

  /// lib/features/chat/v2/forward_target_sheet.dart:235
  ///
  /// In en, this message translates to:
  /// **'Last {chatForwardTargetPageSize} joined conversations · Forwarded messages show their source'**
  String chatV2_forwardTargetSheetContent(Object? chatForwardTargetPageSize);

  /// lib/features/chat/v2/forward_target_sheet.dart:267
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load conversations to forward to; nothing was forwarded.'**
  String get chatV2_forwardTargetSheetForwardTargetSheetErrorReason;

  /// lib/features/chat/v2/forward_target_sheet.dart:258
  ///
  /// In en, this message translates to:
  /// **'Load conversations'**
  String get chatV2_forwardTargetSheetLoopOfflineState;

  /// lib/features/chat/v2/forward_target_sheet.dart:226
  ///
  /// In en, this message translates to:
  /// **'Forward to'**
  String get chatV2_forwardTargetSheetLoopSheetHeading;

  /// lib/features/chat/v2/forward_target_sheet.dart:226
  ///
  /// In en, this message translates to:
  /// **'Forward {count} one by one to'**
  String chatV2_forwardTargetSheetS(Object? count);

  /// lib/features/chat/v2/group_screens.dart:505
  ///
  /// In en, this message translates to:
  /// **'Close group name editor'**
  String get chatV2_groupScreensBarrierLabel;

  /// lib/features/chat/v2/group_screens.dart:442
  ///
  /// In en, this message translates to:
  /// **'You won\'t get messages from this group after leaving. The group creator can\'t leave.'**
  String get chatV2_groupScreensBody;

  /// lib/features/chat/v2/group_screens.dart:334
  ///
  /// In en, this message translates to:
  /// **'Members, notifications and Leave are ordered from low to high risk. Only confirmed info is shown here.'**
  String get chatV2_groupScreensCaption;

  /// lib/features/chat/v2/group_screens.dart:567
  ///
  /// In en, this message translates to:
  /// **'Group name must be 1–40 characters with no control characters'**
  String get chatV2_groupScreensErrorText;

  /// lib/features/chat/v2/group_screens.dart:344
  ///
  /// In en, this message translates to:
  /// **'Capabilities haven\'t loaded yet; this page doesn\'t request any group resource.'**
  String get chatV2_groupScreensGroupInfoCapabilityUnavailableDetail;

  /// lib/features/chat/v2/group_screens.dart:361
  ///
  /// In en, this message translates to:
  /// **'Members and member management'**
  String get chatV2_groupScreensGroupInfoMembersUnavailableLabel;

  /// lib/features/chat/v2/group_screens.dart:353
  ///
  /// In en, this message translates to:
  /// **'Enter from a group chat; this page won\'t guess which group\'s info to open.'**
  String get chatV2_groupScreensGroupInfoMissingCidDetail;

  /// lib/features/chat/v2/group_screens.dart:489
  ///
  /// In en, this message translates to:
  /// **'Loading group name'**
  String get chatV2_groupScreensGroupInfoNameSubtitle;

  /// lib/features/chat/v2/group_screens.dart:489
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load group name'**
  String get chatV2_groupScreensGroupInfoNameSubtitle2;

  /// lib/features/chat/v2/group_screens.dart:488
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get chatV2_groupScreensGroupInfoNameTitle;

  /// lib/features/chat/v2/group_screens.dart:490
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatV2_groupScreensGroupInfoNameTrailingCaption;

  /// lib/features/chat/v2/group_screens.dart:490
  ///
  /// In en, this message translates to:
  /// **'Owner only'**
  String get chatV2_groupScreensGroupInfoNameTrailingCaption2;

  /// lib/features/chat/v2/group_screens.dart:411
  ///
  /// In en, this message translates to:
  /// **'This group\'s info isn\'t confirmed yet, so you can\'t leave; no change was submitted.'**
  String get chatV2_groupScreensGroupInfoResolveFailedReason;

  /// lib/features/chat/v2/group_screens.dart:375
  ///
  /// In en, this message translates to:
  /// **'Notifications and pinned conversation'**
  String get chatV2_groupScreensGroupInfoSettingsUnavailableLabel;

  /// lib/features/chat/v2/group_screens.dart:397
  ///
  /// In en, this message translates to:
  /// **'This group wasn\'t found, or you\'re no longer a member. This doesn\'t mean leaving failed.'**
  String get chatV2_groupScreensGroupInfoStateEmptyMessage;

  /// lib/features/chat/v2/group_screens.dart:396
  ///
  /// In en, this message translates to:
  /// **'No group membership to leave'**
  String get chatV2_groupScreensGroupInfoStateEmptyTitle;

  /// lib/features/chat/v2/group_screens.dart:404
  ///
  /// In en, this message translates to:
  /// **'The group membership service isn\'t available right now; no change was submitted.'**
  String get chatV2_groupScreensGroupInfoStateUnavailableDetail;

  /// lib/features/chat/v2/group_screens.dart:403
  ///
  /// In en, this message translates to:
  /// **'Leave isn\'t available right now'**
  String get chatV2_groupScreensGroupInfoStateUnavailableMessage;

  /// lib/features/chat/v2/group_screens.dart:104, lib/features/chat/v2/group_screens.dart:326, lib/features/chat/v2/group_screens.dart:333, lib/features/chat/v2/group_screens.dart:338
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get chatV2_groupScreensGroupOpenInfoLabel;

  /// lib/features/chat/v2/group_screens.dart:146
  ///
  /// In en, this message translates to:
  /// **'Regular groups have no community token, no Mining Weight and no Community AI. Communities with tokens are under Community.'**
  String get chatV2_groupScreensGroupScopeNoteText;

  /// lib/features/chat/v2/group_screens.dart:143
  ///
  /// In en, this message translates to:
  /// **'Groups vs. communities'**
  String get chatV2_groupScreensGroupScopeNoteTitle;

  /// lib/features/chat/v2/group_screens.dart:332, lib/features/chat/v2/group_screens.dart:364
  ///
  /// In en, this message translates to:
  /// **'Group profile'**
  String get chatV2_groupScreensKicker;

  /// lib/features/chat/v2/group_screens.dart:566
  ///
  /// In en, this message translates to:
  /// **'Group name (1–{groupNameMaximumRunes} characters)'**
  String chatV2_groupScreensLabelText(Object? groupNameMaximumRunes);

  /// lib/features/chat/v2/group_screens.dart:389, lib/features/chat/v2/group_screens.dart:424
  ///
  /// In en, this message translates to:
  /// **'Leave group chat'**
  String get chatV2_groupScreensLoopOfflineState;

  /// lib/features/chat/v2/group_screens.dart:545
  ///
  /// In en, this message translates to:
  /// **'Edit group name'**
  String get chatV2_groupScreensLoopSheetHeading;

  /// lib/features/chat/v2/group_screens.dart:116, lib/features/chat/v2/group_screens.dart:342
  ///
  /// In en, this message translates to:
  /// **'Group chat unavailable'**
  String get chatV2_groupScreensMessage;

  /// lib/features/chat/v2/group_screens.dart:123, lib/features/chat/v2/group_screens.dart:352
  ///
  /// In en, this message translates to:
  /// **'Missing group chat ID'**
  String get chatV2_groupScreensMessage2;

  /// lib/features/chat/v2/group_screens.dart:255
  ///
  /// In en, this message translates to:
  /// **'Group name changed to \"{name}\"'**
  String chatV2_groupScreensMessage3(Object? name);

  /// lib/features/chat/v2/group_screens.dart:452
  ///
  /// In en, this message translates to:
  /// **'Left group chat'**
  String get chatV2_groupScreensMessage4;

  /// lib/features/chat/v2/group_screens.dart:263
  ///
  /// In en, this message translates to:
  /// **'The group doesn\'t exist or you\'re no longer in it.'**
  String get chatV2_groupScreensNotFound;

  /// lib/features/chat/v2/group_screens.dart:261
  ///
  /// In en, this message translates to:
  /// **'Only the group owner can change the group name; nothing was changed.'**
  String get chatV2_groupScreensPermissionDenied;

  /// lib/features/chat/v2/group_screens.dart:124
  ///
  /// In en, this message translates to:
  /// **'Enter from the conversation list or group info; this page won\'t guess which group to open.'**
  String get chatV2_groupScreensReason;

  /// lib/features/chat/v2/group_screens.dart:441
  ///
  /// In en, this message translates to:
  /// **'Leave this group chat?'**
  String get chatV2_groupScreensTitle;

  /// lib/features/chat/v2/group_screens.dart:262
  ///
  /// In en, this message translates to:
  /// **'Renaming isn\'t available right now; the group name wasn\'t changed.'**
  String get chatV2_groupScreensUnavailable;

  /// lib/features/chat/v2/group_screens.dart:264
  ///
  /// In en, this message translates to:
  /// **'Group name must be 1–40 characters with no control characters.'**
  String get chatV2_groupScreensValidationFailed;

  /// lib/features/chat/v2/chat_merge_export.dart:52
  ///
  /// In en, this message translates to:
  /// **'Image created, but no share destination was chosen'**
  String get chatV2_mergeExportDismissed;

  /// lib/features/chat/v2/chat_merge_export.dart:53
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the image; nothing left this device'**
  String get chatV2_mergeExportFailed;

  /// lib/features/chat/v2/chat_merge_export.dart:51
  ///
  /// In en, this message translates to:
  /// **'Image created. Choose where to share it'**
  String get chatV2_mergeExportShared;

  /// lib/features/chat/v2/chat_merge_export.dart:54
  ///
  /// In en, this message translates to:
  /// **'System sharing isn\'t available in this run; no image was created'**
  String get chatV2_mergeExportUnavailable;

  /// lib/features/chat/v2/loop_message_selection.dart:464
  ///
  /// In en, this message translates to:
  /// **'Everyone in the conversation will see \"Message deleted\". This can\'t be undone.'**
  String get chatV2_messageSelectionBody;

  /// lib/features/chat/v2/loop_message_selection.dart:257
  ///
  /// In en, this message translates to:
  /// **'Message selected'**
  String get chatV2_messageSelectionLabel;

  /// lib/features/chat/v2/loop_message_selection.dart:257
  ///
  /// In en, this message translates to:
  /// **'Select this message'**
  String get chatV2_messageSelectionLabel2;

  /// lib/features/chat/v2/loop_message_selection.dart:365
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get chatV2_messageSelectionLoopMessageForwardActions;

  /// lib/features/chat/v2/loop_message_selection.dart:523
  ///
  /// In en, this message translates to:
  /// **'Forward one by one'**
  String get chatV2_messageSelectionLoopSelectionForwardEachLabel;

  /// lib/features/chat/v2/loop_message_selection.dart:534
  ///
  /// In en, this message translates to:
  /// **'Forward as one'**
  String get chatV2_messageSelectionLoopSelectionMergeLabel;

  /// lib/features/chat/v2/loop_message_selection.dart:200
  ///
  /// In en, this message translates to:
  /// **'Up to {loopMessageSelectionLimit}'**
  String chatV2_messageSelectionLoopSelectionTopbarSubtitle(
    Object? loopMessageSelectionLimit,
  );

  /// lib/features/chat/v2/loop_message_selection.dart:199
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String chatV2_messageSelectionLoopSelectionTopbarTitle(Object? count);

  /// lib/features/chat/v2/loop_message_selection.dart:266
  ///
  /// In en, this message translates to:
  /// **'Select up to {loopMessageSelectionLimit} at a time'**
  String chatV2_messageSelectionMessage(Object? loopMessageSelectionLimit);

  /// lib/features/chat/v2/loop_message_selection.dart:439
  ///
  /// In en, this message translates to:
  /// **'{unavailable} deleted or not on this device; left out of the image'**
  String chatV2_messageSelectionMessage2(Object? unavailable);

  /// lib/features/chat/v2/loop_message_selection.dart:488
  ///
  /// In en, this message translates to:
  /// **'Deleted {deleted}'**
  String chatV2_messageSelectionShow(Object? deleted);

  /// lib/features/chat/v2/loop_message_selection.dart:489
  ///
  /// In en, this message translates to:
  /// **'{failed} couldn\'t be deleted'**
  String chatV2_messageSelectionShow2(Object? failed);

  /// lib/features/chat/v2/loop_message_selection.dart:490
  ///
  /// In en, this message translates to:
  /// **'{unavailable} no longer on this device; skipped'**
  String chatV2_messageSelectionShow3(Object? unavailable);

  /// lib/features/chat/v2/loop_message_selection.dart:463
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete this message?} other{Delete these {count} messages?}}'**
  String chatV2_messageSelectionTitle(num count);

  /// lib/features/chat/v2/chat_v2_models.dart:162, lib/features/chat/v2/voice_room_screens.dart:924, lib/features/chat/v2/voice_room_screens.dart:1029, lib/features/chat/v2/voice_room_screens.dart:1048, lib/features/chat/v2/voice_room_stage.dart:188, lib/features/chat/v2/voice_room_stage.dart:195
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get chatV2_modelsHost;

  /// lib/features/chat/v2/chat_v2_models.dart:453, lib/features/chat/v2/voice_room_screens.dart:1572
  ///
  /// In en, this message translates to:
  /// **'Invite to speak'**
  String get chatV2_modelsInviteSpeaker;

  /// lib/features/chat/v2/chat_v2_models.dart:164, lib/features/chat/v2/chat_v2_models.dart:354
  ///
  /// In en, this message translates to:
  /// **'Listener'**
  String get chatV2_modelsListener;

  /// lib/features/chat/v2/chat_v2_models.dart:454, lib/features/chat/v2/voice_room_screens.dart:1572
  ///
  /// In en, this message translates to:
  /// **'Remove from stage'**
  String get chatV2_modelsRemoveSpeaker;

  /// lib/features/chat/v2/chat_v2_models.dart:163, lib/features/chat/v2/chat_v2_models.dart:353
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get chatV2_modelsSpeaker;

  /// lib/features/chat/v2/chat_v2_models.dart:673
  ///
  /// In en, this message translates to:
  /// **'Only members with anonymous mode on show as anonymous; discoverability doesn\'t affect this row.'**
  String get chatV2_modelsSwitch;

  /// lib/features/chat/v2/chat_v2_models.dart:696
  ///
  /// In en, this message translates to:
  /// **'The voice room is still being verified; this page won\'t start any voice connection until it passes.'**
  String get chatV2_modelsSwitch10;

  /// lib/features/chat/v2/chat_v2_models.dart:698
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the online count, so no number is shown.'**
  String get chatV2_modelsSwitch11;

  /// lib/features/chat/v2/chat_v2_models.dart:702
  ///
  /// In en, this message translates to:
  /// **'Listening isn\'t open in this room yet. Refresh, or ask the host to reopen it.'**
  String get chatV2_modelsSwitch12;

  /// lib/features/chat/v2/chat_v2_models.dart:704
  ///
  /// In en, this message translates to:
  /// **'This room hasn\'t confirmed listening is open, so you may not hear anything. Refresh, or ask the host to reopen it.'**
  String get chatV2_modelsSwitch13;

  /// lib/features/chat/v2/chat_v2_models.dart:707
  ///
  /// In en, this message translates to:
  /// **'This voice room isn\'t set up on the provider yet, so you can\'t join.'**
  String get chatV2_modelsSwitch14;

  /// lib/features/chat/v2/chat_v2_models.dart:709
  ///
  /// In en, this message translates to:
  /// **'Your raised hand is recorded; the host may see it a bit later.'**
  String get chatV2_modelsSwitch15;

  /// lib/features/chat/v2/chat_v2_models.dart:710
  ///
  /// In en, this message translates to:
  /// **'The provider hasn\'t confirmed this mute yet.'**
  String get chatV2_modelsSwitch16;

  /// lib/features/chat/v2/chat_v2_models.dart:711
  ///
  /// In en, this message translates to:
  /// **'Community AI isn\'t available yet, so this page is unavailable.'**
  String get chatV2_modelsSwitch17;

  /// lib/features/chat/v2/chat_v2_models.dart:685
  ///
  /// In en, this message translates to:
  /// **'This community doesn\'t have an official group channel yet.'**
  String get chatV2_modelsSwitch2;

  /// lib/features/chat/v2/chat_v2_models.dart:686
  ///
  /// In en, this message translates to:
  /// **'Your channel membership is syncing; you can join shortly.'**
  String get chatV2_modelsSwitch3;

  /// lib/features/chat/v2/chat_v2_models.dart:688
  ///
  /// In en, this message translates to:
  /// **'The official group hit the provider\'s member limit, so you can\'t join right now. Your LOOP community membership isn\'t affected.'**
  String get chatV2_modelsSwitch4;

  /// lib/features/chat/v2/chat_v2_models.dart:689
  ///
  /// In en, this message translates to:
  /// **'The official group failed to create or sync and needs ops to fix it before you can join.'**
  String get chatV2_modelsSwitch5;

  /// lib/features/chat/v2/chat_v2_models.dart:690
  ///
  /// In en, this message translates to:
  /// **'Join this community first to enter its official group.'**
  String get chatV2_modelsSwitch6;

  /// lib/features/chat/v2/chat_v2_models.dart:691, lib/features/chat/v2/chat_v2_models.dart:693
  ///
  /// In en, this message translates to:
  /// **'Chat isn\'t available right now. Try again later.'**
  String get chatV2_modelsSwitch7;

  /// lib/features/chat/v2/chat_v2_models.dart:692
  ///
  /// In en, this message translates to:
  /// **'No live voice room in this community right now.'**
  String get chatV2_modelsSwitch8;

  /// lib/features/chat/v2/chat_v2_models.dart:694
  ///
  /// In en, this message translates to:
  /// **'Chat isn\'t available in this environment yet.'**
  String get chatV2_modelsSwitch9;

  /// lib/features/chat/v2/chat_v2_models.dart:457
  ///
  /// In en, this message translates to:
  /// **'Unmute me'**
  String get chatV2_modelsUnmuteSelf;

  /// lib/features/chat/v2/chat_search_screen.dart:531
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or a wider scope.'**
  String get chatV2_searchChatSearchEmptyMessage;

  /// lib/features/chat/v2/chat_search_screen.dart:530
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get chatV2_searchChatSearchEmptyTitle;

  /// lib/features/chat/v2/chat_search_screen.dart:509
  ///
  /// In en, this message translates to:
  /// **'This search didn\'t finish; no results are shown.'**
  String get chatV2_searchChatSearchErrorReason;

  /// lib/features/chat/v2/chat_search_screen.dart:520
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters. Results only come from conversations you\'ve joined.'**
  String get chatV2_searchChatSearchIdleMessage;

  /// lib/features/chat/v2/chat_search_screen.dart:519
  ///
  /// In en, this message translates to:
  /// **'Enter a keyword to search'**
  String get chatV2_searchChatSearchIdleTitle;

  /// lib/features/chat/v2/chat_search_screen.dart:481
  ///
  /// In en, this message translates to:
  /// **'Chat search isn\'t available right now; this page made no request.'**
  String get chatV2_searchChatSearchNotConnectedDetail;

  /// lib/features/chat/v2/chat_search_screen.dart:480
  ///
  /// In en, this message translates to:
  /// **'Chat search unavailable'**
  String get chatV2_searchChatSearchNotConnectedMessage;

  /// lib/features/chat/v2/chat_search_screen.dart:448
  ///
  /// In en, this message translates to:
  /// **'{label} · Not searched yet'**
  String chatV2_searchChatSearchScreenSubtitle(Object? label);

  /// lib/features/chat/v2/chat_search_screen.dart:449
  ///
  /// In en, this message translates to:
  /// **'{label} · {hits, plural, =1{1 result} other{{hits} results}}'**
  String chatV2_searchChatSearchScreenSubtitle2(num hits, Object? label);

  /// lib/features/chat/v2/chat_search_screen.dart:397, lib/features/chat/v2/chat_search_screen.dart:416
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatV2_searchChatSearchScreenTitle;

  /// lib/features/chat/v2/chat_search_screen.dart:28
  ///
  /// In en, this message translates to:
  /// **'This conversation'**
  String get chatV2_searchCurrentConversation;

  /// lib/features/chat/v2/chat_search_screen.dart:500
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatV2_searchLoopOfflineState;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:927
  ///
  /// In en, this message translates to:
  /// **'Pinned notice'**
  String get chatV2_streamChannelSurfaceLoopChannelPinnedUnavailableTitle;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:47
  ///
  /// In en, this message translates to:
  /// **'Type or paste CA'**
  String get chatV2_streamChannelSurfaceLoopChatComposerHint;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:143, lib/features/chat/v2/loop_stream_channel_surface.dart:477
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get chatV2_streamChannelSurfaceLoopStreamChannelStateBlock;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:144, lib/features/chat/v2/loop_stream_channel_surface.dart:477
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatV2_streamChannelSurfaceLoopStreamChannelStateBlock2;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:122
  ///
  /// In en, this message translates to:
  /// **'This conversation link isn\'t a channel address LOOP supports; no connection was made.'**
  String get chatV2_streamChannelSurfaceMessage;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:133
  ///
  /// In en, this message translates to:
  /// **'Restoring chat session…'**
  String get chatV2_streamChannelSurfaceMessage2;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:148
  ///
  /// In en, this message translates to:
  /// **'Device offline. Chat authorization wasn\'t restored and no message was sent.'**
  String get chatV2_streamChannelSurfaceMessage3;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:154
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore chat authorization; no message action was taken.'**
  String get chatV2_streamChannelSurfaceMessage4;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:451
  ///
  /// In en, this message translates to:
  /// **'Confirming this channel and your membership…'**
  String get chatV2_streamChannelSurfaceMessage5;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:478, lib/features/chat/v2/loop_stream_channel_surface.dart:816
  ///
  /// In en, this message translates to:
  /// **'Device offline. Channel membership wasn\'t confirmed and no message was sent.'**
  String get chatV2_streamChannelSurfaceMessage6;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:884
  ///
  /// In en, this message translates to:
  /// **'Conversation unavailable'**
  String get chatV2_streamChannelSurfaceMessage7;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:812
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the chat service. Check your network and retry.'**
  String get chatV2_streamChannelSurfaceNotConnected;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:65
  ///
  /// In en, this message translates to:
  /// **'This conversation can\'t be opened right now. Try again later.'**
  String get chatV2_streamChannelSurfaceNotConnectedMessage;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:813
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this channel\'s conversation. Try again later.'**
  String get chatV2_streamChannelSurfaceNotOpened;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:809
  ///
  /// In en, this message translates to:
  /// **'You\'re not a member of this group yet; LOOP didn\'t open any conversation.'**
  String get chatV2_streamChannelSurfaceRefused;

  /// lib/features/chat/v2/loop_stream_channel_surface.dart:815
  ///
  /// In en, this message translates to:
  /// **'This channel hasn\'t synced to your account yet; LOOP didn\'t open any conversation.'**
  String get chatV2_streamChannelSurfaceSwitch;

  /// lib/features/chat/v2/voice_room_screens.dart:1945
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get chatV2_voiceRoomQueueInvited;

  /// lib/features/chat/v2/voice_room_screens.dart:1945
  ///
  /// In en, this message translates to:
  /// **'Waiting for invite'**
  String get chatV2_voiceRoomQueueWaiting;

  /// lib/features/chat/v2/voice_room_screens.dart:1639
  ///
  /// In en, this message translates to:
  /// **'Listeners {count}'**
  String chatV2_voiceRoomRosterListenersCount(Object? count);

  /// lib/features/chat/v2/voice_room_screens.dart:1656
  ///
  /// In en, this message translates to:
  /// **'No listeners right now'**
  String get chatV2_voiceRoomRosterListenersEmpty;

  /// lib/features/chat/v2/voice_room_screens.dart:1639
  ///
  /// In en, this message translates to:
  /// **'Speakers {count}'**
  String chatV2_voiceRoomRosterSpeakersCount(Object? count);

  /// lib/features/chat/v2/voice_room_screens.dart:1656
  ///
  /// In en, this message translates to:
  /// **'No speakers right now'**
  String get chatV2_voiceRoomRosterSpeakersEmpty;

  /// lib/features/chat/v2/voice_room_screens.dart:1119
  ///
  /// In en, this message translates to:
  /// **'Leaving exits this call and cancels your raised hand; to keep listening you\'ll need to rejoin.'**
  String get chatV2_voiceRoomScreensBody;

  /// lib/features/chat/v2/voice_room_screens.dart:1264
  ///
  /// In en, this message translates to:
  /// **'Ending disconnects everyone in the room right away; the room can\'t be entered again and the hand-raise queue is discarded. Hosts don\'t have Leave: the host decides whether the room continues. To step away from this page, use Back; the room collapses to the top and you can return anytime. The community can start a new one.'**
  String get chatV2_voiceRoomScreensBody2;

  /// lib/features/chat/v2/voice_room_screens.dart:1735
  ///
  /// In en, this message translates to:
  /// **'The server sends the actions available for each row; only the ones you can actually use are listed.'**
  String get chatV2_voiceRoomScreensChooseVoiceRoomMemberCommand;

  /// lib/features/chat/v2/voice_room_screens.dart:1120, lib/features/chat/v2/voice_room_screens.dart:2069, lib/features/chat/v2/voice_room_screens.dart:2342, lib/features/chat/v2/voice_room_stage.dart:820, lib/features/chat/v2/voice_room_stage.dart:844
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get chatV2_voiceRoomScreensConfirmLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:1268, lib/features/chat/v2/voice_room_screens.dart:2028, lib/features/chat/v2/voice_room_stage.dart:804
  ///
  /// In en, this message translates to:
  /// **'End room'**
  String get chatV2_voiceRoomScreensConfirmLabel2;

  /// lib/features/chat/v2/voice_room_screens.dart:2142
  ///
  /// In en, this message translates to:
  /// **'{part} · Connecting voice'**
  String chatV2_voiceRoomScreensConnecting(Object? part);

  /// lib/features/chat/v2/voice_room_screens.dart:461, lib/features/chat/v2/voice_room_screens.dart:653
  ///
  /// In en, this message translates to:
  /// **'No voice connection is started here. Refresh, or ask the host to reopen it.'**
  String get chatV2_voiceRoomScreensDetail;

  /// lib/features/chat/v2/voice_room_screens.dart:2144
  ///
  /// In en, this message translates to:
  /// **'{part} · Voice disconnected'**
  String chatV2_voiceRoomScreensDisconnected(Object? part);

  /// lib/features/chat/v2/voice_room_screens.dart:2596
  ///
  /// In en, this message translates to:
  /// **'No voice room right now'**
  String get chatV2_voiceRoomScreensEmpty;

  /// lib/features/chat/v2/voice_room_screens.dart:2613
  ///
  /// In en, this message translates to:
  /// **'This community has no live voice room right now.'**
  String get chatV2_voiceRoomScreensEmpty2;

  /// lib/features/chat/v2/voice_room_screens.dart:436
  ///
  /// In en, this message translates to:
  /// **'No live voice room right now'**
  String get chatV2_voiceRoomScreensEmptyMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:1205
  ///
  /// In en, this message translates to:
  /// **'Target: {name}. Once invited, they become a speaker and can talk in this call.'**
  String chatV2_voiceRoomScreensInviteSpeaker(Object? name);

  /// lib/features/chat/v2/voice_room_screens.dart:378
  ///
  /// In en, this message translates to:
  /// **'Voice live'**
  String get chatV2_voiceRoomScreensKicker;

  /// lib/features/chat/v2/voice_room_screens.dart:378
  ///
  /// In en, this message translates to:
  /// **'Voice lobby'**
  String get chatV2_voiceRoomScreensKicker2;

  /// lib/features/chat/v2/voice_room_screens.dart:2061, lib/features/chat/v2/voice_room_stage.dart:830
  ///
  /// In en, this message translates to:
  /// **'Lower hand'**
  String get chatV2_voiceRoomScreensLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:2061, lib/features/chat/v2/voice_room_stage.dart:838
  ///
  /// In en, this message translates to:
  /// **'Raise hand'**
  String get chatV2_voiceRoomScreensLabel2;

  /// lib/features/chat/v2/voice_room_screens.dart:2595
  ///
  /// In en, this message translates to:
  /// **'Loading voice room'**
  String get chatV2_voiceRoomScreensLoading;

  /// lib/features/chat/v2/voice_room_screens.dart:2612
  ///
  /// In en, this message translates to:
  /// **'Loading this community\'s voice room.'**
  String get chatV2_voiceRoomScreensLoading2;

  /// lib/features/chat/v2/voice_room_screens.dart:1050
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get chatV2_voiceRoomScreensLoopBadge;

  /// lib/features/chat/v2/voice_room_screens.dart:1678, lib/features/chat/v2/voice_room_stage.dart:295
  ///
  /// In en, this message translates to:
  /// **'Hand raised'**
  String get chatV2_voiceRoomScreensLoopBadge2;

  /// lib/features/chat/v2/voice_room_screens.dart:533
  ///
  /// In en, this message translates to:
  /// **'Hand-raise queue {handRaises}'**
  String chatV2_voiceRoomScreensLoopLabel(Object? handRaises);

  /// lib/features/chat/v2/voice_room_screens.dart:542
  ///
  /// In en, this message translates to:
  /// **'Host controls'**
  String get chatV2_voiceRoomScreensLoopLabel2;

  /// lib/features/chat/v2/voice_room_screens.dart:694
  ///
  /// In en, this message translates to:
  /// **'Speakers {speakerCount}'**
  String chatV2_voiceRoomScreensLoopLabel3(Object? speakerCount);

  /// lib/features/chat/v2/voice_room_screens.dart:702
  ///
  /// In en, this message translates to:
  /// **'Listeners {listening}'**
  String chatV2_voiceRoomScreensLoopLabel4(Object? listening);

  /// lib/features/chat/v2/voice_room_screens.dart:784
  ///
  /// In en, this message translates to:
  /// **'Minimize voice room'**
  String get chatV2_voiceRoomScreensLoopTopbarBackLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:301
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open share'**
  String get chatV2_voiceRoomScreensMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:1566
  ///
  /// In en, this message translates to:
  /// **'LOOP has no speakers recorded for this room yet. The host isn\'t in this list.'**
  String get chatV2_voiceRoomScreensMessage10;

  /// lib/features/chat/v2/voice_room_screens.dart:1567
  ///
  /// In en, this message translates to:
  /// **'LOOP has no listeners recorded for this room yet. The host isn\'t in this list.'**
  String get chatV2_voiceRoomScreensMessage11;

  /// lib/features/chat/v2/voice_room_screens.dart:456, lib/features/chat/v2/voice_room_screens.dart:651
  ///
  /// In en, this message translates to:
  /// **'Listening isn\'t open in this room yet'**
  String get chatV2_voiceRoomScreensMessage2;

  /// lib/features/chat/v2/voice_room_screens.dart:997
  ///
  /// In en, this message translates to:
  /// **'Left stage, back to listening'**
  String get chatV2_voiceRoomScreensMessage3;

  /// lib/features/chat/v2/voice_room_screens.dart:1008
  ///
  /// In en, this message translates to:
  /// **'Leaving stage isn\'t available right now'**
  String get chatV2_voiceRoomScreensMessage4;

  /// lib/features/chat/v2/voice_room_screens.dart:1151, lib/features/chat/v2/voice_room_screens.dart:2248, lib/features/chat/v2/voice_room_screens.dart:2465
  ///
  /// In en, this message translates to:
  /// **'Room ended · The host ended this voice room'**
  String get chatV2_voiceRoomScreensMessage5;

  /// lib/features/chat/v2/voice_room_screens.dart:1166, lib/features/chat/v2/voice_room_screens.dart:2480
  ///
  /// In en, this message translates to:
  /// **'Left voice room'**
  String get chatV2_voiceRoomScreensMessage6;

  /// lib/features/chat/v2/voice_room_screens.dart:1167, lib/features/chat/v2/voice_room_screens.dart:2480
  ///
  /// In en, this message translates to:
  /// **'Left voice room; voice cleanup wasn\'t confirmed'**
  String get chatV2_voiceRoomScreensMessage7;

  /// lib/features/chat/v2/voice_room_screens.dart:1249
  ///
  /// In en, this message translates to:
  /// **'Mic is on, but the mute flag on the list couldn\'t be cleared: {communityFailureReason}'**
  String chatV2_voiceRoomScreensMessage8(Object? communityFailureReason);

  /// lib/features/chat/v2/voice_room_screens.dart:1317
  ///
  /// In en, this message translates to:
  /// **'Hand raised, waiting for the host to invite you'**
  String get chatV2_voiceRoomScreensMessage9;

  /// lib/features/chat/v2/voice_room_screens.dart:1208
  ///
  /// In en, this message translates to:
  /// **'Target: {name}. Mute is a LOOP-side intent; their device may still unmute itself. You can undo it on this row later.'**
  String chatV2_voiceRoomScreensMute(Object? name);

  /// lib/features/chat/v2/voice_room_screens.dart:1229
  ///
  /// In en, this message translates to:
  /// **'Mute requested'**
  String get chatV2_voiceRoomScreensMute2;

  /// lib/features/chat/v2/voice_room_screens.dart:919
  ///
  /// In en, this message translates to:
  /// **'Me · {named}'**
  String chatV2_voiceRoomScreensName(Object? named);

  /// lib/features/chat/v2/voice_room_screens.dart:2147
  ///
  /// In en, this message translates to:
  /// **'{part} · {count} joined'**
  String chatV2_voiceRoomScreensPart(Object? count, Object? part);

  /// lib/features/chat/v2/voice_room_screens.dart:2143
  ///
  /// In en, this message translates to:
  /// **'{part} · Voice reconnecting'**
  String chatV2_voiceRoomScreensReconnecting(Object? part);

  /// lib/features/chat/v2/voice_room_screens.dart:1206
  ///
  /// In en, this message translates to:
  /// **'Target: {name}. After removal they go back to listening and stay in the room.'**
  String chatV2_voiceRoomScreensRemoveSpeaker(Object? name);

  /// lib/features/chat/v2/voice_room_screens.dart:1228
  ///
  /// In en, this message translates to:
  /// **'Removed from stage'**
  String get chatV2_voiceRoomScreensRemoveSpeaker2;

  /// lib/features/chat/v2/voice_room_screens.dart:545, lib/features/chat/v2/voice_room_screens.dart:752
  ///
  /// In en, this message translates to:
  /// **'Mute all requested'**
  String get chatV2_voiceRoomScreensRun;

  /// lib/features/chat/v2/voice_room_screens.dart:547, lib/features/chat/v2/voice_room_screens.dart:1227
  ///
  /// In en, this message translates to:
  /// **'Invited to speak'**
  String get chatV2_voiceRoomScreensRun2;

  /// lib/features/chat/v2/voice_room_screens.dart:567, lib/features/chat/v2/voice_room_screens.dart:746
  ///
  /// In en, this message translates to:
  /// **'Joined, connecting voice'**
  String get chatV2_voiceRoomScreensRun3;

  /// lib/features/chat/v2/voice_room_screens.dart:570, lib/features/chat/v2/voice_room_screens.dart:750
  ///
  /// In en, this message translates to:
  /// **'Hand lowered'**
  String get chatV2_voiceRoomScreensRun4;

  /// lib/features/chat/v2/voice_room_screens.dart:1279, lib/features/chat/v2/voice_room_screens.dart:1973
  ///
  /// In en, this message translates to:
  /// **'Room ended'**
  String get chatV2_voiceRoomScreensRun5;

  /// lib/features/chat/v2/voice_room_screens.dart:534
  ///
  /// In en, this message translates to:
  /// **'Hand-raise queue'**
  String get chatV2_voiceRoomScreensS;

  /// lib/features/chat/v2/voice_room_screens.dart:1279
  ///
  /// In en, this message translates to:
  /// **'Room ended; voice cleanup wasn\'t confirmed'**
  String get chatV2_voiceRoomScreensS2;

  /// lib/features/chat/v2/voice_room_screens.dart:2141
  ///
  /// In en, this message translates to:
  /// **'{part} · {count} in call'**
  String chatV2_voiceRoomScreensS3(Object? count, Object? part);

  /// lib/features/chat/v2/voice_room_screens.dart:2602
  ///
  /// In en, this message translates to:
  /// **'{inRoom} in the room'**
  String chatV2_voiceRoomScreensS4(Object? inRoom);

  /// lib/features/chat/v2/voice_room_screens.dart:1691
  ///
  /// In en, this message translates to:
  /// **'Tap this row to unmute'**
  String get chatV2_voiceRoomScreensSubtitle;

  /// lib/features/chat/v2/voice_room_screens.dart:1691
  ///
  /// In en, this message translates to:
  /// **'Muted by host in LOOP'**
  String get chatV2_voiceRoomScreensSubtitle2;

  /// lib/features/chat/v2/voice_room_screens.dart:1692
  ///
  /// In en, this message translates to:
  /// **'Can speak'**
  String get chatV2_voiceRoomScreensSubtitle3;

  /// lib/features/chat/v2/voice_room_screens.dart:1693
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to invite'**
  String get chatV2_voiceRoomScreensSubtitle4;

  /// lib/features/chat/v2/voice_room_screens.dart:1693
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get chatV2_voiceRoomScreensSubtitle5;

  /// lib/features/chat/v2/voice_room_screens.dart:1830
  ///
  /// In en, this message translates to:
  /// **'#{entries} · {entries2}'**
  String chatV2_voiceRoomScreensSubtitle6(Object? entries, Object? entries2);

  /// lib/features/chat/v2/voice_room_screens.dart:1897
  ///
  /// In en, this message translates to:
  /// **'Invite to speak'**
  String get chatV2_voiceRoomScreensSubtitle7;

  /// lib/features/chat/v2/voice_room_screens.dart:1464
  ///
  /// In en, this message translates to:
  /// **'The voice room is recorded, but the call isn\'t set up yet. Tap Start voice room again to continue.'**
  String get chatV2_voiceRoomScreensSwitch;

  /// lib/features/chat/v2/voice_room_screens.dart:2621
  ///
  /// In en, this message translates to:
  /// **'Back collapses the room to the top; tap it to return anytime.'**
  String get chatV2_voiceRoomScreensSwitch10;

  /// lib/features/chat/v2/voice_room_screens.dart:2622
  ///
  /// In en, this message translates to:
  /// **'Check the host, online count and recording notice before joining.'**
  String get chatV2_voiceRoomScreensSwitch11;

  /// lib/features/chat/v2/voice_room_screens.dart:1465
  ///
  /// In en, this message translates to:
  /// **'The voice room is set up but listening isn\'t open yet. Tap Start voice room again to retry.'**
  String get chatV2_voiceRoomScreensSwitch2;

  /// lib/features/chat/v2/voice_room_screens.dart:1466
  ///
  /// In en, this message translates to:
  /// **'The voice room isn\'t ready, so no one can join yet. Tap Start voice room again to retry.'**
  String get chatV2_voiceRoomScreensSwitch3;

  /// lib/features/chat/v2/voice_room_screens.dart:1475
  ///
  /// In en, this message translates to:
  /// **'LOOP submitted this change; the provider hasn\'t confirmed it yet. Refresh later for the latest status.'**
  String get chatV2_voiceRoomScreensSwitch4;

  /// lib/features/chat/v2/voice_room_screens.dart:1501, lib/features/chat/v2/voice_room_stage.dart:115
  ///
  /// In en, this message translates to:
  /// **'Me · {alias}'**
  String chatV2_voiceRoomScreensSwitch5(Object? alias);

  /// lib/features/chat/v2/voice_room_screens.dart:2141
  ///
  /// In en, this message translates to:
  /// **'{part} · Counting'**
  String chatV2_voiceRoomScreensSwitch6(Object? part);

  /// lib/features/chat/v2/voice_room_screens.dart:2597
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load voice room status'**
  String get chatV2_voiceRoomScreensSwitch7;

  /// lib/features/chat/v2/voice_room_screens.dart:2602
  ///
  /// In en, this message translates to:
  /// **'{speaking} on mic'**
  String chatV2_voiceRoomScreensSwitch8(Object? speaking);

  /// lib/features/chat/v2/voice_room_screens.dart:2614
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the voice room status this time; you can retry below.'**
  String get chatV2_voiceRoomScreensSwitch9;

  /// lib/features/chat/v2/voice_room_screens.dart:2372
  ///
  /// In en, this message translates to:
  /// **'Leaving exits this call and cancels your raised hand.'**
  String get chatV2_voiceRoomScreensText;

  /// lib/features/chat/v2/voice_room_screens.dart:1118
  ///
  /// In en, this message translates to:
  /// **'Leave voice room?'**
  String get chatV2_voiceRoomScreensTitle;

  /// lib/features/chat/v2/voice_room_screens.dart:1262
  ///
  /// In en, this message translates to:
  /// **'End voice room?'**
  String get chatV2_voiceRoomScreensTitle2;

  /// lib/features/chat/v2/voice_room_screens.dart:1211
  ///
  /// In en, this message translates to:
  /// **'Target: {name}. This only withdraws the LOOP-side mute intent and won\'t turn on their mic; only their device can do that.'**
  String chatV2_voiceRoomScreensUnmute(Object? name);

  /// lib/features/chat/v2/voice_room_screens.dart:1230
  ///
  /// In en, this message translates to:
  /// **'Mute intent withdrawn'**
  String get chatV2_voiceRoomScreensUnmute2;

  /// lib/features/chat/v2/voice_room_screens.dart:1214
  ///
  /// In en, this message translates to:
  /// **'This is your own speaker row. It only clears the LOOP-side mute flag and won\'t turn on your mic; unmute yourself in the call.'**
  String get chatV2_voiceRoomScreensUnmuteSelf;

  /// lib/features/chat/v2/voice_room_screens.dart:1231
  ///
  /// In en, this message translates to:
  /// **'My mute flag cleared'**
  String get chatV2_voiceRoomScreensUnmuteSelf2;

  /// lib/features/chat/v2/voice_room_screens.dart:2121
  ///
  /// In en, this message translates to:
  /// **'In voice room · {communityName}'**
  String chatV2_voiceRoomScreensVoiceRoomBannerTitle(Object? communityName);

  /// lib/features/chat/v2/voice_room_screens.dart:2652
  ///
  /// In en, this message translates to:
  /// **'{inRoom} listening · {liveVoiceRoomElapsedLabel}'**
  String chatV2_voiceRoomScreensVoiceRoomLiveLine(
    Object? inRoom,
    Object? liveVoiceRoomElapsedLabel,
  );

  /// lib/features/chat/v2/voice_room_screens.dart:2643
  ///
  /// In en, this message translates to:
  /// **'Live · Speaking {speaking} · Listeners {listening}'**
  String chatV2_voiceRoomScreensVoiceRoomTopbarLine(
    Object? listening,
    Object? speaking,
  );

  /// lib/features/chat/v2/voice_room_screens.dart:2393
  ///
  /// In en, this message translates to:
  /// **'Leaving…'**
  String get chatV2_voiceRoomScreensVoiceroomBannerLeaveConfirmLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:2393
  ///
  /// In en, this message translates to:
  /// **'Confirm leave'**
  String get chatV2_voiceRoomScreensVoiceroomBannerLeaveConfirmLabel2;

  /// lib/features/chat/v2/voice_room_screens.dart:2351
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get chatV2_voiceRoomScreensVoiceroomBannerOpenLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:2352
  ///
  /// In en, this message translates to:
  /// **'Return to room'**
  String get chatV2_voiceRoomScreensVoiceroomBannerOpenLabel2;

  /// lib/features/chat/v2/voice_room_screens.dart:417
  ///
  /// In en, this message translates to:
  /// **'This device couldn\'t load the voice room\'s availability. Check your network and retry.'**
  String get chatV2_voiceRoomScreensVoiceroomCapabilityUnavailableDetail;

  /// lib/features/chat/v2/voice_room_screens.dart:419
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the voice room\'s availability yet. Try again later.'**
  String get chatV2_voiceRoomScreensVoiceroomCapabilityUnavailableDetail2;

  /// lib/features/chat/v2/voice_room_screens.dart:1979
  ///
  /// In en, this message translates to:
  /// **'Back to community'**
  String get chatV2_voiceRoomScreensVoiceroomEndedBackLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:1974, lib/features/chat/v2/voice_room_screens.dart:2617
  ///
  /// In en, this message translates to:
  /// **'The host ended this voice room.'**
  String get chatV2_voiceRoomScreensVoiceroomEndedMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:398, lib/features/chat/v2/voice_room_screens.dart:409
  ///
  /// In en, this message translates to:
  /// **'Voice room unavailable'**
  String get chatV2_voiceRoomScreensVoiceroomEvidencePendingMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:715, lib/features/chat/v2/voice_room_screens.dart:2019
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load End room this time. Try again later. Back collapses the room to the top.'**
  String get chatV2_voiceRoomScreensVoiceroomHostNoLeaveDetail;

  /// lib/features/chat/v2/voice_room_screens.dart:714, lib/features/chat/v2/voice_room_screens.dart:2018
  ///
  /// In en, this message translates to:
  /// **'Can\'t end the room right now'**
  String get chatV2_voiceRoomScreensVoiceroomHostNoLeaveMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:842
  ///
  /// In en, this message translates to:
  /// **'Room info, one item unconfirmed by the provider'**
  String get chatV2_voiceRoomScreensVoiceroomInfoLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:842
  ///
  /// In en, this message translates to:
  /// **'Room info'**
  String get chatV2_voiceRoomScreensVoiceroomInfoLabel2;

  /// lib/features/chat/v2/voice_room_screens.dart:1882
  ///
  /// In en, this message translates to:
  /// **'Raised hands are listed here in order.'**
  String get chatV2_voiceRoomScreensVoiceroomInviteEmptyMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:1881
  ///
  /// In en, this message translates to:
  /// **'No raised hands to invite'**
  String get chatV2_voiceRoomScreensVoiceroomInviteEmptyTitle;

  /// lib/features/chat/v2/voice_room_screens.dart:2002, lib/features/chat/v2/voice_room_stage.dart:778
  ///
  /// In en, this message translates to:
  /// **'Join voice room'**
  String get chatV2_voiceRoomScreensVoiceroomJoinLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:474, lib/features/chat/v2/voice_room_screens.dart:666
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get chatV2_voiceRoomScreensVoiceroomMediaBackstageRetryLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:1396
  ///
  /// In en, this message translates to:
  /// **'This voice room can\'t be opened right now; no connection was made.'**
  String get chatV2_voiceRoomScreensVoiceroomMediaUnavailableDetail;

  /// lib/features/chat/v2/voice_room_screens.dart:1395
  ///
  /// In en, this message translates to:
  /// **'Voice connection unavailable'**
  String get chatV2_voiceRoomScreensVoiceroomMediaUnavailableMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:1721
  ///
  /// In en, this message translates to:
  /// **'Close member actions'**
  String get chatV2_voiceRoomScreensVoiceroomMemberSheetBarrierLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:428
  ///
  /// In en, this message translates to:
  /// **'Enter from a community page or its official group; this page won\'t guess which community\'s voice room to open.'**
  String get chatV2_voiceRoomScreensVoiceroomMissingIdDetail;

  /// lib/features/chat/v2/voice_room_screens.dart:1922, lib/features/chat/v2/voice_room_stage.dart:798
  ///
  /// In en, this message translates to:
  /// **'Mute all'**
  String get chatV2_voiceRoomScreensVoiceroomMuteAllLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:690, lib/features/chat/v2/voice_room_screens.dart:1993
  ///
  /// In en, this message translates to:
  /// **'The provider hasn\'t confirmed this room is ready, so joining would be refused. Refresh and try again later.'**
  String get chatV2_voiceRoomScreensVoiceroomNotJoinableDetail;

  /// lib/features/chat/v2/voice_room_screens.dart:689, lib/features/chat/v2/voice_room_screens.dart:1992
  ///
  /// In en, this message translates to:
  /// **'This room can\'t be joined yet'**
  String get chatV2_voiceRoomScreensVoiceroomNotJoinableMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:1807
  ///
  /// In en, this message translates to:
  /// **'No one is waiting. Raised hands are listed here in order.'**
  String get chatV2_voiceRoomScreensVoiceroomQueueEmptyMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:1806
  ///
  /// In en, this message translates to:
  /// **'Hand-raise queue is empty'**
  String get chatV2_voiceRoomScreensVoiceroomQueueEmptyTitle;

  /// lib/features/chat/v2/voice_room_screens.dart:1784
  ///
  /// In en, this message translates to:
  /// **'Only the host can see the full queue. Your position shows here after you raise your hand.'**
  String get chatV2_voiceRoomScreensVoiceroomQueueSelfOnlyMessage;

  /// lib/features/chat/v2/voice_room_screens.dart:1783
  ///
  /// In en, this message translates to:
  /// **'You haven\'t raised your hand'**
  String get chatV2_voiceRoomScreensVoiceroomQueueSelfOnlyTitle;

  /// lib/features/chat/v2/voice_room_screens.dart:1794
  ///
  /// In en, this message translates to:
  /// **'#{sequence} · Waiting for invite'**
  String chatV2_voiceRoomScreensVoiceroomQueueSelfSubtitle(Object? sequence);

  /// lib/features/chat/v2/voice_room_screens.dart:365, lib/features/chat/v2/voice_room_screens.dart:804
  ///
  /// In en, this message translates to:
  /// **'Share voice room'**
  String get chatV2_voiceRoomScreensVoiceroomShareLabel;

  /// lib/features/chat/v2/voice_room_screens.dart:1045
  ///
  /// In en, this message translates to:
  /// **'Host · Speaking'**
  String get chatV2_voiceRoomScreensVoiceroomSpeakerHostSubtitle;

  /// lib/features/chat/v2/voice_room_screens.dart:1047
  ///
  /// In en, this message translates to:
  /// **'Host · Mic on'**
  String get chatV2_voiceRoomScreensVoiceroomSpeakerHostSubtitle2;

  /// lib/features/chat/v2/voice_room_screens.dart:2050
  ///
  /// In en, this message translates to:
  /// **'Only the host can change speakers. To leave the stage, ask the host or leave the room.'**
  String get chatV2_voiceRoomScreensVoiceroomStepDownUnavailableDetail;

  /// lib/features/chat/v2/voice_room_screens.dart:2049
  ///
  /// In en, this message translates to:
  /// **'Leaving stage yourself isn\'t available right now'**
  String get chatV2_voiceRoomScreensVoiceroomStepDownUnavailableMessage;

  /// lib/features/chat/v2/voice_room_share.dart:62
  ///
  /// In en, this message translates to:
  /// **'Join the \"{communityName}\" voice room on LOOP: {roomTitle}'**
  String chatV2_voiceRoomShareLine(Object? communityName, Object? roomTitle);

  /// lib/features/chat/v2/voice_room_share.dart:53
  ///
  /// In en, this message translates to:
  /// **'{communityName} voice room'**
  String chatV2_voiceRoomShareVoiceRoomTitle(Object? communityName);

  /// lib/features/chat/v2/voice_room_stage.dart:1029
  ///
  /// In en, this message translates to:
  /// **'Close go-live sheet'**
  String get chatV2_voiceRoomStageBarrierLabel;

  /// lib/features/chat/v2/voice_room_stage.dart:146, lib/features/chat/v2/voice_room_stage.dart:292
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get chatV2_voiceRoomStageBuild;

  /// lib/features/chat/v2/voice_room_stage.dart:148, lib/features/chat/v2/voice_room_stage.dart:294
  ///
  /// In en, this message translates to:
  /// **'Mic on'**
  String get chatV2_voiceRoomStageBuild2;

  /// lib/features/chat/v2/voice_room_stage.dart:1115
  ///
  /// In en, this message translates to:
  /// **'The room is visible to community members right away and anyone can listen in. As host, you or other admins invite speakers, mute all and end the room; the mic is off by default.'**
  String get chatV2_voiceRoomStageBuild3;

  /// lib/features/chat/v2/voice_room_stage.dart:1131
  ///
  /// In en, this message translates to:
  /// **'Leave blank to show \"Community name voice room\"'**
  String get chatV2_voiceRoomStageHintText;

  /// lib/features/chat/v2/voice_room_stage.dart:657
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more listener} other{{count} more listeners}}{onTap}'**
  String chatV2_voiceRoomStageLabel(num count, Object? onTap);

  /// lib/features/chat/v2/voice_room_stage.dart:977, lib/features/chat/v2/voice_room_stage.dart:1102, lib/features/chat/v2/voice_room_stage.dart:1157
  ///
  /// In en, this message translates to:
  /// **'Go live'**
  String get chatV2_voiceRoomStageLabel2;

  /// lib/features/chat/v2/voice_room_stage.dart:983
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get chatV2_voiceRoomStageLabel3;

  /// lib/features/chat/v2/voice_room_stage.dart:988
  ///
  /// In en, this message translates to:
  /// **'My role'**
  String get chatV2_voiceRoomStageLabel4;

  /// lib/features/chat/v2/voice_room_stage.dart:1130
  ///
  /// In en, this message translates to:
  /// **'Room title (optional)'**
  String get chatV2_voiceRoomStageLabelText;

  /// lib/features/chat/v2/voice_room_stage.dart:436
  ///
  /// In en, this message translates to:
  /// **'View speakers'**
  String get chatV2_voiceRoomStageLoopOfflineState;

  /// lib/features/chat/v2/voice_room_stage.dart:550
  ///
  /// In en, this message translates to:
  /// **'View listeners'**
  String get chatV2_voiceRoomStageLoopOfflineState2;

  /// lib/features/chat/v2/voice_room_stage.dart:934
  ///
  /// In en, this message translates to:
  /// **'{label}, {badge} hands raised'**
  String chatV2_voiceRoomStageSemanticLabel(Object? badge, Object? label);

  /// lib/features/chat/v2/voice_room_stage.dart:989
  ///
  /// In en, this message translates to:
  /// **'Not joined'**
  String get chatV2_voiceRoomStageValue;

  /// lib/features/chat/v2/voice_room_stage.dart:674
  ///
  /// In en, this message translates to:
  /// **', view full list'**
  String get chatV2_voiceRoomStageViewFullList;

  /// lib/features/chat/v2/voice_room_stage.dart:889
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get chatV2_voiceRoomStageVoiceroomBarMicLabel;

  /// lib/features/chat/v2/voice_room_stage.dart:154
  ///
  /// In en, this message translates to:
  /// **'Host {name}{caption}'**
  String chatV2_voiceRoomStageVoiceroomHostLabel(Object? caption, Object? name);

  /// lib/features/chat/v2/voice_room_stage.dart:190
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get chatV2_voiceRoomStageVoiceroomHostTag;

  /// lib/features/chat/v2/voice_room_stage.dart:952
  ///
  /// In en, this message translates to:
  /// **'Close room info'**
  String get chatV2_voiceRoomStageVoiceroomInfoSheetBarrierLabel;

  /// lib/features/chat/v2/voice_room_stage.dart:791
  ///
  /// In en, this message translates to:
  /// **'Invite to speak'**
  String get chatV2_voiceRoomStageVoiceroomInviteOpenLabel;

  /// lib/features/chat/v2/voice_room_stage.dart:581
  ///
  /// In en, this message translates to:
  /// **'No listeners yet'**
  String get chatV2_voiceRoomStageVoiceroomListenersEmptyTitle;

  /// lib/features/chat/v2/voice_room_stage.dart:568
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load listeners'**
  String get chatV2_voiceRoomStageVoiceroomListenersErrorTitle;

  /// lib/features/chat/v2/voice_room_stage.dart:556
  ///
  /// In en, this message translates to:
  /// **'No permission to view listeners'**
  String get chatV2_voiceRoomStageVoiceroomListenersPermissionTitle;

  /// lib/features/chat/v2/voice_room_stage.dart:561
  ///
  /// In en, this message translates to:
  /// **'Listener list unavailable right now'**
  String get chatV2_voiceRoomStageVoiceroomListenersUnavailableMessage;

  /// lib/features/chat/v2/voice_room_stage.dart:997
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed by provider'**
  String get chatV2_voiceRoomStageVoiceroomProviderUnconfirmedTitle;

  /// lib/features/chat/v2/voice_room_stage.dart:714
  ///
  /// In en, this message translates to:
  /// **'No one on stage yet'**
  String get chatV2_voiceRoomStageVoiceroomSpeakersEmptyTitle;

  /// lib/features/chat/v2/voice_room_stage.dart:454
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load speakers'**
  String get chatV2_voiceRoomStageVoiceroomSpeakersErrorTitle;

  /// lib/features/chat/v2/voice_room_stage.dart:442
  ///
  /// In en, this message translates to:
  /// **'No permission to view speakers'**
  String get chatV2_voiceRoomStageVoiceroomSpeakersPermissionTitle;

  /// lib/features/chat/v2/voice_room_stage.dart:447
  ///
  /// In en, this message translates to:
  /// **'Speaker list unavailable right now'**
  String get chatV2_voiceRoomStageVoiceroomSpeakersUnavailableMessage;

  /// lib/features/chat/v2/voice_room_stage.dart:1138
  ///
  /// In en, this message translates to:
  /// **'The last go-live didn\'t finish. Going live again finishes it and keeps the title you entered.'**
  String get chatV2_voiceRoomStageVoiceroomStartPending;

  /// lib/features/chat/v2/voice_room_stage.dart:1157
  ///
  /// In en, this message translates to:
  /// **'Going live…'**
  String get chatV2_voiceRoomStageVoiceroomStartSubmitLabel;

  /// lib/features/chat/v2/voice_room_stage.dart:814
  ///
  /// In en, this message translates to:
  /// **'Leave stage'**
  String get chatV2_voiceRoomStageVoiceroomStepDownLabel;

  /// lib/features/chat/widgets/chat_components.dart:884
  ///
  /// In en, this message translates to:
  /// **'Shared at 14:12 · Demo data'**
  String get chatWidgets_componentsBuild;

  /// lib/features/chat/widgets/chat_components.dart:825
  ///
  /// In en, this message translates to:
  /// **'+8.4% · Demo data'**
  String get chatWidgets_componentsChange;

  /// lib/features/chat/widgets/chat_components.dart:860
  ///
  /// In en, this message translates to:
  /// **'ETH Spot market snapshot · Development preview'**
  String get chatWidgets_componentsChatSpotSnapshotSemanticsLabel;

  /// lib/features/chat/widgets/chat_components.dart:828
  ///
  /// In en, this message translates to:
  /// **'LP unlocks in 3 days'**
  String get chatWidgets_componentsFact;

  /// lib/features/chat/widgets/chat_components.dart:833
  ///
  /// In en, this message translates to:
  /// **'Top 10 holders own 61%'**
  String get chatWidgets_componentsFact2;

  /// lib/features/chat/widgets/chat_components.dart:403
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get chatWidgets_componentsLabel;

  /// lib/features/chat/widgets/chat_components.dart:839
  ///
  /// In en, this message translates to:
  /// **'Development preview facts · Not a provider response · 14:06 UTC'**
  String get chatWidgets_componentsLoopTokenCardModel;

  /// lib/features/chat/widgets/chat_components.dart:840
  ///
  /// In en, this message translates to:
  /// **'Demo data can\'t trigger trades or watchlist changes.'**
  String get chatWidgets_componentsLoopTokenCardModel2;

  /// lib/features/chat/widgets/chat_components.dart:829, lib/features/chat/widgets/chat_components.dart:834
  ///
  /// In en, this message translates to:
  /// **'Development preview facts'**
  String get chatWidgets_componentsSource;

  /// lib/features/chat/chat_inbox_row_actions.dart:138
  ///
  /// In en, this message translates to:
  /// **'Close conversation actions'**
  String get chat_inboxRowActionsChatInboxRowSheetBarrierLabel;

  /// lib/features/chat/chat_inbox_row_actions.dart:20
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get chat_inboxRowActionsMarkRead;

  /// lib/features/chat/chat_inbox_row_actions.dart:16
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chat_inboxRowActionsPin;

  /// lib/features/chat/chat_inbox_row_actions.dart:17
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chat_inboxRowActionsUnpin;

  /// lib/features/chat/chat_preview_pages.dart:183
  ///
  /// In en, this message translates to:
  /// **'Shared in chat · Development preview'**
  String get chat_previewPagesEyebrow;

  /// lib/features/chat/chat_preview_pages.dart:48
  ///
  /// In en, this message translates to:
  /// **'Demo prices and facts aren\'t provider responses. In production, cards without fresh facts don\'t show price, Buy or Watch.'**
  String get chat_previewPagesMessage;

  /// lib/features/chat/chat_preview_pages.dart:193
  ///
  /// In en, this message translates to:
  /// **'Reference price, 24h change, and volume are labelled Demo data. Opening Market loads a separate current public Spot snapshot.'**
  String get chat_previewPagesMessage2;

  /// lib/features/chat/chat_preview_pages.dart:14
  ///
  /// In en, this message translates to:
  /// **'Development preview: messages only store the asset ID; current price and facts are re-verified when shown.'**
  String get chat_previewPagesSubtitle;

  /// lib/features/chat/chat_secondary_pages.dart:116
  ///
  /// In en, this message translates to:
  /// **'Preferences · Development preview'**
  String get chat_secondaryPagesLoopSectionLabel;

  /// lib/features/chat/chat_secondary_pages.dart:313
  ///
  /// In en, this message translates to:
  /// **'Removed from Development preview only. No sender interaction occurred.'**
  String get chat_secondaryPagesS;

  /// lib/features/chat/chat_secondary_pages.dart:312
  ///
  /// In en, this message translates to:
  /// **'Marked accepted in Development preview and removed locally. No Stream conversation was created.'**
  String get chat_secondaryPagesShowRequestNotice;

  /// lib/features/chat/chat_secondary_pages.dart:380
  ///
  /// In en, this message translates to:
  /// **'Removed from Development preview. No report was submitted.'**
  String get chat_secondaryPagesShowRequestNotice2;

  /// lib/features/chat/chat_secondary_pages.dart:246
  ///
  /// In en, this message translates to:
  /// **'Development Preview only · Development preview'**
  String get chat_secondaryPagesTitle;

  /// lib/features/chat/stream_chat_inbox_page.dart:1012
  ///
  /// In en, this message translates to:
  /// **'The conversation is removed from the list and comes back when there\'s a new message. Chat history isn\'t cleared.'**
  String get chat_streamInboxBody;

  /// lib/features/chat/stream_chat_inbox_page.dart:404
  ///
  /// In en, this message translates to:
  /// **'In voice room, {communityName}, return to room'**
  String chat_streamInboxChatVoiceRoomReturnEntrySemanticLabel(
    Object? communityName,
  );

  /// lib/features/chat/stream_chat_inbox_page.dart:402
  ///
  /// In en, this message translates to:
  /// **'In voice room · {communityName}'**
  String chat_streamInboxChatVoiceRoomReturnEntryTitle(Object? communityName);

  /// lib/features/chat/stream_chat_inbox_page.dart:306
  ///
  /// In en, this message translates to:
  /// **'Loading conversations'**
  String get chat_streamInboxLabel;

  /// lib/features/chat/stream_chat_inbox_page.dart:181
  ///
  /// In en, this message translates to:
  /// **'This build isn\'t connected to the chat service, so conversations won\'t show here.'**
  String get chat_streamInboxMessage;

  /// lib/features/chat/stream_chat_inbox_page.dart:515
  ///
  /// In en, this message translates to:
  /// **'Before resolving a LOOP group, we need to confirm you\'re still a member of this group chat.'**
  String get chat_streamInboxMessage10;

  /// lib/features/chat/stream_chat_inbox_page.dart:582
  ///
  /// In en, this message translates to:
  /// **'LOOP is confirming you\'re a member of this group chat.'**
  String get chat_streamInboxMessage11;

  /// lib/features/chat/stream_chat_inbox_page.dart:589
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm your membership in this group chat. No group was resolved.'**
  String get chat_streamInboxMessage12;

  /// lib/features/chat/stream_chat_inbox_page.dart:649
  ///
  /// In en, this message translates to:
  /// **'LOOP is confirming this channel and your membership.'**
  String get chat_streamInboxMessage13;

  /// lib/features/chat/stream_chat_inbox_page.dart:656
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm your membership in this channel. No channel was created or opened.'**
  String get chat_streamInboxMessage14;

  /// lib/features/chat/stream_chat_inbox_page.dart:1024
  ///
  /// In en, this message translates to:
  /// **'\"{label}\" didn\'t finish. Try again later'**
  String chat_streamInboxMessage15(Object? label);

  /// lib/features/chat/stream_chat_inbox_page.dart:265
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the conversation. No message action was taken on this page.'**
  String get chat_streamInboxMessage2;

  /// lib/features/chat/stream_chat_inbox_page.dart:274
  ///
  /// In en, this message translates to:
  /// **'The chat service isn\'t connected yet. Try again later.'**
  String get chat_streamInboxMessage3;

  /// lib/features/chat/stream_chat_inbox_page.dart:427
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t point to a conversation LOOP supports. No channel was opened.'**
  String get chat_streamInboxMessage4;

  /// lib/features/chat/stream_chat_inbox_page.dart:438, lib/features/chat/stream_chat_inbox_page.dart:500
  ///
  /// In en, this message translates to:
  /// **'LOOP is restoring the server-authorized chat connection.'**
  String get chat_streamInboxMessage5;

  /// lib/features/chat/stream_chat_inbox_page.dart:443
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore chat authorization. No conversation was opened.'**
  String get chat_streamInboxMessage6;

  /// lib/features/chat/stream_chat_inbox_page.dart:451
  ///
  /// In en, this message translates to:
  /// **'Opening this conversation needs a server-confirmed chat identity and a short-lived token.'**
  String get chat_streamInboxMessage7;

  /// lib/features/chat/stream_chat_inbox_page.dart:489
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t point to a group chat LOOP supports. No group was resolved.'**
  String get chat_streamInboxMessage8;

  /// lib/features/chat/stream_chat_inbox_page.dart:505
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore chat authorization. No group was resolved.'**
  String get chat_streamInboxMessage9;

  /// lib/features/chat/stream_chat_inbox_page.dart:372
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get chat_streamInboxPlaceholder;

  /// lib/features/chat/stream_chat_inbox_page.dart:952
  ///
  /// In en, this message translates to:
  /// **'Find friends'**
  String get chat_streamInboxStreamChatEmptyActionLabel;

  /// lib/features/chat/stream_chat_inbox_page.dart:951
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chat_streamInboxStreamChatEmptyMessage;

  /// lib/features/chat/stream_chat_inbox_page.dart:964
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the conversation list on this page. Local history wasn\'t deleted.'**
  String get chat_streamInboxStreamChatListErrorMessage;

  /// lib/features/chat/stream_chat_inbox_page.dart:963
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load conversations'**
  String get chat_streamInboxStreamChatListErrorTitle;

  /// lib/features/chat/stream_chat_inbox_page.dart:1208
  ///
  /// In en, this message translates to:
  /// **'Conversations not connected yet'**
  String get chat_streamInboxStreamChatUnavailableTitle;

  /// lib/features/chat/stream_chat_inbox_page.dart:426
  ///
  /// In en, this message translates to:
  /// **'Invalid conversation link'**
  String get chat_streamInboxTitle;

  /// lib/features/chat/stream_chat_inbox_page.dart:655
  ///
  /// In en, this message translates to:
  /// **'Conversation unavailable'**
  String get chat_streamInboxTitle10;

  /// lib/features/chat/stream_chat_inbox_page.dart:996
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get chat_streamInboxTitle11;

  /// lib/features/chat/stream_chat_inbox_page.dart:1011
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get chat_streamInboxTitle12;

  /// lib/features/chat/stream_chat_inbox_page.dart:437, lib/features/chat/stream_chat_inbox_page.dart:499
  ///
  /// In en, this message translates to:
  /// **'Restoring conversation'**
  String get chat_streamInboxTitle2;

  /// lib/features/chat/stream_chat_inbox_page.dart:442
  ///
  /// In en, this message translates to:
  /// **'Chat isn\'t available right now'**
  String get chat_streamInboxTitle3;

  /// lib/features/chat/stream_chat_inbox_page.dart:450, lib/features/chat/stream_chat_inbox_page.dart:514
  ///
  /// In en, this message translates to:
  /// **'Chat service not connected yet'**
  String get chat_streamInboxTitle4;

  /// lib/features/chat/stream_chat_inbox_page.dart:488
  ///
  /// In en, this message translates to:
  /// **'Invalid group chat link'**
  String get chat_streamInboxTitle5;

  /// lib/features/chat/stream_chat_inbox_page.dart:504
  ///
  /// In en, this message translates to:
  /// **'Group identity unavailable'**
  String get chat_streamInboxTitle6;

  /// lib/features/chat/stream_chat_inbox_page.dart:581
  ///
  /// In en, this message translates to:
  /// **'Confirming group chat'**
  String get chat_streamInboxTitle7;

  /// lib/features/chat/stream_chat_inbox_page.dart:588
  ///
  /// In en, this message translates to:
  /// **'Group chat unavailable'**
  String get chat_streamInboxTitle8;

  /// lib/features/chat/stream_chat_inbox_page.dart:648
  ///
  /// In en, this message translates to:
  /// **'Opening conversation'**
  String get chat_streamInboxTitle9;

  /// lib/features/chat/voice_room_page.dart:258
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get chat_voiceRoomLabel;

  /// lib/features/chat/voice_room_page.dart:133
  ///
  /// In en, this message translates to:
  /// **'Mock seat'**
  String get chat_voiceRoomText;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get common_about;

  /// common
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get common_aboutSection;

  /// common
  ///
  /// In en, this message translates to:
  /// **'The action didn\'t finish.'**
  String get common_actionIncomplete;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get common_actions;

  /// common
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get common_all;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get common_amount;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get common_assets;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Awaiting signature'**
  String get common_awaitingSignature;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_back;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Block list'**
  String get common_blockList;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get common_bridge;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get common_broadcast;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get common_buy;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get common_cancelled;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get common_chart;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get common_chat;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get common_claim;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get common_community;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get common_confirmed;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get common_continueAction;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get common_contract;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get common_copied;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get common_copy;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Data source'**
  String get common_dataSource;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Data unavailable'**
  String get common_dataUnavailable;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Demo data'**
  String get common_demoData;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get common_details;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Development preview'**
  String get common_devPreview;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Direct message'**
  String get common_directMessage;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get common_disconnected;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_done;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get common_draft;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_edit;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get common_ended;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Estimated to receive'**
  String get common_estimatedReceive;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get common_exit;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get common_expired;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get common_failed;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get common_feed;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get common_follow;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get common_followers;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get common_following;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get common_gotIt;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Graduate'**
  String get common_graduate;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Graduated'**
  String get common_graduated;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Group chat'**
  String get common_groupChat;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Holders'**
  String get common_holders;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Holdings'**
  String get common_holdings;

  /// common
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get common_inProgress;

  /// common
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get common_inReview;

  /// common
  ///
  /// In en, this message translates to:
  /// **'This item can\'t be loaded right now.'**
  String get common_itemUnavailable;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get common_joining;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get common_justNow;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get common_language;

  /// common
  ///
  /// In en, this message translates to:
  /// **'The last action didn\'t finish'**
  String get common_lastActionIncomplete;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Launchpad'**
  String get common_launchpad;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get common_learnMore;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get common_link;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get common_linkCopied;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Liquidity'**
  String get common_liquidity;

  /// common: joins the parts of one screen-reader label
  ///
  /// In en, this message translates to:
  /// **', '**
  String get common_listSeparator;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get common_loading;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get common_loadingEllipsis;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get common_market;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Market cap'**
  String get common_marketCap;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get common_me;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get common_members;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Message requests'**
  String get common_messageRequests;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Minimum received'**
  String get common_minimumReceive;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Mining'**
  String get common_mining;

  /// common
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get common_more;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get common_mute;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get common_muted;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get common_name;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get common_network;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get common_next;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the next page'**
  String get common_nextPageFailed;

  /// common
  ///
  /// In en, this message translates to:
  /// **'This account doesn\'t have permission'**
  String get common_noPermission;

  /// common
  ///
  /// In en, this message translates to:
  /// **'No trades yet'**
  String get common_noTradesYet;

  /// common
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get common_none;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get common_normal;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get common_notConfigured;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get common_notOpenYet;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get common_nothingHereYet;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get common_notificationSettings;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get common_notifications;

  /// common
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// common
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get common_on;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Go to Security Center'**
  String get common_openSecurityCenter;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get common_openSettings;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get common_paused;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get common_pay;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Pending confirmation'**
  String get common_pendingConfirmation;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get common_power;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Price alerts'**
  String get common_priceAlerts;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get common_profile;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get common_receive;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get common_refresh;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get common_rejected;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get common_reload;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get common_report;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Reverted'**
  String get common_reverted;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get common_scan;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get common_search;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get common_security;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Security Center'**
  String get common_securityCenter;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get common_sell;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get common_send;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get common_settings;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get common_share;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get common_sign;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Simulation passed'**
  String get common_simulationPassed;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Simulation rejected'**
  String get common_simulationRejected;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Simulation result'**
  String get common_simulationResult;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Simulation unavailable'**
  String get common_simulationUnavailable;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Slippage limit'**
  String get common_slippageLimit;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Snapshot block'**
  String get common_snapshotBlock;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get common_submit;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get common_submitted;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Submitting'**
  String get common_submitting;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get common_success;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get common_swap;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get common_today;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get common_token;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Token approvals'**
  String get common_tokenApprovals;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Total supply'**
  String get common_totalSupply;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get common_trade;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get common_unavailable;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get common_unknown;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get common_unmute;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get common_unread;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get common_uploading;

  /// common
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get common_user;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get common_validUntil;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get common_verifying;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Voice rooms'**
  String get common_voiceRooms;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Waiting for data'**
  String get common_waitingForData;

  /// common
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get common_watchlist;

  /// lib/features/dapp/dapp_bridge.dart:58
  ///
  /// In en, this message translates to:
  /// **'The wallet has a pending action'**
  String get dapp_bridgeDappIntentBusyText;

  /// lib/features/dapp/dapp_bridge.dart:55, lib/features/dapp/dapp_signing.dart:52
  ///
  /// In en, this message translates to:
  /// **'Signing isn\'t supported on this network yet'**
  String get dapp_bridgeDappMainnetSigningText;

  /// lib/features/dapp/dapp_bridge.dart:787
  ///
  /// In en, this message translates to:
  /// **'Not enough balance to pay for this transaction'**
  String get dapp_bridgeInsufficientBalance;

  /// lib/features/dapp/dapp_bridge.dart:785
  ///
  /// In en, this message translates to:
  /// **'Network unavailable. Try again later.'**
  String get dapp_bridgeTimedOut;

  /// lib/features/dapp/dapp_bridge.dart:646, lib/features/dapp/dapp_bridge.dart:788
  ///
  /// In en, this message translates to:
  /// **'This request didn\'t pass the checks'**
  String get dapp_bridgeToast;

  /// lib/features/dapp/dapp_bridge.dart:786
  ///
  /// In en, this message translates to:
  /// **'Signing isn\'t supported on this page yet'**
  String get dapp_bridgeUnavailable;

  /// lib/features/dapp/dapp_browser_screens.dart:743
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get dapp_browserScreensBlocked;

  /// lib/features/dapp/dapp_browser_screens.dart:207, lib/features/dapp/dapp_browser_screens.dart:619, lib/features/dapp/dapp_browser_screens.dart:633, lib/features/dapp/dapp_browser_screens.dart:935
  ///
  /// In en, this message translates to:
  /// **'This address can\'t be opened'**
  String get dapp_browserScreensBuild;

  /// lib/features/dapp/dapp_browser_screens.dart:284
  ///
  /// In en, this message translates to:
  /// **'Clear recents'**
  String get dapp_browserScreensDappBrowserClearRecentsLabel;

  /// lib/features/dapp/dapp_browser_screens.dart:261
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get dapp_browserScreensDappBrowserEmptyTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:229
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get dapp_browserScreensDappBrowserGoLabel;

  /// lib/features/dapp/dapp_browser_screens.dart:178
  ///
  /// In en, this message translates to:
  /// **'DApp browser'**
  String get dapp_browserScreensDappBrowserHomeTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:188
  ///
  /// In en, this message translates to:
  /// **'Enter a URL'**
  String get dapp_browserScreensDappBrowserOmniboxHintText;

  /// lib/features/dapp/dapp_browser_screens.dart:379, lib/features/dapp/dapp_browser_screens.dart:963
  ///
  /// In en, this message translates to:
  /// **'Open anyway'**
  String get dapp_browserScreensDappFindingsOpenLabel;

  /// lib/features/dapp/dapp_browser_screens.dart:810
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get dapp_browserScreensDappMenuBookmarkAdd;

  /// lib/features/dapp/dapp_browser_screens.dart:810
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get dapp_browserScreensDappMenuBookmarkTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:817
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get dapp_browserScreensDappMenuCopyTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:832
  ///
  /// In en, this message translates to:
  /// **'Disconnect this site'**
  String get dapp_browserScreensDappMenuDisconnectTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:824
  ///
  /// In en, this message translates to:
  /// **'Open in external browser'**
  String get dapp_browserScreensDappMenuExternalTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:1063
  ///
  /// In en, this message translates to:
  /// **'View address {host}'**
  String dapp_browserScreensDappWebAddressLabel(Object? host);

  /// lib/features/dapp/dapp_browser_screens.dart:1200
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get dapp_browserScreensDappWebBackLabel;

  /// lib/features/dapp/dapp_browser_screens.dart:1103
  ///
  /// In en, this message translates to:
  /// **'Switch network {chainLabel}'**
  String dapp_browserScreensDappWebChainLabel(Object? chainLabel);

  /// lib/features/dapp/dapp_browser_screens.dart:1017
  ///
  /// In en, this message translates to:
  /// **'The page didn\'t open'**
  String get dapp_browserScreensDappWebErrorTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:1208
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get dapp_browserScreensDappWebForwardLabel;

  /// lib/features/dapp/dapp_browser_screens.dart:924
  ///
  /// In en, this message translates to:
  /// **'DApp browser isn\'t available right now'**
  String get dapp_browserScreensDappWebUnavailableTitle;

  /// lib/features/dapp/dapp_browser_screens.dart:1123
  ///
  /// In en, this message translates to:
  /// **'Wallet not connected'**
  String get dapp_browserScreensDappWebWallet;

  /// lib/features/dapp/dapp_browser_screens.dart:742
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get dapp_browserScreensFlagged;

  /// lib/features/dapp/dapp_browser_screens.dart:299
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get dapp_browserScreensIf;

  /// lib/features/dapp/dapp_browser_screens.dart:268, lib/features/dapp/dapp_browser_screens.dart:810
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get dapp_browserScreensLoopLabel;

  /// lib/features/dapp/dapp_browser_screens.dart:281
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get dapp_browserScreensLoopLabel2;

  /// lib/features/dapp/dapp_browser_screens.dart:552
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get dapp_browserScreensMessage;

  /// lib/features/dapp/dapp_browser_screens.dart:852
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get dapp_browserScreensMessage2;

  /// lib/features/dapp/dapp_browser_screens.dart:852
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get dapp_browserScreensMessage3;

  /// lib/features/dapp/dapp_browser_screens.dart:741
  ///
  /// In en, this message translates to:
  /// **'Same origin'**
  String get dapp_browserScreensNormalized;

  /// lib/features/dapp/dapp_browser_screens.dart:613
  ///
  /// In en, this message translates to:
  /// **'Only HTTPS addresses can be opened'**
  String get dapp_browserScreensToast;

  /// lib/features/dapp/dapp_browser_screens.dart:860
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the external browser'**
  String get dapp_browserScreensToast2;

  /// lib/features/dapp/dapp_models.dart:91
  ///
  /// In en, this message translates to:
  /// **'Approval for all NFTs'**
  String get dapp_modelsApprovalForAll;

  /// lib/features/dapp/dapp_models.dart:93
  ///
  /// In en, this message translates to:
  /// **'Approval to a personal address'**
  String get dapp_modelsEoaSpender;

  /// lib/features/dapp/dapp_models.dart:80
  ///
  /// In en, this message translates to:
  /// **'BSC Mainnet'**
  String get dapp_modelsFor;

  /// lib/features/dapp/dapp_models.dart:94
  ///
  /// In en, this message translates to:
  /// **'Permit signature'**
  String get dapp_modelsPermitSignature;

  /// lib/features/dapp/dapp_models.dart:96
  ///
  /// In en, this message translates to:
  /// **'Raw hash signature'**
  String get dapp_modelsRawHashSignature;

  /// lib/features/dapp/dapp_models.dart:104
  ///
  /// In en, this message translates to:
  /// **'Simulation failed'**
  String get dapp_modelsSimulationFailed;

  /// lib/features/dapp/dapp_models.dart:90
  ///
  /// In en, this message translates to:
  /// **'Unlimited approval'**
  String get dapp_modelsUnlimitedApproval;

  /// lib/features/dapp/dapp_models.dart:100
  ///
  /// In en, this message translates to:
  /// **'Unrecognized signature structure'**
  String get dapp_modelsUnrecognizedTypedData;

  /// lib/features/dapp/dapp_models.dart:103
  ///
  /// In en, this message translates to:
  /// **'Unverified contract'**
  String get dapp_modelsUnverifiedContract;

  /// lib/features/dapp/dapp_signing.dart:508
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get dapp_signingDappConnectConfirmLabel;

  /// lib/features/dapp/dapp_signing.dart:723
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get dapp_signingDappSignSheetCancelLabel;

  /// lib/features/dapp/dapp_signing.dart:725
  ///
  /// In en, this message translates to:
  /// **'Signing and broadcasting'**
  String get dapp_signingDappSignSheetSigningTitle;

  /// lib/features/dapp/dapp_signing.dart:726
  ///
  /// In en, this message translates to:
  /// **'Signing'**
  String get dapp_signingDappSignSheetSigningTitle2;

  /// lib/features/dapp/dapp_signing.dart:493
  ///
  /// In en, this message translates to:
  /// **'Wallet address'**
  String get dapp_signingLabel;

  /// lib/features/dapp/dapp_signing.dart:267
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get dapp_signingLoopSignFact;

  /// lib/features/dapp/dapp_signing.dart:269
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get dapp_signingLoopSignFact2;

  /// lib/features/dapp/dapp_signing.dart:270
  ///
  /// In en, this message translates to:
  /// **'Unknown method'**
  String get dapp_signingLoopSignFact3;

  /// lib/features/dapp/dapp_signing.dart:273
  ///
  /// In en, this message translates to:
  /// **'Target contract'**
  String get dapp_signingLoopSignFact4;

  /// lib/features/dapp/dapp_signing.dart:285
  ///
  /// In en, this message translates to:
  /// **'Data length'**
  String get dapp_signingLoopSignFact5;

  /// lib/features/dapp/dapp_signing.dart:285
  ///
  /// In en, this message translates to:
  /// **'{dataLength} bytes'**
  String dapp_signingLoopSignFact6(Object? dataLength);

  /// lib/features/dapp/dapp_signing.dart:292
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get dapp_signingLoopSignFact7;

  /// lib/features/dapp/dapp_signing.dart:294
  ///
  /// In en, this message translates to:
  /// **'Structured data'**
  String get dapp_signingLoopSignFact8;

  /// lib/features/dapp/dapp_signing.dart:244, lib/features/dapp/dapp_signing.dart:722
  ///
  /// In en, this message translates to:
  /// **'Confirm signature'**
  String get dapp_signingMessage;

  /// lib/features/dapp/dapp_signing.dart:269
  ///
  /// In en, this message translates to:
  /// **'Contract call'**
  String get dapp_signingS;

  /// lib/features/dapp/dapp_signing.dart:295
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get dapp_signingS2;

  /// lib/features/dapp/dapp_signing.dart:488
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get dapp_signingShowDappConnectSheet;

  /// lib/features/dapp/dapp_signing.dart:35
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing changed.'**
  String get dapp_signingSwitch;

  /// lib/features/dapp/dapp_signing.dart:36
  ///
  /// In en, this message translates to:
  /// **'Verification didn\'t pass. Nothing changed.'**
  String get dapp_signingSwitch2;

  /// lib/features/dapp/dapp_signing.dart:37
  ///
  /// In en, this message translates to:
  /// **'This request expired and wasn\'t signed. Go back to the page and try again.'**
  String get dapp_signingSwitch3;

  /// lib/features/dapp/dapp_signing.dart:38
  ///
  /// In en, this message translates to:
  /// **'The content to sign doesn\'t match the page\'s request. Signing refused.'**
  String get dapp_signingSwitch4;

  /// lib/features/dapp/dapp_signing.dart:42
  ///
  /// In en, this message translates to:
  /// **'This transaction failed simulation and wasn\'t signed.'**
  String get dapp_signingSwitch5;

  /// lib/features/dapp/dapp_signing.dart:43
  ///
  /// In en, this message translates to:
  /// **'This transaction can\'t be simulated right now and wasn\'t signed.'**
  String get dapp_signingSwitch6;

  /// lib/features/dapp/dapp_signing.dart:47
  ///
  /// In en, this message translates to:
  /// **'The wallet can\'t sign on this chain right now. Nothing was signed.'**
  String get dapp_signingSwitch7;

  /// lib/features/dapp/dapp_signing.dart:48
  ///
  /// In en, this message translates to:
  /// **'The signed-in wallet isn\'t the wallet for this request. Nothing was signed.'**
  String get dapp_signingSwitch8;

  /// lib/features/dapp/dapp_signing.dart:49
  ///
  /// In en, this message translates to:
  /// **'The wallet didn\'t finish signing. Nothing changed.'**
  String get dapp_signingSwitch9;

  /// lib/features/dapp/dapp_signing.dart:243, lib/features/dapp/dapp_signing.dart:721
  ///
  /// In en, this message translates to:
  /// **'Confirm transaction'**
  String get dapp_signingTransaction;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:256
  ///
  /// In en, this message translates to:
  /// **'{figure} ({note})'**
  String launch2Creator_figureWithNote(Object? figure, Object? note);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:136
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get launch2Creator_launch2AwaitingExecutor;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:85
  ///
  /// In en, this message translates to:
  /// **'Your account is still being set up. Try again later.'**
  String get launch2Creator_launch2BootstrapRequired;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:191
  ///
  /// In en, this message translates to:
  /// **'Bonding pool for sale'**
  String get launch2Creator_launch2Build;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:241
  ///
  /// In en, this message translates to:
  /// **'Fixed by the platform template; can\'t be changed.'**
  String get launch2Creator_launch2Build10;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:340
  ///
  /// In en, this message translates to:
  /// **'The platform hasn\'t set a buyback recipient address yet, so you can\'t submit right now.'**
  String get launch2Creator_launch2Build11;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:192
  ///
  /// In en, this message translates to:
  /// **'Graduation reserve'**
  String get launch2Creator_launch2Build2;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:193
  ///
  /// In en, this message translates to:
  /// **'Bonding pool trade tax'**
  String get launch2Creator_launch2Build3;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:194
  ///
  /// In en, this message translates to:
  /// **'DEX pool trade tax'**
  String get launch2Creator_launch2Build4;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:198
  ///
  /// In en, this message translates to:
  /// **'DEX pool buy tax'**
  String get launch2Creator_launch2Build5;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:203
  ///
  /// In en, this message translates to:
  /// **'Per-address cap'**
  String get launch2Creator_launch2Build6;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:206
  ///
  /// In en, this message translates to:
  /// **'Mint price'**
  String get launch2Creator_launch2Build7;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:208
  ///
  /// In en, this message translates to:
  /// **'Mint period'**
  String get launch2Creator_launch2Build8;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:211
  ///
  /// In en, this message translates to:
  /// **'Set by the instance'**
  String get launch2Creator_launch2Build9;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:187
  ///
  /// In en, this message translates to:
  /// **'{launch2CurveCapFigure} tokens'**
  String launch2Creator_launch2CapFigure(Object? launch2CurveCapFigure);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:137
  ///
  /// In en, this message translates to:
  /// **'Preparing to deploy'**
  String get launch2Creator_launch2Claimed;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:140
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get launch2Creator_launch2Confirmed;

  /// lib/features/launch2/creator/launch2_create_screen.dart:320
  ///
  /// In en, this message translates to:
  /// **'What you\'ve entered won\'t be saved.'**
  String get launch2Creator_launch2CreateBody;

  /// lib/features/launch2/creator/launch2_create_screen.dart:322
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get launch2Creator_launch2CreateCancelLabel;

  /// lib/features/launch2/creator/launch2_create_screen.dart:614
  ///
  /// In en, this message translates to:
  /// **'Saving configuration…'**
  String get launch2Creator_launch2CreateConfig;

  /// lib/features/launch2/creator/launch2_create_screen.dart:321
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get launch2Creator_launch2CreateConfirmLabel;

  /// lib/features/launch2/creator/launch2_create_screen.dart:589, lib/features/launch2/creator/launch2_project_screen.dart:55, lib/features/launch2/creator/launch2_project_screen.dart:93, lib/features/launch2/creator/launch2_sign_screen.dart:124
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find this project'**
  String get launch2Creator_launch2CreateEmptyMessage;

  /// lib/features/launch2/creator/launch2_create_screen.dart:435
  ///
  /// In en, this message translates to:
  /// **'Image upload failed: {memeFailureText}'**
  String launch2Creator_launch2CreateFailed(Object? memeFailureText);

  /// lib/features/launch2/creator/launch2_create_screen.dart:973
  ///
  /// In en, this message translates to:
  /// **'X (optional)'**
  String get launch2Creator_launch2CreateFor;

  /// lib/features/launch2/creator/launch2_create_screen.dart:974
  ///
  /// In en, this message translates to:
  /// **'Telegram (optional)'**
  String get launch2Creator_launch2CreateFor2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:975
  ///
  /// In en, this message translates to:
  /// **'Website (optional)'**
  String get launch2Creator_launch2CreateFor3;

  /// lib/features/launch2/creator/launch2_create_screen.dart:976
  ///
  /// In en, this message translates to:
  /// **'Discord (optional)'**
  String get launch2Creator_launch2CreateFor4;

  /// lib/features/launch2/creator/launch2_create_screen.dart:803
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get launch2Creator_launch2CreateGroupTitle;

  /// lib/features/launch2/creator/launch2_create_screen.dart:893
  ///
  /// In en, this message translates to:
  /// **'Basic info'**
  String get launch2Creator_launch2CreateGroupTitle2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:902
  ///
  /// In en, this message translates to:
  /// **'Enter project name'**
  String get launch2Creator_launch2CreateHint;

  /// lib/features/launch2/creator/launch2_create_screen.dart:909
  ///
  /// In en, this message translates to:
  /// **'Enter ticker'**
  String get launch2Creator_launch2CreateHint2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:925
  ///
  /// In en, this message translates to:
  /// **'Describe your project'**
  String get launch2Creator_launch2CreateHint3;

  /// lib/features/launch2/creator/launch2_create_screen.dart:107
  ///
  /// In en, this message translates to:
  /// **'Only links starting with https:// are supported'**
  String get launch2Creator_launch2CreateIf;

  /// lib/features/launch2/creator/launch2_create_screen.dart:617
  ///
  /// In en, this message translates to:
  /// **'Retry submission'**
  String get launch2Creator_launch2CreateLabel;

  /// lib/features/launch2/creator/launch2_create_screen.dart:617
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get launch2Creator_launch2CreateLabel2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:908, lib/features/launch2/creator/launch2_sign_screen.dart:287
  ///
  /// In en, this message translates to:
  /// **'Ticker'**
  String get launch2Creator_launch2CreateLabel3;

  /// lib/features/launch2/creator/launch2_create_screen.dart:924
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get launch2Creator_launch2CreateLabel4;

  /// lib/features/launch2/creator/launch2_create_screen.dart:45
  ///
  /// In en, this message translates to:
  /// **'To bind a community, the community owner does it under Community management → Bind token.'**
  String get launch2Creator_launch2CreateLaunch2CreateLinksCommunityHint;

  /// lib/features/launch2/creator/launch2_create_screen.dart:41
  ///
  /// In en, this message translates to:
  /// **'External links'**
  String get launch2Creator_launch2CreateLaunch2CreateLinksHeading;

  /// lib/features/launch2/creator/launch2_create_screen.dart:43
  ///
  /// In en, this message translates to:
  /// **'The project\'s X / Telegram / website / Discord, all optional; reviewers and users will see them.'**
  String get launch2Creator_launch2CreateLaunch2CreateLinksLine;

  /// lib/features/launch2/creator/launch2_create_screen.dart:810, lib/features/launch2/creator/launch2_create_screen.dart:825
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get launch2Creator_launch2CreateLaunch2CreateLogoMissing;

  /// lib/features/launch2/creator/launch2_create_screen.dart:813
  ///
  /// In en, this message translates to:
  /// **'A launch needs a square avatar'**
  String get launch2Creator_launch2CreateLaunch2CreateLogoMissing2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:858, lib/features/launch2/creator/launch2_create_screen.dart:875, lib/features/launch2/creator/launch2_creator_widgets.dart:744, lib/features/launch2/creator/launch2_project_screen.dart:165
  ///
  /// In en, this message translates to:
  /// **'NFT image'**
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing;

  /// lib/features/launch2/creator/launch2_create_screen.dart:858
  ///
  /// In en, this message translates to:
  /// **'NFT image (optional)'**
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:861
  ///
  /// In en, this message translates to:
  /// **'A launch needs an NFT image'**
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing3;

  /// lib/features/launch2/creator/launch2_create_screen.dart:695, lib/features/launch2/creator/launch2_project_screen.dart:287
  ///
  /// In en, this message translates to:
  /// **'Review notes'**
  String get launch2Creator_launch2CreateLaunch2CreateRejectionTitle;

  /// lib/features/launch2/creator/launch2_create_screen.dart:1016
  ///
  /// In en, this message translates to:
  /// **'Choose mint start time'**
  String get launch2Creator_launch2CreateLaunch2CreateSaleStartLabel;

  /// lib/features/launch2/creator/launch2_create_screen.dart:1028
  ///
  /// In en, this message translates to:
  /// **'Choose a mint start time first.'**
  String get launch2Creator_launch2CreateLaunch2CreateSaleStartMissingBody;

  /// lib/features/launch2/creator/launch2_create_screen.dart:1044
  ///
  /// In en, this message translates to:
  /// **'The mint start time is too early: the platform needs at least {leadLabel} of lead time, earliest {localTimestampLabel}. Choose again.'**
  String launch2Creator_launch2CreateLaunch2CreateSaleTooEarlyBody(
    Object? leadLabel,
    Object? localTimestampLabel,
  );

  /// lib/features/launch2/creator/launch2_create_screen.dart:582, lib/features/launch2/creator/launch2_create_screen.dart:600, lib/features/launch2/creator/launch2_project_screen.dart:315, lib/features/launch2/creator/launch2_sign_screen.dart:239
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get launch2Creator_launch2CreateLaunch2CreateScreenTitle;

  /// lib/features/launch2/creator/launch2_create_screen.dart:600
  ///
  /// In en, this message translates to:
  /// **'Start a v2 launch'**
  String get launch2Creator_launch2CreateLaunch2CreateScreenTitle2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:57
  ///
  /// In en, this message translates to:
  /// **'Name must contain visible characters'**
  String get launch2Creator_launch2CreateLaunch2NameInvisibleMessage;

  /// lib/features/launch2/creator/launch2_create_screen.dart:502
  ///
  /// In en, this message translates to:
  /// **'The platform sets the earliest time; too early gets sent back.'**
  String get launch2Creator_launch2CreateLaunch2SaleStartHint;

  /// lib/features/launch2/creator/launch2_create_screen.dart:503
  ///
  /// In en, this message translates to:
  /// **'Minting must start at least {leadLabel} from now, earliest {localTimestampLabel}.'**
  String launch2Creator_launch2CreateLaunch2SaleStartHint2(
    Object? leadLabel,
    Object? localTimestampLabel,
  );

  /// lib/features/launch2/creator/launch2_create_screen.dart:58
  ///
  /// In en, this message translates to:
  /// **'Ticker must contain visible characters'**
  String get launch2Creator_launch2CreateLaunch2TickerInvisibleMessage;

  /// lib/features/launch2/creator/launch2_create_screen.dart:463
  ///
  /// In en, this message translates to:
  /// **'{minutes}h'**
  String launch2Creator_launch2CreateLeadLabel(Object? minutes);

  /// lib/features/launch2/creator/launch2_create_screen.dart:464
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String launch2Creator_launch2CreateLeadLabel2(Object? minutes);

  /// lib/features/launch2/creator/launch2_create_screen.dart:615
  ///
  /// In en, this message translates to:
  /// **'Submitting for review…'**
  String get launch2Creator_launch2CreateLoopButton;

  /// lib/features/launch2/creator/launch2_create_screen.dart:1030, lib/features/launch2/creator/launch2_project_screen.dart:204, lib/features/launch2/creator/launch2_sign_screen.dart:293
  ///
  /// In en, this message translates to:
  /// **'Buyback recipient address'**
  String get launch2Creator_launch2CreateLoopLabel;

  /// lib/features/launch2/creator/launch2_create_screen.dart:1033
  ///
  /// In en, this message translates to:
  /// **'Launch template'**
  String get launch2Creator_launch2CreateLoopLabel2;

  /// lib/features/launch2/creator/launch2_create_screen.dart:483, lib/features/launch2/creator/launch2_create_screen.dart:1005
  ///
  /// In en, this message translates to:
  /// **'Mint start time'**
  String get launch2Creator_launch2CreateLoopSheetHeading;

  /// lib/features/launch2/creator/launch2_create_screen.dart:819
  ///
  /// In en, this message translates to:
  /// **'Square image; crop before upload'**
  String get launch2Creator_launch2CreateNote;

  /// lib/features/launch2/creator/launch2_create_screen.dart:613
  ///
  /// In en, this message translates to:
  /// **'Saving details…'**
  String get launch2Creator_launch2CreateProject;

  /// lib/features/launch2/creator/launch2_create_screen.dart:38, lib/features/launch2/creator/launch2_creator_entry.dart:248
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch2Creator_launch2CreateText;

  /// lib/features/launch2/creator/launch2_create_screen.dart:319
  ///
  /// In en, this message translates to:
  /// **'Discard this launch?'**
  String get launch2Creator_launch2CreateTitle;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:151, lib/features/launch2/creator/launch2_project_screen.dart:386
  ///
  /// In en, this message translates to:
  /// **'View project page'**
  String get launch2Creator_launch2DeploymentAction;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:162, lib/features/launch2/creator/launch2_deployment_screen.dart:183, lib/features/launch2/creator/launch2_project_screen.dart:371
  ///
  /// In en, this message translates to:
  /// **'Sign again'**
  String get launch2Creator_launch2DeploymentAction2;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:232
  ///
  /// In en, this message translates to:
  /// **'Confirmations: {confirmations}'**
  String launch2Creator_launch2DeploymentBuild(Object? confirmations);

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:233
  ///
  /// In en, this message translates to:
  /// **'Block {blockNumber}'**
  String launch2Creator_launch2DeploymentBuild2(Object? blockNumber);

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:198
  ///
  /// In en, this message translates to:
  /// **'Deploy transaction'**
  String get launch2Creator_launch2DeploymentLabel;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:200
  ///
  /// In en, this message translates to:
  /// **'Activation transaction'**
  String get launch2Creator_launch2DeploymentLabel2;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:306
  ///
  /// In en, this message translates to:
  /// **'Copy BscScan link'**
  String get launch2Creator_launch2DeploymentLabel3;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:146
  ///
  /// In en, this message translates to:
  /// **'Activated. Creating the project page…'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:146, lib/features/launch2/creator/launch2_project_screen.dart:381
  ///
  /// In en, this message translates to:
  /// **'Activated. You\'re this project\'s owner.'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody2;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:158
  ///
  /// In en, this message translates to:
  /// **'This deployment was cancelled.'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentCancelledBody;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:57
  ///
  /// In en, this message translates to:
  /// **'The link has no valid project or job ID.'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentMissingMessage;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:56, lib/features/launch2/creator/launch2_deployment_screen.dart:92
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find this deployment'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentMissingTitle;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:190
  ///
  /// In en, this message translates to:
  /// **'Signature verified and recorded; waiting for the platform executor to deploy. Nothing is on-chain yet.'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentQueuedBody;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:52, lib/features/launch2/creator/launch2_deployment_screen.dart:80
  ///
  /// In en, this message translates to:
  /// **'Deployment progress'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentScreenTitle;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:102
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the latest progress. Showing the last status; retrying automatically.'**
  String get launch2Creator_launch2DeploymentLaunch2DeploymentStaleBody;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:192
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get launch2Creator_launch2DeploymentLoopLabel;

  /// lib/features/launch2/creator/launch2_deployment_screen.dart:308
  ///
  /// In en, this message translates to:
  /// **'BscScan link copied'**
  String get launch2Creator_launch2DeploymentMessage;

  /// lib/features/launch2/creator/launch2_creator_entry.dart:133
  ///
  /// In en, this message translates to:
  /// **'Bonding curve token; moves to PancakeSwap when it fills'**
  String get launch2Creator_launch2EntryLaunch2CreateChooserClassicSubtitle;

  /// lib/features/launch2/creator/launch2_creator_entry.dart:132
  ///
  /// In en, this message translates to:
  /// **'Classic launch'**
  String get launch2Creator_launch2EntryLaunch2CreateChooserClassicTitle;

  /// lib/features/launch2/creator/launch2_creator_entry.dart:123
  ///
  /// In en, this message translates to:
  /// **'NFT presale + priority buy + public pool, graduates to the official DEX pool'**
  String get launch2Creator_launch2EntryLaunch2CreateChooserV2Subtitle;

  /// lib/features/launch2/creator/launch2_creator_entry.dart:122
  ///
  /// In en, this message translates to:
  /// **'v2 launch'**
  String get launch2Creator_launch2EntryLaunch2CreateChooserV2Title;

  /// lib/features/launch2/creator/launch2_creator_entry.dart:41
  ///
  /// In en, this message translates to:
  /// **'v2 launch (NFT presale + official DEX pool)'**
  String get launch2Creator_launch2EntryLaunch2CreatorEntryLabel;

  /// lib/features/launch2/creator/launch2_creator_entry.dart:59, lib/features/launch2/creator/launch2_creator_entry.dart:160, lib/features/launch2/creator/launch2_projects_screen.dart:122
  ///
  /// In en, this message translates to:
  /// **'My projects'**
  String get launch2Creator_launch2EntryLaunch2MyProjectsEntryLabel;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:82
  ///
  /// In en, this message translates to:
  /// **'This submission differs from the last one. Sign again.'**
  String get launch2Creator_launch2IdempotencyConflict;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:79
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t accept these details. Most often the mint start time is too early and leaves no time to deploy and activate. Move it later and submit again.'**
  String get launch2Creator_launch2InvalidData;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:456
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {labels}, {labels2}'**
  String launch2Creator_launch2Label(
    Object? current,
    Object? labels,
    Object? labels2,
  );

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:579
  ///
  /// In en, this message translates to:
  /// **'Upload {semanticLabel}'**
  String launch2Creator_launch2Label2(Object? semanticLabel);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:579
  ///
  /// In en, this message translates to:
  /// **'{semanticLabel}, replace'**
  String launch2Creator_launch2Label3(Object? semanticLabel);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:73
  ///
  /// In en, this message translates to:
  /// **'Another project in your wallet already used this configuration version. Edit the details and save a new version.'**
  String get launch2Creator_launch2Launch2ConfigVersionUsedCode;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:49
  ///
  /// In en, this message translates to:
  /// **'{seconds}d'**
  String launch2Creator_launch2Launch2DurationLabel(Object? seconds);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:50
  ///
  /// In en, this message translates to:
  /// **'{seconds}h'**
  String launch2Creator_launch2Launch2DurationLabel2(Object? seconds);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:51
  ///
  /// In en, this message translates to:
  /// **'{seconds} min'**
  String launch2Creator_launch2Launch2DurationLabel3(Object? seconds);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:321
  ///
  /// In en, this message translates to:
  /// **'Not configured yet'**
  String get launch2Creator_launch2Launch2FixedRecipientAddress;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:305
  ///
  /// In en, this message translates to:
  /// **'Buyback recipient address not configured yet'**
  String get launch2Creator_launch2Launch2FixedRecipientAddressLabel;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:305
  ///
  /// In en, this message translates to:
  /// **'Buyback recipient address {value}, fixed by the platform, can\'t be changed'**
  String launch2Creator_launch2Launch2FixedRecipientAddressLabel2(
    Object? value,
  );

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:433
  ///
  /// In en, this message translates to:
  /// **'Shown in wallets as the project NFT image'**
  String get launch2Creator_launch2Launch2NftImageHelp;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:70
  ///
  /// In en, this message translates to:
  /// **'The buyback recipient address must be the platform\'s fixed address. This version uses another one. Edit the details and save a new version (needs review again).'**
  String get launch2Creator_launch2Launch2RecipientFixedCode;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:75
  ///
  /// In en, this message translates to:
  /// **'The platform\'s buyback recipient address isn\'t configured, so you can\'t save or sign right now. Try again later.'**
  String get launch2Creator_launch2Launch2RecipientUnavailableCode;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:385
  ///
  /// In en, this message translates to:
  /// **'Rejected · {label}'**
  String launch2Creator_launch2Launch2RejectedRowText(Object? label);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:389
  ///
  /// In en, this message translates to:
  /// **'Review rejected: {label}'**
  String launch2Creator_launch2Launch2RejectionTitle(Object? label);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:280
  ///
  /// In en, this message translates to:
  /// **'{local} (in {inDays}d)'**
  String launch2Creator_launch2Launch2SaleStartLabel(
    Object? inDays,
    Object? local,
  );

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:281
  ///
  /// In en, this message translates to:
  /// **'{local} (in {inHours}h)'**
  String launch2Creator_launch2Launch2SaleStartLabel2(
    Object? inHours,
    Object? local,
  );

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:282
  ///
  /// In en, this message translates to:
  /// **'{local} (in {inMinutes} min)'**
  String launch2Creator_launch2Launch2SaleStartLabel3(
    Object? inMinutes,
    Object? local,
  );

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:34
  ///
  /// In en, this message translates to:
  /// **'{formatDecimal}'**
  String launch2Creator_launch2Launch2SupplyLabel(Object? formatDecimal);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:37
  ///
  /// In en, this message translates to:
  /// **'{formatDecimal}'**
  String launch2Creator_launch2Launch2SupplyLabel2(Object? formatDecimal);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:333
  ///
  /// In en, this message translates to:
  /// **'Fixed by platform'**
  String get launch2Creator_launch2LoopBadge;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:374
  ///
  /// In en, this message translates to:
  /// **'Review notes: {note}'**
  String launch2Creator_launch2LoopNotice(Object? note);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:375
  ///
  /// In en, this message translates to:
  /// **'{configuration} didn\'t pass review ({localTimestampLabel}). Edit it and submit again.'**
  String launch2Creator_launch2LoopNotice2(
    Object? configuration,
    Object? localTimestampLabel,
  );

  /// lib/features/launch2/creator/launch2_creator_models.dart:31, lib/features/launch2/creator/launch2_creator_widgets.dart:142, lib/features/launch2/creator/launch2_creator_widgets.dart:159
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get launch2Creator_launch2ModelsActive;

  /// lib/features/launch2/creator/launch2_creator_models.dart:33, lib/features/launch2/creator/launch2_creator_widgets.dart:143, lib/features/launch2/creator/launch2_creator_widgets.dart:161
  ///
  /// In en, this message translates to:
  /// **'Deployment failed'**
  String get launch2Creator_launch2ModelsDeployFailed;

  /// lib/features/launch2/creator/launch2_creator_models.dart:29
  ///
  /// In en, this message translates to:
  /// **'On-chain'**
  String get launch2Creator_launch2ModelsDeployed;

  /// lib/features/launch2/creator/launch2_creator_models.dart:28
  ///
  /// In en, this message translates to:
  /// **'Deploying'**
  String get launch2Creator_launch2ModelsDeploying;

  /// lib/features/launch2/creator/launch2_creator_models.dart:61
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get launch2Creator_launch2ModelsIsFailure;

  /// lib/features/launch2/creator/launch2_creator_models.dart:63
  ///
  /// In en, this message translates to:
  /// **'Deploy'**
  String get launch2Creator_launch2ModelsIsFailure2;

  /// lib/features/launch2/creator/launch2_creator_models.dart:64
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get launch2Creator_launch2ModelsIsFailure3;

  /// lib/features/launch2/creator/launch2_creator_models.dart:27
  ///
  /// In en, this message translates to:
  /// **'Signing'**
  String get launch2Creator_launch2ModelsSigning;

  /// lib/features/launch2/creator/launch2_creator_models.dart:30, lib/features/launch2/creator/launch2_creator_widgets.dart:141
  ///
  /// In en, this message translates to:
  /// **'Activating'**
  String get launch2Creator_launch2ModelsVerified;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:84
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find this project. It may not belong to this account.'**
  String get launch2Creator_launch2NotFound;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:83
  ///
  /// In en, this message translates to:
  /// **'This account can\'t do this step.'**
  String get launch2Creator_launch2PermissionDenied;

  /// lib/features/launch2/creator/launch2_project_screen.dart:247
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get launch2Creator_launch2ProjectAction;

  /// lib/features/launch2/creator/launch2_project_screen.dart:293
  ///
  /// In en, this message translates to:
  /// **'Edit and resubmit'**
  String get launch2Creator_launch2ProjectAction2;

  /// lib/features/launch2/creator/launch2_project_screen.dart:332
  ///
  /// In en, this message translates to:
  /// **'Sign to deploy'**
  String get launch2Creator_launch2ProjectAction3;

  /// lib/features/launch2/creator/launch2_project_screen.dart:348
  ///
  /// In en, this message translates to:
  /// **'View deployment progress'**
  String get launch2Creator_launch2ProjectAction4;

  /// lib/features/launch2/creator/launch2_project_screen.dart:207
  ///
  /// In en, this message translates to:
  /// **'Configuration version'**
  String get launch2Creator_launch2ProjectLabel;

  /// lib/features/launch2/creator/launch2_project_screen.dart:56, lib/features/launch2/creator/launch2_sign_screen.dart:125
  ///
  /// In en, this message translates to:
  /// **'The link has no valid project ID.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectMissingMessage;

  /// lib/features/launch2/creator/launch2_project_screen.dart:381
  ///
  /// In en, this message translates to:
  /// **'Activated. Creating the project page; pull down to refresh.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextActiveBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:343
  ///
  /// In en, this message translates to:
  /// **'Deployment in progress.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDeployingBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:243
  ///
  /// In en, this message translates to:
  /// **'Details saved; the launch configuration is still missing.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDraftBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:243
  ///
  /// In en, this message translates to:
  /// **'Not submitted for review yet.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDraftBody2;

  /// lib/features/launch2/creator/launch2_project_screen.dart:360
  ///
  /// In en, this message translates to:
  /// **'The deployment didn\'t finish.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextFailedBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:310
  ///
  /// In en, this message translates to:
  /// **'This version\'s buyback recipient address isn\'t the platform\'s fixed address, so it can\'t be signed and deployed. Saving a new version needs review again.'**
  String
  get launch2Creator_launch2ProjectLaunch2ProjectNextRecipientOutdatedBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:308, lib/features/launch2/creator/launch2_projects_screen.dart:143
  ///
  /// In en, this message translates to:
  /// **'Buyback recipient address needs updating'**
  String
  get launch2Creator_launch2ProjectLaunch2ProjectNextRecipientOutdatedTitle;

  /// lib/features/launch2/creator/launch2_project_screen.dart:289
  ///
  /// In en, this message translates to:
  /// **'This review didn\'t pass. Edit and submit again.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextRejectedBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:261
  ///
  /// In en, this message translates to:
  /// **'The platform is reviewing the launch configuration. The result shows here; pull down to refresh.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextReviewBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:262
  ///
  /// In en, this message translates to:
  /// **'Submitted {localTimestampLabel}. The result shows here; pull down to refresh.'**
  String launch2Creator_launch2ProjectLaunch2ProjectNextReviewBody2(
    Object? localTimestampLabel,
  );

  /// lib/features/launch2/creator/launch2_project_screen.dart:326
  ///
  /// In en, this message translates to:
  /// **'Sign with your wallet and the platform will deploy and activate.'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextSignBody;

  /// lib/features/launch2/creator/launch2_project_screen.dart:327
  ///
  /// In en, this message translates to:
  /// **'Approved {localTimestampLabel}. Sign with your wallet and the platform will deploy and activate.'**
  String launch2Creator_launch2ProjectLaunch2ProjectNextSignBody2(
    Object? localTimestampLabel,
  );

  /// lib/features/launch2/creator/launch2_project_screen.dart:324
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get launch2Creator_launch2ProjectLaunch2ProjectNextSignTitle;

  /// lib/features/launch2/creator/launch2_project_screen.dart:199, lib/features/launch2/creator/launch2_sign_screen.dart:289
  ///
  /// In en, this message translates to:
  /// **'Mint starts'**
  String get launch2Creator_launch2ProjectLaunch2ProjectSaleStartLabel;

  /// lib/features/launch2/creator/launch2_project_screen.dart:51, lib/features/launch2/creator/launch2_project_screen.dart:81
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get launch2Creator_launch2ProjectLaunch2ProjectScreenTitle;

  /// lib/features/launch2/creator/launch2_project_screen.dart:193
  ///
  /// In en, this message translates to:
  /// **'Launch configuration'**
  String get launch2Creator_launch2ProjectLoopLabel;

  /// lib/features/launch2/creator/launch2_project_screen.dart:189
  ///
  /// In en, this message translates to:
  /// **'Progress: {launch2CreatorMilestones}, {label}'**
  String launch2Creator_launch2ProjectSemanticLabel(
    Object? label,
    Object? launch2CreatorMilestones,
  );

  /// lib/features/launch2/creator/launch2_projects_screen.dart:64
  ///
  /// In en, this message translates to:
  /// **'NFT presale + official DEX pool, in one launch.'**
  String get launch2Creator_launch2ProjectsLaunch2ProjectsEmptyMessage;

  /// lib/features/launch2/creator/launch2_projects_screen.dart:63
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get launch2Creator_launch2ProjectsLaunch2ProjectsEmptyTitle;

  /// lib/features/launch2/creator/launch2_projects_screen.dart:182
  ///
  /// In en, this message translates to:
  /// **'{name}, launch configuration unavailable'**
  String launch2Creator_launch2ProjectsSemanticLabel(Object? name);

  /// lib/features/launch2/creator/launch2_projects_screen.dart:181
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the launch configuration. Pull to refresh or tap to retry'**
  String get launch2Creator_launch2ProjectsSubtitle;

  /// lib/features/launch2/creator/launch2_projects_screen.dart:140
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get launch2Creator_launch2ProjectsSwitch;

  /// lib/features/launch2/creator/launch2_projects_screen.dart:144
  ///
  /// In en, this message translates to:
  /// **'No launch configuration yet'**
  String get launch2Creator_launch2ProjectsSwitch2;

  /// lib/features/launch2/creator/launch2_projects_screen.dart:146
  ///
  /// In en, this message translates to:
  /// **'Mint starts {localTimestampLabel}'**
  String launch2Creator_launch2ProjectsSwitch3(Object? localTimestampLabel);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:144
  ///
  /// In en, this message translates to:
  /// **'Chain reorg, reconfirming'**
  String get launch2Creator_launch2Reorged;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:62
  ///
  /// In en, this message translates to:
  /// **'v2 launch isn\'t open yet. You can continue here once it opens.'**
  String get launch2Creator_launch2S;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:64
  ///
  /// In en, this message translates to:
  /// **'The launch factory isn\'t available (or is computing addresses). Try again later.'**
  String get launch2Creator_launch2S2;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:66
  ///
  /// In en, this message translates to:
  /// **'The configuration is waiting for platform approval. Sign after it\'s approved.'**
  String get launch2Creator_launch2S3;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:68
  ///
  /// In en, this message translates to:
  /// **'The signing request expired. Renew it and sign again.'**
  String get launch2Creator_launch2S4;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:139
  ///
  /// In en, this message translates to:
  /// **'On-chain, confirmations: {confirmations}'**
  String launch2Creator_launch2S5(Object? confirmations);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:341
  ///
  /// In en, this message translates to:
  /// **'Tokens bought back go to this address. The platform fixes it; it can\'t be changed.'**
  String get launch2Creator_launch2S6;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:536
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get launch2Creator_launch2S7;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:568
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get launch2Creator_launch2S8;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:204
  ///
  /// In en, this message translates to:
  /// **'Preparing the signing request; the server may take a few seconds to compute addresses.'**
  String get launch2Creator_launch2SignIf;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:366
  ///
  /// In en, this message translates to:
  /// **'Token address {address}'**
  String launch2Creator_launch2SignLabel(Object? address);

  /// lib/features/launch2/creator/launch2_sign_screen.dart:437
  ///
  /// In en, this message translates to:
  /// **'Signature valid for'**
  String get launch2Creator_launch2SignLabel2;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:311
  ///
  /// In en, this message translates to:
  /// **'The signing request expired. Renewing gets a new request that you need to sign again.'**
  String get launch2Creator_launch2SignLaunch2SignExpiredBody;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:178
  ///
  /// In en, this message translates to:
  /// **'Loading wallet…'**
  String get launch2Creator_launch2SignLaunch2SignNoWalletBody;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:178
  ///
  /// In en, this message translates to:
  /// **'No wallet available. Create or activate one in Wallet first.'**
  String get launch2Creator_launch2SignLaunch2SignNoWalletBody2;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:317
  ///
  /// In en, this message translates to:
  /// **'The configuration or nonce changed. The signing request was refreshed; sign again.'**
  String get launch2Creator_launch2SignLaunch2SignRefreshedBody;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:143
  ///
  /// In en, this message translates to:
  /// **'Renew signing request'**
  String get launch2Creator_launch2SignLaunch2SignRenewLabel;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:120, lib/features/launch2/creator/launch2_sign_screen.dart:169
  ///
  /// In en, this message translates to:
  /// **'Sign deployment'**
  String get launch2Creator_launch2SignLaunch2SignScreenTitle;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:509
  ///
  /// In en, this message translates to:
  /// **'Authorize deployment'**
  String get launch2Creator_launch2SignLaunch2SignSheetTitle;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:156
  ///
  /// In en, this message translates to:
  /// **'Sign and submit'**
  String get launch2Creator_launch2SignLoopButton;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:285
  ///
  /// In en, this message translates to:
  /// **'What you sign'**
  String get launch2Creator_launch2SignLoopLabel;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:517
  ///
  /// In en, this message translates to:
  /// **'Authorize deploying {tickerLabel}'**
  String launch2Creator_launch2SignLoopSignFact(Object? tickerLabel);

  /// lib/features/launch2/creator/launch2_sign_screen.dart:519
  ///
  /// In en, this message translates to:
  /// **'Signing wallet'**
  String get launch2Creator_launch2SignLoopSignFact2;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:521
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get launch2Creator_launch2SignLoopSignFact3;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:521
  ///
  /// In en, this message translates to:
  /// **'None (signature only, no transaction)'**
  String get launch2Creator_launch2SignLoopSignFact4;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:262, lib/features/launch2/creator/launch2_sign_screen.dart:518
  ///
  /// In en, this message translates to:
  /// **'Token address'**
  String get launch2Creator_launch2SignReady;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:154
  ///
  /// In en, this message translates to:
  /// **'Waiting for wallet signature…'**
  String get launch2Creator_launch2SignSigning;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:155
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get launch2Creator_launch2SignSubmitting;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:30
  ///
  /// In en, this message translates to:
  /// **'You cancelled the signature in your wallet. Nothing was submitted.'**
  String get launch2Creator_launch2SignSwitch;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:31
  ///
  /// In en, this message translates to:
  /// **'This signing request belongs to another wallet. Switch to the project owner\'s wallet.'**
  String get launch2Creator_launch2SignSwitch2;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:32
  ///
  /// In en, this message translates to:
  /// **'The signing request is for the wrong network. Nothing was signed.'**
  String get launch2Creator_launch2SignSwitch3;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:33
  ///
  /// In en, this message translates to:
  /// **'The embedded wallet isn\'t available. Sign in again and retry.'**
  String get launch2Creator_launch2SignSwitch4;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:34
  ///
  /// In en, this message translates to:
  /// **'The wallet didn\'t finish signing. Nothing was submitted.'**
  String get launch2Creator_launch2SignSwitch5;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:346
  ///
  /// In en, this message translates to:
  /// **'This is an authorization signature and spends nothing. The platform deploys and activates once it receives it; progress is on the next page.'**
  String get launch2Creator_launch2SignText;

  /// lib/features/launch2/creator/launch2_sign_screen.dart:440
  ///
  /// In en, this message translates to:
  /// **'Expires in {minutes}:{seconds}'**
  String launch2Creator_launch2SignValue(Object? minutes, Object? seconds);

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:93
  ///
  /// In en, this message translates to:
  /// **'The signature expired. Sign and submit again.'**
  String get launch2Creator_launch2Switch;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:108
  ///
  /// In en, this message translates to:
  /// **'The platform is processing and will retry automatically.'**
  String get launch2Creator_launch2Switch10;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:109
  ///
  /// In en, this message translates to:
  /// **'The deployment didn\'t finish. Contact the platform.'**
  String get launch2Creator_launch2Switch11;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:130
  ///
  /// In en, this message translates to:
  /// **'Edit name or ticker'**
  String get launch2Creator_launch2Switch12;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:131
  ///
  /// In en, this message translates to:
  /// **'Edit mint start time'**
  String get launch2Creator_launch2Switch13;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:139
  ///
  /// In en, this message translates to:
  /// **'On-chain, awaiting confirmation'**
  String get launch2Creator_launch2Switch14;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:143
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get launch2Creator_launch2Switch15;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:151
  ///
  /// In en, this message translates to:
  /// **'Signature verified and recorded'**
  String get launch2Creator_launch2Switch16;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:152
  ///
  /// In en, this message translates to:
  /// **'Claimed by executor'**
  String get launch2Creator_launch2Switch17;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:153
  ///
  /// In en, this message translates to:
  /// **'Deploy transaction broadcast'**
  String get launch2Creator_launch2Switch18;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:154
  ///
  /// In en, this message translates to:
  /// **'Transaction included'**
  String get launch2Creator_launch2Switch19;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:94
  ///
  /// In en, this message translates to:
  /// **'The configuration was updated. Sign again.'**
  String get launch2Creator_launch2Switch2;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:155
  ///
  /// In en, this message translates to:
  /// **'Deployment confirmed'**
  String get launch2Creator_launch2Switch20;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:156
  ///
  /// In en, this message translates to:
  /// **'Module check passed'**
  String get launch2Creator_launch2Switch21;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:157
  ///
  /// In en, this message translates to:
  /// **'Activation transaction broadcast'**
  String get launch2Creator_launch2Switch22;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:158
  ///
  /// In en, this message translates to:
  /// **'Activation transaction included'**
  String get launch2Creator_launch2Switch23;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:160
  ///
  /// In en, this message translates to:
  /// **'Chain reorg, reconfirming'**
  String get launch2Creator_launch2Switch24;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:163
  ///
  /// In en, this message translates to:
  /// **'Status update'**
  String get launch2Creator_launch2Switch25;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:95
  ///
  /// In en, this message translates to:
  /// **'The configuration approval lapsed. Sign again after the platform approves.'**
  String get launch2Creator_launch2Switch3;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:96
  ///
  /// In en, this message translates to:
  /// **'Invalid signature. Sign again.'**
  String get launch2Creator_launch2Switch4;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:97
  ///
  /// In en, this message translates to:
  /// **'The wallet nonce changed. Sign again.'**
  String get launch2Creator_launch2Switch5;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:98
  ///
  /// In en, this message translates to:
  /// **'This version is already deployed on-chain. Contact the platform.'**
  String get launch2Creator_launch2Switch6;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:99
  ///
  /// In en, this message translates to:
  /// **'Too close to the mint start to activate. Change the mint start time and submit again.'**
  String get launch2Creator_launch2Switch7;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:103
  ///
  /// In en, this message translates to:
  /// **'The name or ticker isn\'t allowed. Edit and submit again.'**
  String get launch2Creator_launch2Switch8;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:104
  ///
  /// In en, this message translates to:
  /// **'The deployment check didn\'t match, so the project wasn\'t activated. Contact the platform.'**
  String get launch2Creator_launch2Switch9;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:81
  ///
  /// In en, this message translates to:
  /// **'The details were changed elsewhere and have been reloaded. Check them and submit again.'**
  String get launch2Creator_launch2VersionConflict;

  /// lib/features/launch2/creator/launch2_creator_widgets.dart:373
  ///
  /// In en, this message translates to:
  /// **'Project details'**
  String get launch2Creator_projectDetails;

  /// lib/features/launch2/launch2_instance_screen.dart:2179
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get launch2_buybackExecuted;

  /// lib/features/launch2/launch2_candle_chart.dart:462
  ///
  /// In en, this message translates to:
  /// **'candles'**
  String get launch2_candlesCandles;

  /// lib/features/launch2/launch2_candle_chart.dart:462
  ///
  /// In en, this message translates to:
  /// **', graduation marked'**
  String get launch2_candlesGraduationMark;

  /// lib/features/launch2/launch2_candle_chart.dart:462
  ///
  /// In en, this message translates to:
  /// **'close-price line'**
  String get launch2_candlesLine;

  /// lib/features/launch2/launch2_signing.dart:175
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get launch2_intentAction;

  /// lib/features/launch2/launch2_signing.dart:81
  ///
  /// In en, this message translates to:
  /// **'buy'**
  String get launch2_intentNounBuy;

  /// lib/features/launch2/launch2_signing.dart:82
  ///
  /// In en, this message translates to:
  /// **'sell'**
  String get launch2_intentNounSell;

  /// lib/features/launch2/launch2_atmosphere.dart:1136
  ///
  /// In en, this message translates to:
  /// **'Launch a token'**
  String get launch2_launch2AtmosphereActionLabel;

  /// lib/features/launch2/launch2_atmosphere.dart:939, lib/features/launch2/launch2_widgets.dart:346
  ///
  /// In en, this message translates to:
  /// **'{prefix}TBD'**
  String launch2_launch2AtmosphereBuild(Object? prefix);

  /// lib/features/launch2/launch2_atmosphere.dart:968, lib/features/launch2/launch2_hero.dart:233, lib/features/launch2/launch2_instance_parts.dart:44, lib/features/launch2/launch2_nft_screen.dart:121
  ///
  /// In en, this message translates to:
  /// **'Mint in '**
  String get launch2_launch2AtmosphereCountdown;

  /// lib/features/launch2/launch2_atmosphere.dart:971, lib/features/launch2/launch2_hero.dart:233, lib/features/launch2/launch2_instance_parts.dart:44, lib/features/launch2/launch2_nft_screen.dart:74, lib/features/launch2/launch2_widgets.dart:372
  ///
  /// In en, this message translates to:
  /// **'Ends in '**
  String get launch2_launch2AtmosphereCountdown2;

  /// lib/features/launch2/launch2_atmosphere.dart:224
  ///
  /// In en, this message translates to:
  /// **'Live trades, no trades yet'**
  String get launch2_launch2AtmosphereIf;

  /// lib/features/launch2/launch2_atmosphere.dart:287
  ///
  /// In en, this message translates to:
  /// **'All live trades'**
  String get launch2_launch2AtmosphereLaunch2TickerAllLabel;

  /// lib/features/launch2/launch2_atmosphere.dart:261
  ///
  /// In en, this message translates to:
  /// **'No trades yet'**
  String get launch2_launch2AtmosphereLaunch2TickerEmpty;

  /// lib/features/launch2/launch2_atmosphere.dart:1134
  ///
  /// In en, this message translates to:
  /// **'No projects in the queue yet'**
  String get launch2_launch2AtmosphereMessage;

  /// lib/features/launch2/launch2_atmosphere.dart:225
  ///
  /// In en, this message translates to:
  /// **'Live trades, {items}'**
  String launch2_launch2AtmosphereS(Object? items);

  /// lib/features/launch2/launch2_atmosphere.dart:970, lib/features/launch2/launch2_atmosphere.dart:974, lib/features/launch2/launch2_widgets.dart:208, lib/features/launch2/launch2_widgets.dart:372, lib/features/launch2/launch2_widgets.dart:374
  ///
  /// In en, this message translates to:
  /// **'Minted {soldCount}'**
  String launch2_launch2AtmosphereSwitch(Object? soldCount);

  /// lib/features/launch2/launch2_atmosphere.dart:975, lib/features/launch2/launch2_format.dart:25, lib/features/launch2/launch2_format.dart:588, lib/features/launch2/launch2_hero.dart:94, lib/features/launch2/launch2_launchpad.dart:95, lib/features/launch2/launch2_widgets.dart:375
  ///
  /// In en, this message translates to:
  /// **'Building allowlist'**
  String get launch2_launch2AtmosphereSwitch2;

  /// lib/features/launch2/launch2_atmosphere.dart:989, lib/features/launch2/launch2_widgets.dart:405
  ///
  /// In en, this message translates to:
  /// **'Platform checking'**
  String get launch2_launch2AtmosphereSwitch3;

  /// lib/features/launch2/launch2_atmosphere.dart:412
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get launch2_launch2AtmosphereText;

  /// lib/features/launch2/launch2_widgets.dart:720
  ///
  /// In en, this message translates to:
  /// **'Allowlist addresses aren\'t listed in the app; check them in the publish transaction.'**
  String get launch2_launch2Build;

  /// lib/features/launch2/launch2_campaigns.dart:70
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get launch2_launch2CampaignsLaunch2CampaignDefaultCta;

  /// lib/features/launch2/launch2_campaigns.dart:178
  ///
  /// In en, this message translates to:
  /// **'{monthDay} – {monthDay2}'**
  String launch2_launch2CampaignsLaunch2CampaignKicker(
    Object? monthDay,
    Object? monthDay2,
  );

  /// lib/features/launch2/launch2_campaigns.dart:188
  ///
  /// In en, this message translates to:
  /// **'Starts {monthDay}'**
  String launch2_launch2CampaignsLaunch2CampaignStamp(Object? monthDay);

  /// lib/features/launch2/launch2_campaigns.dart:191
  ///
  /// In en, this message translates to:
  /// **'Ends today'**
  String get launch2_launch2CampaignsLaunch2CampaignStamp2;

  /// lib/features/launch2/launch2_campaigns.dart:192
  ///
  /// In en, this message translates to:
  /// **'{inDays}d left'**
  String launch2_launch2CampaignsLaunch2CampaignStamp3(Object? inDays);

  /// lib/features/launch2/launch2_campaigns.dart:218
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the browser. Link copied'**
  String get launch2_launch2CampaignsMessage;

  /// lib/features/launch2/launch2_candle_chart.dart:53
  ///
  /// In en, this message translates to:
  /// **'No trades yet. Candles appear after the first trade'**
  String get launch2_launch2CandleChartLaunch2CandlesEmptyText;

  /// lib/features/launch2/launch2_candle_chart.dart:380
  ///
  /// In en, this message translates to:
  /// **'Open full-screen chart'**
  String get launch2_launch2CandleChartLaunch2CandlesExpandLabel;

  /// lib/features/launch2/launch2_candle_chart.dart:56
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load candles. Tap to retry'**
  String get launch2_launch2CandleChartLaunch2CandlesFailedText;

  /// lib/features/launch2/launch2_candle_chart.dart:461
  ///
  /// In en, this message translates to:
  /// **'{candles} {label} {line}, in USD1{mark}'**
  String launch2_launch2CandleChartSemanticLabel(
    Object? candles,
    Object? label,
    Object? line,
    Object? mark,
  );

  /// lib/features/launch2/launch2_candle_models.dart:11
  ///
  /// In en, this message translates to:
  /// **'15m'**
  String get launch2_launch2CandleModelsFifteenMinutes;

  /// lib/features/launch2/launch2_candle_models.dart:10
  ///
  /// In en, this message translates to:
  /// **'5m'**
  String get launch2_launch2CandleModelsFiveMinutes;

  /// lib/features/launch2/launch2_candle_models.dart:13
  ///
  /// In en, this message translates to:
  /// **'4h'**
  String get launch2_launch2CandleModelsFourHours;

  /// lib/features/launch2/launch2_candle_models.dart:14
  ///
  /// In en, this message translates to:
  /// **'1D'**
  String get launch2_launch2CandleModelsOneDay;

  /// lib/features/launch2/launch2_candle_models.dart:12
  ///
  /// In en, this message translates to:
  /// **'1h'**
  String get launch2_launch2CandleModelsOneHour;

  /// lib/features/launch2/launch2_candle_models.dart:9
  ///
  /// In en, this message translates to:
  /// **'1m'**
  String get launch2_launch2CandleModelsOneMinute;

  /// lib/features/launch2/launch2_widgets.dart:357
  ///
  /// In en, this message translates to:
  /// **'Mint '**
  String get launch2_launch2Countdown;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:295
  ///
  /// In en, this message translates to:
  /// **'DEX pool trading and rewards for this project aren\'t available right now.'**
  String get launch2_launch2DynamicPoolImpact;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:194
  ///
  /// In en, this message translates to:
  /// **'Buy base tax total'**
  String get launch2_launch2DynamicPoolLabel;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:170
  ///
  /// In en, this message translates to:
  /// **'The drop is measured on 5-minute candles; buyback buys don\'t earn reward weight.'**
  String get launch2_launch2DynamicPoolLaunch2DynProvenanceDetail;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:92, lib/features/launch2/launch2_instance_parts.dart:557
  ///
  /// In en, this message translates to:
  /// **'This round'**
  String get launch2_launch2DynamicPoolLaunch2DynRewardsLink;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:102, lib/features/launch2/launch2_dynamic_pool_widgets.dart:118
  ///
  /// In en, this message translates to:
  /// **'My rewards'**
  String get launch2_launch2DynamicPoolLaunch2DynRewardsLinkLabel;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:21
  ///
  /// In en, this message translates to:
  /// **'Ends on the first 5-minute candle that closes at or above its open (up, flat or no trades all count)'**
  String get launch2_launch2DynamicPoolLaunch2DynamicEndText;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:219
  ///
  /// In en, this message translates to:
  /// **'Dynamic tax total'**
  String get launch2_launch2DynamicPoolLaunch2DynamicFeeRows;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:224
  ///
  /// In en, this message translates to:
  /// **'Sell base tax total'**
  String get launch2_launch2DynamicPoolLaunch2DynamicFeeRows2;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:18
  ///
  /// In en, this message translates to:
  /// **'A drop of more than 10% within 5 minutes turns on dynamic tax and buy rewards'**
  String get launch2_launch2DynamicPoolLaunch2DynamicIdleText;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:33
  ///
  /// In en, this message translates to:
  /// **'Reward pool'**
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:40
  ///
  /// In en, this message translates to:
  /// **'Current drop'**
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows2;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:43, lib/features/launch2/launch2_instance_parts.dart:516
  ///
  /// In en, this message translates to:
  /// **'Candle closed, awaiting settlement'**
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows3;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:48
  ///
  /// In en, this message translates to:
  /// **'My weight this round'**
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows4;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:58
  ///
  /// In en, this message translates to:
  /// **'{launch2Usd1Label} · {formatDecimal}% share'**
  String launch2_launch2DynamicPoolLaunch2DynamicRoundRows5(
    Object? formatDecimal,
    Object? launch2Usd1Label,
  );

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:61
  ///
  /// In en, this message translates to:
  /// **'This candle ends'**
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows6;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:62
  ///
  /// In en, this message translates to:
  /// **'End condition'**
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows7;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:248
  ///
  /// In en, this message translates to:
  /// **'Fees collected'**
  String get launch2_launch2DynamicPoolLaunch2SectionLabel;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:94, lib/features/launch2/launch2_instance_parts.dart:562
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get launch2_launch2DynamicPoolLoopBadge;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:296
  ///
  /// In en, this message translates to:
  /// **'Tap Retry later to load again.'**
  String get launch2_launch2DynamicPoolNext;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:94, lib/features/launch2/launch2_instance_parts.dart:562
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get launch2_launch2DynamicPoolS;

  /// lib/features/launch2/launch2_dynamic_pool_widgets.dart:293
  ///
  /// In en, this message translates to:
  /// **'DEX pool unavailable'**
  String get launch2_launch2DynamicPoolTitle;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:652
  ///
  /// In en, this message translates to:
  /// **'You haven\'t bought this round'**
  String get launch2_launch2DynamicRewardsBuild;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:657
  ///
  /// In en, this message translates to:
  /// **'Buys while the round is open count toward its weight. Claim here after it ends.'**
  String get launch2_launch2DynamicRewardsBuild2;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:91
  ///
  /// In en, this message translates to:
  /// **'DEX pool rewards claimed and confirmed on-chain.'**
  String get launch2_launch2DynamicRewardsConfirmedText;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:220
  ///
  /// In en, this message translates to:
  /// **'Claim submitted ({launch2ShortAddress}), waiting for on-chain confirmation. Don\'t claim again.'**
  String launch2_launch2DynamicRewardsConfirmedText2(
    Object? launch2ShortAddress,
  );

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:517, lib/features/launch2/launch2_instance_screen.dart:597, lib/features/launch2/launch2_nft_screen.dart:577, lib/features/launch2/launch2_pool_view_model.dart:413, lib/features/launch2/launch2_trade_panel.dart:529
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get launch2_launch2DynamicRewardsLabel;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:519
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get launch2_launch2DynamicRewardsLabel2;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:521
  ///
  /// In en, this message translates to:
  /// **'Confirming claim…'**
  String get launch2_launch2DynamicRewardsLabel3;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:559
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get launch2_launch2DynamicRewardsLabel4;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:565
  ///
  /// In en, this message translates to:
  /// **'My weight / total weight'**
  String get launch2_launch2DynamicRewardsLabel5;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:573
  ///
  /// In en, this message translates to:
  /// **'Round rewards'**
  String get launch2_launch2DynamicRewardsLabel6;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:581
  ///
  /// In en, this message translates to:
  /// **'Claimable'**
  String get launch2_launch2DynamicRewardsLabel7;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:587
  ///
  /// In en, this message translates to:
  /// **'Claimed so far'**
  String get launch2_launch2DynamicRewardsLabel8;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:330, lib/features/launch2/launch2_full_chart_screen.dart:98, lib/features/launch2/launch2_instance_screen.dart:524, lib/features/launch2/launch2_nft_screen.dart:541
  ///
  /// In en, this message translates to:
  /// **'MEME v2 isn\'t available right now'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsBlockedTitle;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:438
  ///
  /// In en, this message translates to:
  /// **'{launch2DynamicIdleText}. Once on, buys from any app count toward the round\'s weight. Claim here after it ends.'**
  String launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyMessage(
    Object? launch2DynamicIdleText,
  );

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:437
  ///
  /// In en, this message translates to:
  /// **'No DEX pool rewards yet'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyTitle;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:252, lib/features/launch2/launch2_full_chart_screen.dart:79, lib/features/launch2/launch2_instance_screen.dart:467, lib/features/launch2/launch2_nft_screen.dart:497
  ///
  /// In en, this message translates to:
  /// **'Nothing was requested and no other project was loaded instead.'**
  String
  get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityMessage;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:251, lib/features/launch2/launch2_full_chart_screen.dart:78, lib/features/launch2/launch2_instance_screen.dart:466, lib/features/launch2/launch2_nft_screen.dart:496
  ///
  /// In en, this message translates to:
  /// **'The route has no usable project ID'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityTitle;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:245, lib/features/launch2/launch2_dynamic_rewards_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'DEX pool rewards'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidRouteTitle;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:400
  ///
  /// In en, this message translates to:
  /// **'DEX pool rewards are recorded per wallet. Activate a wallet to view and claim.'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletMessage;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:399
  ///
  /// In en, this message translates to:
  /// **'No wallet available'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletTitle;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:359
  ///
  /// In en, this message translates to:
  /// **'Only projects with dynamic tax have per-round DEX pool rewards.'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoneMessage;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:358
  ///
  /// In en, this message translates to:
  /// **'This project has no DEX pool rewards'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoneTitle;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:475
  ///
  /// In en, this message translates to:
  /// **'Weight is each wallet\'s buy amount this round (USD1); buyback buys don\'t count. Claims follow on-chain confirmation.'**
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsProvenanceDetail;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:620, lib/features/launch2/launch2_pool_view_model.dart:130
  ///
  /// In en, this message translates to:
  /// **'No rewards to claim this round'**
  String get launch2_launch2DynamicRewardsLaunch2DynamicNoRewardText;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:542, lib/features/launch2/launch2_dynamic_rewards_screen.dart:639
  ///
  /// In en, this message translates to:
  /// **'Round {id}'**
  String launch2_launch2DynamicRewardsLaunch2SectionLabel(Object? id);

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:523
  ///
  /// In en, this message translates to:
  /// **'Claimable after the round ends'**
  String get launch2_launch2DynamicRewardsOpen;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:123
  ///
  /// In en, this message translates to:
  /// **'Broadcast, but no confirmation yet. It may still be confirming; check again later. Don\'t claim again.'**
  String get launch2_launch2DynamicRewardsPending;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:371, lib/features/launch2/launch2_instance_screen.dart:557, lib/features/launch2/launch2_pool_view_model.dart:118
  ///
  /// In en, this message translates to:
  /// **'The DEX pool is syncing. Try again later'**
  String get launch2_launch2DynamicRewardsReason;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:525
  ///
  /// In en, this message translates to:
  /// **'Nothing to claim'**
  String get launch2_launch2DynamicRewardsS;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:657
  ///
  /// In en, this message translates to:
  /// **'You didn\'t buy this round, so you have no reward weight.'**
  String get launch2_launch2DynamicRewardsS2;

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:513
  ///
  /// In en, this message translates to:
  /// **'From {start} · in progress'**
  String launch2_launch2DynamicRewardsSpan(Object? start);

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:512
  ///
  /// In en, this message translates to:
  /// **'Candle #{startCandle}'**
  String launch2_launch2DynamicRewardsStart(Object? startCandle);

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:222
  ///
  /// In en, this message translates to:
  /// **'Reporting {text} failed; the on-chain result isn\'t affected. Don\'t claim again.'**
  String launch2_launch2DynamicRewardsText(Object? text);

  /// lib/features/launch2/launch2_dynamic_rewards_screen.dart:575
  ///
  /// In en, this message translates to:
  /// **'Settled after the round ends'**
  String get launch2_launch2DynamicRewardsValue;

  /// lib/features/launch2/launch2_format.dart:139
  ///
  /// In en, this message translates to:
  /// **'No activation record on-chain yet; the platform is checking'**
  String get launch2_launch2FormatActivationMissing;

  /// lib/features/launch2/launch2_format.dart:178
  ///
  /// In en, this message translates to:
  /// **'Wallet balance'**
  String get launch2_launch2FormatBalance;

  /// lib/features/launch2/launch2_format.dart:590
  ///
  /// In en, this message translates to:
  /// **'Publishing allowlist'**
  String get launch2_launch2FormatBroadcast;

  /// lib/features/launch2/launch2_format.dart:180
  ///
  /// In en, this message translates to:
  /// **'Trading closed at this stage'**
  String get launch2_launch2FormatClosed;

  /// lib/features/launch2/launch2_format.dart:26
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get launch2_launch2FormatClosedNoHolders;

  /// lib/features/launch2/launch2_format.dart:138
  ///
  /// In en, this message translates to:
  /// **'The on-chain deploy record doesn\'t match the registration; the platform is checking'**
  String get launch2_launch2FormatDeployedEventMismatch;

  /// lib/features/launch2/launch2_format.dart:52
  ///
  /// In en, this message translates to:
  /// **'Trading in the official pool'**
  String get launch2_launch2FormatGraduated;

  /// lib/features/launch2/launch2_format.dart:177
  ///
  /// In en, this message translates to:
  /// **'Bonding pool stock left'**
  String get launch2_launch2FormatInventory;

  /// lib/features/launch2/launch2_format.dart:556
  ///
  /// In en, this message translates to:
  /// **'Not enough USD1: {parts}'**
  String launch2_launch2FormatLaunch2ActionFailure(Object? parts);

  /// lib/features/launch2/launch2_format.dart:571
  ///
  /// In en, this message translates to:
  /// **'Sell amount exceeds holdings: {parts}'**
  String launch2_launch2FormatLaunch2ActionFailure2(Object? parts);

  /// lib/features/launch2/launch2_format.dart:367
  ///
  /// In en, this message translates to:
  /// **'The USD1 issuer has restricted this project\'s contract address; trading and claims are unavailable'**
  String get launch2_launch2FormatLaunch2AddressFrozenText;

  /// lib/features/launch2/launch2_format.dart:324
  ///
  /// In en, this message translates to:
  /// **'Source: chain read · auto buyback'**
  String get launch2_launch2FormatLaunch2BuybackHeldLine;

  /// lib/features/launch2/launch2_format.dart:38
  ///
  /// In en, this message translates to:
  /// **'No one minted, closed'**
  String get launch2_launch2FormatLaunch2ClosedNoHoldersText;

  /// lib/features/launch2/launch2_format.dart:65
  ///
  /// In en, this message translates to:
  /// **'{days}d {two}:{two2}:{two3}'**
  String launch2_launch2FormatLaunch2CountdownText(
    Object? days,
    Object? two,
    Object? two2,
    Object? two3,
  );

  /// lib/features/launch2/launch2_format.dart:166
  ///
  /// In en, this message translates to:
  /// **'Each address can buy up to {launch2CurveCapFigure} tokens'**
  String launch2_launch2FormatLaunch2CurveCapSentence(
    Object? launch2CurveCapFigure,
  );

  /// lib/features/launch2/launch2_format.dart:502
  ///
  /// In en, this message translates to:
  /// **'this needs about {bnb}'**
  String launch2_launch2FormatLaunch2GasFailureText(Object? bnb);

  /// lib/features/launch2/launch2_format.dart:503
  ///
  /// In en, this message translates to:
  /// **'wallet has {bnb}'**
  String launch2_launch2FormatLaunch2GasFailureText2(Object? bnb);

  /// lib/features/launch2/launch2_format.dart:505
  ///
  /// In en, this message translates to:
  /// **'Not enough {loopLaunchNativeSymbolText} for fees: {parts}. Top up and retry'**
  String launch2_launch2FormatLaunch2GasFailureText3(
    Object? loopLaunchNativeSymbolText,
    Object? parts,
  );

  /// lib/features/launch2/launch2_format.dart:489
  ///
  /// In en, this message translates to:
  /// **'Not enough {loopLaunchNativeSymbolText} for fees: your wallet\'s {loopLaunchNativeSymbolText2} can\'t cover this network fee. Top up and retry'**
  String launch2_launch2FormatLaunch2GasShortText(
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchNativeSymbolText2,
  );

  /// lib/features/launch2/launch2_format.dart:247
  ///
  /// In en, this message translates to:
  /// **'Auto buyback running'**
  String get launch2_launch2FormatLaunch2KeeperLine;

  /// lib/features/launch2/launch2_format.dart:248
  ///
  /// In en, this message translates to:
  /// **'One on its way on-chain'**
  String get launch2_launch2FormatLaunch2KeeperLine2;

  /// lib/features/launch2/launch2_format.dart:249
  ///
  /// In en, this message translates to:
  /// **'Last {dateTimeLabel}'**
  String launch2_launch2FormatLaunch2KeeperLine3(Object? dateTimeLabel);

  /// lib/features/launch2/launch2_format.dart:263
  ///
  /// In en, this message translates to:
  /// **'Buyback on hold: {reason}'**
  String launch2_launch2FormatLaunch2KeeperLine4(Object? reason);

  /// lib/features/launch2/launch2_format.dart:264, lib/features/launch2/launch2_format.dart:317
  ///
  /// In en, this message translates to:
  /// **'Retry at {clockLabel}'**
  String launch2_launch2FormatLaunch2KeeperLine5(Object? clockLabel);

  /// lib/features/launch2/launch2_format.dart:409
  ///
  /// In en, this message translates to:
  /// **'You don\'t hold this token yet'**
  String get launch2_launch2FormatLaunch2NoMemeText;

  /// lib/features/launch2/launch2_format.dart:406
  ///
  /// In en, this message translates to:
  /// **'No USD1 in your wallet yet'**
  String get launch2_launch2FormatLaunch2NoUsd1Text;

  /// lib/features/launch2/launch2_format.dart:42
  ///
  /// In en, this message translates to:
  /// **'No NFT holders, public pool opened directly'**
  String get launch2_launch2FormatLaunch2OpenedWithoutHoldersText;

  /// lib/features/launch2/launch2_format.dart:170
  ///
  /// In en, this message translates to:
  /// **'Used up the per-address cap of {launch2CurveCapFigure} tokens'**
  String launch2_launch2FormatLaunch2QuotaExhaustedText(
    Object? launch2CurveCapFigure,
  );

  /// lib/features/launch2/launch2_format.dart:389
  ///
  /// In en, this message translates to:
  /// **'This amount can\'t buy the smallest unit. Try another amount'**
  String get launch2_launch2FormatLaunch2QuoteZeroText;

  /// lib/features/launch2/launch2_format.dart:651
  ///
  /// In en, this message translates to:
  /// **'{hours}d'**
  String launch2_launch2FormatLaunch2SaleDurationLabel(Object? hours);

  /// lib/features/launch2/launch2_format.dart:652
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String launch2_launch2FormatLaunch2SaleDurationLabel2(Object? hours);

  /// lib/features/launch2/launch2_format.dart:653
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String launch2_launch2FormatLaunch2SaleDurationLabel3(Object? minutes);

  /// lib/features/launch2/launch2_format.dart:609
  ///
  /// In en, this message translates to:
  /// **'Waiting for the cutoff block; the 1-hour priority buy starts once the allowlist is published'**
  String get launch2_launch2FormatLaunch2SnapshotPendingMessage;

  /// lib/features/launch2/launch2_format.dart:610
  ///
  /// In en, this message translates to:
  /// **'Cutoff block #{groupedFigure}; the 1-hour priority buy starts once the allowlist is published'**
  String launch2_launch2FormatLaunch2SnapshotPendingMessage2(
    Object? groupedFigure,
  );

  /// lib/features/launch2/launch2_format.dart:663
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String launch2_launch2FormatLaunch2SpokenDuration(
    Object? days,
    Object? hours,
  );

  /// lib/features/launch2/launch2_format.dart:664
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String launch2_launch2FormatLaunch2SpokenDuration2(
    Object? hours,
    Object? minutes,
  );

  /// lib/features/launch2/launch2_format.dart:665
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String launch2_launch2FormatLaunch2SpokenDuration3(Object? minutes);

  /// lib/features/launch2/launch2_format.dart:666
  ///
  /// In en, this message translates to:
  /// **'Under 1m'**
  String get launch2_launch2FormatLaunch2SpokenDuration4;

  /// lib/features/launch2/launch2_format.dart:383
  ///
  /// In en, this message translates to:
  /// **'Since {localClockLabel}'**
  String launch2_launch2FormatLaunch2TradingHoldSinceText(
    Object? localClockLabel,
  );

  /// lib/features/launch2/launch2_format.dart:366
  ///
  /// In en, this message translates to:
  /// **'The USD1 issuer has paused USD1; trading and claims are unavailable'**
  String get launch2_launch2FormatLaunch2Usd1PausedText;

  /// lib/features/launch2/launch2_format.dart:594
  ///
  /// In en, this message translates to:
  /// **'Allowlist publish issue; the platform is handling it'**
  String get launch2_launch2FormatMismatch;

  /// lib/features/launch2/launch2_format.dart:631
  ///
  /// In en, this message translates to:
  /// **'Check mismatch; the platform is handling it'**
  String get launch2_launch2FormatMismatch2;

  /// lib/features/launch2/launch2_format.dart:24, lib/features/launch2/launch2_launchpad.dart:92, lib/features/launch2/launch2_launchpad.dart:130, lib/features/launch2/launch2_nft_screen.dart:133
  ///
  /// In en, this message translates to:
  /// **'Minting'**
  String get launch2_launch2FormatNftSale;

  /// lib/features/launch2/launch2_format.dart:47
  ///
  /// In en, this message translates to:
  /// **'Time left'**
  String get launch2_launch2FormatNftSale2;

  /// lib/features/launch2/launch2_format.dart:53
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get launch2_launch2FormatPaused;

  /// lib/features/launch2/launch2_format.dart:630
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get launch2_launch2FormatPending;

  /// lib/features/launch2/launch2_format.dart:27, lib/features/launch2/launch2_launchpad.dart:93, lib/features/launch2/launch2_trade_panel.dart:552
  ///
  /// In en, this message translates to:
  /// **'Priority buy'**
  String get launch2_launch2FormatPriority;

  /// lib/features/launch2/launch2_format.dart:50
  ///
  /// In en, this message translates to:
  /// **'Holders first · time left'**
  String get launch2_launch2FormatPriority2;

  /// lib/features/launch2/launch2_format.dart:28, lib/features/launch2/launch2_hero.dart:96, lib/features/launch2/launch2_hero.dart:247, lib/features/launch2/launch2_trade_panel.dart:552
  ///
  /// In en, this message translates to:
  /// **'Public pool'**
  String get launch2_launch2FormatPublic;

  /// lib/features/launch2/launch2_format.dart:51
  ///
  /// In en, this message translates to:
  /// **'Open to all; graduates when sold out'**
  String get launch2_launch2FormatPublic2;

  /// lib/features/launch2/launch2_format.dart:176
  ///
  /// In en, this message translates to:
  /// **'Per-address cap {launch2CurveCapFigure} tokens'**
  String launch2_launch2FormatQuota(Object? launch2CurveCapFigure);

  /// lib/features/launch2/launch2_format.dart:323
  ///
  /// In en, this message translates to:
  /// **'Next one on hold: {live}'**
  String launch2_launch2FormatReason(Object? live);

  /// lib/features/launch2/launch2_format.dart:328
  ///
  /// In en, this message translates to:
  /// **'Next one on hold: {live} (on-chain read); {reason} (auto buyback)'**
  String launch2_launch2FormatReason2(Object? live, Object? reason);

  /// lib/features/launch2/launch2_format.dart:314
  ///
  /// In en, this message translates to:
  /// **', on hold'**
  String get launch2_launch2FormatReplaceAll;

  /// lib/features/launch2/launch2_format.dart:315
  ///
  /// In en, this message translates to:
  /// **', runs shortly'**
  String get launch2_launch2FormatReplaceAll2;

  /// lib/features/launch2/launch2_format.dart:162
  ///
  /// In en, this message translates to:
  /// **'taken from the MEME you receive'**
  String get launch2_launch2FormatS;

  /// lib/features/launch2/launch2_format.dart:384
  ///
  /// In en, this message translates to:
  /// **'Since {localTimestampLabel}'**
  String launch2_launch2FormatS2(Object? localTimestampLabel);

  /// lib/features/launch2/launch2_format.dart:592
  ///
  /// In en, this message translates to:
  /// **'Allowlist on-chain, syncing'**
  String get launch2_launch2FormatS3;

  /// lib/features/launch2/launch2_format.dart:663
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String launch2_launch2FormatS4(Object? days);

  /// lib/features/launch2/launch2_format.dart:48
  ///
  /// In en, this message translates to:
  /// **'1-hour priority buy starts once the allowlist is published'**
  String get launch2_launch2FormatSnapshotPending;

  /// lib/features/launch2/launch2_format.dart:179
  ///
  /// In en, this message translates to:
  /// **'Bonding pool sellable amount'**
  String get launch2_launch2FormatSoldSupply;

  /// lib/features/launch2/launch2_format.dart:140
  ///
  /// In en, this message translates to:
  /// **'The platform is checking this project'**
  String get launch2_launch2FormatSwitch;

  /// lib/features/launch2/launch2_format.dart:194
  ///
  /// In en, this message translates to:
  /// **'Legacy price protection active, on hold'**
  String get launch2_launch2FormatSwitch10;

  /// lib/features/launch2/launch2_format.dart:195, lib/features/launch2/launch2_format.dart:351
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get launch2_launch2FormatSwitch11;

  /// lib/features/launch2/launch2_format.dart:337
  ///
  /// In en, this message translates to:
  /// **'Official pool principal protection: principal under 10,000 USD1 or one order over 1%'**
  String get launch2_launch2FormatSwitch12;

  /// lib/features/launch2/launch2_format.dart:339, lib/features/launch2/launch2_format.dart:356
  ///
  /// In en, this message translates to:
  /// **'Contract buyback paused'**
  String get launch2_launch2FormatSwitch13;

  /// lib/features/launch2/launch2_format.dart:340
  ///
  /// In en, this message translates to:
  /// **'The project hasn\'t graduated yet'**
  String get launch2_launch2FormatSwitch14;

  /// lib/features/launch2/launch2_format.dart:343
  ///
  /// In en, this message translates to:
  /// **'Buyback executor account isn\'t ready; the platform is handling it'**
  String get launch2_launch2FormatSwitch15;

  /// lib/features/launch2/launch2_format.dart:344
  ///
  /// In en, this message translates to:
  /// **'Escrow records don\'t match the chain; the platform is checking'**
  String get launch2_launch2FormatSwitch16;

  /// lib/features/launch2/launch2_format.dart:345
  ///
  /// In en, this message translates to:
  /// **'The trade received 0; the platform is handling it'**
  String get launch2_launch2FormatSwitch17;

  /// lib/features/launch2/launch2_format.dart:348
  ///
  /// In en, this message translates to:
  /// **'Legacy price protection active'**
  String get launch2_launch2FormatSwitch18;

  /// lib/features/launch2/launch2_format.dart:349
  ///
  /// In en, this message translates to:
  /// **'On-chain fees too high'**
  String get launch2_launch2FormatSwitch19;

  /// lib/features/launch2/launch2_format.dart:162
  ///
  /// In en, this message translates to:
  /// **'taken from the USD1 you pay'**
  String get launch2_launch2FormatSwitch2;

  /// lib/features/launch2/launch2_format.dart:350
  ///
  /// In en, this message translates to:
  /// **'The contract refused to execute; the platform is handling it'**
  String get launch2_launch2FormatSwitch20;

  /// lib/features/launch2/launch2_format.dart:357
  ///
  /// In en, this message translates to:
  /// **'The executor account is short on fees; the platform is handling it'**
  String get launch2_launch2FormatSwitch21;

  /// lib/features/launch2/launch2_format.dart:358
  ///
  /// In en, this message translates to:
  /// **'On-chain fees too high; retrying later'**
  String get launch2_launch2FormatSwitch22;

  /// lib/features/launch2/launch2_format.dart:359
  ///
  /// In en, this message translates to:
  /// **'The last one didn\'t execute; retrying later'**
  String get launch2_launch2FormatSwitch23;

  /// lib/features/launch2/launch2_format.dart:414, lib/features/launch2/launch2_full_chart_screen.dart:131, lib/features/launch2/launch2_instance_screen.dart:536, lib/features/launch2/launch2_nft_screen.dart:555
  ///
  /// In en, this message translates to:
  /// **'This project doesn\'t exist'**
  String get launch2_launch2FormatSwitch24;

  /// lib/features/launch2/launch2_format.dart:415
  ///
  /// In en, this message translates to:
  /// **'Trading isn\'t open at this stage; the project status was reloaded'**
  String get launch2_launch2FormatSwitch25;

  /// lib/features/launch2/launch2_format.dart:416, lib/features/launch2/launch2_instance_screen.dart:612
  ///
  /// In en, this message translates to:
  /// **'Priority buy is buy-only; selling opens with the public pool'**
  String get launch2_launch2FormatSwitch26;

  /// lib/features/launch2/launch2_format.dart:417
  ///
  /// In en, this message translates to:
  /// **'The bonding pool is sold out'**
  String get launch2_launch2FormatSwitch27;

  /// lib/features/launch2/launch2_format.dart:420
  ///
  /// In en, this message translates to:
  /// **'Used up the per-address buy cap'**
  String get launch2_launch2FormatSwitch28;

  /// lib/features/launch2/launch2_format.dart:421, lib/features/launch2/launch2_instance_screen.dart:798, lib/features/launch2/launch2_nft_screen.dart:206
  ///
  /// In en, this message translates to:
  /// **'The project is paused'**
  String get launch2_launch2FormatSwitch29;

  /// lib/features/launch2/launch2_format.dart:187
  ///
  /// In en, this message translates to:
  /// **'The next one can run'**
  String get launch2_launch2FormatSwitch3;

  /// lib/features/launch2/launch2_format.dart:422
  ///
  /// In en, this message translates to:
  /// **'This wallet already minted the NFT (1 per address, ever)'**
  String get launch2_launch2FormatSwitch30;

  /// lib/features/launch2/launch2_format.dart:423, lib/features/launch2/launch2_pool_view_model.dart:28, lib/features/launch2/launch2_trade_panel.dart:24
  ///
  /// In en, this message translates to:
  /// **'The price changed and was refreshed'**
  String get launch2_launch2FormatSwitch31;

  /// lib/features/launch2/launch2_format.dart:424
  ///
  /// In en, this message translates to:
  /// **'The quote expired and was refreshed'**
  String get launch2_launch2FormatSwitch32;

  /// lib/features/launch2/launch2_format.dart:425
  ///
  /// In en, this message translates to:
  /// **'Not enough USD1'**
  String get launch2_launch2FormatSwitch33;

  /// lib/features/launch2/launch2_format.dart:426
  ///
  /// In en, this message translates to:
  /// **'Sell amount exceeds holdings'**
  String get launch2_launch2FormatSwitch34;

  /// lib/features/launch2/launch2_format.dart:427
  ///
  /// In en, this message translates to:
  /// **'Not enough {loopLaunchNativeSymbolText} for fees. Top up and retry'**
  String launch2_launch2FormatSwitch35(Object? loopLaunchNativeSymbolText);

  /// lib/features/launch2/launch2_format.dart:428, lib/features/launch2/launch2_pool_view_model.dart:151
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get launch2_launch2FormatSwitch36;

  /// lib/features/launch2/launch2_format.dart:429
  ///
  /// In en, this message translates to:
  /// **'Over the buy limit'**
  String get launch2_launch2FormatSwitch37;

  /// lib/features/launch2/launch2_format.dart:430
  ///
  /// In en, this message translates to:
  /// **'The quote changed. Get a new quote'**
  String get launch2_launch2FormatSwitch38;

  /// lib/features/launch2/launch2_format.dart:433
  ///
  /// In en, this message translates to:
  /// **'Only the LOOP built-in wallet can buy'**
  String get launch2_launch2FormatSwitch39;

  /// lib/features/launch2/launch2_format.dart:188, lib/features/launch2/launch2_instance_screen.dart:2095
  ///
  /// In en, this message translates to:
  /// **'Buyback paused'**
  String get launch2_launch2FormatSwitch4;

  /// lib/features/launch2/launch2_format.dart:434
  ///
  /// In en, this message translates to:
  /// **'Priority buy is for allowlisted holders only'**
  String get launch2_launch2FormatSwitch40;

  /// lib/features/launch2/launch2_format.dart:435
  ///
  /// In en, this message translates to:
  /// **'Not available right now'**
  String get launch2_launch2FormatSwitch41;

  /// lib/features/launch2/launch2_format.dart:436
  ///
  /// In en, this message translates to:
  /// **'This transaction expired and nothing was submitted. Start again'**
  String get launch2_launch2FormatSwitch42;

  /// lib/features/launch2/launch2_format.dart:437
  ///
  /// In en, this message translates to:
  /// **'The simulation failed; this transaction would be rejected on-chain'**
  String get launch2_launch2FormatSwitch43;

  /// lib/features/launch2/launch2_format.dart:438
  ///
  /// In en, this message translates to:
  /// **'Approve first; the simulation can\'t run before approval'**
  String get launch2_launch2FormatSwitch44;

  /// lib/features/launch2/launch2_format.dart:439
  ///
  /// In en, this message translates to:
  /// **'Checking the allowlist; priority buy is unavailable'**
  String get launch2_launch2FormatSwitch45;

  /// lib/features/launch2/launch2_format.dart:441
  ///
  /// In en, this message translates to:
  /// **'The MEME v2 contract isn\'t configured yet'**
  String get launch2_launch2FormatSwitch46;

  /// lib/features/launch2/launch2_format.dart:443
  ///
  /// In en, this message translates to:
  /// **'The MEME v2 service isn\'t available right now'**
  String get launch2_launch2FormatSwitch47;

  /// lib/features/launch2/launch2_format.dart:444
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read on-chain data right now'**
  String get launch2_launch2FormatSwitch48;

  /// lib/features/launch2/launch2_format.dart:445
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the wallet directory right now'**
  String get launch2_launch2FormatSwitch49;

  /// lib/features/launch2/launch2_format.dart:189
  ///
  /// In en, this message translates to:
  /// **'Buyback starts after graduation'**
  String get launch2_launch2FormatSwitch5;

  /// lib/features/launch2/launch2_format.dart:446
  ///
  /// In en, this message translates to:
  /// **'Trading is closed for now'**
  String get launch2_launch2FormatSwitch50;

  /// lib/features/launch2/launch2_format.dart:447
  ///
  /// In en, this message translates to:
  /// **'Mainnet signing isn\'t open yet'**
  String get launch2_launch2FormatSwitch51;

  /// lib/features/launch2/launch2_format.dart:448
  ///
  /// In en, this message translates to:
  /// **'MEME v2 isn\'t open yet'**
  String get launch2_launch2FormatSwitch52;

  /// lib/features/launch2/launch2_format.dart:449
  ///
  /// In en, this message translates to:
  /// **'Over the per-transaction limit'**
  String get launch2_launch2FormatSwitch53;

  /// lib/features/launch2/launch2_format.dart:450
  ///
  /// In en, this message translates to:
  /// **'Over today\'s limit'**
  String get launch2_launch2FormatSwitch54;

  /// lib/features/launch2/launch2_format.dart:451
  ///
  /// In en, this message translates to:
  /// **'This transaction isn\'t allowed right now'**
  String get launch2_launch2FormatSwitch55;

  /// lib/features/launch2/launch2_format.dart:549
  ///
  /// In en, this message translates to:
  /// **'need {usd1}'**
  String launch2_launch2FormatSwitch56(Object? usd1);

  /// lib/features/launch2/launch2_format.dart:551
  ///
  /// In en, this message translates to:
  /// **'have {usd1}'**
  String launch2_launch2FormatSwitch57(Object? usd1);

  /// lib/features/launch2/launch2_format.dart:553
  ///
  /// In en, this message translates to:
  /// **'can pay up to {usd1}'**
  String launch2_launch2FormatSwitch58(Object? usd1);

  /// lib/features/launch2/launch2_format.dart:564
  ///
  /// In en, this message translates to:
  /// **'need {meme}'**
  String launch2_launch2FormatSwitch59(Object? meme);

  /// lib/features/launch2/launch2_format.dart:190, lib/features/launch2/launch2_format.dart:338
  ///
  /// In en, this message translates to:
  /// **'Escrow balance below one order'**
  String get launch2_launch2FormatSwitch6;

  /// lib/features/launch2/launch2_format.dart:566
  ///
  /// In en, this message translates to:
  /// **'holding {meme}'**
  String launch2_launch2FormatSwitch60(Object? meme);

  /// lib/features/launch2/launch2_format.dart:568
  ///
  /// In en, this message translates to:
  /// **'can sell up to {meme}'**
  String launch2_launch2FormatSwitch61(Object? meme);

  /// lib/features/launch2/launch2_format.dart:592, lib/features/launch2/launch2_widgets.dart:683
  ///
  /// In en, this message translates to:
  /// **'NFT allowlist published'**
  String get launch2_launch2FormatSwitch62;

  /// lib/features/launch2/launch2_format.dart:191
  ///
  /// In en, this message translates to:
  /// **'Less than 10 seconds since the last one, runs shortly'**
  String get launch2_launch2FormatSwitch7;

  /// lib/features/launch2/launch2_format.dart:192
  ///
  /// In en, this message translates to:
  /// **'Official pool principal protection: principal under 10,000 USD1 or one order over 1%'**
  String get launch2_launch2FormatSwitch8;

  /// lib/features/launch2/launch2_format.dart:193
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the contract quote, on hold'**
  String get launch2_launch2FormatSwitch9;

  /// lib/features/launch2/launch2_format.dart:23
  ///
  /// In en, this message translates to:
  /// **'Minting soon'**
  String get launch2_launch2FormatUpcoming;

  /// lib/features/launch2/launch2_format.dart:46, lib/features/launch2/launch2_hero.dart:92, lib/features/launch2/launch2_nft_screen.dart:119
  ///
  /// In en, this message translates to:
  /// **'Mint countdown'**
  String get launch2_launch2FormatUpcoming2;

  /// lib/features/launch2/launch2_format.dart:629
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get launch2_launch2FormatVerified;

  /// lib/features/launch2/launch2_full_chart_screen.dart:94, lib/features/launch2/launch2_full_chart_screen.dart:121
  ///
  /// In en, this message translates to:
  /// **'Full-screen chart'**
  String get launch2_launch2FullChartLaunch2ChartFullBlockedTitle;

  /// lib/features/launch2/launch2_full_chart_screen.dart:72
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this chart'**
  String get launch2_launch2FullChartLaunch2ChartFullInvalidTitle;

  /// lib/features/launch2/launch2_widgets.dart:213
  ///
  /// In en, this message translates to:
  /// **'Graduation price {launch2PriceLabel}'**
  String launch2_launch2Graduated(Object? launch2PriceLabel);

  /// lib/features/launch2/launch2_hero.dart:272
  ///
  /// In en, this message translates to:
  /// **'{past}% of mint period passed · {launch2HeroDetail}'**
  String launch2_launch2HeroLaunch2RecordFoot(
    Object? launch2HeroDetail,
    Object? past,
  );

  /// lib/features/launch2/launch2_hero.dart:93
  ///
  /// In en, this message translates to:
  /// **'Consensus medal minting'**
  String get launch2_launch2HeroNftSale;

  /// lib/features/launch2/launch2_hero.dart:113
  ///
  /// In en, this message translates to:
  /// **'{soldCount} minted · {perNft}'**
  String launch2_launch2HeroNftSale2(Object? perNft, Object? soldCount);

  /// lib/features/launch2/launch2_hero.dart:213
  ///
  /// In en, this message translates to:
  /// **'{soldCount} minted · {perNft}. Holders join the snapshot allowlist; a 1-hour priority buy follows its publication.'**
  String launch2_launch2HeroNftSale3(Object? perNft, Object? soldCount);

  /// lib/features/launch2/launch2_hero.dart:241
  ///
  /// In en, this message translates to:
  /// **'Mint period {launch2SaleDurationLabel} · ends {launch2ShortDateTime}'**
  String launch2_launch2HeroNftSale4(
    Object? launch2SaleDurationLabel,
    Object? launch2ShortDateTime,
  );

  /// lib/features/launch2/launch2_hero.dart:256
  ///
  /// In en, this message translates to:
  /// **'Mint ends in'**
  String get launch2_launch2HeroNftSale5;

  /// lib/features/launch2/launch2_hero.dart:110, lib/features/launch2/launch2_hero.dart:210
  ///
  /// In en, this message translates to:
  /// **'{launch2Usd1Label} each'**
  String launch2_launch2HeroPerNft(Object? launch2Usd1Label);

  /// lib/features/launch2/launch2_hero.dart:95, lib/features/launch2/launch2_hero.dart:244, lib/features/launch2/launch2_nft_screen.dart:162
  ///
  /// In en, this message translates to:
  /// **'Priority buy live'**
  String get launch2_launch2HeroPriority;

  /// lib/features/launch2/launch2_hero.dart:116
  ///
  /// In en, this message translates to:
  /// **'Bonding pool {launch2BpsLabel} sold · {launch2HeroPrice}'**
  String launch2_launch2HeroPriority2(
    Object? launch2BpsLabel,
    Object? launch2HeroPrice,
  );

  /// lib/features/launch2/launch2_hero.dart:218
  ///
  /// In en, this message translates to:
  /// **'{soldCount} minted · bonding pool {launch2BpsLabel} sold · {launch2HeroPrice}'**
  String launch2_launch2HeroPriority3(
    Object? launch2BpsLabel,
    Object? launch2HeroPrice,
    Object? soldCount,
  );

  /// lib/features/launch2/launch2_hero.dart:257
  ///
  /// In en, this message translates to:
  /// **'Priority buy ends in'**
  String get launch2_launch2HeroPriority4;

  /// lib/features/launch2/launch2_hero.dart:118
  ///
  /// In en, this message translates to:
  /// **'{launch2HeroPrice} · graduates when sold out'**
  String launch2_launch2HeroPublic(Object? launch2HeroPrice);

  /// lib/features/launch2/launch2_hero.dart:222
  ///
  /// In en, this message translates to:
  /// **'{launch2HeroPrice} · graduates at 800M sold'**
  String launch2_launch2HeroPublic2(Object? launch2HeroPrice);

  /// lib/features/launch2/launch2_hero.dart:168, lib/features/launch2/launch2_widgets.dart:205
  ///
  /// In en, this message translates to:
  /// **'Mint in {left}'**
  String launch2_launch2HeroS(Object? left);

  /// lib/features/launch2/launch2_hero.dart:244
  ///
  /// In en, this message translates to:
  /// **'Priority buy live · ends {launch2ShortDateTime}'**
  String launch2_launch2HeroS2(Object? launch2ShortDateTime);

  /// lib/features/launch2/launch2_hero.dart:114
  ///
  /// In en, this message translates to:
  /// **'1-hour priority buy after the allowlist is published'**
  String get launch2_launch2HeroSnapshotPending;

  /// lib/features/launch2/launch2_hero.dart:96
  ///
  /// In en, this message translates to:
  /// **'Bonding pool sprint'**
  String get launch2_launch2HeroSwitch;

  /// lib/features/launch2/launch2_hero.dart:168, lib/features/launch2/launch2_nft_screen.dart:119, lib/features/launch2/launch2_widgets.dart:205
  ///
  /// In en, this message translates to:
  /// **'Mint time TBD'**
  String get launch2_launch2HeroSwitch2;

  /// lib/features/launch2/launch2_hero.dart:170, lib/features/launch2/launch2_hero.dart:175
  ///
  /// In en, this message translates to:
  /// **'Ends in {left}'**
  String launch2_launch2HeroSwitch3(Object? left);

  /// lib/features/launch2/launch2_hero.dart:171, lib/features/launch2/launch2_hero.dart:173, lib/features/launch2/launch2_nft_screen.dart:113
  ///
  /// In en, this message translates to:
  /// **'{soldCount} minted'**
  String launch2_launch2HeroSwitch4(Object? soldCount);

  /// lib/features/launch2/launch2_hero.dart:176, lib/features/launch2/launch2_hero.dart:179, lib/features/launch2/launch2_instance_screen.dart:978
  ///
  /// In en, this message translates to:
  /// **'Bonding pool {launch2BpsLabel} sold'**
  String launch2_launch2HeroSwitch5(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_hero.dart:259, lib/features/launch2/launch2_instance_screen.dart:1458
  ///
  /// In en, this message translates to:
  /// **'Bonding pool progress'**
  String get launch2_launch2HeroSwitch6;

  /// lib/features/launch2/launch2_hero.dart:112
  ///
  /// In en, this message translates to:
  /// **'{perNft} · mint period {launch2SaleDurationLabel}'**
  String launch2_launch2HeroUpcoming(
    Object? launch2SaleDurationLabel,
    Object? perNft,
  );

  /// lib/features/launch2/launch2_hero.dart:224
  ///
  /// In en, this message translates to:
  /// **'Mint starts {launch2ShortDateTime} · {perNft} · mint period {launch2SaleDurationLabel}'**
  String launch2_launch2HeroUpcoming2(
    Object? launch2SaleDurationLabel,
    Object? launch2ShortDateTime,
    Object? perNft,
  );

  /// lib/features/launch2/launch2_hero.dart:248
  ///
  /// In en, this message translates to:
  /// **'Mint starts {launch2ShortDateTime}'**
  String launch2_launch2HeroUpcoming3(Object? launch2ShortDateTime);

  /// lib/features/launch2/launch2_hero.dart:258
  ///
  /// In en, this message translates to:
  /// **'Mint in'**
  String get launch2_launch2HeroUpcoming4;

  /// lib/features/launch2/launch2_instance_screen.dart:1004
  ///
  /// In en, this message translates to:
  /// **'24h vol {launch2Usd1Label}'**
  String launch2_launch2InstanceAside(Object? launch2Usd1Label);

  /// lib/features/launch2/launch2_instance_screen.dart:1231
  ///
  /// In en, this message translates to:
  /// **'Every v2 project uses the same parameters; project owners can\'t change them.'**
  String get launch2_launch2InstanceBody;

  /// lib/features/launch2/launch2_instance_screen.dart:1236
  ///
  /// In en, this message translates to:
  /// **'Medal mint ({launch2Usd1Label} each, 1 per address, ever) → snapshot allowlist and 1-hour priority buy → public pool. Selling out {launch2MemeCompact} tokens in any round builds the official pool and graduates.'**
  String launch2_launch2InstanceBody2(
    Object? launch2MemeCompact,
    Object? launch2Usd1Label,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1316
  ///
  /// In en, this message translates to:
  /// **'Each address can mint only 1, ever. Addresses holding a medal when minting ends join the snapshot allowlist, with a 1-hour priority buy after it\'s published.'**
  String get launch2_launch2InstanceBody3;

  /// lib/features/launch2/launch2_instance_screen.dart:1825
  ///
  /// In en, this message translates to:
  /// **'LP fee {launch2BpsLabel}, tickSpacing {tickSpacing}'**
  String launch2_launch2InstanceBody4(
    Object? launch2BpsLabel,
    Object? tickSpacing,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:2024
  ///
  /// In en, this message translates to:
  /// **'{launch2Usd1Label} per order, at least {buybackMinIntervalSeconds} seconds apart. Skipped when the official pool\'s USD1 principal is under 10,000 or an order exceeds 1% of it; refused attempts leave no record.'**
  String launch2_launch2InstanceBody5(
    Object? buybackMinIntervalSeconds,
    Object? launch2Usd1Label,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1353
  ///
  /// In en, this message translates to:
  /// **'Mint progress'**
  String get launch2_launch2InstanceBuild;

  /// lib/features/launch2/launch2_instance_screen.dart:1899
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get launch2_launch2InstanceBuild2;

  /// lib/features/launch2/launch2_instance_screen.dart:1251, lib/features/launch2/launch2_launchpad.dart:94, lib/features/launch2/launch2_launchpad.dart:131, lib/features/launch2/launch2_launchpad.dart:187
  ///
  /// In en, this message translates to:
  /// **'Bonding pool'**
  String get launch2_launch2InstanceLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:1253
  ///
  /// In en, this message translates to:
  /// **'Graduation reserve'**
  String get launch2_launch2InstanceLabel2;

  /// lib/features/launch2/launch2_instance_screen.dart:1259
  ///
  /// In en, this message translates to:
  /// **'Bonding pool trade tax'**
  String get launch2_launch2InstanceLabel3;

  /// lib/features/launch2/launch2_instance_screen.dart:1261, lib/features/launch2/launch2_instance_screen.dart:1851
  ///
  /// In en, this message translates to:
  /// **'DEX pool tax'**
  String get launch2_launch2InstanceLabel4;

  /// lib/features/launch2/launch2_instance_screen.dart:1265
  ///
  /// In en, this message translates to:
  /// **'Per-address cap'**
  String get launch2_launch2InstanceLabel5;

  /// lib/features/launch2/launch2_instance_screen.dart:1333
  ///
  /// In en, this message translates to:
  /// **'Price each'**
  String get launch2_launch2InstanceLabel6;

  /// lib/features/launch2/launch2_instance_screen.dart:1841
  ///
  /// In en, this message translates to:
  /// **'Graduated at'**
  String get launch2_launch2InstanceLabel7;

  /// lib/features/launch2/launch2_instance_screen.dart:1847, lib/features/launch2/launch2_widgets.dart:400
  ///
  /// In en, this message translates to:
  /// **'Graduation price'**
  String get launch2_launch2InstanceLabel8;

  /// lib/features/launch2/launch2_instance_screen.dart:595
  ///
  /// In en, this message translates to:
  /// **'Medal held'**
  String get launch2_launch2InstanceLaunch2BuyNftLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:598
  ///
  /// In en, this message translates to:
  /// **'Mint medal'**
  String get launch2_launch2InstanceLaunch2BuyNftLabel2;

  /// lib/features/launch2/launch2_instance_screen.dart:2037
  ///
  /// In en, this message translates to:
  /// **'Escrow balance'**
  String get launch2_launch2InstanceLaunch2BuybackEscrowLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:2008
  ///
  /// In en, this message translates to:
  /// **'About buybacks'**
  String get launch2_launch2InstanceLaunch2BuybackInfoLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:2051
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get launch2_launch2InstanceLaunch2BuybackLatestValue;

  /// lib/features/launch2/launch2_instance_screen.dart:2074
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read live on-chain data · {launch2ReasonText}'**
  String launch2_launch2InstanceLaunch2BuybackLiveUnavailableMessage(
    Object? launch2ReasonText,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:2068
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get launch2_launch2InstanceLaunch2BuybackNextLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:2019
  ///
  /// In en, this message translates to:
  /// **'Tokens bought back go to the project\'s registered recipient address; they aren\'t burned.'**
  String get launch2_launch2InstanceLaunch2BuybackNotBurnBody;

  /// lib/features/launch2/launch2_instance_screen.dart:2018
  ///
  /// In en, this message translates to:
  /// **'Buyback isn\'t a burn'**
  String get launch2_launch2InstanceLaunch2BuybackNotBurnTitle;

  /// lib/features/launch2/launch2_instance_screen.dart:2044
  ///
  /// In en, this message translates to:
  /// **'Total bought back'**
  String get launch2_launch2InstanceLaunch2BuybackTotalLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:2046
  ///
  /// In en, this message translates to:
  /// **'{launch2Usd1Label} · orders: {executedCount}'**
  String launch2_launch2InstanceLaunch2BuybackTotalValue(
    Object? executedCount,
    Object? launch2Usd1Label,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:2081
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load buyback details · {chainFailureReason}'**
  String launch2_launch2InstanceLaunch2BuybackUnavailableMessage(
    Object? chainFailureReason,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1478
  ///
  /// In en, this message translates to:
  /// **'Sold {launch2MemeCompact} / {launch2MemeCompact2}; graduates to the official pool when sold out'**
  String launch2_launch2InstanceLaunch2CurveSupply(
    Object? launch2MemeCompact,
    Object? launch2MemeCompact2,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:748
  ///
  /// In en, this message translates to:
  /// **'Checking the contract; trading may be unavailable'**
  String get launch2_launch2InstanceLaunch2EvidencePendingMessage;

  /// lib/features/launch2/launch2_instance_screen.dart:460
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this project'**
  String get launch2_launch2InstanceLaunch2InvalidRouteTitle;

  /// lib/features/launch2/launch2_instance_screen.dart:1639
  ///
  /// In en, this message translates to:
  /// **'My DEX pool trades'**
  String get launch2_launch2InstanceLaunch2MineOnlyToggle;

  /// lib/features/launch2/launch2_instance_screen.dart:1761
  ///
  /// In en, this message translates to:
  /// **'Trades are still syncing. Refresh later'**
  String get launch2_launch2InstanceLaunch2MyPoolTradesEmptyMessage;

  /// lib/features/launch2/launch2_instance_screen.dart:1753
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load my DEX pool trades · {chainFailureReason}'**
  String launch2_launch2InstanceLaunch2MyPoolTradesFailedMessage(
    Object? chainFailureReason,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1710
  ///
  /// In en, this message translates to:
  /// **'Activate a wallet to see only your trades'**
  String get launch2_launch2InstanceLaunch2MyPoolTradesNoWalletMessage;

  /// lib/features/launch2/launch2_instance_screen.dart:1728
  ///
  /// In en, this message translates to:
  /// **'You have no DEX pool trades yet'**
  String get launch2_launch2InstanceLaunch2MyPoolTradesNoneTitle;

  /// lib/features/launch2/launch2_instance_screen.dart:1780
  ///
  /// In en, this message translates to:
  /// **'Only trades routed through the official pool, latest {launch2MyPoolTradesShown}; amounts are after the 2% DEX pool tax.'**
  String launch2_launch2InstanceLaunch2MyPoolTradesProvenanceDetail(
    Object? launch2MyPoolTradesShown,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1719
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load my DEX pool trades'**
  String get launch2_launch2InstanceLaunch2MyPoolTradesUnsupportedMessage;

  /// lib/features/launch2/launch2_instance_screen.dart:1370, lib/features/launch2/launch2_nft_screen.dart:714
  ///
  /// In en, this message translates to:
  /// **'Ends {dateTimeLabel}'**
  String launch2_launch2InstanceLaunch2NftEnd(Object? dateTimeLabel);

  /// lib/features/launch2/launch2_instance_screen.dart:1386, lib/features/launch2/launch2_nft_screen.dart:722
  ///
  /// In en, this message translates to:
  /// **'I hold'**
  String get launch2_launch2InstanceLaunch2NftHeldLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:1302, lib/features/launch2/launch2_instance_screen.dart:1311
  ///
  /// In en, this message translates to:
  /// **'Project NFT'**
  String get launch2_launch2InstanceLaunch2NftInfo;

  /// lib/features/launch2/launch2_instance_screen.dart:1306
  ///
  /// In en, this message translates to:
  /// **'About the project NFT'**
  String get launch2_launch2InstanceLaunch2NftInfoLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:1404, lib/features/launch2/launch2_instance_screen.dart:1421
  ///
  /// In en, this message translates to:
  /// **'Mint page'**
  String get launch2_launch2InstanceLaunch2NftOpenLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:769
  ///
  /// In en, this message translates to:
  /// **'{launch2OpenedWithoutHoldersText}; priority buy skipped.'**
  String launch2_launch2InstanceLaunch2OpenedWithoutHoldersBody(
    Object? launch2OpenedWithoutHoldersText,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1818
  ///
  /// In en, this message translates to:
  /// **'Pool ID (Uniswap v4, no pool address)'**
  String get launch2_launch2InstanceLaunch2PoolIdTitle;

  /// lib/features/launch2/launch2_instance_screen.dart:1803, lib/features/launch2/launch2_instance_screen.dart:1812, lib/features/launch2/launch2_pool_trade_panel.dart:658
  ///
  /// In en, this message translates to:
  /// **'Official pool'**
  String get launch2_launch2InstanceLaunch2PoolInfo;

  /// lib/features/launch2/launch2_instance_screen.dart:1807
  ///
  /// In en, this message translates to:
  /// **'About the official pool'**
  String get launch2_launch2InstanceLaunch2PoolInfoLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:1833
  ///
  /// In en, this message translates to:
  /// **'Charged on every official pool buy and sell; the Hook adds it to buyback escrow for rule-based buybacks.'**
  String get launch2_launch2InstanceLaunch2PoolTaxBody;

  /// lib/features/launch2/launch2_instance_screen.dart:1832, lib/features/launch2/launch2_pool_view_model.dart:216, lib/features/launch2/launch2_pool_view_model.dart:406, lib/features/launch2/launch2_signing.dart:134
  ///
  /// In en, this message translates to:
  /// **'DEX pool tax {launch2BpsLabel}'**
  String launch2_launch2InstanceLaunch2PoolTaxTitle(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_instance_screen.dart:1678
  ///
  /// In en, this message translates to:
  /// **'No DEX pool trades yet'**
  String get launch2_launch2InstanceLaunch2PoolTradesEmptyTitle;

  /// lib/features/launch2/launch2_instance_screen.dart:1665
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load DEX pool trades · {state}'**
  String launch2_launch2InstanceLaunch2PoolTradesFailedMessage(Object? state);

  /// lib/features/launch2/launch2_instance_screen.dart:1696
  ///
  /// In en, this message translates to:
  /// **'Latest {launch2RecentPoolTradesLimit} official pool trades, excluding buybacks; sell amounts are received after tax.'**
  String launch2_launch2InstanceLaunch2PoolTradesProvenanceDetail(
    Object? launch2RecentPoolTradesLimit,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1217, lib/features/launch2/launch2_instance_screen.dart:1226
  ///
  /// In en, this message translates to:
  /// **'Launch rules'**
  String get launch2_launch2InstanceLaunch2TemplateInfo;

  /// lib/features/launch2/launch2_instance_screen.dart:1221
  ///
  /// In en, this message translates to:
  /// **'About launch rules'**
  String get launch2_launch2InstanceLaunch2TemplateInfoLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:1242, lib/features/launch2/launch2_instance_screen.dart:1321, lib/features/launch2/launch2_nft_screen.dart:716
  ///
  /// In en, this message translates to:
  /// **'Risks'**
  String get launch2_launch2InstanceLaunch2TemplateRiskTitle;

  /// lib/features/launch2/launch2_instance_screen.dart:662
  ///
  /// In en, this message translates to:
  /// **'Close trade panel'**
  String get launch2_launch2InstanceLaunch2TradeSheetBarrierLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:1596
  ///
  /// In en, this message translates to:
  /// **'Latest 20 bonding pool trades; amounts include the 10% tax.'**
  String get launch2_launch2InstanceLaunch2TradesProvenanceDetail;

  /// lib/features/launch2/launch2_instance_screen.dart:1102
  ///
  /// In en, this message translates to:
  /// **'You\'re the owner'**
  String get launch2_launch2InstanceLoopBadge;

  /// lib/features/launch2/launch2_instance_screen.dart:932
  ///
  /// In en, this message translates to:
  /// **'Medal mint'**
  String get launch2_launch2InstanceLoopLabel;

  /// lib/features/launch2/launch2_instance_screen.dart:1576
  ///
  /// In en, this message translates to:
  /// **'Latest trades'**
  String get launch2_launch2InstanceLoopLabel2;

  /// lib/features/launch2/launch2_instance_screen.dart:1588, lib/features/launch2/launch2_instance_screen.dart:1692, lib/features/launch2/launch2_instance_screen.dart:1776, lib/features/launch2/launch2_list.dart:426, lib/features/launch2/launch2_nft_screen.dart:735
  ///
  /// In en, this message translates to:
  /// **'LOOP on-chain index'**
  String get launch2_launch2InstanceLoopProvenanceLine;

  /// lib/features/launch2/launch2_instance_screen.dart:729
  ///
  /// In en, this message translates to:
  /// **'Token address copied'**
  String get launch2_launch2InstanceMessage;

  /// lib/features/launch2/launch2_instance_screen.dart:1158
  ///
  /// In en, this message translates to:
  /// **'No one minted during the mint period. This project uses a legacy contract, so no allowlist can be built and priority buy and the public pool won\'t start.'**
  String get launch2_launch2InstanceMessage2;

  /// lib/features/launch2/launch2_instance_screen.dart:1125
  ///
  /// In en, this message translates to:
  /// **'1 per address · {soldCount} minted'**
  String launch2_launch2InstanceNftSale(Object? soldCount);

  /// lib/features/launch2/launch2_instance_parts.dart:263
  ///
  /// In en, this message translates to:
  /// **'Current price (USD1)'**
  String get launch2_launch2InstancePartsBuild;

  /// lib/features/launch2/launch2_instance_parts.dart:425
  ///
  /// In en, this message translates to:
  /// **'My holdings'**
  String get launch2_launch2InstancePartsBuild2;

  /// lib/features/launch2/launch2_instance_parts.dart:762
  ///
  /// In en, this message translates to:
  /// **'{launch2TradeTimeLabel} · price {launch2PriceLabel}'**
  String launch2_launch2InstancePartsBuild3(
    Object? launch2PriceLabel,
    Object? launch2TradeTimeLabel,
  );

  /// lib/features/launch2/launch2_instance_parts.dart:595, lib/features/launch2/launch2_instance_screen.dart:2004, lib/features/launch2/launch2_instance_screen.dart:2013
  ///
  /// In en, this message translates to:
  /// **'Buyback'**
  String get launch2_launch2InstancePartsBuyback;

  /// lib/features/launch2/launch2_instance_parts.dart:239
  ///
  /// In en, this message translates to:
  /// **'No trade price yet'**
  String get launch2_launch2InstancePartsEmptyText;

  /// lib/features/launch2/launch2_instance_parts.dart:594
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get launch2_launch2InstancePartsInfo;

  /// lib/features/launch2/launch2_instance_parts.dart:377
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get launch2_launch2InstancePartsLabel;

  /// lib/features/launch2/launch2_instance_parts.dart:383
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get launch2_launch2InstancePartsLabel2;

  /// lib/features/launch2/launch2_instance_parts.dart:822, lib/features/launch2/launch2_instance_parts.dart:852
  ///
  /// In en, this message translates to:
  /// **'Mine only'**
  String get launch2_launch2InstancePartsLabel3;

  /// lib/features/launch2/launch2_instance_parts.dart:144
  ///
  /// In en, this message translates to:
  /// **'Copy token address'**
  String get launch2_launch2InstancePartsLaunch2CopyAddressLabel;

  /// lib/features/launch2/launch2_instance_parts.dart:543
  ///
  /// In en, this message translates to:
  /// **'This round, {state}, {line}'**
  String launch2_launch2InstancePartsLaunch2DynStripLineLabel(
    Object? line,
    Object? state,
  );

  /// lib/features/launch2/launch2_instance_parts.dart:403
  ///
  /// In en, this message translates to:
  /// **'Some holdings were transferred in on-chain without a cost record; cost price and P&L only cover the part with cost records.'**
  String get launch2_launch2InstancePartsLaunch2HoldingPartialNoteBody;

  /// lib/features/launch2/launch2_instance_parts.dart:402
  ///
  /// In en, this message translates to:
  /// **'Some holdings have no cost record'**
  String get launch2_launch2InstancePartsLaunch2HoldingPartialNoteTitle;

  /// lib/features/launch2/launch2_instance_parts.dart:389
  ///
  /// In en, this message translates to:
  /// **'P&L'**
  String get launch2_launch2InstancePartsLaunch2HoldingPnlInfoLabel;

  /// lib/features/launch2/launch2_instance_parts.dart:396
  ///
  /// In en, this message translates to:
  /// **'Holding P&L'**
  String get launch2_launch2InstancePartsLaunch2HoldingPnlInfoTitle;

  /// lib/features/launch2/launch2_instance_parts.dart:410
  ///
  /// In en, this message translates to:
  /// **'Realized P&L'**
  String get launch2_launch2InstancePartsLaunch2HoldingRealizedNoteTitle;

  /// lib/features/launch2/launch2_instance_parts.dart:513
  ///
  /// In en, this message translates to:
  /// **'Reward pool {launch2Usd1Label}'**
  String launch2_launch2InstancePartsPot(Object? launch2Usd1Label);

  /// lib/features/launch2/launch2_instance_parts.dart:517
  ///
  /// In en, this message translates to:
  /// **'Drop {launch2BpsLabel}'**
  String launch2_launch2InstancePartsS(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_instance_parts.dart:748
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get launch2_launch2InstancePartsText;

  /// lib/features/launch2/launch2_instance_parts.dart:593, lib/features/launch2/launch2_instance_screen.dart:2056
  ///
  /// In en, this message translates to:
  /// **'Trades'**
  String get launch2_launch2InstancePartsTrades;

  /// lib/features/launch2/launch2_instance_screen.dart:1126
  ///
  /// In en, this message translates to:
  /// **'Holders first'**
  String get launch2_launch2InstancePriority;

  /// lib/features/launch2/launch2_instance_screen.dart:936
  ///
  /// In en, this message translates to:
  /// **'Mint starts'**
  String get launch2_launch2InstanceRows;

  /// lib/features/launch2/launch2_instance_screen.dart:937
  ///
  /// In en, this message translates to:
  /// **'Mint price'**
  String get launch2_launch2InstanceRows2;

  /// lib/features/launch2/launch2_instance_screen.dart:938
  ///
  /// In en, this message translates to:
  /// **'Mint duration'**
  String get launch2_launch2InstanceRows3;

  /// lib/features/launch2/launch2_instance_screen.dart:965, lib/features/launch2/launch2_instance_screen.dart:1165, lib/features/launch2/launch2_instance_screen.dart:1338, lib/features/launch2/launch2_nft_screen.dart:727
  ///
  /// In en, this message translates to:
  /// **'Minted'**
  String get launch2_launch2InstanceRows4;

  /// lib/features/launch2/launch2_instance_screen.dart:965, lib/features/launch2/launch2_instance_screen.dart:1165, lib/features/launch2/launch2_instance_screen.dart:1339, lib/features/launch2/launch2_nft_screen.dart:728
  ///
  /// In en, this message translates to:
  /// **'{soldCount}'**
  String launch2_launch2InstanceRows5(Object? soldCount);

  /// lib/features/launch2/launch2_instance_screen.dart:967
  ///
  /// In en, this message translates to:
  /// **'My NFT'**
  String get launch2_launch2InstanceRows6;

  /// lib/features/launch2/launch2_instance_screen.dart:968, lib/features/launch2/launch2_instance_screen.dart:1387, lib/features/launch2/launch2_nft_screen.dart:220
  ///
  /// In en, this message translates to:
  /// **'Wallet not activated'**
  String get launch2_launch2InstanceRows7;

  /// lib/features/launch2/launch2_instance_screen.dart:1168
  ///
  /// In en, this message translates to:
  /// **'Cutoff block'**
  String get launch2_launch2InstanceRows8;

  /// lib/features/launch2/launch2_instance_screen.dart:1171
  ///
  /// In en, this message translates to:
  /// **'Closed at'**
  String get launch2_launch2InstanceRows9;

  /// lib/features/launch2/launch2_instance_screen.dart:1296
  ///
  /// In en, this message translates to:
  /// **'{elapsed}% passed'**
  String launch2_launch2InstanceS(Object? elapsed);

  /// lib/features/launch2/launch2_instance_screen.dart:1363
  ///
  /// In en, this message translates to:
  /// **'Mint time {elapsedText}'**
  String launch2_launch2InstanceSemanticLabel(Object? elapsedText);

  /// lib/features/launch2/launch2_instance_screen.dart:1474
  ///
  /// In en, this message translates to:
  /// **'Bonding pool progress {launch2BpsLabel}'**
  String launch2_launch2InstanceSemanticLabel2(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_instance_screen.dart:609
  ///
  /// In en, this message translates to:
  /// **'The last one is still confirming on-chain. Trade after it confirms'**
  String get launch2_launch2InstanceSwitch;

  /// lib/features/launch2/launch2_instance_screen.dart:236, lib/features/launch2/launch2_signing.dart:413
  ///
  /// In en, this message translates to:
  /// **'Your {noun} is confirmed on-chain.'**
  String launch2_launch2InstanceText(Object? noun);

  /// lib/features/launch2/launch2_instance_screen.dart:238
  ///
  /// In en, this message translates to:
  /// **'Your DEX pool {noun} is confirmed on-chain.'**
  String launch2_launch2InstanceText2(Object? noun);

  /// lib/features/launch2/launch2_instance_screen.dart:239
  ///
  /// In en, this message translates to:
  /// **'The official pool recorded a new trade, so your DEX pool {noun} should be confirmed; your wallet balance is the final amount.'**
  String launch2_launch2InstanceText3(Object? noun);

  /// lib/features/launch2/launch2_instance_screen.dart:254
  ///
  /// In en, this message translates to:
  /// **'Broadcast, but no confirmation yet. It may still be confirming; check again later. Don\'t submit the {launch2IntentNoun} again.'**
  String launch2_launch2InstanceText4(Object? launch2IntentNoun);

  /// lib/features/launch2/launch2_instance_screen.dart:1106
  ///
  /// In en, this message translates to:
  /// **'You\'re seeing the project page as users see it'**
  String get launch2_launch2InstanceText5;

  /// lib/features/launch2/launch2_instance_screen.dart:1230
  ///
  /// In en, this message translates to:
  /// **'Fixed by the platform template'**
  String get launch2_launch2InstanceTitle;

  /// lib/features/launch2/launch2_instance_screen.dart:1234
  ///
  /// In en, this message translates to:
  /// **'Three-stage launch'**
  String get launch2_launch2InstanceTitle2;

  /// lib/features/launch2/launch2_instance_screen.dart:1635
  ///
  /// In en, this message translates to:
  /// **'All DEX pool trades'**
  String get launch2_launch2InstanceTitle3;

  /// lib/features/launch2/launch2_instance_screen.dart:1823
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get launch2_launch2InstanceTitle4;

  /// lib/features/launch2/launch2_instance_screen.dart:2022, lib/features/launch2/launch2_nft_screen.dart:701
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get launch2_launch2InstanceTitle5;

  /// lib/features/launch2/launch2_instance_screen.dart:2029
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get launch2_launch2InstanceTitle6;

  /// lib/features/launch2/launch2_instance_screen.dart:1123, lib/features/launch2/launch2_nft_screen.dart:124
  ///
  /// In en, this message translates to:
  /// **'{launch2Usd1Label} each · mint period {launch2SaleDurationLabel}'**
  String launch2_launch2InstanceUpcoming(
    Object? launch2SaleDurationLabel,
    Object? launch2Usd1Label,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1268
  ///
  /// In en, this message translates to:
  /// **'{launch2CurveCapFigure} tokens ({launch2BpsLabel})'**
  String launch2_launch2InstanceValue(
    Object? launch2BpsLabel,
    Object? launch2CurveCapFigure,
  );

  /// lib/features/launch2/launch2_instance_screen.dart:1638
  ///
  /// In en, this message translates to:
  /// **'My DEX pool trades · {groupedFigure} total'**
  String launch2_launch2InstanceZero(Object? groupedFigure);

  /// lib/features/launch2/launch2_widgets.dart:562
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get launch2_launch2Label;

  /// lib/features/launch2/launch2_widgets.dart:566
  ///
  /// In en, this message translates to:
  /// **'Get funds'**
  String get launch2_launch2Label2;

  /// lib/features/launch2/launch2_widgets.dart:737
  ///
  /// In en, this message translates to:
  /// **'View publish transaction on BscScan'**
  String get launch2_launch2Launch2SnapshotExplorerLabel;

  /// lib/features/launch2/launch2_widgets.dart:693
  ///
  /// In en, this message translates to:
  /// **'Allowlist size'**
  String get launch2_launch2Launch2SnapshotMembersLabel;

  /// lib/features/launch2/launch2_widgets.dart:694
  ///
  /// In en, this message translates to:
  /// **'{members}'**
  String launch2_launch2Launch2SnapshotMembersValue(Object? members);

  /// lib/features/launch2/launch2_widgets.dart:700
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get launch2_launch2Launch2SnapshotPublishedAtLabel;

  /// lib/features/launch2/launch2_widgets.dart:714
  ///
  /// In en, this message translates to:
  /// **'Publish transaction'**
  String get launch2_launch2Launch2SnapshotTxLabel;

  /// lib/features/launch2/launch2_widgets.dart:707
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get launch2_launch2Launch2SnapshotVerificationLabel;

  /// lib/features/launch2/launch2_launchpad.dart:1032
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get launch2_launch2LaunchpadBuild;

  /// lib/features/launch2/launch2_launchpad.dart:78
  ///
  /// In en, this message translates to:
  /// **'Platform bought back {ticker}{usd1}'**
  String launch2_launch2LaunchpadBuyback(Object? ticker, Object? usd1);

  /// lib/features/launch2/launch2_launchpad.dart:98
  ///
  /// In en, this message translates to:
  /// **'Paused / no mints'**
  String get launch2_launch2LaunchpadClosed;

  /// lib/features/launch2/launch2_launchpad.dart:74
  ///
  /// In en, this message translates to:
  /// **'{who}bought {ticker}{usd1}'**
  String launch2_launch2LaunchpadCurveBuy(
    Object? ticker,
    Object? usd1,
    Object? who,
  );

  /// lib/features/launch2/launch2_launchpad.dart:75
  ///
  /// In en, this message translates to:
  /// **'{who}sold {ticker}{usd1}'**
  String launch2_launch2LaunchpadCurveSell(
    Object? ticker,
    Object? usd1,
    Object? who,
  );

  /// lib/features/launch2/launch2_launchpad.dart:77
  ///
  /// In en, this message translates to:
  /// **'{ticker} graduated'**
  String launch2_launch2LaunchpadGraduated(Object? ticker);

  /// lib/features/launch2/launch2_launchpad.dart:254
  ///
  /// In en, this message translates to:
  /// **'Launchpad · {loopTestnetStampText}'**
  String launch2_launch2LaunchpadLaunch2DeskKicker(
    Object? loopTestnetStampText,
  );

  /// lib/features/launch2/launch2_launchpad.dart:46
  ///
  /// In en, this message translates to:
  /// **'{inMinutes}m ago'**
  String launch2_launch2LaunchpadLaunch2RelativeTime(Object? inMinutes);

  /// lib/features/launch2/launch2_launchpad.dart:52, lib/features/launch2/launch2_launchpad.dart:64
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get launch2_launch2LaunchpadLaunch2TapeActor;

  /// lib/features/launch2/launch2_launchpad.dart:1271
  ///
  /// In en, this message translates to:
  /// **'This user'**
  String get launch2_launch2LaunchpadLaunch2TapeFaceName;

  /// lib/features/launch2/launch2_launchpad.dart:1164
  ///
  /// In en, this message translates to:
  /// **'Live trades'**
  String get launch2_launch2LaunchpadLoopLabel;

  /// lib/features/launch2/launch2_launchpad.dart:76
  ///
  /// In en, this message translates to:
  /// **'{who}minted the {ticker} medal'**
  String launch2_launch2LaunchpadNftMint(Object? ticker, Object? who);

  /// lib/features/launch2/launch2_launchpad.dart:80
  ///
  /// In en, this message translates to:
  /// **'{who}claimed {ticker} rewards{usd1}'**
  String launch2_launch2LaunchpadRewardClaimed(
    Object? ticker,
    Object? usd1,
    Object? who,
  );

  /// lib/features/launch2/launch2_launchpad.dart:79
  ///
  /// In en, this message translates to:
  /// **'New {ticker} DEX pool round active'**
  String launch2_launch2LaunchpadRoundActivated(Object? ticker);

  /// lib/features/launch2/launch2_launchpad.dart:255
  ///
  /// In en, this message translates to:
  /// **'Launchpad · BSC'**
  String get launch2_launch2LaunchpadS;

  /// lib/features/launch2/launch2_launchpad.dart:910
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get launch2_launch2LaunchpadSemantics;

  /// lib/features/launch2/launch2_launchpad.dart:512
  ///
  /// In en, this message translates to:
  /// **'No launches in progress'**
  String get launch2_launch2LaunchpadTitle;

  /// lib/features/launch2/launch2_launchpad.dart:96, lib/features/launch2/launch2_launchpad.dart:135, lib/features/launch2/launch2_launchpad.dart:194
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get launch2_launch2LaunchpadUpcoming;

  /// lib/features/launch2/launch2_list.dart:382, lib/features/launch2/launch2_list.dart:393
  ///
  /// In en, this message translates to:
  /// **'No v2 projects yet'**
  String get launch2_launch2ListEmptyMessage;

  /// lib/features/launch2/launch2_list.dart:44
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach LOOP right now'**
  String get launch2_launch2ListIf;

  /// lib/features/launch2/launch2_list.dart:400
  ///
  /// In en, this message translates to:
  /// **'See live launches'**
  String get launch2_launch2ListLabel;

  /// lib/features/launch2/launch2_list.dart:400
  ///
  /// In en, this message translates to:
  /// **'See classic launches'**
  String get launch2_launch2ListLabel2;

  /// lib/features/launch2/launch2_list.dart:617
  ///
  /// In en, this message translates to:
  /// **'No projects minting or in the bonding pool right now'**
  String get launch2_launch2ListLaunch2LiveEmptyMessage;

  /// lib/features/launch2/launch2_list.dart:345
  ///
  /// In en, this message translates to:
  /// **'MEME v2 isn\'t available right now · {launch2CapabilityText}'**
  String launch2_launch2ListMessage(Object? launch2CapabilityText);

  /// lib/features/launch2/launch2_list.dart:44
  ///
  /// In en, this message translates to:
  /// **'MEME v2 status not loaded yet'**
  String get launch2_launch2ListS;

  /// lib/features/launch2/launch2_list.dart:327
  ///
  /// In en, this message translates to:
  /// **'v2 launch'**
  String get launch2_launch2ListTitle;

  /// lib/features/launch2/launch2_list.dart:393, lib/features/launch2/launch2_list.dart:653, lib/features/launch2/launch2_list.dart:662
  ///
  /// In en, this message translates to:
  /// **'No graduated v2 projects yet'**
  String get launch2_launch2ListTitle2;

  /// lib/features/launch2/launch2_nft_screen.dart:359
  ///
  /// In en, this message translates to:
  /// **'Close NFT picker'**
  String get launch2_launch2NftBarrierLabel;

  /// lib/features/launch2/launch2_nft_screen.dart:126
  ///
  /// In en, this message translates to:
  /// **'Mint opens at start'**
  String get launch2_launch2NftButtonLabel;

  /// lib/features/launch2/launch2_nft_screen.dart:138
  ///
  /// In en, this message translates to:
  /// **'Held · 1 per address'**
  String get launch2_launch2NftButtonLabel2;

  /// lib/features/launch2/launch2_nft_screen.dart:140
  ///
  /// In en, this message translates to:
  /// **'Mint 1 · {launch2Usd1Label}'**
  String launch2_launch2NftButtonLabel3(Object? launch2Usd1Label);

  /// lib/features/launch2/launch2_nft_screen.dart:141
  ///
  /// In en, this message translates to:
  /// **'Activate a wallet to mint'**
  String get launch2_launch2NftButtonLabel4;

  /// lib/features/launch2/launch2_nft_screen.dart:155
  ///
  /// In en, this message translates to:
  /// **'Waiting for allowlist'**
  String get launch2_launch2NftButtonLabel5;

  /// lib/features/launch2/launch2_nft_screen.dart:155
  ///
  /// In en, this message translates to:
  /// **'Minting ended'**
  String get launch2_launch2NftButtonLabel6;

  /// lib/features/launch2/launch2_nft_screen.dart:199, lib/features/launch2/launch2_nft_screen.dart:209
  ///
  /// In en, this message translates to:
  /// **'Go to project page'**
  String get launch2_launch2NftButtonLabel7;

  /// lib/features/launch2/launch2_nft_card.dart:98
  ///
  /// In en, this message translates to:
  /// **'Default image'**
  String get launch2_launch2NftCardSemantics;

  /// lib/features/launch2/launch2_nft_screen.dart:692
  ///
  /// In en, this message translates to:
  /// **'Join the snapshot allowlist'**
  String get launch2_launch2NftEntry;

  /// lib/features/launch2/launch2_nft_screen.dart:692
  ///
  /// In en, this message translates to:
  /// **'Hold it when minting ends to join the snapshot allowlist, with a 1-hour bonding pool priority buy after it\'s published'**
  String get launch2_launch2NftEntry2;

  /// lib/features/launch2/launch2_nft_screen.dart:695
  ///
  /// In en, this message translates to:
  /// **'Escrow and buyback'**
  String get launch2_launch2NftEntry3;

  /// lib/features/launch2/launch2_nft_screen.dart:696
  ///
  /// In en, this message translates to:
  /// **'Mint payments go to this project\'s escrow contract; after graduation the platform buys back MEME at {launch2Usd1Label} per order'**
  String launch2_launch2NftEntry4(Object? launch2Usd1Label);

  /// lib/features/launch2/launch2_nft_screen.dart:707
  ///
  /// In en, this message translates to:
  /// **'1 per address'**
  String get launch2_launch2NftEntry5;

  /// lib/features/launch2/launch2_nft_screen.dart:708
  ///
  /// In en, this message translates to:
  /// **'Each address can mint only 1, ever · {launch2Usd1Label} each'**
  String launch2_launch2NftEntry6(Object? launch2Usd1Label);

  /// lib/features/launch2/launch2_nft_screen.dart:713
  ///
  /// In en, this message translates to:
  /// **'Mint period {launch2SaleDurationLabel}'**
  String launch2_launch2NftEntry7(Object? launch2SaleDurationLabel);

  /// lib/features/launch2/launch2_nft_screen.dart:225
  ///
  /// In en, this message translates to:
  /// **'#{tokenId} · on the snapshot allowlist'**
  String launch2_launch2NftIf(Object? tokenId);

  /// lib/features/launch2/launch2_nft_screen.dart:227
  ///
  /// In en, this message translates to:
  /// **'#{tokenId} · on the candidate list'**
  String launch2_launch2NftIf2(Object? tokenId);

  /// lib/features/launch2/launch2_nft_screen.dart:850
  ///
  /// In en, this message translates to:
  /// **'{ticker} consensus medal, {bottomLabel}'**
  String launch2_launch2NftLaunch2NftMedalPictureLabel(
    Object? bottomLabel,
    Object? ticker,
  );

  /// lib/features/launch2/launch2_nft_screen.dart:231
  ///
  /// In en, this message translates to:
  /// **'Minted · joins the allowlist when minting ends'**
  String get launch2_launch2NftLaunch2NftMintedToast;

  /// lib/features/launch2/launch2_nft_screen.dart:738
  ///
  /// In en, this message translates to:
  /// **'Stages and countdowns come from the server on chain time and reload when due.'**
  String get launch2_launch2NftLaunch2NftProvenanceDetail;

  /// lib/features/launch2/launch2_nft_screen.dart:688
  ///
  /// In en, this message translates to:
  /// **'What this medal does'**
  String get launch2_launch2NftLoopLabel;

  /// lib/features/launch2/launch2_nft_screen.dart:719
  ///
  /// In en, this message translates to:
  /// **'My medal'**
  String get launch2_launch2NftLoopLabel2;

  /// lib/features/launch2/launch2_nft_screen.dart:998
  ///
  /// In en, this message translates to:
  /// **'Choose an NFT to send'**
  String get launch2_launch2NftLoopLabel3;

  /// lib/features/launch2/launch2_nft_mint.dart:89
  ///
  /// In en, this message translates to:
  /// **'Continue to {noun}'**
  String launch2_launch2NftMintConfirmLabel(Object? noun);

  /// lib/features/launch2/launch2_nft_mint.dart:88
  ///
  /// In en, this message translates to:
  /// **'{noun} {ticker} consensus medal'**
  String launch2_launch2NftMintHeading(Object? noun, Object? ticker);

  /// lib/features/launch2/launch2_nft_mint.dart:96
  ///
  /// In en, this message translates to:
  /// **'No wallet available. Activate a wallet before minting'**
  String get launch2_launch2NftMintLaunch2ActionFailure;

  /// lib/features/launch2/launch2_nft_mint.dart:32, lib/features/launch2/launch2_signing.dart:79
  ///
  /// In en, this message translates to:
  /// **'mint'**
  String get launch2_launch2NftMintNoun;

  /// lib/features/launch2/launch2_nft_screen.dart:112, lib/features/launch2/launch2_nft_screen.dart:490, lib/features/launch2/launch2_nft_screen.dart:534, lib/features/launch2/launch2_nft_screen.dart:777
  ///
  /// In en, this message translates to:
  /// **'Consensus medal'**
  String get launch2_launch2NftS;

  /// lib/features/launch2/launch2_widgets.dart:207
  ///
  /// In en, this message translates to:
  /// **'Minted {soldCount}{left}'**
  String launch2_launch2NftSale(Object? left, Object? soldCount);

  /// lib/features/launch2/launch2_nft_screen.dart:152
  ///
  /// In en, this message translates to:
  /// **'Minting ended · {launch2SnapshotPendingTitle}'**
  String launch2_launch2NftStatus(Object? launch2SnapshotPendingTitle);

  /// lib/features/launch2/launch2_nft_screen.dart:174
  ///
  /// In en, this message translates to:
  /// **'No one minted during the mint period; went straight to the public round'**
  String get launch2_launch2NftStatus2;

  /// lib/features/launch2/launch2_nft_screen.dart:175
  ///
  /// In en, this message translates to:
  /// **'Bonding pool open'**
  String get launch2_launch2NftStatus3;

  /// lib/features/launch2/launch2_nft_screen.dart:197
  ///
  /// In en, this message translates to:
  /// **'No one minted during the mint period; the project is closed'**
  String get launch2_launch2NftStatus4;

  /// lib/features/launch2/launch2_nft_screen.dart:423
  ///
  /// In en, this message translates to:
  /// **'Broadcast, but no confirmation yet. It may still be confirming; check again later. Don\'t mint again.'**
  String get launch2_launch2NftText;

  /// lib/features/launch2/launch2_nft_screen.dart:115
  ///
  /// In en, this message translates to:
  /// **'Trade on project page'**
  String get launch2_launch2NftToProject;

  /// lib/features/launch2/launch2_pool_trade_panel.dart:684
  ///
  /// In en, this message translates to:
  /// **'Buys from any app count toward rewards, credited to the address receiving the MEME'**
  String get launch2_launch2PoolTradePanelLaunch2DynPanelNote;

  /// lib/features/launch2/launch2_pool_trade_panel.dart:759, lib/features/launch2/launch2_pool_trade_panel.dart:769
  ///
  /// In en, this message translates to:
  /// **'Or trade in Wallet Swap'**
  String get launch2_launch2PoolTradePanelLaunch2GoSwapLabel;

  /// lib/features/launch2/launch2_pool_trade_panel.dart:722
  ///
  /// In en, this message translates to:
  /// **'Fill max sellable'**
  String get launch2_launch2PoolTradePanelLaunch2PoolMaxLabel;

  /// lib/features/launch2/launch2_pool_trade_panel.dart:444
  ///
  /// In en, this message translates to:
  /// **'Input mode'**
  String get launch2_launch2PoolTradePanelLaunch2PoolModeCaption;

  /// lib/features/launch2/launch2_pool_trade_panel.dart:591
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get launch2_launch2PoolTradePanelLaunch2PoolSlippageCustomLabel;

  /// lib/features/launch2/launch2_pool_trade_panel.dart:654
  ///
  /// In en, this message translates to:
  /// **'DEX pool trade'**
  String get launch2_launch2PoolTradePanelLaunch2PoolTaxLabel;

  /// lib/features/launch2/launch2_pool_trade_panel.dart:540, lib/features/launch2/launch2_signing.dart:102
  ///
  /// In en, this message translates to:
  /// **'Official pool router'**
  String get launch2_launch2PoolTradePanelLoopProvenanceLine;

  /// lib/features/launch2/launch2_pool_view_model.dart:260
  ///
  /// In en, this message translates to:
  /// **'Base tax {launch2BpsLabel}'**
  String launch2_launch2PoolViewModelBase(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_pool_view_model.dart:415
  ///
  /// In en, this message translates to:
  /// **'Confirming last one…'**
  String get launch2_launch2PoolViewModelConfirmLabel;

  /// lib/features/launch2/launch2_pool_view_model.dart:417, lib/features/launch2/launch2_trade_panel.dart:531
  ///
  /// In en, this message translates to:
  /// **'Confirm buy'**
  String get launch2_launch2PoolViewModelConfirmLabel2;

  /// lib/features/launch2/launch2_pool_view_model.dart:418, lib/features/launch2/launch2_trade_panel.dart:532
  ///
  /// In en, this message translates to:
  /// **'Confirm sell'**
  String get launch2_launch2PoolViewModelConfirmLabel3;

  /// lib/features/launch2/launch2_pool_view_model.dart:169, lib/features/launch2/launch2_trade_panel.dart:473
  ///
  /// In en, this message translates to:
  /// **'Pay (incl. tax)'**
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText;

  /// lib/features/launch2/launch2_pool_view_model.dart:171
  ///
  /// In en, this message translates to:
  /// **'Want to buy'**
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText2;

  /// lib/features/launch2/launch2_pool_view_model.dart:178
  ///
  /// In en, this message translates to:
  /// **'Want to receive'**
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText3;

  /// lib/features/launch2/launch2_pool_view_model.dart:183
  ///
  /// In en, this message translates to:
  /// **'Pay amount'**
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText4;

  /// lib/features/launch2/launch2_pool_view_model.dart:183
  ///
  /// In en, this message translates to:
  /// **'Buy amount'**
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText5;

  /// lib/features/launch2/launch2_pool_view_model.dart:183
  ///
  /// In en, this message translates to:
  /// **'Sell amount'**
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText6;

  /// lib/features/launch2/launch2_pool_view_model.dart:183
  ///
  /// In en, this message translates to:
  /// **'Get amount'**
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText7;

  /// lib/features/launch2/launch2_pool_view_model.dart:211
  ///
  /// In en, this message translates to:
  /// **'Estimated payment'**
  String get launch2_launch2PoolViewModelLaunch2PoolLine;

  /// lib/features/launch2/launch2_pool_view_model.dart:212, lib/features/launch2/launch2_signing.dart:172
  ///
  /// In en, this message translates to:
  /// **'Maximum payment'**
  String get launch2_launch2PoolViewModelLaunch2PoolLine2;

  /// lib/features/launch2/launch2_pool_view_model.dart:221, lib/features/launch2/launch2_pool_view_model.dart:288
  ///
  /// In en, this message translates to:
  /// **'Average price'**
  String get launch2_launch2PoolViewModelLaunch2PoolLine3;

  /// lib/features/launch2/launch2_pool_view_model.dart:238, lib/features/launch2/launch2_pool_view_model.dart:243
  ///
  /// In en, this message translates to:
  /// **'Base tax {rate} ({launch2BuyFeeSideText})'**
  String launch2_launch2PoolViewModelLaunch2PoolLine4(
    Object? launch2BuyFeeSideText,
    Object? rate,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:272
  ///
  /// In en, this message translates to:
  /// **'This trade earns reward weight'**
  String get launch2_launch2PoolViewModelLaunch2PoolLine5;

  /// lib/features/launch2/launch2_pool_view_model.dart:275
  ///
  /// In en, this message translates to:
  /// **'Reward weight'**
  String get launch2_launch2PoolViewModelLaunch2PoolLine6;

  /// lib/features/launch2/launch2_pool_view_model.dart:275
  ///
  /// In en, this message translates to:
  /// **'Not active now, no rewards'**
  String get launch2_launch2PoolViewModelLaunch2PoolLine7;

  /// lib/features/launch2/launch2_pool_view_model.dart:279
  ///
  /// In en, this message translates to:
  /// **'{base} + current dynamic tax {launch2BpsLabel} (from USD1)'**
  String launch2_launch2PoolViewModelLaunch2PoolLine8(
    Object? base,
    Object? launch2BpsLabel,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:284
  ///
  /// In en, this message translates to:
  /// **'Of which dynamic tax'**
  String get launch2_launch2PoolViewModelLaunch2PoolLine9;

  /// lib/features/launch2/launch2_pool_view_model.dart:455
  ///
  /// In en, this message translates to:
  /// **'{launch2MemeLabel} · pay {usd1}'**
  String launch2_launch2PoolViewModelLaunch2PoolSlippageFromInput(
    Object? launch2MemeLabel,
    Object? usd1,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:340
  ///
  /// In en, this message translates to:
  /// **'Official pool info is still syncing; trading isn\'t available yet'**
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView;

  /// lib/features/launch2/launch2_pool_view_model.dart:342
  ///
  /// In en, this message translates to:
  /// **'DEX pool trading isn\'t open yet (router not configured)'**
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView2;

  /// lib/features/launch2/launch2_pool_view_model.dart:344, lib/features/launch2/launch2_trade_panel.dart:429
  ///
  /// In en, this message translates to:
  /// **'No wallet available. Activate a wallet to trade'**
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView3;

  /// lib/features/launch2/launch2_pool_view_model.dart:353
  ///
  /// In en, this message translates to:
  /// **'Sell amount exceeds sellable {launch2MemeLabel}'**
  String launch2_launch2PoolViewModelLaunch2PoolTradeView4(
    Object? launch2MemeLabel,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:357
  ///
  /// In en, this message translates to:
  /// **'Not enough USD1: needs up to {usd1}, wallet has {usd12}'**
  String launch2_launch2PoolViewModelLaunch2PoolTradeView5(
    Object? usd1,
    Object? usd12,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:370
  ///
  /// In en, this message translates to:
  /// **'Getting a quote from the official pool…'**
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView6;

  /// lib/features/launch2/launch2_pool_view_model.dart:394
  ///
  /// In en, this message translates to:
  /// **'Holding {launch2MemeLabel}'**
  String launch2_launch2PoolViewModelLaunch2PoolTradeView7(
    Object? launch2MemeLabel,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:364
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a quote · {launch2PoolFailureText}'**
  String launch2_launch2PoolViewModelNull(Object? launch2PoolFailureText);

  /// lib/features/launch2/launch2_pool_view_model.dart:431
  ///
  /// In en, this message translates to:
  /// **'Based on the official pool at block {quotedAtBlock}, {quote}; re-quotes automatically when it expires.'**
  String launch2_launch2PoolViewModelProvenance(
    Object? quote,
    Object? quotedAtBlock,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:434
  ///
  /// In en, this message translates to:
  /// **'Based on the official pool at block {quotedAtBlock}, after the {launch2BpsLabel} DEX pool tax; re-quotes automatically when it expires.'**
  String launch2_launch2PoolViewModelProvenance2(
    Object? launch2BpsLabel,
    Object? quotedAtBlock,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:115
  ///
  /// In en, this message translates to:
  /// **'DEX pool router not configured; trading unavailable'**
  String get launch2_launch2PoolViewModelS;

  /// lib/features/launch2/launch2_pool_view_model.dart:125
  ///
  /// In en, this message translates to:
  /// **'The pool doesn\'t support this trade type'**
  String get launch2_launch2PoolViewModelS10;

  /// lib/features/launch2/launch2_pool_view_model.dart:126
  ///
  /// In en, this message translates to:
  /// **'The pool is busy. Try again later'**
  String get launch2_launch2PoolViewModelS11;

  /// lib/features/launch2/launch2_pool_view_model.dart:127
  ///
  /// In en, this message translates to:
  /// **'This round hasn\'t ended; claim after it ends'**
  String get launch2_launch2PoolViewModelS12;

  /// lib/features/launch2/launch2_pool_view_model.dart:128
  ///
  /// In en, this message translates to:
  /// **'This round\'s rewards were already claimed'**
  String get launch2_launch2PoolViewModelS13;

  /// lib/features/launch2/launch2_pool_view_model.dart:129
  ///
  /// In en, this message translates to:
  /// **'This claim already recorded another transaction'**
  String get launch2_launch2PoolViewModelS14;

  /// lib/features/launch2/launch2_pool_view_model.dart:131
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find this claim request'**
  String get launch2_launch2PoolViewModelS15;

  /// lib/features/launch2/launch2_pool_view_model.dart:206, lib/features/launch2/launch2_pool_view_model.dart:262, lib/features/launch2/launch2_signing.dart:197, lib/features/launch2/launch2_trade_panel.dart:824
  ///
  /// In en, this message translates to:
  /// **'Estimated to receive'**
  String get launch2_launch2PoolViewModelS16;

  /// lib/features/launch2/launch2_pool_view_model.dart:209, lib/features/launch2/launch2_pool_view_model.dart:263, lib/features/launch2/launch2_signing.dart:201, lib/features/launch2/launch2_trade_panel.dart:831
  ///
  /// In en, this message translates to:
  /// **'Minimum received'**
  String get launch2_launch2PoolViewModelS17;

  /// lib/features/launch2/launch2_pool_view_model.dart:211
  ///
  /// In en, this message translates to:
  /// **'Estimated sell'**
  String get launch2_launch2PoolViewModelS18;

  /// lib/features/launch2/launch2_pool_view_model.dart:212
  ///
  /// In en, this message translates to:
  /// **'Maximum sell'**
  String get launch2_launch2PoolViewModelS19;

  /// lib/features/launch2/launch2_pool_view_model.dart:116
  ///
  /// In en, this message translates to:
  /// **'DEX pool router check failed; trading unavailable'**
  String get launch2_launch2PoolViewModelS2;

  /// lib/features/launch2/launch2_pool_view_model.dart:359
  ///
  /// In en, this message translates to:
  /// **'Not enough {tickerLabel}: needs up to {launch2MemeLabel}, wallet has {launch2MemeLabel2}'**
  String launch2_launch2PoolViewModelS20(
    Object? launch2MemeLabel,
    Object? launch2MemeLabel2,
    Object? tickerLabel,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:370, lib/features/launch2/launch2_trade_panel.dart:769
  ///
  /// In en, this message translates to:
  /// **'Enter an amount to see a quote'**
  String get launch2_launch2PoolViewModelS21;

  /// lib/features/launch2/launch2_pool_view_model.dart:395
  ///
  /// In en, this message translates to:
  /// **'Holding {launch2MemeLabel} · sellable {launch2MemeLabel2}'**
  String launch2_launch2PoolViewModelS22(
    Object? launch2MemeLabel,
    Object? launch2MemeLabel2,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:457
  ///
  /// In en, this message translates to:
  /// **'{launch2MemeLabel} · get {usd1}'**
  String launch2_launch2PoolViewModelS23(
    Object? launch2MemeLabel,
    Object? usd1,
  );

  /// lib/features/launch2/launch2_pool_view_model.dart:117
  ///
  /// In en, this message translates to:
  /// **'DEX pool router doesn\'t match the pool; trading unavailable'**
  String get launch2_launch2PoolViewModelS3;

  /// lib/features/launch2/launch2_pool_view_model.dart:119
  ///
  /// In en, this message translates to:
  /// **'DEX pool check failed; trading unavailable'**
  String get launch2_launch2PoolViewModelS4;

  /// lib/features/launch2/launch2_pool_view_model.dart:120
  ///
  /// In en, this message translates to:
  /// **'The DEX pool isn\'t initialized yet'**
  String get launch2_launch2PoolViewModelS5;

  /// lib/features/launch2/launch2_pool_view_model.dart:121
  ///
  /// In en, this message translates to:
  /// **'This pool only supports trading by payment amount'**
  String get launch2_launch2PoolViewModelS6;

  /// lib/features/launch2/launch2_pool_view_model.dart:122
  ///
  /// In en, this message translates to:
  /// **'This project\'s DEX pool has no reward rounds'**
  String get launch2_launch2PoolViewModelS7;

  /// lib/features/launch2/launch2_pool_view_model.dart:123
  ///
  /// In en, this message translates to:
  /// **'Invalid round number'**
  String get launch2_launch2PoolViewModelS8;

  /// lib/features/launch2/launch2_pool_view_model.dart:124
  ///
  /// In en, this message translates to:
  /// **'The pool rejected this trade entry'**
  String get launch2_launch2PoolViewModelS9;

  /// lib/features/launch2/launch2_pool_view_model.dart:143
  ///
  /// In en, this message translates to:
  /// **'The official pool simulation failed. Try another amount'**
  String get launch2_launch2PoolViewModelSwitch;

  /// lib/features/launch2/launch2_pool_view_model.dart:144, lib/features/launch2/launch2_pool_view_model.dart:338
  ///
  /// In en, this message translates to:
  /// **'The project hasn\'t graduated; the official pool isn\'t open yet'**
  String get launch2_launch2PoolViewModelSwitch2;

  /// lib/features/launch2/launch2_pool_view_model.dart:145
  ///
  /// In en, this message translates to:
  /// **'Not enough liquidity in the official pool. Try a smaller amount'**
  String get launch2_launch2PoolViewModelSwitch3;

  /// lib/features/launch2/launch2_pool_view_model.dart:146
  ///
  /// In en, this message translates to:
  /// **'This amount is too small and converts to 0'**
  String get launch2_launch2PoolViewModelSwitch4;

  /// lib/features/launch2/launch2_pool_view_model.dart:150
  ///
  /// In en, this message translates to:
  /// **'DEX pool trading is closed while the platform checks the official pool'**
  String get launch2_launch2PoolViewModelSwitch5;

  /// lib/features/launch2/launch2_pool_view_model.dart:152
  ///
  /// In en, this message translates to:
  /// **'Not enough USD1; no transaction was made'**
  String get launch2_launch2PoolViewModelSwitch6;

  /// lib/features/launch2/launch2_pool_view_model.dart:153
  ///
  /// In en, this message translates to:
  /// **'Sell amount exceeds holdings; no transaction was made'**
  String get launch2_launch2PoolViewModelSwitch7;

  /// lib/features/launch2/launch2_pool_view_model.dart:407
  ///
  /// In en, this message translates to:
  /// **'{launch2BpsLabel} + dyn. tax'**
  String launch2_launch2PoolViewModelTaxLabel(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_pool_view_model.dart:398
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load wallet balance · shown after quote'**
  String get launch2_launch2PoolViewModelText;

  /// lib/features/launch2/launch2_pool_view_model.dart:400
  ///
  /// In en, this message translates to:
  /// **'Bonding pool net buys {launch2MemeLabel} · wallet balance shown after quote'**
  String launch2_launch2PoolViewModelText2(Object? launch2MemeLabel);

  /// lib/features/launch2/launch2_widgets.dart:211
  ///
  /// In en, this message translates to:
  /// **'Bonding pool progress {launch2BpsLabel}, current price {launch2PriceLabel}'**
  String launch2_launch2Public(
    Object? launch2BpsLabel,
    Object? launch2PriceLabel,
  );

  /// lib/features/launch2/launch2_signing.dart:1105
  ///
  /// In en, this message translates to:
  /// **'Confirm in your wallet'**
  String get launch2_launch2SigningActive;

  /// lib/features/launch2/launch2_signing.dart:1148
  ///
  /// In en, this message translates to:
  /// **'Continue to mint'**
  String get launch2_launch2SigningConfirmLabel;

  /// lib/features/launch2/launch2_signing.dart:94
  ///
  /// In en, this message translates to:
  /// **'Confirm {noun}'**
  String launch2_launch2SigningCurve(Object? noun);

  /// lib/features/launch2/launch2_signing.dart:1108
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get launch2_launch2SigningFailed;

  /// lib/features/launch2/launch2_signing.dart:1159
  ///
  /// In en, this message translates to:
  /// **'Mint {ticker} consensus medal'**
  String launch2_launch2SigningHeading(Object? ticker);

  /// lib/features/launch2/launch2_signing.dart:123
  ///
  /// In en, this message translates to:
  /// **'Base tax {launch2BpsLabel} + dynamic tax {launch2BpsLabel2}'**
  String launch2_launch2SigningIf(
    Object? launch2BpsLabel,
    Object? launch2BpsLabel2,
  );

  /// lib/features/launch2/launch2_signing.dart:130
  ///
  /// In en, this message translates to:
  /// **'Base tax {launch2BpsLabel} ({launch2BuyFeeSideText})'**
  String launch2_launch2SigningIf2(
    Object? launch2BpsLabel,
    Object? launch2BuyFeeSideText,
  );

  /// lib/features/launch2/launch2_signing.dart:339
  ///
  /// In en, this message translates to:
  /// **'Approval broadcast ({launch2ShortAddress}), but the wallet result of the {noun} transaction is unknown, so it\'s locked. Don\'t sign again; refresh later.'**
  String launch2_launch2SigningIf3(Object? launch2ShortAddress, Object? noun);

  /// lib/features/launch2/launch2_signing.dart:342
  ///
  /// In en, this message translates to:
  /// **'The wallet result is unknown, so this {noun} is locked. Don\'t sign again; refresh later.'**
  String launch2_launch2SigningIf4(Object? noun);

  /// lib/features/launch2/launch2_signing.dart:344
  ///
  /// In en, this message translates to:
  /// **'Broadcast ({launch2ShortAddress}). Broadcast doesn\'t mean filled; this updates after on-chain confirmation.'**
  String launch2_launch2SigningIf5(Object? launch2ShortAddress);

  /// lib/features/launch2/launch2_signing.dart:157
  ///
  /// In en, this message translates to:
  /// **'Buy {meme} in the official pool'**
  String launch2_launch2SigningIntentField(Object? meme);

  /// lib/features/launch2/launch2_signing.dart:161
  ///
  /// In en, this message translates to:
  /// **'Sell {meme} in the official pool'**
  String launch2_launch2SigningIntentField2(Object? meme);

  /// lib/features/launch2/launch2_signing.dart:229
  ///
  /// In en, this message translates to:
  /// **'Can\'t simulate before approval'**
  String get launch2_launch2SigningIntentField3;

  /// lib/features/launch2/launch2_signing.dart:172
  ///
  /// In en, this message translates to:
  /// **'Maximum payment (incl. tax)'**
  String get launch2_launch2SigningLabel;

  /// lib/features/launch2/launch2_signing.dart:217
  ///
  /// In en, this message translates to:
  /// **'Approve first'**
  String get launch2_launch2SigningLabel2;

  /// lib/features/launch2/launch2_signing.dart:1225, lib/features/launch2/launch2_trade_panel.dart:858
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get launch2_launch2SigningLabel3;

  /// lib/features/launch2/launch2_signing.dart:1269
  ///
  /// In en, this message translates to:
  /// **'I understand: {launch2NftRiskSentence}.'**
  String launch2_launch2SigningLaunch2NftRisk(Object? launch2NftRiskSentence);

  /// lib/features/launch2/launch2_signing.dart:1136
  ///
  /// In en, this message translates to:
  /// **'fills and allocation aren\'t guaranteed, and the public pool may not happen'**
  String get launch2_launch2SigningLaunch2NftRiskSentence;

  /// lib/features/launch2/launch2_signing.dart:1244
  ///
  /// In en, this message translates to:
  /// **'I understand: {launch2NftRiskSentence}'**
  String launch2_launch2SigningLaunch2NftRiskTickLabel(
    Object? launch2NftRiskSentence,
  );

  /// lib/features/launch2/launch2_signing.dart:1075
  ///
  /// In en, this message translates to:
  /// **'Quote refreshed: the old quote was about to expire, so it was re-quoted at the latest block within the range you confirmed'**
  String get launch2_launch2SigningLaunch2RefreshedText;

  /// lib/features/launch2/launch2_signing.dart:93
  ///
  /// In en, this message translates to:
  /// **'Confirm DEX pool reward claim'**
  String get launch2_launch2SigningLoopDynamicRewards;

  /// lib/features/launch2/launch2_signing.dart:154
  ///
  /// In en, this message translates to:
  /// **'{noun} {ticker} consensus medal (1 per address)'**
  String launch2_launch2SigningNftMint(Object? noun, Object? ticker);

  /// lib/features/launch2/launch2_signing.dart:92
  ///
  /// In en, this message translates to:
  /// **'Confirm DEX pool {noun}'**
  String launch2_launch2SigningOfficialPool(Object? noun);

  /// lib/features/launch2/launch2_signing.dart:111
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get launch2_launch2SigningOfficialPool2;

  /// lib/features/launch2/launch2_signing.dart:862
  ///
  /// In en, this message translates to:
  /// **'Your wallet opens twice: approve first, then {noun}. The approval covers only this one.'**
  String launch2_launch2SigningReason(Object? noun);

  /// lib/features/launch2/launch2_signing.dart:1106
  ///
  /// In en, this message translates to:
  /// **'Refreshing quote'**
  String get launch2_launch2SigningRefreshing;

  /// lib/features/launch2/launch2_signing.dart:82
  ///
  /// In en, this message translates to:
  /// **'reward claim'**
  String get launch2_launch2SigningRewardClaim;

  /// lib/features/launch2/launch2_signing.dart:163
  ///
  /// In en, this message translates to:
  /// **'Claim {meme} DEX pool rewards'**
  String launch2_launch2SigningRewardClaim2(Object? meme);

  /// lib/features/launch2/launch2_signing.dart:105
  ///
  /// In en, this message translates to:
  /// **'Curve contract'**
  String get launch2_launch2SigningS;

  /// lib/features/launch2/launch2_signing.dart:135, lib/features/launch2/launch2_trade_panel.dart:847
  ///
  /// In en, this message translates to:
  /// **'Tax {launch2BpsLabel}'**
  String launch2_launch2SigningS2(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_signing.dart:158
  ///
  /// In en, this message translates to:
  /// **'Buy {meme}'**
  String launch2_launch2SigningS3(Object? meme);

  /// lib/features/launch2/launch2_signing.dart:162
  ///
  /// In en, this message translates to:
  /// **'Sell {meme}'**
  String launch2_launch2SigningS4(Object? meme);

  /// lib/features/launch2/launch2_signing.dart:282
  ///
  /// In en, this message translates to:
  /// **'couldn\'t get a new quote ({launch2PoolFailureText})'**
  String launch2_launch2SigningS5(Object? launch2PoolFailureText);

  /// lib/features/launch2/launch2_signing.dart:930
  ///
  /// In en, this message translates to:
  /// **'Approval broadcast, but the {noun} wasn\'t signed and no {noun2} transaction was submitted. Close and start again.'**
  String launch2_launch2SigningSetState(Object? noun, Object? noun2);

  /// lib/features/launch2/launch2_signing.dart:1236
  ///
  /// In en, this message translates to:
  /// **'Addresses holding the NFT join the snapshot allowlist and can take part in the 1-hour priority buy.'**
  String get launch2_launch2SigningShowLaunch2NftConfirmSheet;

  /// lib/features/launch2/launch2_signing.dart:100, lib/features/launch2/launch2_signing.dart:112
  ///
  /// In en, this message translates to:
  /// **'Rewards contract'**
  String get launch2_launch2SigningSwitch;

  /// lib/features/launch2/launch2_signing.dart:263
  ///
  /// In en, this message translates to:
  /// **'The wallet the server built this transaction for doesn\'t match the current wallet. Signing refused; nothing was submitted.'**
  String get launch2_launch2SigningSwitch10;

  /// lib/features/launch2/launch2_signing.dart:265
  ///
  /// In en, this message translates to:
  /// **'Signing isn\'t allowed on this chain. Nothing was submitted.'**
  String get launch2_launch2SigningSwitch11;

  /// lib/features/launch2/launch2_signing.dart:266
  ///
  /// In en, this message translates to:
  /// **'The wallet can\'t sign on this chain right now. Nothing was submitted.'**
  String get launch2_launch2SigningSwitch12;

  /// lib/features/launch2/launch2_signing.dart:267
  ///
  /// In en, this message translates to:
  /// **'The signed-in wallet isn\'t this transaction\'s wallet. Nothing was submitted.'**
  String get launch2_launch2SigningSwitch13;

  /// lib/features/launch2/launch2_signing.dart:268
  ///
  /// In en, this message translates to:
  /// **'The wallet didn\'t finish signing. Nothing was submitted.'**
  String get launch2_launch2SigningSwitch14;

  /// lib/features/launch2/launch2_signing.dart:277
  ///
  /// In en, this message translates to:
  /// **'approval is still confirming on-chain'**
  String get launch2_launch2SigningSwitch15;

  /// lib/features/launch2/launch2_signing.dart:278
  ///
  /// In en, this message translates to:
  /// **'the latest quote was outside the range you confirmed'**
  String get launch2_launch2SigningSwitch16;

  /// lib/features/launch2/launch2_signing.dart:281
  ///
  /// In en, this message translates to:
  /// **'couldn\'t get a new quote'**
  String get launch2_launch2SigningSwitch17;

  /// lib/features/launch2/launch2_signing.dart:283
  ///
  /// In en, this message translates to:
  /// **'the new transaction didn\'t pass the check'**
  String get launch2_launch2SigningSwitch18;

  /// lib/features/launch2/launch2_signing.dart:285
  ///
  /// In en, this message translates to:
  /// **'Approval broadcast. The old quote was about to expire and on refresh {why}, so the {noun} wasn\'t signed and no {noun2} transaction was submitted. Start again later; with enough approval you only sign once.'**
  String launch2_launch2SigningSwitch19(
    Object? noun,
    Object? noun2,
    Object? why,
  );

  /// lib/features/launch2/launch2_signing.dart:104
  ///
  /// In en, this message translates to:
  /// **'NFT contract'**
  String get launch2_launch2SigningSwitch2;

  /// lib/features/launch2/launch2_signing.dart:327
  ///
  /// In en, this message translates to:
  /// **'Approval broadcast, but the {noun} wasn\'t signed. You can start again.'**
  String launch2_launch2SigningSwitch20(Object? noun);

  /// lib/features/launch2/launch2_signing.dart:115
  ///
  /// In en, this message translates to:
  /// **'Approved for: {spenderNoun}'**
  String launch2_launch2SigningSwitch3(Object? spenderNoun);

  /// lib/features/launch2/launch2_signing.dart:256
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing changed.'**
  String get launch2_launch2SigningSwitch4;

  /// lib/features/launch2/launch2_signing.dart:257
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Nothing changed.'**
  String get launch2_launch2SigningSwitch5;

  /// lib/features/launch2/launch2_signing.dart:258
  ///
  /// In en, this message translates to:
  /// **'This transaction expired and nothing was submitted. Start again.'**
  String get launch2_launch2SigningSwitch6;

  /// lib/features/launch2/launch2_signing.dart:259
  ///
  /// In en, this message translates to:
  /// **'The simulation failed; this transaction would be rejected on-chain. Nothing was submitted.'**
  String get launch2_launch2SigningSwitch7;

  /// lib/features/launch2/launch2_signing.dart:260
  ///
  /// In en, this message translates to:
  /// **'The transaction doesn\'t match what you confirmed. Signing refused; nothing was submitted.'**
  String get launch2_launch2SigningSwitch8;

  /// lib/features/launch2/launch2_signing.dart:261
  ///
  /// In en, this message translates to:
  /// **'The wallet directory doesn\'t have this transaction\'s wallet. Nothing was submitted.'**
  String get launch2_launch2SigningSwitch9;

  /// lib/features/launch2/launch2_signing.dart:479, lib/features/launch2/launch2_signing.dart:1119
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get launch2_launch2SigningTitle;

  /// lib/features/launch2/launch2_signing.dart:1109
  ///
  /// In en, this message translates to:
  /// **'Result unknown'**
  String get launch2_launch2SigningUnknown;

  /// lib/features/launch2/launch2_signing.dart:1231
  ///
  /// In en, this message translates to:
  /// **'1 per address, ever'**
  String get launch2_launch2SigningValue;

  /// lib/features/launch2/launch2_widgets.dart:368
  ///
  /// In en, this message translates to:
  /// **'until mint'**
  String get launch2_launch2Switch;

  /// lib/features/launch2/launch2_trade_panel.dart:433
  ///
  /// In en, this message translates to:
  /// **'Priority buy is for allowlisted holders; buying opens with the public pool'**
  String get launch2_launch2TradePanelBuild;

  /// lib/features/launch2/launch2_trade_panel.dart:638
  ///
  /// In en, this message translates to:
  /// **'Total quota'**
  String get launch2_launch2TradePanelBuild2;

  /// lib/features/launch2/launch2_trade_panel.dart:815
  ///
  /// In en, this message translates to:
  /// **'Fill {launch2Usd1Label}'**
  String launch2_launch2TradePanelIf(Object? launch2Usd1Label);

  /// lib/features/launch2/launch2_trade_panel.dart:853
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get launch2_launch2TradePanelLabel;

  /// lib/features/launch2/launch2_trade_panel.dart:928
  ///
  /// In en, this message translates to:
  /// **'Based on the current curve price with {launch2BpsLabel} slippage protection; the on-chain fill is final'**
  String launch2_launch2TradePanelLaunch2CurveMinOutNote(
    Object? launch2BpsLabel,
  );

  /// lib/features/launch2/launch2_trade_panel.dart:558
  ///
  /// In en, this message translates to:
  /// **'Listed'**
  String get launch2_launch2TradePanelLaunch2EligibilityBadge;

  /// lib/features/launch2/launch2_trade_panel.dart:558
  ///
  /// In en, this message translates to:
  /// **'Not listed'**
  String get launch2_launch2TradePanelLaunch2EligibilityBadge2;

  /// lib/features/launch2/launch2_trade_panel.dart:797
  ///
  /// In en, this message translates to:
  /// **'Over the {side} limit ({launch2LimitedByText})'**
  String launch2_launch2TradePanelLaunch2TradeExceeds(
    Object? launch2LimitedByText,
    Object? side,
  );

  /// lib/features/launch2/launch2_trade_panel.dart:682
  ///
  /// In en, this message translates to:
  /// **'Fill max buyable'**
  String get launch2_launch2TradePanelLaunch2TradeMaxLabel;

  /// lib/features/launch2/launch2_trade_panel.dart:769
  ///
  /// In en, this message translates to:
  /// **'Getting a quote…'**
  String get launch2_launch2TradePanelLaunch2TradeQuoteEmpty;

  /// lib/features/launch2/launch2_trade_panel.dart:763
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a quote · {failureText}'**
  String launch2_launch2TradePanelLaunch2TradeQuoteFailedMessage(
    Object? failureText,
  );

  /// lib/features/launch2/launch2_trade_panel.dart:870
  ///
  /// In en, this message translates to:
  /// **'Quoted on the curve at block {basisBlockNumber}, incl. the 10% tax; slippage {launch2BpsLabel}; re-quotes automatically when it expires.'**
  String launch2_launch2TradePanelLaunch2TradeQuoteProvenanceDetail(
    Object? basisBlockNumber,
    Object? launch2BpsLabel,
  );

  /// lib/features/launch2/launch2_trade_panel.dart:567
  ///
  /// In en, this message translates to:
  /// **'Tax {launch2BpsLabel}'**
  String launch2_launch2TradePanelLaunch2TradeTax(Object? launch2BpsLabel);

  /// lib/features/launch2/launch2_trade_panel.dart:866
  ///
  /// In en, this message translates to:
  /// **'On-chain curve'**
  String get launch2_launch2TradePanelLoopProvenanceLine;

  /// lib/features/launch2/launch2_trade_panel.dart:816
  ///
  /// In en, this message translates to:
  /// **'Fill {launch2MemeLabel}'**
  String launch2_launch2TradePanelS(Object? launch2MemeLabel);

  /// lib/features/launch2/launch2_trade_panel.dart:663
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load total quota'**
  String get launch2_launch2TradePanelSemanticLabel;

  /// lib/features/launch2/launch2_trade_panel.dart:664
  ///
  /// In en, this message translates to:
  /// **'Total quota used {launch2MemeFigure} {tickerLabel}, {launch2CurveCapSentence}'**
  String launch2_launch2TradePanelSemanticLabel2(
    Object? launch2CurveCapSentence,
    Object? launch2MemeFigure,
    Object? tickerLabel,
  );

  /// lib/features/launch2/launch2_wallet_rows.dart:155
  ///
  /// In en, this message translates to:
  /// **'Launch chain'**
  String get launch2_launch2WalletRowsLaunch2WalletChainLabel;

  /// lib/features/launch2/launch2_wallet_rows.dart:94
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load MEME v2 holdings'**
  String get launch2_launch2WalletRowsLaunch2WalletUnavailableMessage;

  /// lib/features/launch2/launch2_wallet_rows.dart:128
  ///
  /// In en, this message translates to:
  /// **'{launch2WalletChainLabel} · bonding pool holdings'**
  String launch2_launch2WalletRowsSubtitle(Object? launch2WalletChainLabel);

  /// lib/features/launch2/launch2_launchpad.dart:64
  ///
  /// In en, this message translates to:
  /// **'Someone '**
  String get launch2_launchpadSomeoneWho;

  /// lib/features/launch2/launch2_instance_screen.dart:1297
  ///
  /// In en, this message translates to:
  /// **'{sentence}.'**
  String launch2_nftRiskBody(Object? sentence);

  /// lib/features/launch2/launch2_widgets.dart:208
  ///
  /// In en, this message translates to:
  /// **', {left} left'**
  String launch2_nftSaleLeft(Object? left);

  /// lib/features/launch2/launch2_pool_view_model.dart:529
  ///
  /// In en, this message translates to:
  /// **'Tax {bps}'**
  String launch2_poolPanelTax(Object? bps);

  /// lib/features/launch2/launch2_instance_screen.dart:1659
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again later'**
  String get launch2_poolTradesRateLimited;

  /// lib/features/launch2/launch2_pool_view_model.dart:429
  ///
  /// In en, this message translates to:
  /// **'{bps} base tax taken from the USD1 paid'**
  String launch2_provenanceBuyFeeFromUsd1(Object? bps);

  /// lib/features/launch2/launch2_pool_view_model.dart:429
  ///
  /// In en, this message translates to:
  /// **'after the {bps} DEX pool tax'**
  String launch2_provenancePoolTax(Object? bps);

  /// lib/features/launch2/launch2_pool_view_model.dart:429
  ///
  /// In en, this message translates to:
  /// **'after base and dynamic tax (simulated on the post-trade drop)'**
  String get launch2_provenanceSellPostSwap;

  /// lib/features/launch2/launch2_pool_view_model.dart:429
  ///
  /// In en, this message translates to:
  /// **'after base and dynamic tax (simulated on the pre-trade drop)'**
  String get launch2_provenanceSellPreSwap;

  /// lib/features/launch2/launch2_trade_panel.dart:797
  ///
  /// In en, this message translates to:
  /// **'buy'**
  String get launch2_sideBuy;

  /// lib/features/launch2/launch2_trade_panel.dart:797
  ///
  /// In en, this message translates to:
  /// **'sell'**
  String get launch2_sideSell;

  /// lib/features/launch2/launch2_atmosphere.dart:227
  ///
  /// In en, this message translates to:
  /// **'; '**
  String get launch2_tickerSeparator;

  /// lib/features/launch/launch_action_screens.dart:180
  ///
  /// In en, this message translates to:
  /// **'Stake amount'**
  String get launch_actionScreensBuild;

  /// lib/features/launch/launch_action_screens.dart:205
  ///
  /// In en, this message translates to:
  /// **'The staking contract isn\'t live yet. This page accepts no amount and opens no signature.'**
  String get launch_actionScreensBuild2;

  /// lib/features/launch/launch_action_screens.dart:985
  ///
  /// In en, this message translates to:
  /// **'Evaluate first, then launch'**
  String get launch_actionScreensBuild3;

  /// lib/features/launch/launch_action_screens.dart:988
  ///
  /// In en, this message translates to:
  /// **'LOOP works with exchanges, KOLs and communities to pick projects with a narrative, reach and long-term operations.'**
  String get launch_actionScreensBuild4;

  /// lib/features/launch/launch_action_screens.dart:992
  ///
  /// In en, this message translates to:
  /// **'Manual review, cap settings, liquidity plan'**
  String get launch_actionScreensBuild5;

  /// lib/features/launch/launch_action_screens.dart:1233
  ///
  /// In en, this message translates to:
  /// **'Details are read-only in this status. Only drafts and returned applications can be edited.'**
  String get launch_actionScreensBuild6;

  /// lib/features/launch/launch_action_screens.dart:63
  ///
  /// In en, this message translates to:
  /// **'Staked amount, available balance and the unbonding period all need the staking contract. This page builds no transaction and opens no signature.'**
  String get launch_actionScreensCaption;

  /// lib/features/launch/launch_action_screens.dart:258
  ///
  /// In en, this message translates to:
  /// **'Only amounts LOOP can verify are shown here. Total supply, issuance and ecosystem tax can\'t be loaded yet.'**
  String get launch_actionScreensCaption2;

  /// lib/features/launch/launch_action_screens.dart:727
  ///
  /// In en, this message translates to:
  /// **'Submitting doesn\'t mean approval. Review is manual; the result and listing time follow the latest status.'**
  String get launch_actionScreensCaption3;

  /// lib/features/launch/launch_action_screens.dart:421
  ///
  /// In en, this message translates to:
  /// **'Registered launches'**
  String get launch_actionScreensCell;

  /// lib/features/launch/launch_action_screens.dart:428
  ///
  /// In en, this message translates to:
  /// **'Total volume'**
  String get launch_actionScreensCell2;

  /// lib/features/launch/launch_action_screens.dart:429
  ///
  /// In en, this message translates to:
  /// **'Total ecosystem tax'**
  String get launch_actionScreensCell3;

  /// lib/features/launch/launch_action_screens.dart:506
  ///
  /// In en, this message translates to:
  /// **'Total raised (successful sales only)'**
  String get launch_actionScreensCell4;

  /// lib/features/launch/launch_action_screens.dart:517
  ///
  /// In en, this message translates to:
  /// **'Registered sales'**
  String get launch_actionScreensCell5;

  /// lib/features/launch/launch_action_screens.dart:525
  ///
  /// In en, this message translates to:
  /// **'LP locked'**
  String get launch_actionScreensCell6;

  /// lib/features/launch/launch_action_screens.dart:920
  ///
  /// In en, this message translates to:
  /// **', current status'**
  String get launch_actionScreensCurrentSuffix;

  /// lib/features/launch/launch_action_screens.dart:95
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load staking status'**
  String get launch_actionScreensEmptyMessage;

  /// lib/features/launch/launch_action_screens.dart:277
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load ledger counts'**
  String get launch_actionScreensEmptyMessage2;

  /// lib/features/launch/launch_action_screens.dart:748
  ///
  /// In en, this message translates to:
  /// **'No applications yet'**
  String get launch_actionScreensEmptyMessage3;

  /// lib/features/launch/launch_action_screens.dart:1033
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load listing progress'**
  String get launch_actionScreensEmptyMessage4;

  /// lib/features/launch/launch_action_screens.dart:96
  ///
  /// In en, this message translates to:
  /// **'Staking isn\'t open yet.'**
  String get launch_actionScreensEmptyReason;

  /// lib/features/launch/launch_action_screens.dart:278
  ///
  /// In en, this message translates to:
  /// **'No verifiable amounts can be loaded right now.'**
  String get launch_actionScreensEmptyReason2;

  /// lib/features/launch/launch_action_screens.dart:749
  ///
  /// In en, this message translates to:
  /// **'Fill in the form below to create your first draft.'**
  String get launch_actionScreensEmptyReason3;

  /// lib/features/launch/launch_action_screens.dart:1034
  ///
  /// In en, this message translates to:
  /// **'Progress is recorded by operations. This page infers no listing outcome.'**
  String get launch_actionScreensEmptyReason4;

  /// lib/features/launch/launch_action_screens.dart:62, lib/features/launch/launch_action_screens.dart:77
  ///
  /// In en, this message translates to:
  /// **'Staking isn\'t open yet'**
  String get launch_actionScreensHeading;

  /// lib/features/launch/launch_action_screens.dart:257
  ///
  /// In en, this message translates to:
  /// **'{confirmedRoundCount, plural, =1{1 confirmed round} other{{confirmedRoundCount} confirmed rounds}}'**
  String launch_actionScreensHeading2(num confirmedRoundCount);

  /// lib/features/launch/launch_action_screens.dart:725
  ///
  /// In en, this message translates to:
  /// **'{reviewPipeline}-step review'**
  String launch_actionScreensHeading3(Object? reviewPipeline);

  /// lib/features/launch/launch_action_screens.dart:61
  ///
  /// In en, this message translates to:
  /// **'Staking position'**
  String get launch_actionScreensKicker;

  /// lib/features/launch/launch_action_screens.dart:253
  ///
  /// In en, this message translates to:
  /// **'Public economy'**
  String get launch_actionScreensKicker2;

  /// lib/features/launch/launch_action_screens.dart:720, lib/features/launch/launch_action_screens.dart:983
  ///
  /// In en, this message translates to:
  /// **'Curated launch'**
  String get launch_actionScreensKicker3;

  /// lib/features/launch/launch_action_screens.dart:72
  ///
  /// In en, this message translates to:
  /// **'Wallet available balance'**
  String get launch_actionScreensLabel;

  /// lib/features/launch/launch_action_screens.dart:107
  ///
  /// In en, this message translates to:
  /// **'Stake'**
  String get launch_actionScreensLabel2;

  /// lib/features/launch/launch_action_screens.dart:108
  ///
  /// In en, this message translates to:
  /// **'Unstake'**
  String get launch_actionScreensLabel3;

  /// lib/features/launch/launch_action_screens.dart:127
  ///
  /// In en, this message translates to:
  /// **'My staking'**
  String get launch_actionScreensLabel4;

  /// lib/features/launch/launch_action_screens.dart:302
  ///
  /// In en, this message translates to:
  /// **'Total distributed'**
  String get launch_actionScreensLabel5;

  /// lib/features/launch/launch_action_screens.dart:303
  ///
  /// In en, this message translates to:
  /// **'Confirmed rounds'**
  String get launch_actionScreensLabel6;

  /// lib/features/launch/launch_action_screens.dart:304
  ///
  /// In en, this message translates to:
  /// **'Approved applications'**
  String get launch_actionScreensLabel7;

  /// lib/features/launch/launch_action_screens.dart:1263
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get launch_actionScreensLabel8;

  /// lib/features/launch/launch_action_screens.dart:1168
  ///
  /// In en, this message translates to:
  /// **'Project name (1–20 characters)'**
  String get launch_actionScreensLabelText;

  /// lib/features/launch/launch_action_screens.dart:1179
  ///
  /// In en, this message translates to:
  /// **'Ticker (1–20 characters: Chinese, letters, digits, emoji)'**
  String get launch_actionScreensLabelText2;

  /// lib/features/launch/launch_action_screens.dart:1190
  ///
  /// In en, this message translates to:
  /// **'Narrative (optional, ≤2000)'**
  String get launch_actionScreensLabelText3;

  /// lib/features/launch/launch_action_screens.dart:1200
  ///
  /// In en, this message translates to:
  /// **'Website (optional, https://)'**
  String get launch_actionScreensLabelText4;

  /// lib/features/launch/launch_action_screens.dart:1209
  ///
  /// In en, this message translates to:
  /// **'X (optional, https://)'**
  String get launch_actionScreensLabelText5;

  /// lib/features/launch/launch_action_screens.dart:1217
  ///
  /// In en, this message translates to:
  /// **'Telegram (optional, https://)'**
  String get launch_actionScreensLabelText6;

  /// lib/features/launch/launch_action_screens.dart:1226
  ///
  /// In en, this message translates to:
  /// **'Discord (optional, https://)'**
  String get launch_actionScreensLabelText7;

  /// lib/features/launch/launch_action_screens.dart:737
  ///
  /// In en, this message translates to:
  /// **'Applications aren\'t available right now'**
  String get launch_actionScreensLaunchApplyCapabilityUnavailableTitle;

  /// lib/features/launch/launch_action_screens.dart:1267
  ///
  /// In en, this message translates to:
  /// **'Entity review isn\'t open yet'**
  String get launch_actionScreensLaunchApplyKybMessage;

  /// lib/features/launch/launch_action_screens.dart:1104
  ///
  /// In en, this message translates to:
  /// **'A directory entry is created only after approval'**
  String get launch_actionScreensLaunchApplyLaunchIdSubtitle;

  /// lib/features/launch/launch_action_screens.dart:1105
  ///
  /// In en, this message translates to:
  /// **'In the directory, awaiting schedule'**
  String get launch_actionScreensLaunchApplyLaunchIdSubtitle2;

  /// lib/features/launch/launch_action_screens.dart:1102
  ///
  /// In en, this message translates to:
  /// **'Directory entry'**
  String get launch_actionScreensLaunchApplyLaunchIdTitle;

  /// lib/features/launch/launch_action_screens.dart:1106
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get launch_actionScreensLaunchApplyLaunchIdTrailing;

  /// lib/features/launch/launch_action_screens.dart:793
  ///
  /// In en, this message translates to:
  /// **'New application'**
  String get launch_actionScreensLaunchApplyNewLabel;

  /// lib/features/launch/launch_action_screens.dart:884
  ///
  /// In en, this message translates to:
  /// **'Review is manual. Only approved projects enter the directory, then wait for a confirmed schedule.'**
  String get launch_actionScreensLaunchApplyNoticeBody;

  /// lib/features/launch/launch_action_screens.dart:883
  ///
  /// In en, this message translates to:
  /// **'Submitting doesn\'t mean approval'**
  String get launch_actionScreensLaunchApplyNoticeTitle;

  /// lib/features/launch/launch_action_screens.dart:874
  ///
  /// In en, this message translates to:
  /// **'Screening principles and submission notes'**
  String get launch_actionScreensLaunchApplyPrinciplesSummary;

  /// lib/features/launch/launch_action_screens.dart:1255
  ///
  /// In en, this message translates to:
  /// **'Once open, upload materials and check review status here.'**
  String get launch_actionScreensLaunchApplyProvidersPendingDetail;

  /// lib/features/launch/launch_action_screens.dart:1254
  ///
  /// In en, this message translates to:
  /// **'Attachment upload and entity review aren\'t open yet'**
  String get launch_actionScreensLaunchApplyProvidersPendingMessage;

  /// lib/features/launch/launch_action_screens.dart:1116
  ///
  /// In en, this message translates to:
  /// **'Reason returned'**
  String get launch_actionScreensLaunchApplyReturnedReasonTitle;

  /// lib/features/launch/launch_action_screens.dart:1094
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get launch_actionScreensLaunchApplyReviewedAtTitle;

  /// lib/features/launch/launch_action_screens.dart:851
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get launch_actionScreensLaunchApplySaveLabel;

  /// lib/features/launch/launch_action_screens.dart:851
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get launch_actionScreensLaunchApplySaveLabel2;

  /// lib/features/launch/launch_action_screens.dart:715, lib/features/launch/launch_screen.dart:265
  ///
  /// In en, this message translates to:
  /// **'Apply to launch'**
  String get launch_actionScreensLaunchApplyScreenTitle;

  /// lib/features/launch/launch_action_screens.dart:862
  ///
  /// In en, this message translates to:
  /// **'Resubmit'**
  String get launch_actionScreensLaunchApplySubmitLabel;

  /// lib/features/launch/launch_action_screens.dart:863
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get launch_actionScreensLaunchApplySubmitLabel2;

  /// lib/features/launch/launch_action_screens.dart:1085
  ///
  /// In en, this message translates to:
  /// **'Only the applicant can see the review history'**
  String get launch_actionScreensLaunchApplySubmittedAtSubtitle;

  /// lib/features/launch/launch_action_screens.dart:1086
  ///
  /// In en, this message translates to:
  /// **'Review history and versions belong to the applicant only'**
  String get launch_actionScreensLaunchApplySubmittedAtSubtitle2;

  /// lib/features/launch/launch_action_screens.dart:1081
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get launch_actionScreensLaunchApplySubmittedAtTitle;

  /// lib/features/launch/launch_action_screens.dart:824
  ///
  /// In en, this message translates to:
  /// **'This submission didn\'t finish'**
  String get launch_actionScreensLaunchApplyWriteFailureTitle;

  /// lib/features/launch/launch_action_screens.dart:185
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get launch_actionScreensLoopBadge;

  /// lib/features/launch/launch_action_screens.dart:915
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get launch_actionScreensLoopBadge2;

  /// lib/features/launch/launch_action_screens.dart:266
  ///
  /// In en, this message translates to:
  /// **'The ecosystem ledger isn\'t available right now'**
  String get launch_actionScreensLoopEconomyCapabilityUnavailableTitle;

  /// lib/features/launch/launch_action_screens.dart:534
  ///
  /// In en, this message translates to:
  /// **'Read at block {groupedFigure}, LOOP on-chain event index'**
  String launch_actionScreensLoopEconomyOnchainBlock(Object? groupedFigure);

  /// lib/features/launch/launch_action_screens.dart:490
  ///
  /// In en, this message translates to:
  /// **'The on-chain ledger can\'t be loaded right now'**
  String get launch_actionScreensLoopEconomyOnchainUnavailableMessage;

  /// lib/features/launch/launch_action_screens.dart:248
  ///
  /// In en, this message translates to:
  /// **'LOOP ecosystem ledger'**
  String get launch_actionScreensLoopEconomyScreenTitle;

  /// lib/features/launch/launch_action_screens.dart:282
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch_actionScreensLoopLabel;

  /// lib/features/launch/launch_action_screens.dart:1027
  ///
  /// In en, this message translates to:
  /// **'Exchange listing progress'**
  String get launch_actionScreensLoopLabel10;

  /// lib/features/launch/launch_action_screens.dart:1067
  ///
  /// In en, this message translates to:
  /// **'Review status'**
  String get launch_actionScreensLoopLabel11;

  /// lib/features/launch/launch_action_screens.dart:294
  ///
  /// In en, this message translates to:
  /// **'On-chain ledger'**
  String get launch_actionScreensLoopLabel2;

  /// lib/features/launch/launch_action_screens.dart:311
  ///
  /// In en, this message translates to:
  /// **'Value flywheel'**
  String get launch_actionScreensLoopLabel3;

  /// lib/features/launch/launch_action_screens.dart:328
  ///
  /// In en, this message translates to:
  /// **'Application status counts'**
  String get launch_actionScreensLoopLabel4;

  /// lib/features/launch/launch_action_screens.dart:350
  ///
  /// In en, this message translates to:
  /// **'Schedule status counts'**
  String get launch_actionScreensLoopLabel5;

  /// lib/features/launch/launch_action_screens.dart:758
  ///
  /// In en, this message translates to:
  /// **'Review history'**
  String get launch_actionScreensLoopLabel6;

  /// lib/features/launch/launch_action_screens.dart:772
  ///
  /// In en, this message translates to:
  /// **'My applications'**
  String get launch_actionScreensLoopLabel7;

  /// lib/features/launch/launch_action_screens.dart:805
  ///
  /// In en, this message translates to:
  /// **'Project details'**
  String get launch_actionScreensLoopLabel8;

  /// lib/features/launch/launch_action_screens.dart:817
  ///
  /// In en, this message translates to:
  /// **'Attachments and entity review'**
  String get launch_actionScreensLoopLabel9;

  /// lib/features/launch/launch_action_screens.dart:84
  ///
  /// In en, this message translates to:
  /// **'LOOP staking isn\'t available right now'**
  String get launch_actionScreensLoopStakeCapabilityUnavailableTitle;

  /// lib/features/launch/launch_action_screens.dart:51
  ///
  /// In en, this message translates to:
  /// **'LOOP staking'**
  String get launch_actionScreensLoopStakeScreenTitle;

  /// lib/features/launch/launch_action_screens.dart:116
  ///
  /// In en, this message translates to:
  /// **'Confirm stake'**
  String get launch_actionScreensLoopStakeSubmitLabel;

  /// lib/features/launch/launch_action_screens.dart:123
  ///
  /// In en, this message translates to:
  /// **'Confirm stake, not available right now'**
  String get launch_actionScreensLoopStakeSubmitSemanticLabel;

  /// lib/features/launch/launch_action_screens.dart:617
  ///
  /// In en, this message translates to:
  /// **'Total supply, total distributed and total ecosystem tax have no values yet'**
  String get launch_actionScreensMessage;

  /// lib/features/launch/launch_action_screens.dart:958
  ///
  /// In en, this message translates to:
  /// **'Review result'**
  String get launch_actionScreensProjectRow;

  /// lib/features/launch/launch_action_screens.dart:185
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get launch_actionScreensS;

  /// lib/features/launch/launch_action_screens.dart:944
  ///
  /// In en, this message translates to:
  /// **', selected'**
  String get launch_actionScreensSelectedSuffix;

  /// lib/features/launch/launch_action_screens.dart:259
  ///
  /// In en, this message translates to:
  /// **'LOOP records'**
  String get launch_actionScreensStamp;

  /// lib/features/launch/launch_action_screens.dart:729
  ///
  /// In en, this message translates to:
  /// **'{reviewPipeline} steps'**
  String launch_actionScreensStamp2(Object? reviewPipeline);

  /// lib/features/launch/launch_action_screens.dart:935
  ///
  /// In en, this message translates to:
  /// **'{ticker}, version {materialVersion}, updated {launchTimestampLabel}'**
  String launch_actionScreensSubtitle(
    Object? launchTimestampLabel,
    Object? materialVersion,
    Object? ticker,
  );

  /// lib/features/launch/launch_action_screens.dart:469
  ///
  /// In en, this message translates to:
  /// **'LOOP\'s on-chain event index hasn\'t started yet. The on-chain ledger will show up later.'**
  String get launch_actionScreensSwitch;

  /// lib/features/launch/launch_action_screens.dart:470
  ///
  /// In en, this message translates to:
  /// **'LOOP\'s on-chain event index is still catching up. The on-chain ledger will show up later.'**
  String get launch_actionScreensSwitch2;

  /// lib/features/launch/launch_action_screens.dart:390
  ///
  /// In en, this message translates to:
  /// **'Curated projects complete Launch'**
  String get launch_actionScreensText;

  /// lib/features/launch/launch_action_screens.dart:390
  ///
  /// In en, this message translates to:
  /// **'Community reach and bonding pool trading build liquidity'**
  String get launch_actionScreensText2;

  /// lib/features/launch/launch_action_screens.dart:391
  ///
  /// In en, this message translates to:
  /// **'Hit the line, graduate and move to the DEX pool'**
  String get launch_actionScreensText3;

  /// lib/features/launch/launch_action_screens.dart:391
  ///
  /// In en, this message translates to:
  /// **'After migration, external liquidity carries the trading'**
  String get launch_actionScreensText4;

  /// lib/features/launch/launch_action_screens.dart:392
  ///
  /// In en, this message translates to:
  /// **'Value flows back to LOOP'**
  String get launch_actionScreensText5;

  /// lib/features/launch/launch_action_screens.dart:392
  ///
  /// In en, this message translates to:
  /// **'More liquidity, mining appeal and the next round of distribution'**
  String get launch_actionScreensText6;

  /// lib/features/launch/launch_action_screens.dart:75
  ///
  /// In en, this message translates to:
  /// **'Staked'**
  String get launch_actionScreensTrailingLabel;

  /// lib/features/launch/launch_approval.dart:429
  ///
  /// In en, this message translates to:
  /// **'The approval transaction didn\'t succeed on chain and the allowance didn\'t change. You can start the approval again.'**
  String get launch_approvalFailedOnChain;

  /// lib/features/launch/launch_approval.dart:427
  ///
  /// In en, this message translates to:
  /// **'The approval was submitted, but the allowance hasn\'t updated. It may still be confirming; check again later and don\'t approve again.'**
  String get launch_approvalPollTimedOut;

  /// lib/features/launch/launch_approval.dart:424
  ///
  /// In en, this message translates to:
  /// **'The approval went to the wallet. Waiting for the on-chain allowance to update (checked {attempts} times). You can\'t buy until it lands; don\'t approve again.'**
  String launch_approvalPolling(Object? attempts);

  /// lib/features/launch/launch_approval.dart:420
  ///
  /// In en, this message translates to:
  /// **'Preparing the approval. The wallet hasn\'t opened yet.'**
  String get launch_approvalPreparing;

  /// lib/features/launch/launch_approval.dart:422
  ///
  /// In en, this message translates to:
  /// **'The approval wasn\'t signed and no transaction was submitted. You can start the approval again.'**
  String get launch_approvalSignRefused;

  /// lib/features/launch/launch_signing.dart:452
  ///
  /// In en, this message translates to:
  /// **'it was filled'**
  String get launch_broadcastKindFilled;

  /// lib/features/launch/launch_signing.dart:452
  ///
  /// In en, this message translates to:
  /// **'it landed'**
  String get launch_broadcastKindLanded;

  /// lib/features/launch/launch_chain_models.dart:92
  ///
  /// In en, this message translates to:
  /// **'Running normally'**
  String get launch_chainModelsActive;

  /// lib/features/launch/launch_chain_models.dart:210, lib/features/launch/launch_widgets.dart:632
  ///
  /// In en, this message translates to:
  /// **'Sale in progress'**
  String get launch_chainModelsBody;

  /// lib/features/launch/launch_chain_models.dart:212
  ///
  /// In en, this message translates to:
  /// **'Sale ended, awaiting finalization'**
  String get launch_chainModelsBody2;

  /// lib/features/launch/launch_chain_models.dart:24
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get launch_chainModelsCancelled;

  /// lib/features/launch/launch_chain_models.dart:570, lib/features/launch/launch_settlement_section.dart:338
  ///
  /// In en, this message translates to:
  /// **'Fully claimed'**
  String get launch_chainModelsClaimed;

  /// lib/features/launch/launch_chain_models.dart:644, lib/features/launch/launch_settlement.dart:295, lib/features/launch/launch_settlement_section.dart:332
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get launch_chainModelsClaimed2;

  /// lib/features/launch/launch_chain_models.dart:43
  ///
  /// In en, this message translates to:
  /// **'Vesting schedule fully matured'**
  String get launch_chainModelsCompleted;

  /// lib/features/launch/launch_chain_models.dart:69
  ///
  /// In en, this message translates to:
  /// **'Lock period ended, LP withdrawn'**
  String get launch_chainModelsCompleted2;

  /// lib/features/launch/launch_chain_models.dart:221
  ///
  /// In en, this message translates to:
  /// **'Graduated, LP lock period ended'**
  String get launch_chainModelsCompleted3;

  /// lib/features/launch/launch_chain_models.dart:225
  ///
  /// In en, this message translates to:
  /// **', vesting fully matured'**
  String get launch_chainModelsCompleted4;

  /// lib/features/launch/launch_chain_models.dart:266, lib/features/launch/launch_detail_screens.dart:847, lib/features/launch/launch_settlement_section.dart:341, lib/features/launch/launch_settlement_section.dart:359
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get launch_chainModelsDone;

  /// lib/features/launch/launch_chain_models.dart:21
  ///
  /// In en, this message translates to:
  /// **'All rounds ended, awaiting finalization'**
  String get launch_chainModelsEnded;

  /// lib/features/launch/launch_chain_models.dart:314, lib/features/launch/launch_detail_screens.dart:1313, lib/features/launch/launch_models.dart:626
  ///
  /// In en, this message translates to:
  /// **'Soft cap'**
  String get launch_chainModelsEntries;

  /// lib/features/launch/launch_chain_models.dart:325
  ///
  /// In en, this message translates to:
  /// **'Project token'**
  String get launch_chainModelsEntries10;

  /// lib/features/launch/launch_chain_models.dart:326
  ///
  /// In en, this message translates to:
  /// **'Settlement token USD1'**
  String get launch_chainModelsEntries11;

  /// lib/features/launch/launch_chain_models.dart:315, lib/features/launch/launch_detail_screens.dart:1310, lib/features/launch/launch_models.dart:627
  ///
  /// In en, this message translates to:
  /// **'Hard cap'**
  String get launch_chainModelsEntries2;

  /// lib/features/launch/launch_chain_models.dart:316, lib/features/launch/launch_models.dart:624, lib/features/launch/launch_widgets.dart:1020, lib/features/launch/launch_widgets.dart:1078
  ///
  /// In en, this message translates to:
  /// **'Per-wallet project cap'**
  String get launch_chainModelsEntries3;

  /// lib/features/launch/launch_chain_models.dart:317, lib/features/launch/launch_widgets.dart:1084
  ///
  /// In en, this message translates to:
  /// **'Minimum per purchase'**
  String get launch_chainModelsEntries4;

  /// lib/features/launch/launch_chain_models.dart:318
  ///
  /// In en, this message translates to:
  /// **'Protocol fee'**
  String get launch_chainModelsEntries5;

  /// lib/features/launch/launch_chain_models.dart:319
  ///
  /// In en, this message translates to:
  /// **'To liquidity'**
  String get launch_chainModelsEntries6;

  /// lib/features/launch/launch_chain_models.dart:320
  ///
  /// In en, this message translates to:
  /// **'TGE unlock'**
  String get launch_chainModelsEntries7;

  /// lib/features/launch/launch_chain_models.dart:323
  ///
  /// In en, this message translates to:
  /// **'Pool fee tier'**
  String get launch_chainModelsEntries8;

  /// lib/features/launch/launch_chain_models.dart:324
  ///
  /// In en, this message translates to:
  /// **'LP lock'**
  String get launch_chainModelsEntries9;

  /// lib/features/launch/launch_chain_models.dart:23
  ///
  /// In en, this message translates to:
  /// **'Finalized: soft cap not reached'**
  String get launch_chainModelsFailed;

  /// lib/features/launch/launch_chain_models.dart:41
  ///
  /// In en, this message translates to:
  /// **'Allocation frozen, claims not open yet'**
  String get launch_chainModelsFrozen;

  /// lib/features/launch/launch_chain_models.dart:568, lib/features/launch/launch_chain_models.dart:605
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get launch_chainModelsFrozen2;

  /// lib/features/launch/launch_chain_models.dart:253
  ///
  /// In en, this message translates to:
  /// **'Graduating'**
  String get launch_chainModelsIf;

  /// lib/features/launch/launch_chain_models.dart:174, lib/features/launch/launch_chain_models.dart:199
  ///
  /// In en, this message translates to:
  /// **'Sale status'**
  String get launch_chainModelsLaunchAxisReading;

  /// lib/features/launch/launch_chain_models.dart:176, lib/features/launch/launch_chain_models.dart:199
  ///
  /// In en, this message translates to:
  /// **'Entitlement status'**
  String get launch_chainModelsLaunchAxisReading2;

  /// lib/features/launch/launch_chain_models.dart:180, lib/features/launch/launch_chain_models.dart:199
  ///
  /// In en, this message translates to:
  /// **'Liquidity status'**
  String get launch_chainModelsLaunchAxisReading3;

  /// lib/features/launch/launch_chain_models.dart:182, lib/features/launch/launch_chain_models.dart:199
  ///
  /// In en, this message translates to:
  /// **'Operations status'**
  String get launch_chainModelsLaunchAxisReading4;

  /// lib/features/launch/launch_chain_models.dart:1071
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 day} other{{seconds} days}}'**
  String launch_chainModelsLaunchDurationLabel(num seconds);

  /// lib/features/launch/launch_chain_models.dart:1072
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 hour} other{{seconds} hours}}'**
  String launch_chainModelsLaunchDurationLabel2(num seconds);

  /// lib/features/launch/launch_chain_models.dart:1073
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 minute} other{{seconds} minutes}}'**
  String launch_chainModelsLaunchDurationLabel3(num seconds);

  /// lib/features/launch/launch_chain_models.dart:1074
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String launch_chainModelsLaunchDurationLabel4(num seconds);

  /// lib/features/launch/launch_chain_models.dart:20
  ///
  /// In en, this message translates to:
  /// **'A round is within its window'**
  String get launch_chainModelsLive;

  /// lib/features/launch/launch_chain_models.dart:68
  ///
  /// In en, this message translates to:
  /// **'LP NFT locked'**
  String get launch_chainModelsLpLocked;

  /// lib/features/launch/launch_chain_models.dart:220
  ///
  /// In en, this message translates to:
  /// **'Graduated, LP locked'**
  String get launch_chainModelsLpLocked2;

  /// lib/features/launch/launch_chain_models.dart:40
  ///
  /// In en, this message translates to:
  /// **'Not finalized yet'**
  String get launch_chainModelsNone;

  /// lib/features/launch/launch_chain_models.dart:267
  ///
  /// In en, this message translates to:
  /// **'Not applicable'**
  String get launch_chainModelsNotApplicable;

  /// lib/features/launch/launch_chain_models.dart:65
  ///
  /// In en, this message translates to:
  /// **'Pool creation not started'**
  String get launch_chainModelsNotStarted;

  /// lib/features/launch/launch_chain_models.dart:215, lib/features/launch/launch_widgets.dart:634
  ///
  /// In en, this message translates to:
  /// **'Sale succeeded'**
  String get launch_chainModelsNotStarted2;

  /// lib/features/launch/launch_chain_models.dart:569
  ///
  /// In en, this message translates to:
  /// **'Partially claimed'**
  String get launch_chainModelsPartiallyClaimed;

  /// lib/features/launch/launch_chain_models.dart:606
  ///
  /// In en, this message translates to:
  /// **'Partially refunded'**
  String get launch_chainModelsPartiallyRefunded;

  /// lib/features/launch/launch_chain_models.dart:93
  ///
  /// In en, this message translates to:
  /// **'Paused: buys, claims and refunds are all refused'**
  String get launch_chainModelsPaused;

  /// lib/features/launch/launch_chain_models.dart:263, lib/features/launch/launch_detail_screens.dart:710, lib/features/launch/launch_detail_screens.dart:828, lib/features/launch/launch_detail_screens.dart:844, lib/features/launch/launch_detail_screens.dart:849
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get launch_chainModelsPending;

  /// lib/features/launch/launch_chain_models.dart:66
  ///
  /// In en, this message translates to:
  /// **'Budget frozen, awaiting pool creation'**
  String get launch_chainModelsPreparing;

  /// lib/features/launch/launch_chain_models.dart:216
  ///
  /// In en, this message translates to:
  /// **'Sale succeeded, preparing liquidity'**
  String get launch_chainModelsPreparing2;

  /// lib/features/launch/launch_chain_models.dart:45
  ///
  /// In en, this message translates to:
  /// **'Refund window closed or fully refunded'**
  String get launch_chainModelsRefunded;

  /// lib/features/launch/launch_chain_models.dart:232
  ///
  /// In en, this message translates to:
  /// **'Soft cap not reached, refund window closed'**
  String get launch_chainModelsRefunded2;

  /// lib/features/launch/launch_chain_models.dart:238
  ///
  /// In en, this message translates to:
  /// **'Cancelled, refund window closed'**
  String get launch_chainModelsRefunded3;

  /// lib/features/launch/launch_chain_models.dart:607, lib/features/launch/launch_settlement_section.dart:357
  ///
  /// In en, this message translates to:
  /// **'Fully refunded'**
  String get launch_chainModelsRefunded4;

  /// lib/features/launch/launch_chain_models.dart:645, lib/features/launch/launch_settlement.dart:257, lib/features/launch/launch_settlement.dart:296
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get launch_chainModelsRefunded5;

  /// lib/features/launch/launch_chain_models.dart:44
  ///
  /// In en, this message translates to:
  /// **'Refund liability frozen, refunds open'**
  String get launch_chainModelsRefunding;

  /// lib/features/launch/launch_chain_models.dart:231
  ///
  /// In en, this message translates to:
  /// **'Soft cap not reached, refunds open'**
  String get launch_chainModelsRefunding2;

  /// lib/features/launch/launch_chain_models.dart:237
  ///
  /// In en, this message translates to:
  /// **'Cancelled, refunds open'**
  String get launch_chainModelsRefunding3;

  /// lib/features/launch/launch_chain_models.dart:521
  ///
  /// In en, this message translates to:
  /// **'Reorged'**
  String get launch_chainModelsReorged;

  /// lib/features/launch/launch_chain_models.dart:70
  ///
  /// In en, this message translates to:
  /// **'Pool creation or funding failed, retry scheduled'**
  String get launch_chainModelsRetryScheduled;

  /// lib/features/launch/launch_chain_models.dart:217
  ///
  /// In en, this message translates to:
  /// **'Sale succeeded, pool retry scheduled'**
  String get launch_chainModelsRetryScheduled2;

  /// lib/features/launch/launch_chain_models.dart:265
  ///
  /// In en, this message translates to:
  /// **'Retry scheduled'**
  String get launch_chainModelsRetrying;

  /// lib/features/launch/launch_chain_models.dart:734
  ///
  /// In en, this message translates to:
  /// **'Reverted on chain'**
  String get launch_chainModelsReverted;

  /// lib/features/launch/launch_chain_models.dart:19, lib/features/launch/launch_chain_models.dart:208, lib/features/launch/launch_widgets.dart:631
  ///
  /// In en, this message translates to:
  /// **'Scheduled, not on sale'**
  String get launch_chainModelsScheduled;

  /// lib/features/launch/launch_chain_models.dart:731
  ///
  /// In en, this message translates to:
  /// **'Submitted, awaiting on-chain index'**
  String get launch_chainModelsSubmitted;

  /// lib/features/launch/launch_chain_models.dart:22
  ///
  /// In en, this message translates to:
  /// **'Finalized: soft cap reached'**
  String get launch_chainModelsSucceeded;

  /// lib/features/launch/launch_chain_models.dart:233, lib/features/launch/launch_widgets.dart:635
  ///
  /// In en, this message translates to:
  /// **'Soft cap not reached'**
  String get launch_chainModelsSwitch;

  /// lib/features/launch/launch_chain_models.dart:243
  ///
  /// In en, this message translates to:
  /// **'Paused, {body}'**
  String launch_chainModelsSwitch2(Object? body);

  /// lib/features/launch/launch_chain_models.dart:736
  ///
  /// In en, this message translates to:
  /// **'Result unknown (locked)'**
  String get launch_chainModelsUnknown;

  /// lib/features/launch/launch_chain_models.dart:67
  ///
  /// In en, this message translates to:
  /// **'V3 pool created and liquidity added'**
  String get launch_chainModelsV3Live;

  /// lib/features/launch/launch_chain_models.dart:219
  ///
  /// In en, this message translates to:
  /// **'Sale succeeded, V3 pool live, LP not locked'**
  String get launch_chainModelsV3Live2;

  /// lib/features/launch/launch_chain_models.dart:42
  ///
  /// In en, this message translates to:
  /// **'Claims open, vesting on schedule'**
  String get launch_chainModelsVesting;

  /// lib/features/launch/launch_chain_models.dart:224
  ///
  /// In en, this message translates to:
  /// **', claims open'**
  String get launch_chainModelsVesting2;

  /// lib/features/launch/launch_contract.dart:139
  ///
  /// In en, this message translates to:
  /// **'Activate your LOOP ID first to do this.'**
  String get launch_contractActivationRequired;

  /// lib/features/launch/launch_contract.dart:140
  ///
  /// In en, this message translates to:
  /// **'Account setup isn\'t finished. Try again later.'**
  String get launch_contractBootstrapRequired;

  /// lib/features/launch/launch_contract.dart:131
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled and the result is unknown. Check the latest status before deciding to retry.'**
  String get launch_contractCancelled;

  /// lib/features/launch/launch_contract.dart:142
  ///
  /// In en, this message translates to:
  /// **'The same action was already submitted with different content. Check the latest status and try again.'**
  String get launch_contractIdempotencyConflict;

  /// lib/features/launch/launch_contract.dart:295
  ///
  /// In en, this message translates to:
  /// **'This purchase didn\'t go through and there\'s no description for this reason yet. No transaction was submitted. The server\'s code is under \"Error code\" below.'**
  String get launch_contractIf;

  /// lib/features/launch/launch_contract.dart:143
  ///
  /// In en, this message translates to:
  /// **'The payment wallet\'s balance, allowance or network fee is too low. No transaction was submitted.'**
  String get launch_contractInsufficientBalance;

  /// lib/features/launch/launch_contract.dart:144
  ///
  /// In en, this message translates to:
  /// **'The returned data is incomplete. This page used none of it.'**
  String get launch_contractInvalidData;

  /// lib/features/launch/launch_contract.dart:112
  ///
  /// In en, this message translates to:
  /// **'No value'**
  String get launch_contractLaunchMissingHeading;

  /// lib/features/launch/launch_contract.dart:117
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get launch_contractLaunchMissingName;

  /// lib/features/launch/launch_contract.dart:118
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get launch_contractLaunchMissingResult;

  /// lib/features/launch/launch_contract.dart:136
  ///
  /// In en, this message translates to:
  /// **'The target doesn\'t exist, was removed, or isn\'t visible to this account.'**
  String get launch_contractNotFound;

  /// lib/features/launch/launch_contract.dart:129
  ///
  /// In en, this message translates to:
  /// **'The device is offline. This page loaded no data and submitted nothing.'**
  String get launch_contractOffline;

  /// lib/features/launch/launch_contract.dart:132
  ///
  /// In en, this message translates to:
  /// **'The returned data is incomplete and the result is unconfirmed. Refresh to see the latest status; don\'t submit again.'**
  String get launch_contractOutcomeUnknown;

  /// lib/features/launch/launch_contract.dart:134
  ///
  /// In en, this message translates to:
  /// **'This account doesn\'t have permission for this action.'**
  String get launch_contractPermissionDenied;

  /// lib/features/launch/launch_contract.dart:135
  ///
  /// In en, this message translates to:
  /// **'This action didn\'t pass the server\'s rule check. Nothing was submitted.'**
  String get launch_contractPolicyBlocked;

  /// lib/features/launch/launch_contract.dart:137
  ///
  /// In en, this message translates to:
  /// **'The current status doesn\'t allow this action. Refresh and decide again from the latest status.'**
  String get launch_contractStale;

  /// lib/features/launch/launch_contract.dart:164
  ///
  /// In en, this message translates to:
  /// **'The Launch contract isn\'t live yet. On-chain status, buying, refunds and claims aren\'t available yet.'**
  String get launch_contractSwitch;

  /// lib/features/launch/launch_contract.dart:174
  ///
  /// In en, this message translates to:
  /// **'This launch can\'t be found on the contract. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch10;

  /// lib/features/launch/launch_contract.dart:175
  ///
  /// In en, this message translates to:
  /// **'The on-chain config version doesn\'t match the record. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch11;

  /// lib/features/launch/launch_contract.dart:176
  ///
  /// In en, this message translates to:
  /// **'This launch\'s settlement token isn\'t the configured USD1. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch12;

  /// lib/features/launch/launch_contract.dart:177
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the Launch contract. Refresh later.'**
  String get launch_contractSwitch13;

  /// lib/features/launch/launch_contract.dart:181
  ///
  /// In en, this message translates to:
  /// **'The USD1 allowance isn\'t enough for this purchase. No transaction was submitted. Approve this amount first, then buy once it lands.'**
  String get launch_contractSwitch14;

  /// lib/features/launch/launch_contract.dart:183
  ///
  /// In en, this message translates to:
  /// **'The payment wallet doesn\'t have enough USD1 on the Launch chain. No transaction was submitted. Send enough USD1 to this wallet first, or lower the amount.'**
  String get launch_contractSwitch15;

  /// lib/features/launch/launch_contract.dart:185
  ///
  /// In en, this message translates to:
  /// **'The payment wallet doesn\'t have enough native coin on the Launch chain for the network fee. No transaction was submitted. Send a small amount of fee coin to this wallet and try again.'**
  String get launch_contractSwitch16;

  /// lib/features/launch/launch_contract.dart:186
  ///
  /// In en, this message translates to:
  /// **'The Launch contract returned a value that can\'t be decoded. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch17;

  /// lib/features/launch/launch_contract.dart:187
  ///
  /// In en, this message translates to:
  /// **'A block reorg happened during the read. Refresh later.'**
  String get launch_contractSwitch18;

  /// lib/features/launch/launch_contract.dart:188
  ///
  /// In en, this message translates to:
  /// **'The list doesn\'t read the chain per item. Open the details to see on-chain status.'**
  String get launch_contractSwitch19;

  /// lib/features/launch/launch_contract.dart:166
  ///
  /// In en, this message translates to:
  /// **'The Launch contract is finishing on-chain checks. Refresh later.'**
  String get launch_contractSwitch2;

  /// lib/features/launch/launch_contract.dart:189
  ///
  /// In en, this message translates to:
  /// **'This item has no confirmed configuration yet. Value pending.'**
  String get launch_contractSwitch20;

  /// lib/features/launch/launch_contract.dart:190
  ///
  /// In en, this message translates to:
  /// **'Liquidity pool info can\'t be loaded yet. Graduation steps stay pending.'**
  String get launch_contractSwitch21;

  /// lib/features/launch/launch_contract.dart:191
  ///
  /// In en, this message translates to:
  /// **'Total supply, issuance and ecosystem tax wait for the contract. Only amounts LOOP can verify are shown here.'**
  String get launch_contractSwitch22;

  /// lib/features/launch/launch_contract.dart:192
  ///
  /// In en, this message translates to:
  /// **'Launch isn\'t available right now. Try again later.'**
  String get launch_contractSwitch23;

  /// lib/features/launch/launch_contract.dart:194
  ///
  /// In en, this message translates to:
  /// **'You can only link a community you own. This community doesn\'t exist, was rejected, or you\'re no longer its owner. The details weren\'t saved.'**
  String get launch_contractSwitch24;

  /// lib/features/launch/launch_contract.dart:195
  ///
  /// In en, this message translates to:
  /// **'The eligibility rules for this launch aren\'t configured yet. Eligibility doesn\'t depend on staking.'**
  String get launch_contractSwitch25;

  /// lib/features/launch/launch_contract.dart:196
  ///
  /// In en, this message translates to:
  /// **'Staking isn\'t open yet. This page can\'t be used right now.'**
  String get launch_contractSwitch26;

  /// lib/features/launch/launch_contract.dart:197
  ///
  /// In en, this message translates to:
  /// **'Review status will show here once it opens.'**
  String get launch_contractSwitch27;

  /// lib/features/launch/launch_contract.dart:198
  ///
  /// In en, this message translates to:
  /// **'Attachments can\'t be uploaded right now.'**
  String get launch_contractSwitch28;

  /// lib/features/launch/launch_contract.dart:200
  ///
  /// In en, this message translates to:
  /// **'The mining formula isn\'t approved yet. Power, output, rankings and invite boost aren\'t available yet.'**
  String get launch_contractSwitch29;

  /// lib/features/launch/launch_contract.dart:167
  ///
  /// In en, this message translates to:
  /// **'There\'s no code at the configured Launch contract address. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch3;

  /// lib/features/launch/launch_contract.dart:205
  ///
  /// In en, this message translates to:
  /// **'The active formula version hasn\'t approved an invite boost. This item has no value yet.'**
  String get launch_contractSwitch30;

  /// lib/features/launch/launch_contract.dart:206
  ///
  /// In en, this message translates to:
  /// **'No power snapshot yet.'**
  String get launch_contractSwitch31;

  /// lib/features/launch/launch_contract.dart:207
  ///
  /// In en, this message translates to:
  /// **'The latest power snapshot used an old formula version. Check again after the next snapshot.'**
  String get launch_contractSwitch32;

  /// lib/features/launch/launch_contract.dart:263
  ///
  /// In en, this message translates to:
  /// **'The graduated list can\'t be loaded right now'**
  String get launch_contractSwitch33;

  /// lib/features/launch/launch_contract.dart:264
  ///
  /// In en, this message translates to:
  /// **'The on-chain index has no progress yet. The graduated list can\'t be loaded right now.'**
  String get launch_contractSwitch34;

  /// lib/features/launch/launch_contract.dart:280
  ///
  /// In en, this message translates to:
  /// **'Total supply, issuance and ecosystem tax aren\'t open yet. Only amounts LOOP can verify are shown here.'**
  String get launch_contractSwitch35;

  /// lib/features/launch/launch_contract.dart:168
  ///
  /// In en, this message translates to:
  /// **'This Launch contract version isn\'t supported. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch4;

  /// lib/features/launch/launch_contract.dart:169
  ///
  /// In en, this message translates to:
  /// **'The Launch chain has no available node yet. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch5;

  /// lib/features/launch/launch_contract.dart:170
  ///
  /// In en, this message translates to:
  /// **'The Launch node returned a different chain than configured. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch6;

  /// lib/features/launch/launch_contract.dart:171
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the Launch chain node right now. Refresh later.'**
  String get launch_contractSwitch7;

  /// lib/features/launch/launch_contract.dart:172
  ///
  /// In en, this message translates to:
  /// **'This launch isn\'t registered on chain yet. Waiting for it to go on chain.'**
  String get launch_contractSwitch8;

  /// lib/features/launch/launch_contract.dart:173
  ///
  /// In en, this message translates to:
  /// **'The contract registered for this launch doesn\'t match the current configuration. On-chain status isn\'t available right now.'**
  String get launch_contractSwitch9;

  /// lib/features/launch/launch_contract.dart:211
  ///
  /// In en, this message translates to:
  /// **'An asset in the latest calculation had no reference price, so it wasn\'t published. There\'s no complete snapshot to fall back on yet.'**
  String get launch_contractText;

  /// lib/features/launch/launch_contract.dart:220
  ///
  /// In en, this message translates to:
  /// **'This user made their mining power visible only to themselves.'**
  String get launch_contractText10;

  /// lib/features/launch/launch_contract.dart:221
  ///
  /// In en, this message translates to:
  /// **'The reference price isn\'t fresh enough, so this asset wasn\'t counted.'**
  String get launch_contractText11;

  /// lib/features/launch/launch_contract.dart:222
  ///
  /// In en, this message translates to:
  /// **'This asset\'s reference price comes from an unregistered token, so it wasn\'t counted.'**
  String get launch_contractText12;

  /// lib/features/launch/launch_contract.dart:223
  ///
  /// In en, this message translates to:
  /// **'The current formula version gives this asset no weight.'**
  String get launch_contractText13;

  /// lib/features/launch/launch_contract.dart:224
  ///
  /// In en, this message translates to:
  /// **'This community hasn\'t linked a token yet.'**
  String get launch_contractText14;

  /// lib/features/launch/launch_contract.dart:225
  ///
  /// In en, this message translates to:
  /// **'Two communities linked this asset, so it wasn\'t counted.'**
  String get launch_contractText15;

  /// lib/features/launch/launch_contract.dart:226
  ///
  /// In en, this message translates to:
  /// **'Mining isn\'t available right now. Try again later.'**
  String get launch_contractText16;

  /// lib/features/launch/launch_contract.dart:227
  ///
  /// In en, this message translates to:
  /// **'Reward payouts aren\'t on yet. Claims aren\'t available.'**
  String get launch_contractText17;

  /// lib/features/launch/launch_contract.dart:228
  ///
  /// In en, this message translates to:
  /// **'This community\'s mining weight is still in review.'**
  String get launch_contractText18;

  /// lib/features/launch/launch_contract.dart:230
  ///
  /// In en, this message translates to:
  /// **'Invitations aren\'t available right now. Try again later.'**
  String get launch_contractText19;

  /// lib/features/launch/launch_contract.dart:212
  ///
  /// In en, this message translates to:
  /// **'This wallet isn\'t in any complete power snapshot yet. It will show after the next snapshot.'**
  String get launch_contractText2;

  /// lib/features/launch/launch_contract.dart:231
  ///
  /// In en, this message translates to:
  /// **'Activate your LOOP ID before binding an invite code.'**
  String get launch_contractText20;

  /// lib/features/launch/launch_contract.dart:213
  ///
  /// In en, this message translates to:
  /// **'This asset has no usable quote right now and wasn\'t counted.'**
  String get launch_contractText3;

  /// lib/features/launch/launch_contract.dart:214
  ///
  /// In en, this message translates to:
  /// **'That power snapshot was incomplete and has been voided.'**
  String get launch_contractText4;

  /// lib/features/launch/launch_contract.dart:215
  ///
  /// In en, this message translates to:
  /// **'The latest power snapshot has no wallet balance for this account.'**
  String get launch_contractText5;

  /// lib/features/launch/launch_contract.dart:216
  ///
  /// In en, this message translates to:
  /// **'Network power is 0, so shares can\'t be calculated yet.'**
  String get launch_contractText6;

  /// lib/features/launch/launch_contract.dart:217
  ///
  /// In en, this message translates to:
  /// **'The current formula version has no daily output configured.'**
  String get launch_contractText7;

  /// lib/features/launch/launch_contract.dart:218
  ///
  /// In en, this message translates to:
  /// **'Power is 0, so there\'s no rank yet.'**
  String get launch_contractText8;

  /// lib/features/launch/launch_contract.dart:219
  ///
  /// In en, this message translates to:
  /// **'The community board doesn\'t show personal ranks.'**
  String get launch_contractText9;

  /// lib/features/launch/launch_contract.dart:130
  ///
  /// In en, this message translates to:
  /// **'LOOP timed out. This page loaded no data and submitted nothing.'**
  String get launch_contractTimedOut;

  /// lib/features/launch/launch_contract.dart:133
  ///
  /// In en, this message translates to:
  /// **'This feature isn\'t available right now. Try again later.'**
  String get launch_contractUnavailable;

  /// lib/features/launch/launch_contract.dart:145
  ///
  /// In en, this message translates to:
  /// **'The action didn\'t finish. Try again later.'**
  String get launch_contractUnexpected;

  /// lib/features/launch/launch_contract.dart:141
  ///
  /// In en, this message translates to:
  /// **'The input doesn\'t meet the requirements. Edit it and try again.'**
  String get launch_contractValidationFailed;

  /// lib/features/launch/launch_contract.dart:138
  ///
  /// In en, this message translates to:
  /// **'The details were changed on another device. Reload before submitting; nothing was overwritten.'**
  String get launch_contractVersionConflict;

  /// lib/features/launch/launch_contract.dart:268
  ///
  /// In en, this message translates to:
  /// **'The graduated list isn\'t open yet'**
  String get launch_contractWhenLive;

  /// lib/features/launch/launch_controllers.dart:215, lib/features/launch/launch_models.dart:1220
  ///
  /// In en, this message translates to:
  /// **'Awaiting schedule'**
  String get launch_controllersAwaitingSchedule;

  /// lib/features/launch/launch_controllers.dart:213, lib/features/launch/launch_models.dart:1222, lib/features/launch/launch_widgets.dart:476
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get launch_controllersLive;

  /// lib/features/launch/launch_controllers.dart:214
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get launch_controllersUpcoming;

  /// lib/features/launch/launch_detail_screens.dart:540
  ///
  /// In en, this message translates to:
  /// **'Axes, rounds and contract parameters are read at block {block}, state digest {digest}. '**
  String launch_detailScreensBaselineOnChain(Object? block, Object? digest);

  /// lib/features/launch/launch_detail_screens.dart:938, lib/features/launch/launch_widgets.dart:658
  ///
  /// In en, this message translates to:
  /// **'Allowlist round'**
  String get launch_detailScreensBuild;

  /// lib/features/launch/launch_detail_screens.dart:983
  ///
  /// In en, this message translates to:
  /// **'Raised'**
  String get launch_detailScreensBuild2;

  /// lib/features/launch/launch_detail_screens.dart:1281
  ///
  /// In en, this message translates to:
  /// **'Rounds, windows, prices and caps are read from the contract at block {groupedFigure}.'**
  String launch_detailScreensCaption(Object? groupedFigure);

  /// lib/features/launch/launch_detail_screens.dart:2092
  ///
  /// In en, this message translates to:
  /// **'Records come from the on-chain index, indexed to block {groupedFigure}. P&L isn\'t shown.'**
  String launch_detailScreensCaption10(Object? groupedFigure);

  /// lib/features/launch/launch_detail_screens.dart:1283
  ///
  /// In en, this message translates to:
  /// **'Rounds, times, prices, eligibility and caps are set by this launch\'s config. Anything unconfirmed shows as pending.'**
  String get launch_detailScreensCaption2;

  /// lib/features/launch/launch_detail_screens.dart:1526
  ///
  /// In en, this message translates to:
  /// **'Graduation progress follows liquidity. There\'s no verifiable progress before the contract is live.'**
  String get launch_detailScreensCaption3;

  /// lib/features/launch/launch_detail_screens.dart:1527
  ///
  /// In en, this message translates to:
  /// **'{launchStateProjection}. Steps are derived only from the liquidity and entitlement axes.'**
  String launch_detailScreensCaption4(Object? launchStateProjection);

  /// lib/features/launch/launch_detail_screens.dart:1696
  ///
  /// In en, this message translates to:
  /// **'This round is public. Any wallet can take part.'**
  String get launch_detailScreensCaption5;

  /// lib/features/launch/launch_detail_screens.dart:1697
  ///
  /// In en, this message translates to:
  /// **'This is the current eligibility result, not a tier. Conditions and snapshot time are shown together.'**
  String get launch_detailScreensCaption6;

  /// lib/features/launch/launch_detail_screens.dart:1922
  ///
  /// In en, this message translates to:
  /// **'Participant count, concentration, my position and the per-address cap all need contract readings, and none are available right now.'**
  String get launch_detailScreensCaption7;

  /// lib/features/launch/launch_detail_screens.dart:1923
  ///
  /// In en, this message translates to:
  /// **'Participants are distinct addresses that bought in the bonding pool, not current holders. From the on-chain index, indexed to block {groupedFigure}.'**
  String launch_detailScreensCaption8(Object? groupedFigure);

  /// lib/features/launch/launch_detail_screens.dart:2091
  ///
  /// In en, this message translates to:
  /// **'Purchase, entitlement and refund records need on-chain data, which can\'t be loaded right now, so no counts or P&L are shown.'**
  String get launch_detailScreensCaption9;

  /// lib/features/launch/launch_detail_screens.dart:2293
  ///
  /// In en, this message translates to:
  /// **'Claim {amount}'**
  String launch_detailScreensClaimAmount(Object? amount);

  /// lib/features/launch/launch_detail_screens.dart:857
  ///
  /// In en, this message translates to:
  /// **'The vesting schedule has fully matured. Anything unclaimed can still be claimed in \"My allocation\".'**
  String get launch_detailScreensCompleted;

  /// lib/features/launch/launch_detail_screens.dart:379
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this project'**
  String get launch_detailScreensEmptyMessage;

  /// lib/features/launch/launch_detail_screens.dart:1344
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load round config'**
  String get launch_detailScreensEmptyMessage2;

  /// lib/features/launch/launch_detail_screens.dart:1570
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load graduation records'**
  String get launch_detailScreensEmptyMessage3;

  /// lib/features/launch/launch_detail_screens.dart:1737
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the eligibility result'**
  String get launch_detailScreensEmptyMessage4;

  /// lib/features/launch/launch_detail_screens.dart:1966
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load holder records'**
  String get launch_detailScreensEmptyMessage5;

  /// lib/features/launch/launch_detail_screens.dart:2129
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load participation records'**
  String get launch_detailScreensEmptyMessage6;

  /// lib/features/launch/launch_detail_screens.dart:380, lib/features/launch/launch_detail_screens.dart:1345, lib/features/launch/launch_detail_screens.dart:1571, lib/features/launch/launch_detail_screens.dart:1738, lib/features/launch/launch_detail_screens.dart:1967, lib/features/launch/launch_detail_screens.dart:2130
  ///
  /// In en, this message translates to:
  /// **'The project may not exist, or isn\'t visible to this account.'**
  String get launch_detailScreensEmptyReason;

  /// lib/features/launch/launch_detail_screens.dart:961
  ///
  /// In en, this message translates to:
  /// **'Start UTC'**
  String get launch_detailScreensEntries;

  /// lib/features/launch/launch_detail_screens.dart:962
  ///
  /// In en, this message translates to:
  /// **'End UTC'**
  String get launch_detailScreensEntries2;

  /// lib/features/launch/launch_detail_screens.dart:971
  ///
  /// In en, this message translates to:
  /// **'Price USD1'**
  String get launch_detailScreensEntries3;

  /// lib/features/launch/launch_detail_screens.dart:972
  ///
  /// In en, this message translates to:
  /// **'Round cap USD1'**
  String get launch_detailScreensEntries4;

  /// lib/features/launch/launch_detail_screens.dart:1278
  ///
  /// In en, this message translates to:
  /// **'{chainRounds, plural, =1{1 round} other{{chainRounds} rounds}}'**
  String launch_detailScreensHeading(num chainRounds);

  /// lib/features/launch/launch_detail_screens.dart:1279
  ///
  /// In en, this message translates to:
  /// **'{rounds, plural, =1{1 round} other{{rounds} rounds}}'**
  String launch_detailScreensHeading2(num rounds);

  /// lib/features/launch/launch_detail_screens.dart:1524
  ///
  /// In en, this message translates to:
  /// **'{done} / 4 steps'**
  String launch_detailScreensHeading3(Object? done);

  /// lib/features/launch/launch_detail_screens.dart:1693
  ///
  /// In en, this message translates to:
  /// **'Not on the list'**
  String get launch_detailScreensHeading4;

  /// lib/features/launch/launch_detail_screens.dart:37
  ///
  /// In en, this message translates to:
  /// **'Loading participants'**
  String get launch_detailScreensIf;

  /// lib/features/launch/launch_detail_screens.dart:132
  ///
  /// In en, this message translates to:
  /// **'No records (indexed to block {block})'**
  String launch_detailScreensIf10(Object? block);

  /// lib/features/launch/launch_detail_screens.dart:133
  ///
  /// In en, this message translates to:
  /// **'No purchases; entitlement or refund records exist (indexed to block {block})'**
  String launch_detailScreensIf11(Object? block);

  /// lib/features/launch/launch_detail_screens.dart:608, lib/features/launch/launch_trade_screen.dart:1288
  ///
  /// In en, this message translates to:
  /// **'Round ends'**
  String get launch_detailScreensIf12;

  /// lib/features/launch/launch_detail_screens.dart:610
  ///
  /// In en, this message translates to:
  /// **'Round {index} left'**
  String launch_detailScreensIf13(Object? index);

  /// lib/features/launch/launch_detail_screens.dart:649
  ///
  /// In en, this message translates to:
  /// **'Market cap {launchMissingFigure} / graduation line {launchMissingFigure2}'**
  String launch_detailScreensIf14(
    Object? launchMissingFigure,
    Object? launchMissingFigure2,
  );

  /// lib/features/launch/launch_detail_screens.dart:2314
  ///
  /// In en, this message translates to:
  /// **'Total claimed {launchUnitsFigure}'**
  String launch_detailScreensIf15(Object? launchUnitsFigure);

  /// lib/features/launch/launch_detail_screens.dart:72
  ///
  /// In en, this message translates to:
  /// **'Project details and round config come from LOOP. On-chain status, price and graduation progress can\'t be loaded right now.'**
  String get launch_detailScreensIf2;

  /// lib/features/launch/launch_detail_screens.dart:74
  ///
  /// In en, this message translates to:
  /// **'{launchStateProjection}. Axes, rounds and parameters read at block {groupedFigure}.'**
  String launch_detailScreensIf3(
    Object? groupedFigure,
    Object? launchStateProjection,
  );

  /// lib/features/launch/launch_detail_screens.dart:87
  ///
  /// In en, this message translates to:
  /// **'Eligibility {launchPendingConfirmationLabel}, set by this launch\'s eligibility mode'**
  String launch_detailScreensIf4(Object? launchPendingConfirmationLabel);

  /// lib/features/launch/launch_detail_screens.dart:89
  ///
  /// In en, this message translates to:
  /// **'Public round, no eligibility required'**
  String get launch_detailScreensIf5;

  /// lib/features/launch/launch_detail_screens.dart:125, lib/features/launch/launch_detail_screens.dart:2089
  ///
  /// In en, this message translates to:
  /// **'{purchases, plural, =1{1 purchase} other{{purchases} purchases}}'**
  String launch_detailScreensIf6(num purchases);

  /// lib/features/launch/launch_detail_screens.dart:126
  ///
  /// In en, this message translates to:
  /// **'{claimed, plural, =1{1 claim} other{{claimed} claims}}'**
  String launch_detailScreensIf7(num claimed);

  /// lib/features/launch/launch_detail_screens.dart:127
  ///
  /// In en, this message translates to:
  /// **'{refunded, plural, =1{1 refund} other{{refunded} refunds}}'**
  String launch_detailScreensIf8(num refunded);

  /// lib/features/launch/launch_detail_screens.dart:129
  ///
  /// In en, this message translates to:
  /// **'{parts}, latest {launchTimestampLabel}'**
  String launch_detailScreensIf9(Object? launchTimestampLabel, Object? parts);

  /// lib/features/launch/launch_detail_screens.dart:335
  ///
  /// In en, this message translates to:
  /// **'Launch record'**
  String get launch_detailScreensKicker;

  /// lib/features/launch/launch_detail_screens.dart:1272
  ///
  /// In en, this message translates to:
  /// **'Round config'**
  String get launch_detailScreensKicker2;

  /// lib/features/launch/launch_detail_screens.dart:1519
  ///
  /// In en, this message translates to:
  /// **'Graduation progress'**
  String get launch_detailScreensKicker3;

  /// lib/features/launch/launch_detail_screens.dart:1683
  ///
  /// In en, this message translates to:
  /// **'Eligibility'**
  String get launch_detailScreensKicker4;

  /// lib/features/launch/launch_detail_screens.dart:1915
  ///
  /// In en, this message translates to:
  /// **'Holder distribution'**
  String get launch_detailScreensKicker5;

  /// lib/features/launch/launch_detail_screens.dart:2086
  ///
  /// In en, this message translates to:
  /// **'Participation'**
  String get launch_detailScreensKicker6;

  /// lib/features/launch/launch_detail_screens.dart:527, lib/features/launch/launch_detail_screens.dart:1442
  ///
  /// In en, this message translates to:
  /// **'Confirmed config version'**
  String get launch_detailScreensLabel;

  /// lib/features/launch/launch_detail_screens.dart:1610
  ///
  /// In en, this message translates to:
  /// **'Pool address and lock info'**
  String get launch_detailScreensLabel2;

  /// lib/features/launch/launch_detail_screens.dart:1934
  ///
  /// In en, this message translates to:
  /// **'Top 10 total'**
  String get launch_detailScreensLabel3;

  /// lib/features/launch/launch_detail_screens.dart:2033
  ///
  /// In en, this message translates to:
  /// **'Holder distribution'**
  String get launch_detailScreensLabel4;

  /// lib/features/launch/launch_detail_screens.dart:2100
  ///
  /// In en, this message translates to:
  /// **'Participations'**
  String get launch_detailScreensLabel5;

  /// lib/features/launch/launch_detail_screens.dart:2137
  ///
  /// In en, this message translates to:
  /// **'Purchase, entitlement and refund records'**
  String get launch_detailScreensLabel6;

  /// lib/features/launch/launch_detail_screens.dart:2322
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get launch_detailScreensLabel7;

  /// lib/features/launch/launch_detail_screens.dart:2322
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get launch_detailScreensLabel8;

  /// lib/features/launch/launch_detail_screens.dart:895
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get launch_detailScreensLaunchChainRoundPhaseLabel;

  /// lib/features/launch/launch_detail_screens.dart:540
  ///
  /// In en, this message translates to:
  /// **'{onChain}Details version {materialVersion}, registered {launchTimestampLabel}.'**
  String launch_detailScreensLaunchDetailBaselineNoticeBody(
    Object? launchTimestampLabel,
    Object? materialVersion,
    Object? onChain,
  );

  /// lib/features/launch/launch_detail_screens.dart:538
  ///
  /// In en, this message translates to:
  /// **'Unproven figures aren\'t shown'**
  String get launch_detailScreensLaunchDetailBaselineNoticeTitle;

  /// lib/features/launch/launch_detail_screens.dart:538
  ///
  /// In en, this message translates to:
  /// **'On-chain readings come from one block'**
  String get launch_detailScreensLaunchDetailBaselineNoticeTitle2;

  /// lib/features/launch/launch_detail_screens.dart:368
  ///
  /// In en, this message translates to:
  /// **'Project details aren\'t available right now'**
  String get launch_detailScreensLaunchDetailCapabilityUnavailableTitle;

  /// lib/features/launch/launch_detail_screens.dart:70
  ///
  /// In en, this message translates to:
  /// **'Loading project details and on-chain status'**
  String get launch_detailScreensLaunchDetailCaption;

  /// lib/features/launch/launch_detail_screens.dart:477
  ///
  /// In en, this message translates to:
  /// **'On-chain axes and config'**
  String get launch_detailScreensLaunchDetailFactsSummary;

  /// lib/features/launch/launch_detail_screens.dart:58
  ///
  /// In en, this message translates to:
  /// **'Loading project details'**
  String get launch_detailScreensLaunchDetailHeading;

  /// lib/features/launch/launch_detail_screens.dart:503
  ///
  /// In en, this message translates to:
  /// **'Rounds, caps and fees have values only after a config version is confirmed.'**
  String get launch_detailScreensLaunchDetailNoConfigMessage;

  /// lib/features/launch/launch_detail_screens.dart:502, lib/features/launch/launch_detail_screens.dart:1393
  ///
  /// In en, this message translates to:
  /// **'No config version yet'**
  String get launch_detailScreensLaunchDetailNoConfigTitle;

  /// lib/features/launch/launch_detail_screens.dart:449, lib/features/launch/launch_detail_screens.dart:2080
  ///
  /// In en, this message translates to:
  /// **'My participation'**
  String get launch_detailScreensLaunchDetailOpenHistoryTitle;

  /// lib/features/launch/launch_detail_screens.dart:437, lib/features/launch/launch_detail_screens.dart:1909
  ///
  /// In en, this message translates to:
  /// **'Bonding pool holders'**
  String get launch_detailScreensLaunchDetailOpenHoldersTitle;

  /// lib/features/launch/launch_detail_screens.dart:315
  ///
  /// In en, this message translates to:
  /// **'Round rules'**
  String get launch_detailScreensLaunchDetailRoundsActionLabel;

  /// lib/features/launch/launch_detail_screens.dart:308
  ///
  /// In en, this message translates to:
  /// **'Project details'**
  String get launch_detailScreensLaunchDetailScreenTitle;

  /// lib/features/launch/launch_detail_screens.dart:1542
  ///
  /// In en, this message translates to:
  /// **'{done} of {steps} steps done'**
  String launch_detailScreensLaunchGraduationBarSemanticLabel(
    Object? done,
    Object? steps,
  );

  /// lib/features/launch/launch_detail_screens.dart:1559
  ///
  /// In en, this message translates to:
  /// **'Graduation progress isn\'t available right now'**
  String get launch_detailScreensLaunchGraduationCapabilityUnavailableTitle;

  /// lib/features/launch/launch_detail_screens.dart:1619
  ///
  /// In en, this message translates to:
  /// **'\"Ended\" only means the schedule ended, not that it graduated. Graduation depends on liquidity and the trading pool, and neither can be loaded right now. Migration is advanced by the server\'s authoritative status, one step at a time.'**
  String get launch_detailScreensLaunchGraduationNoticeBody;

  /// lib/features/launch/launch_detail_screens.dart:1622
  ///
  /// In en, this message translates to:
  /// **'\"Ended\" only means the schedule ended, not that it graduated. A live V3 pool doesn\'t mean the LP is locked; only LP_LOCKED or COMPLETED counts as graduated. Each step finishes before the next.'**
  String get launch_detailScreensLaunchGraduationNoticeBody2;

  /// lib/features/launch/launch_detail_screens.dart:1617
  ///
  /// In en, this message translates to:
  /// **'Graduation isn\'t a schedule status'**
  String get launch_detailScreensLaunchGraduationNoticeTitle;

  /// lib/features/launch/launch_detail_screens.dart:2119
  ///
  /// In en, this message translates to:
  /// **'Participation records aren\'t available right now'**
  String get launch_detailScreensLaunchHistoryCapabilityUnavailableTitle;

  /// lib/features/launch/launch_detail_screens.dart:2218
  ///
  /// In en, this message translates to:
  /// **'Claimed {launchUnitsFigure}'**
  String launch_detailScreensLaunchHistoryEntitlementSubtitle(
    Object? launchUnitsFigure,
  );

  /// lib/features/launch/launch_detail_screens.dart:2216
  ///
  /// In en, this message translates to:
  /// **'Entitlement {launchUnitsFigure}'**
  String launch_detailScreensLaunchHistoryEntitlementTitle(
    Object? launchUnitsFigure,
  );

  /// lib/features/launch/launch_detail_screens.dart:2148
  ///
  /// In en, this message translates to:
  /// **'Indexed to block {groupedFigure}, with no purchases, entitlements or refunds for this wallet.'**
  String launch_detailScreensLaunchHistoryIndexedEmptyMessage(
    Object? groupedFigure,
  );

  /// lib/features/launch/launch_detail_screens.dart:2146
  ///
  /// In en, this message translates to:
  /// **'This wallet has no records in this launch'**
  String get launch_detailScreensLaunchHistoryIndexedEmptyTitle;

  /// lib/features/launch/launch_detail_screens.dart:2246
  ///
  /// In en, this message translates to:
  /// **'Refunded {launchUsd1Label}'**
  String launch_detailScreensLaunchHistoryRefundSubtitle(
    Object? launchUsd1Label,
  );

  /// lib/features/launch/launch_detail_screens.dart:2244, lib/features/launch/launch_settlement_section.dart:347
  ///
  /// In en, this message translates to:
  /// **'Refundable {launchUsd1Label}'**
  String launch_detailScreensLaunchHistoryRefundTitle(Object? launchUsd1Label);

  /// lib/features/launch/launch_detail_screens.dart:1956
  ///
  /// In en, this message translates to:
  /// **'Holder distribution isn\'t available right now'**
  String get launch_detailScreensLaunchHoldersCapabilityUnavailableTitle;

  /// lib/features/launch/launch_detail_screens.dart:1986
  ///
  /// In en, this message translates to:
  /// **'My position, {launchReasonCodeText}'**
  String launch_detailScreensLaunchHoldersMeSemanticLabel(
    Object? launchReasonCodeText,
  );

  /// lib/features/launch/launch_detail_screens.dart:2004
  ///
  /// In en, this message translates to:
  /// **'My position, snapshot block {snapshotBlockNumber}'**
  String launch_detailScreensLaunchHoldersMeSemanticLabel2(
    Object? snapshotBlockNumber,
  );

  /// lib/features/launch/launch_detail_screens.dart:1983
  ///
  /// In en, this message translates to:
  /// **'Holding {launchMissingFigure}, can still buy {launchMissingFigure2}'**
  String launch_detailScreensLaunchHoldersMeSubtitle(
    Object? launchMissingFigure,
    Object? launchMissingFigure2,
  );

  /// lib/features/launch/launch_detail_screens.dart:1996
  ///
  /// In en, this message translates to:
  /// **'Bought {launchUnitsFigure}, paid {launchUsd1Label} in total\nClaimable {launchUnitsFigure2}, claimed {launchUnitsFigure3}, refundable {launchUsd1Label2}'**
  String launch_detailScreensLaunchHoldersMeSubtitle2(
    Object? launchUnitsFigure,
    Object? launchUnitsFigure2,
    Object? launchUnitsFigure3,
    Object? launchUsd1Label,
    Object? launchUsd1Label2,
  );

  /// lib/features/launch/launch_detail_screens.dart:1982, lib/features/launch/launch_detail_screens.dart:1994
  ///
  /// In en, this message translates to:
  /// **'My position'**
  String get launch_detailScreensLaunchHoldersMeTitle;

  /// lib/features/launch/launch_detail_screens.dart:2003
  ///
  /// In en, this message translates to:
  /// **'Frozen entitlement'**
  String get launch_detailScreensLaunchHoldersMeTrailingCaption;

  /// lib/features/launch/launch_detail_screens.dart:1323
  ///
  /// In en, this message translates to:
  /// **'Round rules aren\'t available right now'**
  String get launch_detailScreensLaunchRoundsCapabilityUnavailableTitle;

  /// lib/features/launch/launch_detail_screens.dart:1368, lib/features/launch/launch_detail_screens.dart:1404
  ///
  /// In en, this message translates to:
  /// **'Other contract parameters'**
  String get launch_detailScreensLaunchRoundsFactsSummary;

  /// lib/features/launch/launch_detail_screens.dart:1394
  ///
  /// In en, this message translates to:
  /// **'Caps and fees have values only after a config version is confirmed.'**
  String get launch_detailScreensLaunchRoundsNoConfigMessage;

  /// lib/features/launch/launch_detail_screens.dart:1334
  ///
  /// In en, this message translates to:
  /// **'Round config belongs to a specific launch, not a site-wide rule. Go back to the Launch directory, open a project, then view its round config.'**
  String get launch_detailScreensLaunchRoundsNoSubjectMessage;

  /// lib/features/launch/launch_detail_screens.dart:1332
  ///
  /// In en, this message translates to:
  /// **'No launch selected'**
  String get launch_detailScreensLaunchRoundsNoSubjectTitle;

  /// lib/features/launch/launch_detail_screens.dart:1451
  ///
  /// In en, this message translates to:
  /// **'This page writes no fixed round count, fee rate, holding cap or graduation market cap. {launchReasonCodeText}'**
  String launch_detailScreensLaunchRoundsNoticeBody(
    Object? launchReasonCodeText,
  );

  /// lib/features/launch/launch_detail_screens.dart:1453
  ///
  /// In en, this message translates to:
  /// **'The figures on this page are the contract\'s readings at the snapshot block, not rules LOOP wrote. When buying, the reading re-checked before signing applies.'**
  String get launch_detailScreensLaunchRoundsNoticeBody2;

  /// lib/features/launch/launch_detail_screens.dart:1449
  ///
  /// In en, this message translates to:
  /// **'The final confirmed rules apply'**
  String get launch_detailScreensLaunchRoundsNoticeTitle;

  /// lib/features/launch/launch_detail_screens.dart:1449
  ///
  /// In en, this message translates to:
  /// **'The contract reading before signing applies'**
  String get launch_detailScreensLaunchRoundsNoticeTitle2;

  /// lib/features/launch/launch_detail_screens.dart:1266
  ///
  /// In en, this message translates to:
  /// **'Sale round rules'**
  String get launch_detailScreensLaunchRoundsScreenTitle;

  /// lib/features/launch/launch_detail_screens.dart:1726
  ///
  /// In en, this message translates to:
  /// **'Eligibility check isn\'t available right now'**
  String get launch_detailScreensLaunchTierCapabilityUnavailableTitle;

  /// lib/features/launch/launch_detail_screens.dart:1710, lib/features/launch/launch_detail_screens.dart:1803, lib/features/launch/launch_models.dart:630
  ///
  /// In en, this message translates to:
  /// **'Eligibility mode'**
  String get launch_detailScreensLaunchTierConditionsLabel;

  /// lib/features/launch/launch_detail_screens.dart:1829
  ///
  /// In en, this message translates to:
  /// **'Not in effect yet'**
  String get launch_detailScreensLaunchTierConfigVersionSubtitle;

  /// lib/features/launch/launch_detail_screens.dart:1830
  ///
  /// In en, this message translates to:
  /// **'In effect from {launchTimestampLabel}'**
  String launch_detailScreensLaunchTierConfigVersionSubtitle2(
    Object? launchTimestampLabel,
  );

  /// lib/features/launch/launch_detail_screens.dart:1825
  ///
  /// In en, this message translates to:
  /// **'Eligibility rules'**
  String get launch_detailScreensLaunchTierConfigVersionTitle;

  /// lib/features/launch/launch_detail_screens.dart:1839
  ///
  /// In en, this message translates to:
  /// **'Set by this launch\'s eligibility mode'**
  String get launch_detailScreensLaunchTierDependsOnStakingSubtitle;

  /// lib/features/launch/launch_detail_screens.dart:1835
  ///
  /// In en, this message translates to:
  /// **'Depends on staking'**
  String get launch_detailScreensLaunchTierDependsOnStakingTitle;

  /// lib/features/launch/launch_detail_screens.dart:1840
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get launch_detailScreensLaunchTierDependsOnStakingTrailing;

  /// lib/features/launch/launch_detail_screens.dart:1840
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get launch_detailScreensLaunchTierDependsOnStakingTrailing2;

  /// lib/features/launch/launch_detail_screens.dart:1750
  ///
  /// In en, this message translates to:
  /// **'View LOOP staking'**
  String get launch_detailScreensLaunchTierOpenStakeLabel;

  /// lib/features/launch/launch_detail_screens.dart:1795
  ///
  /// In en, this message translates to:
  /// **'Passed to the contract as-is when buying'**
  String get launch_detailScreensLaunchTierProofSubtitle;

  /// lib/features/launch/launch_detail_screens.dart:1794
  ///
  /// In en, this message translates to:
  /// **'Eligibility proof'**
  String get launch_detailScreensLaunchTierProofTitle;

  /// lib/features/launch/launch_detail_screens.dart:1796
  ///
  /// In en, this message translates to:
  /// **'{eligibilityProof, plural, =1{1 entry} other{{eligibilityProof} entries}}'**
  String launch_detailScreensLaunchTierProofTrailing(num eligibilityProof);

  /// lib/features/launch/launch_detail_screens.dart:1850
  ///
  /// In en, this message translates to:
  /// **'{eligibility}Eligibility is this launch\'s access result and changes with config and snapshots. No threshold, fee or time window is shown here.'**
  String launch_detailScreensLaunchTierResultBody(Object? eligibility);

  /// lib/features/launch/launch_detail_screens.dart:1848
  ///
  /// In en, this message translates to:
  /// **'Eligibility isn\'t a tier or an entitlement'**
  String get launch_detailScreensLaunchTierResultTitle;

  /// lib/features/launch/launch_detail_screens.dart:1785
  ///
  /// In en, this message translates to:
  /// **'This round has no eligibility requirement'**
  String get launch_detailScreensLaunchTierRootSubtitle;

  /// lib/features/launch/launch_detail_screens.dart:1785
  ///
  /// In en, this message translates to:
  /// **'Allowlist computed at the snapshot block'**
  String get launch_detailScreensLaunchTierRootSubtitle2;

  /// lib/features/launch/launch_detail_screens.dart:1784
  ///
  /// In en, this message translates to:
  /// **'Allowlist root'**
  String get launch_detailScreensLaunchTierRootTitle;

  /// lib/features/launch/launch_detail_screens.dart:1787
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get launch_detailScreensLaunchTierRootTrailing;

  /// lib/features/launch/launch_detail_screens.dart:1777
  ///
  /// In en, this message translates to:
  /// **'Applicable round'**
  String get launch_detailScreensLaunchTierRoundTitle;

  /// lib/features/launch/launch_detail_screens.dart:755, lib/features/launch/launch_detail_screens.dart:1179
  ///
  /// In en, this message translates to:
  /// **'Each launch sets its own number of rounds.'**
  String get launch_detailScreensLaunchTrackEmptyMessage;

  /// lib/features/launch/launch_detail_screens.dart:754, lib/features/launch/launch_detail_screens.dart:1178
  ///
  /// In en, this message translates to:
  /// **'No rounds configured yet'**
  String get launch_detailScreensLaunchTrackEmptyTitle;

  /// lib/features/launch/launch_detail_screens.dart:824, lib/features/launch/launch_detail_screens.dart:1128, lib/features/launch/launch_detail_screens.dart:1513
  ///
  /// In en, this message translates to:
  /// **'Graduation and migration'**
  String get launch_detailScreensLaunchTrackGraduationTitle;

  /// lib/features/launch/launch_detail_screens.dart:1150
  ///
  /// In en, this message translates to:
  /// **'View graduation steps'**
  String get launch_detailScreensLaunchTrackOpenGraduationLabel;

  /// lib/features/launch/launch_detail_screens.dart:2331
  ///
  /// In en, this message translates to:
  /// **'Invalidated'**
  String get launch_detailScreensLoopBadge;

  /// lib/features/launch/launch_detail_screens.dart:1296
  ///
  /// In en, this message translates to:
  /// **'Access opens in stages; contract rules don\'t change per user'**
  String get launch_detailScreensLoopCompositeDetailNote;

  /// lib/features/launch/launch_detail_screens.dart:1547
  ///
  /// In en, this message translates to:
  /// **'Market cap {launchMissingFigure} / graduation line {launchMissingFigure2}. Migration triggers once the line is hit'**
  String launch_detailScreensLoopCompositeDetailNote2(
    Object? launchMissingFigure,
    Object? launchMissingFigure2,
  );

  /// lib/features/launch/launch_detail_screens.dart:1948
  ///
  /// In en, this message translates to:
  /// **'The cap is enforced by LOOP\'s bonding pool contract'**
  String get launch_detailScreensLoopCompositeDetailNote3;

  /// lib/features/launch/launch_detail_screens.dart:2111
  ///
  /// In en, this message translates to:
  /// **'Bonding pool and post-graduation records are archived together'**
  String get launch_detailScreensLoopCompositeDetailNote4;

  /// lib/features/launch/launch_detail_screens.dart:393, lib/features/launch/launch_detail_screens.dart:402, lib/features/launch/launch_detail_screens.dart:1677
  ///
  /// In en, this message translates to:
  /// **'My eligibility'**
  String get launch_detailScreensLoopLabel;

  /// lib/features/launch/launch_detail_screens.dart:1771
  ///
  /// In en, this message translates to:
  /// **'Eligibility result'**
  String get launch_detailScreensLoopLabel10;

  /// lib/features/launch/launch_detail_screens.dart:1971
  ///
  /// In en, this message translates to:
  /// **'Top holders'**
  String get launch_detailScreensLoopLabel11;

  /// lib/features/launch/launch_detail_screens.dart:2009
  ///
  /// In en, this message translates to:
  /// **'My allowance'**
  String get launch_detailScreensLoopLabel12;

  /// lib/features/launch/launch_detail_screens.dart:2134
  ///
  /// In en, this message translates to:
  /// **'Participation details'**
  String get launch_detailScreensLoopLabel13;

  /// lib/features/launch/launch_detail_screens.dart:2157
  ///
  /// In en, this message translates to:
  /// **'Purchases and settlement'**
  String get launch_detailScreensLoopLabel14;

  /// lib/features/launch/launch_detail_screens.dart:2167, lib/features/launch/launch_settlement.dart:281, lib/features/launch/launch_signing.dart:257, lib/features/launch/launch_signing.dart:403, lib/features/launch/launch_signing.dart:411, lib/features/launch/launch_widgets.dart:75
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get launch_detailScreensLoopLabel15;

  /// lib/features/launch/launch_detail_screens.dart:2201
  ///
  /// In en, this message translates to:
  /// **'Entitlement'**
  String get launch_detailScreensLoopLabel16;

  /// lib/features/launch/launch_detail_screens.dart:2233, lib/features/launch/launch_signing.dart:259
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get launch_detailScreensLoopLabel17;

  /// lib/features/launch/launch_detail_screens.dart:421
  ///
  /// In en, this message translates to:
  /// **'Launch track'**
  String get launch_detailScreensLoopLabel2;

  /// lib/features/launch/launch_detail_screens.dart:431
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get launch_detailScreensLoopLabel3;

  /// lib/features/launch/launch_detail_screens.dart:490
  ///
  /// In en, this message translates to:
  /// **'On-chain axes'**
  String get launch_detailScreensLoopLabel4;

  /// lib/features/launch/launch_detail_screens.dart:492
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get launch_detailScreensLoopLabel5;

  /// lib/features/launch/launch_detail_screens.dart:1349
  ///
  /// In en, this message translates to:
  /// **'Access timeline'**
  String get launch_detailScreensLoopLabel6;

  /// lib/features/launch/launch_detail_screens.dart:1363
  ///
  /// In en, this message translates to:
  /// **'Contract caps'**
  String get launch_detailScreensLoopLabel7;

  /// lib/features/launch/launch_detail_screens.dart:1575
  ///
  /// In en, this message translates to:
  /// **'Migration steps'**
  String get launch_detailScreensLoopLabel8;

  /// lib/features/launch/launch_detail_screens.dart:1608
  ///
  /// In en, this message translates to:
  /// **'Liquidity pool'**
  String get launch_detailScreensLoopLabel9;

  /// lib/features/launch/launch_detail_screens.dart:2293
  ///
  /// In en, this message translates to:
  /// **'Refund {amount}'**
  String launch_detailScreensRefundAmount(Object? amount);

  /// lib/features/launch/launch_detail_screens.dart:848
  ///
  /// In en, this message translates to:
  /// **'Refunding'**
  String get launch_detailScreensRefunding;

  /// lib/features/launch/launch_detail_screens.dart:858
  ///
  /// In en, this message translates to:
  /// **'The sale didn\'t succeed. Request a refund in \"My allocation\".'**
  String get launch_detailScreensRefunding2;

  /// lib/features/launch/launch_detail_screens.dart:37, lib/features/launch/launch_detail_screens.dart:48
  ///
  /// In en, this message translates to:
  /// **'Participants can\'t be loaded right now'**
  String get launch_detailScreensS;

  /// lib/features/launch/launch_detail_screens.dart:45
  ///
  /// In en, this message translates to:
  /// **'The Launch contract isn\'t live yet. Participant count isn\'t available.'**
  String get launch_detailScreensS2;

  /// lib/features/launch/launch_detail_screens.dart:58
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load project details'**
  String get launch_detailScreensS3;

  /// lib/features/launch/launch_detail_screens.dart:611
  ///
  /// In en, this message translates to:
  /// **'Round {index} ends'**
  String launch_detailScreensS4(Object? index);

  /// lib/features/launch/launch_detail_screens.dart:650
  ///
  /// In en, this message translates to:
  /// **'Raised {launchUsd1Label} / hard cap {launchUsd1Label2}'**
  String launch_detailScreensS5(
    Object? launchUsd1Label,
    Object? launchUsd1Label2,
  );

  /// lib/features/launch/launch_detail_screens.dart:938, lib/features/launch/launch_detail_screens.dart:1691, lib/features/launch/launch_widgets.dart:658
  ///
  /// In en, this message translates to:
  /// **'Public round'**
  String get launch_detailScreensS6;

  /// lib/features/launch/launch_detail_screens.dart:1548
  ///
  /// In en, this message translates to:
  /// **'Snapshot block {groupedFigure}, liquidity {wireName}, entitlement {wireName2}'**
  String launch_detailScreensS7(
    Object? groupedFigure,
    Object? wireName,
    Object? wireName2,
  );

  /// lib/features/launch/launch_detail_screens.dart:1816
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get launch_detailScreensS8;

  /// lib/features/launch/launch_detail_screens.dart:2315
  ///
  /// In en, this message translates to:
  /// **'Total refunded {launchUsd1Label}'**
  String launch_detailScreensS9(Object? launchUsd1Label);

  /// lib/features/launch/launch_detail_screens.dart:644, lib/features/launch/launch_detail_screens.dart:1541
  ///
  /// In en, this message translates to:
  /// **'Graduation progress can\'t be loaded right now'**
  String get launch_detailScreensSemanticLabel;

  /// lib/features/launch/launch_detail_screens.dart:644
  ///
  /// In en, this message translates to:
  /// **'Share of hard cap raised'**
  String get launch_detailScreensSemanticLabel2;

  /// lib/features/launch/launch_detail_screens.dart:733, lib/features/launch/launch_detail_screens.dart:832
  ///
  /// In en, this message translates to:
  /// **'Graduation and migration, {badge}'**
  String launch_detailScreensSemanticLabel3(Object? badge);

  /// lib/features/launch/launch_detail_screens.dart:1017
  ///
  /// In en, this message translates to:
  /// **'Round progress can\'t be loaded right now'**
  String get launch_detailScreensSemanticLabel4;

  /// lib/features/launch/launch_detail_screens.dart:1017
  ///
  /// In en, this message translates to:
  /// **'Share of round cap raised'**
  String get launch_detailScreensSemanticLabel5;

  /// lib/features/launch/launch_detail_screens.dart:729, lib/features/launch/launch_detail_screens.dart:823
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get launch_detailScreensShortTitle;

  /// lib/features/launch/launch_detail_screens.dart:1287, lib/features/launch/launch_detail_screens.dart:1528, lib/features/launch/launch_screen.dart:159
  ///
  /// In en, this message translates to:
  /// **'On-chain'**
  String get launch_detailScreensStamp;

  /// lib/features/launch/launch_detail_screens.dart:1926, lib/features/launch/launch_detail_screens.dart:2094
  ///
  /// In en, this message translates to:
  /// **'Indexed'**
  String get launch_detailScreensStamp2;

  /// lib/features/launch/launch_detail_screens.dart:2020
  ///
  /// In en, this message translates to:
  /// **'Used {launchUsd1Label}'**
  String launch_detailScreensSubtitle(Object? launchUsd1Label);

  /// lib/features/launch/launch_detail_screens.dart:2181, lib/features/launch/launch_detail_screens.dart:2293
  ///
  /// In en, this message translates to:
  /// **'Received {launchUnitsFigure}, block {groupedFigure}\nTx {launchShortHex}, seen {launchTimestampLabel}'**
  String launch_detailScreensSubtitle2(
    Object? groupedFigure,
    Object? launchShortHex,
    Object? launchTimestampLabel,
    Object? launchUnitsFigure,
  );

  /// lib/features/launch/launch_detail_screens.dart:2325
  ///
  /// In en, this message translates to:
  /// **'{total}, {label}, block {groupedFigure}\nTx {launchShortHex}, seen {launchTimestampLabel}'**
  String launch_detailScreensSubtitle3(
    Object? groupedFigure,
    Object? label,
    Object? launchShortHex,
    Object? launchTimestampLabel,
    Object? total,
  );

  /// lib/features/launch/launch_detail_screens.dart:41, lib/features/launch/launch_detail_screens.dart:1920
  ///
  /// In en, this message translates to:
  /// **'{groupedFigure} participants'**
  String launch_detailScreensSwitch(Object? groupedFigure);

  /// lib/features/launch/launch_detail_screens.dart:45
  ///
  /// In en, this message translates to:
  /// **'Participant count isn\'t open yet'**
  String get launch_detailScreensSwitch2;

  /// lib/features/launch/launch_detail_screens.dart:47
  ///
  /// In en, this message translates to:
  /// **'Indexing on-chain records. Participant count will show later.'**
  String get launch_detailScreensSwitch3;

  /// lib/features/launch/launch_detail_screens.dart:859
  ///
  /// In en, this message translates to:
  /// **'Advanced by the server\'s authoritative status once graduation conditions are met'**
  String get launch_detailScreensSwitch4;

  /// lib/features/launch/launch_detail_screens.dart:1022, lib/features/launch/launch_widgets.dart:664
  ///
  /// In en, this message translates to:
  /// **'LOOP has no record of this round. You can\'t buy here.'**
  String get launch_detailScreensSwitch5;

  /// lib/features/launch/launch_detail_screens.dart:1766
  ///
  /// In en, this message translates to:
  /// **'Eligibility for this launch doesn\'t depend on LOOP staking'**
  String get launch_detailScreensText;

  /// lib/features/launch/launch_detail_screens.dart:2179, lib/features/launch/launch_detail_screens.dart:2291
  ///
  /// In en, this message translates to:
  /// **'Paid {launchUsd1Label}'**
  String launch_detailScreensTitle(Object? launchUsd1Label);

  /// lib/features/launch/launch_detail_screens.dart:744, lib/features/launch/launch_settlement_section.dart:241
  ///
  /// In en, this message translates to:
  /// **'Read at block {groupedFigure}'**
  String launch_detailScreensTrackFooter(Object? groupedFigure);

  /// lib/features/launch/launch_detail_screens.dart:813
  ///
  /// In en, this message translates to:
  /// **'Wallet cap {launchUsd1Label}'**
  String launch_detailScreensTrackFooter2(Object? launchUsd1Label);

  /// lib/features/launch/launch_detail_screens.dart:2024
  ///
  /// In en, this message translates to:
  /// **'Round cap'**
  String get launch_detailScreensTrailingCaption;

  /// lib/features/launch/launch_detail_screens.dart:1303
  ///
  /// In en, this message translates to:
  /// **'Graduation line'**
  String get launch_detailScreensTrailingLabel;

  /// lib/features/launch/launch_detail_screens.dart:1937
  ///
  /// In en, this message translates to:
  /// **'Per-address holding cap'**
  String get launch_detailScreensTrailingLabel2;

  /// lib/features/launch/launch_detail_screens.dart:2106
  ///
  /// In en, this message translates to:
  /// **'Total result'**
  String get launch_detailScreensTrailingLabel3;

  /// lib/features/launch/launch_detail_screens.dart:100
  ///
  /// In en, this message translates to:
  /// **'An empty list doesn\'t mean you didn\'t take part'**
  String get launch_detailScreensUnread;

  /// lib/features/launch/launch_detail_screens.dart:846
  ///
  /// In en, this message translates to:
  /// **'Claiming'**
  String get launch_detailScreensVesting;

  /// lib/features/launch/launch_detail_screens.dart:856
  ///
  /// In en, this message translates to:
  /// **'Claims are open and vest on schedule. Claim in \"My allocation\".'**
  String get launch_detailScreensVesting2;

  /// lib/features/launch/launch_signing.dart:257
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get launch_intentActionBuy;

  /// lib/features/launch/launch_signing.dart:257
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get launch_intentActionRefund;

  /// lib/features/launch/launch_signing.dart:257
  ///
  /// In en, this message translates to:
  /// **'purchase'**
  String get launch_intentNounBuy;

  /// lib/features/launch/launch_signing.dart:257
  ///
  /// In en, this message translates to:
  /// **'claim'**
  String get launch_intentNounClaim;

  /// lib/features/launch/launch_signing.dart:257
  ///
  /// In en, this message translates to:
  /// **'refund'**
  String get launch_intentNounRefund;

  /// lib/features/launch/launch_models.dart:894
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get launch_modelsActivity;

  /// lib/features/launch/launch_models.dart:902
  ///
  /// In en, this message translates to:
  /// **'Eligibility is set by account activity.'**
  String get launch_modelsActivity2;

  /// lib/features/launch/launch_models.dart:725
  ///
  /// In en, this message translates to:
  /// **'Add and lock liquidity'**
  String get launch_modelsAddAndLockLiquidity;

  /// lib/features/launch/launch_models.dart:740
  ///
  /// In en, this message translates to:
  /// **'Status becomes graduated only after adding and locking'**
  String get launch_modelsAddAndLockLiquidity2;

  /// lib/features/launch/launch_models.dart:1085
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get launch_modelsApplied;

  /// lib/features/launch/launch_models.dart:228, lib/features/launch/launch_models.dart:1200
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get launch_modelsApproved;

  /// lib/features/launch/launch_models.dart:239
  ///
  /// In en, this message translates to:
  /// **'Approved and in the directory. Details are now read-only.'**
  String get launch_modelsApproved2;

  /// lib/features/launch/launch_models.dart:250
  ///
  /// In en, this message translates to:
  /// **'Buyback recipient address is invalid'**
  String get launch_modelsBuybackRecipientInvalid;

  /// lib/features/launch/launch_models.dart:552
  ///
  /// In en, this message translates to:
  /// **'The linked community ID is invalid. Choose again.'**
  String get launch_modelsCommunity;

  /// lib/features/launch/launch_models.dart:901
  ///
  /// In en, this message translates to:
  /// **'Eligibility is set by community membership.'**
  String get launch_modelsCommunity2;

  /// lib/features/launch/launch_models.dart:251
  ///
  /// In en, this message translates to:
  /// **'Linked community doesn\'t match the project'**
  String get launch_modelsCommunityBindingMismatch;

  /// lib/features/launch/launch_models.dart:1090
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get launch_modelsDeferred;

  /// lib/features/launch/launch_models.dart:1092
  ///
  /// In en, this message translates to:
  /// **'Delisted'**
  String get launch_modelsDelisted;

  /// lib/features/launch/launch_models.dart:235
  ///
  /// In en, this message translates to:
  /// **'You can keep editing and submit.'**
  String get launch_modelsDraft;

  /// lib/features/launch/launch_models.dart:623, lib/features/launch/launch_widgets.dart:1018
  ///
  /// In en, this message translates to:
  /// **'Per-wallet round cap'**
  String get launch_modelsEntries;

  /// lib/features/launch/launch_models.dart:625
  ///
  /// In en, this message translates to:
  /// **'Fee (bps)'**
  String get launch_modelsEntries2;

  /// lib/features/launch/launch_models.dart:1221, lib/features/launch/launch_widgets.dart:475
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get launch_modelsEntries3;

  /// lib/features/launch/launch_models.dart:1091
  ///
  /// In en, this message translates to:
  /// **'Invalid materials'**
  String get launch_modelsEvidenceInvalid;

  /// lib/features/launch/launch_models.dart:1086
  ///
  /// In en, this message translates to:
  /// **'Materials needed'**
  String get launch_modelsEvidencePending;

  /// lib/features/launch/launch_models.dart:1088
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get launch_modelsFeatured;

  /// lib/features/launch/launch_models.dart:237
  ///
  /// In en, this message translates to:
  /// **'Review in progress. Details are read-only meanwhile.'**
  String get launch_modelsInReview;

  /// lib/features/launch/launch_models.dart:248
  ///
  /// In en, this message translates to:
  /// **'Incomplete materials'**
  String get launch_modelsIncompleteMaterials;

  /// lib/features/launch/launch_models.dart:1087
  ///
  /// In en, this message translates to:
  /// **'Listed'**
  String get launch_modelsListed;

  /// lib/features/launch/launch_models.dart:548
  ///
  /// In en, this message translates to:
  /// **'Project name must be 1–20 characters (emoji count as 2), with no line breaks or invisible characters.'**
  String get launch_modelsName;

  /// lib/features/launch/launch_models.dart:249
  ///
  /// In en, this message translates to:
  /// **'Name or ticker conflicts with an existing project'**
  String get launch_modelsNameOrTickerConflict;

  /// lib/features/launch/launch_models.dart:550
  ///
  /// In en, this message translates to:
  /// **'Narrative is up to 2000 characters with no control characters. Leave it empty to skip it.'**
  String get launch_modelsNarrative;

  /// lib/features/launch/launch_models.dart:551
  ///
  /// In en, this message translates to:
  /// **'Official links must start with https:// and be at most 512 characters.'**
  String get launch_modelsOfficialLinks;

  /// lib/features/launch/launch_models.dart:726
  ///
  /// In en, this message translates to:
  /// **'Open DEX pool trading'**
  String get launch_modelsOpenExternalTrading;

  /// lib/features/launch/launch_models.dart:741
  ///
  /// In en, this message translates to:
  /// **'The bonding pool holding cap lifts as the DEX pool opens'**
  String get launch_modelsOpenExternalTrading2;

  /// lib/features/launch/launch_models.dart:252
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get launch_modelsOther;

  /// lib/features/launch/launch_models.dart:1052
  ///
  /// In en, this message translates to:
  /// **'Perpetual'**
  String get launch_modelsPerpetual;

  /// lib/features/launch/launch_models.dart:724
  ///
  /// In en, this message translates to:
  /// **'Collect funds and create the liquidity pool'**
  String get launch_modelsPreparePool;

  /// lib/features/launch/launch_models.dart:739
  ///
  /// In en, this message translates to:
  /// **'Collect funds and create the liquidity pool on the DEX'**
  String get launch_modelsPreparePool2;

  /// lib/features/launch/launch_models.dart:1084
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get launch_modelsPreparing;

  /// lib/features/launch/launch_models.dart:240
  ///
  /// In en, this message translates to:
  /// **'Rejected. Edit per the review notes and resubmit.'**
  String get launch_modelsRejected;

  /// lib/features/launch/launch_models.dart:1089
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get launch_modelsRejected2;

  /// lib/features/launch/launch_models.dart:227, lib/features/launch/launch_models.dart:1199
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get launch_modelsReturned;

  /// lib/features/launch/launch_models.dart:238
  ///
  /// In en, this message translates to:
  /// **'Returned. Edit per the reason and resubmit.'**
  String get launch_modelsReturned2;

  /// lib/features/launch/launch_models.dart:1050
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get launch_modelsSpot;

  /// lib/features/launch/launch_models.dart:723
  ///
  /// In en, this message translates to:
  /// **'Stop bonding pool trading'**
  String get launch_modelsStopInternalTrading;

  /// lib/features/launch/launch_models.dart:738
  ///
  /// In en, this message translates to:
  /// **'Bonding pool matching freezes the moment graduation conditions are met'**
  String get launch_modelsStopInternalTrading2;

  /// lib/features/launch/launch_models.dart:236
  ///
  /// In en, this message translates to:
  /// **'Submitted, awaiting manual review. Submitting doesn\'t mean approval.'**
  String get launch_modelsSubmitted;

  /// lib/features/launch/launch_models.dart:549
  ///
  /// In en, this message translates to:
  /// **'Ticker must be 1–20 characters: Chinese, letters, digits or emoji, with no line breaks or invisible characters.'**
  String get launch_modelsTicker;

  /// lib/features/launch/launch_models.dart:903
  ///
  /// In en, this message translates to:
  /// **'This launch has no eligibility mode configured yet, so there\'s no eligibility result.'**
  String get launch_modelsUnavailable;

  /// lib/features/launch/launch_models.dart:892
  ///
  /// In en, this message translates to:
  /// **'Allowlist'**
  String get launch_modelsWhitelist;

  /// lib/features/launch/launch_models.dart:900
  ///
  /// In en, this message translates to:
  /// **'Eligibility is set by an allowlist maintained by operations.'**
  String get launch_modelsWhitelist2;

  /// lib/features/launch/launch_trade_screen.dart:698
  ///
  /// In en, this message translates to:
  /// **'Round {index}, '**
  String launch_roundComma(Object? index);

  /// lib/features/launch/launch_screen.dart:416
  ///
  /// In en, this message translates to:
  /// **'Approved projects without a schedule show up here.'**
  String get launch_screenBody;

  /// lib/features/launch/launch_screen.dart:297
  ///
  /// In en, this message translates to:
  /// **'BSC Mainnet'**
  String get launch_screenBscMainnet;

  /// lib/features/launch/launch_screen.dart:186
  ///
  /// In en, this message translates to:
  /// **'No approved projects in the directory yet'**
  String get launch_screenEmptyMessage;

  /// lib/features/launch/launch_screen.dart:187
  ///
  /// In en, this message translates to:
  /// **'Approved projects show up here.'**
  String get launch_screenEmptyReason;

  /// lib/features/launch/launch_screen.dart:147
  ///
  /// In en, this message translates to:
  /// **'Loading directory'**
  String get launch_screenHeading;

  /// lib/features/launch/launch_screen.dart:148
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{1 registered project} other{{total} registered projects}}'**
  String launch_screenHeading2(num total);

  /// lib/features/launch/launch_screen.dart:352
  ///
  /// In en, this message translates to:
  /// **'Graduated projects'**
  String get launch_screenLabel;

  /// lib/features/launch/launch_screen.dart:165
  ///
  /// In en, this message translates to:
  /// **'Launch isn\'t available right now'**
  String get launch_screenLaunchCapabilityUnavailableTitle;

  /// lib/features/launch/launch_screen.dart:319
  ///
  /// In en, this message translates to:
  /// **'Directory available, contract not ready'**
  String get launch_screenLaunchEvidenceNoticeTitle;

  /// lib/features/launch/launch_screen.dart:364
  ///
  /// In en, this message translates to:
  /// **'Projects show up here once their liquidity is locked.'**
  String get launch_screenLaunchGraduatedEmptyMessage;

  /// lib/features/launch/launch_screen.dart:363
  ///
  /// In en, this message translates to:
  /// **'No graduated projects yet'**
  String get launch_screenLaunchGraduatedEmptyTitle;

  /// lib/features/launch/launch_screen.dart:256
  ///
  /// In en, this message translates to:
  /// **'Shows only counts the LOOP ledger can prove'**
  String get launch_screenLaunchOpenEconomySubtitle;

  /// lib/features/launch/launch_screen.dart:255
  ///
  /// In en, this message translates to:
  /// **'Ecosystem economy panel'**
  String get launch_screenLaunchOpenEconomyTitle;

  /// lib/features/launch/launch_screen.dart:297
  ///
  /// In en, this message translates to:
  /// **'Directory, applications and round config come from LOOP. On-chain status is read from {testnet}.'**
  String launch_screenLaunchOverviewCaption(Object? testnet);

  /// lib/features/launch/launch_screen.dart:302
  ///
  /// In en, this message translates to:
  /// **'Directory, applications and round config come from LOOP. On-chain status, price and graduation progress can\'t be loaded right now.'**
  String get launch_screenLaunchOverviewCaption2;

  /// lib/features/launch/launch_screen.dart:63
  ///
  /// In en, this message translates to:
  /// **'Launch rules'**
  String get launch_screenLaunchRulesActionLabel;

  /// lib/features/launch/launch_screen.dart:25
  ///
  /// In en, this message translates to:
  /// **'No projects in this segment yet. Segments follow on-chain sale status; projects without on-chain readings are grouped by schedule status.'**
  String get launch_screenLaunchSegmentEmptyBody;

  /// lib/features/launch/launch_screen.dart:51
  ///
  /// In en, this message translates to:
  /// **'Manage staking'**
  String get launch_screenLaunchStakeActionLabel;

  /// lib/features/launch/launch_screen.dart:160
  ///
  /// In en, this message translates to:
  /// **'Off-chain'**
  String get launch_screenStamp;

  /// lib/features/launch/launch_screen.dart:414
  ///
  /// In en, this message translates to:
  /// **'{launchSegmentLabel}: no projects'**
  String launch_screenTitle(Object? launchSegmentLabel);

  /// lib/features/launch/launch_settlement.dart:304
  ///
  /// In en, this message translates to:
  /// **'{tx}This {noun} is confirmed on chain. {landed}.'**
  String launch_settlementBody(Object? landed, Object? noun, Object? tx);

  /// lib/features/launch/launch_settlement.dart:308
  ///
  /// In en, this message translates to:
  /// **'{tx}Execution was refused on chain and no funds moved. You can start again.'**
  String launch_settlementBody2(Object? tx);

  /// lib/features/launch/launch_settlement.dart:312
  ///
  /// In en, this message translates to:
  /// **'{tx}This transaction still wasn\'t seen after the signing window ended. Holdings were reloaded; a late transaction may still succeed, so check before starting again.'**
  String launch_settlementBody3(Object? tx);

  /// lib/features/launch/launch_settlement.dart:316
  ///
  /// In en, this message translates to:
  /// **'{tx}The on-chain transaction doesn\'t match what was reviewed at signing, so the server didn\'t record it. Check and start again, and contact support.'**
  String launch_settlementBody4(Object? tx);

  /// lib/features/launch/launch_settlement.dart:318
  ///
  /// In en, this message translates to:
  /// **'{tx}Broadcast doesn\'t mean it landed; the on-chain index decides the result. Don\'t repeat the {noun}.'**
  String launch_settlementBody5(Object? noun, Object? tx);

  /// lib/features/launch/launch_settlement.dart:294
  ///
  /// In en, this message translates to:
  /// **'Purchase confirmed'**
  String get launch_settlementBuy;

  /// lib/features/launch/launch_settlement.dart:226
  ///
  /// In en, this message translates to:
  /// **'Claim {launchUnitsFigure} tokens'**
  String launch_settlementClaim(Object? launchUnitsFigure);

  /// lib/features/launch/launch_settlement.dart:228
  ///
  /// In en, this message translates to:
  /// **'Request refund of {launchUnitsFigure} USD1'**
  String launch_settlementClaimRefund(Object? launchUnitsFigure);

  /// lib/features/launch/launch_settlement.dart:281
  ///
  /// In en, this message translates to:
  /// **'payment wallet'**
  String get launch_settlementReplaceAll;

  /// lib/features/launch/launch_settlement.dart:281
  ///
  /// In en, this message translates to:
  /// **'current wallet'**
  String get launch_settlementReplaceAll2;

  /// lib/features/launch/launch_settlement.dart:298
  ///
  /// In en, this message translates to:
  /// **'The wallet balance is what counts'**
  String get launch_settlementS;

  /// lib/features/launch/launch_settlement.dart:300
  ///
  /// In en, this message translates to:
  /// **'Tx {launchShortHex}. '**
  String launch_settlementS2(Object? launchShortHex);

  /// lib/features/launch/launch_settlement_section.dart:316
  ///
  /// In en, this message translates to:
  /// **'Claimable'**
  String get launch_settlementSectionBadge;

  /// lib/features/launch/launch_settlement_section.dart:351
  ///
  /// In en, this message translates to:
  /// **'Refundable'**
  String get launch_settlementSectionBadge2;

  /// lib/features/launch/launch_settlement_section.dart:470
  ///
  /// In en, this message translates to:
  /// **'{body}No on-chain result yet. You can check again later.'**
  String launch_settlementSectionBody(Object? body);

  /// lib/features/launch/launch_settlement_section.dart:193, lib/features/launch/launch_settlement_section.dart:385
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get launch_settlementSectionLabel;

  /// lib/features/launch/launch_settlement_section.dart:220, lib/features/launch/launch_trade_screen.dart:608, lib/features/launch/launch_trade_screen.dart:732
  ///
  /// In en, this message translates to:
  /// **'{launchReasonCodeText}So this page builds no transaction and opens no signature.'**
  String launch_settlementSectionLaunchSettlementEvidenceBody(
    Object? launchReasonCodeText,
  );

  /// lib/features/launch/launch_settlement_section.dart:218
  ///
  /// In en, this message translates to:
  /// **'Not available right now'**
  String get launch_settlementSectionLaunchSettlementEvidenceTitle;

  /// lib/features/launch/launch_settlement_section.dart:209
  ///
  /// In en, this message translates to:
  /// **'The contract refuses claims and refunds while paused, so the buttons are off. They reopen here once it resumes.'**
  String get launch_settlementSectionLaunchSettlementPausedBody;

  /// lib/features/launch/launch_settlement_section.dart:478, lib/features/launch/launch_trade_screen.dart:1008
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get launch_settlementSectionLaunchSettlementPollResumeLabel;

  /// lib/features/launch/launch_settlement_section.dart:386
  ///
  /// In en, this message translates to:
  /// **'Loading the allocation you can act on from the server. The signing review opens once it loads.'**
  String get launch_settlementSectionLaunchSettlementPreparingBody;

  /// lib/features/launch/launch_settlement_section.dart:369
  ///
  /// In en, this message translates to:
  /// **'The contract still records {launchUsd1Label} unrefunded, but the refund window has closed and the contract no longer accepts refunds.'**
  String launch_settlementSectionLaunchSettlementRefundClosedBody(
    Object? launchUsd1Label,
  );

  /// lib/features/launch/launch_settlement_section.dart:367
  ///
  /// In en, this message translates to:
  /// **'Refund window closed'**
  String get launch_settlementSectionLaunchSettlementRefundClosedTitle;

  /// lib/features/launch/launch_settlement_section.dart:446, lib/features/launch/launch_trade_screen.dart:1018
  ///
  /// In en, this message translates to:
  /// **'Reporting again'**
  String get launch_settlementSectionLaunchSettlementReportRetryLabel;

  /// lib/features/launch/launch_settlement_section.dart:446, lib/features/launch/launch_trade_screen.dart:1018
  ///
  /// In en, this message translates to:
  /// **'Report again'**
  String get launch_settlementSectionLaunchSettlementReportRetryLabel2;

  /// lib/features/launch/launch_settlement_section.dart:412, lib/features/launch/launch_trade_screen.dart:1029
  ///
  /// In en, this message translates to:
  /// **'Not signed'**
  String get launch_settlementSectionLaunchSettlementSignRefusedTitle;

  /// lib/features/launch/launch_settlement_section.dart:306
  ///
  /// In en, this message translates to:
  /// **'{view}Claim and refund buttons show only after it loads. Pull down to reload.'**
  String launch_settlementSectionLaunchSettlementUnreadBody(Object? view);

  /// lib/features/launch/launch_settlement_section.dart:304
  ///
  /// In en, this message translates to:
  /// **'My allocation can\'t be loaded right now'**
  String get launch_settlementSectionLaunchSettlementUnreadTitle;

  /// lib/features/launch/launch_settlement_section.dart:168
  ///
  /// In en, this message translates to:
  /// **'My allocation'**
  String get launch_settlementSectionLoopLabel;

  /// lib/features/launch/launch_settlement_section.dart:275
  ///
  /// In en, this message translates to:
  /// **'Awaiting finalization'**
  String get launch_settlementSectionNotice;

  /// lib/features/launch/launch_settlement_section.dart:276
  ///
  /// In en, this message translates to:
  /// **'The sale ended and is awaiting finalization. If the soft cap is reached, claims open on the vesting schedule; otherwise refunds open. Wallets that took part see the matching button here.'**
  String get launch_settlementSectionNotice2;

  /// lib/features/launch/launch_settlement_section.dart:282
  ///
  /// In en, this message translates to:
  /// **'Awaiting TGE'**
  String get launch_settlementSectionNotice3;

  /// lib/features/launch/launch_settlement_section.dart:283
  ///
  /// In en, this message translates to:
  /// **'The sale succeeded and the allocation is frozen{position}. Claims open once TGE arrives and the liquidity pool is live.'**
  String launch_settlementSectionNotice4(Object? position);

  /// lib/features/launch/launch_settlement_section.dart:290
  ///
  /// In en, this message translates to:
  /// **'Preparing refunds'**
  String get launch_settlementSectionNotice5;

  /// lib/features/launch/launch_settlement_section.dart:291
  ///
  /// In en, this message translates to:
  /// **'The sale didn\'t succeed. Refunds open once the refund liability is frozen; wallets that took part see the button here.'**
  String get launch_settlementSectionNotice6;

  /// lib/features/launch/launch_settlement_section.dart:282
  ///
  /// In en, this message translates to:
  /// **' ({amount} tokens)'**
  String launch_settlementSectionPositionTokens(Object? amount);

  /// lib/features/launch/launch_settlement_section.dart:198
  ///
  /// In en, this message translates to:
  /// **'{label}, not available right now'**
  String launch_settlementSectionSemanticLabel(Object? label);

  /// lib/features/launch/launch_settlement_section.dart:297
  ///
  /// In en, this message translates to:
  /// **'Claim and refund buttons show only after holdings load.'**
  String get launch_settlementSectionSubtitle;

  /// lib/features/launch/launch_settlement_section.dart:314
  ///
  /// In en, this message translates to:
  /// **'Claimed {launchUnitsFigure} tokens, {block}\nThe contract executes the claim; tokens go straight to the current wallet.'**
  String launch_settlementSectionSubtitle2(
    Object? block,
    Object? launchUnitsFigure,
  );

  /// lib/features/launch/launch_settlement_section.dart:324
  ///
  /// In en, this message translates to:
  /// **'Allocation {launchUnitsFigure} tokens, claimable as it vests, {block}'**
  String launch_settlementSectionSubtitle3(
    Object? block,
    Object? launchUnitsFigure,
  );

  /// lib/features/launch/launch_settlement_section.dart:331
  ///
  /// In en, this message translates to:
  /// **'Nothing claimable now. Come back after the next unlock, {block}'**
  String launch_settlementSectionSubtitle4(Object? block);

  /// lib/features/launch/launch_settlement_section.dart:340
  ///
  /// In en, this message translates to:
  /// **'Total claimed {launchUnitsFigure} tokens, {block}'**
  String launch_settlementSectionSubtitle5(
    Object? block,
    Object? launchUnitsFigure,
  );

  /// lib/features/launch/launch_settlement_section.dart:349
  ///
  /// In en, this message translates to:
  /// **'Refunded {launchUsd1Label}, {block}\nThe contract executes the refund all at once; USD1 goes straight to the current wallet.'**
  String launch_settlementSectionSubtitle6(
    Object? block,
    Object? launchUsd1Label,
  );

  /// lib/features/launch/launch_settlement_section.dart:358
  ///
  /// In en, this message translates to:
  /// **'Total refunded {launchUsd1Label}, {block}'**
  String launch_settlementSectionSubtitle7(
    Object? block,
    Object? launchUsd1Label,
  );

  /// lib/features/launch/launch_settlement_section.dart:296
  ///
  /// In en, this message translates to:
  /// **'Loading my allocation'**
  String get launch_settlementSectionTitle;

  /// lib/features/launch/launch_settlement_section.dart:312
  ///
  /// In en, this message translates to:
  /// **'Claimable {launchUnitsFigure} tokens'**
  String launch_settlementSectionTitle2(Object? launchUnitsFigure);

  /// lib/features/launch/launch_settlement_section.dart:330
  ///
  /// In en, this message translates to:
  /// **'Claimed {launchUnitsFigure} tokens'**
  String launch_settlementSectionTitle3(Object? launchUnitsFigure);

  /// lib/features/launch/launch_settlement_section.dart:429, lib/features/launch/launch_trade_screen.dart:693, lib/features/launch/launch_trade_screen.dart:982
  ///
  /// In en, this message translates to:
  /// **'Sent to the wallet, result unconfirmed'**
  String get launch_settlementSectionTitle4;

  /// lib/features/launch/launch_settlement_section.dart:429
  ///
  /// In en, this message translates to:
  /// **'Broadcast, not recorded by the server'**
  String get launch_settlementSectionTitle5;

  /// lib/features/launch/launch_settlement_section.dart:303
  ///
  /// In en, this message translates to:
  /// **'The current wallet\'s holdings didn\'t load this time. '**
  String get launch_settlementSectionUnreadPosition;

  /// lib/features/launch/launch_settlement.dart:252
  ///
  /// In en, this message translates to:
  /// **'Claims not open yet'**
  String get launch_settlementSwitch;

  /// lib/features/launch/launch_settlement.dart:274
  ///
  /// In en, this message translates to:
  /// **'The current wallet didn\'t take part in this launch and has nothing to claim or refund. No transaction was submitted. If you took part with another wallet, switch to it in Wallet and come back.'**
  String get launch_settlementSwitch10;

  /// lib/features/launch/launch_settlement.dart:276
  ///
  /// In en, this message translates to:
  /// **'Claimable is 0: the next unlock hasn\'t arrived, or everything was claimed. No transaction was submitted. Come back after the next unlock.'**
  String get launch_settlementSwitch11;

  /// lib/features/launch/launch_settlement.dart:277
  ///
  /// In en, this message translates to:
  /// **'This wallet\'s USD1 has been fully refunded. No transaction was submitted.'**
  String get launch_settlementSwitch12;

  /// lib/features/launch/launch_settlement.dart:298
  ///
  /// In en, this message translates to:
  /// **'\"My participation\" is what counts for the allocation'**
  String get launch_settlementSwitch13;

  /// lib/features/launch/launch_settlement.dart:253
  ///
  /// In en, this message translates to:
  /// **'Refunds not available'**
  String get launch_settlementSwitch2;

  /// lib/features/launch/launch_settlement.dart:254, lib/features/launch/launch_settlement_section.dart:208
  ///
  /// In en, this message translates to:
  /// **'Contract paused'**
  String get launch_settlementSwitch3;

  /// lib/features/launch/launch_settlement.dart:255
  ///
  /// In en, this message translates to:
  /// **'This wallet didn\'t take part'**
  String get launch_settlementSwitch4;

  /// lib/features/launch/launch_settlement.dart:256, lib/features/launch/launch_settlement_section.dart:322
  ///
  /// In en, this message translates to:
  /// **'Nothing to claim'**
  String get launch_settlementSwitch5;

  /// lib/features/launch/launch_settlement.dart:258
  ///
  /// In en, this message translates to:
  /// **'This didn\'t go through'**
  String get launch_settlementSwitch6;

  /// lib/features/launch/launch_settlement.dart:269
  ///
  /// In en, this message translates to:
  /// **'The contract hasn\'t opened claims yet (TGE not reached, or the liquidity pool isn\'t live). No transaction was submitted. Details were reloaded; the claim button appears here once it opens.'**
  String get launch_settlementSwitch7;

  /// lib/features/launch/launch_settlement.dart:271
  ///
  /// In en, this message translates to:
  /// **'Refunds are only possible when the sale failed or was cancelled and the refund window is open. No transaction was submitted. Details were reloaded.'**
  String get launch_settlementSwitch8;

  /// lib/features/launch/launch_settlement.dart:272
  ///
  /// In en, this message translates to:
  /// **'Claims and refunds are refused while the contract is paused. No transaction was submitted. Try again later.'**
  String get launch_settlementSwitch9;

  /// lib/features/launch/launch_settlement.dart:307
  ///
  /// In en, this message translates to:
  /// **'Transaction failed (gas only)'**
  String get launch_settlementTitle;

  /// lib/features/launch/launch_settlement.dart:311
  ///
  /// In en, this message translates to:
  /// **'Not on chain, you can start again'**
  String get launch_settlementTitle2;

  /// lib/features/launch/launch_settlement.dart:315
  ///
  /// In en, this message translates to:
  /// **'Reported transaction doesn\'t match'**
  String get launch_settlementTitle3;

  /// lib/features/launch/launch_settlement.dart:318
  ///
  /// In en, this message translates to:
  /// **'Broadcast, awaiting on-chain confirmation'**
  String get launch_settlementTitle4;

  /// lib/features/launch/launch_signing.dart:271
  ///
  /// In en, this message translates to:
  /// **'Claim {launchUnitsFigure} tokens to the current wallet'**
  String launch_signingClaim(Object? launchUnitsFigure);

  /// lib/features/launch/launch_signing.dart:273
  ///
  /// In en, this message translates to:
  /// **'Refund {launchUnitsFigure} USD1 to the current wallet'**
  String launch_signingClaimRefund(Object? launchUnitsFigure);

  /// lib/features/launch/launch_signing.dart:451
  ///
  /// In en, this message translates to:
  /// **'The wallet\'s result is unknown and this {noun} is locked. Check \"My participation\" and don\'t sign again.'**
  String launch_signingIf(Object? noun);

  /// lib/features/launch/launch_signing.dart:456
  ///
  /// In en, this message translates to:
  /// **'The wallet broadcast ({short}) and the server recorded it. Current status: {label}. Broadcast doesn\'t mean {kind}; the on-chain index decides, and it will appear in \"My participation\". Don\'t repeat the {noun}.'**
  String launch_signingIf2(
    Object? kind,
    Object? label,
    Object? noun,
    Object? short,
  );

  /// lib/features/launch/launch_signing.dart:460
  ///
  /// In en, this message translates to:
  /// **'The wallet broadcast ({short}). Broadcast doesn\'t mean {kind}. {launchReportReasonTextFor}'**
  String launch_signingIf3(
    Object? kind,
    Object? launchReportReasonTextFor,
    Object? short,
  );

  /// lib/features/launch/launch_signing.dart:293
  ///
  /// In en, this message translates to:
  /// **'Funds'**
  String get launch_signingLabel;

  /// lib/features/launch/launch_signing.dart:355
  ///
  /// In en, this message translates to:
  /// **'Wallet project cap'**
  String get launch_signingLabel10;

  /// lib/features/launch/launch_signing.dart:297
  ///
  /// In en, this message translates to:
  /// **'Claimable now'**
  String get launch_signingLabel2;

  /// lib/features/launch/launch_signing.dart:303
  ///
  /// In en, this message translates to:
  /// **'Refund now'**
  String get launch_signingLabel3;

  /// lib/features/launch/launch_signing.dart:307
  ///
  /// In en, this message translates to:
  /// **'Wallet total purchased'**
  String get launch_signingLabel4;

  /// lib/features/launch/launch_signing.dart:312
  ///
  /// In en, this message translates to:
  /// **'Signature valid until'**
  String get launch_signingLabel5;

  /// lib/features/launch/launch_signing.dart:313, lib/features/launch/launch_signing.dart:361
  ///
  /// In en, this message translates to:
  /// **'State digest'**
  String get launch_signingLabel6;

  /// lib/features/launch/launch_signing.dart:340
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get launch_signingLabel7;

  /// lib/features/launch/launch_signing.dart:342
  ///
  /// In en, this message translates to:
  /// **'Wallet total'**
  String get launch_signingLabel8;

  /// lib/features/launch/launch_signing.dart:348
  ///
  /// In en, this message translates to:
  /// **'Wallet cap this round'**
  String get launch_signingLabel9;

  /// lib/features/launch/launch_signing.dart:245
  ///
  /// In en, this message translates to:
  /// **'Confirm claim'**
  String get launch_signingLaunchClaimTitle;

  /// lib/features/launch/launch_signing.dart:244
  ///
  /// In en, this message translates to:
  /// **'Confirm purchase'**
  String get launch_signingLaunchPurchaseTitle;

  /// lib/features/launch/launch_signing.dart:246
  ///
  /// In en, this message translates to:
  /// **'Confirm refund'**
  String get launch_signingLaunchRefundTitle;

  /// lib/features/launch/launch_signing.dart:263
  ///
  /// In en, this message translates to:
  /// **'Executed by the contract; LOOP never holds the funds'**
  String get launch_signingLaunchSettlementCustodyNote;

  /// lib/features/launch/launch_signing.dart:374
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing changed.'**
  String get launch_signingSwitch;

  /// lib/features/launch/launch_signing.dart:384
  ///
  /// In en, this message translates to:
  /// **'Simulation failed: this purchase would be refused on chain. No transaction was submitted. Adjust the amount or get a new quote later.'**
  String get launch_signingSwitch10;

  /// lib/features/launch/launch_signing.dart:385
  ///
  /// In en, this message translates to:
  /// **'This purchase can\'t be simulated right now, so the server doesn\'t allow signing. No transaction was submitted. Get a new quote later.'**
  String get launch_signingSwitch11;

  /// lib/features/launch/launch_signing.dart:386
  ///
  /// In en, this message translates to:
  /// **'This purchase was already submitted and can\'t be signed again. Check \"My participation\".'**
  String get launch_signingSwitch12;

  /// lib/features/launch/launch_signing.dart:387
  ///
  /// In en, this message translates to:
  /// **'The wallet didn\'t finish signing. No transaction was submitted.'**
  String get launch_signingSwitch13;

  /// lib/features/launch/launch_signing.dart:397
  ///
  /// In en, this message translates to:
  /// **'The signing window for this {noun} has passed. No transaction was submitted. Start again.'**
  String launch_signingSwitch14(Object? noun);

  /// lib/features/launch/launch_signing.dart:398
  ///
  /// In en, this message translates to:
  /// **'Simulation failed: this {noun} would be refused on chain. No transaction was submitted. Refresh and try again.'**
  String launch_signingSwitch15(Object? noun);

  /// lib/features/launch/launch_signing.dart:400
  ///
  /// In en, this message translates to:
  /// **'This {noun} can\'t be simulated right now, so the server doesn\'t allow signing. No transaction was submitted. Start again later.'**
  String launch_signingSwitch16(Object? noun);

  /// lib/features/launch/launch_signing.dart:402
  ///
  /// In en, this message translates to:
  /// **'This {noun} was already submitted and can\'t be signed again. Check \"My participation\".'**
  String launch_signingSwitch17(Object? noun);

  /// lib/features/launch/launch_signing.dart:418
  ///
  /// In en, this message translates to:
  /// **'Another transaction was already reported for this purchase, so this broadcast wasn\'t recorded. The transaction may be on chain; check \"My participation\" and don\'t sign again.'**
  String get launch_signingSwitch18;

  /// lib/features/launch/launch_signing.dart:421
  ///
  /// In en, this message translates to:
  /// **'The server no longer accepts reports for this purchase; its status has changed. The wallet already broadcast and the transaction may be on chain; check \"My participation\" and don\'t sign again.'**
  String get launch_signingSwitch19;

  /// lib/features/launch/launch_signing.dart:375
  ///
  /// In en, this message translates to:
  /// **'Verification didn\'t pass. Nothing changed.'**
  String get launch_signingSwitch2;

  /// lib/features/launch/launch_signing.dart:424
  ///
  /// In en, this message translates to:
  /// **'This purchase expired and the transaction isn\'t visible on chain yet, so the report wasn\'t accepted. It may still be propagating; check \"My participation\" later and don\'t sign again.'**
  String get launch_signingSwitch20;

  /// lib/features/launch/launch_signing.dart:427
  ///
  /// In en, this message translates to:
  /// **'The on-chain transaction doesn\'t match the purchase reviewed at signing, so the server didn\'t record it. Check \"My participation\", don\'t sign again, and contact support.'**
  String get launch_signingSwitch21;

  /// lib/features/launch/launch_signing.dart:430
  ///
  /// In en, this message translates to:
  /// **'The wallet already broadcast, but the server didn\'t accept or didn\'t receive this report. The transaction may be on chain; you can report again later. Don\'t sign again.'**
  String get launch_signingSwitch22;

  /// lib/features/launch/launch_signing.dart:376
  ///
  /// In en, this message translates to:
  /// **'This purchase expired. No transaction was submitted. Get a new quote.'**
  String get launch_signingSwitch3;

  /// lib/features/launch/launch_signing.dart:377
  ///
  /// In en, this message translates to:
  /// **'The transaction doesn\'t match what was reviewed. Signing refused; no transaction was submitted.'**
  String get launch_signingSwitch4;

  /// lib/features/launch/launch_signing.dart:378
  ///
  /// In en, this message translates to:
  /// **'The payment wallet for this purchase isn\'t in the wallet list. No transaction was submitted.'**
  String get launch_signingSwitch5;

  /// lib/features/launch/launch_signing.dart:380
  ///
  /// In en, this message translates to:
  /// **'Signing isn\'t allowed on this chain. No transaction was submitted.'**
  String get launch_signingSwitch6;

  /// lib/features/launch/launch_signing.dart:381
  ///
  /// In en, this message translates to:
  /// **'The wallet can\'t sign on this chain right now. No transaction was submitted.'**
  String get launch_signingSwitch7;

  /// lib/features/launch/launch_signing.dart:382
  ///
  /// In en, this message translates to:
  /// **'The signed-in wallet isn\'t the payment wallet for this purchase. No transaction was submitted.'**
  String get launch_signingSwitch8;

  /// lib/features/launch/launch_signing.dart:383
  ///
  /// In en, this message translates to:
  /// **'The wallet the server built the transaction for doesn\'t match the current payment wallet. Signing refused; no transaction was submitted.'**
  String get launch_signingSwitch9;

  /// lib/features/launch/launch_signing.dart:350
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get launch_signingValue;

  /// lib/features/launch/launch_detail_screens.dart:2281
  ///
  /// In en, this message translates to:
  /// **'tokens'**
  String get launch_tokensUnit;

  /// lib/features/launch/launch_trade_screen.dart:995
  ///
  /// In en, this message translates to:
  /// **'No on-chain result yet. You can check again later.'**
  String get launch_tradeBody;

  /// lib/features/launch/launch_trade_screen.dart:1107
  ///
  /// In en, this message translates to:
  /// **'Loading this wallet\'s USD1 allowance on the Launch chain. You can\'t buy until it loads.'**
  String get launch_tradeBody2;

  /// lib/features/launch/launch_trade_screen.dart:1120
  ///
  /// In en, this message translates to:
  /// **'{usd1}This purchase needs {amount} USD1. The approval covers only this amount, not unlimited; you can buy once it lands.'**
  String launch_tradeBody3(Object? amount, Object? usd1);

  /// lib/features/launch/launch_trade_screen.dart:1202
  ///
  /// In en, this message translates to:
  /// **'{fact}. After sending funds, reload the balance and buy again.'**
  String launch_tradeBody4(Object? fact);

  /// lib/features/launch/launch_trade_screen.dart:793, lib/features/launch/launch_trade_screen.dart:795
  ///
  /// In en, this message translates to:
  /// **'Not loaded'**
  String get launch_tradeBuild;

  /// lib/features/launch/launch_trade_screen.dart:814
  ///
  /// In en, this message translates to:
  /// **'Pay {payAsset}'**
  String launch_tradeBuild2(Object? payAsset);

  /// lib/features/launch/launch_trade_screen.dart:492
  ///
  /// In en, this message translates to:
  /// **'Pay, receive, fees and remaining allowance get a final review before signing. A server quote exists only after submitting.'**
  String get launch_tradeCaption;

  /// lib/features/launch/launch_trade_screen.dart:493
  ///
  /// In en, this message translates to:
  /// **'Quote from contract readings at block {snapshotBlockNumber}. The review below applies before signing.'**
  String launch_tradeCaption2(Object? snapshotBlockNumber);

  /// lib/features/launch/launch_trade_screen.dart:1112
  ///
  /// In en, this message translates to:
  /// **'Current allowance {allowance}. '**
  String launch_tradeCurrentAllowance(Object? allowance);

  /// lib/features/launch/launch_trade_screen.dart:514
  ///
  /// In en, this message translates to:
  /// **'This Launch has no readable purchase info'**
  String get launch_tradeEmptyMessage;

  /// lib/features/launch/launch_trade_screen.dart:1097
  ///
  /// In en, this message translates to:
  /// **'Approval didn\'t take effect'**
  String get launch_tradeFailedOnChain;

  /// lib/features/launch/launch_trade_screen.dart:569
  ///
  /// In en, this message translates to:
  /// **'This purchase: Round {lockedRoundIndex}'**
  String launch_tradeIf(Object? lockedRoundIndex);

  /// lib/features/launch/launch_trade_screen.dart:701
  ///
  /// In en, this message translates to:
  /// **'{round}This purchase is locked; don\'t sign again. The result will appear in \"My participation\".'**
  String launch_tradeIf2(Object? round);

  /// lib/features/launch/launch_trade_screen.dart:1188
  ///
  /// In en, this message translates to:
  /// **'Network fee balance not loaded'**
  String get launch_tradeIf3;

  /// lib/features/launch/launch_trade_screen.dart:1192
  ///
  /// In en, this message translates to:
  /// **'USD1 balance not loaded'**
  String get launch_tradeIf4;

  /// lib/features/launch/launch_trade_screen.dart:1277
  ///
  /// In en, this message translates to:
  /// **'Fixed price'**
  String get launch_tradeIf5;

  /// lib/features/launch/launch_trade_screen.dart:1295
  ///
  /// In en, this message translates to:
  /// **'Raised {raisedLabel} / hard cap {hardCap}'**
  String launch_tradeIf6(Object? hardCap, Object? raisedLabel);

  /// lib/features/launch/launch_trade_screen.dart:758
  ///
  /// In en, this message translates to:
  /// **'The USD1 allowance is too low. Approve this amount first, then buy once it lands.'**
  String get launch_tradeInsufficient;

  /// lib/features/launch/launch_trade_screen.dart:485
  ///
  /// In en, this message translates to:
  /// **'Final buy quote'**
  String get launch_tradeKicker;

  /// lib/features/launch/launch_trade_screen.dart:1152
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get launch_tradeLaunchTradeAllowanceRereadLabel;

  /// lib/features/launch/launch_trade_screen.dart:423, lib/features/launch/launch_trade_screen.dart:439
  ///
  /// In en, this message translates to:
  /// **'Approve USD1 first'**
  String get launch_tradeLaunchTradeApproveLabel;

  /// lib/features/launch/launch_trade_screen.dart:437
  ///
  /// In en, this message translates to:
  /// **'Approve USD1 first, {moneyCapabilityCheckingLabel}'**
  String launch_tradeLaunchTradeApproveSemanticLabel(
    Object? moneyCapabilityCheckingLabel,
  );

  /// lib/features/launch/launch_trade_screen.dart:440
  ///
  /// In en, this message translates to:
  /// **'Approve USD1 first, not available right now'**
  String get launch_tradeLaunchTradeApproveSemanticLabel2;

  /// lib/features/launch/launch_trade_screen.dart:883
  ///
  /// In en, this message translates to:
  /// **'Includes round fee {launchMissingFigure}, USD1 balance {balance}, allowance {allowance}'**
  String launch_tradeLaunchTradeBalance(
    Object? allowance,
    Object? balance,
    Object? launchMissingFigure,
  );

  /// lib/features/launch/launch_trade_screen.dart:655
  ///
  /// In en, this message translates to:
  /// **'There\'s no sell in the bonding pool stage. After graduation and external liquidity, trading moves to Market.'**
  String get launch_tradeLaunchTradeBuyOnlyBody;

  /// lib/features/launch/launch_trade_screen.dart:654
  ///
  /// In en, this message translates to:
  /// **'Buy only until graduation'**
  String get launch_tradeLaunchTradeBuyOnlyTitle;

  /// lib/features/launch/launch_trade_screen.dart:502
  ///
  /// In en, this message translates to:
  /// **'Bonding pool purchases aren\'t available right now'**
  String get launch_tradeLaunchTradeCapabilityUnavailableTitle;

  /// lib/features/launch/launch_trade_screen.dart:1042
  ///
  /// In en, this message translates to:
  /// **'New quote'**
  String get launch_tradeLaunchTradeDiscardLabel;

  /// lib/features/launch/launch_trade_screen.dart:665
  ///
  /// In en, this message translates to:
  /// **'Fixed price and contract limits'**
  String get launch_tradeLaunchTradeFactsSummary;

  /// lib/features/launch/launch_trade_screen.dart:1214
  ///
  /// In en, this message translates to:
  /// **'Loading balance'**
  String get launch_tradeLaunchTradeFundingRereadLabel;

  /// lib/features/launch/launch_trade_screen.dart:1214
  ///
  /// In en, this message translates to:
  /// **'Reload balance'**
  String get launch_tradeLaunchTradeFundingRereadLabel2;

  /// lib/features/launch/launch_trade_screen.dart:477
  ///
  /// In en, this message translates to:
  /// **'View holders'**
  String get launch_tradeLaunchTradeHoldersActionLabel;

  /// lib/features/launch/launch_trade_screen.dart:1349
  ///
  /// In en, this message translates to:
  /// **'Round config isn\'t confirmed yet, so there\'s no price, eligibility or allowance to show.'**
  String get launch_tradeLaunchTradeNoRoundMessage;

  /// lib/features/launch/launch_trade_screen.dart:1348
  ///
  /// In en, this message translates to:
  /// **'No round to join'**
  String get launch_tradeLaunchTradeNoRoundTitle;

  /// lib/features/launch/launch_trade_screen.dart:642
  ///
  /// In en, this message translates to:
  /// **'Error code'**
  String get launch_tradeLaunchTradeRefusalCodeSummary;

  /// lib/features/launch/launch_trade_screen.dart:601
  ///
  /// In en, this message translates to:
  /// **'This purchase didn\'t go through'**
  String get launch_tradeLaunchTradeRefusalTitle;

  /// lib/features/launch/launch_trade_screen.dart:601
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t available right now'**
  String get launch_tradeLaunchTradeRefusalTitle2;

  /// lib/features/launch/launch_trade_screen.dart:468
  ///
  /// In en, this message translates to:
  /// **'Bonding pool, buy only, fee {launchMissingFigure}'**
  String launch_tradeLaunchTradeScreenSubtitle(Object? launchMissingFigure);

  /// lib/features/launch/launch_trade_screen.dart:467
  ///
  /// In en, this message translates to:
  /// **'Launch purchase'**
  String get launch_tradeLaunchTradeScreenTitle;

  /// lib/features/launch/launch_trade_screen.dart:971
  ///
  /// In en, this message translates to:
  /// **'Buy again'**
  String get launch_tradeLaunchTradeSettledDoneLabel;

  /// lib/features/launch/launch_trade_screen.dart:1049
  ///
  /// In en, this message translates to:
  /// **'Sign purchase'**
  String get launch_tradeLaunchTradeSignLabel;

  /// lib/features/launch/launch_trade_screen.dart:457
  ///
  /// In en, this message translates to:
  /// **'Buy, not available right now'**
  String get launch_tradeLaunchTradeSubmitSemanticLabel;

  /// lib/features/launch/launch_trade_screen.dart:558
  ///
  /// In en, this message translates to:
  /// **'This round'**
  String get launch_tradeLoopLabel;

  /// lib/features/launch/launch_trade_screen.dart:929
  ///
  /// In en, this message translates to:
  /// **'Review before signing'**
  String get launch_tradeLoopLabel2;

  /// lib/features/launch/launch_trade_screen.dart:737
  ///
  /// In en, this message translates to:
  /// **'On-chain status hasn\'t loaded yet. This page builds no transaction.'**
  String get launch_tradeNull;

  /// lib/features/launch/launch_trade_screen.dart:1096
  ///
  /// In en, this message translates to:
  /// **'Allowance hasn\'t updated'**
  String get launch_tradePollTimedOut;

  /// lib/features/launch/launch_trade_screen.dart:1095
  ///
  /// In en, this message translates to:
  /// **'Waiting for the approval to land'**
  String get launch_tradePolling;

  /// lib/features/launch/launch_trade_screen.dart:754
  ///
  /// In en, this message translates to:
  /// **'Loading the USD1 allowance. You can\'t buy until it loads.'**
  String get launch_tradeReading;

  /// lib/features/launch/launch_trade_screen.dart:702
  ///
  /// In en, this message translates to:
  /// **'{round}Tx {launchShortHex}. Broadcast doesn\'t mean it was filled; the on-chain index decides, and it will appear in \"My participation\".'**
  String launch_tradeS(Object? launchShortHex, Object? round);

  /// lib/features/launch/launch_trade_screen.dart:1113
  ///
  /// In en, this message translates to:
  /// **'{chainFailureReason}You can\'t buy until the allowance loads.'**
  String launch_tradeS2(Object? chainFailureReason);

  /// lib/features/launch/launch_trade_screen.dart:1189
  ///
  /// In en, this message translates to:
  /// **'Network fee balance {formatDecimal} {symbol}'**
  String launch_tradeS3(Object? formatDecimal, Object? symbol);

  /// lib/features/launch/launch_trade_screen.dart:1193
  ///
  /// In en, this message translates to:
  /// **'USD1 balance {launchUsd1Label}'**
  String launch_tradeS4(Object? launchUsd1Label);

  /// lib/features/launch/launch_trade_screen.dart:1301
  ///
  /// In en, this message translates to:
  /// **'Raise progress can\'t be loaded right now'**
  String get launch_tradeSemanticLabel;

  /// lib/features/launch/launch_trade_screen.dart:1301
  ///
  /// In en, this message translates to:
  /// **'Raise progress'**
  String get launch_tradeSemanticLabel2;

  /// lib/features/launch/launch_trade_screen.dart:1098
  ///
  /// In en, this message translates to:
  /// **'Approval not signed'**
  String get launch_tradeSignRefused;

  /// lib/features/launch/launch_trade_screen.dart:495
  ///
  /// In en, this message translates to:
  /// **'Can buy'**
  String get launch_tradeStamp;

  /// lib/features/launch/launch_trade_screen.dart:495
  ///
  /// In en, this message translates to:
  /// **'Can\'t buy'**
  String get launch_tradeStamp2;

  /// lib/features/launch/launch_trade_screen.dart:760
  ///
  /// In en, this message translates to:
  /// **'Ready to submit. The status after submitting decides the result.'**
  String get launch_tradeSufficient;

  /// lib/features/launch/launch_trade_screen.dart:734
  ///
  /// In en, this message translates to:
  /// **'Current on-chain status: {launchStateProjection}. You can only buy while the sale is in progress and not paused.'**
  String launch_tradeSwitch(Object? launchStateProjection);

  /// lib/features/launch/launch_trade_screen.dart:741
  ///
  /// In en, this message translates to:
  /// **'No payment wallet yet. Choose one in Wallet first.'**
  String get launch_tradeSwitch2;

  /// lib/features/launch/launch_trade_screen.dart:742
  ///
  /// In en, this message translates to:
  /// **'Choose a round first.'**
  String get launch_tradeSwitch3;

  /// lib/features/launch/launch_trade_screen.dart:744
  ///
  /// In en, this message translates to:
  /// **'Round {roundIndex} hasn\'t started. You can buy once it opens at {launchTimestampLabel}.'**
  String launch_tradeSwitch4(Object? launchTimestampLabel, Object? roundIndex);

  /// lib/features/launch/launch_trade_screen.dart:748
  ///
  /// In en, this message translates to:
  /// **'Round {roundIndex} ended at {launchTimestampLabel}. Choose a round in progress.'**
  String launch_tradeSwitch5(Object? launchTimestampLabel, Object? roundIndex);

  /// lib/features/launch/launch_trade_screen.dart:751
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount to pay (up to 18 decimals).'**
  String get launch_tradeSwitch6;

  /// lib/features/launch/launch_trade_screen.dart:1099
  ///
  /// In en, this message translates to:
  /// **'Preparing approval'**
  String get launch_tradeSwitch7;

  /// lib/features/launch/launch_trade_screen.dart:1111
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this wallet\'s USD1 allowance on the Launch chain. This page doesn\'t guess the allowance, so you can\'t buy yet.'**
  String get launch_tradeSwitch8;

  /// lib/features/launch/launch_trade_screen.dart:695
  ///
  /// In en, this message translates to:
  /// **'Broadcast, awaiting on-chain index'**
  String get launch_tradeTitle;

  /// lib/features/launch/launch_trade_screen.dart:697, lib/features/launch/launch_trade_screen.dart:983
  ///
  /// In en, this message translates to:
  /// **'Broadcast, {label}'**
  String launch_tradeTitle2(Object? label);

  /// lib/features/launch/launch_trade_screen.dart:1087
  ///
  /// In en, this message translates to:
  /// **'The approval wasn\'t prepared'**
  String get launch_tradeTitle3;

  /// lib/features/launch/launch_trade_screen.dart:1106
  ///
  /// In en, this message translates to:
  /// **'Loading approval status'**
  String get launch_tradeTitle4;

  /// lib/features/launch/launch_trade_screen.dart:1109
  ///
  /// In en, this message translates to:
  /// **'Approval status not loaded'**
  String get launch_tradeTitle5;

  /// lib/features/launch/launch_trade_screen.dart:1118
  ///
  /// In en, this message translates to:
  /// **'Approve USD1 first'**
  String get launch_tradeTitle6;

  /// lib/features/launch/launch_trade_screen.dart:1201
  ///
  /// In en, this message translates to:
  /// **'Add network fee first'**
  String get launch_tradeTitle7;

  /// lib/features/launch/launch_trade_screen.dart:1201
  ///
  /// In en, this message translates to:
  /// **'Add USD1 first'**
  String get launch_tradeTitle8;

  /// lib/features/launch/launch_trade_screen.dart:756
  ///
  /// In en, this message translates to:
  /// **'Approval status not loaded. This page doesn\'t guess the allowance, so you can\'t buy yet.'**
  String get launch_tradeUnread;

  /// lib/features/launch/launch_widgets.dart:699
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get launch_widgetsAdd;

  /// lib/features/launch/launch_widgets.dart:701
  ///
  /// In en, this message translates to:
  /// **'Updated {launchTimestampLabel}'**
  String launch_widgetsAdd2(Object? launchTimestampLabel);

  /// lib/features/launch/launch_widgets.dart:707
  ///
  /// In en, this message translates to:
  /// **'Review recorded {launchMissingFigure}'**
  String launch_widgetsAdd3(Object? launchMissingFigure);

  /// lib/features/launch/launch_widgets.dart:712
  ///
  /// In en, this message translates to:
  /// **'Platform-verifiable time {launchMissingFigure} (not provided by the operator)'**
  String launch_widgetsAdd4(Object? launchMissingFigure);

  /// lib/features/launch/launch_widgets.dart:715
  ///
  /// In en, this message translates to:
  /// **'Reviewer {reviewer}'**
  String launch_widgetsAdd5(Object? reviewer);

  /// lib/features/launch/launch_widgets.dart:717
  ///
  /// In en, this message translates to:
  /// **'No materials to check for this status'**
  String get launch_widgetsAdd6;

  /// lib/features/launch/launch_widgets.dart:833
  ///
  /// In en, this message translates to:
  /// **'Not registered'**
  String get launch_widgetsAddressUnregistered;

  /// lib/features/launch/launch_widgets.dart:444
  ///
  /// In en, this message translates to:
  /// **'Source {launchSourceLabel}, seen {launchTimestampLabel}'**
  String launch_widgetsBuild(
    Object? launchSourceLabel,
    Object? launchTimestampLabel,
  );

  /// lib/features/launch/launch_widgets.dart:868
  ///
  /// In en, this message translates to:
  /// **'Contract {address}'**
  String launch_widgetsBuild2(Object? address);

  /// lib/features/launch/launch_widgets.dart:1023
  ///
  /// In en, this message translates to:
  /// **'The cap applies only in the bonding pool stage and is enforced by the contract. This page writes no fixed ratio or amount; the confirmed config of this launch applies.'**
  String get launch_widgetsBuild3;

  /// lib/features/launch/launch_widgets.dart:1081
  ///
  /// In en, this message translates to:
  /// **'Round {roundIndex} per-wallet cap'**
  String launch_widgetsBuild4(Object? roundIndex);

  /// lib/features/launch/launch_widgets.dart:1124
  ///
  /// In en, this message translates to:
  /// **'The contract enforces the cap on every purchase. This is the contract\'s reading at the snapshot block, not a fixed ratio or amount LOOP wrote.'**
  String get launch_widgetsBuild5;

  /// lib/features/launch/launch_widgets.dart:402
  ///
  /// In en, this message translates to:
  /// **'LOOP directory'**
  String get launch_widgetsCatalog;

  /// lib/features/launch/launch_widgets.dart:633
  ///
  /// In en, this message translates to:
  /// **'Sale ended'**
  String get launch_widgetsEnded;

  /// lib/features/launch/launch_widgets.dart:169
  ///
  /// In en, this message translates to:
  /// **'{label}, no value. {launchMetricReasonLine}'**
  String launch_widgetsLabel(Object? label, Object? launchMetricReasonLine);

  /// lib/features/launch/launch_widgets.dart:1165
  ///
  /// In en, this message translates to:
  /// **'Bonding pool ended, raise succeeded'**
  String get launch_widgetsLabel10;

  /// lib/features/launch/launch_widgets.dart:1167
  ///
  /// In en, this message translates to:
  /// **'Bonding pool ended, soft cap not reached'**
  String get launch_widgetsLabel11;

  /// lib/features/launch/launch_widgets.dart:1169
  ///
  /// In en, this message translates to:
  /// **'Bonding pool cancelled'**
  String get launch_widgetsLabel12;

  /// lib/features/launch/launch_widgets.dart:833
  ///
  /// In en, this message translates to:
  /// **'{name}, {ticker}. {narrative}Contract {address}'**
  String launch_widgetsLabel2(
    Object? address,
    Object? name,
    Object? narrative,
    Object? ticker,
  );

  /// lib/features/launch/launch_widgets.dart:893
  ///
  /// In en, this message translates to:
  /// **'Current price'**
  String get launch_widgetsLabel3;

  /// lib/features/launch/launch_widgets.dart:894
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get launch_widgetsLabel4;

  /// lib/features/launch/launch_widgets.dart:1149, lib/features/launch/launch_widgets.dart:1156
  ///
  /// In en, this message translates to:
  /// **'Go to bonding pool trading'**
  String get launch_widgetsLabel5;

  /// lib/features/launch/launch_widgets.dart:1152
  ///
  /// In en, this message translates to:
  /// **'Bonding pool paused'**
  String get launch_widgetsLabel6;

  /// lib/features/launch/launch_widgets.dart:1158
  ///
  /// In en, this message translates to:
  /// **'Bonding pool not started'**
  String get launch_widgetsLabel7;

  /// lib/features/launch/launch_widgets.dart:1160
  ///
  /// In en, this message translates to:
  /// **'Bonding pool ended, awaiting finalization'**
  String get launch_widgetsLabel8;

  /// lib/features/launch/launch_widgets.dart:1165
  ///
  /// In en, this message translates to:
  /// **'Graduated, bonding pool closed'**
  String get launch_widgetsLabel9;

  /// lib/features/launch/launch_widgets.dart:587
  ///
  /// In en, this message translates to:
  /// **'Snapshot block {groupedFigure}, state digest {launchShortHex}'**
  String launch_widgetsLaunchAxisSnapshot(
    Object? groupedFigure,
    Object? launchShortHex,
  );

  /// lib/features/launch/launch_widgets.dart:661
  ///
  /// In en, this message translates to:
  /// **'Round cap {launchUsd1Label}, wallet cap {launchUsd1Label2}'**
  String launch_widgetsLaunchChainRoundRow(
    Object? launchUsd1Label,
    Object? launchUsd1Label2,
  );

  /// lib/features/launch/launch_widgets.dart:663
  ///
  /// In en, this message translates to:
  /// **'Raised {launchUsd1Label}'**
  String launch_widgetsLaunchChainRoundRow2(Object? launchUsd1Label);

  /// lib/features/launch/launch_widgets.dart:791
  ///
  /// In en, this message translates to:
  /// **'Launch runs on {loopTestnetBadgeLabel}, {loopLaunchTestnetChainId}; mainnet features are unaffected'**
  String launch_widgetsLaunchChainRowSemanticLabel(
    Object? loopLaunchTestnetChainId,
    Object? loopTestnetBadgeLabel,
  );

  /// lib/features/launch/launch_widgets.dart:787
  ///
  /// In en, this message translates to:
  /// **'{loopLaunchTestnetChainId}, Launch chain; wallet balances, market, swap and approvals stay on mainnet'**
  String launch_widgetsLaunchChainRowSubtitle(Object? loopLaunchTestnetChainId);

  /// lib/features/launch/launch_widgets.dart:646
  ///
  /// In en, this message translates to:
  /// **'On-chain pending'**
  String get launch_widgetsLaunchOnChainUnavailable;

  /// lib/features/launch/launch_widgets.dart:481
  ///
  /// In en, this message translates to:
  /// **'Config confirmed'**
  String get launch_widgetsLaunchPendingConfirmationLabel;

  /// lib/features/launch/launch_widgets.dart:336
  ///
  /// In en, this message translates to:
  /// **'Eligibility {pendingLabel}'**
  String launch_widgetsLaunchRoundRow(Object? pendingLabel);

  /// lib/features/launch/launch_widgets.dart:338
  ///
  /// In en, this message translates to:
  /// **'Time {pendingLabel}'**
  String launch_widgetsLaunchRoundRow2(Object? pendingLabel);

  /// lib/features/launch/launch_widgets.dart:340
  ///
  /// In en, this message translates to:
  /// **'Price {pendingLabel}'**
  String launch_widgetsLaunchRoundRow3(Object? pendingLabel);

  /// lib/features/launch/launch_widgets.dart:342
  ///
  /// In en, this message translates to:
  /// **'Cap {pendingLabel}'**
  String launch_widgetsLaunchRoundRow4(Object? pendingLabel);

  /// lib/features/launch/launch_widgets.dart:958
  ///
  /// In en, this message translates to:
  /// **'Opens {launchPendingConfirmationLabel}'**
  String launch_widgetsLaunchTrackRow(Object? launchPendingConfirmationLabel);

  /// lib/features/launch/launch_widgets.dart:405
  ///
  /// In en, this message translates to:
  /// **'LOOP ledger'**
  String get launch_widgetsLedger;

  /// lib/features/launch/launch_widgets.dart:354, lib/features/launch/launch_widgets.dart:674
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get launch_widgetsLoopBadge;

  /// lib/features/launch/launch_widgets.dart:75
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get launch_widgetsLoopOfflineState;

  /// lib/features/launch/launch_widgets.dart:75
  ///
  /// In en, this message translates to:
  /// **'Bind'**
  String get launch_widgetsLoopOfflineState2;

  /// lib/features/launch/launch_widgets.dart:80
  ///
  /// In en, this message translates to:
  /// **'This feature isn\'t available right now'**
  String get launch_widgetsMessage;

  /// lib/features/launch/launch_widgets.dart:833
  ///
  /// In en, this message translates to:
  /// **'No project summary yet. '**
  String get launch_widgetsNoNarrative;

  /// lib/features/launch/launch_widgets.dart:518
  ///
  /// In en, this message translates to:
  /// **'On-chain status pending'**
  String get launch_widgetsOnChainPending;

  /// lib/features/launch/launch_widgets.dart:336
  ///
  /// In en, this message translates to:
  /// **'Eligibility {launchTierLabel}'**
  String launch_widgetsS(Object? launchTierLabel);

  /// lib/features/launch/launch_widgets.dart:339
  ///
  /// In en, this message translates to:
  /// **'Starts {launchTimestampLabel}'**
  String launch_widgetsS2(Object? launchTimestampLabel);

  /// lib/features/launch/launch_widgets.dart:340
  ///
  /// In en, this message translates to:
  /// **'Price {priceUsd1} USD1'**
  String launch_widgetsS3(Object? priceUsd1);

  /// lib/features/launch/launch_widgets.dart:343
  ///
  /// In en, this message translates to:
  /// **'Cap {walletRoundCapRaw}'**
  String launch_widgetsS4(Object? walletRoundCapRaw);

  /// lib/features/launch/launch_widgets.dart:708
  ///
  /// In en, this message translates to:
  /// **'Review recorded {launchTimestampLabel}'**
  String launch_widgetsS5(Object? launchTimestampLabel);

  /// lib/features/launch/launch_widgets.dart:713
  ///
  /// In en, this message translates to:
  /// **'Platform-verified {launchTimestampLabel}'**
  String launch_widgetsS6(Object? launchTimestampLabel);

  /// lib/features/launch/launch_widgets.dart:959
  ///
  /// In en, this message translates to:
  /// **'Opens {launchTimestampLabel}'**
  String launch_widgetsS7(Object? launchTimestampLabel);

  /// lib/features/launch/launch_widgets.dart:363
  ///
  /// In en, this message translates to:
  /// **', selected'**
  String get launch_widgetsSelectedSuffix;

  /// lib/features/launch/launch_widgets.dart:610
  ///
  /// In en, this message translates to:
  /// **'{launchAxisLabels}, no provable on-chain status'**
  String launch_widgetsSemanticLabel(Object? launchAxisLabels);

  /// lib/features/launch/launch_widgets.dart:679
  ///
  /// In en, this message translates to:
  /// **'Round {roundIndex}, {access}, price {price}, {lines}{selected}'**
  String launch_widgetsSemanticLabel2(
    Object? access,
    Object? lines,
    Object? price,
    Object? roundIndex,
    Object? selected,
  );

  /// lib/features/launch/launch_widgets.dart:970
  ///
  /// In en, this message translates to:
  /// **'{title}, {subtitle}, fee {launchPendingConfirmationLabel}'**
  String launch_widgetsSemanticLabel3(
    Object? launchPendingConfirmationLabel,
    Object? subtitle,
    Object? title,
  );

  /// lib/features/launch/launch_widgets.dart:286
  ///
  /// In en, this message translates to:
  /// **'{subjects}: {shared}'**
  String launch_widgetsSubjectsShared(Object? shared, Object? subjects);

  /// lib/features/launch/launch_widgets.dart:919
  ///
  /// In en, this message translates to:
  /// **'Contract reading'**
  String get launch_widgetsSubtitle;

  /// lib/features/launch/launch_widgets.dart:674
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get launch_widgetsTrailingCaption;

  /// lib/features/launch/launch_widgets.dart:966
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get launch_widgetsTrailingCaption2;

  /// lib/features/launch/launch_widgets.dart:617
  ///
  /// In en, this message translates to:
  /// **'On-chain info can\'t be loaded right now, so this page shows no contract address, total supply, tax rate or cap.'**
  String get launch_widgetsUnavailable;

  /// lib/features/launch/launch_widgets.dart:474
  ///
  /// In en, this message translates to:
  /// **'Approved, awaiting schedule'**
  String get launch_widgetsUnscheduled;

  /// lib/features/notifications/community_application_notifications.dart:93
  ///
  /// In en, this message translates to:
  /// **'No reason was given. Edit the community profile and submit again.'**
  String get notifications_applicationNoReason;

  /// lib/features/notifications/community_application_notifications.dart:93
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String notifications_applicationReason(Object? reason);

  /// lib/features/notifications/community_application_notifications.dart:85
  ///
  /// In en, this message translates to:
  /// **'{subject} wasn\'t approved'**
  String notifications_applicationRejected(Object? subject);

  /// lib/features/notifications/community_application_notifications.dart:82
  ///
  /// In en, this message translates to:
  /// **'Your community'**
  String get notifications_applicationSubject;

  /// lib/features/notifications/community_application_notifications.dart:82
  ///
  /// In en, this message translates to:
  /// **'Your community \"{communityName}\"'**
  String notifications_applicationSubjectNamed(Object? communityName);

  /// lib/features/notifications/community_application_notifications.dart:84
  ///
  /// In en, this message translates to:
  /// **'{subject} was approved'**
  String notifications_applicationVerified(Object? subject);

  /// lib/features/notifications/community_application_notifications.dart:91
  ///
  /// In en, this message translates to:
  /// **'The verified badge is showing; mining weight and the official group are open.'**
  String get notifications_applicationVerifiedBody;

  /// lib/features/notifications/notification_inbox_screen.dart:280
  ///
  /// In en, this message translates to:
  /// **'Consensus badge minted'**
  String get notifications_badgeMinted;

  /// lib/features/notifications/notification_bell.dart:60
  ///
  /// In en, this message translates to:
  /// **'Notifications, {label} unread'**
  String notifications_bellUnread(Object? label);

  /// lib/features/notifications/notification_models.dart:19
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get notifications_categoryAnnouncement;

  /// lib/features/notifications/notification_models.dart:20
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get notifications_categoryCommunityAll;

  /// lib/features/notifications/notification_models.dart:20
  ///
  /// In en, this message translates to:
  /// **'Best kept off for large groups'**
  String get notifications_categoryCommunityAllDetail;

  /// lib/features/notifications/notification_models.dart:15
  ///
  /// In en, this message translates to:
  /// **'Graduations'**
  String get notifications_categoryGraduation;

  /// lib/features/notifications/notification_models.dart:14
  ///
  /// In en, this message translates to:
  /// **'Eligibility snapshots and start reminders'**
  String get notifications_categoryLaunchRound;

  /// lib/features/notifications/notification_models.dart:14
  ///
  /// In en, this message translates to:
  /// **'Includes consensus badges, launch review results and on-chain progress'**
  String get notifications_categoryLaunchRoundDetail;

  /// lib/features/notifications/notification_models.dart:18
  ///
  /// In en, this message translates to:
  /// **'Mentions of me'**
  String get notifications_categoryMention;

  /// lib/features/notifications/notification_models.dart:17
  ///
  /// In en, this message translates to:
  /// **'When off, price alerts are still recorded but no notification is sent'**
  String get notifications_categoryPriceAlertDetail;

  /// lib/features/notifications/notification_models.dart:21
  ///
  /// In en, this message translates to:
  /// **'Can\'t be turned off'**
  String get notifications_categorySecurityDetail;

  /// lib/features/notifications/notification_models.dart:9
  ///
  /// In en, this message translates to:
  /// **'Daily settlement complete'**
  String get notifications_categorySettlement;

  /// lib/features/notifications/notification_models.dart:16
  ///
  /// In en, this message translates to:
  /// **'Trade results'**
  String get notifications_categoryTradeResult;

  /// lib/features/notifications/notification_models.dart:10
  ///
  /// In en, this message translates to:
  /// **'Weight changes'**
  String get notifications_categoryWeight;

  /// lib/features/notifications/notification_models.dart:10
  ///
  /// In en, this message translates to:
  /// **'When a held token\'s Mining Weight changes'**
  String get notifications_categoryWeightDetail;

  /// lib/features/notifications/notification_inbox_screen.dart:327
  ///
  /// In en, this message translates to:
  /// **'Deployment failed'**
  String get notifications_deployFailed;

  /// lib/features/notifications/notification_inbox_screen.dart:360
  ///
  /// In en, this message translates to:
  /// **'A device session was revoked'**
  String get notifications_deviceSessionRevoked;

  /// lib/features/notifications/notification_inbox.dart:251
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notifications_earlier;

  /// lib/features/notifications/notification_inbox_screen.dart:134
  ///
  /// In en, this message translates to:
  /// **'Token graduations, badge mints, friend requests and security alerts show up here.'**
  String get notifications_emptyMessage;

  /// lib/features/notifications/notification_inbox_screen.dart:133
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifications_emptyTitle;

  /// lib/features/notifications/notification_inbox_screen.dart:299
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get notifications_friendAccepted;

  /// lib/features/notifications/notification_inbox_screen.dart:300
  ///
  /// In en, this message translates to:
  /// **'You and {name} are now friends'**
  String notifications_friendAcceptedBody(Object? name);

  /// lib/features/notifications/notification_inbox_screen.dart:293
  ///
  /// In en, this message translates to:
  /// **'New friend request'**
  String get notifications_friendRequest;

  /// lib/features/notifications/notification_inbox_screen.dart:294
  ///
  /// In en, this message translates to:
  /// **'{name} wants to add you as a friend'**
  String notifications_friendRequestBody(Object? name);

  /// lib/features/notifications/notification_inbox_screen.dart:272
  ///
  /// In en, this message translates to:
  /// **'A project you joined graduated'**
  String get notifications_graduated;

  /// lib/features/notifications/notification_inbox_screen.dart:271
  ///
  /// In en, this message translates to:
  /// **'{subject} graduated'**
  String notifications_graduatedNamed(Object? subject);

  /// lib/features/notifications/notification_inbox_screen.dart:309
  ///
  /// In en, this message translates to:
  /// **'Sign to deploy the launch'**
  String get notifications_launchApprovedBody;

  /// lib/features/notifications/notification_inbox_screen.dart:327
  ///
  /// In en, this message translates to:
  /// **'Launch deployment failed'**
  String get notifications_launchDeployFailed;

  /// lib/features/notifications/notification_inbox_screen.dart:321
  ///
  /// In en, this message translates to:
  /// **'Your launch is on-chain'**
  String get notifications_launchOnChain;

  /// lib/features/notifications/notification_inbox_screen.dart:308
  ///
  /// In en, this message translates to:
  /// **'Launch approved'**
  String get notifications_launchReviewApproved;

  /// lib/features/notifications/notification_inbox_screen.dart:314
  ///
  /// In en, this message translates to:
  /// **'Launch not approved'**
  String get notifications_launchReviewRejected;

  /// lib/features/notifications/notification_inbox_screen.dart:322
  ///
  /// In en, this message translates to:
  /// **'Sale starts {saleStartAt}'**
  String notifications_launchSaleStart(Object? saleStartAt);

  /// lib/features/notifications/notification_inbox_screen.dart:321
  ///
  /// In en, this message translates to:
  /// **'On-chain'**
  String get notifications_onChain;

  /// lib/features/notifications/notification_inbox_screen.dart:352
  ///
  /// In en, this message translates to:
  /// **'Target {threshold} · Observed {observed}'**
  String notifications_priceAlertBody(Object? observed, Object? threshold);

  /// lib/features/notifications/notification_inbox_screen.dart:347
  ///
  /// In en, this message translates to:
  /// **'Price alert triggered'**
  String get notifications_priceAlertTriggered;

  /// lib/features/notifications/notification_inbox_screen.dart:347
  ///
  /// In en, this message translates to:
  /// **'{symbol} price alert triggered'**
  String notifications_priceAlertTriggeredNamed(Object? symbol);

  /// lib/features/notifications/notification_inbox_screen.dart:106
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifications_readAll;

  /// lib/features/notifications/notification_inbox_screen.dart:203
  ///
  /// In en, this message translates to:
  /// **'All marked as read'**
  String get notifications_readAllDone;

  /// lib/features/notifications/notification_inbox_screen.dart:203
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark as read. Try again later'**
  String get notifications_readAllFailed;

  /// lib/features/notifications/notification_inbox_screen.dart:308
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get notifications_reviewApproved;

  /// lib/features/notifications/notification_inbox_screen.dart:314
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get notifications_reviewRejected;

  /// lib/features/notifications/notification_inbox_screen.dart:361, lib/features/notifications/notification_models.dart:21
  ///
  /// In en, this message translates to:
  /// **'Security event'**
  String get notifications_securityEvent;

  /// lib/features/notifications/notification_inbox_screen.dart:125
  ///
  /// In en, this message translates to:
  /// **'Choose which notifications you get'**
  String get notifications_settingsSubtitle;

  /// lib/features/notifications/notification_models.dart:315
  ///
  /// In en, this message translates to:
  /// **'Source: {factSourceLabel}'**
  String notifications_source(Object? factSourceLabel);

  /// lib/features/notifications/notification_inbox_screen.dart:99
  ///
  /// In en, this message translates to:
  /// **'{unreadCount} unread'**
  String notifications_unreadCount(Object? unreadCount);

  /// lib/features/profile/settings/settings_screen.dart:261
  ///
  /// In en, this message translates to:
  /// **'About and legal'**
  String get profileSettings_aboutAndLegal;

  /// lib/features/profile/settings/settings_screen.dart:183
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get profileSettings_appLock;

  /// lib/features/profile/settings/settings_screen.dart:83
  ///
  /// In en, this message translates to:
  /// **'This device\'s screen lock hasn\'t been read yet'**
  String get profileSettings_appLockCapabilityUnknown;

  /// lib/features/profile/settings/settings_screen.dart:85
  ///
  /// In en, this message translates to:
  /// **'{appLockFactorText} · Applies now; won\'t be remembered after the app restarts'**
  String profileSettings_appLockNotPersisted(Object? appLockFactorText);

  /// lib/features/profile/settings/settings_screen.dart:81
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get profileSettings_appLockOff;

  /// lib/features/profile/settings/settings_screen.dart:212
  ///
  /// In en, this message translates to:
  /// **'App lock, {appLockLabel}. Tap and verify to change'**
  String profileSettings_appLockSemantic(Object? appLockLabel);

  /// lib/features/profile/settings/settings_screen.dart:213
  ///
  /// In en, this message translates to:
  /// **'App lock, unavailable: {appLockDetail}'**
  String profileSettings_appLockUnavailableSemantic(Object? appLockDetail);

  /// lib/features/profile/settings/settings_screen.dart:111
  ///
  /// In en, this message translates to:
  /// **'Account settings aren\'t available right now'**
  String get profileSettings_capabilityBlocked;

  /// lib/features/profile/settings/settings_screen.dart:149
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get profileSettings_currency;

  /// lib/features/profile/settings/settings_screen.dart:69
  ///
  /// In en, this message translates to:
  /// **'Saved on this device only; never written to your account or sent to the server'**
  String get profileSettings_displaySavedLocally;

  /// lib/features/profile/settings/settings_screen.dart:70
  ///
  /// In en, this message translates to:
  /// **'Applied; saving to this device'**
  String get profileSettings_displaySaving;

  /// lib/features/profile/settings/settings_screen.dart:71
  ///
  /// In en, this message translates to:
  /// **'Applies for this session; saving on this device isn\'t available'**
  String get profileSettings_displaySessionOnly;

  /// lib/features/profile/settings/settings_screen.dart:120
  ///
  /// In en, this message translates to:
  /// **'No account settings yet'**
  String get profileSettings_empty;

  /// lib/features/profile/settings/settings_screen.dart:225
  ///
  /// In en, this message translates to:
  /// **'Theme is fixed in this version.'**
  String get profileSettings_fixedThemeNote;

  /// lib/features/profile/settings/settings_screen.dart:225
  ///
  /// In en, this message translates to:
  /// **'Currency and theme are fixed in this version.'**
  String get profileSettings_fixedValuesNote;

  /// lib/features/profile/settings/settings_screen.dart:107
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get profileSettings_general;

  /// lib/features/profile/settings/settings_screen.dart:267
  ///
  /// In en, this message translates to:
  /// **'Help and support'**
  String get profileSettings_helpAndSupport;

  /// lib/features/profile/settings/settings_screen.dart:161
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get profileSettings_reduceMotion;

  /// lib/features/profile/settings/settings_screen.dart:175
  ///
  /// In en, this message translates to:
  /// **'Reduce motion, {preferences}'**
  String profileSettings_reduceMotionSemantic(Object? preferences);

  /// lib/features/profile/settings/settings_screen.dart:238
  ///
  /// In en, this message translates to:
  /// **'Reduce motion still applies for this session. Retry only reads this device\'s storage again; it doesn\'t use your account or the server.'**
  String get profileSettings_storageUnavailableBody;

  /// lib/features/profile/settings/settings_screen.dart:237
  ///
  /// In en, this message translates to:
  /// **'Can\'t save on this device'**
  String get profileSettings_storageUnavailableTitle;

  /// lib/features/profile/settings/settings_screen.dart:155
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get profileSettings_theme;

  /// lib/features/profile/settings/settings_screen.dart:156
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get profileSettings_themeDark;

  /// lib/features/profile/settings/settings_screen.dart:282
  ///
  /// In en, this message translates to:
  /// **'Updated {relativeTime}'**
  String profileSettings_updatedAt(Object? relativeTime);

  /// lib/features/profile/settings/settings_screen.dart:281
  ///
  /// In en, this message translates to:
  /// **'Using default settings'**
  String get profileSettings_usingDefaults;

  /// lib/features/scan/scan_screen.dart:20
  ///
  /// In en, this message translates to:
  /// **'Scanning is unavailable. Turn it back on in Settings → LOOP → Camera.'**
  String get scan_cameraDeniedBody;

  /// lib/features/scan/scan_screen.dart:550
  ///
  /// In en, this message translates to:
  /// **'The camera didn\'t open. Retry, or use Photos below.'**
  String get scan_cameraErrorReason;

  /// lib/features/scan/scan_screen.dart:530
  ///
  /// In en, this message translates to:
  /// **'No camera access'**
  String get scan_cameraNoAccess;

  /// lib/features/scan/scan_screen.dart:521
  ///
  /// In en, this message translates to:
  /// **'Opening camera…'**
  String get scan_cameraOpening;

  /// lib/features/scan/scan_screen.dart:540
  ///
  /// In en, this message translates to:
  /// **'This device has no available camera'**
  String get scan_cameraUnsupported;

  /// lib/features/scan/scan_screen.dart:541
  ///
  /// In en, this message translates to:
  /// **'Use Photos below to read a QR code from an image.'**
  String get scan_cameraUnsupportedDetail;

  /// lib/features/scan/scan_screen.dart:194
  ///
  /// In en, this message translates to:
  /// **'QR code content copied'**
  String get scan_contentCopied;

  /// lib/features/scan/scan_screen.dart:296
  ///
  /// In en, this message translates to:
  /// **'Point at a LOOP profile card, invite poster, community QR code or wallet address QR code.'**
  String get scan_hint;

  /// lib/features/scan/scan_screen.dart:175
  ///
  /// In en, this message translates to:
  /// **'No QR code found in this image'**
  String get scan_imageNoCode;

  /// lib/features/scan/scan_screen.dart:181
  ///
  /// In en, this message translates to:
  /// **'No photo access. Allow LOOP to access Photos in Settings, then try again'**
  String get scan_imageNoPhotoAccess;

  /// lib/features/scan/scan_screen.dart:187
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the image. Try another one'**
  String get scan_imageUnreadable;

  /// lib/features/scan/scan_screen.dart:634
  ///
  /// In en, this message translates to:
  /// **'Keep scanning'**
  String get scan_keepScanning;

  /// lib/features/scan/scan_screen.dart:314
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get scan_pickImageLabel;

  /// lib/features/scan/scan_screen.dart:314
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get scan_pickImageReading;

  /// lib/features/scan/scan_screen.dart:315
  ///
  /// In en, this message translates to:
  /// **'Choose from Photos'**
  String get scan_pickImageSemantic;

  /// lib/features/scan/scan_screen.dart:325
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get scan_torch;

  /// lib/features/scan/scan_screen.dart:325
  ///
  /// In en, this message translates to:
  /// **'Turn off flashlight'**
  String get scan_torchOff;

  /// lib/features/scan/scan_screen.dart:210
  ///
  /// In en, this message translates to:
  /// **'Scanning isn\'t available right now'**
  String get scan_unavailable;

  /// lib/features/scan/scan_screen.dart:211
  ///
  /// In en, this message translates to:
  /// **'This build doesn\'t include camera scanning; this page won\'t open the camera.'**
  String get scan_unavailableDetail;

  /// lib/features/scan/scan_screen.dart:612
  ///
  /// In en, this message translates to:
  /// **'LOOP won\'t open this content; it\'s only shown below.'**
  String get scan_unknownBody;

  /// lib/features/scan/scan_screen.dart:611
  ///
  /// In en, this message translates to:
  /// **'Not a LOOP QR code'**
  String get scan_unknownTitle;

  /// lib/features/security/app_lock/app_lock_controller.dart:177
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to turn on App lock'**
  String get securityAppLock_controllerReason;

  /// lib/features/security/app_lock/app_lock_controller.dart:177
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to turn off App lock'**
  String get securityAppLock_controllerReason2;

  /// lib/features/security/app_lock/app_lock_controller.dart:202
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to open LOOP'**
  String get securityAppLock_controllerReason3;

  /// lib/features/security/app_lock/app_lock_gate.dart:35
  ///
  /// In en, this message translates to:
  /// **'Unlock with this device\'s biometrics; falls back to the device passcode if not recognized'**
  String get securityAppLock_gateBiometric;

  /// lib/features/security/app_lock/app_lock_gate.dart:23
  ///
  /// In en, this message translates to:
  /// **'You cancelled this verification.'**
  String get securityAppLock_gateCanceled;

  /// lib/features/security/app_lock/app_lock_gate.dart:36
  ///
  /// In en, this message translates to:
  /// **'Unlock with this device\'s screen lock passcode'**
  String get securityAppLock_gateDeviceCredential;

  /// lib/features/security/app_lock/app_lock_gate.dart:22
  ///
  /// In en, this message translates to:
  /// **'Verification didn\'t pass. Try again.'**
  String get securityAppLock_gateFailed;

  /// lib/features/security/app_lock/app_lock_gate.dart:24
  ///
  /// In en, this message translates to:
  /// **'The system has paused verification for now. Wait a moment and try again, or use the device passcode.'**
  String get securityAppLock_gateLockedOut;

  /// lib/features/security/app_lock/app_lock_gate.dart:112, lib/features/security/app_lock/app_lock_prompt.dart:234
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get securityAppLock_gateLoopAppLockUnlockLabel;

  /// lib/features/security/app_lock/app_lock_gate.dart:112
  ///
  /// In en, this message translates to:
  /// **'Verify identity'**
  String get securityAppLock_gateLoopAppLockUnlockLabel2;

  /// lib/features/security/app_lock/app_lock_gate.dart:100, lib/features/security/app_lock/app_lock_gate.dart:103
  ///
  /// In en, this message translates to:
  /// **'LOOP is locked'**
  String get securityAppLock_gateLoopAppLockUnlockSemanticLabel;

  /// lib/features/security/app_lock/app_lock_gate.dart:39
  ///
  /// In en, this message translates to:
  /// **'This device has no screen lock passcode or biometrics yet. Add one in system Settings first'**
  String get securityAppLock_gateNoCredentialSet;

  /// lib/features/security/app_lock/app_lock_gate.dart:29
  ///
  /// In en, this message translates to:
  /// **'Verification didn\'t finish · System message: {systemMessage}'**
  String securityAppLock_gateS(Object? systemMessage);

  /// lib/features/security/app_lock/app_lock_gate.dart:21
  ///
  /// In en, this message translates to:
  /// **'Verified.'**
  String get securityAppLock_gateSucceeded;

  /// lib/features/security/app_lock/app_lock_gate.dart:28
  ///
  /// In en, this message translates to:
  /// **'Verification didn\'t finish.'**
  String get securityAppLock_gateSwitch;

  /// lib/features/security/app_lock/app_lock_gate.dart:41
  ///
  /// In en, this message translates to:
  /// **'Haven\'t read this device\'s screen lock capability yet'**
  String get securityAppLock_gateSwitch2;

  /// lib/features/security/app_lock/app_lock_gate.dart:25
  ///
  /// In en, this message translates to:
  /// **'This device has no screen lock verification available right now.'**
  String get securityAppLock_gateUnavailable;

  /// lib/features/security/app_lock/app_lock_gate.dart:40
  ///
  /// In en, this message translates to:
  /// **'This device doesn\'t support screen lock verification'**
  String get securityAppLock_gateUnsupportedPlatform;

  /// lib/features/security/app_lock/app_lock_prompt.dart:234
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get securityAppLock_promptAppLockPromptEnableLabel;

  /// lib/features/security/app_lock/app_lock_prompt.dart:244
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get securityAppLock_promptAppLockPromptLaterLabel;

  /// lib/features/security/app_lock/app_lock_prompt.dart:15
  ///
  /// In en, this message translates to:
  /// **'Require Face ID / fingerprint when you return after 60 seconds in the background, keeping your wallet and chats safer'**
  String get securityAppLock_promptLoopAppLockPromptBody;

  /// lib/features/security/app_lock/app_lock_prompt.dart:211
  ///
  /// In en, this message translates to:
  /// **'Turn on App lock'**
  String get securityAppLock_promptLoopSheetHeading;

  /// lib/features/security/mfa/mfa_controller.dart:349
  ///
  /// In en, this message translates to:
  /// **'Verify your identity once before unlinking the passkey'**
  String get securityMfa_controllerConfirmOwnerPresent;

  /// lib/features/security/mfa/mfa_models.dart:10
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get securityMfa_modelsSms;

  /// lib/features/security/mfa/mfa_models.dart:9, lib/features/security/mfa/mfa_sheet.dart:101
  ///
  /// In en, this message translates to:
  /// **'Authenticator app'**
  String get securityMfa_modelsTotp;

  /// lib/features/security/mfa/passkey_sheet.dart:70
  ///
  /// In en, this message translates to:
  /// **'The passkey is kept by this device\'s system; the login service only records its public key. On a new phone, a passkey synced through the same system account gets you back in.'**
  String get securityMfa_passkeySheetBuild;

  /// lib/features/security/mfa/passkey_sheet.dart:85
  ///
  /// In en, this message translates to:
  /// **'This didn\'t finish'**
  String get securityMfa_passkeySheetCancelled;

  /// lib/features/security/mfa/passkey_sheet.dart:151
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get securityMfa_passkeySheetLoopLabel;

  /// lib/features/security/mfa/passkey_sheet.dart:186
  ///
  /// In en, this message translates to:
  /// **'The device verifies your identity once before unlinking. The passkey stored in the system is managed by the system; LOOP can\'t delete it, the login service just stops accepting it.'**
  String get securityMfa_passkeySheetPasskeySheetConfirmBody;

  /// lib/features/security/mfa/passkey_sheet.dart:185
  ///
  /// In en, this message translates to:
  /// **'After unlinking, this way back is gone'**
  String get securityMfa_passkeySheetPasskeySheetConfirmTitle;

  /// lib/features/security/mfa/passkey_sheet.dart:147
  ///
  /// In en, this message translates to:
  /// **'Once linked, this device\'s face or fingerprint is a separate way back in.'**
  String get securityMfa_passkeySheetPasskeySheetEmptyMessage;

  /// lib/features/security/mfa/passkey_sheet.dart:146
  ///
  /// In en, this message translates to:
  /// **'This account has no passkey yet'**
  String get securityMfa_passkeySheetPasskeySheetEmptyTitle;

  /// lib/features/security/mfa/passkey_sheet.dart:208
  ///
  /// In en, this message translates to:
  /// **'Link passkey'**
  String get securityMfa_passkeySheetPasskeySheetLinkLabel;

  /// lib/features/security/mfa/passkey_sheet.dart:209
  ///
  /// In en, this message translates to:
  /// **'Link another passkey'**
  String get securityMfa_passkeySheetPasskeySheetLinkLabel2;

  /// lib/features/security/mfa/passkey_sheet.dart:135
  ///
  /// In en, this message translates to:
  /// **'No response from the login service yet'**
  String get securityMfa_passkeySheetPasskeySheetUnknownTitle;

  /// lib/features/security/mfa/passkey_sheet.dart:191
  ///
  /// In en, this message translates to:
  /// **'Unlinking…'**
  String get securityMfa_passkeySheetPasskeySheetUnlinkLabel;

  /// lib/features/security/mfa/passkey_sheet.dart:191
  ///
  /// In en, this message translates to:
  /// **'Confirm unlink'**
  String get securityMfa_passkeySheetPasskeySheetUnlinkLabel2;

  /// lib/features/security/mfa/passkey_sheet.dart:174
  ///
  /// In en, this message translates to:
  /// **'{passkey}, set up, tap to unlink'**
  String securityMfa_passkeySheetSemanticLabel(Object? passkey);

  /// lib/features/security/mfa/passkey_sheet.dart:158
  ///
  /// In en, this message translates to:
  /// **'Also used for two-step verification'**
  String get securityMfa_passkeySheetSubtitle;

  /// lib/features/security/mfa/passkey_sheet.dart:158
  ///
  /// In en, this message translates to:
  /// **'Used for sign-in and recovery'**
  String get securityMfa_passkeySheetSubtitle2;

  /// lib/features/security/mfa/passkey_sheet.dart:221
  ///
  /// In en, this message translates to:
  /// **'The login service hasn\'t responded during this session yet.'**
  String get securityMfa_passkeySheetText;

  /// lib/features/security/mfa/passkey_sheet.dart:157
  ///
  /// In en, this message translates to:
  /// **'Passkeys on this account'**
  String get securityMfa_passkeySheetTitle;

  /// lib/features/security/mfa/passkey_sheet.dart:159
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get securityMfa_passkeySheetTrailing;

  /// lib/features/security/mfa/mfa_sheet.dart:85
  ///
  /// In en, this message translates to:
  /// **'Both methods are kept by the login service. LOOP doesn\'t store the secret key or the passkey.'**
  String get securityMfa_sheetBuild;

  /// lib/features/security/mfa/mfa_sheet.dart:104
  ///
  /// In en, this message translates to:
  /// **'Once turned off, the login service won\'t ask you for a code when it requires two-step verification.'**
  String get securityMfa_sheetBuild2;

  /// lib/features/security/mfa/mfa_sheet.dart:24
  ///
  /// In en, this message translates to:
  /// **'System verification didn\'t finish. Nothing was changed.'**
  String get securityMfa_sheetCancelled;

  /// lib/features/security/mfa/mfa_sheet.dart:25
  ///
  /// In en, this message translates to:
  /// **'This device has no passkey available; the system offers no place to create one.'**
  String get securityMfa_sheetDeviceUnsupported;

  /// lib/features/security/mfa/mfa_sheet.dart:28
  ///
  /// In en, this message translates to:
  /// **'The code is wrong or has expired. Enter it again.'**
  String get securityMfa_sheetInvalidCode;

  /// lib/features/security/mfa/mfa_sheet.dart:166
  ///
  /// In en, this message translates to:
  /// **'Manual entry key'**
  String get securityMfa_sheetLoopLabel;

  /// lib/features/security/mfa/mfa_sheet.dart:186
  ///
  /// In en, this message translates to:
  /// **'6-digit code from your authenticator'**
  String get securityMfa_sheetLoopLabel2;

  /// lib/features/security/mfa/mfa_sheet.dart:42
  ///
  /// In en, this message translates to:
  /// **'LOOP needs domain credentials for passkeys first; this version doesn\'t have them yet'**
  String get securityMfa_sheetLoopPasskeyDomainPending;

  /// lib/features/security/mfa/mfa_sheet.dart:136
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get securityMfa_sheetMessage;

  /// lib/features/security/mfa/mfa_sheet.dart:154
  ///
  /// In en, this message translates to:
  /// **'Get key'**
  String get securityMfa_sheetMfaSheetBeginLabel;

  /// lib/features/security/mfa/mfa_sheet.dart:95
  ///
  /// In en, this message translates to:
  /// **'The login service hasn\'t enabled MFA yet'**
  String get securityMfa_sheetMfaSheetFailureTitle;

  /// lib/features/security/mfa/mfa_sheet.dart:96, lib/features/security/mfa/passkey_sheet.dart:86
  ///
  /// In en, this message translates to:
  /// **'This step didn\'t finish'**
  String get securityMfa_sheetMfaSheetFailureTitle2;

  /// lib/features/security/mfa/mfa_sheet.dart:250, lib/features/security/mfa/passkey_sheet.dart:206
  ///
  /// In en, this message translates to:
  /// **'Waiting for system verification…'**
  String get securityMfa_sheetMfaSheetPasskeyLabel;

  /// lib/features/security/mfa/mfa_sheet.dart:252
  ///
  /// In en, this message translates to:
  /// **'Turn off passkey verification'**
  String get securityMfa_sheetMfaSheetPasskeyLabel2;

  /// lib/features/security/mfa/mfa_sheet.dart:253
  ///
  /// In en, this message translates to:
  /// **'Use passkey for two-step verification'**
  String get securityMfa_sheetMfaSheetPasskeyLabel3;

  /// lib/features/security/mfa/mfa_sheet.dart:239
  ///
  /// In en, this message translates to:
  /// **'On · Passkey. When the login service requires two-step verification, the system shows a passkey prompt.'**
  String get securityMfa_sheetMfaSheetPasskeyStatus;

  /// lib/features/security/mfa/mfa_sheet.dart:241
  ///
  /// In en, this message translates to:
  /// **'This account already has a passkey; you can also use it for two-step verification.'**
  String get securityMfa_sheetMfaSheetPasskeyStatus2;

  /// lib/features/security/mfa/mfa_sheet.dart:242
  ///
  /// In en, this message translates to:
  /// **'Create a passkey on this device and use it as your two-step verification method.'**
  String get securityMfa_sheetMfaSheetPasskeyStatus3;

  /// lib/features/security/mfa/mfa_sheet.dart:228, lib/features/security/mfa/passkey_sheet.dart:84, lib/features/security/mfa/passkey_sheet.dart:111
  ///
  /// In en, this message translates to:
  /// **'Passkey not available right now'**
  String get securityMfa_sheetMfaSheetPasskeyUnavailableTitle;

  /// lib/features/security/mfa/mfa_sheet.dart:271
  ///
  /// In en, this message translates to:
  /// **'Turning off…'**
  String get securityMfa_sheetMfaSheetRemoveLabel;

  /// lib/features/security/mfa/mfa_sheet.dart:271
  ///
  /// In en, this message translates to:
  /// **'Turn off MFA'**
  String get securityMfa_sheetMfaSheetRemoveLabel2;

  /// lib/features/security/mfa/mfa_sheet.dart:204
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get securityMfa_sheetMfaSheetSubmitLabel;

  /// lib/features/security/mfa/mfa_sheet.dart:205
  ///
  /// In en, this message translates to:
  /// **'Verify and turn on'**
  String get securityMfa_sheetMfaSheetSubmitLabel2;

  /// lib/features/security/mfa/mfa_sheet.dart:80
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get securityMfa_sheetMfaSheetTitle;

  /// lib/features/security/mfa/mfa_sheet.dart:27
  ///
  /// In en, this message translates to:
  /// **'Your sign-in has expired. Sign in again and retry.'**
  String get securityMfa_sheetNotAuthenticated;

  /// lib/features/security/mfa/mfa_sheet.dart:26
  ///
  /// In en, this message translates to:
  /// **'The login service hasn\'t enabled MFA yet. This isn\'t a problem with this device or your account.'**
  String get securityMfa_sheetNotEnabled;

  /// lib/features/security/mfa/mfa_sheet.dart:24
  ///
  /// In en, this message translates to:
  /// **'LOOP needs domain credentials for passkeys first; this version doesn\'t have them yet.'**
  String get securityMfa_sheetPasskeyDomainUnconfigured;

  /// lib/features/security/mfa/mfa_sheet.dart:29
  ///
  /// In en, this message translates to:
  /// **'This didn\'t finish.'**
  String get securityMfa_sheetRejected;

  /// lib/features/security/mfa/mfa_sheet.dart:105
  ///
  /// In en, this message translates to:
  /// **'An authenticator app generates 6-digit codes on your phone, such as Google Authenticator, Microsoft Authenticator or 1Password. Scan the code or enter the key with it. The key is issued by the login service; LOOP doesn\'t store it.'**
  String get securityMfa_sheetS;

  /// lib/features/security/mfa/mfa_sheet.dart:30
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the login service right now.'**
  String get securityMfa_sheetUnavailable;

  /// lib/features/security/mfa/mfa_sheet.dart:31
  ///
  /// In en, this message translates to:
  /// **'Didn\'t finish; the login service gave no reason.'**
  String get securityMfa_sheetUnknown;

  /// lib/features/security/step_up/step_up_controller.dart:190
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to turn on large-amount verification'**
  String get securityStepUp_controllerAsk;

  /// lib/features/security/step_up/step_up_controller.dart:205
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to raise the large-amount verification threshold'**
  String get securityStepUp_controllerAsk2;

  /// lib/features/security/step_up/step_up_controller.dart:263
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to sign this large transaction'**
  String get securityStepUp_controllerAsk3;

  /// lib/features/security/step_up/step_up_controller.dart:285
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to sign this request'**
  String get securityStepUp_controllerAsk4;

  /// lib/features/security/step_up/step_up_controller.dart:190
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to turn off large-amount verification'**
  String get securityStepUp_controllerS;

  /// lib/features/security/step_up/step_up_models.dart:141
  ///
  /// In en, this message translates to:
  /// **'Amount must be between 1 and 1,000,000 USD1'**
  String get securityStepUp_modelsIf;

  /// lib/features/security/step_up/step_up_models.dart:58
  ///
  /// In en, this message translates to:
  /// **'Approval sent; the transaction wasn\'t started.'**
  String get securityStepUp_modelsLoopStepUpAfterApprovalText;

  /// lib/features/security/step_up/step_up_models.dart:167
  ///
  /// In en, this message translates to:
  /// **'Verify again at {stepUpThresholdLabel} USD1 or more'**
  String securityStepUp_modelsLoopStepUpSubtitle(Object? stepUpThresholdLabel);

  /// lib/features/security/step_up/step_up_models.dart:138
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get securityStepUp_modelsLoopStepUpThresholdError;

  /// lib/features/security/step_up/step_up_models.dart:63
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing was changed.'**
  String get securityStepUp_modelsSwitch;

  /// lib/features/security/step_up/step_up_models.dart:64
  ///
  /// In en, this message translates to:
  /// **'Identity verification didn\'t pass. Nothing was changed.'**
  String get securityStepUp_modelsSwitch2;

  /// lib/features/security/step_up/step_up_widgets.dart:56
  ///
  /// In en, this message translates to:
  /// **'Confirm in your wallet'**
  String get securityStepUp_widgetsActive;

  /// lib/features/security/step_up/step_up_widgets.dart:303
  ///
  /// In en, this message translates to:
  /// **'Valid this time only; not remembered after reopening the app'**
  String get securityStepUp_widgetsBuild;

  /// lib/features/security/step_up/step_up_widgets.dart:437
  ///
  /// In en, this message translates to:
  /// **'When a signed amount reaches or exceeds this value, this device verifies your identity first.'**
  String get securityStepUp_widgetsBuild2;

  /// lib/features/security/step_up/step_up_widgets.dart:39
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get securityStepUp_widgetsDone;

  /// lib/features/security/step_up/step_up_widgets.dart:422
  ///
  /// In en, this message translates to:
  /// **'Verification didn\'t pass. The amount wasn\'t changed.'**
  String get securityStepUp_widgetsError;

  /// lib/features/security/step_up/step_up_widgets.dart:59
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get securityStepUp_widgetsFailed;

  /// lib/features/security/step_up/step_up_widgets.dart:454
  ///
  /// In en, this message translates to:
  /// **'e.g. 1000'**
  String get securityStepUp_widgetsHint;

  /// lib/features/security/step_up/step_up_widgets.dart:46
  ///
  /// In en, this message translates to:
  /// **'Verify identity'**
  String get securityStepUp_widgetsLabel;

  /// lib/features/security/step_up/step_up_widgets.dart:328
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get securityStepUp_widgetsLoopBadge;

  /// lib/features/security/step_up/step_up_widgets.dart:434
  ///
  /// In en, this message translates to:
  /// **'Large-amount verification threshold'**
  String get securityStepUp_widgetsLoopSheetHeading;

  /// lib/features/security/step_up/step_up_widgets.dart:38
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get securityStepUp_widgetsRefreshing;

  /// lib/features/security/step_up/step_up_widgets.dart:57
  ///
  /// In en, this message translates to:
  /// **'Refreshing quote'**
  String get securityStepUp_widgetsRefreshing2;

  /// lib/features/security/step_up/step_up_widgets.dart:97
  ///
  /// In en, this message translates to:
  /// **'Signing and broadcasting'**
  String get securityStepUp_widgetsS;

  /// lib/features/security/step_up/step_up_widgets.dart:341
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get securityStepUp_widgetsSX;

  /// lib/features/security/step_up/step_up_widgets.dart:355
  ///
  /// In en, this message translates to:
  /// **'{stepUpSubtitle}. Tap this row to change the amount.'**
  String securityStepUp_widgetsSecurityStepUpInfoBodyBody(
    Object? stepUpSubtitle,
  );

  /// lib/features/security/step_up/step_up_widgets.dart:339
  ///
  /// In en, this message translates to:
  /// **'{stepUpTitle}, unavailable: {capability}'**
  String securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel(
    Object? capability,
    Object? stepUpTitle,
  );

  /// lib/features/security/step_up/step_up_widgets.dart:340
  ///
  /// In en, this message translates to:
  /// **'{stepUpTitle}, {on}, {base}, tap to change the amount'**
  String securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel2(
    Object? base,
    Object? on,
    Object? stepUpTitle,
  );

  /// lib/features/security/step_up/step_up_widgets.dart:249
  ///
  /// In en, this message translates to:
  /// **'{stepUpTitle}, unavailable: no device verification available in this session'**
  String securityStepUp_widgetsSemanticLabel(Object? stepUpTitle);

  /// lib/features/security/step_up/step_up_widgets.dart:97
  ///
  /// In en, this message translates to:
  /// **'Verifying identity'**
  String get securityStepUp_widgetsStepUpSigningTitle;

  /// lib/features/security/step_up/step_up_widgets.dart:441
  ///
  /// In en, this message translates to:
  /// **'Whole number, 1 to 1,000,000'**
  String get securityStepUp_widgetsStepUpThresholdFieldFootnote;

  /// lib/features/security/step_up/step_up_widgets.dart:440
  ///
  /// In en, this message translates to:
  /// **'Amount (USD1)'**
  String get securityStepUp_widgetsStepUpThresholdFieldLabel;

  /// lib/features/security/step_up/step_up_widgets.dart:212
  ///
  /// In en, this message translates to:
  /// **'Large-amount verification'**
  String get securityStepUp_widgetsStepUpTitle;

  /// lib/features/security/step_up/step_up_widgets.dart:244
  ///
  /// In en, this message translates to:
  /// **'No device verification available in this session'**
  String get securityStepUp_widgetsSubtitle;

  /// lib/features/security/step_up/step_up_widgets.dart:60
  ///
  /// In en, this message translates to:
  /// **'Result unknown'**
  String get securityStepUp_widgetsUnknown;

  /// lib/features/security/step_up/step_up_widgets.dart:37, lib/features/security/step_up/step_up_widgets.dart:49
  ///
  /// In en, this message translates to:
  /// **'Pending verification'**
  String get securityStepUp_widgetsWaiting;

  /// lib/features/shell/loop_pending_surface.dart:27
  ///
  /// In en, this message translates to:
  /// **'Pay isn\'t available'**
  String get shell_payUnavailableHeadline;

  /// lib/features/shell/loop_pending_surface.dart:32
  ///
  /// In en, this message translates to:
  /// **'Pay isn\'t open yet. This page doesn\'t scan codes, ask for camera access, collect payment details or submit any transaction.'**
  String get shell_payUnavailableMessage;

  /// lib/features/shell/loop_pending_surface.dart:59
  ///
  /// In en, this message translates to:
  /// **'Back to community'**
  String get shell_pendingBackToCommunity;

  /// lib/features/shell/loop_pending_surface.dart:26
  ///
  /// In en, this message translates to:
  /// **'This page isn\'t open yet'**
  String get shell_pendingHeadline;

  /// lib/features/shell/loop_pending_surface.dart:112
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" isn\'t open yet. Nothing is shown here and no action can be taken.'**
  String shell_pendingMessage(Object? title);

  /// lib/features/shell/loop_pending_surface.dart:34
  ///
  /// In en, this message translates to:
  /// **'Module: {label}'**
  String shell_pendingSourceLine(Object? label);

  /// lib/features/shell/loop_shell.dart:55
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get shell_tabChat;

  /// lib/features/shell/loop_shell.dart:58
  ///
  /// In en, this message translates to:
  /// **'Intel'**
  String get shell_tabIntel;

  /// lib/features/shell/loop_shell.dart:59
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get shell_tabMe;

  /// lib/features/shell/loop_shell.dart:736
  ///
  /// In en, this message translates to:
  /// **'{label}, new messages'**
  String shell_tabNewMessages(Object? label);

  /// lib/features/shell/loop_shell.dart:56
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get shell_tabSquare;

  /// lib/features/social/public_profile/public_profile_controller.dart:549
  ///
  /// In en, this message translates to:
  /// **'You\'re already friends.'**
  String get socialPublicProfile_controllerAlreadyFriends;

  /// lib/features/social/public_profile/public_profile_controller.dart:517
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get socialPublicProfile_controllerCommand;

  /// lib/features/social/public_profile/public_profile_controller.dart:525
  ///
  /// In en, this message translates to:
  /// **'Friend removed'**
  String get socialPublicProfile_controllerCommand2;

  /// lib/features/social/public_profile/public_profile_controller.dart:537
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get socialPublicProfile_controllerCommand3;

  /// lib/features/social/public_profile/public_profile_controller.dart:552
  ///
  /// In en, this message translates to:
  /// **'Recently declined. Try again later.'**
  String get socialPublicProfile_controllerCooldown;

  /// lib/features/social/public_profile/public_profile_controller.dart:551
  ///
  /// In en, this message translates to:
  /// **'They\'ve sent you a request. Handle it in Friend requests.'**
  String get socialPublicProfile_controllerIncomingRequestPending;

  /// lib/features/social/public_profile/public_profile_controller.dart:556
  ///
  /// In en, this message translates to:
  /// **'User not found.'**
  String get socialPublicProfile_controllerNotFound;

  /// lib/features/social/public_profile/public_profile_controller.dart:558
  ///
  /// In en, this message translates to:
  /// **'Result not confirmed. Refresh to check; don\'t resubmit.'**
  String get socialPublicProfile_controllerOutcomeUnknown;

  /// lib/features/social/public_profile/public_profile_controller.dart:550
  ///
  /// In en, this message translates to:
  /// **'Request already sent, waiting for them.'**
  String get socialPublicProfile_controllerOutgoingRequestPending;

  /// lib/features/social/public_profile/public_profile_controller.dart:553
  ///
  /// In en, this message translates to:
  /// **'They don\'t accept friend requests.'**
  String get socialPublicProfile_controllerPermissionDenied;

  /// lib/features/social/public_profile/public_profile_controller.dart:555
  ///
  /// In en, this message translates to:
  /// **'Activate your LOOP ID first.'**
  String get socialPublicProfile_controllerProfileRequired;

  /// lib/features/social/public_profile/public_profile_controller.dart:554
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get socialPublicProfile_controllerRateLimited;

  /// lib/features/social/public_profile/public_profile_controller.dart:493
  ///
  /// In en, this message translates to:
  /// **'Unfollowed'**
  String get socialPublicProfile_controllerS;

  /// lib/features/social/public_profile/public_profile_controller.dart:537
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get socialPublicProfile_controllerS2;

  /// lib/features/social/public_profile/public_profile_controller.dart:559
  ///
  /// In en, this message translates to:
  /// **'Friend request not sent. Try again later.'**
  String get socialPublicProfile_controllerSwitch;

  /// lib/features/social/public_profile/public_profile_controller.dart:557
  ///
  /// In en, this message translates to:
  /// **'The friend service isn\'t available right now; no request was sent.'**
  String get socialPublicProfile_controllerUnavailable;

  /// lib/features/social/public_profile/public_profile_models.dart:299
  ///
  /// In en, this message translates to:
  /// **'Transfer in'**
  String get socialPublicProfile_modelsTransferIn;

  /// lib/features/social/public_profile/public_profile_models.dart:300
  ///
  /// In en, this message translates to:
  /// **'Transfer out'**
  String get socialPublicProfile_modelsTransferOut;

  /// lib/features/social/public_profile/user_profile_screen.dart:364
  ///
  /// In en, this message translates to:
  /// **'After removing, you\'re no longer friends; direct message history is kept. You can send a request again later.'**
  String get socialPublicProfile_userBody;

  /// lib/features/social/public_profile/user_profile_screen.dart:373
  ///
  /// In en, this message translates to:
  /// **'After blocking, they can\'t see your profile or send you messages or friend requests. You can unblock in Block list.'**
  String get socialPublicProfile_userBody2;

  /// lib/features/social/public_profile/user_profile_screen.dart:551
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get socialPublicProfile_userCountCommunities;

  /// lib/features/social/public_profile/user_profile_screen.dart:551
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get socialPublicProfile_userCountFollowing;

  /// lib/features/social/public_profile/user_profile_screen.dart:696
  ///
  /// In en, this message translates to:
  /// **'On-chain data isn\'t available right now; 0 isn\'t shown in its place.'**
  String get socialPublicProfile_userDetail;

  /// lib/features/social/public_profile/user_profile_screen.dart:599
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get socialPublicProfile_userFriends;

  /// lib/features/social/public_profile/user_profile_screen.dart:666
  ///
  /// In en, this message translates to:
  /// **'Holdings not public'**
  String get socialPublicProfile_userHoldingsHidden;

  /// lib/features/social/public_profile/user_profile_screen.dart:666
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load holdings right now'**
  String get socialPublicProfile_userHoldingsUnavailable;

  /// lib/features/social/public_profile/user_profile_screen.dart:826
  ///
  /// In en, this message translates to:
  /// **'Launch chain'**
  String get socialPublicProfile_userLaunch2Row;

  /// lib/features/social/public_profile/user_profile_screen.dart:1036
  ///
  /// In en, this message translates to:
  /// **'Block #{block}'**
  String socialPublicProfile_userLoopRecordRow(Object? block);

  /// lib/features/social/public_profile/user_profile_screen.dart:1128
  ///
  /// In en, this message translates to:
  /// **'{formatDecimal} members'**
  String socialPublicProfile_userMembers(Object? formatDecimal);

  /// lib/features/social/public_profile/user_profile_screen.dart:596
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get socialPublicProfile_userNone;

  /// lib/features/social/public_profile/user_profile_screen.dart:1127
  ///
  /// In en, this message translates to:
  /// **'1 member'**
  String get socialPublicProfile_userOneMember;

  /// lib/features/social/public_profile/user_profile_screen.dart:598
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get socialPublicProfile_userPendingIn;

  /// lib/features/social/public_profile/user_profile_screen.dart:597
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get socialPublicProfile_userPendingOut;

  /// lib/features/social/public_profile/user_profile_screen.dart:827
  ///
  /// In en, this message translates to:
  /// **'Launch chain, {launch2StageLabel}'**
  String socialPublicProfile_userS(Object? launch2StageLabel);

  /// lib/features/social/public_profile/user_profile_screen.dart:769
  ///
  /// In en, this message translates to:
  /// **'Total holdings'**
  String get socialPublicProfile_userSwitch;

  /// lib/features/social/public_profile/user_profile_screen.dart:781
  ///
  /// In en, this message translates to:
  /// **'Loaded {localTimestampLabel}'**
  String socialPublicProfile_userSwitch2(Object? localTimestampLabel);

  /// lib/features/social/public_profile/user_profile_screen.dart:363
  ///
  /// In en, this message translates to:
  /// **'Remove friend?'**
  String get socialPublicProfile_userTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:372
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}?'**
  String socialPublicProfile_userTitle2(Object? displayName);

  /// lib/features/social/public_profile/user_profile_screen.dart:690
  ///
  /// In en, this message translates to:
  /// **'No wallet yet'**
  String get socialPublicProfile_userTitle4;

  /// lib/features/social/public_profile/user_profile_screen.dart:666
  ///
  /// In en, this message translates to:
  /// **'Trades not public'**
  String get socialPublicProfile_userTradesHidden;

  /// lib/features/social/public_profile/user_profile_screen.dart:666
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load trades right now'**
  String get socialPublicProfile_userTradesUnavailable;

  /// lib/features/social/public_profile/user_profile_screen.dart:326
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get socialPublicProfile_userUserProfileBlockLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:326, lib/features/social/public_profile/user_profile_screen.dart:374
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get socialPublicProfile_userUserProfileBlockLabel2;

  /// lib/features/social/public_profile/user_profile_screen.dart:640
  ///
  /// In en, this message translates to:
  /// **'They can\'t send you messages or friend requests, and you can\'t see their holdings or trades.'**
  String get socialPublicProfile_userUserProfileBlockedBody;

  /// lib/features/social/public_profile/user_profile_screen.dart:639
  ///
  /// In en, this message translates to:
  /// **'You blocked them'**
  String get socialPublicProfile_userUserProfileBlockedTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:1103
  ///
  /// In en, this message translates to:
  /// **'No communities joined yet'**
  String get socialPublicProfile_userUserProfileCommunitiesEmptyTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:1095
  ///
  /// In en, this message translates to:
  /// **'Community list not public'**
  String get socialPublicProfile_userUserProfileCommunitiesHiddenTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:1077
  ///
  /// In en, this message translates to:
  /// **'The community service isn\'t available right now; an empty list isn\'t shown in its place.'**
  String get socialPublicProfile_userUserProfileCommunitiesUnavailableDetail;

  /// lib/features/social/public_profile/user_profile_screen.dart:1076
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load communities right now'**
  String get socialPublicProfile_userUserProfileCommunitiesUnavailableMessage;

  /// lib/features/social/public_profile/user_profile_screen.dart:805
  ///
  /// In en, this message translates to:
  /// **'No holdings yet'**
  String get socialPublicProfile_userUserProfileHoldingsEmptyTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:797
  ///
  /// In en, this message translates to:
  /// **'MEME holdings unavailable'**
  String get socialPublicProfile_userUserProfileHoldingsLaunch2UnavailableLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:772, lib/features/social/public_profile/user_profile_screen.dart:878
  ///
  /// In en, this message translates to:
  /// **'No quote'**
  String get socialPublicProfile_userUserProfileHoldingsTotal;

  /// lib/features/social/public_profile/user_profile_screen.dart:144
  ///
  /// In en, this message translates to:
  /// **'Enter from a chat, search or member list.'**
  String get socialPublicProfile_userUserProfileInvalidTargetMessage;

  /// lib/features/social/public_profile/user_profile_screen.dart:143
  ///
  /// In en, this message translates to:
  /// **'No user to open from this link'**
  String get socialPublicProfile_userUserProfileInvalidTargetTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:620
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get socialPublicProfile_userUserProfileMoreSemanticLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:301
  ///
  /// In en, this message translates to:
  /// **'Close more actions'**
  String get socialPublicProfile_userUserProfileMoreSheetBarrierLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:404
  ///
  /// In en, this message translates to:
  /// **'The account doesn\'t exist, or their profile isn\'t visible to you.'**
  String get socialPublicProfile_userUserProfileNotFoundMessage;

  /// lib/features/social/public_profile/user_profile_screen.dart:403
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get socialPublicProfile_userUserProfileNotFoundTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get socialPublicProfile_userUserProfileRemoveFriendLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:338
  ///
  /// In en, this message translates to:
  /// **'Report and block'**
  String get socialPublicProfile_userUserProfileReportLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:343
  ///
  /// In en, this message translates to:
  /// **'Reporting isn\'t available yet; you can block for now.'**
  String get socialPublicProfile_userUserProfileReportUnavailable;

  /// lib/features/social/public_profile/user_profile_screen.dart:137, lib/features/social/public_profile/user_profile_screen.dart:170, lib/features/social/public_profile/user_profile_screen.dart:178
  ///
  /// In en, this message translates to:
  /// **'User profile'**
  String get socialPublicProfile_userUserProfileScreenTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:613
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get socialPublicProfile_userUserProfileShareCardSemanticLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:957
  ///
  /// In en, this message translates to:
  /// **'No trades yet'**
  String get socialPublicProfile_userUserProfileTradesEmptyTitle;

  /// lib/features/social/public_profile/user_profile_screen.dart:943
  ///
  /// In en, this message translates to:
  /// **'MEME records unavailable'**
  String get socialPublicProfile_userUserProfileTradesLaunch2UnavailableLabel;

  /// lib/features/social/public_profile/user_profile_screen.dart:412
  ///
  /// In en, this message translates to:
  /// **'The profile service isn\'t available yet; this page didn\'t load anything.'**
  String get socialPublicProfile_userUserProfileUnavailableDetail;

  /// lib/features/social/public_profile/user_profile_screen.dart:411
  ///
  /// In en, this message translates to:
  /// **'User profile unavailable'**
  String get socialPublicProfile_userUserProfileUnavailableMessage;

  /// lib/features/social/public_profile/user_profile_screen.dart:649
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get socialPublicProfile_userUserProfileUnblockLabel;

  /// lib/features/social/qr/loop_qr_card.dart:119
  ///
  /// In en, this message translates to:
  /// **'Close QR card'**
  String get socialQr_cardBarrierLabel;

  /// lib/features/social/qr/loop_qr_card.dart:230
  ///
  /// In en, this message translates to:
  /// **'Invite text copied'**
  String get socialQr_cardCopy;

  /// lib/features/social/qr/loop_qr_card.dart:103
  ///
  /// In en, this message translates to:
  /// **'Poster created, but no share destination was chosen'**
  String get socialQr_cardDismissed;

  /// lib/features/social/qr/loop_qr_card.dart:104
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the poster; nothing left this device'**
  String get socialQr_cardFailed;

  /// lib/features/social/qr/loop_qr_card.dart:157
  ///
  /// In en, this message translates to:
  /// **'Community QR card'**
  String get socialQr_cardLoopCommunityQrCard;

  /// lib/features/social/qr/loop_qr_card.dart:156
  ///
  /// In en, this message translates to:
  /// **'My QR card'**
  String get socialQr_cardLoopUserQrCard;

  /// lib/features/social/qr/loop_qr_card.dart:424
  ///
  /// In en, this message translates to:
  /// **'{name}\'s QR code'**
  String socialQr_cardQrCardCodeSemanticLabel(Object? name);

  /// lib/features/social/qr/loop_qr_card.dart:228
  ///
  /// In en, this message translates to:
  /// **'Copy invite text'**
  String get socialQr_cardQrCardCopyInviteLabel;

  /// lib/features/social/qr/loop_qr_card.dart:208
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get socialQr_cardQrCardCopyLinkLabel;

  /// lib/features/social/qr/loop_qr_card.dart:350
  ///
  /// In en, this message translates to:
  /// **'{name}\'s QR card'**
  String socialQr_cardQrCardPosterLabel(Object? name);

  /// lib/features/social/qr/loop_qr_card.dart:220
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get socialQr_cardQrCardSharePosterLabel;

  /// lib/features/social/qr/loop_qr_card.dart:220
  ///
  /// In en, this message translates to:
  /// **'Share poster'**
  String get socialQr_cardQrCardSharePosterLabel2;

  /// lib/features/social/qr/loop_qr_card.dart:173
  ///
  /// In en, this message translates to:
  /// **'QR code unavailable'**
  String get socialQr_cardQrCardUnavailableLabel;

  /// lib/features/social/qr/loop_qr_card.dart:95
  ///
  /// In en, this message translates to:
  /// **'Join \"{name}\" on LOOP\n{link}'**
  String socialQr_cardS(Object? link, Object? name);

  /// lib/features/social/qr/loop_qr_card.dart:102
  ///
  /// In en, this message translates to:
  /// **'Poster created. Choose where to share it'**
  String get socialQr_cardShared;

  /// lib/features/social/qr/loop_qr_card.dart:95
  ///
  /// In en, this message translates to:
  /// **'Join \"{name}\" on LOOP'**
  String socialQr_cardSwitch(Object? name);

  /// lib/features/social/qr/loop_qr_card.dart:318
  ///
  /// In en, this message translates to:
  /// **'Scan to add me'**
  String get socialQr_cardSwitch2;

  /// lib/features/social/qr/loop_qr_card.dart:328
  ///
  /// In en, this message translates to:
  /// **'{memberCount, plural, =1{1 member} other{{memberCount} members}}'**
  String socialQr_cardSwitch3(num memberCount);

  /// lib/features/social/qr/loop_qr_card.dart:330
  ///
  /// In en, this message translates to:
  /// **'Scan to join'**
  String get socialQr_cardSwitch4;

  /// lib/features/social/qr/loop_qr_card.dart:105
  ///
  /// In en, this message translates to:
  /// **'System sharing isn\'t available in this run; no poster was created'**
  String get socialQr_cardUnavailable;

  /// lib/features/social/blocklist_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'Block list unavailable'**
  String get social_blocklistBlocklistCapabilityUnavailableTitle;

  /// lib/features/social/blocklist_screen.dart:182
  ///
  /// In en, this message translates to:
  /// **'These two block types aren\'t available yet, so nothing is listed here.'**
  String get social_blocklistBlocklistDeferredKindsDetail;

  /// lib/features/social/blocklist_screen.dart:181
  ///
  /// In en, this message translates to:
  /// **'Contract and domain blocks aren\'t available yet'**
  String get social_blocklistBlocklistDeferredKindsMessage;

  /// lib/features/social/blocklist_screen.dart:197
  ///
  /// In en, this message translates to:
  /// **'Blocking immediately removes follows both ways and hides them from search, follow lists and message requests. Unblocking doesn\'t restore follows; you\'ll need to follow again.'**
  String get social_blocklistBlocklistPrecedenceNoticeBody;

  /// lib/features/social/blocklist_screen.dart:195
  ///
  /// In en, this message translates to:
  /// **'What blocking does'**
  String get social_blocklistBlocklistPrecedenceNoticeTitle;

  /// lib/features/social/blocklist_screen.dart:243
  ///
  /// In en, this message translates to:
  /// **'After unblocking, they can show up in search and message requests again. Removed follows aren\'t restored automatically.'**
  String get social_blocklistBody;

  /// lib/features/social/blocklist_screen.dart:74
  ///
  /// In en, this message translates to:
  /// **'Blocking overrides follows and direct messages. Unblocking doesn\'t restore follows.'**
  String get social_blocklistCaption;

  /// lib/features/social/blocklist_screen.dart:244
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get social_blocklistConfirmLabel;

  /// lib/features/social/blocklist_screen.dart:129
  ///
  /// In en, this message translates to:
  /// **'Contract and domain blocks aren\'t available yet, so nothing is listed here.'**
  String get social_blocklistDetail;

  /// lib/features/social/blocklist_screen.dart:39
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get social_blocklistDomain;

  /// lib/features/social/blocklist_screen.dart:137
  ///
  /// In en, this message translates to:
  /// **'No blocked accounts'**
  String get social_blocklistEmptyMessage;

  /// lib/features/social/blocklist_screen.dart:138
  ///
  /// In en, this message translates to:
  /// **'Choosing Report on a message request blocks the sender automatically.'**
  String get social_blocklistEmptyReason;

  /// lib/features/social/blocklist_screen.dart:73
  ///
  /// In en, this message translates to:
  /// **'{userCount, plural, =1{1 blocked account} other{{userCount} blocked accounts}}'**
  String social_blocklistHeading(num userCount);

  /// lib/features/social/blocklist_screen.dart:94
  ///
  /// In en, this message translates to:
  /// **'Users {userCount}'**
  String social_blocklistLabel(Object? userCount);

  /// lib/features/social/blocklist_screen.dart:227
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get social_blocklistLoopBadge;

  /// lib/features/social/blocklist_screen.dart:128
  ///
  /// In en, this message translates to:
  /// **'\"{segmentLabels}\" blocks aren\'t available yet'**
  String social_blocklistMessage(Object? segmentLabels);

  /// lib/features/social/blocklist_screen.dart:251
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get social_blocklistMessage2;

  /// lib/features/social/blocklist_screen.dart:231
  ///
  /// In en, this message translates to:
  /// **'{title}, {blockReasonText}, can unblock'**
  String social_blocklistSemanticLabel(Object? blockReasonText, Object? title);

  /// lib/features/social/blocklist_screen.dart:75
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get social_blocklistStamp;

  /// lib/features/social/blocklist_screen.dart:242
  ///
  /// In en, this message translates to:
  /// **'Unblock {title}?'**
  String social_blocklistTitle(Object? title);

  /// lib/features/social/connections_screen.dart:307
  ///
  /// In en, this message translates to:
  /// **'After unfollowing, you won\'t see their public posts.'**
  String get social_connectionsBody;

  /// lib/features/social/connections_screen.dart:308
  ///
  /// In en, this message translates to:
  /// **'Following is one-way and doesn\'t need their approval. They need Discoverable on to be followed.'**
  String get social_connectionsBody2;

  /// lib/features/social/connections_screen.dart:130, lib/features/social/connections_screen.dart:138
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet'**
  String get social_connectionsCommunityStateEmptyEmptyMessage;

  /// lib/features/social/connections_screen.dart:131, lib/features/social/connections_screen.dart:139
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get social_connectionsCommunityStateEmptyEmptyMessage2;

  /// lib/features/social/connections_screen.dart:132, lib/features/social/connections_screen.dart:140, lib/features/social/dm_requests_screen.dart:95, lib/features/social/dm_requests_screen.dart:100
  ///
  /// In en, this message translates to:
  /// **'Accounts you\'ve blocked don\'t appear here.'**
  String get social_connectionsCommunityStateEmptyEmptyReason;

  /// lib/features/social/connections_screen.dart:265, lib/features/social/public_profile_sheet.dart:354
  ///
  /// In en, this message translates to:
  /// **'Open direct message'**
  String get social_connectionsConnectionActionDmLabel;

  /// lib/features/social/connections_screen.dart:274, lib/features/social/connections_screen.dart:309, lib/features/social/public_profile_sheet.dart:338
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get social_connectionsConnectionActionFollowLabel;

  /// lib/features/social/connections_screen.dart:247
  ///
  /// In en, this message translates to:
  /// **'Close contact actions'**
  String get social_connectionsConnectionActionsSheetBarrierLabel;

  /// lib/features/social/connections_screen.dart:112
  ///
  /// In en, this message translates to:
  /// **'Follows unavailable'**
  String get social_connectionsConnectionsCapabilityUnavailableTitle;

  /// lib/features/social/connections_screen.dart:178
  ///
  /// In en, this message translates to:
  /// **'Others can find you by nickname once Privacy Center · Discoverable is on; your LOOP ID can always be searched exactly.'**
  String get social_connectionsConnectionsDiscoverableNotice;

  /// lib/features/social/connections_screen.dart:69
  ///
  /// In en, this message translates to:
  /// **'Following and followers'**
  String get social_connectionsConnectionsScreenTitle;

  /// lib/features/social/connections_screen.dart:96
  ///
  /// In en, this message translates to:
  /// **'Followers {followers}'**
  String social_connectionsConnectionsSegFollowersLabel(Object? followers);

  /// lib/features/social/connections_screen.dart:86
  ///
  /// In en, this message translates to:
  /// **'Following {following}'**
  String social_connectionsConnectionsSegFollowingLabel(Object? following);

  /// lib/features/social/connections_screen.dart:319
  ///
  /// In en, this message translates to:
  /// **'Unfollowed'**
  String get social_connectionsMessage;

  /// lib/features/social/connections_screen.dart:124
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get social_connectionsResource;

  /// lib/features/social/connections_screen.dart:305
  ///
  /// In en, this message translates to:
  /// **'Unfollow?'**
  String get social_connectionsTitle;

  /// lib/features/social/connections_screen.dart:305
  ///
  /// In en, this message translates to:
  /// **'Follow this account?'**
  String get social_connectionsTitle2;

  /// lib/features/social/dm_requests_screen.dart:148, lib/features/social/dm_requests_screen.dart:224
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get social_dmRequestsAccept;

  /// lib/features/social/dm_requests_screen.dart:156
  ///
  /// In en, this message translates to:
  /// **'Accepting connects you. It can\'t connect if either of you has blocked the other.'**
  String get social_dmRequestsAccept2;

  /// lib/features/social/dm_requests_screen.dart:154
  ///
  /// In en, this message translates to:
  /// **'Accept this request?'**
  String get social_dmRequestsAcceptTitle;

  /// lib/features/social/dm_requests_screen.dart:182
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get social_dmRequestsAccepted;

  /// lib/features/social/dm_requests_screen.dart:234
  ///
  /// In en, this message translates to:
  /// **'Close request actions'**
  String get social_dmRequestsBarrierLabel;

  /// lib/features/social/dm_requests_screen.dart:94, lib/features/social/dm_requests_screen.dart:99
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get social_dmRequestsCommunityStateEmptyEmptyMessage;

  /// lib/features/social/dm_requests_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'The last decision didn\'t finish'**
  String get social_dmRequestsDmRequestsActionFailureTitle;

  /// lib/features/social/dm_requests_screen.dart:77
  ///
  /// In en, this message translates to:
  /// **'Message requests unavailable'**
  String get social_dmRequestsDmRequestsCapabilityUnavailableTitle;

  /// lib/features/social/dm_requests_screen.dart:68
  ///
  /// In en, this message translates to:
  /// **'0 pending'**
  String get social_dmRequestsEmpty;

  /// lib/features/social/dm_requests_screen.dart:149, lib/features/social/dm_requests_screen.dart:254
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get social_dmRequestsIgnore;

  /// lib/features/social/dm_requests_screen.dart:157
  ///
  /// In en, this message translates to:
  /// **'After ignoring, they can\'t send another request for 24 hours.'**
  String get social_dmRequestsIgnore2;

  /// lib/features/social/dm_requests_screen.dart:154
  ///
  /// In en, this message translates to:
  /// **'Ignore this request?'**
  String get social_dmRequestsIgnoreTitle;

  /// lib/features/social/dm_requests_screen.dart:182
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get social_dmRequestsIgnored;

  /// lib/features/social/dm_requests_screen.dart:182
  ///
  /// In en, this message translates to:
  /// **'Reported and blocked'**
  String get social_dmRequestsMessage;

  /// lib/features/social/dm_requests_screen.dart:67
  ///
  /// In en, this message translates to:
  /// **'{items} pending'**
  String social_dmRequestsReady(Object? items);

  /// lib/features/social/dm_requests_screen.dart:150, lib/features/social/dm_requests_screen.dart:264
  ///
  /// In en, this message translates to:
  /// **'Report and block'**
  String get social_dmRequestsReport;

  /// lib/features/social/dm_requests_screen.dart:158
  ///
  /// In en, this message translates to:
  /// **'Reporting declines the request, blocks the sender, writes an audit record and removes follows both ways.'**
  String get social_dmRequestsReport2;

  /// lib/features/social/dm_requests_screen.dart:154
  ///
  /// In en, this message translates to:
  /// **'Report and block this request?'**
  String get social_dmRequestsReportTitle;

  /// lib/features/social/loop_id_copy.dart:62
  ///
  /// In en, this message translates to:
  /// **'Copy LOOP ID'**
  String get social_idCopyLabel;

  /// lib/features/social/loop_id_copy.dart:85
  ///
  /// In en, this message translates to:
  /// **'LOOP ID copied'**
  String get social_idCopyMessage;

  /// lib/features/social/loop_id_share.dart:76
  ///
  /// In en, this message translates to:
  /// **'Add me as a friend on LOOP: {loopId}'**
  String social_idShareLine(Object? loopId);

  /// lib/features/social/social_models.dart:162
  ///
  /// In en, this message translates to:
  /// **'Blocked by you'**
  String get social_modelsSwitch;

  /// lib/features/social/social_models.dart:163
  ///
  /// In en, this message translates to:
  /// **'Blocked automatically when reporting a message request'**
  String get social_modelsSwitch2;

  /// lib/features/social/social_models.dart:164
  ///
  /// In en, this message translates to:
  /// **'Block reason'**
  String get social_modelsSwitch3;

  /// lib/features/social/profile_face_link.dart:67
  ///
  /// In en, this message translates to:
  /// **'View my profile'**
  String get social_profileFaceLinkLabel;

  /// lib/features/social/profile_face_link.dart:67
  ///
  /// In en, this message translates to:
  /// **'View {name}\'s profile'**
  String social_profileFaceLinkLabel2(Object? name);

  /// lib/features/social/public_profile_sheet.dart:165
  ///
  /// In en, this message translates to:
  /// **'Close public profile'**
  String get social_publicProfileSheetBarrierLabel;

  /// lib/features/social/public_profile_sheet.dart:365
  ///
  /// In en, this message translates to:
  /// **'If you\'re not connected yet, you\'ll send a message request first.'**
  String get social_publicProfileSheetPublicProfileDmHint;

  /// lib/features/social/public_profile_sheet.dart:313
  ///
  /// In en, this message translates to:
  /// **'Not following'**
  String get social_publicProfileSheetPublicProfileFollowState;

  /// lib/features/social/public_profile_sheet.dart:333
  ///
  /// In en, this message translates to:
  /// **'The current follow status can\'t be read here; the result after the action applies.'**
  String get social_publicProfileSheetPublicProfileFollowUnknownBody;

  /// lib/features/social/public_profile_sheet.dart:323
  ///
  /// In en, this message translates to:
  /// **'This account has no public profile; it can\'t be followed or acted on.'**
  String get social_publicProfileSheetPublicProfileNotTargetableDetail;

  /// lib/features/social/public_profile_sheet.dart:322
  ///
  /// In en, this message translates to:
  /// **'This member has no public profile'**
  String get social_publicProfileSheetPublicProfileNotTargetableMessage;

  /// lib/features/social/public_profile_sheet.dart:376
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get social_publicProfileSheetPublicProfileOpenPageLabel;

  /// lib/features/square/square_community_list.dart:99
  ///
  /// In en, this message translates to:
  /// **'Close sorting rules'**
  String get square_communityListBarrierLabel;

  /// lib/features/square/square_community_list.dart:119
  ///
  /// In en, this message translates to:
  /// **'Close sorting'**
  String get square_communityListBarrierLabel2;

  /// lib/features/square/square_community_list.dart:354
  ///
  /// In en, this message translates to:
  /// **'Discover communities'**
  String get square_communityListBuild;

  /// lib/features/square/square_community_list.dart:1172
  ///
  /// In en, this message translates to:
  /// **'Sorting uses only verifiable numbers: members, creation time, power and 7-day discussion count. Popular doesn\'t mean recommended.'**
  String get square_communityListBuild2;

  /// lib/features/square/square_community_list.dart:1184
  ///
  /// In en, this message translates to:
  /// **'How to list a community'**
  String get square_communityListBuild3;

  /// lib/features/square/square_community_list.dart:1187
  ///
  /// In en, this message translates to:
  /// **'Any community can apply. After applying the status is \"In review\"; only communities verified by operations show a verified mark. This page doesn\'t imply any Mining weight.'**
  String get square_communityListBuild4;

  /// lib/features/square/square_community_list.dart:719
  ///
  /// In en, this message translates to:
  /// **', not joined'**
  String get square_communityListJoin;

  /// lib/features/square/square_community_list.dart:584
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get square_communityListJoined;

  /// lib/features/square/square_community_list.dart:720
  ///
  /// In en, this message translates to:
  /// **', joined'**
  String get square_communityListJoined2;

  /// lib/features/square/square_community_list.dart:481
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get square_communityListLoopSheetHeading;

  /// lib/features/square/square_community_list.dart:1159
  ///
  /// In en, this message translates to:
  /// **'Sorting rules'**
  String get square_communityListLoopSheetHeading2;

  /// lib/features/square/square_community_list.dart:85, lib/features/square/square_community_list.dart:1089
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get square_communityListMessage;

  /// lib/features/square/square_community_list.dart:172
  ///
  /// In en, this message translates to:
  /// **'\"{label}\" isn\'t available right now'**
  String square_communityListMessage2(Object? label);

  /// lib/features/square/square_community_list.dart:721
  ///
  /// In en, this message translates to:
  /// **', my community'**
  String get square_communityListMine;

  /// lib/features/square/square_community_list.dart:722
  ///
  /// In en, this message translates to:
  /// **', in review'**
  String get square_communityListPending;

  /// lib/features/square/square_community_list.dart:535
  ///
  /// In en, this message translates to:
  /// **'Search communities'**
  String get square_communityListPlaceholder;

  /// lib/features/square/square_community_list.dart:152
  ///
  /// In en, this message translates to:
  /// **'Community directory'**
  String get square_communityListResource;

  /// lib/features/square/square_community_list.dart:1197
  ///
  /// In en, this message translates to:
  /// **'Apply to list'**
  String get square_communityListSquareCommunityApplyLabel;

  /// lib/features/square/square_community_list.dart:287
  ///
  /// In en, this message translates to:
  /// **'Communities aren\'t available right now'**
  String get square_communityListSquareCommunityCapabilityUnavailableTitle;

  /// lib/features/square/square_community_list.dart:201
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get square_communityListSquareCommunityJoinedEmptyAllLabel;

  /// lib/features/square/square_community_list.dart:198
  ///
  /// In en, this message translates to:
  /// **'No joined communities yet'**
  String get square_communityListSquareCommunityJoinedEmptyTitle;

  /// lib/features/square/square_community_list.dart:186
  ///
  /// In en, this message translates to:
  /// **'Sort by most members'**
  String get square_communityListSquareCommunityOrderingBackLabel;

  /// lib/features/square/square_community_list.dart:35
  ///
  /// In en, this message translates to:
  /// **'Sorted by members / power / discussions / newest. Popular doesn\'t mean recommended.'**
  String get square_communityListSquareCommunityRuleLine;

  /// lib/features/square/square_community_list.dart:363
  ///
  /// In en, this message translates to:
  /// **'Rules and listing'**
  String get square_communityListSquareCommunityRulesLabel;

  /// lib/features/square/square_community_list.dart:431
  ///
  /// In en, this message translates to:
  /// **'Sort, {label}'**
  String square_communityListSquareCommunitySortLabel(Object? label);

  /// lib/features/square/square_community_list.dart:217
  ///
  /// In en, this message translates to:
  /// **'No matching communities'**
  String get square_communityListSquareCommunityStateEmptyMessage;

  /// lib/features/square/square_community_list.dart:651, lib/features/square/square_community_list.dart:800
  ///
  /// In en, this message translates to:
  /// **'{memberCount, plural, =1{1 member} other{{memberCount} members}}'**
  String square_communityListSquareCommunitySubline(num memberCount);

  /// lib/features/square/square_community_list.dart:991
  ///
  /// In en, this message translates to:
  /// **'Power community'**
  String get square_communityListSquareMiningLabel;

  /// lib/features/square/square_community_list.dart:1085
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get square_communityListSwitch;

  /// lib/features/square/square_community_list.dart:1090
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get square_communityListSwitch2;

  /// lib/features/square/square_community_list.dart:1094
  ///
  /// In en, this message translates to:
  /// **'Joining'**
  String get square_communityListSwitch3;

  /// lib/features/square/square_feed.dart:641
  ///
  /// In en, this message translates to:
  /// **'Result unconfirmed. Pull to refresh to check whether it was posted.'**
  String get square_feedCancelled;

  /// lib/features/square/square_feed.dart:18
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get square_feedGlobal;

  /// lib/features/square/square_feed.dart:642
  ///
  /// In en, this message translates to:
  /// **'This was already submitted. Pull to refresh to check.'**
  String get square_feedIdempotencyConflict;

  /// lib/features/square/square_feed.dart:630, lib/features/square/square_feed.dart:637
  ///
  /// In en, this message translates to:
  /// **'Posting too fast. Wait a minute and try again.'**
  String get square_feedSwitch;

  /// lib/features/square/square_feed.dart:631
  ///
  /// In en, this message translates to:
  /// **'Write something before posting'**
  String get square_feedSwitch2;

  /// lib/features/square/square_feed.dart:632
  ///
  /// In en, this message translates to:
  /// **'500 characters max. Shorten it and post again.'**
  String get square_feedSwitch3;

  /// lib/features/square/square_feed.dart:633
  ///
  /// In en, this message translates to:
  /// **'The text has unsupported characters. Remove them and post again.'**
  String get square_feedSwitch4;

  /// lib/features/square/square_feed.dart:634
  ///
  /// In en, this message translates to:
  /// **'The quoted token can\'t be loaded. Pick another or post without a token.'**
  String get square_feedSwitch5;

  /// lib/features/square/square_feed.dart:635
  ///
  /// In en, this message translates to:
  /// **'Finish account setup before posting'**
  String get square_feedSwitch6;

  /// lib/features/square/square_feed.dart:644
  ///
  /// In en, this message translates to:
  /// **'Not posted. Try again later.'**
  String get square_feedSwitch7;

  /// lib/features/square/square_feed.dart:639
  ///
  /// In en, this message translates to:
  /// **'No network connection. Not posted.'**
  String get square_feedTimedOut;

  /// lib/features/square/square_feed.dart:643
  ///
  /// In en, this message translates to:
  /// **'The feed isn\'t available right now. Try again later.'**
  String get square_feedUnavailable;

  /// lib/features/square/square_feed_view.dart:372, lib/features/square/square_feed_view.dart:833
  ///
  /// In en, this message translates to:
  /// **'LOOP Official'**
  String get square_feedViewBuild;

  /// lib/features/square/square_feed_view.dart:915
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get square_feedViewBuild2;

  /// lib/features/square/square_feed_view.dart:1083
  ///
  /// In en, this message translates to:
  /// **'Once deleted, no one can see it and it can\'t be restored.'**
  String get square_feedViewBuild3;

  /// lib/features/square/square_feed_view.dart:750
  ///
  /// In en, this message translates to:
  /// **'{got} {where}'**
  String square_feedViewClaimHeadJoined(Object? got, Object? where);

  /// lib/features/square/square_feed_view.dart:750
  ///
  /// In en, this message translates to:
  /// **'{got} {where}'**
  String square_feedViewClaimHeadSpaced(Object? got, Object? where);

  /// lib/features/square/square_feed_view.dart:750
  ///
  /// In en, this message translates to:
  /// **'{head}.'**
  String square_feedViewClaimSentence(Object? head);

  /// lib/features/square/square_feed_view.dart:1320
  ///
  /// In en, this message translates to:
  /// **'Search by ticker or name'**
  String get square_feedViewHint;

  /// lib/features/square/square_feed_view.dart:1362
  ///
  /// In en, this message translates to:
  /// **'Say something…'**
  String get square_feedViewHint2;

  /// lib/features/square/square_feed_view.dart:1366
  ///
  /// In en, this message translates to:
  /// **'Linked token (optional)'**
  String get square_feedViewLoopLabel;

  /// lib/features/square/square_feed_view.dart:1074
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get square_feedViewLoopSheetHeading;

  /// lib/features/square/square_feed_view.dart:579
  ///
  /// In en, this message translates to:
  /// **'Mcap {memeCapLabel}'**
  String square_feedViewMarketCapCompact(Object? memeCapLabel);

  /// lib/features/square/square_feed_view.dart:102
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get square_feedViewMessage;

  /// lib/features/square/square_feed_view.dart:112
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unlike. Try again later.'**
  String get square_feedViewMessage2;

  /// lib/features/square/square_feed_view.dart:112
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t like. Try again later.'**
  String get square_feedViewMessage3;

  /// lib/features/square/square_feed_view.dart:132
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get square_feedViewMessage4;

  /// lib/features/square/square_feed_view.dart:132
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Try again later.'**
  String get square_feedViewMessage5;

  /// lib/features/square/square_feed_view.dart:733
  ///
  /// In en, this message translates to:
  /// **'{named} filled the bonding pool. The official pool is live and buybacks have started.'**
  String square_feedViewS(Object? named);

  /// lib/features/square/square_feed_view.dart:737
  ///
  /// In en, this message translates to:
  /// **'Bought {amount} of {named}.'**
  String square_feedViewS2(Object? amount, Object? named);

  /// lib/features/square/square_feed_view.dart:747
  ///
  /// In en, this message translates to:
  /// **'Claimed {amount}'**
  String square_feedViewS3(Object? amount);

  /// lib/features/square/square_feed_view.dart:756
  ///
  /// In en, this message translates to:
  /// **'{head}, weight {formatDecimal}%.'**
  String square_feedViewS4(Object? formatDecimal, Object? head);

  /// lib/features/square/square_feed_view.dart:1351
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get square_feedViewSquareComposerFieldLabel;

  /// lib/features/square/square_feed_view.dart:1386
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get square_feedViewSquareComposerSendLabel;

  /// lib/features/square/square_feed_view.dart:1386
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get square_feedViewSquareComposerSendLabel2;

  /// lib/features/square/square_feed_view.dart:1244
  ///
  /// In en, this message translates to:
  /// **'Loading tokens…'**
  String get square_feedViewSquareComposerTokenEmpty;

  /// lib/features/square/square_feed_view.dart:1244
  ///
  /// In en, this message translates to:
  /// **'Tokens can\'t be loaded right now. Try again later.'**
  String get square_feedViewSquareComposerTokenEmpty2;

  /// lib/features/square/square_feed_view.dart:1293
  ///
  /// In en, this message translates to:
  /// **'{hidden} more'**
  String square_feedViewSquareComposerTokenMoreLabel(Object? hidden);

  /// lib/features/square/square_feed_view.dart:1327
  ///
  /// In en, this message translates to:
  /// **'No matching tokens'**
  String get square_feedViewSquareComposerTokenNoMatch;

  /// lib/features/square/square_feed_view.dart:1281
  ///
  /// In en, this message translates to:
  /// **'No token'**
  String get square_feedViewSquareComposerTokenNoneLabel;

  /// lib/features/square/square_feed_view.dart:1300
  ///
  /// In en, this message translates to:
  /// **'Search tokens'**
  String get square_feedViewSquareComposerTokenSearchLabel;

  /// lib/features/square/square_feed_view.dart:812
  ///
  /// In en, this message translates to:
  /// **'{month} {day}'**
  String square_feedViewSquareFeedAgeLabel(Object? day, Object? month);

  /// lib/features/square/square_feed_view.dart:289, lib/features/square/square_feed_view.dart:1349
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get square_feedViewSquareFeedComposeLabel;

  /// lib/features/square/square_feed_view.dart:182
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get square_feedViewSquareFeedEmptyTitle;

  /// lib/features/square/square_feed_view.dart:321
  ///
  /// In en, this message translates to:
  /// **'The feed can\'t be loaded right now'**
  String get square_feedViewSquareFeedUnavailableMessage;

  /// lib/features/square/square_feed_view.dart:774
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get square_feedViewSquarePostBadgeClaim;

  /// lib/features/square/square_feed_view.dart:765
  ///
  /// In en, this message translates to:
  /// **'Opinion'**
  String get square_feedViewSquarePostBadgeOpinion;

  /// lib/features/square/square_feed_view.dart:786
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get square_feedViewSquarePostBadgePinned;

  /// lib/features/square/square_feed_view.dart:1029
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get square_feedViewSquarePostLikeLabel;

  /// lib/features/square/square_feed_view.dart:1029
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get square_feedViewSquarePostLikeLabel2;

  /// lib/features/square/square_feed_view.dart:508
  ///
  /// In en, this message translates to:
  /// **'Delete this post'**
  String get square_feedViewSquarePostOwnOnLongPressHint;

  /// lib/features/square/square_feed_view.dart:733
  ///
  /// In en, this message translates to:
  /// **'This token filled the bonding pool. The official pool is live and buybacks have started.'**
  String get square_feedViewSwitch;

  /// lib/features/square/square_feed_view.dart:737
  ///
  /// In en, this message translates to:
  /// **'Bought {amount}.'**
  String square_feedViewSwitch2(Object? amount);

  /// lib/features/square/square_feed_view.dart:744
  ///
  /// In en, this message translates to:
  /// **'in {named}'**
  String square_feedViewSwitch3(Object? named);

  /// lib/features/square/square_feed_view.dart:745
  ///
  /// In en, this message translates to:
  /// **'round {round}'**
  String square_feedViewSwitch4(Object? round);

  /// lib/features/square/square_feed_view.dart:747
  ///
  /// In en, this message translates to:
  /// **'Claimed a reward'**
  String get square_feedViewSwitch5;

  /// lib/features/square/live_voice_rooms.dart:275
  ///
  /// In en, this message translates to:
  /// **'Just started'**
  String get square_liveVoiceRoomsLiveVoiceRoomElapsedLabel;

  /// lib/features/square/live_voice_rooms.dart:276
  ///
  /// In en, this message translates to:
  /// **'Live {inMinutes}m'**
  String square_liveVoiceRoomsLiveVoiceRoomElapsedLabel2(Object? inMinutes);

  /// lib/features/square/live_voice_rooms.dart:277
  ///
  /// In en, this message translates to:
  /// **'Live {inHours}h'**
  String square_liveVoiceRoomsLiveVoiceRoomElapsedLabel3(Object? inHours);

  /// lib/features/square/live_voice_rooms.dart:278
  ///
  /// In en, this message translates to:
  /// **'Live {inDays}d'**
  String square_liveVoiceRoomsLiveVoiceRoomElapsedLabel4(Object? inDays);

  /// lib/features/square/square_screen.dart:345
  ///
  /// In en, this message translates to:
  /// **'{room} listening'**
  String square_screenListening(Object? room);

  /// lib/features/square/square_screen.dart:355
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get square_screenLoopBadge;

  /// lib/features/square/square_screen.dart:356
  ///
  /// In en, this message translates to:
  /// **'Join first'**
  String get square_screenLoopBadge2;

  /// lib/features/square/square_screen.dart:157
  ///
  /// In en, this message translates to:
  /// **'Join \"{communityName}\" to enter the voice room'**
  String square_screenMessage(Object? communityName);

  /// lib/features/square/square_screen.dart:186
  ///
  /// In en, this message translates to:
  /// **'Voice room list'**
  String get square_screenResource;

  /// lib/features/square/square_screen.dart:85
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get square_screenSquareScreenTitle;

  /// lib/features/square/square_screen.dart:212
  ///
  /// In en, this message translates to:
  /// **'Browse communities'**
  String get square_screenSquareVoiceRoomBrowseLabel;

  /// lib/features/square/square_screen.dart:209
  ///
  /// In en, this message translates to:
  /// **'Communities show up here when they go live'**
  String get square_screenSquareVoiceRoomEmptyMessage;

  /// lib/features/square/square_screen.dart:208
  ///
  /// In en, this message translates to:
  /// **'No one is live yet'**
  String get square_screenSquareVoiceRoomEmptyTitle;

  /// lib/features/square/square_screen.dart:350
  ///
  /// In en, this message translates to:
  /// **'In room'**
  String get square_screenSquareVoiceRoomInRoom;

  /// lib/features/square/square_screen.dart:203
  ///
  /// In en, this message translates to:
  /// **'No voice rooms are live now'**
  String get square_screenSquareVoiceRoomStateEmptyMessage;

  /// lib/features/square/square_screen.dart:204
  ///
  /// In en, this message translates to:
  /// **'Rooms show up here when a community goes live.'**
  String get square_screenSquareVoiceRoomStateEmptyReason;

  /// lib/features/square/square_screen.dart:367
  ///
  /// In en, this message translates to:
  /// **'{title}, {communityName}, host {host}, {listening}, {elapsed}{inRoom}{room}'**
  String square_screenSquareVoiceRoomTitleLabel(
    Object? communityName,
    Object? elapsed,
    Object? host,
    Object? inRoom,
    Object? listening,
    Object? room,
    Object? title,
  );

  /// lib/features/square/square_screen.dart:431
  ///
  /// In en, this message translates to:
  /// **'Host {host}'**
  String square_screenText(Object? host);

  /// lib/features/square/square_screen.dart:375
  ///
  /// In en, this message translates to:
  /// **', you are in the room'**
  String get square_screenVoiceRoomInRoomSuffix;

  /// lib/features/square/square_screen.dart:375
  ///
  /// In en, this message translates to:
  /// **', join the community to enter'**
  String get square_screenVoiceRoomJoinFirstSuffix;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:164
  ///
  /// In en, this message translates to:
  /// **'Close Get funds'**
  String get walletTestnetFaucet_sheetBarrierLabel;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:141
  ///
  /// In en, this message translates to:
  /// **'Sending to someone else. Try again in a few seconds'**
  String get walletTestnetFaucet_sheetBusy;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:139
  ///
  /// In en, this message translates to:
  /// **'On-chain figures can\'t be fetched right now. Try again later'**
  String get walletTestnetFaucet_sheetChainReadFailed;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:145, lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:510
  ///
  /// In en, this message translates to:
  /// **'{testnetFaucetClaimedText}. Come back later'**
  String walletTestnetFaucet_sheetCooldown(Object? testnetFaucetClaimedText);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:127
  ///
  /// In en, this message translates to:
  /// **'Claiming is closed'**
  String get walletTestnetFaucet_sheetDisabled;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:100
  ///
  /// In en, this message translates to:
  /// **'{loopLaunchNativeSymbolText} was sent but isn\'t confirmed yet; {loopLaunchUsd1SymbolText} wasn\'t sent this time. {again}'**
  String walletTestnetFaucet_sheetIf(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:107
  ///
  /// In en, this message translates to:
  /// **'{loopLaunchNativeSymbolText} was sent; {loopLaunchUsd1SymbolText} wasn\'t sent this time. {again}'**
  String walletTestnetFaucet_sheetIf2(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:110
  ///
  /// In en, this message translates to:
  /// **'{loopLaunchUsd1SymbolText} arrived; {loopLaunchNativeSymbolText} didn\'t go through this time. {again}'**
  String walletTestnetFaucet_sheetIf3(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:112
  ///
  /// In en, this message translates to:
  /// **'Only part of it was sent this time. {again}'**
  String walletTestnetFaucet_sheetIf4(Object? again);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:113
  ///
  /// In en, this message translates to:
  /// **'{loopLaunchNativeSymbolText} arrived; {loopLaunchUsd1SymbolText} didn\'t go through this time. {again}'**
  String walletTestnetFaucet_sheetIf5(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:450
  ///
  /// In en, this message translates to:
  /// **'Loading claim status…'**
  String get walletTestnetFaucet_sheetIf6;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:534
  ///
  /// In en, this message translates to:
  /// **'Claimed recently'**
  String get walletTestnetFaucet_sheetLabel;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:535
  ///
  /// In en, this message translates to:
  /// **'Claimed in the last {testnetFaucetCooldownText}'**
  String walletTestnetFaucet_sheetLabel2(Object? testnetFaucetCooldownText);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:536
  ///
  /// In en, this message translates to:
  /// **'Next claim {testnetFaucetNextLabel}'**
  String walletTestnetFaucet_sheetLabel3(Object? testnetFaucetNextLabel);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:639
  ///
  /// In en, this message translates to:
  /// **'Copy {label} transaction hash'**
  String walletTestnetFaucet_sheetLabel4(Object? label);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:646
  ///
  /// In en, this message translates to:
  /// **'Copy {label} BscScan link'**
  String walletTestnetFaucet_sheetLabel5(Object? label);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:641
  ///
  /// In en, this message translates to:
  /// **'Transaction hash copied'**
  String get walletTestnetFaucet_sheetMessage;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:648
  ///
  /// In en, this message translates to:
  /// **'BscScan link copied'**
  String get walletTestnetFaucet_sheetMessage2;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:135
  ///
  /// In en, this message translates to:
  /// **'Claiming isn\'t available right now. Try again later'**
  String get walletTestnetFaucet_sheetRuntimeUnavailable;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:85
  ///
  /// In en, this message translates to:
  /// **'You can claim again in {testnetFaucetCooldownText}'**
  String walletTestnetFaucet_sheetS(Object? testnetFaucetCooldownText);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:91
  ///
  /// In en, this message translates to:
  /// **'This wallet already claimed in the last {testnetFaucetCooldownText}'**
  String walletTestnetFaucet_sheetS2(Object? testnetFaucetCooldownText);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:432
  ///
  /// In en, this message translates to:
  /// **'Receiving wallet'**
  String get walletTestnetFaucet_sheetTestnetFaucetAddressLabel;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:49
  ///
  /// In en, this message translates to:
  /// **'Sending… (about 30 seconds)'**
  String get walletTestnetFaucet_sheetTestnetFaucetBusyLabel;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:74
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:75
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 day} other{{seconds} days}}'**
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText2(num seconds);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:76
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 hour} other{{seconds} hours}}'**
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText3(num seconds);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:77
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 minute} other{{seconds} minutes}}'**
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText4(num seconds);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:78
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText5(num seconds);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:84
  ///
  /// In en, this message translates to:
  /// **'You can claim again later'**
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText6;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:90
  ///
  /// In en, this message translates to:
  /// **'This wallet claimed recently'**
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText7;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:572
  ///
  /// In en, this message translates to:
  /// **'Sent {formatDecimal} {loopLaunchNativeSymbolText} and {formatDecimal2} {loopLaunchUsd1SymbolText}. Arrival is final once confirmed on-chain; your balance refreshes automatically.'**
  String walletTestnetFaucet_sheetTestnetFaucetGranted(
    Object? formatDecimal,
    Object? formatDecimal2,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:52
  ///
  /// In en, this message translates to:
  /// **'Check the result here later'**
  String get walletTestnetFaucet_sheetTestnetFaucetInFlightLaterText;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:418
  ///
  /// In en, this message translates to:
  /// **'Claim {loopLaunchNativeSymbolText} and {loopLaunchUsd1SymbolText} to the current wallet for fees and trading, once every 24 hours.'**
  String walletTestnetFaucet_sheetTestnetFaucetIntro(
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:420
  ///
  /// In en, this message translates to:
  /// **'This sends {formatDecimal} {loopLaunchNativeSymbolText} and {formatDecimal2} {loopLaunchUsd1SymbolText} to the current wallet; you can claim once every {testnetFaucetCooldownText}.'**
  String walletTestnetFaucet_sheetTestnetFaucetIntro2(
    Object? formatDecimal,
    Object? formatDecimal2,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
    Object? testnetFaucetCooldownText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:66
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}'**
  String walletTestnetFaucet_sheetTestnetFaucetNextLabel(Object? time);

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:67
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {time}'**
  String walletTestnetFaucet_sheetTestnetFaucetNextLabel2(
    Object? day,
    Object? month,
    Object? time,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:51
  ///
  /// In en, this message translates to:
  /// **'Only the built-in wallet you\'re signed in with can claim'**
  String get walletTestnetFaucet_sheetTestnetFaucetNotOwnedText;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:50
  ///
  /// In en, this message translates to:
  /// **'The funding pool is low right now. Try again later'**
  String get walletTestnetFaucet_sheetTestnetFaucetOperatorLowText;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:53
  ///
  /// In en, this message translates to:
  /// **'Still sending. Check back later'**
  String get walletTestnetFaucet_sheetTestnetFaucetTimedOutLaterText;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:47
  ///
  /// In en, this message translates to:
  /// **'Get funds'**
  String get walletTestnetFaucet_sheetTestnetFaucetTitle;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:511
  ///
  /// In en, this message translates to:
  /// **'{testnetFaucetClaimedText}. Next claim {testnetFaucetNextLabel}'**
  String walletTestnetFaucet_sheetText(
    Object? testnetFaucetClaimedText,
    Object? testnetFaucetNextLabel,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:475
  ///
  /// In en, this message translates to:
  /// **'Claim status can\'t be loaded right now'**
  String get walletTestnetFaucet_sheetTitle;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:143
  ///
  /// In en, this message translates to:
  /// **'Nothing was sent this time. You can retry'**
  String get walletTestnetFaucet_sheetTransferFailed;

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:137
  ///
  /// In en, this message translates to:
  /// **'The {loopLaunchUsd1SymbolText} contract isn\'t available right now. Try again later'**
  String walletTestnetFaucet_sheetUsd1Unavailable(
    Object? loopLaunchUsd1SymbolText,
  );

  /// lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart:129
  ///
  /// In en, this message translates to:
  /// **'Claiming isn\'t supported on the current network'**
  String get walletTestnetFaucet_sheetWrongChain;

  /// lib/features/wallet/wallet_activity_export.dart:56
  ///
  /// In en, this message translates to:
  /// **'CSV created, but no share destination was chosen'**
  String get wallet_activityExportDismissed;

  /// lib/features/wallet/wallet_activity_export.dart:59
  ///
  /// In en, this message translates to:
  /// **'No records in this range to export'**
  String get wallet_activityExportEmpty;

  /// lib/features/wallet/wallet_activity_export.dart:57
  ///
  /// In en, this message translates to:
  /// **'Export didn\'t finish; nothing left this device'**
  String get wallet_activityExportFailed;

  /// lib/features/wallet/wallet_read_screens.dart:3355
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get wallet_activityExportIncoming;

  /// lib/features/wallet/wallet_read_screens.dart:3355
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get wallet_activityExportOutgoing;

  /// lib/features/wallet/wallet_activity_export.dart:99, lib/features/wallet/wallet_read_screens.dart:3256
  ///
  /// In en, this message translates to:
  /// **'Self-transfer'**
  String get wallet_activityExportSelf;

  /// lib/features/wallet/wallet_activity_export.dart:55
  ///
  /// In en, this message translates to:
  /// **'Records exported. Choose a destination in the share sheet'**
  String get wallet_activityExportShared;

  /// lib/features/wallet/wallet_activity_export.dart:65
  ///
  /// In en, this message translates to:
  /// **'Time (UTC)'**
  String get wallet_activityExportSwitch;

  /// lib/features/wallet/wallet_activity_export.dart:66
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get wallet_activityExportSwitch2;

  /// lib/features/wallet/wallet_activity_export.dart:68
  ///
  /// In en, this message translates to:
  /// **'Asset ID'**
  String get wallet_activityExportSwitch3;

  /// lib/features/wallet/wallet_activity_export.dart:70
  ///
  /// In en, this message translates to:
  /// **'Amount (base units)'**
  String get wallet_activityExportSwitch4;

  /// lib/features/wallet/wallet_activity_export.dart:71
  ///
  /// In en, this message translates to:
  /// **'Counterparty address'**
  String get wallet_activityExportSwitch5;

  /// lib/features/wallet/wallet_activity_export.dart:73
  ///
  /// In en, this message translates to:
  /// **'Log index'**
  String get wallet_activityExportSwitch6;

  /// lib/features/wallet/wallet_activity_export.dart:74
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get wallet_activityExportSwitch7;

  /// lib/features/wallet/wallet_activity_export.dart:76
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get wallet_activityExportSwitch8;

  /// lib/features/wallet/wallet_activity_export.dart:58
  ///
  /// In en, this message translates to:
  /// **'System sharing isn\'t set up in this session; nothing was exported'**
  String get wallet_activityExportUnavailable;

  /// lib/features/wallet/approval_screens.dart:706
  ///
  /// In en, this message translates to:
  /// **'Switch to limited approval'**
  String get wallet_approvalScreensApprovalActionLimitLabel;

  /// lib/features/wallet/approval_screens.dart:713
  ///
  /// In en, this message translates to:
  /// **'Revoke approval (approve 0)'**
  String get wallet_approvalScreensApprovalActionRevokeLabel;

  /// lib/features/wallet/approval_screens.dart:412
  ///
  /// In en, this message translates to:
  /// **'Call can\'t be decoded'**
  String get wallet_approvalScreensApprovalDecodedUnavailableLabel;

  /// lib/features/wallet/approval_screens.dart:159
  ///
  /// In en, this message translates to:
  /// **'Approvals aren\'t available right now'**
  String get wallet_approvalScreensApprovalGuardCapabilityBlockTitle;

  /// lib/features/wallet/approval_screens.dart:289
  ///
  /// In en, this message translates to:
  /// **'The approval couldn\'t be prepared'**
  String get wallet_approvalScreensApprovalGuardErrorTitle;

  /// lib/features/wallet/approval_screens.dart:235
  ///
  /// In en, this message translates to:
  /// **'Approve a limited amount'**
  String get wallet_approvalScreensApprovalGuardExactLabel;

  /// lib/features/wallet/approval_screens.dart:236
  ///
  /// In en, this message translates to:
  /// **'Approve a limit of {wire} {symbol}'**
  String wallet_approvalScreensApprovalGuardExactLabel2(
    Object? symbol,
    Object? wire,
  );

  /// lib/features/wallet/approval_screens.dart:131
  ///
  /// In en, this message translates to:
  /// **'Token, spender, amount and the decoded call are shown in full before signing.'**
  String get wallet_approvalScreensApprovalGuardFolioCaption;

  /// lib/features/wallet/approval_screens.dart:127
  ///
  /// In en, this message translates to:
  /// **'{symbol} approval'**
  String wallet_approvalScreensApprovalGuardFolioHeading(Object? symbol);

  /// lib/features/wallet/approval_screens.dart:129
  ///
  /// In en, this message translates to:
  /// **'Unlimited {symbol} approval'**
  String wallet_approvalScreensApprovalGuardFolioHeading2(Object? symbol);

  /// lib/features/wallet/approval_screens.dart:130
  ///
  /// In en, this message translates to:
  /// **'{display} {symbol} limit'**
  String wallet_approvalScreensApprovalGuardFolioHeading3(
    Object? display,
    Object? symbol,
  );

  /// lib/features/wallet/approval_screens.dart:125
  ///
  /// In en, this message translates to:
  /// **'Approval request'**
  String get wallet_approvalScreensApprovalGuardFolioKicker;

  /// lib/features/wallet/approval_screens.dart:132
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get wallet_approvalScreensApprovalGuardFolioStamp;

  /// lib/features/wallet/approval_screens.dart:268
  ///
  /// In en, this message translates to:
  /// **'Switch back to limited approval'**
  String get wallet_approvalScreensApprovalGuardRestartLabel;

  /// lib/features/wallet/approval_screens.dart:115
  ///
  /// In en, this message translates to:
  /// **'Approval guard'**
  String get wallet_approvalScreensApprovalGuardScreenTitle;

  /// lib/features/wallet/approval_screens.dart:142, lib/features/wallet/send_screens.dart:1213
  ///
  /// In en, this message translates to:
  /// **'Facts expired · Prepare again'**
  String get wallet_approvalScreensApprovalGuardSignLabel;

  /// lib/features/wallet/approval_screens.dart:143
  ///
  /// In en, this message translates to:
  /// **'Confirm approval ({moneyCountdownLabel})'**
  String wallet_approvalScreensApprovalGuardSignLabel2(
    Object? moneyCountdownLabel,
  );

  /// lib/features/wallet/approval_screens.dart:263
  ///
  /// In en, this message translates to:
  /// **'You\'ve confirmed twice. Once signed, this spender can keep using this token\'s entire balance, and the permission stays valid after you leave their interface until you revoke it in Token approvals.'**
  String get wallet_approvalScreensApprovalGuardUnlimitedConfirmedBody;

  /// lib/features/wallet/approval_screens.dart:261
  ///
  /// In en, this message translates to:
  /// **'This is an unlimited approval'**
  String get wallet_approvalScreensApprovalGuardUnlimitedConfirmedTitle;

  /// lib/features/wallet/approval_screens.dart:248
  ///
  /// In en, this message translates to:
  /// **'Approve unlimited anyway'**
  String get wallet_approvalScreensApprovalGuardUnlimitedLabel;

  /// lib/features/wallet/approval_screens.dart:197
  ///
  /// In en, this message translates to:
  /// **'A contract with an unlimited allowance can move this token\'s entire balance at any time until you revoke it. LOOP\'s default is to approve only the amount needed this time.'**
  String get wallet_approvalScreensApprovalGuardUnlimitedWarningBody;

  /// lib/features/wallet/approval_screens.dart:195
  ///
  /// In en, this message translates to:
  /// **'Unlimited approval means ongoing access to your entire balance'**
  String get wallet_approvalScreensApprovalGuardUnlimitedWarningTitle;

  /// lib/features/wallet/approval_screens.dart:330
  ///
  /// In en, this message translates to:
  /// **'I understand, approve unlimited anyway'**
  String get wallet_approvalScreensApprovalUnlimitedAcceptLabel;

  /// lib/features/wallet/approval_screens.dart:325
  ///
  /// In en, this message translates to:
  /// **'Use a limit instead'**
  String get wallet_approvalScreensApprovalUnlimitedCancelLabel;

  /// lib/features/wallet/approval_screens.dart:530
  ///
  /// In en, this message translates to:
  /// **'Revoke in batch'**
  String get wallet_approvalScreensApprovalsBatchActionLabel;

  /// lib/features/wallet/approval_screens.dart:542
  ///
  /// In en, this message translates to:
  /// **'Token approvals aren\'t available right now'**
  String get wallet_approvalScreensApprovalsCapabilityBlockTitle;

  /// lib/features/wallet/approval_screens.dart:636
  ///
  /// In en, this message translates to:
  /// **'Approvals since block {groupedFigure} · Indexed {groupedFigure2} / head {groupedFigure3} · observed {relativeTime}'**
  String wallet_approvalScreensApprovalsFreshnessText(
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? groupedFigure3,
    Object? relativeTime,
  );

  /// lib/features/wallet/approval_screens.dart:560
  ///
  /// In en, this message translates to:
  /// **'The approval list isn\'t available right now'**
  String get wallet_approvalScreensApprovalsPageBlockMessage;

  /// lib/features/wallet/approval_screens.dart:596
  ///
  /// In en, this message translates to:
  /// **'The revoke couldn\'t be prepared'**
  String get wallet_approvalScreensApprovalsRevokeErrorTitle;

  /// lib/features/wallet/approval_screens.dart:170
  ///
  /// In en, this message translates to:
  /// **'Approval check'**
  String get wallet_approvalScreensBuild;

  /// lib/features/wallet/approval_screens.dart:314
  ///
  /// In en, this message translates to:
  /// **'An unlimited allowance doesn\'t expire over time or when this transaction ends. This spender can later move this token\'s entire balance without asking you again. It\'s only taken back when you send approve(spender, 0) from Token approvals.'**
  String get wallet_approvalScreensConfirmUnlimited;

  /// lib/features/wallet/approval_screens.dart:570, lib/features/wallet/approval_screens.dart:623
  ///
  /// In en, this message translates to:
  /// **'This wallet has no active approvals'**
  String get wallet_approvalScreensEmptyMessage;

  /// lib/features/wallet/approval_screens.dart:424
  ///
  /// In en, this message translates to:
  /// **'Function'**
  String get wallet_approvalScreensLabel;

  /// lib/features/wallet/approval_screens.dart:553, lib/features/wallet/approval_screens.dart:604
  ///
  /// In en, this message translates to:
  /// **'Unlimited approval'**
  String get wallet_approvalScreensLabel2;

  /// lib/features/wallet/approval_screens.dart:554, lib/features/wallet/approval_screens.dart:612
  ///
  /// In en, this message translates to:
  /// **'Limited approval'**
  String get wallet_approvalScreensLabel3;

  /// lib/features/wallet/approval_screens.dart:222
  ///
  /// In en, this message translates to:
  /// **'Approval amount ({symbol})'**
  String wallet_approvalScreensLabelText(Object? symbol);

  /// lib/features/wallet/approval_screens.dart:656, lib/features/wallet/money_asset_picker.dart:109, lib/features/wallet/wallet_read_widgets.dart:59
  ///
  /// In en, this message translates to:
  /// **'Can\'t load'**
  String get wallet_approvalScreensLoopBadge;

  /// lib/features/wallet/approval_screens.dart:667
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get wallet_approvalScreensLoopBadge2;

  /// lib/features/wallet/approval_screens.dart:668
  ///
  /// In en, this message translates to:
  /// **'Limited'**
  String get wallet_approvalScreensLoopBadge3;

  /// lib/features/wallet/approval_screens.dart:201
  ///
  /// In en, this message translates to:
  /// **'Limited approval (default)'**
  String get wallet_approvalScreensLoopLabel;

  /// lib/features/wallet/approval_screens.dart:253
  ///
  /// In en, this message translates to:
  /// **'Decoded call'**
  String get wallet_approvalScreensLoopLabel2;

  /// lib/features/wallet/approval_screens.dart:557, lib/features/wallet/approval_screens.dart:618
  ///
  /// In en, this message translates to:
  /// **'Sorted by amount'**
  String get wallet_approvalScreensLoopLabel3;

  /// lib/features/wallet/approval_screens.dart:306
  ///
  /// In en, this message translates to:
  /// **'Confirm unlimited approval'**
  String get wallet_approvalScreensLoopSheetHeading;

  /// lib/features/wallet/approval_screens.dart:533
  ///
  /// In en, this message translates to:
  /// **'Batch revoke isn\'t available yet. Each revoke is a separate signature.'**
  String get wallet_approvalScreensMessage;

  /// lib/features/wallet/approval_screens.dart:284
  ///
  /// In en, this message translates to:
  /// **'Prepare approval'**
  String get wallet_approvalScreensMoneyOfflinePause;

  /// lib/features/wallet/approval_screens.dart:591
  ///
  /// In en, this message translates to:
  /// **'Revoke approval'**
  String get wallet_approvalScreensMoneyOfflinePause2;

  /// lib/features/wallet/approval_screens.dart:591
  ///
  /// In en, this message translates to:
  /// **'Change amount'**
  String get wallet_approvalScreensMoneyOfflinePause3;

  /// lib/features/wallet/approval_screens.dart:656
  ///
  /// In en, this message translates to:
  /// **'Allowance {display}'**
  String wallet_approvalScreensS(Object? display);

  /// lib/features/wallet/approval_screens.dart:663
  ///
  /// In en, this message translates to:
  /// **'{truncatedAddress} · {unlimited} · block {groupedFigure}'**
  String wallet_approvalScreensSubtitle(
    Object? groupedFigure,
    Object? truncatedAddress,
    Object? unlimited,
  );

  /// lib/features/wallet/approval_screens.dart:227
  ///
  /// In en, this message translates to:
  /// **'Approve only the amount this transaction needs.'**
  String get wallet_approvalScreensText;

  /// lib/features/wallet/approval_screens.dart:442
  ///
  /// In en, this message translates to:
  /// **'Native assets have no approvals'**
  String get wallet_approvalScreensValue;

  /// lib/features/wallet/deferred_screens.dart:414, lib/features/wallet/deferred_screens.dart:450
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get wallet_deferredScreensBlocked;

  /// lib/features/wallet/deferred_screens.dart:102
  ///
  /// In en, this message translates to:
  /// **'A scan result never starts signing directly; amount, network and recipient are shown again.'**
  String get wallet_deferredScreensBody;

  /// lib/features/wallet/deferred_screens.dart:159
  ///
  /// In en, this message translates to:
  /// **'Choose the source chain, destination chain and amount first; then estimated fees and arrival time are shown.'**
  String get wallet_deferredScreensBody2;

  /// lib/features/wallet/deferred_screens.dart:262
  ///
  /// In en, this message translates to:
  /// **'Source chain confirmation, bridging and destination arrival are three separate states.'**
  String get wallet_deferredScreensBody3;

  /// lib/features/wallet/deferred_screens.dart:382
  ///
  /// In en, this message translates to:
  /// **'The check runs entirely on this device: it won\'t open this URL, follow redirects or connect a wallet.'**
  String get wallet_deferredScreensBody4;

  /// lib/features/wallet/deferred_screens.dart:151, lib/features/wallet/deferred_screens.dart:201
  ///
  /// In en, this message translates to:
  /// **'Bridge isn\'t available yet'**
  String get wallet_deferredScreensBridgeFolioHeading;

  /// lib/features/wallet/deferred_screens.dart:150
  ///
  /// In en, this message translates to:
  /// **'Bridge intent'**
  String get wallet_deferredScreensBridgeFolioKicker;

  /// lib/features/wallet/deferred_screens.dart:169
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get wallet_deferredScreensBridgeFolioStamp;

  /// lib/features/wallet/deferred_screens.dart:177
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get wallet_deferredScreensBridgeFromCaption;

  /// lib/features/wallet/deferred_screens.dart:209
  ///
  /// In en, this message translates to:
  /// **'View bridge progress'**
  String get wallet_deferredScreensBridgeOpenStatusLabel;

  /// lib/features/wallet/deferred_screens.dart:164
  ///
  /// In en, this message translates to:
  /// **'Bridge fees, received amount and estimated time can only come from a real route. Without a route there are no such numbers, and this page won\'t substitute sample data.'**
  String get wallet_deferredScreensBridgeScopeNoticeBody;

  /// lib/features/wallet/deferred_screens.dart:157
  ///
  /// In en, this message translates to:
  /// **'About Bridge'**
  String get wallet_deferredScreensBridgeScopeNoticeTitle;

  /// lib/features/wallet/deferred_screens.dart:162
  ///
  /// In en, this message translates to:
  /// **'No estimates appear here'**
  String get wallet_deferredScreensBridgeScopeNoticeTitle2;

  /// lib/features/wallet/deferred_screens.dart:189
  ///
  /// In en, this message translates to:
  /// **'Start bridge'**
  String get wallet_deferredScreensBridgeStartLabel;

  /// lib/features/wallet/deferred_screens.dart:296
  ///
  /// In en, this message translates to:
  /// **'Back to Wallet'**
  String get wallet_deferredScreensBridgeStatusBackToWalletLabel;

  /// lib/features/wallet/deferred_screens.dart:255
  ///
  /// In en, this message translates to:
  /// **'Bridge progress isn\'t available yet'**
  String get wallet_deferredScreensBridgeStatusFolioHeading;

  /// lib/features/wallet/deferred_screens.dart:266
  ///
  /// In en, this message translates to:
  /// **'Once Bridge is available, it continues in the background, notifies you when done, and can be viewed in transaction history.'**
  String get wallet_deferredScreensBridgeStatusLeaveNoticeBody;

  /// lib/features/wallet/deferred_screens.dart:260
  ///
  /// In en, this message translates to:
  /// **'About bridge progress'**
  String get wallet_deferredScreensBridgeStatusLeaveNoticeTitle;

  /// lib/features/wallet/deferred_screens.dart:265
  ///
  /// In en, this message translates to:
  /// **'You can leave this page'**
  String get wallet_deferredScreensBridgeStatusLeaveNoticeTitle2;

  /// lib/features/wallet/deferred_screens.dart:282
  ///
  /// In en, this message translates to:
  /// **'No bridge to track yet'**
  String get wallet_deferredScreensBridgeStatusPageBlockMessage;

  /// lib/features/wallet/deferred_screens.dart:245, lib/features/wallet/deferred_screens.dart:254
  ///
  /// In en, this message translates to:
  /// **'Bridge progress'**
  String get wallet_deferredScreensBridgeStatusScreenTitle;

  /// lib/features/wallet/deferred_screens.dart:182
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get wallet_deferredScreensBridgeToCaption;

  /// lib/features/wallet/deferred_screens.dart:469
  ///
  /// In en, this message translates to:
  /// **'It looks like {confusableReading}, but it contains look-alike characters that aren\'t Latin letters. This is the most common phishing trick, so it was blocked.'**
  String wallet_deferredScreensDappConfusableNoticeBody(
    Object? confusableReading,
  );

  /// lib/features/wallet/deferred_screens.dart:467
  ///
  /// In en, this message translates to:
  /// **'This domain is impersonating another domain'**
  String get wallet_deferredScreensDappConfusableNoticeTitle;

  /// lib/features/wallet/deferred_screens.dart:521
  ///
  /// In en, this message translates to:
  /// **'Wallet connection and signing aren\'t available yet'**
  String get wallet_deferredScreensDappExecutionUnavailableLabel;

  /// lib/features/wallet/deferred_screens.dart:484
  ///
  /// In en, this message translates to:
  /// **'This only means the address itself is well-formed; it doesn\'t mean the site is trustworthy.'**
  String get wallet_deferredScreensDappFindingsEmptyMessage;

  /// lib/features/wallet/deferred_screens.dart:483
  ///
  /// In en, this message translates to:
  /// **'No issues found'**
  String get wallet_deferredScreensDappFindingsEmptyTitle;

  /// lib/features/wallet/deferred_screens.dart:368
  ///
  /// In en, this message translates to:
  /// **'DApp check · Read only'**
  String get wallet_deferredScreensDappFolioKicker;

  /// lib/features/wallet/deferred_screens.dart:386
  ///
  /// In en, this message translates to:
  /// **'The check is purely local: no requests, no DNS lookups and no redirects, so the domain you see is exactly the one you typed.'**
  String get wallet_deferredScreensDappNoFetchNoticeBody;

  /// lib/features/wallet/deferred_screens.dart:380
  ///
  /// In en, this message translates to:
  /// **'This page won\'t open the URL'**
  String get wallet_deferredScreensDappNoFetchNoticeTitle;

  /// lib/features/wallet/deferred_screens.dart:357
  ///
  /// In en, this message translates to:
  /// **'Search assets / communities / users / Launch / DApps / URLs'**
  String get wallet_deferredScreensDappOmniboxHintText;

  /// lib/features/wallet/deferred_screens.dart:514
  ///
  /// In en, this message translates to:
  /// **'Domain reputation can\'t be loaded'**
  String get wallet_deferredScreensDappReputationUnavailableLabel;

  /// lib/features/wallet/deferred_screens.dart:445
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t normalize; blocked'**
  String get wallet_deferredScreensDappReviewCanonicalSubtitle;

  /// lib/features/wallet/deferred_screens.dart:444
  ///
  /// In en, this message translates to:
  /// **'Normalized result'**
  String get wallet_deferredScreensDappReviewCanonicalTitle;

  /// lib/features/wallet/deferred_screens.dart:430
  ///
  /// In en, this message translates to:
  /// **'Enter a URL to see the normalized result and any issues here.'**
  String get wallet_deferredScreensDappReviewEmptyMessage;

  /// lib/features/wallet/deferred_screens.dart:438
  ///
  /// In en, this message translates to:
  /// **'What you typed'**
  String get wallet_deferredScreensDappReviewTypedTitle;

  /// lib/features/wallet/deferred_screens.dart:345
  ///
  /// In en, this message translates to:
  /// **'DApp check'**
  String get wallet_deferredScreensDappScreenTitle;

  /// lib/features/wallet/deferred_screens.dart:393
  ///
  /// In en, this message translates to:
  /// **'Check origin'**
  String get wallet_deferredScreensFlagged;

  /// lib/features/wallet/deferred_screens.dart:413, lib/features/wallet/deferred_screens.dart:449
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get wallet_deferredScreensFlagged2;

  /// lib/features/wallet/deferred_screens.dart:373, lib/features/wallet/deferred_screens.dart:429
  ///
  /// In en, this message translates to:
  /// **'No URL to check yet'**
  String get wallet_deferredScreensLoopFolioPrimary;

  /// lib/features/wallet/deferred_screens.dart:277
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get wallet_deferredScreensLoopLabel;

  /// lib/features/wallet/deferred_screens.dart:424
  ///
  /// In en, this message translates to:
  /// **'Local check'**
  String get wallet_deferredScreensLoopLabel2;

  /// lib/features/wallet/deferred_screens.dart:478
  ///
  /// In en, this message translates to:
  /// **'Findings'**
  String get wallet_deferredScreensLoopLabel3;

  /// lib/features/wallet/deferred_screens.dart:511
  ///
  /// In en, this message translates to:
  /// **'Domain reputation'**
  String get wallet_deferredScreensLoopLabel4;

  /// lib/features/wallet/deferred_screens.dart:518
  ///
  /// In en, this message translates to:
  /// **'Connection and signing'**
  String get wallet_deferredScreensLoopLabel5;

  /// lib/features/wallet/deferred_screens.dart:392
  ///
  /// In en, this message translates to:
  /// **'Origin matches'**
  String get wallet_deferredScreensNormalized;

  /// lib/features/wallet/deferred_screens.dart:412
  ///
  /// In en, this message translates to:
  /// **'Normalized'**
  String get wallet_deferredScreensNormalized2;

  /// lib/features/wallet/deferred_screens.dart:448
  ///
  /// In en, this message translates to:
  /// **'Readable'**
  String get wallet_deferredScreensNormalized3;

  /// lib/features/wallet/deferred_screens.dart:94
  ///
  /// In en, this message translates to:
  /// **'Scan to pay'**
  String get wallet_deferredScreensPayFolioHeading;

  /// lib/features/wallet/deferred_screens.dart:110
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get wallet_deferredScreensPayFolioStamp;

  /// lib/features/wallet/deferred_screens.dart:106
  ///
  /// In en, this message translates to:
  /// **'Payments involve compliance and payment provider approval and need a separate review. Community, Mining and Launch come first.'**
  String get wallet_deferredScreensPayWhyNoticeBody;

  /// lib/features/wallet/deferred_screens.dart:100
  ///
  /// In en, this message translates to:
  /// **'About Scan to pay'**
  String get wallet_deferredScreensPayWhyNoticeTitle;

  /// lib/features/wallet/deferred_screens.dart:105
  ///
  /// In en, this message translates to:
  /// **'Why not now'**
  String get wallet_deferredScreensPayWhyNoticeTitle2;

  /// lib/features/wallet/deferred_screens.dart:373
  ///
  /// In en, this message translates to:
  /// **'This URL can\'t be used'**
  String get wallet_deferredScreensS;

  /// lib/features/wallet/deferred_screens.dart:54
  ///
  /// In en, this message translates to:
  /// **'View {title}'**
  String wallet_deferredScreensSemanticsLabel(Object? title);

  /// lib/features/wallet/deferred_screens.dart:494, lib/features/wallet/deferred_screens.dart:496
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get wallet_deferredScreensSubtitle;

  /// lib/features/wallet/deferred_screens.dart:494, lib/features/wallet/deferred_screens.dart:496
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get wallet_deferredScreensSubtitle2;

  /// lib/features/wallet/wallet_home_widgets.dart:542
  ///
  /// In en, this message translates to:
  /// **'Close total assets notes'**
  String get wallet_homeBarrierLabel;

  /// lib/features/wallet/wallet_home_widgets.dart:1276
  ///
  /// In en, this message translates to:
  /// **'Holdings breakdown'**
  String get wallet_homeBuild;

  /// lib/features/wallet/wallet_home_widgets.dart:1669
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get wallet_homeBuild2;

  /// lib/features/wallet/wallet_home_widgets.dart:1062, lib/features/wallet/wallet_home_widgets.dart:1460
  ///
  /// In en, this message translates to:
  /// **'Pending {hidden}'**
  String wallet_homeIf(Object? hidden);

  /// lib/features/wallet/wallet_home_widgets.dart:1063, lib/features/wallet/wallet_home_widgets.dart:1461, lib/features/wallet/wallet_read_screens.dart:1649, lib/features/wallet/wallet_read_widgets.dart:89
  ///
  /// In en, this message translates to:
  /// **'Data sources don\'t match yet'**
  String get wallet_homeIf2;

  /// lib/features/wallet/wallet_home_widgets.dart:210
  ///
  /// In en, this message translates to:
  /// **'{address}, copy wallet address'**
  String wallet_homeLabel(Object? address);

  /// lib/features/wallet/wallet_home_widgets.dart:643
  ///
  /// In en, this message translates to:
  /// **'Snapshot observed'**
  String get wallet_homeLabel10;

  /// lib/features/wallet/wallet_home_widgets.dart:650, lib/features/wallet/wallet_read_screens.dart:1537
  ///
  /// In en, this message translates to:
  /// **'Fee reserve'**
  String get wallet_homeLabel11;

  /// lib/features/wallet/wallet_home_widgets.dart:789
  ///
  /// In en, this message translates to:
  /// **'{label}, not available right now'**
  String wallet_homeLabel12(Object? label);

  /// lib/features/wallet/wallet_home_widgets.dart:1017
  ///
  /// In en, this message translates to:
  /// **'{symbol}, balance can\'t be loaded'**
  String wallet_homeLabel13(Object? symbol);

  /// lib/features/wallet/wallet_home_widgets.dart:1234
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get wallet_homeLabel14;

  /// lib/features/wallet/wallet_home_widgets.dart:1612
  ///
  /// In en, this message translates to:
  /// **'{symbol}, {subtitle}, balance {amount}, value {valueText}{changeText}'**
  String wallet_homeLabel15(
    Object? amount,
    Object? changeText,
    Object? subtitle,
    Object? symbol,
    Object? valueText,
  );

  /// lib/features/wallet/wallet_home_widgets.dart:1647, lib/features/wallet/wallet_read_screens.dart:527
  ///
  /// In en, this message translates to:
  /// **'Wallet management'**
  String get wallet_homeLabel16;

  /// lib/features/wallet/wallet_home_widgets.dart:340
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get wallet_homeLabel2;

  /// lib/features/wallet/wallet_home_widgets.dart:340
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get wallet_homeLabel3;

  /// lib/features/wallet/wallet_home_widgets.dart:587
  ///
  /// In en, this message translates to:
  /// **'Price source'**
  String get wallet_homeLabel4;

  /// lib/features/wallet/wallet_home_widgets.dart:592, lib/features/wallet/wallet_read_screens.dart:3287
  ///
  /// In en, this message translates to:
  /// **'Observed'**
  String get wallet_homeLabel5;

  /// lib/features/wallet/wallet_home_widgets.dart:598
  ///
  /// In en, this message translates to:
  /// **'Not included'**
  String get wallet_homeLabel6;

  /// lib/features/wallet/wallet_home_widgets.dart:603
  ///
  /// In en, this message translates to:
  /// **'24h change'**
  String get wallet_homeLabel7;

  /// lib/features/wallet/wallet_home_widgets.dart:621
  ///
  /// In en, this message translates to:
  /// **'Balance block'**
  String get wallet_homeLabel8;

  /// lib/features/wallet/wallet_home_widgets.dart:637
  ///
  /// In en, this message translates to:
  /// **'Net value snapshot source'**
  String get wallet_homeLabel9;

  /// lib/features/wallet/wallet_home_widgets.dart:909
  ///
  /// In en, this message translates to:
  /// **'Earns power'**
  String get wallet_homeLoopBadge;

  /// lib/features/wallet/wallet_home_widgets.dart:605
  ///
  /// In en, this message translates to:
  /// **'Calculated from the same price read'**
  String get wallet_homeLoopNetWorthChangeAvailable;

  /// lib/features/wallet/wallet_home_widgets.dart:607
  ///
  /// In en, this message translates to:
  /// **'Some assets have no 24h price change, so it\'s hidden for now'**
  String get wallet_homeLoopNetWorthChangeUnavailable;

  /// lib/features/wallet/wallet_home_widgets.dart:553
  ///
  /// In en, this message translates to:
  /// **'About total assets'**
  String get wallet_homeLoopSheetHeading;

  /// lib/features/wallet/wallet_home_widgets.dart:934
  ///
  /// In en, this message translates to:
  /// **'Holdings that earn power'**
  String get wallet_homeLoopSheetHeading2;

  /// lib/features/wallet/wallet_home_widgets.dart:218
  ///
  /// In en, this message translates to:
  /// **'Wallet address copied'**
  String get wallet_homeMessage;

  /// lib/features/wallet/wallet_home_widgets.dart:1036
  ///
  /// In en, this message translates to:
  /// **'Balance can\'t be loaded · {reasonCodeText}'**
  String wallet_homeMessage2(Object? reasonCodeText);

  /// lib/features/wallet/wallet_home_widgets.dart:1078
  ///
  /// In en, this message translates to:
  /// **'Value {valueText}, 24h {walletRowChangeText}'**
  String wallet_homeS(Object? valueText, Object? walletRowChangeText);

  /// lib/features/wallet/wallet_home_widgets.dart:1610
  ///
  /// In en, this message translates to:
  /// **', 24h {changeText}'**
  String wallet_homeSX(Object? changeText);

  /// lib/features/wallet/wallet_home_widgets.dart:1114
  ///
  /// In en, this message translates to:
  /// **'{symbol}, balance {amount}, {valueLabel}'**
  String wallet_homeSemanticLabel(
    Object? amount,
    Object? symbol,
    Object? valueLabel,
  );

  /// lib/features/wallet/wallet_home_widgets.dart:938
  ///
  /// In en, this message translates to:
  /// **'Registered assets in your wallet earn mining power by their weights, and power decides how much LOOP you get each day. Community tokens count only after you join an approved linked community. See each asset\'s weight and power on the Mining page.'**
  String get wallet_homeShowWalletPowerSheet;

  /// lib/features/wallet/wallet_home_widgets.dart:561
  ///
  /// In en, this message translates to:
  /// **'Total assets is the value of registered assets at current prices, for display only; it isn\'t an available balance. The usable amount is the \"Usable\" figure on each asset page.'**
  String get wallet_homeShowWalletTotalInfoSheet;

  /// lib/features/wallet/wallet_home_widgets.dart:1077
  ///
  /// In en, this message translates to:
  /// **'Value {valueText}'**
  String wallet_homeSwitch(Object? valueText);

  /// lib/features/wallet/wallet_home_widgets.dart:337, lib/features/wallet/wallet_home_widgets.dart:615
  ///
  /// In en, this message translates to:
  /// **'Total assets'**
  String get wallet_homeText;

  /// lib/features/wallet/wallet_home_widgets.dart:146
  ///
  /// In en, this message translates to:
  /// **'Not available right now'**
  String get wallet_homeUnreadText;

  /// lib/features/wallet/wallet_home_widgets.dart:599
  ///
  /// In en, this message translates to:
  /// **'{unavailableCount, plural, =1{1 asset has no price yet} other{{unavailableCount} assets have no price yet}}'**
  String wallet_homeValue(num unavailableCount);

  /// lib/features/wallet/wallet_home_widgets.dart:1080, lib/features/wallet/wallet_home_widgets.dart:1082, lib/features/wallet/wallet_home_widgets.dart:1483
  ///
  /// In en, this message translates to:
  /// **'No value yet'**
  String get wallet_homeValueText;

  /// lib/features/wallet/wallet_home_widgets.dart:1270
  ///
  /// In en, this message translates to:
  /// **'Holdings breakdown, {label}'**
  String wallet_homeWalletDistributionBarLabel(Object? label);

  /// lib/features/wallet/wallet_home_widgets.dart:925
  ///
  /// In en, this message translates to:
  /// **'Close power notes'**
  String get wallet_homeWalletPowerSheetBarrierLabel;

  /// lib/features/wallet/wallet_home_widgets.dart:898
  ///
  /// In en, this message translates to:
  /// **'Holdings earn power, view notes'**
  String get wallet_homeWalletPowerTagLabel;

  /// lib/features/wallet/wallet_home_widgets.dart:125
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 asset has no price yet, not included} other{{count} assets have no price yet, not included}}'**
  String wallet_homeWalletRowChangeUsd(num count);

  /// lib/features/wallet/wallet_mining_hooks.dart:77
  ///
  /// In en, this message translates to:
  /// **'No weight'**
  String get wallet_miningHooksFor;

  /// lib/features/wallet/wallet_mining_hooks.dart:120
  ///
  /// In en, this message translates to:
  /// **'{power} power'**
  String wallet_miningHooksLoopPowerHint(Object? power);

  /// lib/features/wallet/wallet_mining_hooks.dart:122
  ///
  /// In en, this message translates to:
  /// **'No estimate for today yet'**
  String get wallet_miningHooksLoopPowerHint2;

  /// lib/features/wallet/wallet_mining_hooks.dart:164
  ///
  /// In en, this message translates to:
  /// **'{powerFigure} power'**
  String wallet_miningHooksLoopPowerHint3(Object? powerFigure);

  /// lib/features/wallet/wallet_mining_hooks.dart:165
  ///
  /// In en, this message translates to:
  /// **'Weight {weight}×'**
  String wallet_miningHooksLoopPowerHint4(Object? weight);

  /// lib/features/wallet/wallet_mining_hooks.dart:122
  ///
  /// In en, this message translates to:
  /// **'Est. today {daily} LOOP'**
  String wallet_miningHooksS(Object? daily);

  /// lib/features/wallet/wallet_mining_hooks.dart:153, lib/features/wallet/wallet_mining_hooks.dart:162
  ///
  /// In en, this message translates to:
  /// **'This asset\'s mining contribution'**
  String get wallet_miningHooksWalletAssetPowerHintText;

  /// lib/features/wallet/wallet_mining_hooks.dart:73, lib/features/wallet/wallet_mining_hooks.dart:79
  ///
  /// In en, this message translates to:
  /// **'Power {loopFigureDash}'**
  String wallet_miningHooksWalletAssetPowerText(Object? loopFigureDash);

  /// lib/features/wallet/wallet_mining_hooks.dart:75
  ///
  /// In en, this message translates to:
  /// **'Power {powerFigure}'**
  String wallet_miningHooksWalletAssetPowerText2(Object? powerFigure);

  /// lib/features/wallet/wallet_mining_hooks.dart:118
  ///
  /// In en, this message translates to:
  /// **'Wallet holdings are earning power'**
  String get wallet_miningHooksWalletPowerHintText;

  /// lib/features/wallet/wallet_mining_hooks.dart:118
  ///
  /// In en, this message translates to:
  /// **'Wallet holdings earn power by weight'**
  String get wallet_miningHooksWalletPowerHintText2;

  /// lib/features/wallet/money_actions_signing.dart:290
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get wallet_moneyActionNameApprove;

  /// lib/features/wallet/money_actions_signing.dart:290
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get wallet_moneyActionNameRevoke;

  /// lib/features/wallet/money_actions_signing.dart:290
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get wallet_moneyActionNameSend;

  /// lib/features/wallet/money_actions_signing.dart:290
  ///
  /// In en, this message translates to:
  /// **'NFT send'**
  String get wallet_moneyActionNameSendNft;

  /// lib/features/wallet/money_actions_signing.dart:290
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get wallet_moneyActionNameSwap;

  /// lib/features/wallet/money_actions_widgets.dart:499
  ///
  /// In en, this message translates to:
  /// **'This asset is blocked; no fund actions are allowed.'**
  String get wallet_moneyActionsAssetBlocked;

  /// lib/features/wallet/money_actions_widgets.dart:485
  ///
  /// In en, this message translates to:
  /// **'This asset isn\'t in the current range of supported assets, so this action didn\'t pass. LOOP maintains the range and it can\'t be changed in the app; use an asset within the range.'**
  String get wallet_moneyActionsAssetNotInAllowlist;

  /// lib/features/wallet/money_actions_widgets.dart:380
  ///
  /// In en, this message translates to:
  /// **'{moneyActionTitle} · Final confirmation'**
  String wallet_moneyActionsBuild(Object? moneyActionTitle);

  /// lib/features/wallet/money_actions_widgets.dart:387
  ///
  /// In en, this message translates to:
  /// **'Unlimited {symbol}'**
  String wallet_moneyActionsBuild2(Object? symbol);

  /// lib/features/wallet/money_actions_widgets.dart:394
  ///
  /// In en, this message translates to:
  /// **'No fresh market data this time, so no value is shown.'**
  String get wallet_moneyActionsBuild3;

  /// lib/features/wallet/money_actions_widgets.dart:491
  ///
  /// In en, this message translates to:
  /// **'{figures}This action exceeds the per-transaction limit. No transaction was submitted. LOOP sets the limit; lower the amount and try again.'**
  String wallet_moneyActionsCanaryCeilingExceeded(Object? figures);

  /// lib/features/wallet/money_actions_widgets.dart:494
  ///
  /// In en, this message translates to:
  /// **'{figures}{budget}This action would exceed the 24-hour cumulative limit. No transaction was submitted. LOOP sets the limit; lower the amount, or wait until the 24-hour window rolls over.'**
  String wallet_moneyActionsCanaryDailyCeilingExceeded(
    Object? budget,
    Object? figures,
  );

  /// lib/features/wallet/money_actions_widgets.dart:488
  ///
  /// In en, this message translates to:
  /// **'This recipient address isn\'t on the current allowed list, so this action didn\'t pass and no transaction was submitted. LOOP maintains the list and it can\'t be changed in the app; use an address on the list.'**
  String get wallet_moneyActionsCounterpartyNotInAllowlist;

  /// lib/features/wallet/money_actions_widgets.dart:32
  ///
  /// In en, this message translates to:
  /// **'Checking availability'**
  String get wallet_moneyActionsMoneyCapabilityCheckingLabel;

  /// lib/features/wallet/money_actions_widgets.dart:137
  ///
  /// In en, this message translates to:
  /// **'Block {groupedFigure} · {observed}'**
  String wallet_moneyActionsMoneyFactsFooterText(
    Object? groupedFigure,
    Object? observed,
  );

  /// lib/features/wallet/money_actions_widgets.dart:474
  ///
  /// In en, this message translates to:
  /// **'This time \${exposureUsd} · limit \${ceilingUsd}. '**
  String wallet_moneyActionsMoneyPolicyRefusalText(
    Object? ceilingUsd,
    Object? exposureUsd,
  );

  /// lib/features/wallet/money_actions_widgets.dart:481
  ///
  /// In en, this message translates to:
  /// **'Used \${spentUsd} in 24 hours · \${remainingUsd} left. '**
  String wallet_moneyActionsMoneyPolicyRefusalText2(
    Object? remainingUsd,
    Object? spentUsd,
  );

  /// lib/features/wallet/money_actions_widgets.dart:502
  ///
  /// In en, this message translates to:
  /// **'Native BNB has no approvals: it isn\'t ERC-20 and has no allowance to approve or revoke. This step doesn\'t apply to native assets.'**
  String get wallet_moneyActionsNativeAssetNotApprovable;

  /// lib/features/wallet/money_actions_widgets.dart:132
  ///
  /// In en, this message translates to:
  /// **'Facts observed {relativeTime}'**
  String wallet_moneyActionsObserved(Object? relativeTime);

  /// lib/features/wallet/money_actions_widgets.dart:500
  ///
  /// In en, this message translates to:
  /// **'The price impact of this swap is too high, so it was blocked. Lower the amount or try again later.'**
  String get wallet_moneyActionsPriceImpactBlocked;

  /// lib/features/wallet/money_actions_widgets.dart:556
  ///
  /// In en, this message translates to:
  /// **'This step requires two-step verification, which isn\'t available yet. Nothing was signed, broadcast or submitted. Check the verification methods available in Security Center.'**
  String get wallet_moneyActionsPurpose;

  /// lib/features/wallet/money_actions_widgets.dart:285
  ///
  /// In en, this message translates to:
  /// **'Submitted, waiting for the on-chain receipt. A success message doesn\'t mean it\'s done on-chain.'**
  String get wallet_moneyActionsReason;

  /// lib/features/wallet/money_actions_widgets.dart:288
  ///
  /// In en, this message translates to:
  /// **'This action was submitted and the result is unknown, so it\'s locked. Check the result page; don\'t submit again.'**
  String get wallet_moneyActionsReason2;

  /// lib/features/wallet/money_actions_widgets.dart:295
  ///
  /// In en, this message translates to:
  /// **'The wallet broadcast it ({txHash}), but this report wasn\'t accepted. The transaction may already be on-chain. Check the result page and report again later; don\'t sign again.'**
  String wallet_moneyActionsS(Object? txHash);

  /// lib/features/wallet/money_actions_widgets.dart:395
  ///
  /// In en, this message translates to:
  /// **'Estimated value {formatUsd} · source {intent}'**
  String wallet_moneyActionsS2(Object? formatUsd, Object? intent);

  /// lib/features/wallet/money_actions_widgets.dart:294
  ///
  /// In en, this message translates to:
  /// **'The wallet signed, but this submission hasn\'t been recorded yet. Check the status on the result page; don\'t sign again.'**
  String get wallet_moneyActionsSetState;

  /// lib/features/wallet/money_actions_widgets.dart:307
  ///
  /// In en, this message translates to:
  /// **'The wallet didn\'t finish signing. No transaction was submitted.'**
  String get wallet_moneyActionsSetState2;

  /// lib/features/wallet/money_actions_signing.dart:284
  ///
  /// In en, this message translates to:
  /// **'Confirm approval'**
  String get wallet_moneyActionsSigningApprove;

  /// lib/features/wallet/money_actions_signing.dart:318, lib/features/wallet/money_actions_signing.dart:342, lib/features/wallet/send_screens.dart:1595, lib/features/wallet/send_screens.dart:1743
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get wallet_moneyActionsSigningLabel;

  /// lib/features/wallet/money_actions_signing.dart:331
  ///
  /// In en, this message translates to:
  /// **'Allowance'**
  String get wallet_moneyActionsSigningLabel2;

  /// lib/features/wallet/money_actions_signing.dart:381, lib/features/wallet/send_screens.dart:1597, lib/features/wallet/tx_result_screen.dart:425
  ///
  /// In en, this message translates to:
  /// **'Max network fee'**
  String get wallet_moneyActionsSigningLabel3;

  /// lib/features/wallet/money_actions_signing.dart:285
  ///
  /// In en, this message translates to:
  /// **'Confirm revoke'**
  String get wallet_moneyActionsSigningRevoke;

  /// lib/features/wallet/money_actions_signing.dart:283, lib/features/wallet/send_screens.dart:1201
  ///
  /// In en, this message translates to:
  /// **'Confirm send'**
  String get wallet_moneyActionsSigningSend;

  /// lib/features/wallet/money_actions_signing.dart:287, lib/features/wallet/send_screens.dart:1201
  ///
  /// In en, this message translates to:
  /// **'Confirm NFT send'**
  String get wallet_moneyActionsSigningSendNft;

  /// lib/features/wallet/money_actions_signing.dart:286
  ///
  /// In en, this message translates to:
  /// **'Confirm swap'**
  String get wallet_moneyActionsSigningSwap;

  /// lib/features/wallet/approval_screens.dart:656
  ///
  /// In en, this message translates to:
  /// **'Unlimited allowance'**
  String get wallet_moneyActionsSigningValue;

  /// lib/features/wallet/money_actions_widgets.dart:504
  ///
  /// In en, this message translates to:
  /// **'The current policy doesn\'t allow this action. No transaction was submitted. We won\'t guess which rule applies.'**
  String get wallet_moneyActionsSwitch;

  /// lib/features/wallet/money_actions_widgets.dart:549
  ///
  /// In en, this message translates to:
  /// **'This step requires two-step verification; no transaction was submitted'**
  String get wallet_moneyActionsTitle;

  /// lib/features/wallet/money_actions_widgets.dart:551
  ///
  /// In en, this message translates to:
  /// **'This action isn\'t available in your region; no transaction was submitted'**
  String get wallet_moneyActionsTitle2;

  /// lib/features/wallet/money_actions_widgets.dart:553
  ///
  /// In en, this message translates to:
  /// **'Native assets can\'t be approved'**
  String get wallet_moneyActionsTitle3;

  /// lib/features/wallet/money_actions_widgets.dart:554
  ///
  /// In en, this message translates to:
  /// **'Rejected by policy; no transaction was submitted'**
  String get wallet_moneyActionsTitle4;

  /// lib/features/wallet/money_actions_widgets.dart:51
  ///
  /// In en, this message translates to:
  /// **'Unknown (locked)'**
  String get wallet_moneyActionsUnknown;

  /// lib/features/wallet/money_actions_widgets.dart:497
  ///
  /// In en, this message translates to:
  /// **'{figures}An unlimited approval\'s exposure is based on the current balance and exceeds the per-transaction limit. Use a limited approval, or lower this asset\'s balance first.'**
  String wallet_moneyActionsUnlimitedExposureExceedsCeiling(Object? figures);

  /// lib/features/wallet/money_actions_widgets.dart:391, lib/features/wallet/swap_screens.dart:1030
  ///
  /// In en, this message translates to:
  /// **'Not labeled'**
  String get wallet_moneyActionsWalletMoneyActionsS2;

  /// lib/features/wallet/money_asset_picker.dart:147
  ///
  /// In en, this message translates to:
  /// **'Search name or symbol'**
  String get wallet_moneyAssetPickerHintText;

  /// lib/features/wallet/money_asset_picker.dart:101
  ///
  /// In en, this message translates to:
  /// **'{name} · Usable {formatDecimal}'**
  String wallet_moneyAssetPickerLoopBalanceAvailable(
    Object? formatDecimal,
    Object? name,
  );

  /// lib/features/wallet/money_asset_picker.dart:179
  ///
  /// In en, this message translates to:
  /// **'Zero-balance assets · {folded}'**
  String wallet_moneyAssetPickerSummary(Object? folded);

  /// lib/features/wallet/money_asset_picker.dart:39, lib/features/wallet/money_asset_picker.dart:59
  ///
  /// In en, this message translates to:
  /// **'Choose asset'**
  String get wallet_moneyAssetPickerTitle;

  /// lib/features/wallet/money_asset_picker.dart:159, lib/features/wallet/send_screens.dart:848, lib/features/wallet/swap_screens.dart:210, lib/features/wallet/wallet_read_screens.dart:752
  ///
  /// In en, this message translates to:
  /// **'This wallet has no readable assets yet'**
  String get wallet_moneyAssetPickerTitle2;

  /// lib/features/wallet/money_asset_picker.dart:159
  ///
  /// In en, this message translates to:
  /// **'No matching assets'**
  String get wallet_moneyAssetPickerTitle3;

  /// lib/features/wallet/money_asset_picker.dart:167, lib/features/wallet/send_screens.dart:878
  ///
  /// In en, this message translates to:
  /// **'No assets with a usable balance'**
  String get wallet_moneyAssetPickerTitle4;

  /// lib/features/wallet/wallet_networth_widgets.dart:419
  ///
  /// In en, this message translates to:
  /// **'Collapse net value trend'**
  String get wallet_networthBuild;

  /// lib/features/wallet/wallet_networth_widgets.dart:437
  ///
  /// In en, this message translates to:
  /// **'Today\'s P&L'**
  String get wallet_networthBuild2;

  /// lib/features/wallet/wallet_networth_widgets.dart:141
  ///
  /// In en, this message translates to:
  /// **'The trend is the USD value the server records hourly for this wallet, for display only; it isn\'t an available balance.'**
  String get wallet_networthDetail;

  /// lib/features/wallet/wallet_networth_widgets.dart:185
  ///
  /// In en, this message translates to:
  /// **'CNY converted at {walletFxSourceLabel} 1 USD = {rate} CNY (published {published}, observed {observed}){stale}'**
  String wallet_networthIf(
    Object? observed,
    Object? published,
    Object? rate,
    Object? stale,
    Object? walletFxSourceLabel,
  );

  /// lib/features/wallet/wallet_networth_widgets.dart:423
  ///
  /// In en, this message translates to:
  /// **'Today\'s P&L {value}, {action}'**
  String wallet_networthLabel(Object? action, Object? value);

  /// lib/features/wallet/wallet_networth_widgets.dart:419
  ///
  /// In en, this message translates to:
  /// **'Expand net value trend'**
  String get wallet_networthS;

  /// lib/features/wallet/wallet_networth_widgets.dart:139
  ///
  /// In en, this message translates to:
  /// **'LOOP net value snapshot'**
  String get wallet_networthSource;

  /// lib/features/wallet/wallet_networth_widgets.dart:148
  ///
  /// In en, this message translates to:
  /// **'ECB reference rate'**
  String get wallet_networthSwitch;

  /// lib/features/wallet/wallet_networth_widgets.dart:149
  ///
  /// In en, this message translates to:
  /// **'Reference rate'**
  String get wallet_networthSwitch2;

  /// lib/features/wallet/wallet_networth_widgets.dart:86
  ///
  /// In en, this message translates to:
  /// **'No net value records in this range yet · recorded hourly; the line starts once you have assets'**
  String get wallet_networthWalletNetworthChartEmptyMessage;

  /// lib/features/wallet/wallet_networth_widgets.dart:215
  ///
  /// In en, this message translates to:
  /// **'{label} net value trend, high {highText}, low {lowText}'**
  String wallet_networthWalletNetworthChartLabel(
    Object? highText,
    Object? label,
    Object? lowText,
  );

  /// lib/features/wallet/wallet_networth_widgets.dart:100
  ///
  /// In en, this message translates to:
  /// **'Net value trend can\'t be loaded right now'**
  String get wallet_networthWalletNetworthChartUnavailableMessage;

  /// lib/features/wallet/wallet_networth_widgets.dart:477
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get wallet_networthWalletNetworthChevronLabel;

  /// lib/features/wallet/wallet_networth_widgets.dart:477
  ///
  /// In en, this message translates to:
  /// **'Net value trend'**
  String get wallet_networthWalletNetworthChevronLabel2;

  /// lib/features/wallet/wallet_networth_widgets.dart:116
  ///
  /// In en, this message translates to:
  /// **'Net value trend range'**
  String get wallet_networthWalletNetworthRangesSemanticLabel;

  /// lib/features/wallet/nft_send.dart:118
  ///
  /// In en, this message translates to:
  /// **'Sending this NFT isn\'t supported yet'**
  String get wallet_nftSendContractUnsupported;

  /// lib/features/wallet/nft_send.dart:129
  ///
  /// In en, this message translates to:
  /// **'This send was already submitted. Check the latest status'**
  String get wallet_nftSendIdempotencyConflict;

  /// lib/features/wallet/nft_send.dart:128
  ///
  /// In en, this message translates to:
  /// **'Not enough {loopLaunchNativeSymbolText} for fees. Top up and try again'**
  String wallet_nftSendInsufficientBalance(Object? loopLaunchNativeSymbolText);

  /// lib/features/wallet/nft_send.dart:96
  ///
  /// In en, this message translates to:
  /// **'Sending NFTs isn\'t supported yet'**
  String get wallet_nftSendNftSendDisabledText;

  /// lib/features/wallet/nft_send.dart:116
  ///
  /// In en, this message translates to:
  /// **'This NFT is no longer in your wallet. Go back and choose again'**
  String get wallet_nftSendNotOwned;

  /// lib/features/wallet/nft_send.dart:120
  ///
  /// In en, this message translates to:
  /// **'The recipient address doesn\'t accept this NFT'**
  String get wallet_nftSendRecipientRejects;

  /// lib/features/wallet/nft_send.dart:122
  ///
  /// In en, this message translates to:
  /// **'You can\'t send to yourself'**
  String get wallet_nftSendRecipientSelf;

  /// lib/features/wallet/nft_send.dart:131
  ///
  /// In en, this message translates to:
  /// **'This send didn\'t pass simulation. Try again later'**
  String get wallet_nftSendSimulationFailed;

  /// lib/features/wallet/wallet_read_widgets.dart:657
  ///
  /// In en, this message translates to:
  /// **'Usable {hidden}'**
  String wallet_readBuild(Object? hidden);

  /// lib/features/wallet/wallet_read_widgets.dart:263
  ///
  /// In en, this message translates to:
  /// **'Buyback · {ticker}'**
  String wallet_readBuyback(Object? ticker);

  /// lib/features/wallet/wallet_read_widgets.dart:823
  ///
  /// In en, this message translates to:
  /// **'Requesting an embedded wallet from Privy; the list refreshes automatically when done.'**
  String get wallet_readCreating;

  /// lib/features/wallet/wallet_read_widgets.dart:825
  ///
  /// In en, this message translates to:
  /// **'The last creation didn\'t finish: {provisioning} Your sign-in is unchanged; you can try again.'**
  String wallet_readFailed(Object? provisioning);

  /// lib/features/wallet/wallet_read_widgets.dart:512, lib/features/wallet/wallet_read_widgets.dart:559
  ///
  /// In en, this message translates to:
  /// **'Only the sum of valued assets, not total assets'**
  String get wallet_readIf;

  /// lib/features/wallet/wallet_read_widgets.dart:532
  ///
  /// In en, this message translates to:
  /// **'Net value ({valuationCurrency})'**
  String wallet_readIf2(Object? valuationCurrency);

  /// lib/features/wallet/wallet_read_widgets.dart:838
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get wallet_readLabel;

  /// lib/features/wallet/wallet_read_widgets.dart:838
  ///
  /// In en, this message translates to:
  /// **'Create wallet'**
  String get wallet_readLabel2;

  /// lib/features/wallet/wallet_read_widgets.dart:878
  ///
  /// In en, this message translates to:
  /// **'Loading list'**
  String get wallet_readLabel3;

  /// lib/features/wallet/wallet_read_widgets.dart:961
  ///
  /// In en, this message translates to:
  /// **'Loading receiving address'**
  String get wallet_readLabel4;

  /// lib/features/wallet/wallet_read_widgets.dart:81, lib/features/wallet/wallet_read_widgets.dart:130
  ///
  /// In en, this message translates to:
  /// **'Usable {formatDecimal}'**
  String wallet_readLoopBalanceAvailable(Object? formatDecimal);

  /// lib/features/wallet/wallet_read_widgets.dart:139, lib/features/wallet/wallet_read_widgets.dart:654
  ///
  /// In en, this message translates to:
  /// **'Fee reserve {formatDecimal}'**
  String wallet_readLoopBalanceAvailable2(Object? formatDecimal);

  /// lib/features/wallet/wallet_read_widgets.dart:128
  ///
  /// In en, this message translates to:
  /// **'Usable {reasonCodeText}'**
  String wallet_readLoopBalanceUnavailable(Object? reasonCodeText);

  /// lib/features/wallet/wallet_read_widgets.dart:137
  ///
  /// In en, this message translates to:
  /// **'Fee reserve {reasonCodeText}'**
  String wallet_readLoopBalanceUnavailable2(Object? reasonCodeText);

  /// lib/features/wallet/wallet_read_widgets.dart:816
  ///
  /// In en, this message translates to:
  /// **'Development preview doesn\'t create a real wallet or call Privy.'**
  String get wallet_readMessage;

  /// lib/features/wallet/wallet_read_widgets.dart:817
  ///
  /// In en, this message translates to:
  /// **'This session isn\'t verified, so a wallet can\'t be created right now. Sign in again and retry.'**
  String get wallet_readMessage2;

  /// lib/features/wallet/wallet_read_widgets.dart:853
  ///
  /// In en, this message translates to:
  /// **'Wallet created'**
  String get wallet_readMessage3;

  /// lib/features/wallet/wallet_read_models.dart:842
  ///
  /// In en, this message translates to:
  /// **'1D'**
  String get wallet_readModelsDay;

  /// lib/features/wallet/wallet_read_models.dart:845
  ///
  /// In en, this message translates to:
  /// **'180D'**
  String get wallet_readModelsHalfYear;

  /// lib/features/wallet/wallet_read_models.dart:844
  ///
  /// In en, this message translates to:
  /// **'30D'**
  String get wallet_readModelsMonth;

  /// lib/features/wallet/wallet_read_models.dart:832
  ///
  /// In en, this message translates to:
  /// **'Only receives assets on the BNB Smart Chain (BSC) network. Assets sent to this address from other networks may be lost permanently.'**
  String get wallet_readModelsSwitch;

  /// lib/features/wallet/wallet_read_models.dart:833
  ///
  /// In en, this message translates to:
  /// **'Make sure the sender\'s network matches the one shown here.'**
  String get wallet_readModelsSwitch2;

  /// lib/features/wallet/wallet_read_models.dart:843
  ///
  /// In en, this message translates to:
  /// **'7D'**
  String get wallet_readModelsWeek;

  /// lib/features/wallet/wallet_read_models.dart:846
  ///
  /// In en, this message translates to:
  /// **'360D'**
  String get wallet_readModelsYear;

  /// lib/features/wallet/wallet_read_widgets.dart:261
  ///
  /// In en, this message translates to:
  /// **'Mint badge · {ticker}'**
  String wallet_readNftMint(Object? ticker);

  /// lib/features/wallet/wallet_read_widgets.dart:258
  ///
  /// In en, this message translates to:
  /// **'Buy {ticker}'**
  String wallet_readPoolBuy(Object? ticker);

  /// lib/features/wallet/wallet_read_widgets.dart:260
  ///
  /// In en, this message translates to:
  /// **'Sell {ticker}'**
  String wallet_readPoolSell(Object? ticker);

  /// lib/features/wallet/wallet_read_widgets.dart:262
  ///
  /// In en, this message translates to:
  /// **'Claim rewards · {ticker}'**
  String wallet_readRewardClaim(Object? ticker);

  /// lib/features/wallet/wallet_read_widgets.dart:114
  ///
  /// In en, this message translates to:
  /// **'Balance {amount}'**
  String wallet_readRowBalance(Object? amount);

  /// lib/features/wallet/wallet_read_widgets.dart:114
  ///
  /// In en, this message translates to:
  /// **'Balance can\'t be loaded'**
  String get wallet_readRowBalanceMissing;

  /// lib/features/wallet/wallet_read_widgets.dart:87
  ///
  /// In en, this message translates to:
  /// **'Pending {formatDecimal}'**
  String wallet_readS(Object? formatDecimal);

  /// lib/features/wallet/wallet_read_screens.dart:936
  ///
  /// In en, this message translates to:
  /// **'This account doesn\'t have permission to read balances'**
  String get wallet_readScreensBalancesFailureLine;

  /// lib/features/wallet/wallet_read_screens.dart:3355
  ///
  /// In en, this message translates to:
  /// **'Native transfers'**
  String get wallet_readScreensBuild;

  /// lib/features/wallet/wallet_read_screens.dart:3355
  ///
  /// In en, this message translates to:
  /// **'Bridge / Mining'**
  String get wallet_readScreensBuild2;

  /// lib/features/wallet/wallet_read_screens.dart:1875, lib/features/wallet/wallet_read_screens.dart:1886
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get wallet_readScreensCopy;

  /// lib/features/wallet/wallet_read_screens.dart:538, lib/features/wallet/wallet_read_screens.dart:2244
  ///
  /// In en, this message translates to:
  /// **'The wallet list hasn\'t loaded yet'**
  String get wallet_readScreensEmptyMessage;

  /// lib/features/wallet/wallet_read_screens.dart:1149
  ///
  /// In en, this message translates to:
  /// **'This wallet doesn\'t have this row'**
  String get wallet_readScreensEmptyMessage2;

  /// lib/features/wallet/wallet_read_screens.dart:1441, lib/features/wallet/wallet_read_screens.dart:1461
  ///
  /// In en, this message translates to:
  /// **'No transfers for this asset yet'**
  String get wallet_readScreensEmptyMessage3;

  /// lib/features/wallet/wallet_read_screens.dart:1830
  ///
  /// In en, this message translates to:
  /// **'No receiving address available'**
  String get wallet_readScreensEmptyMessage4;

  /// lib/features/wallet/wallet_read_screens.dart:2279
  ///
  /// In en, this message translates to:
  /// **'No embedded wallet'**
  String get wallet_readScreensEmptyMessage5;

  /// lib/features/wallet/wallet_read_screens.dart:2291
  ///
  /// In en, this message translates to:
  /// **'No connected external wallets'**
  String get wallet_readScreensEmptyMessage6;

  /// lib/features/wallet/wallet_read_screens.dart:2914, lib/features/wallet/wallet_read_screens.dart:3186
  ///
  /// In en, this message translates to:
  /// **'No on-chain activity yet'**
  String get wallet_readScreensEmptyMessage7;

  /// lib/features/wallet/wallet_read_screens.dart:3465
  ///
  /// In en, this message translates to:
  /// **'No networks to show'**
  String get wallet_readScreensEmptyMessage8;

  /// lib/features/wallet/wallet_read_screens.dart:2245
  ///
  /// In en, this message translates to:
  /// **'This isn\'t \"no wallet\"; the list just wasn\'t loaded this time.'**
  String get wallet_readScreensEmptyReason;

  /// lib/features/wallet/wallet_read_screens.dart:2915
  ///
  /// In en, this message translates to:
  /// **'The indexer has read this range, but it has no transfers for this wallet.'**
  String get wallet_readScreensEmptyReason2;

  /// lib/features/wallet/wallet_read_screens.dart:2750
  ///
  /// In en, this message translates to:
  /// **'External wallet'**
  String get wallet_readScreensExternalWalletKind;

  /// lib/features/wallet/wallet_read_screens.dart:3658
  ///
  /// In en, this message translates to:
  /// **'Latency {best}ms'**
  String wallet_readScreensFor(Object? best);

  /// lib/features/wallet/wallet_read_screens.dart:3658, lib/features/wallet/wallet_read_screens.dart:3685
  ///
  /// In en, this message translates to:
  /// **'Latency unknown'**
  String get wallet_readScreensFor2;

  /// lib/features/wallet/wallet_read_screens.dart:1338
  ///
  /// In en, this message translates to:
  /// **'{ticker} · balance not loaded yet'**
  String wallet_readScreensIf(Object? ticker);

  /// lib/features/wallet/wallet_read_screens.dart:1726
  ///
  /// In en, this message translates to:
  /// **'Name and decimals come only from on-chain calls'**
  String get wallet_readScreensIf2;

  /// lib/features/wallet/wallet_read_screens.dart:1728
  ///
  /// In en, this message translates to:
  /// **'Block height {groupedFigure}'**
  String wallet_readScreensIf3(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:1730
  ///
  /// In en, this message translates to:
  /// **'Checked {relativeTime}'**
  String wallet_readScreensIf4(Object? relativeTime);

  /// lib/features/wallet/wallet_read_screens.dart:1177, lib/features/wallet/wallet_read_screens.dart:1525
  ///
  /// In en, this message translates to:
  /// **'On-chain balance'**
  String get wallet_readScreensLabel;

  /// lib/features/wallet/wallet_read_screens.dart:1714
  ///
  /// In en, this message translates to:
  /// **'Balance in base units (integer, {decimals} decimals)'**
  String wallet_readScreensLabel10(Object? decimals);

  /// lib/features/wallet/wallet_read_screens.dart:1717
  ///
  /// In en, this message translates to:
  /// **'Registration status'**
  String get wallet_readScreensLabel11;

  /// lib/features/wallet/wallet_read_screens.dart:1720
  ///
  /// In en, this message translates to:
  /// **'Contract address'**
  String get wallet_readScreensLabel12;

  /// lib/features/wallet/wallet_read_screens.dart:2005
  ///
  /// In en, this message translates to:
  /// **'Network {name}'**
  String wallet_readScreensLabel13(Object? name);

  /// lib/features/wallet/wallet_read_screens.dart:2979
  ///
  /// In en, this message translates to:
  /// **'Native BNB transfers unavailable'**
  String get wallet_readScreensLabel14;

  /// lib/features/wallet/wallet_read_screens.dart:2987
  ///
  /// In en, this message translates to:
  /// **'Bridge and mining claim history unavailable'**
  String get wallet_readScreensLabel15;

  /// lib/features/wallet/wallet_read_screens.dart:3000
  ///
  /// In en, this message translates to:
  /// **'MEME records not available right now'**
  String get wallet_readScreensLabel16;

  /// lib/features/wallet/wallet_read_screens.dart:1186
  ///
  /// In en, this message translates to:
  /// **'Usable'**
  String get wallet_readScreensLabel2;

  /// lib/features/wallet/wallet_read_screens.dart:1195
  ///
  /// In en, this message translates to:
  /// **'Current price'**
  String get wallet_readScreensLabel3;

  /// lib/features/wallet/wallet_read_screens.dart:1204, lib/features/wallet/wallet_read_screens.dart:1594
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get wallet_readScreensLabel4;

  /// lib/features/wallet/wallet_read_screens.dart:1529
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get wallet_readScreensLabel5;

  /// lib/features/wallet/wallet_read_screens.dart:1533
  ///
  /// In en, this message translates to:
  /// **'Usable (after fee reserve)'**
  String get wallet_readScreensLabel6;

  /// lib/features/wallet/wallet_read_screens.dart:1552
  ///
  /// In en, this message translates to:
  /// **'Pending incoming (not included in available)'**
  String get wallet_readScreensLabel7;

  /// lib/features/wallet/wallet_read_screens.dart:1593
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get wallet_readScreensLabel8;

  /// lib/features/wallet/wallet_read_screens.dart:1709
  ///
  /// In en, this message translates to:
  /// **'Decimals'**
  String get wallet_readScreensLabel9;

  /// lib/features/wallet/wallet_read_screens.dart:3721
  ///
  /// In en, this message translates to:
  /// **'{name} (Launch)'**
  String wallet_readScreensLaunchChainTitle(Object? name);

  /// lib/features/wallet/wallet_read_screens.dart:1606
  ///
  /// In en, this message translates to:
  /// **'Data may be out of date'**
  String get wallet_readScreensLoopBadge;

  /// lib/features/wallet/wallet_read_screens.dart:2763
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get wallet_readScreensLoopBadge2;

  /// lib/features/wallet/wallet_read_screens.dart:2765
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get wallet_readScreensLoopBadge3;

  /// lib/features/wallet/wallet_read_screens.dart:3547
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get wallet_readScreensLoopBadge4;

  /// lib/features/wallet/wallet_read_screens.dart:3618
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get wallet_readScreensLoopBadge5;

  /// lib/features/wallet/wallet_read_screens.dart:1126
  ///
  /// In en, this message translates to:
  /// **'Balance not loaded yet'**
  String get wallet_readScreensLoopFolioPrimary;

  /// lib/features/wallet/wallet_read_screens.dart:1216
  ///
  /// In en, this message translates to:
  /// **'Mining contribution'**
  String get wallet_readScreensLoopLabel;

  /// lib/features/wallet/wallet_read_screens.dart:1256
  ///
  /// In en, this message translates to:
  /// **'On-chain breakdown'**
  String get wallet_readScreensLoopLabel2;

  /// lib/features/wallet/wallet_read_screens.dart:1277
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get wallet_readScreensLoopLabel3;

  /// lib/features/wallet/wallet_read_screens.dart:2272
  ///
  /// In en, this message translates to:
  /// **'Embedded wallet'**
  String get wallet_readScreensLoopLabel4;

  /// lib/features/wallet/wallet_read_screens.dart:2281
  ///
  /// In en, this message translates to:
  /// **'External wallets'**
  String get wallet_readScreensLoopLabel5;

  /// lib/features/wallet/wallet_read_screens.dart:3477
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get wallet_readScreensLoopLabel6;

  /// lib/features/wallet/wallet_read_screens.dart:3577
  ///
  /// In en, this message translates to:
  /// **'RPC endpoints'**
  String get wallet_readScreensLoopLabel7;

  /// lib/features/wallet/wallet_read_screens.dart:3596
  ///
  /// In en, this message translates to:
  /// **'Indexer'**
  String get wallet_readScreensLoopLabel8;

  /// lib/features/wallet/wallet_read_screens.dart:2260, lib/features/wallet/wallet_read_screens.dart:2664
  ///
  /// In en, this message translates to:
  /// **'Switch active wallet'**
  String get wallet_readScreensLoopOfflineState;

  /// lib/features/wallet/wallet_read_screens.dart:2940
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get wallet_readScreensLoopOfflineState2;

  /// lib/features/wallet/wallet_read_screens.dart:2303
  ///
  /// In en, this message translates to:
  /// **'Holdings in all linked wallets count toward power, no need to move them. LOOP ID is your identity; wallets are replaceable credentials and addresses aren\'t account identifiers.'**
  String get wallet_readScreensLoopProvenanceFooter;

  /// lib/features/wallet/wallet_read_screens.dart:2926
  ///
  /// In en, this message translates to:
  /// **'Indexed height {groupedFigure}'**
  String wallet_readScreensLoopProvenanceFooter2(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:2929
  ///
  /// In en, this message translates to:
  /// **'Data {groupedFigure} blocks behind'**
  String wallet_readScreensLoopProvenanceFooter3(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:885
  ///
  /// In en, this message translates to:
  /// **'LOOP on-chain index'**
  String get wallet_readScreensLoopProvenanceLine;

  /// lib/features/wallet/wallet_read_screens.dart:3606
  ///
  /// In en, this message translates to:
  /// **'Height {groupedFigure}'**
  String wallet_readScreensLoopRecordRow(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:3609, lib/features/wallet/wallet_read_screens.dart:3687
  ///
  /// In en, this message translates to:
  /// **'{groupedFigure} blocks behind'**
  String wallet_readScreensLoopRecordRow2(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:3612
  ///
  /// In en, this message translates to:
  /// **'{reorgCount, plural, =1{1 reorg} other{{reorgCount} reorgs}}'**
  String wallet_readScreensLoopRecordRow3(num reorgCount);

  /// lib/features/wallet/wallet_read_screens.dart:3681
  ///
  /// In en, this message translates to:
  /// **'Endpoint {index}'**
  String wallet_readScreensLoopRecordRow4(Object? index);

  /// lib/features/wallet/wallet_read_screens.dart:3683
  ///
  /// In en, this message translates to:
  /// **'Latency {latencyMs}ms'**
  String wallet_readScreensLoopRecordRow5(Object? latencyMs);

  /// lib/features/wallet/wallet_read_screens.dart:3688
  ///
  /// In en, this message translates to:
  /// **'Checked {label}'**
  String wallet_readScreensLoopRecordRow6(Object? label);

  /// lib/features/wallet/wallet_read_screens.dart:2440
  ///
  /// In en, this message translates to:
  /// **'Link up to {limit} external wallets'**
  String wallet_readScreensLoopSheetHeading(Object? limit);

  /// lib/features/wallet/wallet_read_screens.dart:2477
  ///
  /// In en, this message translates to:
  /// **'Connect external wallet'**
  String get wallet_readScreensLoopSheetHeading2;

  /// lib/features/wallet/wallet_read_screens.dart:2544
  ///
  /// In en, this message translates to:
  /// **'External wallet {truncatedAddress}'**
  String wallet_readScreensLoopSheetHeading3(Object? truncatedAddress);

  /// lib/features/wallet/wallet_read_screens.dart:2601
  ///
  /// In en, this message translates to:
  /// **'Unlink external wallet'**
  String get wallet_readScreensLoopSheetHeading4;

  /// lib/features/wallet/wallet_read_screens.dart:3242
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get wallet_readScreensLoopSheetHeading5;

  /// lib/features/wallet/wallet_read_screens.dart:613, lib/features/wallet/wallet_read_screens.dart:3175
  ///
  /// In en, this message translates to:
  /// **'Wallet activity isn\'t available right now'**
  String get wallet_readScreensMeTradesCapabilityBlockTitle;

  /// lib/features/wallet/wallet_read_screens.dart:1957
  ///
  /// In en, this message translates to:
  /// **'This device can\'t open the share sheet. Copy the address instead'**
  String get wallet_readScreensMessage;

  /// lib/features/wallet/wallet_read_screens.dart:2648
  ///
  /// In en, this message translates to:
  /// **'External wallet unlinked'**
  String get wallet_readScreensMessage10;

  /// lib/features/wallet/wallet_read_screens.dart:2704
  ///
  /// In en, this message translates to:
  /// **'Active wallet switched'**
  String get wallet_readScreensMessage11;

  /// lib/features/wallet/wallet_read_screens.dart:3166
  ///
  /// In en, this message translates to:
  /// **'Records haven\'t loaded yet; there\'s nothing to export.'**
  String get wallet_readScreensMessage12;

  /// lib/features/wallet/wallet_read_screens.dart:3231
  ///
  /// In en, this message translates to:
  /// **'{what} copied'**
  String wallet_readScreensMessage13(Object? what);

  /// lib/features/wallet/wallet_read_screens.dart:2225
  ///
  /// In en, this message translates to:
  /// **'The wallet list isn\'t available right now, so external wallets can\'t be connected.'**
  String get wallet_readScreensMessage2;

  /// lib/features/wallet/wallet_read_screens.dart:2327
  ///
  /// In en, this message translates to:
  /// **'The wallet list hasn\'t loaded yet. Connect an external wallet once it loads.'**
  String get wallet_readScreensMessage3;

  /// lib/features/wallet/wallet_read_screens.dart:2364
  ///
  /// In en, this message translates to:
  /// **'Wallet linking didn\'t finish. Retry.'**
  String get wallet_readScreensMessage4;

  /// lib/features/wallet/wallet_read_screens.dart:2407
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the limit of {limit} external wallets. Unlink one first'**
  String wallet_readScreensMessage5(Object? limit);

  /// lib/features/wallet/wallet_read_screens.dart:2426
  ///
  /// In en, this message translates to:
  /// **'External wallet linked; the wallet list will refresh shortly'**
  String get wallet_readScreensMessage6;

  /// lib/features/wallet/wallet_read_screens.dart:2427
  ///
  /// In en, this message translates to:
  /// **'External wallet linked'**
  String get wallet_readScreensMessage7;

  /// lib/features/wallet/wallet_read_screens.dart:2636
  ///
  /// In en, this message translates to:
  /// **'Unlinking didn\'t finish. Try again later.'**
  String get wallet_readScreensMessage8;

  /// lib/features/wallet/wallet_read_screens.dart:2647
  ///
  /// In en, this message translates to:
  /// **'External wallet unlinked; the wallet list will refresh shortly'**
  String get wallet_readScreensMessage9;

  /// lib/features/wallet/wallet_read_screens.dart:3454
  ///
  /// In en, this message translates to:
  /// **'On-chain reads aren\'t available right now'**
  String get wallet_readScreensNetworksCapabilityBlockTitle;

  /// lib/features/wallet/wallet_read_screens.dart:3473
  ///
  /// In en, this message translates to:
  /// **'The endpoint didn\'t return BNB Smart Chain'**
  String get wallet_readScreensNetworksChainMismatchLabel;

  /// lib/features/wallet/wallet_read_screens.dart:3571
  ///
  /// In en, this message translates to:
  /// **'{status}{chainId} · {groupedFigure} confirmations · reorg tracking {groupedFigure2} blocks'**
  String wallet_readScreensNetworksChainParametersText(
    Object? chainId,
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? status,
  );

  /// lib/features/wallet/wallet_read_screens.dart:3497
  ///
  /// In en, this message translates to:
  /// **'{healthyCount} / {endpoints} healthy'**
  String wallet_readScreensNetworksChainRowTrailing(
    Object? endpoints,
    Object? healthyCount,
  );

  /// lib/features/wallet/wallet_read_screens.dart:3530
  ///
  /// In en, this message translates to:
  /// **'Custom RPC'**
  String get wallet_readScreensNetworksCustomRpcTitle;

  /// lib/features/wallet/wallet_read_screens.dart:3737
  ///
  /// In en, this message translates to:
  /// **'{chainId} · {groupedFigure} confirmations · reorg tracking {groupedFigure2} blocks'**
  String wallet_readScreensNetworksLaunchChainRowSubtitle(
    Object? chainId,
    Object? groupedFigure,
    Object? groupedFigure2,
  );

  /// lib/features/wallet/wallet_read_screens.dart:3717
  ///
  /// In en, this message translates to:
  /// **'{name} (Launch) has no RPC configured'**
  String wallet_readScreensNetworksLaunchChainUnavailableLabel(Object? name);

  /// lib/features/wallet/wallet_read_screens.dart:3581
  ///
  /// In en, this message translates to:
  /// **'No RPC endpoints configured'**
  String get wallet_readScreensNetworksNoEndpointsLabel;

  /// lib/features/wallet/wallet_read_screens.dart:3561
  ///
  /// In en, this message translates to:
  /// **'Endpoints, indexer and chain parameters'**
  String get wallet_readScreensNetworksOperatorDisclosureSummary;

  /// lib/features/wallet/wallet_read_screens.dart:3629
  ///
  /// In en, this message translates to:
  /// **'{readableAssetCount} readable assets · {registeredPoolCount} registered pools'**
  String wallet_readScreensNetworksRegistryText(
    Object? readableAssetCount,
    Object? registeredPoolCount,
  );

  /// lib/features/wallet/wallet_read_screens.dart:3449
  ///
  /// In en, this message translates to:
  /// **'Networks and RPC'**
  String get wallet_readScreensNetworksScreenTitle;

  /// lib/features/wallet/wallet_read_screens.dart:3545
  ///
  /// In en, this message translates to:
  /// **'{name} · Used by Launch only'**
  String wallet_readScreensNetworksTestnetSubtitle(Object? name);

  /// lib/features/wallet/wallet_read_screens.dart:938
  ///
  /// In en, this message translates to:
  /// **'Network disconnected; balance not loaded'**
  String get wallet_readScreensOffline;

  /// lib/features/wallet/wallet_read_screens.dart:2547, lib/features/wallet/wallet_read_screens.dart:2670
  ///
  /// In en, this message translates to:
  /// **'Wallet {truncatedAddress} becomes the current wallet for balances, activity and Receive.'**
  String wallet_readScreensOpenExternalWallet(Object? truncatedAddress);

  /// lib/features/wallet/wallet_read_screens.dart:940
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again later'**
  String get wallet_readScreensRateLimited;

  /// lib/features/wallet/wallet_read_screens.dart:1884, lib/features/wallet/wallet_read_screens.dart:2087
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get wallet_readScreensReceiveCopyAddressLabel;

  /// lib/features/wallet/wallet_read_screens.dart:1845
  ///
  /// In en, this message translates to:
  /// **'Receivable networks can\'t be loaded right now.'**
  String get wallet_readScreensReceiveNoNetworkDetail;

  /// lib/features/wallet/wallet_read_screens.dart:1844
  ///
  /// In en, this message translates to:
  /// **'No receivable network'**
  String get wallet_readScreensReceiveNoNetworkMessage;

  /// lib/features/wallet/wallet_read_screens.dart:2064
  ///
  /// In en, this message translates to:
  /// **'{name} receive QR code'**
  String wallet_readScreensReceiveQrLabel(Object? name);

  /// lib/features/wallet/wallet_read_screens.dart:2054
  ///
  /// In en, this message translates to:
  /// **'QR code unavailable · {reasonCodeText}'**
  String wallet_readScreensReceiveQrUnavailableMessage(Object? reasonCodeText);

  /// lib/features/wallet/wallet_read_screens.dart:1920
  ///
  /// In en, this message translates to:
  /// **'Only receive assets on this network'**
  String get wallet_readScreensReceiveWarningTitle;

  /// lib/features/wallet/wallet_read_screens.dart:3510, lib/features/wallet/wallet_read_screens.dart:3697, lib/features/wallet/wallet_read_screens.dart:3729
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get wallet_readScreensS;

  /// lib/features/wallet/wallet_read_screens.dart:3547
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get wallet_readScreensS2;

  /// lib/features/wallet/wallet_read_screens.dart:1647
  ///
  /// In en, this message translates to:
  /// **' ({blockDelta} blocks apart)'**
  String wallet_readScreensS2X(Object? blockDelta);

  /// lib/features/wallet/wallet_read_screens.dart:3618
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get wallet_readScreensS3;

  /// lib/features/wallet/wallet_read_screens.dart:3558
  ///
  /// In en, this message translates to:
  /// **'Block {groupedFigure} · '**
  String wallet_readScreensS3X(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:823
  ///
  /// In en, this message translates to:
  /// **'Launch chain balances are read from block {groupedFigure} and aren\'t included in total assets.'**
  String wallet_readScreensSX(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:1939
  ///
  /// In en, this message translates to:
  /// **'{name} receiving address'**
  String wallet_readScreensSubject(Object? name);

  /// lib/features/wallet/wallet_read_screens.dart:942
  ///
  /// In en, this message translates to:
  /// **'Balance can\'t be loaded right now'**
  String get wallet_readScreensSwitch;

  /// lib/features/wallet/wallet_read_screens.dart:1612, lib/features/wallet/wallet_read_widgets.dart:510, lib/features/wallet/wallet_read_widgets.dart:557
  ///
  /// In en, this message translates to:
  /// **'Source {factSourceLabel}'**
  String wallet_readScreensSwitch2(Object? factSourceLabel);

  /// lib/features/wallet/wallet_read_screens.dart:1613, lib/features/wallet/wallet_read_screens.dart:2931, lib/features/wallet/wallet_read_screens.dart:3659, lib/features/wallet/wallet_read_widgets.dart:511, lib/features/wallet/wallet_read_widgets.dart:558
  ///
  /// In en, this message translates to:
  /// **'Observed {relativeTime}'**
  String wallet_readScreensSwitch3(Object? relativeTime);

  /// lib/features/wallet/wallet_read_screens.dart:1615
  ///
  /// In en, this message translates to:
  /// **'Proxy asset {truncatedAssetId}'**
  String wallet_readScreensSwitch4(Object? truncatedAssetId);

  /// lib/features/wallet/wallet_read_screens.dart:3728
  ///
  /// In en, this message translates to:
  /// **'Pending check'**
  String get wallet_readScreensSwitch5;

  /// lib/features/wallet/wallet_read_screens.dart:1938
  ///
  /// In en, this message translates to:
  /// **'{name} receiving address\n{address}'**
  String wallet_readScreensText(Object? address, Object? name);

  /// lib/features/wallet/wallet_read_screens.dart:939
  ///
  /// In en, this message translates to:
  /// **'Read timed out; balance not loaded'**
  String get wallet_readScreensTimedOut;

  /// lib/features/wallet/wallet_read_screens.dart:2946
  ///
  /// In en, this message translates to:
  /// **'This page didn\'t finish loading'**
  String get wallet_readScreensTitle;

  /// lib/features/wallet/wallet_read_screens.dart:3017
  ///
  /// In en, this message translates to:
  /// **'No records in this range'**
  String get wallet_readScreensTitle2;

  /// lib/features/wallet/wallet_read_screens.dart:3308
  ///
  /// In en, this message translates to:
  /// **'Copy hash'**
  String get wallet_readScreensTxEntrySheetCopyHashLabel;

  /// lib/features/wallet/wallet_read_screens.dart:3319
  ///
  /// In en, this message translates to:
  /// **'Copy BscScan link'**
  String get wallet_readScreensTxEntrySheetCopyLinkLabel;

  /// lib/features/wallet/wallet_read_screens.dart:3339
  ///
  /// In en, this message translates to:
  /// **'LOOP can\'t open an external browser directly yet. Copy the link and open it in a browser to see the same transaction on-chain.'**
  String get wallet_readScreensTxEntrySheetExplorerNoticeBody;

  /// lib/features/wallet/wallet_read_screens.dart:3338
  ///
  /// In en, this message translates to:
  /// **'Paste it into a browser yourself'**
  String get wallet_readScreensTxEntrySheetExplorerNoticeTitle;

  /// lib/features/wallet/wallet_read_screens.dart:3158
  ///
  /// In en, this message translates to:
  /// **'Exporting'**
  String get wallet_readScreensTxHistoryExportActionLabel;

  /// lib/features/wallet/wallet_read_screens.dart:3158
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get wallet_readScreensTxHistoryExportActionLabel2;

  /// lib/features/wallet/wallet_read_screens.dart:941
  ///
  /// In en, this message translates to:
  /// **'On-chain balance can\'t be loaded right now'**
  String get wallet_readScreensUnavailable;

  /// lib/features/wallet/wallet_read_screens.dart:3698
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get wallet_readScreensUnreachable;

  /// lib/features/wallet/wallet_read_screens.dart:1462
  ///
  /// In en, this message translates to:
  /// **'The indexer has read this range, but it has no transfers for this asset.'**
  String get wallet_readScreensWalletAssetActivityEmptyMessage;

  /// lib/features/wallet/wallet_read_screens.dart:1515
  ///
  /// In en, this message translates to:
  /// **'On-chain balance can\'t be loaded'**
  String get wallet_readScreensWalletAssetBalanceMissingLabel;

  /// lib/features/wallet/wallet_read_screens.dart:1651
  ///
  /// In en, this message translates to:
  /// **'The on-chain reading doesn\'t match the value reported by Privy{crossCheck}. This page always shows the on-chain reading; the cross-check doesn\'t change it.'**
  String wallet_readScreensWalletAssetCrosscheckBody(Object? crossCheck);

  /// lib/features/wallet/wallet_read_screens.dart:1640
  ///
  /// In en, this message translates to:
  /// **'Cross-check with Privy unavailable'**
  String get wallet_readScreensWalletAssetCrosscheckUnavailableLabel;

  /// lib/features/wallet/wallet_read_screens.dart:1290
  ///
  /// In en, this message translates to:
  /// **'Balance notes and asset facts'**
  String get wallet_readScreensWalletAssetFactsDisclosureSummary;

  /// lib/features/wallet/wallet_read_screens.dart:1110
  ///
  /// In en, this message translates to:
  /// **'Wallet asset'**
  String get wallet_readScreensWalletAssetFolioKicker;

  /// lib/features/wallet/wallet_read_screens.dart:1478
  ///
  /// In en, this message translates to:
  /// **'All ERC-20 transfers for this wallet, from the on-chain index'**
  String get wallet_readScreensWalletAssetHistoryEntrySubtitle;

  /// lib/features/wallet/wallet_read_screens.dart:1477, lib/features/wallet/wallet_read_screens.dart:3145
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get wallet_readScreensWalletAssetHistoryEntryTitle;

  /// lib/features/wallet/wallet_read_screens.dart:1024
  ///
  /// In en, this message translates to:
  /// **'This page only accepts a canonical CAIP assetId; no balance was requested.'**
  String get wallet_readScreensWalletAssetInvalidIdentityMessage;

  /// lib/features/wallet/wallet_read_screens.dart:1023
  ///
  /// In en, this message translates to:
  /// **'No usable asset ID in the route'**
  String get wallet_readScreensWalletAssetInvalidIdentityTitle;

  /// lib/features/wallet/wallet_read_screens.dart:1017
  ///
  /// In en, this message translates to:
  /// **'Can\'t open this asset'**
  String get wallet_readScreensWalletAssetInvalidTitle;

  /// lib/features/wallet/wallet_read_screens.dart:1092
  ///
  /// In en, this message translates to:
  /// **'Wallet asset · {asset}'**
  String wallet_readScreensWalletAssetMarketActionTitle(Object? asset);

  /// lib/features/wallet/wallet_read_screens.dart:1164
  ///
  /// In en, this message translates to:
  /// **'Only registered assets show a balance.'**
  String get wallet_readScreensWalletAssetMissingRowDetail;

  /// lib/features/wallet/wallet_read_screens.dart:1163
  ///
  /// In en, this message translates to:
  /// **'This asset isn\'t on the readable list'**
  String get wallet_readScreensWalletAssetMissingRowMessage;

  /// lib/features/wallet/wallet_read_screens.dart:1547
  ///
  /// In en, this message translates to:
  /// **'Pending amount unavailable'**
  String get wallet_readScreensWalletAssetPendingMissingLabel;

  /// lib/features/wallet/wallet_read_screens.dart:1602, lib/features/wallet/wallet_read_widgets.dart:69
  ///
  /// In en, this message translates to:
  /// **'Priced in WBNB'**
  String get wallet_readScreensWalletAssetProxied;

  /// lib/features/wallet/wallet_read_screens.dart:1578
  ///
  /// In en, this message translates to:
  /// **'Value unavailable'**
  String get wallet_readScreensWalletAssetValuationUnavailableLabel;

  /// lib/features/wallet/wallet_read_screens.dart:800
  ///
  /// In en, this message translates to:
  /// **'No assets yet'**
  String get wallet_readScreensWalletBalancesEmptyTitle;

  /// lib/features/wallet/wallet_read_screens.dart:565, lib/features/wallet/wallet_read_screens.dart:1135, lib/features/wallet/wallet_read_screens.dart:1809
  ///
  /// In en, this message translates to:
  /// **'Wallet reads aren\'t available right now'**
  String get wallet_readScreensWalletCapabilityBlockTitle;

  /// lib/features/wallet/wallet_read_screens.dart:524
  ///
  /// In en, this message translates to:
  /// **'No current wallet selected yet'**
  String get wallet_readScreensWalletDirectoryNoActiveTitle;

  /// lib/features/wallet/wallet_read_screens.dart:660
  ///
  /// In en, this message translates to:
  /// **'No wallet yet'**
  String get wallet_readScreensWalletFolioUnreadText;

  /// lib/features/wallet/wallet_read_screens.dart:662
  ///
  /// In en, this message translates to:
  /// **'No wallet selected'**
  String get wallet_readScreensWalletFolioUnreadText2;

  /// lib/features/wallet/wallet_read_screens.dart:667
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get wallet_readScreensWalletFolioUnreadText3;

  /// lib/features/wallet/wallet_read_screens.dart:865
  ///
  /// In en, this message translates to:
  /// **'No NFTs yet'**
  String get wallet_readScreensWalletNftEmptyTitle;

  /// lib/features/wallet/wallet_read_screens.dart:844
  ///
  /// In en, this message translates to:
  /// **'MEME v2 isn\'t available yet, so project NFTs can\'t be loaded right now'**
  String get wallet_readScreensWalletNftUnavailableMessage;

  /// lib/features/wallet/wallet_read_screens.dart:328, lib/features/wallet/wallet_read_screens.dart:339
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get wallet_readScreensWalletScreenTitle;

  /// lib/features/wallet/wallet_read_screens.dart:822
  ///
  /// In en, this message translates to:
  /// **'Every balance row is read from the same block ({groupedFigure} confirmations). Native BNB keeps {formatDecimal} BNB as a fee reserve, not included in usable. {launchSnapshot}'**
  String wallet_readScreensWalletSnapshotFooterDetail(
    Object? formatDecimal,
    Object? groupedFigure,
    Object? launchSnapshot,
  );

  /// lib/features/wallet/wallet_read_screens.dart:815
  ///
  /// In en, this message translates to:
  /// **'Block {groupedFigure}'**
  String wallet_readScreensWalletSnapshotFooterPrefix(Object? groupedFigure);

  /// lib/features/wallet/wallet_read_screens.dart:2559, lib/features/wallet/wallet_read_screens.dart:2682
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get wallet_readScreensWalletsActivateConfirmLabel;

  /// lib/features/wallet/wallet_read_screens.dart:2218
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get wallet_readScreensWalletsAddActionLabel;

  /// lib/features/wallet/wallet_read_screens.dart:2511
  ///
  /// In en, this message translates to:
  /// **'Continue connecting'**
  String get wallet_readScreensWalletsAddSheetContinueLabel;

  /// lib/features/wallet/wallet_read_screens.dart:2499
  ///
  /// In en, this message translates to:
  /// **'Networks in mainland China need a VPN to connect external wallets.'**
  String get wallet_readScreensWalletsAddSheetNetworkBody;

  /// lib/features/wallet/wallet_read_screens.dart:2498
  ///
  /// In en, this message translates to:
  /// **'Mainland China networks need a VPN'**
  String get wallet_readScreensWalletsAddSheetNetworkTitle;

  /// lib/features/wallet/wallet_read_screens.dart:2483
  ///
  /// In en, this message translates to:
  /// **'External wallets are only used to calculate power; you can\'t trade or claim rewards with them in LOOP. LOOP never gets your private key.'**
  String get wallet_readScreensWalletsAddSheetReasonBody;

  /// lib/features/wallet/wallet_read_screens.dart:2481
  ///
  /// In en, this message translates to:
  /// **'External wallets only count toward power'**
  String get wallet_readScreensWalletsAddSheetReasonTitle;

  /// lib/features/wallet/wallet_read_screens.dart:2491
  ///
  /// In en, this message translates to:
  /// **'Community tokens in every linked wallet count toward power; no need to move assets into one wallet.'**
  String get wallet_readScreensWalletsAddSheetScopeBody;

  /// lib/features/wallet/wallet_read_screens.dart:2490
  ///
  /// In en, this message translates to:
  /// **'Holdings in all linked wallets count toward power'**
  String get wallet_readScreensWalletsAddSheetScopeTitle;

  /// lib/features/wallet/wallet_read_screens.dart:2235
  ///
  /// In en, this message translates to:
  /// **'The wallet list isn\'t available right now'**
  String get wallet_readScreensWalletsCapabilityBlockTitle;

  /// lib/features/wallet/wallet_read_screens.dart:2442
  ///
  /// In en, this message translates to:
  /// **'You can link up to {limit} external wallets. Unlink one before connecting a new wallet.'**
  String wallet_readScreensWalletsLimitSheetBody(Object? limit);

  /// lib/features/wallet/wallet_read_screens.dart:2209
  ///
  /// In en, this message translates to:
  /// **'My wallets'**
  String get wallet_readScreensWalletsScreenTitle;

  /// lib/features/wallet/wallet_read_screens.dart:2301
  ///
  /// In en, this message translates to:
  /// **'Source Privy · observed {relativeTime}'**
  String wallet_readScreensWalletsSourceText(Object? relativeTime);

  /// lib/features/wallet/wallet_read_screens.dart:2300
  ///
  /// In en, this message translates to:
  /// **'About linked wallets'**
  String get wallet_readScreensWalletsSourceTitle;

  /// lib/features/wallet/wallet_read_screens.dart:2266
  ///
  /// In en, this message translates to:
  /// **'Active wallet wasn\'t switched'**
  String get wallet_readScreensWalletsSwitchErrorTitle;

  /// lib/features/wallet/wallet_read_screens.dart:2571
  ///
  /// In en, this message translates to:
  /// **'Unlink this wallet'**
  String get wallet_readScreensWalletsUnlinkActionLabel;

  /// lib/features/wallet/wallet_read_screens.dart:2618
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get wallet_readScreensWalletsUnlinkConfirmLabel;

  /// lib/features/wallet/wallet_read_screens.dart:2603
  ///
  /// In en, this message translates to:
  /// **'After unlinking, this wallet\'s holdings stop counting toward power from the next hour. Assets in wallet {truncatedAddress} aren\'t affected, and you can link it again later.'**
  String wallet_readScreensWalletsUnlinkSheetBody(Object? truncatedAddress);

  /// lib/features/wallet/wallet_read_screens.dart:3320
  ///
  /// In en, this message translates to:
  /// **'Explorer link'**
  String get wallet_readScreensWhat;

  /// lib/features/wallet/wallet_read_widgets.dart:163
  ///
  /// In en, this message translates to:
  /// **'Usable, power and fee reserve for {symbol}'**
  String wallet_readSemanticLabel(Object? symbol);

  /// lib/features/wallet/wallet_read_widgets.dart:312
  ///
  /// In en, this message translates to:
  /// **'Spent {launch2Usd1Label}'**
  String wallet_readSwitch(Object? launch2Usd1Label);

  /// lib/features/wallet/wallet_read_widgets.dart:827
  ///
  /// In en, this message translates to:
  /// **'LOOP will create a Privy embedded wallet for this account. The address is a public on-chain fact, not an account identifier.'**
  String get wallet_readSwitch2;

  /// lib/features/wallet/wallet_read_widgets.dart:814, lib/features/wallet/wallet_read_widgets.dart:834
  ///
  /// In en, this message translates to:
  /// **'This account has no wallet yet'**
  String get wallet_readTitle;

  /// lib/features/wallet/wallet_read_widgets.dart:231
  ///
  /// In en, this message translates to:
  /// **'From {address}'**
  String wallet_readTransferFrom(Object? address);

  /// lib/features/wallet/wallet_read_widgets.dart:231
  ///
  /// In en, this message translates to:
  /// **'To {address}'**
  String wallet_readTransferTo(Object? address);

  /// lib/features/wallet/wallet_read_widgets.dart:381
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get wallet_readWalletActivityDayLabel;

  /// lib/features/wallet/wallet_read_widgets.dart:382
  ///
  /// In en, this message translates to:
  /// **'{month} {day}'**
  String wallet_readWalletActivityDayLabel2(Object? day, Object? month);

  /// lib/features/wallet/wallet_read_widgets.dart:383
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String wallet_readWalletActivityDayLabel3(
    Object? day,
    Object? month,
    Object? year,
  );

  /// lib/features/wallet/wallet_read_widgets.dart:334, lib/features/wallet/wallet_read_widgets.dart:627
  ///
  /// In en, this message translates to:
  /// **'Launch chain'**
  String get wallet_readWalletLaunch2ActivityRow;

  /// lib/features/wallet/wallet_read_widgets.dart:335
  ///
  /// In en, this message translates to:
  /// **'Confirming'**
  String get wallet_readWalletLaunch2ActivityRow2;

  /// lib/features/wallet/wallet_read_widgets.dart:633
  ///
  /// In en, this message translates to:
  /// **'{name} balance unavailable'**
  String wallet_readWalletLaunchChainUnavailableLabel(Object? name);

  /// lib/features/wallet/wallet_read_widgets.dart:768
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load'**
  String get wallet_readWalletLaunchUsd1Failed;

  /// lib/features/wallet/wallet_read_widgets.dart:502, lib/features/wallet/wallet_read_widgets.dart:549
  ///
  /// In en, this message translates to:
  /// **'Not an available balance'**
  String get wallet_readWalletNetworthNotSpendable;

  /// lib/features/wallet/wallet_read_widgets.dart:496, lib/features/wallet/wallet_read_widgets.dart:542
  ///
  /// In en, this message translates to:
  /// **'Partial value · {unavailableCount} without price'**
  String wallet_readWalletNetworthPartial(Object? unavailableCount);

  /// lib/features/wallet/wallet_read_widgets.dart:475
  ///
  /// In en, this message translates to:
  /// **'Net value unavailable'**
  String get wallet_readWalletNetworthUnavailableLabel;

  /// lib/features/wallet/wallet_read_widgets.dart:824
  ///
  /// In en, this message translates to:
  /// **'Unknown reason'**
  String get wallet_readWalletReadFailed;

  /// lib/features/wallet/wallet_read_widgets.dart:441
  ///
  /// In en, this message translates to:
  /// **'Block {groupedFigure} · {groupedFigure2} confirmations · observed {relativeTime}'**
  String wallet_readWalletSnapshotFooterText(
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? relativeTime,
  );

  /// lib/features/wallet/send_screens.dart:1696
  ///
  /// In en, this message translates to:
  /// **'{moneyActionTitle} · {moneyIntentStateLabel}. Preparing a new one will invalidate it; if it\'s already signed and broadcast, report or cancel it first.'**
  String wallet_sendScreensBody(
    Object? moneyActionTitle,
    Object? moneyIntentStateLabel,
  );

  /// lib/features/wallet/send_screens.dart:1078, lib/features/wallet/send_screens.dart:1098
  ///
  /// In en, this message translates to:
  /// **'First transfer to this address'**
  String get wallet_sendScreensBuild;

  /// lib/features/wallet/send_screens.dart:1079, lib/features/wallet/send_screens.dart:1106
  ///
  /// In en, this message translates to:
  /// **'Recipient is a contract address'**
  String get wallet_sendScreensBuild2;

  /// lib/features/wallet/send_screens.dart:1080, lib/features/wallet/send_screens.dart:1113
  ///
  /// In en, this message translates to:
  /// **'Malicious address screening unavailable'**
  String get wallet_sendScreensBuild3;

  /// lib/features/wallet/send_screens.dart:1595, lib/features/wallet/send_screens.dart:1744, lib/features/wallet/send_screens.dart:1751
  ///
  /// In en, this message translates to:
  /// **'Not filled in yet'**
  String get wallet_sendScreensBuild4;

  /// lib/features/wallet/send_screens.dart:1597, lib/features/wallet/send_screens.dart:1758
  ///
  /// In en, this message translates to:
  /// **'Not loaded yet'**
  String get wallet_sendScreensBuild5;

  /// lib/features/wallet/send_screens.dart:1769
  ///
  /// In en, this message translates to:
  /// **'These two rows are what you entered in the previous step, not server facts yet. Network fee, balance and simulation appear together once this transfer is prepared.'**
  String get wallet_sendScreensBuild6;

  /// lib/features/wallet/send_screens.dart:1804
  ///
  /// In en, this message translates to:
  /// **'There\'s no source for arrival time, so no made-up seconds here. After submitting, track it by confirmations on the result page; that\'s the only progress.'**
  String get wallet_sendScreensBuild7;

  /// lib/features/wallet/send_screens.dart:617
  ///
  /// In en, this message translates to:
  /// **'This account has no wallet that can send yet'**
  String get wallet_sendScreensEmptyMessage;

  /// lib/features/wallet/send_screens.dart:618
  ///
  /// In en, this message translates to:
  /// **'Only the Privy embedded wallet can sign and broadcast from this device.'**
  String get wallet_sendScreensEmptyReason;

  /// lib/features/wallet/send_screens.dart:609, lib/features/wallet/send_screens.dart:627
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get wallet_sendScreensLabel;

  /// lib/features/wallet/send_screens.dart:828
  ///
  /// In en, this message translates to:
  /// **'Amount and asset'**
  String get wallet_sendScreensLabel2;

  /// lib/features/wallet/send_screens.dart:1244, lib/features/wallet/send_screens.dart:1249
  ///
  /// In en, this message translates to:
  /// **'Confirm and sign'**
  String get wallet_sendScreensLabel3;

  /// lib/features/wallet/send_screens.dart:882
  ///
  /// In en, this message translates to:
  /// **'Usable {formatDecimal} {symbol} (after fee reserve)'**
  String wallet_sendScreensLoopBalanceAvailable(
    Object? formatDecimal,
    Object? symbol,
  );

  /// lib/features/wallet/send_screens.dart:577
  ///
  /// In en, this message translates to:
  /// **'One more step: waiting for address check.'**
  String get wallet_sendScreensMissing;

  /// lib/features/wallet/send_screens.dart:721
  ///
  /// In en, this message translates to:
  /// **'Check address'**
  String get wallet_sendScreensMoneyOfflinePause;

  /// lib/features/wallet/send_screens.dart:1709
  ///
  /// In en, this message translates to:
  /// **'Cancel and prepare again'**
  String get wallet_sendScreensMoneyPendingCancelLabel;

  /// lib/features/wallet/send_screens.dart:1704
  ///
  /// In en, this message translates to:
  /// **'View that transaction'**
  String get wallet_sendScreensMoneyPendingOpenLabel;

  /// lib/features/wallet/send_screens.dart:654
  ///
  /// In en, this message translates to:
  /// **'0x… ({chainName})'**
  String wallet_sendScreensRecipientHint(Object? chainName);

  /// lib/features/wallet/send_screens.dart:556
  ///
  /// In en, this message translates to:
  /// **'Checking address…'**
  String get wallet_sendScreensRecipientStep;

  /// lib/features/wallet/send_screens.dart:558
  ///
  /// In en, this message translates to:
  /// **'Address checked · {chainName}'**
  String wallet_sendScreensRecipientStep2(Object? chainName);

  /// lib/features/wallet/send_screens.dart:562
  ///
  /// In en, this message translates to:
  /// **'Invalid address format: starts with 0x, 42 characters'**
  String get wallet_sendScreensRecipientStep3;

  /// lib/features/wallet/send_screens.dart:578
  ///
  /// In en, this message translates to:
  /// **'One more step: enter the full recipient address (starts with 0x, 42 characters).'**
  String get wallet_sendScreensSendAddressNextMissing;

  /// lib/features/wallet/send_screens.dart:569
  ///
  /// In en, this message translates to:
  /// **'Send NFT'**
  String get wallet_sendScreensSendAddressScreenTitle;

  /// lib/features/wallet/send_screens.dart:919
  ///
  /// In en, this message translates to:
  /// **'Exceeds usable balance'**
  String get wallet_sendScreensSendAmountMaxErrorText;

  /// lib/features/wallet/send_screens.dart:917
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get wallet_sendScreensSendAmountMaxHintText;

  /// lib/features/wallet/send_screens.dart:794
  ///
  /// In en, this message translates to:
  /// **'One more step: choose the asset to send.'**
  String get wallet_sendScreensSendAmountNextMissing;

  /// lib/features/wallet/send_screens.dart:796
  ///
  /// In en, this message translates to:
  /// **'One more step: enter the amount to send.'**
  String get wallet_sendScreensSendAmountNextMissing2;

  /// lib/features/wallet/send_screens.dart:798
  ///
  /// In en, this message translates to:
  /// **'The amount exceeds your usable balance. Lower it.'**
  String get wallet_sendScreensSendAmountNextMissing3;

  /// lib/features/wallet/send_screens.dart:836
  ///
  /// In en, this message translates to:
  /// **'Recipient address · Checked'**
  String get wallet_sendScreensSendAmountRecipientSubtitle;

  /// lib/features/wallet/send_screens.dart:837
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get wallet_sendScreensSendAmountRecipientTrailingCaption;

  /// lib/features/wallet/send_screens.dart:892
  ///
  /// In en, this message translates to:
  /// **'Amount to send'**
  String get wallet_sendScreensSendAmountTitle;

  /// lib/features/wallet/send_screens.dart:892
  ///
  /// In en, this message translates to:
  /// **'Amount to send ({symbol})'**
  String wallet_sendScreensSendAmountTitle2(Object? symbol);

  /// lib/features/wallet/send_screens.dart:879
  ///
  /// In en, this message translates to:
  /// **'{candidates, plural, =1{1 asset can be sent} other{{candidates} assets can be sent}}'**
  String wallet_sendScreensSendAssetSelectorSubtitle(num candidates);

  /// lib/features/wallet/send_screens.dart:860
  ///
  /// In en, this message translates to:
  /// **'Once assets are registered, each one always keeps a row here.'**
  String get wallet_sendScreensSendAssetsEmptyMessage;

  /// lib/features/wallet/send_screens.dart:859
  ///
  /// In en, this message translates to:
  /// **'No readable assets yet'**
  String get wallet_sendScreensSendAssetsEmptyTitle;

  /// lib/features/wallet/send_screens.dart:602, lib/features/wallet/send_screens.dart:824, lib/features/wallet/send_screens.dart:1230
  ///
  /// In en, this message translates to:
  /// **'Send isn\'t available right now'**
  String get wallet_sendScreensSendCapabilityBlockTitle;

  /// lib/features/wallet/send_screens.dart:1763, lib/features/wallet/send_screens.dart:1799
  ///
  /// In en, this message translates to:
  /// **'Estimated arrival'**
  String get wallet_sendScreensSendConfirmDraftArrivalLabel;

  /// lib/features/wallet/send_screens.dart:1764, lib/features/wallet/send_screens.dart:1800
  ///
  /// In en, this message translates to:
  /// **'Not estimated'**
  String get wallet_sendScreensSendConfirmDraftArrivalValue;

  /// lib/features/wallet/send_screens.dart:1757
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get wallet_sendScreensSendConfirmDraftFeeLabel;

  /// lib/features/wallet/send_screens.dart:1317
  ///
  /// In en, this message translates to:
  /// **'Prepare it again before signing.'**
  String get wallet_sendScreensSendConfirmExpiredBody;

  /// lib/features/wallet/send_screens.dart:1342
  ///
  /// In en, this message translates to:
  /// **'Balance, fees and simulation all come from the same moment. Prepare it again before signing.'**
  String get wallet_sendScreensSendConfirmExpiredBody2;

  /// lib/features/wallet/send_screens.dart:1316, lib/features/wallet/send_screens.dart:1341
  ///
  /// In en, this message translates to:
  /// **'Facts expired'**
  String get wallet_sendScreensSendConfirmExpiredTitle;

  /// lib/features/wallet/send_screens.dart:1360
  ///
  /// In en, this message translates to:
  /// **'Power drops with your holdings after sending. The exact figure can\'t be loaded right now, so no estimate is made here.'**
  String get wallet_sendScreensSendConfirmPowerBody;

  /// lib/features/wallet/send_screens.dart:1359
  ///
  /// In en, this message translates to:
  /// **'Power drops with your holdings'**
  String get wallet_sendScreensSendConfirmPowerTitle;

  /// lib/features/wallet/send_screens.dart:1214
  ///
  /// In en, this message translates to:
  /// **'Confirm send ({moneyCountdownLabel})'**
  String wallet_sendScreensSendConfirmSignLabel(Object? moneyCountdownLabel);

  /// lib/features/wallet/send_screens.dart:1352
  ///
  /// In en, this message translates to:
  /// **'Signing is done on this device by the Privy embedded wallet; every fund action goes through the same signing sheet, the only signing exit in the product.'**
  String get wallet_sendScreensSendConfirmSigningExitText;

  /// lib/features/wallet/send_screens.dart:1350
  ///
  /// In en, this message translates to:
  /// **'Unified signing exit'**
  String get wallet_sendScreensSendConfirmSigningExitTitle;

  /// lib/features/wallet/send_screens.dart:1305, lib/features/wallet/send_screens.dart:1330
  ///
  /// In en, this message translates to:
  /// **'Simulation didn\'t pass; can\'t sign'**
  String get wallet_sendScreensSendConfirmSimulationFailedTitle;

  /// lib/features/wallet/send_screens.dart:937
  ///
  /// In en, this message translates to:
  /// **'After sending a weighted community token, power drops with your holdings. The exact figure can\'t be loaded right now, so no estimate is made here.'**
  String get wallet_sendScreensSendPowerNoticeBody;

  /// lib/features/wallet/send_screens.dart:936
  ///
  /// In en, this message translates to:
  /// **'Sending lowers your power'**
  String get wallet_sendScreensSendPowerNoticeTitle;

  /// lib/features/wallet/send_screens.dart:1123
  ///
  /// In en, this message translates to:
  /// **'First-time recipient is judged by your own ERC-20 transfer history indexed in LOOP'**
  String get wallet_sendScreensSendRecipientBasisText;

  /// lib/features/wallet/send_screens.dart:1122
  ///
  /// In en, this message translates to:
  /// **'Basis'**
  String get wallet_sendScreensSendRecipientBasisTitle;

  /// lib/features/wallet/send_screens.dart:1086
  ///
  /// In en, this message translates to:
  /// **'Address check · {headlines} to confirm · {first}'**
  String wallet_sendScreensSendRecipientChecksSummary(
    Object? first,
    Object? headlines,
  );

  /// lib/features/wallet/send_screens.dart:1107
  ///
  /// In en, this message translates to:
  /// **'Sending directly to a contract address may lose this asset permanently. Make sure this contract actually accepts direct transfers.'**
  String get wallet_sendScreensSendRecipientContractBody;

  /// lib/features/wallet/send_screens.dart:1099
  ///
  /// In en, this message translates to:
  /// **'This address isn\'t in your own indexed transfer history. Check the full address character by character before continuing.'**
  String get wallet_sendScreensSendRecipientFirstTimeBody;

  /// lib/features/wallet/send_screens.dart:661
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get wallet_sendScreensSendRecipientPasteLabel;

  /// lib/features/wallet/send_screens.dart:709
  ///
  /// In en, this message translates to:
  /// **'Recipient address from scan, checked automatically'**
  String get wallet_sendScreensSendRecipientPrefill;

  /// lib/features/wallet/send_screens.dart:735
  ///
  /// In en, this message translates to:
  /// **'Address check didn\'t succeed'**
  String get wallet_sendScreensSendRecipientPreflightErrorTitle;

  /// lib/features/wallet/send_screens.dart:667, lib/features/wallet/wallet_read_screens.dart:491
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get wallet_sendScreensSendRecipientScanLabel;

  /// lib/features/wallet/send_screens.dart:1001
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}, {label}'**
  String wallet_sendScreensSendStepBarLabel(
    Object? label,
    Object? step,
    Object? total,
  );

  /// lib/features/wallet/send_screens.dart:1694
  ///
  /// In en, this message translates to:
  /// **'This wallet has an unfinished action'**
  String get wallet_sendScreensTitle;

  /// lib/features/wallet/swap_screens.dart:471
  ///
  /// In en, this message translates to:
  /// **'Choose the asset to pay with first; its usable balance shows here.'**
  String get wallet_swapScreensBalanceLineFor;

  /// lib/features/wallet/swap_screens.dart:472
  ///
  /// In en, this message translates to:
  /// **'Balance not loaded yet.'**
  String get wallet_swapScreensBalanceLineFor2;

  /// lib/features/wallet/swap_screens.dart:474
  ///
  /// In en, this message translates to:
  /// **'This wallet doesn\'t have this row, so its balance can\'t be read.'**
  String get wallet_swapScreensBalanceLineFor3;

  /// lib/features/wallet/swap_screens.dart:200
  ///
  /// In en, this message translates to:
  /// **'This account has no wallet that can swap yet'**
  String get wallet_swapScreensEmptyMessage;

  /// lib/features/wallet/swap_screens.dart:928, lib/features/wallet/swap_screens.dart:1023
  ///
  /// In en, this message translates to:
  /// **'Can\'t price'**
  String get wallet_swapScreensIf;

  /// lib/features/wallet/swap_screens.dart:857, lib/features/wallet/swap_screens.dart:1016
  ///
  /// In en, this message translates to:
  /// **'Price impact'**
  String get wallet_swapScreensLabel;

  /// lib/features/wallet/swap_screens.dart:865
  ///
  /// In en, this message translates to:
  /// **'Platform fee'**
  String get wallet_swapScreensLabel2;

  /// lib/features/wallet/swap_screens.dart:872
  ///
  /// In en, this message translates to:
  /// **'Per-transaction limit'**
  String get wallet_swapScreensLabel3;

  /// lib/features/wallet/swap_screens.dart:1004
  ///
  /// In en, this message translates to:
  /// **'Estimated network fee'**
  String get wallet_swapScreensLabel4;

  /// lib/features/wallet/swap_screens.dart:1009
  ///
  /// In en, this message translates to:
  /// **'LOOP service fee'**
  String get wallet_swapScreensLabel5;

  /// lib/features/wallet/swap_screens.dart:1021
  ///
  /// In en, this message translates to:
  /// **'Market value'**
  String get wallet_swapScreensLabel6;

  /// lib/features/wallet/swap_screens.dart:477
  ///
  /// In en, this message translates to:
  /// **'Usable {formatDecimal} {symbol}'**
  String wallet_swapScreensLoopBalanceAvailable(
    Object? formatDecimal,
    Object? symbol,
  );

  /// lib/features/wallet/swap_screens.dart:995
  ///
  /// In en, this message translates to:
  /// **'Fee breakdown'**
  String get wallet_swapScreensLoopLabel;

  /// lib/features/wallet/swap_screens.dart:1038
  ///
  /// In en, this message translates to:
  /// **'Only the final quote is shown: per-hop details appear only when the quote provider supplies a path, and it didn\'t this time.'**
  String get wallet_swapScreensLoopProvenanceFooter;

  /// lib/features/wallet/swap_screens.dart:357
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get wallet_swapScreensMoneyOfflinePause;

  /// lib/features/wallet/swap_screens.dart:802
  ///
  /// In en, this message translates to:
  /// **'Shown after quote'**
  String get wallet_swapScreensS;

  /// lib/features/wallet/swap_screens.dart:189
  ///
  /// In en, this message translates to:
  /// **'Swap isn\'t available right now'**
  String get wallet_swapScreensSwapCapabilityBlockLabel;

  /// lib/features/wallet/swap_screens.dart:442
  ///
  /// In en, this message translates to:
  /// **'Quote expired · Get new quote'**
  String get wallet_swapScreensSwapConfirmActionLabel;

  /// lib/features/wallet/swap_screens.dart:444
  ///
  /// In en, this message translates to:
  /// **'Swap is still being verified'**
  String get wallet_swapScreensSwapConfirmActionLabel2;

  /// lib/features/wallet/swap_screens.dart:445
  ///
  /// In en, this message translates to:
  /// **'Swap ({moneyCountdownLabel})'**
  String wallet_swapScreensSwapConfirmActionLabel3(Object? moneyCountdownLabel);

  /// lib/features/wallet/swap_screens.dart:184, lib/features/wallet/swap_screens.dart:794
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get wallet_swapScreensSwapDestinationBlockedCaption;

  /// lib/features/wallet/swap_screens.dart:283
  ///
  /// In en, this message translates to:
  /// **'Swap pay and receive'**
  String get wallet_swapScreensSwapFlipLabel;

  /// lib/features/wallet/swap_screens.dart:917
  ///
  /// In en, this message translates to:
  /// **'Price impact exceeds the hard block line'**
  String get wallet_swapScreensSwapImpactBlockedTitle;

  /// lib/features/wallet/swap_screens.dart:910
  ///
  /// In en, this message translates to:
  /// **'This swap will noticeably move the price. Slippage and price impact are different: slippage is the limit you set, price impact is the shift this trade itself causes.'**
  String get wallet_swapScreensSwapImpactConfirmBody;

  /// lib/features/wallet/swap_screens.dart:908
  ///
  /// In en, this message translates to:
  /// **'Price impact is between 1% and 5%'**
  String get wallet_swapScreensSwapImpactConfirmTitle;

  /// lib/features/wallet/swap_screens.dart:159, lib/features/wallet/swap_screens.dart:1049
  ///
  /// In en, this message translates to:
  /// **'About Swap'**
  String get wallet_swapScreensSwapInfoActionLabel;

  /// lib/features/wallet/swap_screens.dart:1062
  ///
  /// In en, this message translates to:
  /// **'The power change after buying can\'t be loaded right now, so no estimate is made here.'**
  String get wallet_swapScreensSwapPowerNoticeBody;

  /// lib/features/wallet/swap_screens.dart:1061
  ///
  /// In en, this message translates to:
  /// **'Power impact unavailable'**
  String get wallet_swapScreensSwapPowerNoticeTitle;

  /// lib/features/wallet/swap_screens.dart:410, lib/features/wallet/swap_screens.dart:417, lib/features/wallet/swap_screens.dart:802
  ///
  /// In en, this message translates to:
  /// **'Quoting…'**
  String get wallet_swapScreensSwapQuoteActionLabel;

  /// lib/features/wallet/swap_screens.dart:412
  ///
  /// In en, this message translates to:
  /// **'Choose assets to pay and receive'**
  String get wallet_swapScreensSwapQuoteActionLabel2;

  /// lib/features/wallet/swap_screens.dart:414
  ///
  /// In en, this message translates to:
  /// **'Enter an amount to get a quote'**
  String get wallet_swapScreensSwapQuoteActionLabel3;

  /// lib/features/wallet/swap_screens.dart:416
  ///
  /// In en, this message translates to:
  /// **'Get new quote'**
  String get wallet_swapScreensSwapQuoteActionLabel4;

  /// lib/features/wallet/swap_screens.dart:363
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a quote'**
  String get wallet_swapScreensSwapQuoteErrorTitle;

  /// lib/features/wallet/swap_screens.dart:885
  ///
  /// In en, this message translates to:
  /// **'Quoted by {provider} · {relativeTime}{quote}'**
  String wallet_swapScreensSwapQuoteProvenanceText(
    Object? provider,
    Object? quote,
    Object? relativeTime,
  );

  /// lib/features/wallet/swap_screens.dart:166
  ///
  /// In en, this message translates to:
  /// **'Quote and fee details'**
  String get wallet_swapScreensSwapRouteActionLabel;

  /// lib/features/wallet/swap_screens.dart:957
  ///
  /// In en, this message translates to:
  /// **'Back to Swap to confirm'**
  String get wallet_swapScreensSwapRouteBackLabel;

  /// lib/features/wallet/swap_screens.dart:385
  ///
  /// In en, this message translates to:
  /// **'Quote details and fees'**
  String get wallet_swapScreensSwapRouteEntryLabel;

  /// lib/features/wallet/swap_screens.dart:1034
  ///
  /// In en, this message translates to:
  /// **'Quoted by {provider} · pricing source {priceImpact} · valid for {quoteTtlSeconds}s'**
  String wallet_swapScreensSwapRouteProvenanceText(
    Object? priceImpact,
    Object? provider,
    Object? quoteTtlSeconds,
  );

  /// lib/features/wallet/swap_screens.dart:953
  ///
  /// In en, this message translates to:
  /// **'Quote and fees'**
  String get wallet_swapScreensSwapRouteScreenTitle;

  /// lib/features/wallet/swap_screens.dart:1056
  ///
  /// In en, this message translates to:
  /// **'LOOP doesn\'t build its own routes or split hops. Only the final quote returned by Privy is shown here; swapped assets go straight into this wallet.'**
  String get wallet_swapScreensSwapRoutingNoticeBody;

  /// lib/features/wallet/swap_screens.dart:1054
  ///
  /// In en, this message translates to:
  /// **'The provider chooses the route'**
  String get wallet_swapScreensSwapRoutingNoticeTitle;

  /// lib/features/wallet/swap_screens.dart:380
  ///
  /// In en, this message translates to:
  /// **'I understand the price impact is between 1% and 5% and want to continue'**
  String get wallet_swapScreensText;

  /// lib/features/wallet/swap_screens.dart:496
  ///
  /// In en, this message translates to:
  /// **'Choose asset to pay'**
  String get wallet_swapScreensTitle;

  /// lib/features/wallet/swap_screens.dart:496
  ///
  /// In en, this message translates to:
  /// **'Choose asset to receive'**
  String get wallet_swapScreensTitle2;

  /// lib/features/wallet/swap_screens.dart:867, lib/features/wallet/swap_screens.dart:1011
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get wallet_swapScreensValue;

  /// lib/features/wallet/swap_screens.dart:986
  ///
  /// In en, this message translates to:
  /// **'{display} {symbol} (slippage {moneySlippageLabel})'**
  String wallet_swapScreensValue2(
    Object? display,
    Object? moneySlippageLabel,
    Object? symbol,
  );

  /// lib/features/wallet/swap_screens.dart:886
  ///
  /// In en, this message translates to:
  /// **' · Pending product confirmation'**
  String get wallet_swapScreensWalletSwapScreensSwapQuoteProvenanceText;

  /// lib/features/wallet/tx_result_screen.dart:323
  ///
  /// In en, this message translates to:
  /// **'{action} cancelled'**
  String wallet_txResultCancelled(Object? action);

  /// lib/features/wallet/tx_result_screen.dart:319
  ///
  /// In en, this message translates to:
  /// **'{action} confirmed'**
  String wallet_txResultConfirmed(Object? action);

  /// lib/features/wallet/tx_result_screen.dart:233
  ///
  /// In en, this message translates to:
  /// **'This action has no readable status'**
  String get wallet_txResultEmptyMessage;

  /// lib/features/wallet/tx_result_screen.dart:324
  ///
  /// In en, this message translates to:
  /// **'{action} expired'**
  String wallet_txResultExpired(Object? action);

  /// lib/features/wallet/tx_result_screen.dart:321
  ///
  /// In en, this message translates to:
  /// **'{action} failed'**
  String wallet_txResultFailed(Object? action);

  /// lib/features/wallet/tx_result_screen.dart:334
  ///
  /// In en, this message translates to:
  /// **'Result, transaction hash and next steps are all here; no new quotes are mixed in.'**
  String get wallet_txResultIf;

  /// lib/features/wallet/tx_result_screen.dart:336
  ///
  /// In en, this message translates to:
  /// **'Block {groupedFigure} · {receipt}'**
  String wallet_txResultIf2(Object? groupedFigure, Object? receipt);

  /// lib/features/wallet/tx_result_screen.dart:190
  ///
  /// In en, this message translates to:
  /// **'Transaction confirmed'**
  String get wallet_txResultMessage;

  /// lib/features/wallet/tx_result_screen.dart:320
  ///
  /// In en, this message translates to:
  /// **'{action} reverted'**
  String wallet_txResultReverted(Object? action);

  /// lib/features/wallet/tx_result_screen.dart:334
  ///
  /// In en, this message translates to:
  /// **'{groupedFigure} confirmations'**
  String wallet_txResultS(Object? groupedFigure);

  /// lib/features/wallet/tx_result_screen.dart:325
  ///
  /// In en, this message translates to:
  /// **'{action} in progress'**
  String wallet_txResultSwitch(Object? action);

  /// lib/features/wallet/tx_result_screen.dart:350
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get wallet_txResultSwitch2;

  /// lib/features/wallet/tx_result_screen.dart:375
  ///
  /// In en, this message translates to:
  /// **'Latest status.'**
  String get wallet_txResultSwitch3;

  /// lib/features/wallet/tx_result_screen.dart:409
  ///
  /// In en, this message translates to:
  /// **'Provider action'**
  String get wallet_txResultTxResultActionIdLabel;

  /// lib/features/wallet/tx_result_screen.dart:222
  ///
  /// In en, this message translates to:
  /// **'Transaction status can\'t be read right now'**
  String get wallet_txResultTxResultCapabilityBlockTitle;

  /// lib/features/wallet/wallet_activity_export.dart:75
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get wallet_txResultTxResultConfirmationsLabel;

  /// lib/features/wallet/tx_result_screen.dart:417
  ///
  /// In en, this message translates to:
  /// **'No receipt yet'**
  String get wallet_txResultTxResultConfirmationsValue;

  /// lib/features/wallet/tx_result_screen.dart:419
  ///
  /// In en, this message translates to:
  /// **'Chain head can\'t be loaded'**
  String get wallet_txResultTxResultConfirmationsValue2;

  /// lib/features/wallet/tx_result_screen.dart:167
  ///
  /// In en, this message translates to:
  /// **'When you come here from a Send, approval or Swap signing page, this page shows that transaction\'s status.'**
  String get wallet_txResultTxResultEmptyMessage;

  /// lib/features/wallet/tx_result_screen.dart:166
  ///
  /// In en, this message translates to:
  /// **'No action to show here yet'**
  String get wallet_txResultTxResultEmptyTitle;

  /// lib/features/wallet/tx_result_screen.dart:160
  ///
  /// In en, this message translates to:
  /// **'The result page shows one specific action and needs to know which one.'**
  String get wallet_txResultTxResultFolioCaption;

  /// lib/features/wallet/tx_result_screen.dart:214
  ///
  /// In en, this message translates to:
  /// **'The result follows the on-chain check; this page doesn\'t decide success on its own.'**
  String get wallet_txResultTxResultFolioCaption2;

  /// lib/features/wallet/tx_result_screen.dart:159
  ///
  /// In en, this message translates to:
  /// **'No result to show'**
  String get wallet_txResultTxResultFolioHeading;

  /// lib/features/wallet/tx_result_screen.dart:213
  ///
  /// In en, this message translates to:
  /// **'Loading result'**
  String get wallet_txResultTxResultFolioHeading2;

  /// lib/features/wallet/tx_result_screen.dart:293
  ///
  /// In en, this message translates to:
  /// **'Forward message'**
  String get wallet_txResultTxResultForwardLabel;

  /// lib/features/wallet/tx_result_screen.dart:425
  ///
  /// In en, this message translates to:
  /// **'Gas used'**
  String get wallet_txResultTxResultGasLabel;

  /// lib/features/wallet/wallet_activity_export.dart:72
  ///
  /// In en, this message translates to:
  /// **'Transaction hash'**
  String get wallet_txResultTxResultHashLabel;

  /// lib/features/wallet/tx_result_screen.dart:403
  ///
  /// In en, this message translates to:
  /// **'Not reported yet'**
  String get wallet_txResultTxResultHashValue;

  /// lib/features/wallet/tx_result_screen.dart:300
  ///
  /// In en, this message translates to:
  /// **'Merge into long image'**
  String get wallet_txResultTxResultMergeLabel;

  /// lib/features/wallet/tx_result_screen.dart:265
  ///
  /// In en, this message translates to:
  /// **'A successful submission doesn\'t mean it\'s done on-chain; it still needs 15 block confirmations.'**
  String get wallet_txResultTxResultPendingBody;

  /// lib/features/wallet/tx_result_screen.dart:264
  ///
  /// In en, this message translates to:
  /// **'Submitted, waiting for receipt'**
  String get wallet_txResultTxResultPendingTitle;

  /// lib/features/wallet/tx_result_screen.dart:274
  ///
  /// In en, this message translates to:
  /// **'{maximumPollFailures} reads failed in a row, so this page has stopped retrying automatically. This action\'s status hasn\'t changed; retry manually.'**
  String wallet_txResultTxResultPollingStoppedBody(Object? maximumPollFailures);

  /// lib/features/wallet/tx_result_screen.dart:272
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh stopped'**
  String get wallet_txResultTxResultPollingStoppedTitle;

  /// lib/features/wallet/tx_result_screen.dart:150, lib/features/wallet/tx_result_screen.dart:158, lib/features/wallet/tx_result_screen.dart:204, lib/features/wallet/tx_result_screen.dart:212
  ///
  /// In en, this message translates to:
  /// **'Transaction result'**
  String get wallet_txResultTxResultScreenTitle;

  /// lib/features/wallet/tx_result_screen.dart:245
  ///
  /// In en, this message translates to:
  /// **'{reasonCodeText} This page will only keep checking and won\'t submit again; don\'t sign again.'**
  String wallet_txResultTxResultUnknownLockBody(Object? reasonCodeText);

  /// lib/features/wallet/tx_result_screen.dart:243
  ///
  /// In en, this message translates to:
  /// **'Result unknown, locked'**
  String get wallet_txResultTxResultUnknownLockTitle;

  /// lib/features/wallet/tx_result_screen.dart:256
  ///
  /// In en, this message translates to:
  /// **'If the wallet already broadcast this transaction, it may be on-chain and only the report failed. Come back and retry later; don\'t sign again until the submission is accepted.'**
  String get wallet_txResultTxResultUnreportedBody;

  /// lib/features/wallet/tx_result_screen.dart:254
  ///
  /// In en, this message translates to:
  /// **'This submission hasn\'t been recorded yet'**
  String get wallet_txResultTxResultUnreportedTitle;

  /// lib/features/wallet/tx_result_screen.dart:435
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get wallet_txResultTxResultUpdatedLabel;

  /// lib/features/wallet/tx_result_screen.dart:322
  ///
  /// In en, this message translates to:
  /// **'{action} result unknown'**
  String wallet_txResultUnknown(Object? action);

  /// lib/features/wallet/tx_result_screen.dart:334
  ///
  /// In en, this message translates to:
  /// **'Confirmations can\'t be loaded'**
  String get wallet_txResultWalletMoneyActionsMoneyFactsFooterText;
}

class _LoopLocalizationsDelegate
    extends LocalizationsDelegate<LoopLocalizations> {
  const _LoopLocalizationsDelegate();

  @override
  Future<LoopLocalizations> load(Locale locale) {
    return SynchronousFuture<LoopLocalizations>(
      lookupLoopLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_LoopLocalizationsDelegate old) => false;
}

LoopLocalizations lookupLoopLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LoopLocalizationsEn();
    case 'zh':
      return LoopLocalizationsZh();
  }

  throw FlutterError(
    'LoopLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
