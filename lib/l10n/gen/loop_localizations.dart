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
