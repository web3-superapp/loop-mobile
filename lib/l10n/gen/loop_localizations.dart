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
