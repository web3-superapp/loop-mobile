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
  /// **'24h volume {launch2Usd1Label}'**
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
  /// **'Published at'**
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
  /// **'{launch2BpsLabel} + dynamic sell tax'**
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
