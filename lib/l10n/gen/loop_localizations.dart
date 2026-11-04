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

  /// lib/features/square/square_feed_view.dart:579
  ///
  /// In en, this message translates to:
  /// **'Market cap {memeCapLabel}'**
  String square_feedViewNull(Object? memeCapLabel);

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
