// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'loop_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LoopLocalizationsEn extends LoopLocalizations {
  LoopLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get account_emailAuthControllerErrorMessage =>
      'A Privy Mobile App Client ID is required.';

  @override
  String get account_emailAuthControllerErrorMessage10 =>
      'Provide a Privy Mobile App Client ID with --dart-define first.';

  @override
  String get account_emailAuthControllerErrorMessage11 =>
      'Sign-in didn\'t finish. Check your network and the app redirect, then try again.';

  @override
  String get account_emailAuthControllerErrorMessage12 =>
      'Provide a valid Reown Project ID with --dart-define first.';

  @override
  String get account_emailAuthControllerErrorMessage13 =>
      'Provide a Privy Client ID and a Reown Project ID with --dart-define first.';

  @override
  String get account_emailAuthControllerErrorMessage14 =>
      'Only a signed-out session or a verified Privy account can connect a wallet.';

  @override
  String get account_emailAuthControllerErrorMessage15 =>
      'The wallet action didn\'t finish. Check your network and the app redirect, then try again.';

  @override
  String get account_emailAuthControllerErrorMessage16 =>
      'Only a verified Privy account can unlink a wallet.';

  @override
  String get account_emailAuthControllerErrorMessage17 =>
      'Unlinking didn\'t finish. Check your network and try again.';

  @override
  String get account_emailAuthControllerErrorMessage2 =>
      'Enter a valid email address.';

  @override
  String get account_emailAuthControllerErrorMessage3 => 'Resend the code.';

  @override
  String get account_emailAuthControllerErrorMessage4 =>
      'No attempts left. Resend the code.';

  @override
  String get account_emailAuthControllerErrorMessage5 =>
      'Enter the 6-digit code.';

  @override
  String account_emailAuthControllerErrorMessage6(Object? userMessage) {
    return '$userMessage No attempts left. Resend the code.';
  }

  @override
  String account_emailAuthControllerErrorMessage7(
    Object? emailAuthMaximumAttempts,
    Object? userMessage,
  ) {
    return '$userMessage Attempts left: $emailAuthMaximumAttempts.';
  }

  @override
  String get account_emailAuthControllerErrorMessage8 =>
      'Sign in with Apple is only available on iOS.';

  @override
  String get account_emailAuthControllerErrorMessage9 =>
      'The session changed. Check again.';

  @override
  String get account_emailAuthControllerSuccessMessage =>
      'External wallet linked as a Privy sign-in method.';

  @override
  String get account_emailAuthControllerSuccessMessage2 =>
      'External wallet unlinked.';

  @override
  String get account_idSetupHintText =>
      '1–40 characters, doesn\'t have to be unique';

  @override
  String get account_idSetupHintText2 => 'A line about yourself (optional)';

  @override
  String get account_idSetupIdentityStepCopy =>
      'Others see your avatar and username in chats. Your wallet address stays private.';

  @override
  String get account_idSetupLabel => 'Load';

  @override
  String get account_idSetupLoopIdActivatedBody =>
      'Your bio wasn\'t saved. You can add it later in \"Edit profile\".';

  @override
  String get account_idSetupLoopIdActivatedBody2 =>
      'You can change it later in \"Edit profile\".';

  @override
  String get account_idSetupLoopIdActivatedTitle => 'Profile saved';

  @override
  String get account_idSetupLoopIdAliasSuggestLabel => 'Try another';

  @override
  String get account_idSetupLoopIdEmptyMessage =>
      'Account profile hasn\'t loaded yet.';

  @override
  String get account_idSetupLoopIdEmptyTitle =>
      'Your LOOP ID hasn\'t loaded yet';

  @override
  String get account_idSetupLoopIdErrorSource => 'Profile service';

  @override
  String get account_idSetupLoopIdFailureTitle => 'Couldn\'t save';

  @override
  String get account_idSetupLoopIdSubmitTitle => 'Complete your profile';

  @override
  String get account_idSetupLoopIdUnavailableTitle =>
      'Profile service isn\'t available right now';

  @override
  String get account_idSetupLoopIdValue => 'Not assigned yet';

  @override
  String get account_idSetupLoopLabel => 'Username';

  @override
  String get account_idSetupLoopLabel2 => 'Bio';

  @override
  String get account_idSetupLoopOfflineState => 'Save profile';

  @override
  String get account_idSetupSubmitting => 'Submitting…';

  @override
  String get account_idSetupText =>
      'System-generated, unique and permanent. Friends can find you with it.';

  @override
  String get account_onboardingCommunitiesDetail =>
      'Muting the communities you just joined…';

  @override
  String get account_onboardingCommunitiesIf => 'Continue to LOOP';

  @override
  String get account_onboardingCommunitiesIf2 =>
      'Pick a few communities you like. They\'re muted after you join, and you can leave anytime.';

  @override
  String get account_onboardingCommunitiesJoined => 'Joined · Muted';

  @override
  String get account_onboardingCommunitiesJoinedMutePending =>
      'Joined · Muting';

  @override
  String get account_onboardingCommunitiesLoopRecordRow => 'Couldn\'t join';

  @override
  String account_onboardingCommunitiesMembers(Object? formatDecimal) {
    return '$formatDecimal members';
  }

  @override
  String get account_onboardingCommunitiesOnboardingCommunitiesScreenTitle =>
      'Join communities';

  @override
  String get account_onboardingCommunitiesOnboardingCommunitiesSkipLabel =>
      'Skip';

  @override
  String
  get account_onboardingCommunitiesOnboardingCommunitiesStateEmptyMessage =>
      'No communities to join yet';

  @override
  String
  get account_onboardingCommunitiesOnboardingCommunitiesStateEmptyReason =>
      'Enter LOOP first and find communities in Square later.';

  @override
  String get account_onboardingCommunitiesResource => 'Recommended communities';

  @override
  String account_onboardingCommunitiesRowSelectedSemanticLabel(
    Object? members,
    Object? name,
  ) {
    return '$name, $members, selected';
  }

  @override
  String account_onboardingCommunitiesRowUnselectedSemanticLabel(
    Object? members,
    Object? name,
  ) {
    return '$name, $members, not selected';
  }

  @override
  String account_onboardingCommunitiesS(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Join $count communities and enter',
      one: 'Join 1 community and enter',
    );
    return '$_temp0';
  }

  @override
  String get account_onboardingCommunitiesState => 'Joined';

  @override
  String get account_onboardingCommunitiesState2 => 'Not selected';

  @override
  String get account_onboardingCommunitiesTitle => 'Entering LOOP';

  @override
  String get account_privyLoginAnotherAccountLabel => 'Use another account';

  @override
  String account_privyLoginAuthMethodBusyLabel(Object? label) {
    return '$label, in progress';
  }

  @override
  String get account_privyLoginEnterDevelopmentPreviewButtonLabel =>
      'Enter development preview';

  @override
  String get account_privyLoginIf => 'Welcome to LOOP';

  @override
  String get account_privyLoginIf2 =>
      'Choose a way to sign in or create an account';

  @override
  String get account_privyLoginMessage =>
      'Once you\'re online, sign-in on this device is confirmed automatically. No need to sign in again.';

  @override
  String get account_privyLoginPrivyAppleLoginButtonLabel =>
      'Sign in with Apple';

  @override
  String get account_privyLoginPrivyAuthConfigurationIncompleteBody =>
      'The Privy Mobile App Client ID is missing, so real code requests stay off.';

  @override
  String get account_privyLoginPrivyAuthConfigurationIncompleteTitle =>
      'Sign-in setup is incomplete';

  @override
  String get account_privyLoginPrivyAuthErrorTitle => 'Can\'t continue';

  @override
  String get account_privyLoginPrivyAuthPrimaryButtonLabel => 'Sending…';

  @override
  String get account_privyLoginPrivyAuthPrimaryButtonLabel2 => 'Get code';

  @override
  String get account_privyLoginPrivyEmailLoginButtonLabel =>
      'Sign in with email';

  @override
  String get account_privyLoginPrivyEmailScreenTitle => 'Email sign-in';

  @override
  String get account_privyLoginPrivyGoogleLoginButtonLabel =>
      'Sign in with Google';

  @override
  String get account_privyLoginPrivyRestoreUnavailableScreenSemanticLabel =>
      'LOOP can\'t confirm your sign-in right now';

  @override
  String get account_privyLoginPrivyRestoreUnavailableScreenStatus =>
      'Can\'t confirm sign-in right now';

  @override
  String get account_privyLoginPrivyRestoringScreenSemanticLabel =>
      'LOOP is restoring your sign-in';

  @override
  String get account_privyLoginPrivySigningOutScreenSemanticLabel =>
      'LOOP is signing you out';

  @override
  String get account_privyLoginPrivySigningOutScreenStatus => 'Signing out';

  @override
  String get account_privyLoginPrivyWalletLoginButtonLabel =>
      'Connecting wallet';

  @override
  String get account_privyLoginPrivyWalletLoginButtonLabel2 =>
      'Have a wallet? Connect it';

  @override
  String get account_privyLoginRestoringTitle => 'Restoring sign-in';

  @override
  String get account_privyLoginS => 'Unavailable · No valid Reown Project ID';

  @override
  String get account_privyLoginSlowMessage =>
      'Slow network, still restoring sign-in…';

  @override
  String get account_privyLoginText =>
      'Unavailable · No Privy Mobile App Client ID';

  @override
  String get account_privyLoginText2 => 'By continuing, you agree to the ';

  @override
  String get account_privyLoginText3 => 'Terms of Service';

  @override
  String get account_privyLoginText4 => ' and ';

  @override
  String get account_privyLoginText5 => 'Privacy Policy';

  @override
  String get account_privyLoginText6 => 'Have a wallet? ';

  @override
  String get account_privyLoginText7 => 'Connecting…';

  @override
  String get account_privyLoginTitle =>
      'Network unavailable, waiting to connect';

  @override
  String get account_privyOtpIdentityStepCopy => 'No code sent yet';

  @override
  String account_privyOtpIdentityStepCopy2(Object? maskEmailForDisplay) {
    return 'Code sent to $maskEmailForDisplay';
  }

  @override
  String get account_privyOtpIdentityStepCopyTitle => 'Verify email';

  @override
  String get account_privyOtpLoopOfflineState => 'Resend code';

  @override
  String account_privyOtpPrivyOtpCaretLabel(Object? index) {
    return 'Code digit $index';
  }

  @override
  String get account_privyOtpPrivyOtpCaretValue => 'Empty';

  @override
  String get account_privyOtpPrivyOtpChangeEmailLabel => 'Change email';

  @override
  String get account_privyOtpPrivyOtpErrorTitle => 'Verification failed';

  @override
  String get account_privyOtpPrivyOtpNoDestinationMessage =>
      'Go back and enter your email.';

  @override
  String get account_privyOtpPrivyOtpNoDestinationTitle => 'No email to verify';

  @override
  String account_privyOtpPrivyOtpResendHint(Object? cooldown) {
    return 'Resend in ${cooldown}s';
  }

  @override
  String get account_privyOtpPrivyOtpResendLabel => 'Resend';

  @override
  String get account_screensAppLockRow => 'Screen lock not read yet';

  @override
  String account_screensAppLockRow2(Object? detail) {
    return '$detail · Applies now; won\'t be remembered after the app restarts';
  }

  @override
  String get account_screensBody =>
      'It isn\'t a LOOP trading wallet and can\'t authorize any transaction.';

  @override
  String get account_screensBody2 =>
      'Your community tokens stay where they are. Once linked, your holdings count toward power. That\'s why the external wallet option stays.';

  @override
  String get account_screensBody3 =>
      'Connecting asks for one signature to prove ownership. No assets move. Cancelling the signature changes nothing.';

  @override
  String get account_screensBody4 =>
      'The session expired. Come back to this page and connect again.';

  @override
  String get account_screensBody5 =>
      'If you lose your email or sign-in method, you lose the wallet too. Adding another method is safer; you can add one once they open.';

  @override
  String get account_screensCloud => 'Automatic recovery';

  @override
  String get account_screensCloud2 =>
      'Recover with your sign-in method; on a new device, sign in with the same email';

  @override
  String get account_screensDetail => 'Pick 3 guardians; any 2 can recover';

  @override
  String get account_screensDetail2 =>
      'Export anytime. It\'s your escape hatch';

  @override
  String get account_screensExternalWalletConnectLabel =>
      'Choose a wallet and sign';

  @override
  String get account_screensExternalWalletConnectTitle => 'Connect wallet';

  @override
  String get account_screensExternalWalletListUnavailableDetail =>
      'Available wallet names show after you connect a wallet.';

  @override
  String get account_screensExternalWalletListUnavailableMessage =>
      'Can\'t read the installed wallet list right now';

  @override
  String get account_screensExternalWalletUnavailableBody =>
      'No valid Reown Project ID or Privy Client ID. With no connection channel, no installed wallets are listed here.';

  @override
  String get account_screensExternalWalletUnavailableTitle =>
      'External wallet connection isn\'t available right now';

  @override
  String account_screensIdentityProgressTrackLabel(
    Object? label,
    Object? step,
    Object? total,
  ) {
    return 'Step $step of $total: $label';
  }

  @override
  String get account_screensIdentityStepCopy =>
      'Connecting only proves ownership. No assets move.';

  @override
  String get account_screensIdentityStepCopy2 =>
      'Your secure wallet is setting up on this device.';

  @override
  String get account_screensIdentityStepCopy3 =>
      'Your wallet already has one recovery method. Add the others once they open.';

  @override
  String get account_screensIdentityStepCopy4 =>
      'App lock is handled by this device; transaction verification by the sign-in service.';

  @override
  String get account_screensLabel => 'LOOP is loading';

  @override
  String get account_screensLabel2 => 'Choose wallet';

  @override
  String get account_screensLabel3 => 'Create wallet';

  @override
  String account_screensLabel4(Object? title) {
    return '$title, done';
  }

  @override
  String account_screensLabel5(Object? pendingDetail, Object? title) {
    return '$title, not done: $pendingDetail';
  }

  @override
  String get account_screensLoopLabel => 'Wallets you can connect';

  @override
  String get account_screensLoopLabel2 => 'Also';

  @override
  String get account_screensLoopLabel3 => 'App lock';

  @override
  String get account_screensLoopLabel4 => 'Transaction verification';

  @override
  String get account_screensLoopSplashEnterLabel => 'Enter LOOP';

  @override
  String account_screensMethodSelectableSemanticLabel(Object? title) {
    return '$title, optional';
  }

  @override
  String account_screensMethodSelectedSemanticLabel(Object? title) {
    return '$title, selected';
  }

  @override
  String get account_screensMfaRow => 'Loading…';

  @override
  String get account_screensMfaRow2 => 'Sign-in service unreachable this run';

  @override
  String get account_screensMfaRow3 => 'No answer from the sign-in service yet';

  @override
  String get account_screensPasskey => 'Passkey (recommended)';

  @override
  String get account_screensPasskey2 =>
      'Uses device biometrics and syncs with the system keychain';

  @override
  String get account_screensPasskeyBoundDetail =>
      'The sign-in service says this account already has a passkey';

  @override
  String get account_screensPendingDetail => 'Done once the wallet appears';

  @override
  String get account_screensPendingDetail2 => 'Done after the choice in step 3';

  @override
  String get account_screensPendingDetail3 => 'Done after step 5';

  @override
  String get account_screensPreparingText => 'Preparing your account…';

  @override
  String get account_screensS => 'Not done';

  @override
  String account_screensS2(Object? named) {
    return 'The sign-in service says this account already has a passkey: $named';
  }

  @override
  String account_screensSecurityAppLockSemanticLabel(Object? detail) {
    return 'App lock, unavailable: $detail';
  }

  @override
  String get account_screensSecurityAppLockSemanticLabel2 =>
      'App lock, on. Tap and verify to turn off';

  @override
  String get account_screensSecurityAppLockSemanticLabel3 =>
      'App lock, off. Tap and verify to turn on';

  @override
  String get account_screensSecurityAppLockTrailing => 'Off';

  @override
  String get account_screensSecurityBiometricFallbackLine =>
      'If the device doesn\'t support biometrics, the system screen lock passcode is used instead.';

  @override
  String get account_screensSecurityMfaSemanticLabel =>
      'MFA, off. Tap to turn on';

  @override
  String account_screensSecurityMfaSemanticLabel2(Object? detail) {
    return 'MFA, on: $detail';
  }

  @override
  String account_screensSecurityMfaSemanticLabel3(Object? reason) {
    return 'MFA, unavailable: $reason';
  }

  @override
  String get account_screensSecuritySetupContinueTitle => 'Security setup';

  @override
  String account_screensSemanticLabel(Object? title) {
    return '$title, available but off';
  }

  @override
  String account_screensSemanticLabel2(
    Object? title,
    Object? unavailableReason,
  ) {
    return '$title, unavailable: $unavailableReason';
  }

  @override
  String account_screensSemanticLabel3(Object? reason, Object? title) {
    return '$title, enabled: $reason';
  }

  @override
  String account_screensSemanticLabel4(Object? detail, Object? title) {
    return '$title, set up: $detail. Tap to unlink';
  }

  @override
  String account_screensSemanticLabel5(Object? reason, Object? title) {
    return '$title, unavailable: $reason';
  }

  @override
  String account_screensSemanticLabel6(Object? title) {
    return '$title, available';
  }

  @override
  String get account_screensStep => 'Done';

  @override
  String get account_screensSummary => 'Scan to connect and failure notes';

  @override
  String get account_screensSummary2 =>
      'Other recovery methods and the risk of skipping';

  @override
  String get account_screensSwitch => 'Wallet created';

  @override
  String get account_screensSwitch2 =>
      'This account already has a built-in wallet. LOOP doesn\'t use recovery phrases.';

  @override
  String get account_screensSwitch3 => 'Creating your wallet';

  @override
  String get account_screensSwitch4 =>
      'Keys are generated on this device and never leave it. LOOP doesn\'t use recovery phrases.';

  @override
  String get account_screensSwitch5 =>
      'Your wallet is still being created. You can continue for now';

  @override
  String get account_screensSwitch6 =>
      'No wallet after 60 seconds. That doesn\'t mean it failed. LOOP doesn\'t use recovery phrases.';

  @override
  String get account_screensSwitch7 => 'Not started yet';

  @override
  String get account_screensSwitch8 =>
      'Privy hasn\'t confirmed built-in wallet support, so this page won\'t fake progress. LOOP doesn\'t use recovery phrases.';

  @override
  String get account_screensTitle =>
      'An external wallet is only a sign-in method';

  @override
  String get account_screensTitle10 =>
      'Automatic recovery depends on your sign-in method';

  @override
  String get account_screensTitle2 => 'Connect an existing wallet to mine';

  @override
  String get account_screensTitle3 => 'Signature rejected';

  @override
  String get account_screensTitle4 => 'Connection timed out';

  @override
  String get account_screensTitle5 => 'Generate key pair';

  @override
  String get account_screensTitle6 => 'Write to secure enclave';

  @override
  String get account_screensTitle7 => 'Link LOOP ID';

  @override
  String get account_screensTitle8 => 'Social recovery 2-of-3';

  @override
  String get account_screensTitle9 => 'Export private key';

  @override
  String get account_screensTrailing => 'Available';

  @override
  String get account_screensTrailing2 => 'Enabled';

  @override
  String get account_screensTrailing3 => 'Set up';

  @override
  String get account_screensTrailing4 => 'Selected';

  @override
  String get account_screensUnknownAccountSurfaceMessage =>
      'Go back to Community. The request has been logged.';

  @override
  String get account_screensUnknownAccountSurfaceTitle => 'Page not found';

  @override
  String get account_screensUnknownAccountSurfaceTitle2 =>
      'This account page isn\'t in the 93-page product list';

  @override
  String get account_screensWalletAutomaticRecoveryEvidence =>
      'Privy built-in wallets recover through your sign-in method by default; on a new device, sign in with the same email (source: Privy)';

  @override
  String get account_screensWalletCreateContinueLabel => 'Set up recovery';

  @override
  String get account_screensWalletCreateContinueTitle => 'Create LOOP wallet';

  @override
  String get account_screensWalletCreateProviderMessageTitle =>
      'Wallet creation didn\'t finish';

  @override
  String get account_screensWalletCreateUnavailableBody =>
      'Privy hasn\'t confirmed built-in wallet support. This page won\'t fake progress, and no wallet was created.';

  @override
  String get account_screensWalletCreateUnavailableTitle =>
      'Wallet creation isn\'t available right now';

  @override
  String get account_screensWalletRecoveryConfirmTitle => 'Recovery methods';

  @override
  String account_screensWalletRecoveryDefaultBody(
    Object? walletAutomaticRecoveryEvidence,
  ) {
    return '$walletAutomaticRecoveryEvidence. LOOP has no recovery phrase; this is the default path.';
  }

  @override
  String get account_screensWalletRecoveryDefaultTitle =>
      'You can already get your assets back on a new phone';

  @override
  String get account_screensWalletRecoveryErrorSource => 'Capability list';

  @override
  String get account_screensWalletRecoveryLaterLabel => 'Set up later';

  @override
  String get account_screensWalletRecoveryProviderPending =>
      'The sign-in service in this version doesn\'t offer this yet';

  @override
  String account_screensWalletRecoveryUnavailableBody(
    Object? walletRecoveryProviderPending,
  ) {
    return '$walletRecoveryProviderPending. The options below aren\'t simulated locally and aren\'t pre-selected.';
  }

  @override
  String get account_screensWalletRecoveryUnavailableTitle =>
      'You can\'t add another one yet';

  @override
  String get app_appUnknownRouteHomeLabel => 'Back to Chat';

  @override
  String get app_appUnknownRouteScreenTitle => 'Page not found';

  @override
  String get app_appUnknownRouteStateMessage => 'This visit has been logged.';

  @override
  String get app_appUnknownRouteStateTitle => 'This address isn\'t a LOOP page';

  @override
  String get app_onboardingSequenceLoopId => 'Create LOOP ID';

  @override
  String get app_onboardingSequenceSecurity => 'Security settings';

  @override
  String get app_onboardingSequenceWalletBackup => 'Set up recovery';

  @override
  String get app_onboardingSequenceWalletCreate => 'Create wallet';

  @override
  String get app_sessionControllerErrorMessage =>
      'You\'re signed out on this device, but LOOP hasn\'t confirmed the server session was revoked.';

  @override
  String get app_sessionControllerErrorMessage2 =>
      'You\'re signed out on this device, but Privy hasn\'t confirmed the remote sign-out.';

  @override
  String get app_sessionControllerPrivyGatewayException =>
      'Signing out. Try again when it finishes.';

  @override
  String get app_sessionControllerPrivyGatewayException2 =>
      'The account changed and no wallet is linked. Try again.';

  @override
  String get app_sessionControllerPrivyGatewayException3 =>
      'Development previews and restricted sessions don\'t create real wallets.';

  @override
  String get app_sessionControllerPrivyGatewayException4 =>
      'The account changed. Check the wallet status again.';

  @override
  String get app_sessionControllerPrivyGatewayException5 =>
      'The wallet status changed. Check it again before continuing.';

  @override
  String get app_walletProvisioningControllerFail =>
      'Wallet creation didn\'t finish. Your account and sign-in are unchanged. Try again later.';

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
  String get community_aiBody => 'Answering…';

  @override
  String community_aiBuild(Object? communityAiTimestamp, Object? label) {
    return '$label · Observed $communityAiTimestamp';
  }

  @override
  String community_aiBuild2(Object? communityAiTimestamp) {
    return 'Observed $communityAiTimestamp';
  }

  @override
  String get community_aiBuild3 =>
      'Choose a reason. The report records only this answer and your choice, not the question you asked.';

  @override
  String get community_aiCommunityAiCapabilitiesEmptyTitle =>
      'This community has no assistant features yet';

  @override
  String get community_aiCommunityAiComposerHintText =>
      'Ask this community\'s AI';

  @override
  String get community_aiCommunityAiComposerUnavailableHintText =>
      'Questions aren\'t available yet';

  @override
  String get community_aiCommunityAiHeadline =>
      'Community AI isn\'t available yet';

  @override
  String get community_aiCommunityAiHeroKicker => 'Community brief';

  @override
  String get community_aiCommunityAiReportSheetBarrierLabel =>
      'Close report options';

  @override
  String get community_aiCommunityAiSourceSheetBarrierLabel =>
      'Close source details';

  @override
  String get community_aiCommunityAiStateEmptyTitle =>
      'Nothing to ask about in this community yet';

  @override
  String get community_aiCommunityAiStatePermissionTitle =>
      'This account can\'t use this assistant yet';

  @override
  String get community_aiCommunityAiStateUnavailableMessage =>
      'This page isn\'t available right now';

  @override
  String get community_aiLabel => 'Reported';

  @override
  String get community_aiLabel2 => 'Report this answer';

  @override
  String community_aiLabel3(Object? sourceId) {
    return 'Source $sourceId';
  }

  @override
  String get community_aiLoopLabel => 'What I can do';

  @override
  String get community_aiLoopLabel2 => 'Try these';

  @override
  String get community_aiLoopLabel3 => 'Planned features';

  @override
  String get community_aiLoopOfflineState => 'Ask';

  @override
  String get community_aiMessage => 'Report submitted';

  @override
  String get community_aiModelsCaption =>
      'Generating from today\'s discussions. Pull down to refresh later.';

  @override
  String get community_aiModelsCaption2 =>
      'Come back tomorrow. The rest of this page isn\'t affected.';

  @override
  String get community_aiModelsCommunityAiBriefPendingHeading =>
      'Generating today\'s summary';

  @override
  String get community_aiModelsCommunityAiBriefQuotaHeading =>
      'Today\'s summary quota is used up';

  @override
  String community_aiModelsCommunityAiGeneratedLabel(
    Object? communityAiTimestamp,
    Object? model,
  ) {
    return 'AI generated · $model · $communityAiTimestamp';
  }

  @override
  String get community_aiModelsCommunityAiKnowledgeLine =>
      'No sources available';

  @override
  String community_aiModelsCommunityAiKnowledgeLine2(
    Object? communityAiTimestamp,
    Object? sourceCount,
  ) {
    return '$sourceCount knowledge sources · Updated $communityAiTimestamp';
  }

  @override
  String get community_aiModelsHarmful => 'Harmful or dangerous';

  @override
  String get community_aiModelsHeading => 'Couldn\'t load today\'s discussions';

  @override
  String get community_aiModelsInaccurate => 'Inaccurate';

  @override
  String get community_aiModelsOffTopic => 'Off topic';

  @override
  String get community_aiModelsOther => 'Other';

  @override
  String get community_aiModelsPrivacy => 'Involves personal privacy';

  @override
  String community_aiModelsS(Object? messageCount) {
    return '$messageCount messages today';
  }

  @override
  String get community_aiModelsSwitch =>
      'No project documents yet, so this can\'t be answered.';

  @override
  String get community_aiModelsSwitch10 =>
      'Couldn\'t read the official group\'s discussions this time.';

  @override
  String get community_aiModelsSwitch11 =>
      'The AI didn\'t answer this time. Try again later.';

  @override
  String get community_aiModelsSwitch12 =>
      'The AI declined this request. Trying again won\'t help.';

  @override
  String get community_aiModelsSwitch13 =>
      'The AI\'s answer was incomplete, so it wasn\'t used.';

  @override
  String get community_aiModelsSwitch14 =>
      'This community has no sources available, so you can\'t ask right now.';

  @override
  String get community_aiModelsSwitch15 =>
      'The AI assistant isn\'t available yet.';

  @override
  String community_aiModelsSwitch16(Object? messageCount) {
    return 'At least $messageCount messages today';
  }

  @override
  String get community_aiModelsSwitch17 =>
      'This community\'s question quota for today is used up. Come back tomorrow.';

  @override
  String get community_aiModelsSwitch18 =>
      'Too many questions. Wait a minute and ask again.';

  @override
  String get community_aiModelsSwitch2 =>
      'No beginner guides yet, so this can\'t be answered.';

  @override
  String get community_aiModelsSwitch3 =>
      'Announcements and official updates aren\'t available yet, so this can\'t be answered.';

  @override
  String get community_aiModelsSwitch4 => 'AI moderation isn\'t available yet.';

  @override
  String get community_aiModelsSwitch5 =>
      'Community analytics isn\'t available yet.';

  @override
  String get community_aiModelsSwitch6 =>
      'Generating today\'s summary. Pull down to refresh later.';

  @override
  String get community_aiModelsSwitch7 =>
      'Today\'s summary quota is used up. Come back tomorrow.';

  @override
  String get community_aiModelsSwitch8 =>
      'Join this community to read its discussions.';

  @override
  String get community_aiModelsSwitch9 =>
      'This community has no official group yet, so there\'s nothing to summarize.';

  @override
  String get community_aiOutlook =>
      'Once available, answers will include sources and observation times. They don\'t replace project announcements.';

  @override
  String get community_aiSentenceGap => ' ';

  @override
  String community_aiSummary(Object? sources) {
    return 'Sources used ($sources)';
  }

  @override
  String community_aiSummary2(Object? omitted) {
    return 'Sources not used ($omitted)';
  }

  @override
  String get community_aiText => 'Project knowledge';

  @override
  String get community_aiText10 =>
      'Price, market cap, liquidity, weight, community power';

  @override
  String get community_aiText11 => 'Community guidance';

  @override
  String get community_aiText12 =>
      'Reminds you to join mining and when weight takes effect';

  @override
  String get community_aiText13 => 'AI moderation';

  @override
  String get community_aiText14 =>
      'Detects scam links, fake CAs, phishing and fake admins';

  @override
  String get community_aiText15 => 'Community analytics';

  @override
  String get community_aiText16 => 'Admins only: DAU, conversion, sentiment';

  @override
  String get community_aiText17 => 'How are tokenomics allocated';

  @override
  String get community_aiText18 => 'How do I join mining';

  @override
  String get community_aiText19 => 'What\'s new this week';

  @override
  String get community_aiText2 => 'Whitepaper, tokenomics, roadmap, FAQ';

  @override
  String get community_aiText3 => 'Community support';

  @override
  String get community_aiText4 =>
      'What a CA is, how to buy, how to join mining';

  @override
  String get community_aiText5 => 'Beginner education';

  @override
  String get community_aiText6 =>
      'Project in 3 minutes, beginner guide, asset safety';

  @override
  String get community_aiText7 => 'Project updates';

  @override
  String get community_aiText8 =>
      'Official X, announcements and blog in daily and weekly digests';

  @override
  String get community_aiText9 => 'Asset info';

  @override
  String get community_contractActivationRequired =>
      'Activate your LOOP ID before using community and social features.';

  @override
  String get community_contractActivationRequired2 =>
      'Activate your LOOP ID before applying for a community. You can resubmit this application after activation.';

  @override
  String get community_contractAliasBlocked =>
      'This name is on the block list. Try another one.';

  @override
  String get community_contractAliasBlocked2 =>
      'This community name is on the block list. Choose another name and submit again.';

  @override
  String get community_contractAliasReserved =>
      'This name is reserved by LOOP. Try another one.';

  @override
  String get community_contractAliasReserved2 =>
      'This community name uses a LOOP reserved word (such as official, support or admin). Choose another name and submit again.';

  @override
  String get community_contractBootstrapRequired =>
      'Your account isn\'t set up yet. Try again later.';

  @override
  String get community_contractBoundAssetTaken =>
      'This token is already linked to another community. Choose another token.';

  @override
  String get community_contractBoundAssetTaken2 =>
      'This token is already linked to another community. Choose another token and submit again.';

  @override
  String get community_contractCancelled =>
      'The request was cancelled and the result is unknown. Check the latest status before retrying.';

  @override
  String get community_contractCommunityBoundAssetUniqueHint =>
      'Each token can be linked to only one community.';

  @override
  String get community_contractIdempotencyConflict =>
      'The same action was already submitted with different content. Check the latest status and try again.';

  @override
  String get community_contractInvalidData =>
      'The response was incomplete, so nothing on this page was used.';

  @override
  String get community_contractNotFound =>
      'This doesn\'t exist, was removed, or isn\'t visible to this account.';

  @override
  String get community_contractOffline =>
      'You\'re offline. Nothing was loaded and nothing was submitted.';

  @override
  String get community_contractOutcomeUnknown =>
      'The response was incomplete and the result isn\'t confirmed. Refresh to check the latest status. Don\'t submit again.';

  @override
  String get community_contractPermissionDenied =>
      'This account doesn\'t have permission for this action.';

  @override
  String get community_contractRateLimited =>
      'Too many searches. Wait a moment and try again.';

  @override
  String get community_contractResourceConflict =>
      'This short link is taken by another community. Choose another one.';

  @override
  String get community_contractResourceConflict2 =>
      'This short link is taken by another community. Choose another one and submit again.';

  @override
  String get community_contractStale =>
      'The status has changed (someone else may have handled it). Refresh and decide again.';

  @override
  String get community_contractSwitch =>
      'Unread count can\'t be loaded right now.';

  @override
  String get community_contractSwitch10 =>
      'The messaging service isn\'t available, so the online count can\'t be checked.';

  @override
  String get community_contractSwitch11 =>
      'Mining rules aren\'t set yet, so power isn\'t shown.';

  @override
  String get community_contractSwitch12 =>
      'Power hasn\'t been calculated yet, so you can\'t sort by power.';

  @override
  String get community_contractSwitch13 =>
      'The last settlement didn\'t finish, so you can\'t sort by power.';

  @override
  String get community_contractSwitch14 =>
      'The last settlement used old rules, so you can\'t sort by power.';

  @override
  String get community_contractSwitch15 =>
      'Mining isn\'t available, so you can\'t sort by power.';

  @override
  String get community_contractSwitch16 =>
      'Discussion counts can\'t be loaded, so this sort isn\'t available.';

  @override
  String get community_contractSwitch17 =>
      'This community\'s discussion count can\'t be loaded right now.';

  @override
  String get community_contractSwitch18 =>
      'This community has no linked asset, so it has no power.';

  @override
  String get community_contractSwitch19 =>
      'This community\'s power weight is still in review.';

  @override
  String get community_contractSwitch2 =>
      'Voice room status can\'t be loaded right now.';

  @override
  String get community_contractSwitch20 =>
      'Community announcements aren\'t available yet.';

  @override
  String get community_contractSwitch21 =>
      'Official links aren\'t available yet.';

  @override
  String get community_contractSwitch22 =>
      'Message previews aren\'t available yet.';

  @override
  String get community_contractSwitch23 =>
      'The asset registry couldn\'t be assembled this time. Try again later.';

  @override
  String get community_contractSwitch24 =>
      'LOOP has no Launch project directory yet, so there\'s nothing to search.';

  @override
  String get community_contractSwitch25 =>
      'The DApp directory isn\'t available yet.';

  @override
  String get community_contractSwitch26 =>
      'Invitation metrics aren\'t available yet.';

  @override
  String get community_contractSwitch27 =>
      'Invite codes aren\'t available yet, so you can\'t share.';

  @override
  String get community_contractSwitch28 =>
      'Communities aren\'t available right now. Try again later.';

  @override
  String get community_contractSwitch29 =>
      'Search isn\'t available right now. Try again later.';

  @override
  String get community_contractSwitch3 =>
      'Online count can\'t be loaded right now.';

  @override
  String get community_contractSwitch4 =>
      'This community has no official channel, so there\'s no online count to check.';

  @override
  String get community_contractSwitch5 =>
      'This community\'s official channel isn\'t set up, so the online count can\'t be checked.';

  @override
  String get community_contractSwitch6 =>
      'Couldn\'t check the online count this time. Retry later.';

  @override
  String get community_contractSwitch7 =>
      'The online count check timed out with no result.';

  @override
  String get community_contractSwitch8 =>
      'This community has more than 500 members, so this version can\'t count who\'s online.';

  @override
  String get community_contractSwitch9 =>
      'Online count wasn\'t checked in this step. Go back to the community page to load it again.';

  @override
  String get community_contractTimedOut =>
      'LOOP timed out. Nothing was loaded and nothing was submitted.';

  @override
  String get community_contractUnavailable =>
      'The community service isn\'t available right now. Try again later.';

  @override
  String get community_contractUnexpected =>
      'The action didn\'t finish. Try again later.';

  @override
  String get community_contractValidationFailed =>
      'Some input isn\'t valid. Fix it and try again.';

  @override
  String get community_contractValidationFailed2 =>
      'The name or bio is too long (name 1–40 characters, bio up to 280). Fix it and submit again.';

  @override
  String get community_discoverBody =>
      'After you submit, the community is \"In review\" and you\'re the owner. The short link can\'t be changed once accepted.';

  @override
  String get community_discoverCaption =>
      'Sorting uses only verifiable numbers: members, creation time, power and 7-day discussions. Popular doesn\'t mean recommended.';

  @override
  String get community_discoverCommunityApplyActionLabel => 'Apply to list';

  @override
  String get community_discoverCommunityDiscoverCapabilityUnavailableTitle =>
      'Communities aren\'t available right now';

  @override
  String get community_discoverCommunityDiscoverOrderingBackLabel =>
      'Sort by most members';

  @override
  String get community_discoverCommunityDiscoverScreenTitle =>
      'Joined communities';

  @override
  String get community_discoverCommunityDiscoverScreenTitle2 =>
      'Discover communities';

  @override
  String get community_discoverDiscussion => 'Most discussed';

  @override
  String get community_discoverEmptyMessage => 'No matching communities';

  @override
  String get community_discoverEmptyReason => 'No communities under this sort.';

  @override
  String community_discoverHeading(num items) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items communities',
      one: '1 community',
    );
    return '$_temp0';
  }

  @override
  String community_discoverHeading2(num items) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items communities loaded',
      one: '1 community loaded',
    );
    return '$_temp0';
  }

  @override
  String get community_discoverKicker => 'Community discovery';

  @override
  String get community_discoverMembers => 'Most members';

  @override
  String community_discoverMessage(Object? label) {
    return '\"$label\" isn\'t available right now';
  }

  @override
  String get community_discoverNewest => 'Newest';

  @override
  String get community_discoverPower => 'Highest power';

  @override
  String get community_discoverResource => 'Community directory';

  @override
  String get community_discoverTitle => 'Submit community application?';

  @override
  String community_homeActivitySentence(Object? clauses) {
    return '$clauses.';
  }

  @override
  String get community_homeBody =>
      'Find communities worth joining by activity, holders and mining weight';

  @override
  String get community_homeBuild => 'Discover';

  @override
  String community_homeBuild2(Object? communityObservedAtLabel) {
    return 'Data observed $communityObservedAtLabel';
  }

  @override
  String community_homeCommunityActivityCaption(Object? mostDiscussed) {
    return '$mostDiscussed is the most active';
  }

  @override
  String community_homeCommunityActivityCaption2(Object? liveVoiceRooms) {
    return '$liveVoiceRooms voice rooms live';
  }

  @override
  String community_homeCommunityActivityCaption3(Object? unreadMessages) {
    return '$unreadMessages unread';
  }

  @override
  String community_homeCommunityMemberCountLabel(Object? groupedFigure) {
    return '$groupedFigure members';
  }

  @override
  String community_homeLabel(Object? label, Object? unreadBadgeLabel) {
    return '$label, $unreadBadgeLabel unread';
  }

  @override
  String community_homeS(Object? count) {
    return 'Discover, $count verified';
  }

  @override
  String get community_homeTitle => 'Discover new communities';

  @override
  String community_logoSemanticLabel(Object? name) {
    return '$name community icon';
  }

  @override
  String community_manageAsyncData(Object? admin, Object? all, Object? owner) {
    return 'Owner $owner · Admin $admin · $all total';
  }

  @override
  String community_manageAsyncError(Object? memberCount) {
    return '$memberCount members';
  }

  @override
  String community_manageBody(Object? communityBoundAssetUniqueHint) {
    return '$communityBoundAssetUniqueHint Linking a token immediately affects the token card and member buy activity on the community page. The short link and verification status can\'t be changed here.';
  }

  @override
  String get community_manageBody2 =>
      'The short link and verification status can\'t be changed here.';

  @override
  String get community_manageBoundAssetLine => 'Not linked';

  @override
  String get community_manageBoundAssetTaken =>
      'This token is already linked to another community. Choose another token. Nothing was changed.';

  @override
  String get community_manageCommunityManageAnnouncementsSubtitle =>
      'Announcements coming soon';

  @override
  String get community_manageCommunityManageAnnouncementsTitle =>
      'Announcements';

  @override
  String get community_manageCommunityManageBoundAssetTitle => 'Linked token';

  @override
  String get community_manageCommunityManageEditProfileSubtitle => 'No bio yet';

  @override
  String get community_manageCommunityManageEditProfileTitle => 'Name and bio';

  @override
  String get community_manageCommunityManageLogoNote =>
      'The community icon, short link and verification status can\'t be changed here. Communities can\'t be dissolved.';

  @override
  String get community_manageCommunityManageLogoNote2 =>
      'The community icon, short link and verification status can\'t be changed here.';

  @override
  String get community_manageCommunityManageMembersTitle =>
      'Members and permissions';

  @override
  String get community_manageCommunityManageMissingIdDetail =>
      'Open this from \"Manage\" at the top right of the community page. This page doesn\'t guess which community to manage.';

  @override
  String get community_manageCommunityManageMissingIdMessage =>
      'Missing community ID';

  @override
  String get community_manageCommunityManagePermissionDetail =>
      'Your role in this community doesn\'t include management. You can still view the community page.';

  @override
  String get community_manageCommunityManagePermissionMessage =>
      'Only the community owner and admins can manage it';

  @override
  String get community_manageCommunityManageScreenTitle =>
      'Community management';

  @override
  String get community_manageCommunityManageShareSubtitle =>
      'Share a poster or copy the community link';

  @override
  String get community_manageCommunityManageShareTitle => 'Community QR card';

  @override
  String get community_manageCommunityManageTransferSubtitle =>
      'Pick a member on the members page. You become an admin after transferring';

  @override
  String get community_manageCommunityManageTransferTitle =>
      'Transfer ownership';

  @override
  String get community_manageCommunityManageVoiceEnterSubtitle =>
      'The community is live';

  @override
  String get community_manageCommunityManageVoiceEnterTitle =>
      'Enter voice room';

  @override
  String get community_manageCommunityManageVoiceOpenSubtitle =>
      'You\'re the host. Your mic is off by default';

  @override
  String get community_manageCommunityManageVoiceOpenTitle =>
      'Start voice room';

  @override
  String get community_manageEmptyMessage => 'Community not found';

  @override
  String get community_manageEmptyReason =>
      'It may have been removed, or isn\'t visible to this account.';

  @override
  String get community_manageGroups =>
      'No registered pools yet, so member buy activity won\'t appear.';

  @override
  String community_manageIf(Object? truncatedAddress) {
    return '$truncatedAddress · Token info can\'t be loaded right now';
  }

  @override
  String get community_manageIf2 => 'Has registered pools';

  @override
  String get community_manageLoopTag => 'Owner only';

  @override
  String get community_manageMessage => 'Nothing was changed';

  @override
  String get community_manageMessage2 => 'Community profile updated';

  @override
  String get community_manageS => 'No registered pools yet';

  @override
  String get community_manageSwitch =>
      'This token isn\'t registered on LOOP, so it can\'t be linked. Nothing was changed.';

  @override
  String get community_manageSwitch2 =>
      'Only the owner can change the linked token. Nothing was changed.';

  @override
  String get community_manageTitle => 'Submit community profile changes?';

  @override
  String get community_membersAdmin => 'No members with this role.';

  @override
  String get community_membersAll => 'This community has no members to show.';

  @override
  String get community_membersBan => 'Ban';

  @override
  String get community_membersBan2 =>
      'Banned members leave the official channel and are removed from the default member directory. You can unban them later under \"Banned\". Banning doesn\'t change personal follows.';

  @override
  String get community_membersBanned => 'Banned members';

  @override
  String get community_membersBanned2 =>
      'This community has no banned members.';

  @override
  String community_membersBody(
    Object? confirmationDetail,
    Object? displayName,
    Object? loopId,
  ) {
    return 'Target: $displayName ($loopId). $confirmationDetail';
  }

  @override
  String get community_membersCommunityMembersMissingIdDetail =>
      'Open this from the community profile. This page doesn\'t guess which community to open.';

  @override
  String get community_membersCommunityMembersSearchClearHintText =>
      'Type the start of an alias';

  @override
  String get community_membersCommunityMembersSearchClearLabel => 'Clear';

  @override
  String get community_membersCommunityMembersSearchClearLabelText =>
      'Search members by alias';

  @override
  String get community_membersCommunityMembersSearchLabel => 'Close search';

  @override
  String get community_membersCommunityMembersSearchLabel2 => 'Search members';

  @override
  String community_membersCommunityMissingHeading(num all) {
    String _temp0 = intl.Intl.pluralLogic(
      all,
      locale: localeName,
      other: '$all members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get community_membersCommunityStateEmptyEmptyMessage =>
      'No matching members';

  @override
  String get community_membersCommunityStateEmptyEmptyMessage2 =>
      'No members under this filter';

  @override
  String get community_membersCommunityStateEmptyEmptyReason =>
      'Aliases match from the start. Try a different beginning.';

  @override
  String get community_membersCommunityStateEmptyPermissionTitle =>
      'No permission to view the member directory';

  @override
  String community_membersConfirmTitle(Object? label) {
    return '$label?';
  }

  @override
  String get community_membersDemote => 'Remove admin';

  @override
  String get community_membersFilterSeg => 'Banned';

  @override
  String get community_membersLabel => 'Manage';

  @override
  String get community_membersMemberDirectoryPresenceNote =>
      'The member directory doesn\'t track presence, so this page doesn\'t show an online count. The community page checks it once.';

  @override
  String get community_membersMembersSegOnlineLabel => 'Online';

  @override
  String community_membersMessage(Object? label) {
    return '$label applied';
  }

  @override
  String get community_membersMute => 'Mute';

  @override
  String get community_membersMuted => 'Muted';

  @override
  String get community_membersPromote => 'Make admin';

  @override
  String get community_membersResource => 'Member directory';

  @override
  String community_membersS(Object? all) {
    return 'All $all';
  }

  @override
  String community_membersS2(Object? owner) {
    return '$owner owner';
  }

  @override
  String community_membersS3(Object? admin) {
    return '$admin admins';
  }

  @override
  String community_membersSubtitle(Object? communityObservedAtLabel) {
    return 'Joined $communityObservedAtLabel';
  }

  @override
  String get community_membersSwitch =>
      'This action is recorded in the community log.';

  @override
  String get community_membersSwitch2 => 'Owner permissions';

  @override
  String get community_membersSwitch3 => 'Admin permissions';

  @override
  String community_membersTitle(Object? displayName) {
    return 'Me · $displayName';
  }

  @override
  String get community_membersTransfer =>
      'After transferring you become an admin. Editing the community profile, appointing admins and transferring again belong to the new owner. You can still mute and ban regular members. This can\'t be undone. Only the new owner can give ownership back.';

  @override
  String get community_membersUnban => 'Unban';

  @override
  String get community_membersUnban2 =>
      'Unbanning restores this member as active, keeps their join date and adds them back to the official channel. They don\'t need to apply again.';

  @override
  String get community_membersUnmute => 'Unmute';

  @override
  String get community_profileBody =>
      'Your profile is saved first, then goes back into the review queue. The short link and verification status can\'t be changed here.';

  @override
  String get community_profileBody2 =>
      'You\'ll appear in the member list after joining.';

  @override
  String get community_profileBody3 =>
      'You\'ll be removed from the member directory after leaving.';

  @override
  String get community_profileBoundAssetTaken =>
      'This token is already linked to another community. Change the token in the profile, then resubmit.';

  @override
  String get community_profileCommunityJoinActionLabel => 'Join community';

  @override
  String get community_profileCommunityMembershipBannedBody =>
      'Community chat and governance aren\'t available';

  @override
  String get community_profileCommunityMembershipBannedTitle =>
      'You\'ve been banned from this community';

  @override
  String get community_profileCommunityOnlineCountExplainLabel =>
      'How the online count works';

  @override
  String get community_profileCommunityOwnerCannotLeaveSemanticLabel =>
      'Leave community, not available to the owner';

  @override
  String get community_profileCommunityOwnerCannotLeaveTitle =>
      'Leave community';

  @override
  String get community_profileCommunityProfileCreateVoiceRoomLabel =>
      'Start room';

  @override
  String get community_profileCommunityProfileOpenAiSubtitle =>
      'Ask about this community';

  @override
  String get community_profileCommunityProfileOpenAiTitle => 'Community AI';

  @override
  String get community_profileCommunityProfileOpenChatLabel => 'Group chat';

  @override
  String get community_profileCommunityProfileOpenVoiceLabel => 'Live';

  @override
  String get community_profileCommunityProfileOpenVoiceSemanticLabel =>
      'Enter voice room · Live';

  @override
  String get community_profileCommunityProfileShareSemanticLabel =>
      'Share community';

  @override
  String get community_profileConfirmLabel => 'Join';

  @override
  String get community_profileLoopLabel => 'Official links';

  @override
  String community_profileLoopLabel2(Object? communityCountLabel) {
    return 'Members $communityCountLabel';
  }

  @override
  String community_profileMessage(Object? label) {
    return '$label link copied';
  }

  @override
  String get community_profileMessage2 =>
      'Resubmitted. Status is back to In review';

  @override
  String get community_profileMessage3 => 'Joined community';

  @override
  String get community_profileMessage4 => 'Left community';

  @override
  String get community_profileResource => 'Community profile';

  @override
  String get community_profileStale =>
      'This application is no longer \"Rejected\". The page has refreshed. Check the latest status.';

  @override
  String community_profileText(Object? communityCountLabel) {
    return '$communityCountLabel online';
  }

  @override
  String get community_profileTitle => 'Resubmit community application?';

  @override
  String get community_profileTitle2 => 'Join this community?';

  @override
  String get community_profileTitle3 => 'Leave this community?';

  @override
  String get community_profileVoiceRoomArrivalOutcome =>
      'Join the community to enter the voice room';

  @override
  String get community_profileVoiceRoomArrivalOutcome2 =>
      'The voice room has ended';

  @override
  String get community_screenCommunityCapabilityUnavailableDeferredMessage =>
      'Communities aren\'t available yet.';

  @override
  String get community_screenCommunityCapabilityUnavailableUnknownMessage =>
      'Communities aren\'t ready yet. Try again later.';

  @override
  String get community_screenCommunityFolioCaption =>
      'Your joined community count appears here once it loads.';

  @override
  String get community_screenCommunityFolioCaption2 =>
      'Community data can\'t be loaded right now, so no figures are shown.';

  @override
  String get community_screenCommunityFolioCaption3 =>
      'Discussion activity and voice rooms aren\'t available yet.';

  @override
  String community_screenCommunityFolioHeading(num miningCount) {
    String _temp0 = intl.Intl.pluralLogic(
      miningCount,
      locale: localeName,
      other: '$miningCount communities mining',
      one: '1 community mining',
    );
    return '$_temp0';
  }

  @override
  String get community_screenCommunityFolioKicker => 'Community index';

  @override
  String get community_screenCommunityJoinedEmptyMessage =>
      'Start from \"Discover communities\". Communities you join appear here.';

  @override
  String get community_screenCommunityViewAllJoinedLabel =>
      'View all joined communities';

  @override
  String get community_screenEmptyMessage => 'No communities joined yet';

  @override
  String get community_screenEmptyReason =>
      'Communities you join are listed here.';

  @override
  String get community_screenHeading => 'Loading';

  @override
  String get community_screenLoopLabel => 'Token communities · Mining';

  @override
  String get community_screenLoopLabel2 => 'Other communities';

  @override
  String get community_screenResource => 'Community data';

  @override
  String community_searchControllerSearchFieldLabel(Object? searchableDomains) {
    return 'Search $searchableDomains';
  }

  @override
  String get community_searchControllerSearchScopeHint =>
      'Nicknames find only discoverable accounts. LOOP IDs match exactly';

  @override
  String get community_searchLabel => 'Enter';

  @override
  String get community_searchLabel2 => 'Following';

  @override
  String community_searchLabel3(Object? name) {
    return 'Remove $name from recent searches';
  }

  @override
  String get community_searchMessage => 'Couldn\'t follow';

  @override
  String community_searchMessage2(Object? label) {
    return '$label can\'t be searched right now';
  }

  @override
  String community_searchMessage3(Object? label) {
    return '$label can\'t be searched right now';
  }

  @override
  String get community_searchMessage4 => 'Nothing to search on the clipboard';

  @override
  String get community_searchResource => 'Search results';

  @override
  String get community_searchSearchCapabilityUnavailableTitle =>
      'Search isn\'t available right now';

  @override
  String get community_searchSearchEmptyEmptyMessage => 'No matching results';

  @override
  String community_searchSearchEmptyEmptyMessage2(Object? searchMinimumRunes) {
    return 'Type at least $searchMinimumRunes characters to search';
  }

  @override
  String get community_searchSearchEmptyEmptyReason =>
      'No results in this category.';

  @override
  String get community_searchSearchEmptyEmptyReason2 =>
      'Search matches from the start and shows only discoverable accounts and verified communities.';

  @override
  String get community_searchSearchEmptyMessage =>
      'Try another keyword or switch the category above';

  @override
  String get community_searchSearchEmptyTitle => 'No matching results found';

  @override
  String get community_searchSearchEmptyTitle2 =>
      'Search tokens, communities and users';

  @override
  String get community_searchSearchPasteLoopIdLabel => 'Paste';

  @override
  String get community_searchSearchPriceAbsentText => 'No price in search';

  @override
  String get community_searchSearchRecentLabelAction => 'Clear all';

  @override
  String get community_searchSearchRecentLabelLabel => 'Recent searches';

  @override
  String community_searchSemanticLabel(Object? title) {
    return '$title, token, recent search';
  }

  @override
  String community_searchSemanticLabel2(Object? memberCount, Object? title) {
    return '$title, $memberCount members';
  }

  @override
  String get community_voiceRoomOpenMessage => 'Voice room started';

  @override
  String get community_voiceRoomOpenMessage2 =>
      'This community already has a live voice room, so no new one was created. Refresh to enter.';

  @override
  String get community_widgetsBarrierLabel => 'Close community profile editor';

  @override
  String get community_widgetsBarrierLabel2 => 'Close community application';

  @override
  String community_widgetsBoundAssetKey(Object? chainId) {
    return 'Needs a 40-character hex contract address, optionally prefixed with $chainId:.';
  }

  @override
  String get community_widgetsCaption => '7-day discussions';

  @override
  String get community_widgetsCommunityAnnouncementsEmptyText =>
      'No announcements yet';

  @override
  String community_widgetsCommunityAnnouncementsUnavailableText(
    Object? communityUnavailableReason,
  ) {
    return 'No announcements yet · $communityUnavailableReason';
  }

  @override
  String get community_widgetsCommunityApplicationPendingBody =>
      'Mining weight and the official group open after approval. Until it\'s verified, this community has no verified badge.';

  @override
  String community_widgetsCommunityApplicationPendingTitle(
    Object? localTimestampLabel,
  ) {
    return 'In review · Submitted $localTimestampLabel';
  }

  @override
  String get community_widgetsCommunityApplicationProgressHint =>
      'Check review progress under Me → My communities → Created.';

  @override
  String get community_widgetsCommunityApplicationRejectedBody =>
      'No reason was given. Edit the community profile and resubmit.';

  @override
  String community_widgetsCommunityApplicationRejectedBody2(Object? reason) {
    return 'Reason: $reason';
  }

  @override
  String get community_widgetsCommunityApplicationResubmitLabel => 'Resubmit';

  @override
  String get community_widgetsCommunityApplySubmitLabel => 'Submit application';

  @override
  String get community_widgetsCommunityApplySubmittedOpenLabel =>
      'View community';

  @override
  String community_widgetsCommunityBoundAssetChainNote(Object? name) {
    return 'Just enter the contract address. $name is filled in for you. ';
  }

  @override
  String community_widgetsCommunityBoundAssetHint(Object? chainId) {
    return '0x… (or paste the full $chainId:0x…)';
  }

  @override
  String get community_widgetsCommunityConfirmAcceptBarrierLabel =>
      'Close confirmation';

  @override
  String get community_widgetsCommunityLinksEmptyText =>
      'No official links yet';

  @override
  String community_widgetsCommunityLinksUnavailableText(
    Object? communityUnavailableReason,
  ) {
    return 'No official links yet · $communityUnavailableReason';
  }

  @override
  String get community_widgetsCommunityMiningPowerParticipantsTitle =>
      'Members with power';

  @override
  String community_widgetsCommunityMiningPowerRowSubtitle(
    Object? communitySettlementLabel,
  ) {
    return 'Latest power snapshot · $communitySettlementLabel';
  }

  @override
  String get community_widgetsCommunityMiningPowerWeightTitle =>
      'Community weight';

  @override
  String get community_widgetsCommunityMissingHeading => 'No value';

  @override
  String get community_widgetsCommunityMissingName => 'No name';

  @override
  String get community_widgetsCommunityOnlineMeaningSheetBarrierLabel =>
      'Close online count details';

  @override
  String community_widgetsCommunityPreviewNoticeBody(Object? resource) {
    return '$resource exists only in this development preview. It isn\'t saved to your account or uploaded.';
  }

  @override
  String get community_widgetsCommunityRejectedReasonPreview =>
      'Rejected: no reason given';

  @override
  String community_widgetsCommunityRejectedReasonPreview2(Object? text) {
    return 'Rejected: $text';
  }

  @override
  String community_widgetsCommunityRejectedReasonPreview3(Object? head) {
    return 'Rejected: $head…';
  }

  @override
  String get community_widgetsCommunityStateUnavailableMessage =>
      'This feature isn\'t available right now';

  @override
  String get community_widgetsDescription =>
      'The bio can be up to 280 characters with no control characters.';

  @override
  String get community_widgetsFor => 'My holdings';

  @override
  String get community_widgetsFor2 => 'My power';

  @override
  String get community_widgetsFor3 => 'Est./day';

  @override
  String get community_widgetsHint =>
      'Short link: lowercase letters, digits and hyphens';

  @override
  String get community_widgetsHint2 => 'Bio (optional)';

  @override
  String community_widgetsHint3(Object? communityBoundAssetHint) {
    return 'Linked token (optional) $communityBoundAssetHint';
  }

  @override
  String community_widgetsIf(Object? localTimestampLabel) {
    return 'Created $localTimestampLabel';
  }

  @override
  String community_widgetsIf2(Object? localTimestampLabel) {
    return 'Submitted $localTimestampLabel';
  }

  @override
  String get community_widgetsLabel => 'Weight';

  @override
  String get community_widgetsLabel2 => 'Community power';

  @override
  String get community_widgetsLabel3 => 'Power snapshot';

  @override
  String get community_widgetsLabel4 => 'Short link (can\'t be changed)';

  @override
  String get community_widgetsLabel5 => 'No community ID';

  @override
  String community_widgetsLabel6(Object? reference) {
    return 'Community ID $reference';
  }

  @override
  String get community_widgetsLabelText => 'Community name';

  @override
  String get community_widgetsLabelText2 => 'Bio (optional)';

  @override
  String get community_widgetsLabelText3 =>
      'Linked token (owner only, optional)';

  @override
  String get community_widgetsLoopOfflineState => 'Block';

  @override
  String get community_widgetsLoopOfflineState2 => 'Governance';

  @override
  String get community_widgetsLoopPageBlock => 'Try again later.';

  @override
  String get community_widgetsLoopSheetHeading =>
      'This counts connections, not activity';

  @override
  String get community_widgetsLoopSheetHeading2 =>
      'Application submitted · In review';

  @override
  String get community_widgetsLoopSheetHeading3 => 'Edit community profile';

  @override
  String get community_widgetsLoopSheetHeading4 => 'Create community';

  @override
  String get community_widgetsMiningCommunityWeightApproved =>
      'Granted after review and included in the figure above';

  @override
  String get community_widgetsMiningCommunityWeightPending =>
      'Weight is still in review, so no value is shown';

  @override
  String get community_widgetsMiningCommunityWeightPending2 =>
      'No linked token, so there\'s no weight to review';

  @override
  String get community_widgetsMiningParticipantsCount =>
      'People with power in the latest power snapshot';

  @override
  String get community_widgetsMiningParticipantsUnavailable =>
      'This item can\'t be loaded right now';

  @override
  String get community_widgetsName =>
      'The name needs 1–40 characters with no control characters.';

  @override
  String community_widgetsRankedSemantic(Object? caption, Object? value) {
    return '$caption $value';
  }

  @override
  String get community_widgetsRejected => 'Rejected';

  @override
  String community_widgetsS(Object? name) {
    return 'Chain status isn\'t loaded yet. If you enter only the address, $name is filled in. ';
  }

  @override
  String community_widgetsSemantic(Object? power, Object? weight) {
    return 'Community mining panel, weight $weight, community power $power';
  }

  @override
  String get community_widgetsSemanticValue => 'Can\'t be loaded right now';

  @override
  String community_widgetsSemanticValue2(Object? messageCount) {
    return 'At least $messageCount';
  }

  @override
  String community_widgetsSemanticValue3(Object? messageCount) {
    return '$messageCount';
  }

  @override
  String community_widgetsShowCommunityApplicationSubmittedSheet(
    Object? communityApplicationProgressHint,
    Object? communityName,
  ) {
    return '\"$communityName\" is in the review queue and you\'re its owner. $communityApplicationProgressHint The verified badge, mining weight and official group appear after approval.';
  }

  @override
  String community_widgetsShowCommunityPresenceMeaningSheet(
    Object? communityCountLabel,
  ) {
    return 'This is how many members of the community\'s official channel are connected to Stream right now ($communityCountLabel). It isn\'t \"watching this channel\", \"recently active\", or the total member count. It\'s a single observation, not a running count.';
  }

  @override
  String get community_widgetsSlug =>
      'The short link must be 3–32 lowercase letters, digits or hyphens.';

  @override
  String get community_widgetsSwitch => 'Community mining';

  @override
  String community_widgetsSwitch2(Object? identifier) {
    return 'Formula version $identifier used by this power snapshot';
  }

  @override
  String community_widgetsText(
    Object? communityBoundAssetChainNote,
    Object? communityBoundAssetUniqueHint,
  ) {
    return '$communityBoundAssetChainNote$communityBoundAssetUniqueHint After you submit it goes into review and you\'re the owner. The verified badge is set after verification.';
  }

  @override
  String community_widgetsValue(Object? communityObservedAtLabel) {
    return '$communityObservedAtLabel · Not updated';
  }

  @override
  String get community_widgetsVerified => 'Verified';

  @override
  String get community_widgetsVerified2 => 'Approved';

  @override
  String get coreAssets_loopLabel => 'Voyager_7 avatar';

  @override
  String get coreAssets_loopLabel10 => 'Community member Echo avatar';

  @override
  String get coreAssets_loopLabel11 => 'Community admin avatar';

  @override
  String get coreAssets_loopLabel12 => 'Community observer avatar';

  @override
  String get coreAssets_loopLabel13 => 'LOOP Official community icon';

  @override
  String get coreAssets_loopLabel14 => 'PEPE Community community icon';

  @override
  String get coreAssets_loopLabel15 => 'BONK Community community icon';

  @override
  String get coreAssets_loopLabel16 => 'MOONCAT community icon';

  @override
  String get coreAssets_loopLabel17 => 'Community mark · Orbit';

  @override
  String get coreAssets_loopLabel18 => 'Community mark · Bolt';

  @override
  String get coreAssets_loopLabel19 => 'Community mark · Wave';

  @override
  String get coreAssets_loopLabel2 => 'NightOwl avatar';

  @override
  String get coreAssets_loopLabel20 => 'Community mark · Hexagon';

  @override
  String get coreAssets_loopLabel21 => 'Community mark · Cube';

  @override
  String get coreAssets_loopLabel22 => 'Community mark · Shield';

  @override
  String get coreAssets_loopLabel23 => 'Community mark · Starburst';

  @override
  String get coreAssets_loopLabel24 => 'Community mark · Signal';

  @override
  String get coreAssets_loopLabel3 => 'pepe_maxi avatar';

  @override
  String get coreAssets_loopLabel4 => 'AlphaDrop avatar';

  @override
  String get coreAssets_loopLabel5 => 'fox_trader avatar';

  @override
  String get coreAssets_loopLabel6 => 'PEPE founder avatar';

  @override
  String get coreAssets_loopLabel7 => 'SmartBuyer avatar';

  @override
  String get coreAssets_loopLabel8 => 'whale_0x9f avatar';

  @override
  String get coreAssets_loopLabel9 => 'DiamondPaw avatar';

  @override
  String get coreConfig_testHintsLoopTestnetChainLabel => 'BSC Testnet';

  @override
  String get coreConfig_testHintsLoopTestnetInfoButtonText =>
      'About the Launch testnet';

  @override
  String get coreConfig_testHintsLoopTestnetNetworkRowAbsent =>
      'No testnet published';

  @override
  String get coreConfig_testHintsLoopTestnetNetworkRowTitle => 'Testnet';

  @override
  String coreConfig_testHintsLoopTestnetNoticeBodyText(Object? chainId) {
    return 'Launch lists, details and sign sheets currently point to BSC Testnet ($chainId); testnet tokens have no real value. Wallet balances, market data, swaps and approvals still use BNB Smart Chain mainnet only and aren\'t affected. You can close this notice; it doesn\'t block anything.';
  }

  @override
  String get coreConfig_testHintsLoopTestnetNoticeDismissText =>
      'Close testnet notice';

  @override
  String get coreConfig_testHintsLoopTestnetNoticeTitleText =>
      'Launch is running on BSC Testnet';

  @override
  String get coreConfig_testHintsLoopTestnetWalletTotalNoteText =>
      'Launch chain balances are on BSC Testnet and don\'t count toward total assets; total assets only count BNB Smart Chain mainnet.';

  @override
  String get coreNavigation_intelPowerRouteInvite => 'Invitation';

  @override
  String get coreNavigation_routeAbout => 'About and legal';

  @override
  String get coreNavigation_routeApprovalGuard => 'Approval guard';

  @override
  String get coreNavigation_routeAsset => 'Asset details';

  @override
  String get coreNavigation_routeAuth => 'Privy sign-in';

  @override
  String get coreNavigation_routeAuthEmail => 'Email sign-in';

  @override
  String get coreNavigation_routeAuthOtp => 'Email code';

  @override
  String get coreNavigation_routeAuthWallet => 'Connect external wallet';

  @override
  String get coreNavigation_routeBetaFeedback => 'Feedback';

  @override
  String get coreNavigation_routeBetaFeedbackMine => 'My feedback';

  @override
  String get coreNavigation_routeBridgeStatus => 'Bridge progress';

  @override
  String get coreNavigation_routeChartFull => 'Full-screen chart';

  @override
  String get coreNavigation_routeChat => 'Chat Tab';

  @override
  String get coreNavigation_routeChatForward => 'Forward message';

  @override
  String get coreNavigation_routeChatMergePreview => 'Forward as one preview';

  @override
  String get coreNavigation_routeChatSearch => 'Message search';

  @override
  String get coreNavigation_routeCommunity => 'Community Tab';

  @override
  String get coreNavigation_routeCommunityChat => 'Community group';

  @override
  String get coreNavigation_routeCommunityDiscover => 'Discover communities';

  @override
  String get coreNavigation_routeCommunityManage => 'Community management';

  @override
  String get coreNavigation_routeCommunityMembers => 'Members and roles';

  @override
  String get coreNavigation_routeCommunityProfile => 'Community home';

  @override
  String get coreNavigation_routeConnections => 'Following and followers';

  @override
  String get coreNavigation_routeDapp => 'DApp browser';

  @override
  String get coreNavigation_routeDappWeb => 'DApp page';

  @override
  String get coreNavigation_routeDevices => 'Device management';

  @override
  String get coreNavigation_routeForceUpdate => 'Force update';

  @override
  String get coreNavigation_routeGroup => 'Group chat';

  @override
  String get coreNavigation_routeGroupInfo => 'Group info';

  @override
  String get coreNavigation_routeIntel => 'Intel Tab';

  @override
  String get coreNavigation_routeKeyExport => 'Private key export';

  @override
  String get coreNavigation_routeLaunch => 'Launch list';

  @override
  String get coreNavigation_routeLaunch2Create => 'Start a v2 launch';

  @override
  String get coreNavigation_routeLaunch2DynamicRewards => 'DEX pool rewards';

  @override
  String get coreNavigation_routeLaunch2Instance => 'MEME v2 project';

  @override
  String get coreNavigation_routeLaunch2Nft => 'Consensus badge';

  @override
  String get coreNavigation_routeLaunch2Project => 'Project status';

  @override
  String get coreNavigation_routeLaunch2ProjectDeployment =>
      'Deployment progress';

  @override
  String get coreNavigation_routeLaunch2ProjectSign => 'Sign deployment';

  @override
  String get coreNavigation_routeLaunch2Projects => 'My projects';

  @override
  String get coreNavigation_routeLaunchApply => 'Apply to launch';

  @override
  String get coreNavigation_routeLaunchDetail => 'Project details';

  @override
  String get coreNavigation_routeLaunchGraduation => 'Graduation and migration';

  @override
  String get coreNavigation_routeLaunchHistory => 'Participation history';

  @override
  String get coreNavigation_routeLaunchHolders => 'Bonding pool holders';

  @override
  String get coreNavigation_routeLaunchRounds => 'Sale round rules';

  @override
  String get coreNavigation_routeLaunchTier => 'My eligibility';

  @override
  String get coreNavigation_routeLaunchTrade => 'Launch subscription';

  @override
  String get coreNavigation_routeLoopEconomy => 'Ecosystem economics';

  @override
  String get coreNavigation_routeLoopIdSetup => 'Create LOOP ID';

  @override
  String get coreNavigation_routeLoopStake => 'LOOP staking';

  @override
  String get coreNavigation_routeMaintenance => 'System maintenance';

  @override
  String get coreNavigation_routeManifestGlobalAccount => 'Global and account';

  @override
  String get coreNavigation_routeManifestSystem =>
      'System states and components';

  @override
  String get coreNavigation_routeMarket => 'Market list';

  @override
  String get coreNavigation_routeMemeCreate => 'Create token';

  @override
  String get coreNavigation_routeMemeToken => 'MEME token';

  @override
  String get coreNavigation_routeMemeTokenHolders => 'MEME holders';

  @override
  String get coreNavigation_routeMemeTokenTrades => 'MEME activity';

  @override
  String get coreNavigation_routeMining => 'My mining';

  @override
  String get coreNavigation_routeMiningAssets => 'Power breakdown';

  @override
  String get coreNavigation_routeMiningCommunity => 'Community mining panel';

  @override
  String get coreNavigation_routeMiningRank => 'Leaderboard';

  @override
  String get coreNavigation_routeMiningRewards => 'Rewards and claims';

  @override
  String get coreNavigation_routeMiningRules => 'Weight and power rules';

  @override
  String get coreNavigation_routeNetworks => 'Networks and RPC';

  @override
  String get coreNavigation_routeNetworth => 'Net worth details';

  @override
  String get coreNavigation_routeNewPairs => 'New pairs';

  @override
  String get coreNavigation_routeNotifications => 'Notification center';

  @override
  String get coreNavigation_routeOffline => 'No network';

  @override
  String get coreNavigation_routeOnboardingCommunities =>
      'Recommended communities';

  @override
  String get coreNavigation_routePay => 'Pay entry';

  @override
  String get coreNavigation_routePermissionNotice => 'Permission notes';

  @override
  String get coreNavigation_routePrivacy => 'Privacy Center';

  @override
  String get coreNavigation_routeProfile => 'LOOP ID home';

  @override
  String get coreNavigation_routeProfileEdit => 'Edit profile';

  @override
  String get coreNavigation_routeReferral => 'Invitations and boost';

  @override
  String get coreNavigation_routeRegionBlocked => 'Region restriction';

  @override
  String get coreNavigation_routeSearch => 'Global search';

  @override
  String get coreNavigation_routeSecuritySetup => 'MFA and app lock';

  @override
  String get coreNavigation_routeSend => 'Send: choose asset';

  @override
  String get coreNavigation_routeSendConfirm => 'Send: confirm';

  @override
  String get coreNavigation_routeSendTo => 'Send: recipient';

  @override
  String get coreNavigation_routeServerError => 'Server error';

  @override
  String get coreNavigation_routeSettings => 'General settings';

  @override
  String get coreNavigation_routeSignSheetStates => 'Four sign sheet states';

  @override
  String get coreNavigation_routeSkeletonStates => 'Three skeleton types';

  @override
  String get coreNavigation_routeSmartMoney => 'Smart money';

  @override
  String get coreNavigation_routeSocialRecovery => 'Social recovery';

  @override
  String get coreNavigation_routeSplash => 'Splash';

  @override
  String get coreNavigation_routeSquare => 'Square Tab';

  @override
  String get coreNavigation_routeSupport => 'Help and support';

  @override
  String get coreNavigation_routeSwapRoute => 'Quote and fees';

  @override
  String get coreNavigation_routeToastStates => 'Three toast states';

  @override
  String get coreNavigation_routeToken => 'Token details';

  @override
  String get coreNavigation_routeTokenCardStates => 'Five Token Card states';

  @override
  String get coreNavigation_routeTokenHolders => 'Holder distribution';

  @override
  String get coreNavigation_routeTokenTrades => 'Trade activity';

  @override
  String get coreNavigation_routeTxHistory => 'Transaction history';

  @override
  String get coreNavigation_routeTxResult => 'Transaction result';

  @override
  String get coreNavigation_routeUserProfile => 'User profile';

  @override
  String get coreNavigation_routeVoiceroomFull => 'Voice room full view';

  @override
  String get coreNavigation_routeWallet => 'Wallet overview';

  @override
  String get coreNavigation_routeWalletCreate => 'Creating wallet';

  @override
  String get coreNavigation_routeWalletRecovery => 'Recovery setup';

  @override
  String get coreNavigation_routeWallets => 'Wallet management';

  @override
  String get coreNavigation_routeWatchlistEdit => 'Edit watchlist';

  @override
  String get coreSecurity_urlReviewConfusableCharacters =>
      'The domain has characters that look like Latin letters';

  @override
  String get coreSecurity_urlReviewCredentialsInUrl =>
      'The address contains a username or password, a common disguise';

  @override
  String get coreSecurity_urlReviewEmpty => 'Input is empty';

  @override
  String get coreSecurity_urlReviewIpLiteralHost =>
      'The address is an IP, not a domain; ownership can\'t be checked';

  @override
  String get coreSecurity_urlReviewMissingHost => 'The address has no domain';

  @override
  String get coreSecurity_urlReviewMixedScriptLabel =>
      'One part of the domain mixes Latin letters with other scripts';

  @override
  String get coreSecurity_urlReviewNonAsciiHost =>
      'The domain has non-ASCII characters; its ASCII form can\'t be computed locally';

  @override
  String get coreSecurity_urlReviewNonStandardPort =>
      'Uses a port other than 443';

  @override
  String get coreSecurity_urlReviewNotHttps =>
      'Only HTTPS is allowed; plain-text or custom schemes are blocked';

  @override
  String get coreSecurity_urlReviewPunycodeLabel =>
      'The domain has an IDN-encoded (xn--) label that can\'t be turned back into readable form locally';

  @override
  String get coreSecurity_urlReviewSchemeAssumed =>
      'No scheme given; read as HTTPS';

  @override
  String get coreSecurity_urlReviewUnsafeCharacters =>
      'The input has control or invisible characters';

  @override
  String get coreText_errorMessage =>
      'The service didn\'t return a recognizable result. Try again later; if you already submitted a funds action, check the latest status first.';

  @override
  String get coreText_errorMessage10 =>
      'This page\'s data is out of date. Refresh before continuing.';

  @override
  String get coreText_errorMessage11 =>
      'The same action was already submitted with different content. Check the latest status, then try again.';

  @override
  String get coreText_errorMessage12 =>
      'The indexer hasn\'t caught up with the latest block; data may lag. Try again later.';

  @override
  String get coreText_errorMessage13 =>
      'Not enough available balance for this action (including fees).';

  @override
  String get coreText_errorMessage14 =>
      'Something went wrong and the result is unconfirmed. Check the latest status before deciding whether to retry.';

  @override
  String get coreText_errorMessage15 =>
      'The request is malformed. Update the app or try again later.';

  @override
  String get coreText_errorMessage16 =>
      'A related service is under maintenance. Try again later.';

  @override
  String get coreText_errorMessage17 =>
      'The requested item doesn\'t exist or was removed.';

  @override
  String get coreText_errorMessage18 =>
      'This account doesn\'t have permission for this action.';

  @override
  String get coreText_errorMessage19 =>
      'This action was blocked by a policy in effect. The feature that started it explains the rule.';

  @override
  String get coreText_errorMessage2 =>
      'Finish setting up your LOOP account to continue.';

  @override
  String get coreText_errorMessage20 =>
      'Community and social actions need an activated LOOP ID. Activate it, then try again.';

  @override
  String get coreText_errorMessage21 =>
      'A required external service isn\'t available right now. Try again later.';

  @override
  String get coreText_errorMessage22 =>
      'The price changed. Refresh the quote before confirming.';

  @override
  String get coreText_errorMessage23 => 'Wait a moment and try again.';

  @override
  String get coreText_errorMessage24 =>
      'This feature isn\'t available in your region.';

  @override
  String get coreText_errorMessage25 =>
      'The service didn\'t respond in time. A timeout doesn\'t mean failure; for funds actions, check the latest status first.';

  @override
  String get coreText_errorMessage26 =>
      'That ID already belongs to something else. Use another one.';

  @override
  String get coreText_errorMessage27 =>
      'The device session expired. Sign in again.';

  @override
  String get coreText_errorMessage28 =>
      'The transaction simulation didn\'t return a verifiable result. Can\'t confirm right now.';

  @override
  String get coreText_errorMessage29 =>
      'The request may have been accepted. Don\'t submit again; wait for reconciliation.';

  @override
  String get coreText_errorMessage3 =>
      'That name is on the current operator list. Try another.';

  @override
  String get coreText_errorMessage30 =>
      'The input doesn\'t meet the requirements. Check it and try again.';

  @override
  String get coreText_errorMessage31 =>
      'The data was changed on another device. Reload before saving.';

  @override
  String get coreText_errorMessage4 =>
      'That name is reserved by LOOP (such as official, support, admin). Try another.';

  @override
  String get coreText_errorMessage5 => 'Your sign-in expired. Sign in again.';

  @override
  String get coreText_errorMessage6 => 'This action needs a signed-in account.';

  @override
  String get coreText_errorMessage7 =>
      'You\'re signed in, but this action needs extra verification.';

  @override
  String get coreText_errorMessage8 =>
      'This feature isn\'t available right now. Try again later.';

  @override
  String get coreText_errorMessage9 =>
      'The requested network doesn\'t match the asset\'s or wallet\'s chain.';

  @override
  String get coreText_errorTitle => 'Can\'t finish right now';

  @override
  String get coreText_errorTitle10 => 'Data out of date';

  @override
  String get coreText_errorTitle11 => 'Duplicate request conflict';

  @override
  String get coreText_errorTitle12 => 'On-chain data delayed';

  @override
  String get coreText_errorTitle13 => 'Insufficient balance';

  @override
  String get coreText_errorTitle14 => 'Internal service error';

  @override
  String get coreText_errorTitle15 => 'Invalid request';

  @override
  String get coreText_errorTitle16 => 'Under maintenance';

  @override
  String get coreText_errorTitle17 => 'Not found';

  @override
  String get coreText_errorTitle18 => 'No permission';

  @override
  String get coreText_errorTitle19 => 'Blocked by policy';

  @override
  String get coreText_errorTitle2 => 'Account not set up';

  @override
  String get coreText_errorTitle20 => 'Activate your LOOP ID first';

  @override
  String get coreText_errorTitle21 => 'Provider not connected';

  @override
  String get coreText_errorTitle22 => 'Quote expired';

  @override
  String get coreText_errorTitle23 => 'Too many requests';

  @override
  String get coreText_errorTitle24 => 'Region restriction';

  @override
  String get coreText_errorTitle25 => 'Request timed out';

  @override
  String get coreText_errorTitle26 => 'ID already taken';

  @override
  String get coreText_errorTitle27 => 'Session not found';

  @override
  String get coreText_errorTitle28 => 'Simulation failed';

  @override
  String get coreText_errorTitle29 => 'Submission status unknown';

  @override
  String get coreText_errorTitle3 => 'That name isn\'t available';

  @override
  String get coreText_errorTitle30 => 'Validation failed';

  @override
  String get coreText_errorTitle31 => 'Version conflict';

  @override
  String get coreText_errorTitle4 => 'That name is reserved';

  @override
  String get coreText_errorTitle5 => 'Invalid sign-in credentials';

  @override
  String get coreText_errorTitle6 => 'Sign-in required';

  @override
  String get coreText_errorTitle7 => 'Higher verification required';

  @override
  String get coreText_errorTitle8 => 'Feature unavailable';

  @override
  String get coreText_errorTitle9 => 'Chain mismatch';

  @override
  String coreText_tokenLoopTokenDescriptionError(
    Object? loopTokenDescriptionMaxCharacters,
  ) {
    return 'Description can be up to $loopTokenDescriptionMaxCharacters characters';
  }

  @override
  String get coreText_tokenLoopTokenDescriptionError2 =>
      'Description can\'t contain control or invisible characters';

  @override
  String get coreText_tokenLoopTokenNameLengthMessage =>
      'Name can be up to 20 characters (emoji count as 2)';

  @override
  String get coreText_tokenLoopTokenTextRule =>
      'Name and ticker 1–20 characters each; Chinese, letters, numbers and emoji allowed';

  @override
  String get coreText_tokenLoopTokenTickerLengthMessage =>
      'Ticker can be up to 20 characters (emoji count as 2)';

  @override
  String coreText_tokenTokenTextError(Object? label) {
    return '$label is required';
  }

  @override
  String coreText_tokenTokenTextError2(Object? label) {
    return '$label can\'t contain line breaks, control or invisible characters';
  }

  @override
  String get coreText_tokenTokenTextError3 => 'Ticker';

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
  String get integrations_chatCameraLoopChatCameraPermissionMessage =>
      'No camera access. Allow LOOP to use the camera in system settings, then try again.';

  @override
  String get integrations_chatCameraLoopChatCameraUnavailableMessage =>
      'The camera didn\'t take a photo, so nothing was added.';

  @override
  String get integrations_chatImageAttachmentsFailureMessage =>
      'Image didn\'t load';

  @override
  String integrations_chatImageAttachmentsLoopChatImageViewerCounter(
    Object? page,
    Object? total,
  ) {
    return '$page / $total';
  }

  @override
  String get integrations_chatImageAttachmentsRetryMessage => 'Tap to retry';

  @override
  String get integrations_chatImageComposerIf =>
      'This device is offline. The image wasn\'t uploaded and the message wasn\'t sent.';

  @override
  String get integrations_chatImageComposerIf2 =>
      'The server rejected this image upload. The message wasn\'t sent.';

  @override
  String get integrations_chatImageComposerIf3 =>
      'The image didn\'t upload. The message wasn\'t sent.';

  @override
  String get integrations_chatImagePolicyNotAnImage =>
      'Only images can be sent here. What you picked isn\'t an image, so it wasn\'t added.';

  @override
  String get integrations_chatImagePolicyTooLarge =>
      'Each image must be 10 MB or less. The larger one wasn\'t added.';

  @override
  String get integrations_chatImagePolicyTooMany =>
      'A message can have up to 9 images. The extra ones weren\'t added.';

  @override
  String get integrations_chatImagePolicyUnsupportedFormat =>
      'Only JPG, PNG, WebP and GIF images are supported. Other formats weren\'t added.';

  @override
  String
  get integrations_externalWalletCredentialGatewayExternalWalletConnectorException =>
      'The wallet returned a duplicate sign-in request. Reconnect.';

  @override
  String
  get integrations_externalWalletCredentialGatewayExternalWalletConnectorException2 =>
      'The address, message or signature from the wallet doesn\'t match this sign-in request.';

  @override
  String
  get integrations_externalWalletCredentialGatewayPrivyGatewayException =>
      'No current Privy account. The wallet wasn\'t linked.';

  @override
  String get integrations_memoryChatGatewaysCommunityName =>
      'Preview community';

  @override
  String get integrations_memoryCommunityGatewaysDescription =>
      'A sample community in development preview. Member counts and roles are local in-memory values.';

  @override
  String get integrations_memoryCommunityGatewaysLabel => 'Power community';

  @override
  String get integrations_memoryCommunityGatewaysName =>
      'Demo community · Frogs';

  @override
  String get integrations_memoryCommunityGatewaysName2 =>
      'Demo community · Builders';

  @override
  String get integrations_memoryCommunityGatewaysName3 =>
      'Demo community · In review';

  @override
  String get integrations_memoryCommunityGatewaysRejectedReason =>
      'Demo data: this name duplicates a live community. Pick another and resubmit.';

  @override
  String get integrations_memoryCommunityGatewaysTitle =>
      'Demo notice · This week\'s roadmap';

  @override
  String get integrations_memoryCommunityGatewaysTitle2 =>
      'Demo notice · Thursday voice room';

  @override
  String get integrations_memoryLiveVoiceRoomsCommunityName =>
      'Preview community (not joined)';

  @override
  String get integrations_memoryLiveVoiceRoomsDisplayName => 'Preview host';

  @override
  String get integrations_memoryLiveVoiceRoomsDisplayName2 => 'Preview speaker';

  @override
  String get integrations_memoryLiveVoiceRoomsTitle =>
      'Development preview · Friday AMA';

  @override
  String get integrations_memoryPublicProfilesAlias => 'Preview user';

  @override
  String get integrations_memoryPublicProfilesBio =>
      'Development preview account. Profile and holdings are demo data.';

  @override
  String get integrations_memoryPublicProfilesLabel => 'Featured community';

  @override
  String get integrations_memoryPublicProfilesName => 'Preview community';

  @override
  String get integrations_memoryPublicProfilesName2 => 'Demo data group';

  @override
  String get integrations_memoryWatchlistGatewayName => 'Default';

  @override
  String get integrations_memoryWatchlistGatewayName2 => 'Watching';

  @override
  String get integrations_networkProbeName => 'LOOP service · Ready';

  @override
  String get integrations_networkProbeName2 => 'LOOP service · Capabilities';

  @override
  String get integrations_networkProbeName3 => 'Sign-in service Privy';

  @override
  String get integrations_networkProbeName4 => 'Chat service Stream';

  @override
  String get integrations_networkProbeName5 => 'Voice service Stream';

  @override
  String get integrations_networkProbeName6 => 'Token icons';

  @override
  String get integrations_networkProbeName7 => 'Push service Firebase';

  @override
  String get integrations_networkProbeName8 => 'BSC mainnet node';

  @override
  String get integrations_networkProbeName9 => 'Network baseline Apple';

  @override
  String get integrations_networkProbePurpose => 'The app\'s main data';

  @override
  String get integrations_networkProbePurpose2 =>
      'Two requests in a row, the second is recorded (reused connection)';

  @override
  String get integrations_networkProbePurpose3 => 'Sign-in and built-in wallet';

  @override
  String get integrations_networkProbePurpose4 => 'Conversations and messages';

  @override
  String get integrations_networkProbePurpose5 => 'Icon image source';

  @override
  String get integrations_networkProbePurpose6 => 'System push notifications';

  @override
  String get integrations_networkProbePurpose7 =>
      'Reference only; the app doesn\'t connect to nodes directly';

  @override
  String get integrations_networkProbePurpose8 =>
      'Baseline for DNS and secure connections';

  @override
  String get integrations_networkProbeSubject => 'LOOP network diagnosis';

  @override
  String get integrations_privyAuthGatewayAuthentication =>
      'Your sign-in has expired. Sign in again.';

  @override
  String
  get integrations_privyAuthGatewayExternalWalletLinkedElsewhereMessage =>
      'This wallet is linked to another LOOP account. Sign in to that account and unlink it first, then come back to link it.';

  @override
  String get integrations_privyAuthGatewayLoopUndecidedSessionMessage =>
      'Can\'t confirm your sign-in right now. Try again later.';

  @override
  String get integrations_privyAuthGatewayMessage =>
      'The Privy App Client ID isn\'t configured, so real sign-in isn\'t available.';

  @override
  String get integrations_privyAuthGatewayNetwork =>
      'Can\'t confirm your sign-in right now. Check your network and retry.';

  @override
  String integrations_privyAuthGatewayOauthFailureMessage(Object? label) {
    return '$label sign-in cancelled.';
  }

  @override
  String integrations_privyAuthGatewayOauthFailureMessage2(Object? label) {
    return '$label sign-in can\'t reach the network. Try again later.';
  }

  @override
  String integrations_privyAuthGatewayOauthFailureMessage3(Object? label) {
    return '$label sign-in couldn\'t return to the app. Check the app configuration and retry.';
  }

  @override
  String integrations_privyAuthGatewayOauthFailureMessage4(Object? label) {
    return '$label sign-in didn\'t finish. Retry.';
  }

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException =>
      'Couldn\'t send the code. Try again later.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException10 =>
      'Invalid wallet address. Nothing was unlinked.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException11 =>
      'The account changed. Refresh to check whether the wallet was unlinked.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException12 =>
      'Unlinking didn\'t finish. Check your network and retry.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException14 =>
      'The previous account\'s wallet action is still finishing. Try again later.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException15 =>
      'Wallet creation isn\'t confirmed. Refresh and try again later.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException16 =>
      'Finish Privy sign-in first.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException17 =>
      'Can\'t reach the sign-in service right now. Check your network and retry.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException18 =>
      'Your sign-in credential has expired. Try again.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException19 =>
      'Couldn\'t sign out. Try again later.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException2 =>
      'The code is invalid or has expired. Check it again.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException3 =>
      'Sign-in didn\'t finish. Check your network and return configuration, then retry.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException4 =>
      'Privy didn\'t return a sign-in message to sign. Retry.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException5 =>
      'Couldn\'t create the wallet sign-in message. Check your network and retry.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException6 =>
      'Wallet sign-in didn\'t finish. Check your network and retry.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException8 =>
      'Wallet linking didn\'t finish. Check your network and retry.';

  @override
  String get integrations_privyAuthGatewayPrivyGatewayException9 =>
      'The account changed and the wallet wasn\'t unlinked. Try again.';

  @override
  String get integrations_privyAuthGatewaySiweFailureMessage =>
      'This wallet already belongs to another Privy account. LOOP won\'t move or delete accounts automatically.';

  @override
  String get integrations_privyAuthGatewaySiweFailureMessage2 =>
      'Couldn\'t submit the wallet credential. Check your network and retry.';

  @override
  String get integrations_privyAuthGatewaySiweFailureMessage3 =>
      'Privy didn\'t accept this wallet credential; it may be linked to another account. LOOP won\'t move or delete accounts automatically.';

  @override
  String get integrations_privyAuthGatewaySiweLinkFailureMessage =>
      'Wallet linking didn\'t finish. Retry.';

  @override
  String get integrations_privyAuthGatewaySiweUnlinkFailureMessage =>
      'This is the account\'s only sign-in method and can\'t be unlinked. Link an email or another sign-in method first.';

  @override
  String get integrations_privyAuthGatewaySiweUnlinkFailureMessage2 =>
      'Unlinking didn\'t finish. Try again later.';

  @override
  String get integrations_privyMfaGatewayReleasedMessage =>
      'LOOP doesn\'t yet offer a way to enter a code for actions held by two-step verification. This action was cancelled.';

  @override
  String get integrations_reactionsLoopReactionFallbackLabel => 'Reaction';

  @override
  String get integrations_reactionsS => 'Like';

  @override
  String get integrations_reactionsS2 => 'Haha';

  @override
  String get integrations_reactionsS3 => 'Love';

  @override
  String get integrations_reactionsS4 => 'Wow';

  @override
  String get integrations_reactionsS5 => 'Sad';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException =>
      'The wallet connection or signature request was rejected.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException10 =>
      'The Reown Project ID isn\'t configured, so external wallets aren\'t available.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException11 =>
      'A sign-in or wallet connection is already in progress.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException12 =>
      'This page was closed. Start the wallet connection again.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException13 =>
      'The sign-in message is empty. Reconnect the wallet.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException14 =>
      'The wallet connection or return didn\'t finish. Go back to LOOP and retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException15 =>
      'Wallet connection cancelled.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException16 =>
      'The wallet picker didn\'t open. Retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException17 =>
      'The wallet connection timed out. Go back to LOOP and retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException18 =>
      'This wallet session didn\'t authorize personal_sign. Reconnect.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException19 =>
      'The wallet didn\'t return a usable EVM address.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException2 =>
      'Wallet app not found. Install it and retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException20 =>
      'Invalid wallet session. Reconnect.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException21 =>
      'The wallet signature timed out. Go back to LOOP and retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException22 =>
      'The wallet didn\'t return a valid signature.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException3 =>
      'Couldn\'t open the wallet app or return to LOOP. Retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException4 =>
      'The wallet connection can\'t reach the network. Try again later.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException5 =>
      'The wallet connection or return didn\'t finish. Retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException6 =>
      'Reown setup didn\'t finish. Restart LOOP and retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException7 =>
      'Reown setup failed. Restart LOOP and retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException8 =>
      'The Reown service timed out. Check your network and retry.';

  @override
  String
  get integrations_reownExternalWalletConnectorExternalWalletConnectorException9 =>
      'The Reown service isn\'t ready. Restart LOOP and retry.';

  @override
  String
  get integrations_streamChatAppearanceLoopMessageAvatarOpenProfileLabel =>
      'View profile';

  @override
  String get integrations_streamDayLabelYesterday => 'Yesterday';

  @override
  String get integrations_streamReactionIconResolverHint => 'Remove reaction';

  @override
  String integrations_streamReactionIconResolverHint2(Object? reactionLabel) {
    return 'React with $reactionLabel';
  }

  @override
  String get integrations_streamUnreadPillBandLoopUnreadPillDismissLabel =>
      'Mark as read';

  @override
  String get intel_rankBoardAlias => 'Anonymous';

  @override
  String get intel_rankBoardBuild => 'Not ranked yet';

  @override
  String get intel_rankBoardBuild2 => 'Leaderboard updates live';

  @override
  String intel_rankBoardCaption(num participants) {
    String _temp0 = intl.Intl.pluralLogic(
      participants,
      locale: localeName,
      other: '$participants people have power',
      one: '1 person has power',
    );
    return '$_temp0';
  }

  @override
  String get intel_rankBoardCaption2 => 'Direct invites';

  @override
  String get intel_rankBoardCaption3 => 'Others see an anonymous member';

  @override
  String get intel_rankBoardEmptyMessage => 'Couldn\'t load Power Ranking';

  @override
  String get intel_rankBoardEmptyReason =>
      'Ranking data can\'t be loaded right now.';

  @override
  String get intel_rankBoardFigure => 'Only visible to you';

  @override
  String intel_rankBoardIf(Object? vString) {
    return 'Members with power: $vString.';
  }

  @override
  String intel_rankBoardIf2(Object? intelRankLedgerKickerBase) {
    return '$intelRankLedgerKickerBase, live';
  }

  @override
  String intel_rankBoardIf3(Object? name, Object? weight) {
    return 'Community $name, weight $weight';
  }

  @override
  String get intel_rankBoardIf4 => 'Invite your first friend to get ranked';

  @override
  String intel_rankBoardIf5(Object? me) {
    return 'Direct invites $me';
  }

  @override
  String intel_rankBoardIf6(Object? powerFigure) {
    return 'Power $powerFigure';
  }

  @override
  String get intel_rankBoardIf7 => 'My communities';

  @override
  String get intel_rankBoardIntelRankBoardTitle => 'Power Ranking';

  @override
  String get intel_rankBoardIntelRankCapabilityBlockTitle =>
      'Power Ranking isn\'t available right now';

  @override
  String get intel_rankBoardIntelRankEmptyInviteLabel => 'Invite';

  @override
  String get intel_rankBoardIntelRankEmptyMessage =>
      'Once you invite your first friend, this ranks by direct invites';

  @override
  String get intel_rankBoardIntelRankEmptyMessage2 =>
      'Check back after the next power snapshot';

  @override
  String get intel_rankBoardIntelRankEmptyTitle =>
      'No one has invited a friend yet';

  @override
  String get intel_rankBoardIntelRankEmptyTitle2 =>
      'No entries ranked this time';

  @override
  String intel_rankBoardIntelRankGapToNext(Object? above, Object? figure) {
    return '$figure more to reach Rank #$above';
  }

  @override
  String get intel_rankBoardIntelRankLedgerHeading => 'My rank\nNot ranked yet';

  @override
  String get intel_rankBoardIntelRankMeLoadingHeading => 'Loading my rank';

  @override
  String get intel_rankBoardIntelRankPodiumLabel => 'Podium';

  @override
  String get intel_rankBoardIntelRankProvenancePrefix => 'By direct invites';

  @override
  String intel_rankBoardIntelRankUnavailableMessage(
    Object? launchReasonCodeText,
  ) {
    return 'Leaderboard can\'t be loaded right now · $launchReasonCodeText';
  }

  @override
  String get intel_rankBoardIntelReferralLedgerTitle => 'My live rank';

  @override
  String intel_rankBoardLabel(Object? place) {
    return 'Rank #$place, open';
  }

  @override
  String get intel_rankBoardLoopProvenanceLine => 'LOOP invite relations';

  @override
  String get intel_rankBoardLoopProvenanceLine2 =>
      'The invite board ranks by current active direct invites; ties share a rank. Invite relations are read live, without waiting for a power snapshot.';

  @override
  String get intel_rankBoardLoopProvenanceLine3 =>
      'Ranks come from the latest power snapshot; power changes on other accounts or communities change ranks. Nothing is calculated on this device.';

  @override
  String intel_rankBoardLoopProvenanceLine4(
    Object? miningRuleKeyText,
    Object? miningRuleKeyText2,
  ) {
    return '$miningRuleKeyText Anonymous entries show \"$miningRuleKeyText2\".';
  }

  @override
  String get intel_rankBoardMiningFormulaEffective =>
      'By the current power formula';

  @override
  String get intel_rankBoardMiningFormulaPending =>
      'Power formula not yet in effect';

  @override
  String intel_rankBoardMiningSnapshotComputed(
    Object? intelRankLedgerKickerBase,
    Object? intelRankMonthDayClock,
  ) {
    return '$intelRankLedgerKickerBase, snapshot $intelRankMonthDayClock';
  }

  @override
  String intel_rankBoardNull(Object? name) {
    return 'Community $name';
  }

  @override
  String intel_rankBoardParticipantEntry(Object? count, Object? name) {
    return '$name ($count)';
  }

  @override
  String get intel_rankBoardReferrals => 'Invitation';

  @override
  String get intel_rankBoardS => 'LOOP power snapshot';

  @override
  String intel_rankBoardS2(Object? rank) {
    return 'My rank\nRank #$rank';
  }

  @override
  String intel_rankBoardS3(Object? above, Object? figure) {
    return '$figure to reach Rank #$above';
  }

  @override
  String get intel_rankBoardS4 =>
      'Once you have power, you\'ll be ranked at the next snapshot';

  @override
  String get intel_rankBoardSpoken => 'Invites';

  @override
  String get intel_rankBoardText3 => 'Not ranked';

  @override
  String intel_rankBoardText4(Object? position) {
    return 'Rank #$position';
  }

  @override
  String intel_rankBoardText5(Object? weight) {
    return 'Weight $weight';
  }

  @override
  String get intel_rankBoardText6 => 'Open';

  @override
  String get intel_screenIntelScreenTitle => 'Intelligence';

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
  String get marketAlerts_modelsAbove => 'Breaks above';

  @override
  String get marketAlerts_modelsActive => 'Watching';

  @override
  String get marketAlerts_modelsAtOrAbove => 'Rises to';

  @override
  String get marketAlerts_modelsAtOrBelow => 'Falls to';

  @override
  String get marketAlerts_modelsBelow => 'Breaks below';

  @override
  String get marketAlerts_modelsTriggered => 'Triggered';

  @override
  String get marketAlerts_screenAbove =>
      'Break: price must be above the threshold (> threshold) to trigger. Exactly equal doesn\'t count.';

  @override
  String get marketAlerts_screenAlertAssetPickLabel =>
      'Pick an asset from your watchlist';

  @override
  String get marketAlerts_screenAlertAssetPickerEmptyMessage =>
      'Add assets to your watchlist on the market page first, or create an alert from a token page.';

  @override
  String get marketAlerts_screenAlertAssetPickerEmptyTitle =>
      'No assets in your watchlist yet';

  @override
  String get marketAlerts_screenAlertAssetRowSubtitle =>
      'This asset\'s name can\'t be loaded right now';

  @override
  String get marketAlerts_screenAlertDeleteConfirmBodyBody =>
      'Triggered records stay in the trigger history and aren\'t deleted.';

  @override
  String get marketAlerts_screenAlertDeleteConfirmBodyTitle =>
      'This price won\'t be watched after deleting';

  @override
  String get marketAlerts_screenAlertsCapabilityBlockTitle =>
      'Price alerts aren\'t available right now';

  @override
  String get marketAlerts_screenAlertsCommandErrorTitle =>
      'Alert wasn\'t updated';

  @override
  String get marketAlerts_screenAlertsCreateActionLabel => 'New';

  @override
  String marketAlerts_screenAlertsEmptyTitle(Object? focusLabel) {
    return 'No alerts for $focusLabel yet';
  }

  @override
  String get marketAlerts_screenAlertsEndText => 'No more alerts';

  @override
  String get marketAlerts_screenAlertsFeedEmptyMessage =>
      'Each triggered alert leaves a record here with its source and time.';

  @override
  String get marketAlerts_screenAlertsFeedEmptyPageMessage =>
      'There are more records. Keep scrolling.';

  @override
  String get marketAlerts_screenAlertsFeedEmptyPageTitle =>
      'No price alert records on this page';

  @override
  String get marketAlerts_screenAlertsFeedEndText => 'No more trigger records';

  @override
  String get marketAlerts_screenAlertsFeedMoreFailedMessage =>
      'Couldn\'t load the next page of trigger records';

  @override
  String marketAlerts_screenAlertsFeedUnreadText(Object? unreadCount) {
    return '$unreadCount unread';
  }

  @override
  String get marketAlerts_screenAlertsMoreFailedMessage =>
      'Couldn\'t load the next page of alerts';

  @override
  String get marketAlerts_screenAlertsNotificationSettingsSubtitle =>
      'With the price alert category off, events are still recorded but no notification is created';

  @override
  String get marketAlerts_screenAlertsPushNoticeBody =>
      'Push notifications aren\'t available yet, so alerts appear only in the in-app notification list. Only the latest price triggers an alert.';

  @override
  String get marketAlerts_screenAlertsPushNoticeTitle =>
      'Push isn\'t available yet';

  @override
  String marketAlerts_screenAlertsScreenSubtitle(
    num armed,
    Object? focusLabel,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      armed,
      locale: localeName,
      other: '$armed alerts watching',
      one: '1 alert watching',
    );
    return '$focusLabel · $_temp0 · Stops after one trigger';
  }

  @override
  String marketAlerts_screenAlertsScreenSubtitle2(num items) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items alerts loaded',
      one: '1 alert loaded',
    );
    return '$_temp0 · Stops after one trigger';
  }

  @override
  String marketAlerts_screenAlertsScreenSubtitle3(num armed) {
    String _temp0 = intl.Intl.pluralLogic(
      armed,
      locale: localeName,
      other: '$armed alerts watching',
      one: '1 alert watching',
    );
    return '$_temp0 · Stops after one trigger';
  }

  @override
  String get marketAlerts_screenAlertsShowEveryAssetLabel =>
      'View alerts for all assets';

  @override
  String get marketAlerts_screenAtOrAbove =>
      'Reach: triggers when price reaches or rises above the threshold (≥ threshold).';

  @override
  String get marketAlerts_screenAtOrBelow =>
      'Reach: triggers when price reaches or falls below the threshold (≤ threshold).';

  @override
  String get marketAlerts_screenBelow =>
      'Break: price must be below the threshold (< threshold) to trigger. Exactly equal doesn\'t count.';

  @override
  String get marketAlerts_screenEmptyMessage => 'No price alerts yet';

  @override
  String get marketAlerts_screenEmptyMessage2 => 'Watchlist hasn\'t loaded yet';

  @override
  String get marketAlerts_screenEmptyMessage3 => 'No trigger records yet';

  @override
  String get marketAlerts_screenEmptyReason =>
      'Set a target price and you\'ll get a notification when it\'s reached.';

  @override
  String get marketAlerts_screenError => 'Pick an asset to watch first.';

  @override
  String get marketAlerts_screenHintText => 'e.g. 800.5';

  @override
  String get marketAlerts_screenLabel => 'Keep';

  @override
  String get marketAlerts_screenLabelText => 'Threshold (USD)';

  @override
  String get marketAlerts_screenLoopBadge => 'This trigger';

  @override
  String get marketAlerts_screenLoopBadge2 => 'Changeable';

  @override
  String get marketAlerts_screenLoopBadge3 => 'Not changeable';

  @override
  String get marketAlerts_screenLoopLabel => 'Alerts set';

  @override
  String get marketAlerts_screenLoopLabel2 => 'Trigger history';

  @override
  String get marketAlerts_screenLoopLabel3 => 'Trigger condition';

  @override
  String get marketAlerts_screenLoopOfflineState => 'New alert';

  @override
  String get marketAlerts_screenLoopOfflineState2 => 'Edit alert';

  @override
  String get marketAlerts_screenLoopOfflineState3 => 'Delete alert';

  @override
  String get marketAlerts_screenLoopRecordRow =>
      'This trigger is recorded in notifications';

  @override
  String marketAlerts_screenLoopRecordRow2(Object? formatPercent) {
    return '$formatPercent from target';
  }

  @override
  String get marketAlerts_screenLoopRecordRow3 => 'Not evaluated yet';

  @override
  String marketAlerts_screenLoopRecordRow4(Object? relativeTime) {
    return 'Evaluated $relativeTime';
  }

  @override
  String get marketAlerts_screenLoopSheetHeading => 'Delete this alert?';

  @override
  String get marketAlerts_screenLoopSheetHeading2 => 'New price alert';

  @override
  String get marketAlerts_screenLoopSheetHeading3 => 'Choose asset';

  @override
  String get marketAlerts_screenMessage => 'Alert deleted';

  @override
  String get marketAlerts_screenMessage2 => 'Alert saved';

  @override
  String get marketAlerts_screenS => 'Edit price alert';

  @override
  String get marketAlerts_screenSetState =>
      'This asset can\'t be used for price alerts. Choose another one.';

  @override
  String get marketAlerts_screenSetState2 =>
      'The threshold must be a positive decimal number with up to 18 decimal places.';

  @override
  String get marketAlerts_screenSetState3 =>
      'The expiry must be in the future.';

  @override
  String get marketAlerts_screenText => 'Delete this alert';

  @override
  String get marketAlerts_screenTitle =>
      'This account can\'t change price alerts';

  @override
  String marketWatchlist_controllerAdd(Object? name) {
    return 'Add group $name';
  }

  @override
  String marketWatchlist_controllerAdd2(Object? name) {
    return 'Remove group $name';
  }

  @override
  String marketWatchlist_controllerAddedItems(Object? added) {
    return '$added added';
  }

  @override
  String marketWatchlist_controllerGroupChange(Object? change, Object? name) {
    return '$name: $change';
  }

  @override
  String marketWatchlist_controllerRemovedItems(Object? removed) {
    return '$removed removed';
  }

  @override
  String get marketWatchlist_controllerReordered => 'Reordered';

  @override
  String marketWatchlist_controllerStringBuffer(Object? version) {
    return 'LOOP watchlist draft (based on version $version)';
  }

  @override
  String marketWatchlist_editorBuild(Object? watchlistMaxGroups) {
    return 'Groups take effect after saving. Up to $watchlistMaxGroups.';
  }

  @override
  String get marketWatchlist_editorBuild2 => 'Reloading discards';

  @override
  String get marketWatchlist_editorEmptyMessage => 'No watchlist assets yet';

  @override
  String get marketWatchlist_editorEmptyReason =>
      'Open a token page and tap the star at the top right to add it.';

  @override
  String marketWatchlist_editorHintText(Object? watchlistMaxNameCodePoints) {
    return '1–$watchlistMaxNameCodePoints characters';
  }

  @override
  String marketWatchlist_editorLabel(Object? displayName) {
    return 'Remove $displayName';
  }

  @override
  String get marketWatchlist_editorLabelText => 'Group name';

  @override
  String get marketWatchlist_editorLoopBadge => 'No data';

  @override
  String get marketWatchlist_editorLoopLabel => 'Groups';

  @override
  String get marketWatchlist_editorLoopOfflineState => 'Save watchlist';

  @override
  String get marketWatchlist_editorMessage => 'Draft copied';

  @override
  String get marketWatchlist_editorMessage2 => 'Watchlist saved';

  @override
  String get marketWatchlist_editorResource => 'Watchlist';

  @override
  String get marketWatchlist_editorTitle =>
      'This account can\'t save the watchlist';

  @override
  String get marketWatchlist_editorUnsavedSuffix => ' · Unsaved';

  @override
  String get marketWatchlist_editorWatchlistCapabilityBlockTitle =>
      'Watchlist editing isn\'t available right now';

  @override
  String get marketWatchlist_editorWatchlistConflictBody =>
      'Your watchlist changed on another device. Reloading discards the changes below. Copy the draft before deciding.';

  @override
  String get marketWatchlist_editorWatchlistConflictCopyDraftLabel =>
      'Copy current draft';

  @override
  String get marketWatchlist_editorWatchlistConflictNoDiff =>
      'This draft matches the submitted version.';

  @override
  String get marketWatchlist_editorWatchlistConflictTitle =>
      'Version conflict — nothing was overwritten';

  @override
  String get marketWatchlist_editorWatchlistDiscardLabel => 'Discard';

  @override
  String marketWatchlist_editorWatchlistEditorScreenSubtitle(
    num distinctAssetCount,
    Object? state,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      distinctAssetCount,
      locale: localeName,
      other: '$distinctAssetCount watchlist assets',
      one: '1 watchlist asset',
    );
    return '$_temp0$state';
  }

  @override
  String get marketWatchlist_editorWatchlistGroupEmptyAddLabel => 'Add asset';

  @override
  String get marketWatchlist_editorWatchlistGroupEmptyTitle =>
      'No assets in this group yet';

  @override
  String marketWatchlist_editorWatchlistGroupLabel(
    Object? items,
    Object? name,
  ) {
    return '$name $items · Drag to sort · Swipe left to delete';
  }

  @override
  String marketWatchlist_editorWatchlistGroupLimitBody(
    Object? watchlistMaxGroups,
  ) {
    return 'You\'ve reached the limit of $watchlistMaxGroups groups. Delete one before creating another.';
  }

  @override
  String get marketWatchlist_editorWatchlistGroupNameConfirmLabel =>
      'Add group';

  @override
  String get marketWatchlist_editorWatchlistNewGroupEmptyLabel => 'New group';

  @override
  String marketWatchlist_editorWatchlistNoGroupsMessage(
    Object? watchlistDefaultGroupName,
  ) {
    return 'Two ways: tap the star at the top right of a token page and the asset goes into the default group \"$watchlistDefaultGroupName\", or create a group here first.';
  }

  @override
  String get marketWatchlist_editorWatchlistNoGroupsTitle => 'No groups yet';

  @override
  String get marketWatchlist_editorWatchlistNoticeText =>
      'Prices and changes aren\'t shown here. This page only sorts, removes and creates groups. Add assets with the star on a token page. Assets must be registered on LOOP, or the whole watchlist won\'t save.';

  @override
  String get marketWatchlist_editorWatchlistNoticeTitle =>
      'A watchlist isn\'t market data';

  @override
  String get marketWatchlist_editorWatchlistSaveErrorTitle =>
      'Watchlist wasn\'t saved';

  @override
  String get marketWatchlist_editorWatchlistSaveLabel => 'Saving…';

  @override
  String get marketWatchlist_editorWatchlistUndoLabel => 'Undo';

  @override
  String marketWatchlist_editorWatchlistUndoMessage(Object? displayName) {
    return 'Removed $displayName. Takes effect after saving';
  }

  @override
  String get marketWatchlist_membershipControllerActionLabel =>
      'Remove from watchlist';

  @override
  String get marketWatchlist_membershipControllerS => 'Add to watchlist';

  @override
  String get marketWatchlist_modelsDuplicate =>
      'A group with this name already exists.';

  @override
  String get marketWatchlist_modelsEmpty => 'Group name can\'t be empty.';

  @override
  String marketWatchlist_modelsGroupLimitReached(Object? watchlistMaxGroups) {
    return 'You\'ve reached the limit of $watchlistMaxGroups groups. Remove one before creating another.';
  }

  @override
  String get marketWatchlist_modelsInvalidCharacters =>
      'The group name has hidden characters that can\'t be used.';

  @override
  String get marketWatchlist_modelsNotEditable =>
      'The watchlist hasn\'t loaded yet, so groups can\'t be created.';

  @override
  String marketWatchlist_modelsTooLong(Object? watchlistMaxNameCodePoints) {
    return 'Group names can be up to $watchlistMaxNameCodePoints characters.';
  }

  @override
  String get market_chartFifteenMinutes => '15m';

  @override
  String get market_chartFourHours => '4h';

  @override
  String get market_chartOneDay => '1D';

  @override
  String get market_chartOneHour => '1h';

  @override
  String get market_chartOneWeek => '1W';

  @override
  String get market_chartToolbarLabel => 'Candles';

  @override
  String get market_chartToolbarLabel2 => 'Line';

  @override
  String market_chartToolbarS(Object? labels) {
    return '$labels · Calculated on device';
  }

  @override
  String get market_chartToolbarSemantic => 'Switch to candles';

  @override
  String get market_chartToolbarSemantic2 => 'Switch to line';

  @override
  String get market_chartToolbarSemantic3 => 'Moving averages';

  @override
  String get market_chartToolbarSemantic4 => 'Volume';

  @override
  String get market_fomoBuild => '24h change not reported';

  @override
  String get market_fomoDerived => 'Derived from trade price';

  @override
  String market_fomoDown(Object? figure) {
    return '24h trend down $figure';
  }

  @override
  String get market_fomoMarker => 'Pool estimate';

  @override
  String get market_fomoMarketTrendPercent => 'Not reported';

  @override
  String market_fomoMarketTrendSpoken(Object? signedPercent) {
    return '24h change $signedPercent';
  }

  @override
  String get market_fomoProxied => 'Priced in WBNB';

  @override
  String market_fomoS(Object? formatPercent) {
    return '24h $formatPercent';
  }

  @override
  String get market_fomoStale => 'Delayed';

  @override
  String market_fomoSubtitle(Object? formatCompactFigure) {
    return 'Market cap $formatCompactFigure';
  }

  @override
  String get market_fomoSwitch => 'No quote yet';

  @override
  String get market_fomoSwitch2 => 'Market data rate-limited';

  @override
  String get market_fomoSwitch3 => 'Market data can\'t be loaded';

  @override
  String get market_fomoSwitch4 => 'Market source not enabled';

  @override
  String get market_fomoSwitch5 => 'No trading pair';

  @override
  String get market_fomoSwitch6 => 'Pair can\'t be quoted';

  @override
  String get market_fomoSwitch7 => 'Not reported by market source';

  @override
  String get market_fomoSwitch8 => 'Market cache unavailable';

  @override
  String market_fomoUnread(Object? figure) {
    return '24h trend flat $figure';
  }

  @override
  String market_fomoUp(Object? figure) {
    return '24h trend up $figure';
  }

  @override
  String get market_readModelsCommunity => 'Community tokens';

  @override
  String get market_readModelsMajor => 'Majors';

  @override
  String get market_readModelsMarketAssetUnavailableLead =>
      'This address can\'t be loaded right now';

  @override
  String market_readModelsProvider(
    Object? factSourceLabel,
    Object? truncatedAddress,
  ) {
    return 'Main pool from $factSourceLabel · Unregistered pool $truncatedAddress';
  }

  @override
  String market_readModelsRegistry(
    Object? factSourceLabel,
    Object? truncatedAddress,
  ) {
    return 'Source $factSourceLabel · Pool $truncatedAddress';
  }

  @override
  String get market_readModelsSwitch => 'Sorted by DexScreener 24h volume';

  @override
  String market_readModelsSwitch2(Object? ordering) {
    return 'Sort rule $ordering';
  }

  @override
  String market_readModelsSwitch3(Object? fact) {
    return 'Buy tax $fact';
  }

  @override
  String market_readModelsSwitch4(Object? fact) {
    return 'Sell tax $fact';
  }

  @override
  String market_readModelsSwitch5(Object? labelKey) {
    return 'Source label $labelKey';
  }

  @override
  String get market_readModelsSwitch6 => 'DexScreener market cap, high to low';

  @override
  String get market_readModelsSwitch7 => 'DexScreener 24h change, high to low';

  @override
  String get market_readModelsSwitch8 => 'DexScreener 24h volume, high to low';

  @override
  String get market_readModelsYesNo => 'Contract source verified';

  @override
  String get market_readModelsYesNo10 => 'Owner can\'t change balances';

  @override
  String get market_readModelsYesNo11 => 'Hidden owner detected';

  @override
  String get market_readModelsYesNo12 => 'No hidden owner detected';

  @override
  String get market_readModelsYesNo13 => 'Self-destruct function detected';

  @override
  String get market_readModelsYesNo14 => 'No self-destruct function detected';

  @override
  String get market_readModelsYesNo15 => 'External call detected';

  @override
  String get market_readModelsYesNo16 => 'No external call detected';

  @override
  String get market_readModelsYesNo17 => 'Honeypot traits detected';

  @override
  String get market_readModelsYesNo18 => 'No honeypot traits detected';

  @override
  String get market_readModelsYesNo19 => 'Transfers can be paused';

  @override
  String get market_readModelsYesNo2 => 'Contract source not verified';

  @override
  String get market_readModelsYesNo20 => 'Transfers can\'t be paused';

  @override
  String get market_readModelsYesNo21 => 'Blacklist function detected';

  @override
  String get market_readModelsYesNo22 => 'No blacklist function detected';

  @override
  String get market_readModelsYesNo23 => 'Whitelist function detected';

  @override
  String get market_readModelsYesNo24 => 'No whitelist function detected';

  @override
  String get market_readModelsYesNo25 => 'Holding limit detected';

  @override
  String get market_readModelsYesNo26 => 'No holding limit detected';

  @override
  String get market_readModelsYesNo27 => 'Trading cooldown detected';

  @override
  String get market_readModelsYesNo28 => 'No trading cooldown detected';

  @override
  String get market_readModelsYesNo29 => 'Can\'t sell all at once';

  @override
  String get market_readModelsYesNo3 => 'Proxy contract';

  @override
  String get market_readModelsYesNo30 => 'Can sell all at once';

  @override
  String get market_readModelsYesNo31 => 'Listed on a DEX';

  @override
  String get market_readModelsYesNo32 => 'Not listed on a DEX';

  @override
  String get market_readModelsYesNo4 => 'Not a proxy contract';

  @override
  String get market_readModelsYesNo5 => 'Mint function detected';

  @override
  String get market_readModelsYesNo6 => 'No mint function detected';

  @override
  String get market_readModelsYesNo7 => 'Reclaimable ownership detected';

  @override
  String get market_readModelsYesNo8 => 'No reclaimable ownership detected';

  @override
  String get market_readModelsYesNo9 => 'Owner can change balances';

  @override
  String get market_screenCommunity =>
      'No verified community has linked a token yet.';

  @override
  String get market_screenEmptyMessage => 'No market data to show yet';

  @override
  String get market_screenEmptyMessage2 => 'No tokens in this category yet';

  @override
  String get market_screenMajor => 'No assets in the majors list to show yet.';

  @override
  String get market_screenMarketCapabilityBlockTitle =>
      'Market isn\'t available right now';

  @override
  String get market_screenMarketSmartMoneyEntryTitle => 'Smart money tracker';

  @override
  String get market_screenMarketWatchlistBrowseMajorLabel => 'Browse majors';

  @override
  String get market_screenMarketWatchlistEmptyMessage =>
      'Tap the star at the top right of a token page to add it to your watchlist';

  @override
  String get market_screenMarketWatchlistEmptyTitle => 'No watchlist yet';

  @override
  String get market_screenMarketWatchlistManageSubtitle =>
      'Sort, group and remove';

  @override
  String get market_screenMarketWatchlistManageTitle => 'Manage watchlist';

  @override
  String market_screenMarketWatchlistUnavailableMessage(
    Object? reasonCodeText,
  ) {
    return 'Watchlist prices can\'t be loaded · $reasonCodeText';
  }

  @override
  String get market_screenMeme => 'No registered Launch project tokens yet.';

  @override
  String get market_screenNewPairs => 'New pairs';

  @override
  String market_screenTitle(Object? label) {
    return 'No tokens in \"$label\" yet';
  }

  @override
  String get market_secondaryScreensChartFullBlockedTitle =>
      'Full-screen chart';

  @override
  String get market_secondaryScreensChartFullIntervalNoticeText =>
      'Intervals: 15m / 1h / 4h / 1D / 1W. Drag sideways for earlier data, pinch to zoom, long-press to see a candle\'s price and time. MA and VOL are calculated on device from the chart\'s closes and volume, with no separate data source. There are no other indicators and no drawing tools.';

  @override
  String get market_secondaryScreensChartFullIntervalNoticeTitle =>
      'What this chart does';

  @override
  String get market_secondaryScreensFact => 'Total holders';

  @override
  String get market_secondaryScreensInvalidAssetIdentityMessage =>
      'This page accepts only a canonical CAIP assetId. No market data was requested and no other asset was used instead.';

  @override
  String get market_secondaryScreensInvalidAssetIdentityTitle =>
      'No usable asset ID in the route';

  @override
  String get market_secondaryScreensInvalidAssetPage =>
      'Can\'t open this chart';

  @override
  String get market_secondaryScreensInvalidAssetPage2 =>
      'Can\'t open holder distribution';

  @override
  String get market_secondaryScreensInvalidAssetPage3 =>
      'Can\'t open trade activity';

  @override
  String get market_secondaryScreensLabel => 'Top 10 concentration';

  @override
  String get market_secondaryScreensLabel2 =>
      'Watchlist isn\'t available right now';

  @override
  String get market_secondaryScreensLoopLabel => 'Distribution';

  @override
  String get market_secondaryScreensLoopLabel2 => 'Risk screening';

  @override
  String get market_secondaryScreensLoopLabel3 => 'Watched addresses';

  @override
  String get market_secondaryScreensLoopLabel4 => 'Recent moves';

  @override
  String market_secondaryScreensLoopProvenanceFooter(Object? groupedFigure) {
    return 'Indexed height $groupedFigure';
  }

  @override
  String market_secondaryScreensLoopProvenanceFooter2(Object? groupedFigure) {
    return 'Data $groupedFigure blocks behind';
  }

  @override
  String market_secondaryScreensLoopRecordRow(Object? groupedFigure) {
    return '$groupedFigure confirmations';
  }

  @override
  String market_secondaryScreensLoopRecordRow2(Object? groupedFigure) {
    return 'Block $groupedFigure';
  }

  @override
  String get market_secondaryScreensMarketSegmentBar => 'Large trades';

  @override
  String get market_secondaryScreensMarketSegmentBar2 => 'Smart money';

  @override
  String get market_secondaryScreensNewPairsEmptyMessage =>
      'This is what the data shows, not a filtered conclusion.';

  @override
  String get market_secondaryScreensNewPairsEmptyTitle =>
      'No new pools right now';

  @override
  String get market_secondaryScreensNewPairsFolioCaption =>
      'Check liquidity, contract status and data source before short-term price.';

  @override
  String market_secondaryScreensNewPairsFolioHeading(Object? items) {
    return '$items new pairs · High risk';
  }

  @override
  String get market_secondaryScreensNewPairsFolioHeading2 =>
      'New pools can\'t be loaded right now';

  @override
  String get market_secondaryScreensNewPairsFolioHeading3 =>
      'Loading new pools';

  @override
  String get market_secondaryScreensNewPairsNoticeBody =>
      'Without risk screening data, this page won\'t judge risk on its own. New pools have thin liquidity and prices are easy to manipulate.';

  @override
  String get market_secondaryScreensNewPairsNoticeTitle =>
      'Screening isn\'t a verdict';

  @override
  String get market_secondaryScreensNewPairsOmittedBody =>
      'These rows\' pool IDs are neither a contract address nor a pool id, so rows that can\'t be verified aren\'t shown.';

  @override
  String market_secondaryScreensNewPairsOmittedTitle(Object? omittedCount) {
    return '$omittedCount more rows couldn\'t be parsed';
  }

  @override
  String get market_secondaryScreensNewPairsRiskScreeningLabel =>
      'Risk screening unavailable';

  @override
  String get market_secondaryScreensNewPairsScreenTitle => 'New pair discovery';

  @override
  String get market_secondaryScreensNewPairsUnavailableLabel =>
      'New pair discovery unavailable';

  @override
  String get market_secondaryScreensSmartMoneyFolioCaption =>
      'Moves by watched addresses are leads, not copy-trade promises or return advice.';

  @override
  String get market_secondaryScreensSmartMoneyFolioHeading =>
      'No addresses to watch yet';

  @override
  String get market_secondaryScreensSmartMoneyMovesUnavailableMessage =>
      'Moves come from watched addresses, which aren\'t available yet.';

  @override
  String get market_secondaryScreensSmartMoneyMovesUnavailableTitle =>
      'No moves to list yet';

  @override
  String get market_secondaryScreensSmartMoneyNoticeText =>
      'Even when available, address labels and win rates are only historical stats from public on-chain data, not advice to follow.';

  @override
  String get market_secondaryScreensSmartMoneyNoticeTitle =>
      'Win rate isn\'t a prediction';

  @override
  String get market_secondaryScreensSmartMoneyUnavailableLabel =>
      'Watched addresses unavailable';

  @override
  String market_secondaryScreensText(
    Object? factSourceLabel,
    Object? relativeTime,
  ) {
    return 'Source $factSourceLabel · Observed $relativeTime';
  }

  @override
  String get market_secondaryScreensTokenHoldersDistributionLabel =>
      'Top holders, concentration and cluster labels unavailable';

  @override
  String get market_secondaryScreensTokenHoldersFolioCaption =>
      'Holder facts haven\'t loaded yet.';

  @override
  String get market_secondaryScreensTokenHoldersFolioHeading =>
      'Total holders unavailable';

  @override
  String market_secondaryScreensTokenHoldersFolioHeading2(
    Object? formatDecimal,
  ) {
    return '$formatDecimal holders';
  }

  @override
  String get market_secondaryScreensTokenHoldersFolioTitle =>
      'Holder distribution';

  @override
  String get market_secondaryScreensTokenHoldersPageBlockTitle =>
      'Holder distribution isn\'t available right now';

  @override
  String market_secondaryScreensTokenHoldersProvenanceSemanticsLabel(
    Object? factProvenance,
  ) {
    return '$factProvenance, view data source details';
  }

  @override
  String get market_secondaryScreensTokenTradesEmptyMessage =>
      'Large trades are picked on device by trade value, not officially labeled.';

  @override
  String get market_secondaryScreensTokenTradesEmptyMessage2 =>
      'The indexer has read this range, but it has no trades.';

  @override
  String get market_secondaryScreensTokenTradesEmptyTitle =>
      'No large trades on this page';

  @override
  String get market_secondaryScreensTokenTradesEmptyTitle2 =>
      'No trades on this page';

  @override
  String get market_secondaryScreensTokenTradesFolioCaption =>
      'Direction, amount and time are scanned together from Swap events in registered PancakeSwap V3 pools.';

  @override
  String market_secondaryScreensTokenTradesFolioHeading(Object? items) {
    return '$items on-chain trades';
  }

  @override
  String get market_secondaryScreensTokenTradesFolioHeading2 =>
      'Latest on-chain trades';

  @override
  String get market_secondaryScreensTokenTradesFolioTitle => 'Trade activity';

  @override
  String get market_secondaryScreensTokenTradesMoreFailedMessage =>
      'Couldn\'t load the next page of trades';

  @override
  String get market_secondaryScreensTokenTradesSmartMoneyLabel =>
      'Smart money filter unavailable';

  @override
  String get market_secondaryScreensTokenTradesUnavailableLabel =>
      'Trade history unavailable';

  @override
  String get market_secondaryScreensTrailingCaption => 'Out of pool';

  @override
  String get market_secondaryScreensTrailingCaption2 => 'Into pool';

  @override
  String market_tokenBuild(Object? reasonCodeSummaryText) {
    return '24h change$reasonCodeSummaryText';
  }

  @override
  String get market_tokenCandleLastOpen => ', last candle still open';

  @override
  String market_tokenCandleSourceSentence(Object? source) {
    return '$source.';
  }

  @override
  String get market_tokenCandleStyleCandle => 'candles';

  @override
  String get market_tokenCandleStyleLine => 'close line';

  @override
  String get market_tokenCandlesEmptyMessage =>
      'Only intervals with trades are drawn. Empty intervals aren\'t filled with 0.';

  @override
  String market_tokenCandlesUnavailableMessage(Object? reasonCodeText) {
    return 'Chart can\'t be loaded · $reasonCodeText';
  }

  @override
  String market_tokenCardChartSemanticLabel(
    Object? closes,
    Object? factSourceLabel,
    Object? priceUnit,
  ) {
    return 'Trend line of $closes 1H closes, in $priceUnit, source $factSourceLabel';
  }

  @override
  String get market_tokenCardChartTokenCardSparklineAbsence =>
      'Loading 1H candles. No trend is drawn until they load.';

  @override
  String get market_tokenCardChartTokenCardSparklineAbsence2 =>
      'No trades in this range. Only intervals with trades are drawn. Empty intervals aren\'t filled with 0.';

  @override
  String get market_tokenEmptyMessage => 'No facts to show for this asset yet';

  @override
  String get market_tokenEmptyMessage2 => 'No trades in this range';

  @override
  String get market_tokenEmptyMessage3 =>
      'No notifications about this asset yet';

  @override
  String get market_tokenFact => '24h volume';

  @override
  String get market_tokenFact2 => 'Fully diluted valuation';

  @override
  String get market_tokenHolderSections => 'Holder count';

  @override
  String get market_tokenHolders => 'Holders';

  @override
  String get market_tokenIf => 'Price alert triggered';

  @override
  String market_tokenIf2(Object? observed, Object? symbol, Object? threshold) {
    return '$symbol triggered $threshold (observed $observed)';
  }

  @override
  String get market_tokenLoopLabel => 'About';

  @override
  String get market_tokenLoopLabel2 => 'Pool and contract facts';

  @override
  String market_tokenLoopProvenanceLine(Object? groupedFigure) {
    return 'Data $groupedFigure blocks behind.';
  }

  @override
  String get market_tokenLoopProvenanceLine2 =>
      'Trades come from Swap events in registered pools. LOOP doesn\'t send counterparty addresses and only marks the trades your own wallet made.';

  @override
  String market_tokenLoopProvenanceLine3(Object? priceUnit) {
    return 'In $priceUnit';
  }

  @override
  String get market_tokenLoopProvenanceLine4 => 'Unregistered pool';

  @override
  String get market_tokenLoopProvenanceLine5 => 'Last candle in progress';

  @override
  String get market_tokenLoopProvenanceLine6 =>
      'The last candle hasn\'t closed and may still change.';

  @override
  String get market_tokenLoopProvenanceLine7 =>
      'MA and VOL are calculated on device from the chart\'s closes and volume, with no separate data source.';

  @override
  String get market_tokenMarker => 'Includes delayed or derived values';

  @override
  String get market_tokenMarketRangeCell => '24h high';

  @override
  String get market_tokenMarketRangeCell2 => '24h low';

  @override
  String get market_tokenMessage => 'System share can\'t open right now';

  @override
  String get market_tokenMessage2 => 'Contract address copied';

  @override
  String get market_tokenSentenceGap => ' ';

  @override
  String market_tokenShare(Object? address) {
    return 'Contract $address';
  }

  @override
  String get market_tokenShare2 => 'View market on LOOP';

  @override
  String get market_tokenTokenAboutContractValue => 'Native chain asset';

  @override
  String get market_tokenTokenAssetBlockedLabel =>
      'This asset is marked as hidden';

  @override
  String market_tokenTokenCandleChartSemanticLabel(
    Object? block,
    Object? chartIntervalLabel,
    Object? items,
    Object? priceUnit,
    Object? style,
  ) {
    return '$items $chartIntervalLabel $style, in $priceUnit$block';
  }

  @override
  String get market_tokenTokenChartExpandLabel => 'Open full-screen chart';

  @override
  String market_tokenTokenCommunityEntrySubtitle(
    Object? memberCount,
    Object? name,
  ) {
    return '$name · $memberCount members';
  }

  @override
  String get market_tokenTokenCommunityEntryTitle => 'Open LOOP community';

  @override
  String market_tokenTokenCommunityUnavailableMessage(Object? reasonCodeText) {
    return 'No linked LOOP community yet · $reasonCodeText';
  }

  @override
  String get market_tokenTokenCopyAddressLabel => 'Copy contract address';

  @override
  String get market_tokenTokenFactsPair =>
      'Main pair: no pair with this asset as base';

  @override
  String market_tokenTokenFactsPair2(
    Object? marketDexLabel,
    Object? quoteTokenSymbol,
    Object? truncatedAddress,
  ) {
    return 'Main pair: $marketDexLabel · Quote $quoteTokenSymbol · $truncatedAddress';
  }

  @override
  String get market_tokenTokenFeedEmptyMessage =>
      'Triggered price alerts appear here. Push notifications aren\'t available yet.';

  @override
  String get market_tokenTokenHoldersDistributionUnavailableMessage =>
      'Holder distribution isn\'t available right now';

  @override
  String get market_tokenTokenInvalidIdentityMessage =>
      'The token page accepts only a canonical CAIP assetId. No market data was requested and no other asset was used instead.';

  @override
  String get market_tokenTokenInvalidRouteTitle => 'Can\'t open this asset';

  @override
  String market_tokenTokenLiveSuppressedMessage(Object? reasonCodeText) {
    return 'On-chain reads aren\'t available right now · $reasonCodeText';
  }

  @override
  String get market_tokenTokenMiningWeightText => 'Mining weight';

  @override
  String market_tokenTokenPriceUnavailableMessage(
    Object? reasonCodeSummaryText,
    Object? reasonCodeText,
  ) {
    return 'Price$reasonCodeSummaryText · $reasonCodeText';
  }

  @override
  String get market_tokenTokenSecurityEmptyMessage =>
      'Contract info can\'t be loaded right now. A missing item doesn\'t mean safe or unsafe';

  @override
  String get market_tokenTokenSecurityProvenanceDetail =>
      'No rating, score or verdict is given here. A missing item only means it couldn\'t be read, not that it\'s safe or unsafe.';

  @override
  String market_tokenTokenSecurityProvenancePrefix(Object? facts) {
    return '$facts contract facts';
  }

  @override
  String market_tokenTokenSecurityUnavailableMessage(Object? reasonCodeText) {
    return 'Contract facts can\'t be loaded · $reasonCodeText';
  }

  @override
  String market_tokenTokenSwapUnavailableMessage(Object? reasonCodeText) {
    return 'Buy, sell and swap aren\'t available right now · $reasonCodeText';
  }

  @override
  String get market_tokenTokenTradesEmptyMessage =>
      'No one has traded in this pool recently';

  @override
  String market_tokenTokenTradesUnavailableMessage(Object? reasonCodeText) {
    return 'Trade history can\'t be loaded · $reasonCodeText';
  }

  @override
  String get market_tokenYesNo => 'Source verified';

  @override
  String get market_tokenYesNo10 => 'Owner can\'t change balances';

  @override
  String get market_tokenYesNo11 => 'Self-destruct detected';

  @override
  String get market_tokenYesNo12 => 'No self-destruct detected';

  @override
  String get market_tokenYesNo13 => 'Transfers pausable';

  @override
  String get market_tokenYesNo14 => 'Transfers not pausable';

  @override
  String get market_tokenYesNo15 => 'Blacklist detected';

  @override
  String get market_tokenYesNo16 => 'No blacklist detected';

  @override
  String get market_tokenYesNo17 => 'Whitelist detected';

  @override
  String get market_tokenYesNo18 => 'No whitelist detected';

  @override
  String get market_tokenYesNo19 => 'Can\'t sell all';

  @override
  String get market_tokenYesNo2 => 'Source not verified';

  @override
  String get market_tokenYesNo20 => 'Can sell all';

  @override
  String get market_tokenYesNo3 => 'Proxy contract';

  @override
  String get market_tokenYesNo4 => 'Not a proxy';

  @override
  String get market_tokenYesNo5 => 'Mint detected';

  @override
  String get market_tokenYesNo6 => 'No mint detected';

  @override
  String get market_tokenYesNo7 => 'Ownership reclaimable';

  @override
  String get market_tokenYesNo8 => 'No ownership reclaim detected';

  @override
  String get market_tokenYesNo9 => 'Owner can change balances';

  @override
  String get market_widgetsLoopRecordRow => 'Priced in BNB';

  @override
  String market_widgetsLoopRecordRow2(Object? formatCompactFigure) {
    return 'Reserve $formatCompactFigure';
  }

  @override
  String get market_widgetsLoopRecordRow3 => 'Reserve can\'t be loaded';

  @override
  String get market_widgetsLoopRecordRow4 => '24h volume can\'t be loaded';

  @override
  String get market_widgetsMarketBrowseOnlyLabel => 'View only';

  @override
  String get market_widgetsMarketNewPairsPageSubtitle =>
      'Risk screening, collapsed rows and full notes are on this page';

  @override
  String get market_widgetsMarketNewPairsStamp => 'High risk';

  @override
  String market_widgetsMarketNewPairsUnavailableMessage(
    Object? reasonCodeText,
  ) {
    return 'New pair discovery unavailable · $reasonCodeText';
  }

  @override
  String get market_widgetsMarketSearchFieldLabel =>
      'Search token or contract address';

  @override
  String get market_widgetsMarketSignalsKicker => 'Market overview';

  @override
  String get market_widgetsMarketTradesKicker => 'Trade history';

  @override
  String get market_widgetsMarketWatchlistKicker => 'Edit watchlist';

  @override
  String get market_widgetsMessage => 'Added to watchlist';

  @override
  String get market_widgetsMessage2 => 'Removed from watchlist';

  @override
  String market_widgetsMessage3(Object? watchlistMaxItems) {
    return 'Your watchlist has reached $watchlistMaxItems items. Remove one in watchlist management first.';
  }

  @override
  String market_widgetsMessage4(
    Object? watchlistDefaultGroupName,
    Object? watchlistMaxGroups,
  ) {
    return 'You\'ve reached $watchlistMaxGroups groups, so the default group \"$watchlistDefaultGroupName\" can\'t be created.';
  }

  @override
  String get market_widgetsMessage5 =>
      'Your watchlist changed on another device, so this wasn\'t saved. Retry.';

  @override
  String get market_widgetsSwitch => 'Search token / contract address';

  @override
  String get market_widgetsTitle => 'Unnamed pool';

  @override
  String get meme_createBody => 'What you\'ve entered won\'t be saved.';

  @override
  String get meme_createCancelLabel => 'Keep editing';

  @override
  String get meme_createConfirmLabel => 'Discard';

  @override
  String get meme_createConfirmStep => 'The address is set at creation';

  @override
  String get meme_createConfirmed => 'Created';

  @override
  String get meme_createEmptyMessage => 'This draft no longer exists';

  @override
  String get meme_createErrorText =>
      'Enter an amount greater than 0, up to 18 decimal places';

  @override
  String get meme_createHintText => '1–32 characters';

  @override
  String get meme_createHintText2 => '2–10 letters or digits';

  @override
  String get meme_createIf => 'Only links starting with https:// are supported';

  @override
  String get meme_createIf2 =>
      'You\'ve used up today\'s creations. Come back tomorrow';

  @override
  String meme_createIf3(Object? memeUsd1Label) {
    return 'Minimum buy $memeUsd1Label';
  }

  @override
  String meme_createIf4(Object? memeTokenFigure) {
    return 'Exceeds the per-wallet limit of $memeTokenFigure';
  }

  @override
  String get meme_createLabel => 'Upload image';

  @override
  String get meme_createLabel2 => 'Change';

  @override
  String get meme_createLabel3 => 'For sale';

  @override
  String get meme_createLabel4 => 'Trading fee';

  @override
  String get meme_createLabel5 => 'Per-wallet limit';

  @override
  String get meme_createLabel6 => 'Graduation condition';

  @override
  String meme_createLabel7(Object? address) {
    return 'Token address $address';
  }

  @override
  String get meme_createLabelText => 'Symbol';

  @override
  String get meme_createLabelText2 => 'Bio (optional)';

  @override
  String get meme_createLabelText3 => 'X (optional)';

  @override
  String get meme_createLabelText4 => 'Telegram (optional)';

  @override
  String get meme_createLabelText5 => 'Website (optional)';

  @override
  String get meme_createLabelText6 => 'First buy with USD1';

  @override
  String get meme_createLoopButton => 'Create';

  @override
  String get meme_createLoopLabel => 'Token address';

  @override
  String get meme_createLoopLabel2 => 'Parameters';

  @override
  String get meme_createLoopLabel3 => 'First buy (optional)';

  @override
  String get meme_createMedia => 'Image and links';

  @override
  String get meme_createMediaStep =>
      'Square image, crop before uploading. Without one, the symbol\'s first letter is used.';

  @override
  String get meme_createMemeCreateBlockedTitle =>
      'Tokens can\'t be created right now';

  @override
  String get meme_createMemeCreateEvidencePendingBody =>
      'Contract check in progress. Creating may be unavailable for now.';

  @override
  String get meme_createMemeCreateNextLabel => 'Generating address…';

  @override
  String get meme_createMemeCreateNoVanityBody =>
      'A 6666 suffix can\'t be assigned this time. The token can still be created and traded normally.';

  @override
  String get meme_createMemeCreateNoWalletBody => 'Loading wallet…';

  @override
  String get meme_createMemeCreateNoWalletBody2 =>
      'No wallet available yet. Create or activate one in Wallet first.';

  @override
  String get meme_createMemeCreateResetLabel => 'Start over';

  @override
  String get meme_createMemeCreateResumeLabel => 'Check again';

  @override
  String get meme_createMemeCreateRetiredOpenV2Label => 'Go to v2 launch';

  @override
  String get meme_createMemeCreateRetiredOpenV2Message =>
      'Use Loop Hook launch (v2 launch) to create new tokens.';

  @override
  String get meme_createMemeCreateRetiredOpenV2Title =>
      'Classic launch is retired';

  @override
  String get meme_createMemeCreateRetiredTitle => 'Create token';

  @override
  String get meme_createMemeCreateRetryReportLabel => 'Report again';

  @override
  String meme_createMemeCreateUploadFailedBody(Object? memeFailureText) {
    return 'The image didn\'t upload: $memeFailureText';
  }

  @override
  String get meme_createPreparing => 'Preparing…';

  @override
  String get meme_createS =>
      'This device can\'t pick images right now. Without one, the symbol\'s first letter is used.';

  @override
  String get meme_createSwitch => 'Name 1–32 characters';

  @override
  String get meme_createSwitch2 => 'Symbol 2–10 letters or digits';

  @override
  String get meme_createSwitch3 => 'Bio up to 500 characters';

  @override
  String meme_createText(
    Object? memeTokenFigure,
    Object? memeTokenLabel,
    Object? memeUsd1Label,
  ) {
    return 'About $memeTokenLabel, fee $memeUsd1Label, limit $memeTokenFigure. The server quote applies before signing.';
  }

  @override
  String get meme_createTitle => 'Discard token creation?';

  @override
  String meme_createValue(Object? memeTokenFigure) {
    return '$memeTokenFigure';
  }

  @override
  String meme_createValue2(Object? memeBpsLabel, Object? memeTokenFigure) {
    return '$memeTokenFigure ($memeBpsLabel)';
  }

  @override
  String get meme_createValue3 =>
      'Lists on PancakeSwap automatically once the sale portion sells out';

  @override
  String meme_createValue4(Object? memeUsd1Label) {
    return 'Lists on PancakeSwap automatically after raising about $memeUsd1Label';
  }

  @override
  String get meme_createWaiting => 'Broadcast, waiting for confirmation…';

  @override
  String get meme_designSemantics => 'Not loaded';

  @override
  String meme_formatMemeAgeLabel(Object? inMinutes) {
    return '${inMinutes}m';
  }

  @override
  String meme_formatMemeAgeLabel2(Object? inHours) {
    return '${inHours}h';
  }

  @override
  String meme_formatMemeAgeLabel3(Object? inDays) {
    return '${inDays}d';
  }

  @override
  String get meme_formatSwitch => 'No DEX pool quote yet';

  @override
  String get meme_formatSwitch10 =>
      'This transaction expired (not signed within about 30 seconds). Start again';

  @override
  String get meme_formatSwitch11 =>
      'This transaction is no longer valid. Start again';

  @override
  String get meme_formatSwitch12 => 'Not enough USD1';

  @override
  String get meme_formatSwitch13 => 'Sell amount exceeds your holdings';

  @override
  String meme_formatSwitch14(Object? loopLaunchNativeSymbolText) {
    return 'Not enough $loopLaunchNativeSymbolText for fees';
  }

  @override
  String get meme_formatSwitch15 => 'Exceeds the per-wallet limit of 40M';

  @override
  String get meme_formatSwitch16 => 'Minimum buy 1 USD1';

  @override
  String get meme_formatSwitch17 =>
      'Some details aren\'t valid. Check the name, symbol, bio and links';

  @override
  String get meme_formatSwitch18 =>
      'This image wasn\'t uploaded by this account. Upload it again';

  @override
  String get meme_formatSwitch19 => 'The quote changed. Get a new quote';

  @override
  String get meme_formatSwitch2 => 'DEX pool market data can\'t be loaded';

  @override
  String get meme_formatSwitch20 =>
      'The on-chain transaction doesn\'t match what you confirmed';

  @override
  String get meme_formatSwitch21 => 'The transaction didn\'t succeed on chain';

  @override
  String get meme_formatSwitch22 =>
      'This transaction hasn\'t appeared on chain for a while';

  @override
  String get meme_formatSwitch23 => 'Simulation failed. Get a new quote';

  @override
  String get meme_formatSwitch24 =>
      'Can\'t simulate right now. Try again later';

  @override
  String get meme_formatSwitch25 =>
      'Approval needed first. Can\'t simulate before approval';

  @override
  String get meme_formatSwitch26 => 'Wallet not activated yet';

  @override
  String get meme_formatSwitch27 => 'On-chain data can\'t be loaded right now';

  @override
  String get meme_formatSwitch28 => 'Trading is closed for now';

  @override
  String get meme_formatSwitch29 => 'Mainnet signing isn\'t available yet';

  @override
  String get meme_formatSwitch3 => 'Not on chain yet';

  @override
  String get meme_formatSwitch30 => 'Launchpad isn\'t available yet';

  @override
  String get meme_formatSwitch31 =>
      'Launchpad service isn\'t available right now';

  @override
  String get meme_formatSwitch32 => 'Launchpad contract isn\'t configured yet';

  @override
  String get meme_formatSwitch33 => 'Exceeds the per-transaction limit';

  @override
  String get meme_formatSwitch34 => 'Exceeds today\'s limit';

  @override
  String get meme_formatSwitch35 => 'This transaction isn\'t allowed right now';

  @override
  String get meme_formatSwitch4 => 'Price can\'t be loaded right now';

  @override
  String get meme_formatSwitch5 => 'Token doesn\'t exist';

  @override
  String get meme_formatSwitch6 => 'Not tradable right now';

  @override
  String get meme_formatSwitch7 => 'Filled, waiting to graduate';

  @override
  String get meme_formatSwitch8 => 'Status changed. Refresh';

  @override
  String get meme_formatSwitch9 => 'Address already taken. Retry';

  @override
  String meme_homeTopClosedReason(Object? chainFailureReason) {
    return 'Wallet didn\'t load · $chainFailureReason';
  }

  @override
  String get meme_homeTopIf =>
      'Can\'t reach LOOP right now, so the balance can\'t be loaded';

  @override
  String meme_homeTopIf2(Object? reasonCodeText) {
    return 'Wallet balance can\'t be loaded · $reasonCodeText';
  }

  @override
  String meme_homeTopLabel(
    Object? displayName,
    Object? formatUsd,
    Object? symbol,
  ) {
    return '$displayName made $formatUsd on $symbol';
  }

  @override
  String get meme_homeTopLoopLabel => 'Best trades this week';

  @override
  String get meme_homeTopMemeTopUpLabel => 'Top up';

  @override
  String get meme_homeTopReason => 'Wallet balance can\'t be loaded right now';

  @override
  String get meme_homeTopReason2 => 'No wallet yet';

  @override
  String meme_homeTopReason3(Object? chainFailureReason) {
    return 'Balance didn\'t load · $chainFailureReason';
  }

  @override
  String meme_homeTopReason4(Object? count) {
    return '$count assets have no price yet, so total assets aren\'t shown';
  }

  @override
  String get meme_homeTopS => 'Wallet status hasn\'t loaded yet';

  @override
  String meme_homeTopText(Object? view) {
    return ' · 24h$view';
  }

  @override
  String get meme_launchpadEmptyMessage =>
      'No tokens yet. Create the first one';

  @override
  String get meme_launchpadEmptyMessage2 => 'No tokens here yet';

  @override
  String get meme_launchpadEmptyMessage3 =>
      'Platform MEME assets appear here once they\'re live';

  @override
  String get meme_launchpadIf =>
      'Can\'t reach LOOP right now, so the Launchpad can\'t be loaded';

  @override
  String get meme_launchpadMemeEmptyCreateLabel => 'Create the first one';

  @override
  String get meme_launchpadMemeEmptyCreateMessage =>
      'Classic launch is retired. Use v2 launch for new tokens';

  @override
  String get meme_launchpadMemeEmptyCreateMessage2 =>
      'Create the first one. It lists on PancakeSwap automatically when filled';

  @override
  String get meme_launchpadMemeEmptyCreateTitle => 'No tokens yet';

  @override
  String meme_launchpadMemeLaunchpadUnavailableMessage(
    Object? memeCapabilityText,
  ) {
    return 'Launchpad isn\'t available right now · $memeCapabilityText';
  }

  @override
  String get meme_launchpadMemeListProvenanceDetail =>
      'Bonding pool token prices and market caps come from the LOOP curve. Graduated tokens come from DexScreener. Tokens without a price show the reason instead of 0.';

  @override
  String get meme_launchpadMemeMarketEmptyTitle => 'No MEME assets yet';

  @override
  String meme_launchpadMemeMarketProvenanceDetail(Object? orderingLabel) {
    return '$orderingLabel. Bonding pool tokens come from the LOOP curve and graduated tokens from DexScreener. Tokens without a quote show the reason.';
  }

  @override
  String meme_launchpadMemeMarketUnavailableMessage(Object? reasonCodeText) {
    return 'Market isn\'t available right now · $reasonCodeText';
  }

  @override
  String get meme_launchpadMemeSearchEntryLabel => 'Search tokens';

  @override
  String get meme_launchpadS => 'Launchpad status hasn\'t loaded yet';

  @override
  String get meme_modelsBroadcastReported =>
      'Broadcast, waiting for confirmation';

  @override
  String get meme_modelsFailed => 'Didn\'t succeed';

  @override
  String get meme_modelsFiveMinutes => '5m';

  @override
  String get meme_modelsFresh => 'New';

  @override
  String get meme_modelsGraduating => 'Almost full';

  @override
  String get meme_modelsHot => 'Hot';

  @override
  String get meme_modelsLoopCurve => 'LOOP curve';

  @override
  String get meme_modelsOneMinute => '1m';

  @override
  String meme_screenLaunch2ListAllUnavailableMessage(
    Object? launch2CapabilityText,
  ) {
    return 'MEME v2 isn\'t available right now · $launch2CapabilityText';
  }

  @override
  String get meme_signingBuy => 'Confirm buy';

  @override
  String meme_signingConfirmed(Object? noun) {
    return '$noun confirmed on chain.';
  }

  @override
  String get meme_signingCreate => 'Confirm create';

  @override
  String meme_signingExpired(Object? memeReasonText, Object? noun) {
    return '$noun expired: $memeReasonText.';
  }

  @override
  String meme_signingFailed(Object? memeReasonText, Object? noun) {
    return '$noun didn\'t succeed: $memeReasonText.';
  }

  @override
  String meme_signingIf(Object? memeShortAddress, Object? noun) {
    return 'Approval broadcast ($memeShortAddress), but the wallet result of the $noun transaction is unknown, so it\'s locked. Don\'t sign again. Refresh later.';
  }

  @override
  String meme_signingIf2(Object? noun) {
    return 'The wallet result is unknown, so this $noun is locked. Don\'t sign again. Refresh later.';
  }

  @override
  String meme_signingIf3(Object? short) {
    return 'Broadcast ($short) and recorded by the server. Broadcast doesn\'t mean filled. Waiting for on-chain confirmation.';
  }

  @override
  String meme_signingIf4(Object? memeReportReasonText, Object? short) {
    return 'Broadcast ($short). $memeReportReasonText';
  }

  @override
  String get meme_signingIntentField => 'Can\'t simulate before approval';

  @override
  String get meme_signingLabel => 'Estimated to receive';

  @override
  String get meme_signingLabel2 => 'Minimum received';

  @override
  String get meme_signingLabel3 => 'First buy payment';

  @override
  String get meme_signingLabel4 => 'Refund when full';

  @override
  String get meme_signingLabel5 => 'Fee';

  @override
  String get meme_signingLabel6 => 'Approve first';

  @override
  String meme_signingPollTimedOut(Object? noun) {
    return 'Broadcast, but no confirmation yet. It may still be confirming, so check again later. Don\'t repeat the $noun.';
  }

  @override
  String meme_signingPreparing(Object? noun) {
    return 'Preparing $noun. The wallet isn\'t open yet.';
  }

  @override
  String meme_signingReason(Object? memeIntentNoun) {
    return 'Your wallet opens twice: approve first, then $memeIntentNoun. The approval covers only this transaction.';
  }

  @override
  String get meme_signingSell => 'Confirm sell';

  @override
  String meme_signingSetState(Object? memeIntentNoun, Object? memeIntentNoun2) {
    return 'Approval broadcast, but $memeIntentNoun wasn\'t signed, so no $memeIntentNoun2 transaction was submitted. Close and start again.';
  }

  @override
  String get meme_signingSwitch => 'Cancelled. Nothing changed.';

  @override
  String get meme_signingSwitch10 =>
      'Simulation failed, so this transaction would be rejected on chain. Nothing was submitted. Get a new quote.';

  @override
  String get meme_signingSwitch11 =>
      'The wallet didn\'t finish signing. Nothing was submitted.';

  @override
  String get meme_signingSwitch12 =>
      'A different hash was already reported for this transaction, so this broadcast wasn\'t recorded. It may already be on chain. Don\'t sign again.';

  @override
  String get meme_signingSwitch13 =>
      'The server no longer accepts reports for this transaction. The wallet already broadcast it and it may be on chain. Don\'t sign again.';

  @override
  String get meme_signingSwitch14 =>
      'This transaction expired and isn\'t visible on chain yet, so the report wasn\'t accepted. It may still be propagating. Don\'t sign again.';

  @override
  String get meme_signingSwitch15 =>
      'The on-chain transaction doesn\'t match what you confirmed, so the server didn\'t record it. Don\'t sign again, and contact support.';

  @override
  String get meme_signingSwitch16 =>
      'The wallet already broadcast, but this report wasn\'t accepted or didn\'t arrive. The transaction may be on chain. You can report again later. Don\'t sign again.';

  @override
  String meme_signingSwitch17(Object? noun) {
    return 'Approval broadcast, but $noun wasn\'t signed. You can start again.';
  }

  @override
  String meme_signingSwitch18(Object? noun) {
    return 'This $noun is locked. Don\'t sign again.';
  }

  @override
  String get meme_signingSwitch2 => 'Identity check failed. Nothing changed.';

  @override
  String get meme_signingSwitch3 =>
      'This transaction expired. Nothing was submitted. Start again.';

  @override
  String get meme_signingSwitch4 =>
      'The transaction doesn\'t match what you confirmed, so signing was refused. Nothing was submitted.';

  @override
  String get meme_signingSwitch5 =>
      'The wallet for this transaction isn\'t in your wallet list. Nothing was submitted.';

  @override
  String get meme_signingSwitch6 =>
      'The server built this transaction for a different wallet, so signing was refused. Nothing was submitted.';

  @override
  String get meme_signingSwitch7 =>
      'Signing isn\'t allowed on this chain. Nothing was submitted.';

  @override
  String get meme_signingSwitch8 =>
      'The wallet can\'t sign on this chain right now. Nothing was submitted.';

  @override
  String get meme_signingSwitch9 =>
      'The signed-in wallet isn\'t this transaction\'s wallet. Nothing was submitted.';

  @override
  String get meme_signingTitle => 'Approve';

  @override
  String meme_signingValue(Object? memeTokenLabel) {
    return '$memeTokenLabel to the curve contract';
  }

  @override
  String meme_signingWaiting(Object? attempts, Object? noun) {
    return 'Broadcast, waiting for on-chain confirmation (checked $attempts times). Don\'t repeat the $noun.';
  }

  @override
  String get meme_tokenBuild => 'DEX pool price';

  @override
  String meme_tokenBuild2(Object? memeTokenLabel) {
    return 'Holding $memeTokenLabel';
  }

  @override
  String get meme_tokenBuild3 => '100% · Graduated';

  @override
  String meme_tokenBuild4(Object? memeBpsLabel, Object? memeCapLabel) {
    return '$memeBpsLabel · $memeCapLabel to go';
  }

  @override
  String get meme_tokenBuild5 => 'Buy';

  @override
  String get meme_tokenCopy => 'Contract address copied';

  @override
  String get meme_tokenCopy2 => 'Pool address copied';

  @override
  String get meme_tokenCreatorBadge => 'Dev';

  @override
  String get meme_tokenDetail =>
      'Holding = net curve buys minus sells. Transfers between wallets don\'t count. Share is out of a 1B total supply.';

  @override
  String get meme_tokenDetail2 =>
      'Buy amounts are what was paid (including the 1% fee, excluding refunds). Sell amounts are what was received (after fees).';

  @override
  String get meme_tokenEmptyMessage => 'No holders yet';

  @override
  String get meme_tokenFor => 'Website';

  @override
  String get meme_tokenFull => 'Filled';

  @override
  String get meme_tokenGraduatedChartHint =>
      ' See the DEX pool market for the trend after graduation.';

  @override
  String meme_tokenIf(Object? holderCount) {
    return '$holderCount holders · Counted from curve trades';
  }

  @override
  String get meme_tokenLabel => 'Token contract';

  @override
  String get meme_tokenLabel10 => '24h volume';

  @override
  String get meme_tokenLabel11 => 'All holders';

  @override
  String get meme_tokenLabel12 => 'All activity';

  @override
  String get meme_tokenLabel2 => 'Curve contract';

  @override
  String get meme_tokenLabel3 => 'Contract version';

  @override
  String get meme_tokenLabel4 => 'PancakeSwap pool';

  @override
  String get meme_tokenLabel5 => 'USD1 added';

  @override
  String get meme_tokenLabel6 => 'Tokens added';

  @override
  String get meme_tokenLabel7 => 'LP burned';

  @override
  String get meme_tokenLabel8 => 'Graduated at';

  @override
  String get meme_tokenLabel9 => 'Fill progress';

  @override
  String meme_tokenLoopInlineUnavailable(Object? text) {
    return 'This token was hidden from the Launchpad · $text';
  }

  @override
  String get meme_tokenLoopInlineUnavailable2 =>
      'This token was hidden from the Launchpad';

  @override
  String get meme_tokenLoopLabel => 'Creator';

  @override
  String get meme_tokenLoopSheetHeading => 'Share token';

  @override
  String get meme_tokenMemeAboutDexSubtitle =>
      'Price and candles after graduation';

  @override
  String get meme_tokenMemeAboutDexTitle => 'DEX pool market';

  @override
  String get meme_tokenMemeAboutExplorerTitle => 'Block explorer';

  @override
  String get meme_tokenMemeAboutProvenanceDetail =>
      'Curve status, holders and trades come from LOOP\'s index of curve contract events. Only tokens created through LOOP are listed.';

  @override
  String get meme_tokenMemeAboutResidualMessage =>
      'The DEX pool exists. Some funds remain in the contract';

  @override
  String meme_tokenMemeCandlesProvenanceDetail(Object? series) {
    return 'Prices after each curve trade are grouped into candles by interval. Empty intervals aren\'t filled.$series';
  }

  @override
  String get meme_tokenMemeCandlesProvenancePrefix => 'In USD1';

  @override
  String get meme_tokenMemeCandlesProvenancePrefix2 => 'Stops at graduation';

  @override
  String get meme_tokenMemeChartEmptyMessage =>
      'A few more trades and the trend will appear';

  @override
  String get meme_tokenMemeProvenance => 'LOOP on-chain index';

  @override
  String get meme_tokenMemeTokenBlockedTitle =>
      'Launchpad isn\'t available right now';

  @override
  String get meme_tokenMemeTokenCopyPoolLabel => 'Copy pool';

  @override
  String get meme_tokenMemeTokenEvidencePendingMessage =>
      'Contract check in progress. Trading may be unavailable for now';

  @override
  String get meme_tokenMemeTokenFullLabel => 'Filled, graduating…';

  @override
  String get meme_tokenMemeTokenGraduatedCloseBody =>
      'The curve is filled, the token is on PancakeSwap and the LP is burned.';

  @override
  String get meme_tokenMemeTokenInvalidIdentityMessage =>
      'No data was requested and no other token was used instead.';

  @override
  String get meme_tokenMemeTokenInvalidIdentityTitle =>
      'No usable token ID in the route';

  @override
  String get meme_tokenMemeTokenInvalidRouteTitle => 'Can\'t open this token';

  @override
  String meme_tokenMemeTokenLiquidityLowBody(Object? memeCapLabel) {
    return 'Low liquidity · Bonding pool reserve $memeCapLabel. Large buys have high slippage';
  }

  @override
  String get meme_tokenMemeTokenPausedLabel => 'Trading paused';

  @override
  String get meme_tokenMemeTokenPendingLabel => 'Creating…';

  @override
  String get meme_tokenMemeTokenPriceProvenanceDetail =>
      'Bonding pool price = ratio of the curve\'s virtual reserves. Market cap = price × 1B total supply.';

  @override
  String get meme_tokenMemeTokenPriceProvenanceDetail2 =>
      'Price and market cap after graduation come from DexScreener.';

  @override
  String meme_tokenMemeTokenProgressBarSemanticLabel(Object? memeBpsLabel) {
    return 'Bonding pool progress $memeBpsLabel';
  }

  @override
  String get meme_tokenMemeTokenQuickBuySurfaceLabel => 'Quick buy';

  @override
  String get meme_tokenMemeTokenResumeLabel => 'Continue creating';

  @override
  String get meme_tokenMemeTokenSwapLabel => 'Go to Swap';

  @override
  String get meme_tokenMemeTokenSwapTestnetMessage =>
      'In-app swap isn\'t supported yet';

  @override
  String meme_tokenMemeTokenViewerUnavailableMessage(Object? memeReasonText) {
    return 'My holdings can\'t be loaded · $memeReasonText';
  }

  @override
  String get meme_tokenMessage => 'No wallet available yet';

  @override
  String get meme_tokenMessage3 => 'Holders appear here after the first buy';

  @override
  String get meme_tokenMessage4 => 'Trades appear here after a buy or sell';

  @override
  String get meme_tokenNoAddressYet => 'No address yet';

  @override
  String get meme_tokenPaused => 'Paused';

  @override
  String get meme_tokenPendingChain => 'Creating';

  @override
  String meme_tokenS(Object? holderCount) {
    return '$holderCount holders · Counted from curve trades · Frozen at graduation';
  }

  @override
  String get meme_tokenS2 => 'Sell';

  @override
  String meme_tokenSemanticLabel(
    Object? candles,
    Object? label,
    Object? style,
  ) {
    return '$candles $label $style, in USD1';
  }

  @override
  String get meme_tokenSemanticLabel2 => 'Token contract address QR code';

  @override
  String meme_tokenShare(Object? address) {
    return 'Contract $address';
  }

  @override
  String get meme_tokenShare2 => 'View on LOOP Launchpad';

  @override
  String get meme_tokenSubtitle => 'The creator has no public profile';

  @override
  String get meme_tokenSubtitle2 => 'View public profile';

  @override
  String meme_tokenSubtitle3(
    Object? memeTokenCompact,
    Object? rank,
    Object? symbol,
  ) {
    return '#$rank · $memeTokenCompact $symbol';
  }

  @override
  String get meme_tokenText => '1D';

  @override
  String get meme_tokenTitle => 'No public profile';

  @override
  String get meme_tokenTrading => 'Bonding pool';

  @override
  String get meme_tokenValue => 'No limit after graduation';

  @override
  String meme_tradePanelIf(Object? memeTokenFigure) {
    return 'Exceeds the per-wallet limit of $memeTokenFigure';
  }

  @override
  String get meme_tradePanelIf2 => 'This amount gets no tokens. Adjust it';

  @override
  String get meme_tradePanelLabel => 'Get';

  @override
  String get meme_tradePanelLabel2 => 'Fee';

  @override
  String get meme_tradePanelLabel3 => 'Impact';

  @override
  String get meme_tradePanelLoopProvenanceLine => 'On-chain curve';

  @override
  String meme_tradePanelLoopSheetHeading(Object? ticker) {
    return 'Buy $ticker';
  }

  @override
  String meme_tradePanelMemeTradeBalance(Object? memeReasonText) {
    return 'Wallet data can\'t be loaded · $memeReasonText';
  }

  @override
  String meme_tradePanelMemeTradeBalance2(Object? memeUsd1Label) {
    return 'Available $memeUsd1Label';
  }

  @override
  String get meme_tradePanelMemeTradeQuoteEmpty => 'Getting quote…';

  @override
  String get meme_tradePanelMemeTradeQuoteEmpty2 =>
      'Enter an amount to see a quote';

  @override
  String meme_tradePanelMemeTradeQuoteFailedMessage(Object? memeFailureText) {
    return 'Couldn\'t get a quote · $memeFailureText';
  }

  @override
  String get meme_tradePanelMemeTradeQuoteProvenanceDetail =>
      'The quote uses the current on-chain curve.';

  @override
  String get meme_tradePanelMemeTradeQuoteProvenanceDetail2 =>
      'On-chain reads aren\'t available, so the quote uses the index snapshot and may lag a few blocks.';

  @override
  String get meme_tradePanelMemeTradeSlippageCustomLabel => 'Custom';

  @override
  String meme_tradePanelS(Object? memeTokenLabel) {
    return 'Exceeds the per-wallet limit. You can buy up to $memeTokenLabel more';
  }

  @override
  String meme_tradePanelS2(Object? ticker) {
    return 'Sell $ticker';
  }

  @override
  String meme_widgetsBuild(Object? memeCapLabel) {
    return '$memeCapLabel volume';
  }

  @override
  String get meme_widgetsMemeChangeUnreported => '1h change not reported';

  @override
  String meme_widgetsMemeTokenSpokenLabel(Object? memeCapLabel) {
    return 'Market cap $memeCapLabel';
  }

  @override
  String meme_widgetsMemeTokenSpokenLabel2(Object? holderCount) {
    return '$holderCount holders';
  }

  @override
  String meme_widgetsSemantics(Object? memeCapLabel) {
    return 'Volume $memeCapLabel';
  }

  @override
  String meme_widgetsSemantics2(Object? age) {
    return 'Live $age';
  }

  @override
  String get miningRewards_inviteHeadActive => 'Active';

  @override
  String get miningRewards_inviteHeadAsset => 'Assets';

  @override
  String get miningRewards_inviteHeadNft => 'NFT';

  @override
  String get miningRewards_modelsMiningPowerOnlyNotice =>
      'Mining starts once the LOOP token launches; until then only power is tracked';

  @override
  String miningRewards_screenBuild(Object? from, Object? need, Object? to) {
    return 'Not enough BNB for the network fee. Swap $from for $to first.$need Come back to claim after the swap; your claimable balance won\'t change.';
  }

  @override
  String get miningRewards_screenBuild2 =>
      'Shown after an hour with power is settled';

  @override
  String get miningRewards_screenBuild3 =>
      'No meme coins counted toward mining last hour';

  @override
  String get miningRewards_screenBuild4 => 'Level';

  @override
  String get miningRewards_screenBuild5 => 'Rate';

  @override
  String get miningRewards_screenCaption =>
      'Updates after the next hour is settled';

  @override
  String miningRewards_screenCaption2(
    Object? clockLabel,
    Object? completedMinutes,
  ) {
    return '$completedMinutes/60 · next $clockLabel';
  }

  @override
  String get miningRewards_screenConfirming => 'Confirming on-chain';

  @override
  String get miningRewards_screenConfirming2 =>
      'On-chain and waiting for confirmation. Don\'t claim again.';

  @override
  String get miningRewards_screenDisabledReason =>
      'Loading the latest claimable amount';

  @override
  String get miningRewards_screenExpired => 'Voucher expired';

  @override
  String get miningRewards_screenExpired2 =>
      'The claim voucher expired and nothing was paid out. Your claimable balance is unchanged. You can claim again.';

  @override
  String get miningRewards_screenFact => 'Own weighted power';

  @override
  String get miningRewards_screenFact2 => 'Invite power';

  @override
  String miningRewards_screenFact4(Object? miningExcludedReasonText) {
    return 'Excluded ($miningExcludedReasonText)';
  }

  @override
  String get miningRewards_screenFact5 => 'Own power';

  @override
  String miningRewards_screenFailed(Object? reasonSuffix) {
    return 'The on-chain claim failed. Your claimable balance didn\'t go down.$reasonSuffix';
  }

  @override
  String miningRewards_screenFailedCode(Object? code) {
    return ' ($code)';
  }

  @override
  String get miningRewards_screenGasInsufficient =>
      'Not enough BNB for the network fee. Swap USDT first.';

  @override
  String get miningRewards_screenHeading =>
      'Settlement results can\'t be loaded right now';

  @override
  String get miningRewards_screenIf => 'No LOOP to claim right now';

  @override
  String get miningRewards_screenIf2 => 'Loading wallet';

  @override
  String miningRewards_screenLabel(Object? figure) {
    return 'Showing $figure LOOP';
  }

  @override
  String get miningRewards_screenLabel2 => 'Total settled LOOP';

  @override
  String get miningRewards_screenLabel3 => 'Total claimed LOOP';

  @override
  String get miningRewards_screenLabel4 => 'Claimable LOOP';

  @override
  String get miningRewards_screenLabel6 => 'Meme coin power';

  @override
  String get miningRewards_screenLoopLabel => 'Power summary';

  @override
  String get miningRewards_screenLoopLabel2 => 'Rewards summary';

  @override
  String get miningRewards_screenLoopLabel3 => 'NFT track';

  @override
  String get miningRewards_screenLoopLabel4 => 'Meme coin track';

  @override
  String get miningRewards_screenLoopLabel5 => 'Five-level invites';

  @override
  String get miningRewards_screenLoopLabel6 => 'Claim history';

  @override
  String get miningRewards_screenLoopProvenanceLine => 'LOOP hourly settlement';

  @override
  String get miningRewards_screenLoopSheetHeading =>
      'Not enough for network fee';

  @override
  String get miningRewards_screenMessage => 'BscScan link copied';

  @override
  String get miningRewards_screenMessage2 => 'Couldn\'t load earlier records';

  @override
  String get miningRewards_screenMiningAssetBasisNote =>
      'Weighted by amount held: power = average amount held that hour × mining weight';

  @override
  String get miningRewards_screenMiningClaimAmountLabel => 'Claimable now';

  @override
  String get miningRewards_screenMiningClaimButtonLabel => 'Claim in progress';

  @override
  String get miningRewards_screenMiningClaimButtonSemanticLabel =>
      'Claim, unavailable';

  @override
  String get miningRewards_screenMiningClaimGasGoLabel => 'Swap';

  @override
  String get miningRewards_screenMiningClaimGasGoLabel2 => 'Top up';

  @override
  String get miningRewards_screenMiningClaimMinimumLabel => 'Minimum claim';

  @override
  String get miningRewards_screenMiningClaimResumeLabel => 'Keep checking';

  @override
  String get miningRewards_screenMiningClaimRetryReportLabel => 'Report again';

  @override
  String get miningRewards_screenMiningClaimTxSubtitle => 'Copy BscScan link';

  @override
  String miningRewards_screenMiningClaimTxTitle(Object? miningShortHash) {
    return 'Successful transaction $miningShortHash';
  }

  @override
  String get miningRewards_screenMiningClaimsEmptyTitle => 'No claims yet';

  @override
  String get miningRewards_screenMiningHourCountedNote =>
      'Active last hour and counted toward power';

  @override
  String get miningRewards_screenMiningInviteNote =>
      'Only invitees\' own power counts; invitees with zero own power don\'t count. Equivalent NFT power is used only for reward calculation.';

  @override
  String miningRewards_screenMiningMinuteBarSemanticLabel(
    Object? completedMinutes,
  ) {
    return 'Minute $completedMinutes of 60';
  }

  @override
  String miningRewards_screenMiningMinuteEpochBody(
    Object? clockLabel,
    Object? clockLabel2,
  ) {
    return 'Settlement period $clockLabel–$clockLabel2 · this hour\'s rewards are fully claimable after settlement';
  }

  @override
  String get miningRewards_screenMiningMinuteKicker => 'Last hour rewards';

  @override
  String miningRewards_screenMiningMinuteTotalBody(Object? miningLoopFigure) {
    return 'Last hour $miningLoopFigure LOOP';
  }

  @override
  String get miningRewards_screenMiningNftBasisNote =>
      'NFT power = amount held × community factor';

  @override
  String get miningRewards_screenMiningNftRealCount =>
      'NFTs held (actual count)';

  @override
  String miningRewards_screenMiningPowerEpochBody(
    Object? clockLabel,
    Object? clockLabel2,
  ) {
    return 'Period $clockLabel–$clockLabel2 · counted every hour on the hour';
  }

  @override
  String miningRewards_screenMiningPowerFolioHeading(Object? figure) {
    return '$figure power';
  }

  @override
  String miningRewards_screenMiningPowerTracksBody(
    Object? assetPower,
    Object? nftPower,
  ) {
    return 'NFT power $nftPower · Meme coin power $assetPower';
  }

  @override
  String get miningRewards_screenMiningRewardsInfoActionTitle =>
      'About mining rewards';

  @override
  String get miningRewards_screenMiningRewardsProvenanceDetail =>
      'Every hour on the hour (UTC), the previous hour\'s NFT and meme coin tracks are settled; that hour\'s rewards are claimable once settled. The per-minute growth only displays last hour\'s rewards and doesn\'t change the claimable amount.';

  @override
  String get miningRewards_screenMiningRewardsProvenanceDetail2 =>
      'Every hour on the hour (UTC), power on the previous hour\'s NFT and meme coin tracks is counted.';

  @override
  String get miningRewards_screenMiningRewardsProvenancePrefix => 'Last read';

  @override
  String get miningRewards_screenMiningRewardsStateEmptyMessage =>
      'No reward records yet';

  @override
  String get miningRewards_screenNoGasSource =>
      'There\'s no BNB in your wallet for the network fee. Top up BNB first.';

  @override
  String get miningRewards_screenNull => 'No power last hour';

  @override
  String get miningRewards_screenPollTimedOut =>
      'Broadcast, but no confirmation read yet. It may still be confirming; check again later and don\'t claim again.';

  @override
  String get miningRewards_screenPowerFolio =>
      'The previous hour settles every hour on the hour; the next hour displays by the minute.';

  @override
  String get miningRewards_screenPreparing =>
      'Creating the claim voucher. The wallet hasn\'t opened yet.';

  @override
  String miningRewards_screenRow(Object? level) {
    return 'Level $level';
  }

  @override
  String get miningRewards_screenRow2 => 'Total';

  @override
  String get miningRewards_screenS =>
      'Power appears after the first hour is settled';

  @override
  String get miningRewards_screenS2 =>
      'Power for the previous hour is counted every hour on the hour.';

  @override
  String get miningRewards_screenS3 => 'Nothing to claim';

  @override
  String get miningRewards_screenS4 =>
      'Claimable amount is below the minimum claim';

  @override
  String get miningRewards_screenS5 => 'No wallet available';

  @override
  String miningRewards_screenS6(Object? requiredNative) {
    return ' This claim needs about $requiredNative BNB.';
  }

  @override
  String get miningRewards_screenS7 => 'BNB needed for network fee';

  @override
  String miningRewards_screenS8(Object? need) {
    return 'Your wallet has no BNB and no USDT to swap.$need Top up a little BNB first, then come back to claim.';
  }

  @override
  String get miningRewards_screenStamp => 'Settling';

  @override
  String get miningRewards_screenSucceeded => 'Claimed. LOOP has arrived.';

  @override
  String get miningRewards_screenSwitch =>
      'Mining rules aren\'t in effect yet, so nothing is settled.';

  @override
  String get miningRewards_screenSwitch10 =>
      'This claim is locked. Don\'t claim again.';

  @override
  String get miningRewards_screenSwitch11 =>
      'The settlement service isn\'t available right now, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch12 =>
      'Mining rules aren\'t in effect yet, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch13 =>
      'Claimable after an hour with power is settled';

  @override
  String miningRewards_screenSwitch14(Object? miningLoopFigure) {
    return 'Claimable at $miningLoopFigure LOOP';
  }

  @override
  String get miningRewards_screenSwitch15 =>
      'The previous claim is still processing. Claim after it finishes';

  @override
  String get miningRewards_screenSwitch16 =>
      'The claim chain isn\'t configured yet, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch17 =>
      'Claim voucher issuing isn\'t configured yet, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch18 =>
      'On-chain writes are off right now, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch19 => 'Mainnet claims aren\'t open yet';

  @override
  String get miningRewards_screenSwitch2 =>
      'Mining rules are in effect. Power for the previous hour is counted every hour on the hour and shown here.';

  @override
  String get miningRewards_screenSwitch20 =>
      'The claim contract is paused, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch21 =>
      'The claim contract can\'t be read right now, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch22 =>
      'The claim contract\'s balance is too low, so you can\'t claim';

  @override
  String get miningRewards_screenSwitch23 =>
      'Claims aren\'t available right now';

  @override
  String get miningRewards_screenSwitch24 => 'No LOOP to claim right now.';

  @override
  String get miningRewards_screenSwitch25 =>
      'Claimable amount is below the minimum claim.';

  @override
  String get miningRewards_screenSwitch26 =>
      'The previous claim is still processing. Claim after it finishes.';

  @override
  String get miningRewards_screenSwitch27 =>
      'The simulation didn\'t pass; this claim would be rejected on-chain. No transaction was submitted.';

  @override
  String get miningRewards_screenSwitch28 =>
      'The claim contract is paused. Your balance is unchanged.';

  @override
  String get miningRewards_screenSwitch29 =>
      'The claim contract can\'t be read right now. No voucher was created and your balance is unchanged.';

  @override
  String get miningRewards_screenSwitch3 =>
      'The settlement service isn\'t available right now. The numbers below may not be current.';

  @override
  String get miningRewards_screenSwitch30 =>
      'The claim contract\'s balance is too low to claim right now. Your balance is unchanged.';

  @override
  String get miningRewards_screenSwitch31 =>
      'The claim voucher expired. No transaction was submitted. Claim again.';

  @override
  String get miningRewards_screenSwitch32 =>
      'Claims go only to your LOOP built-in wallet.';

  @override
  String get miningRewards_screenSwitch33 =>
      'No voucher was created and no transaction was submitted.';

  @override
  String get miningRewards_screenSwitch34 => 'Claim status';

  @override
  String get miningRewards_screenSwitch35 =>
      'Graduated; DEX pool holdings are still syncing';

  @override
  String get miningRewards_screenSwitch36 =>
      'Graduated; DEX pool holdings can\'t be read right now';

  @override
  String get miningRewards_screenSwitch37 => 'Mining weight not configured yet';

  @override
  String get miningRewards_screenSwitch38 => 'Not counted yet';

  @override
  String get miningRewards_screenSwitch4 =>
      'Mining rules are in effect. The previous hour settles every hour on the hour; it\'s then shown here by the minute and can be claimed.';

  @override
  String get miningRewards_screenSwitch5 =>
      'Settlement data can\'t be loaded right now. The numbers below may not be current.';

  @override
  String get miningRewards_screenSwitch6 =>
      'Hours you had power in aren\'t settled yet';

  @override
  String get miningRewards_screenSwitch7 =>
      'Rewards appear after the first hour is settled';

  @override
  String get miningRewards_screenSwitch8 => 'Claimable';

  @override
  String miningRewards_screenSwitch9(Object? attempts) {
    return 'Submitted and waiting to land on-chain (checked $attempts times). Don\'t claim again.';
  }

  @override
  String get miningRewards_screenTimedOut =>
      'Network unavailable. No claim voucher was created.';

  @override
  String miningRewards_screenTitle(Object? miningLoopFigure) {
    return 'Claim $miningLoopFigure LOOP';
  }

  @override
  String get miningRewards_screenUnavailable =>
      'Claims aren\'t available right now. Your balance is unchanged.';

  @override
  String get miningRewards_signingIf =>
      'The wallet result is unknown, so this claim is locked. Don\'t claim again; refresh later to check.';

  @override
  String miningRewards_signingIf2(Object? short) {
    return 'Broadcast ($short) and recorded by the server; waiting for on-chain confirmation.';
  }

  @override
  String miningRewards_signingIf3(
    Object? miningClaimReportReasonText,
    Object? short,
  ) {
    return 'Broadcast ($short). $miningClaimReportReasonText';
  }

  @override
  String get miningRewards_signingLabel => 'Claim amount';

  @override
  String get miningRewards_signingLabel2 => 'Receiving wallet';

  @override
  String get miningRewards_signingLabel3 => 'Network fee';

  @override
  String get miningRewards_signingLabel4 => 'Voucher valid until';

  @override
  String get miningRewards_signingSwitch => 'Cancelled. Nothing changed.';

  @override
  String get miningRewards_signingSwitch10 =>
      'The wallet didn\'t finish signing. No transaction was submitted and your claimable balance is unchanged.';

  @override
  String get miningRewards_signingSwitch11 =>
      'A different hash was already reported for this claim, so this broadcast wasn\'t recorded. Don\'t claim again; refresh later to check.';

  @override
  String get miningRewards_signingSwitch12 =>
      'This on-chain transaction doesn\'t match the claim voucher, so the server didn\'t record it. Don\'t claim again, and contact support.';

  @override
  String get miningRewards_signingSwitch13 =>
      'The wallet broadcast it, but the report didn\'t arrive. The transaction may be on-chain; you can report the same hash again. Don\'t claim again.';

  @override
  String get miningRewards_signingSwitch2 =>
      'Verification didn\'t pass. Nothing changed.';

  @override
  String get miningRewards_signingSwitch3 =>
      'The claim voucher expired. No transaction was submitted and your claimable balance is unchanged. Claim again.';

  @override
  String get miningRewards_signingSwitch4 =>
      'The transaction doesn\'t match what you confirmed, so signing was refused. No transaction was submitted.';

  @override
  String get miningRewards_signingSwitch5 =>
      'Couldn\'t find the wallet for this claim. No transaction was submitted.';

  @override
  String get miningRewards_signingSwitch6 =>
      'The voucher\'s wallet doesn\'t match the current wallet, so signing was refused. No transaction was submitted.';

  @override
  String get miningRewards_signingSwitch7 =>
      'Signing isn\'t allowed on this chain. No transaction was submitted.';

  @override
  String get miningRewards_signingSwitch8 =>
      'The wallet can\'t sign on this chain right now. No transaction was submitted.';

  @override
  String get miningRewards_signingSwitch9 =>
      'The signed-in wallet isn\'t the one for this claim. No transaction was submitted.';

  @override
  String get miningRewards_signingTitle => 'Confirm claim';

  @override
  String get miningRewards_signingValue => 'Claim mining rewards';

  @override
  String get miningRewards_signingValue2 => 'Paid with BNB in wallet';

  @override
  String get mining_controllersActivationRequired =>
      'Activate your LOOP ID before binding an invite code. You can bind any time after activation.';

  @override
  String get mining_controllersIdempotencyConflict =>
      'This binding was already submitted with a different invite code. Refresh to see the latest status.';

  @override
  String get mining_controllersNotFound =>
      'This invite code doesn\'t exist. Check with the person who invited you and try again; codes can\'t be guessed, so more attempts won\'t help.';

  @override
  String get mining_controllersPolicyBlocked =>
      'You can\'t bind an invite code right now. Each account can bind only once. Refresh to see the latest status.';

  @override
  String get mining_controllersStale =>
      'This account already has an inviter. It can\'t be changed after binding.';

  @override
  String get mining_controllersValidationFailed =>
      'This invite code can\'t be bound: you can\'t invite yourself or bind a code from someone you invited.';

  @override
  String mining_copyHead(Object? computedAtLabel) {
    return 'Showing the power snapshot from $computedAtLabel';
  }

  @override
  String get mining_copyIf =>
      'Block and time appear here after the next power snapshot.';

  @override
  String get mining_copyIf2 =>
      'The latest calculation didn\'t finish and there\'s no complete snapshot to fall back on.';

  @override
  String mining_copyIf3(Object? named, Object? rest) {
    return '$named, and $rest more assets';
  }

  @override
  String get mining_copyIncomplete =>
      'Reference prices for some assets couldn\'t be read this time';

  @override
  String get mining_copyMiningConditionEmbedded =>
      'Calculated from holdings in wallets linked to your LOOP account.';

  @override
  String get mining_copyMiningConditionMember =>
      'You must join the community; only the time you\'re a member counts. Tokens without a bound community don\'t require this.';

  @override
  String get mining_copyMiningConditionVerified =>
      'Community tokens count only when their bound community is approved; communities in review don\'t count.';

  @override
  String get mining_copyMiningConditionsShort =>
      'Calculated from linked wallet holdings. Community tokens require joining their approved community.';

  @override
  String get mining_copyMiningPowerFormulaHeading => 'Holdings × weight';

  @override
  String get mining_copyMiningSnapshotRowTitle => 'Latest power snapshot';

  @override
  String get mining_copyMiningSnapshotSectionLabel => 'Power snapshot';

  @override
  String get mining_copyMiningStaleLine =>
      'The latest snapshot was invalidated';

  @override
  String mining_copyS(Object? cause) {
    return 'The latest calculation didn\'t finish ($cause) and there\'s no complete snapshot to fall back on.';
  }

  @override
  String get mining_copyS2 => 'The latest snapshot didn\'t finish';

  @override
  String mining_copyStaleWithCause(Object? cause, Object? head, Object? tail) {
    return '$head · $tail ($cause)';
  }

  @override
  String get mining_copySwitch => 'No power snapshot has been taken yet';

  @override
  String get mining_copySwitch2 => 'No complete power snapshot yet';

  @override
  String get mining_copySwitch3 => 'Shown after the next power snapshot';

  @override
  String get mining_copySwitch4 => 'Power snapshot can\'t be loaded right now';

  @override
  String mining_copySwitch5(Object? label) {
    return '$label has no available quote right now';
  }

  @override
  String mining_copySwitch6(Object? label) {
    return '$label\'s reference price isn\'t recent enough';
  }

  @override
  String mining_copySwitch7(Object? label) {
    return '$label\'s reference price comes from an unregistered token';
  }

  @override
  String mining_copySwitch8(Object? label) {
    return '$label\'s reference price couldn\'t be read this time';
  }

  @override
  String get mining_copySwitch9 => 'That snapshot\'s data was incomplete';

  @override
  String get mining_modelsApproved => 'Approved';

  @override
  String get mining_modelsCommunities => 'Communities';

  @override
  String mining_modelsMiningAssetLabel(Object? chainName) {
    return '$chainName native token';
  }

  @override
  String get mining_modelsMiningBaselineDetail =>
      'Token power = amount held × asset weight, not multiplied by price; NFT power = amount held × community factor. Community tokens count only when their bound community is approved and you\'ve joined it. Calculated from holdings in wallets linked to your LOOP account. Current version: every asset\'s weight is 1, the daily output is an estimate, and the reward token isn\'t decided yet. These numbers aren\'t earnings or a promise.';

  @override
  String get mining_modelsMiningBaselineLabel => 'Current power formula';

  @override
  String get mining_modelsMiningReferralRankLabel => 'Invites';

  @override
  String get mining_modelsPendingApproval => 'Pending approval';

  @override
  String get mining_modelsRetired => 'Retired';

  @override
  String get mining_modelsS => 'Native token';

  @override
  String get mining_modelsSwitch => 'Power = holdings × weight';

  @override
  String get mining_modelsSwitch10 => 'Market stability';

  @override
  String get mining_modelsSwitch11 => 'User quality';

  @override
  String get mining_modelsSwitch12 => 'Depth of partnership with LOOP';

  @override
  String get mining_modelsSwitch13 =>
      'TWAP (time-weighted average price): keeps a single trade from skewing the reference price.';

  @override
  String get mining_modelsSwitch14 =>
      'Multi-period, multi-source comparison to cross-check unusual moves.';

  @override
  String get mining_modelsSwitch15 =>
      'Liquidity cap: limits the value counted for low-liquidity assets.';

  @override
  String get mining_modelsSwitch16 => 'Anonymous member';

  @override
  String get mining_modelsSwitch17 =>
      'Whether others see an alias or \"Anonymous member\" depends only on that account\'s anonymous mode; \"Discoverable\" isn\'t involved, and you always see your own alias.';

  @override
  String get mining_modelsSwitch18 =>
      'Power values follow that account\'s own \"Mining power\" visibility; when set to only me, others can\'t see the value, but rank and entry counts stay public.';

  @override
  String get mining_modelsSwitch19 => 'A rule item defined by LOOP.';

  @override
  String get mining_modelsSwitch2 =>
      'Power = holdings × reference price × weight';

  @override
  String get mining_modelsSwitch3 =>
      'Daily output = my power ÷ network power × daily output';

  @override
  String get mining_modelsSwitch4 =>
      'LOOP uses a fixed top weight tier (value pending approval).';

  @override
  String get mining_modelsSwitch5 =>
      'Community token weights are granted by review; the range is pending approval.';

  @override
  String get mining_modelsSwitch6 => 'Community quality';

  @override
  String get mining_modelsSwitch7 => 'Community size';

  @override
  String get mining_modelsSwitch8 => 'Token liquidity';

  @override
  String get mining_modelsSwitch9 => 'Project quality';

  @override
  String get mining_modelsUsers => 'Users';

  @override
  String get mining_referralAppliesMiningPower => 'mining power';

  @override
  String get mining_referralBarrierLabel => 'Close invite code binding';

  @override
  String get mining_referralBarrierLabel2 => 'Close invite poster';

  @override
  String get mining_referralBuild => 'Invite code';

  @override
  String get mining_referralBuild2 => 'Invite link';

  @override
  String get mining_referralBuild3 =>
      'Enter the invite code any time after signing up and mine together.';

  @override
  String get mining_referralBuild4 =>
      'Enter the invite code after signing up on LOOP';

  @override
  String get mining_referralBuild5 =>
      'Inviter bound. The relation is locked and can\'t be changed';

  @override
  String get mining_referralBuild6 =>
      'Each account can bind only once, and the relation can\'t be changed once locked. You can\'t bind your own code or a code from someone you invited.';

  @override
  String mining_referralDepthMax(Object? maximumDepth) {
    return ', up to L$maximumDepth';
  }

  @override
  String get mining_referralEmptyMessage => 'Couldn\'t load invite relations';

  @override
  String get mining_referralEmptyMessage2 => 'No invitations yet';

  @override
  String get mining_referralEmptyReason =>
      'Invite code and invite count can\'t be loaded right now.';

  @override
  String get mining_referralErrorText =>
      'Invalid invite code format. Check it and try again.';

  @override
  String mining_referralIf(Object? code) {
    return 'Mine with me on LOOP. Sign up and enter my invite code $code';
  }

  @override
  String get mining_referralInvitees => 'Invite list';

  @override
  String mining_referralLabel(Object? code) {
    return 'My invite code $code';
  }

  @override
  String get mining_referralLabelText => 'Invite code (like LOOP-XXXXX)';

  @override
  String get mining_referralLoopLabel => 'My inviter';

  @override
  String mining_referralLoopRecordRow(num shown) {
    String _temp0 = intl.Intl.pluralLogic(
      shown,
      locale: localeName,
      other: '$shown active members',
      one: '1 active member',
    );
    return '$_temp0';
  }

  @override
  String get mining_referralLoopSheetHeading => 'Invite poster';

  @override
  String mining_referralMessage(Object? code) {
    return 'This account already has an inviter, so $code from the invite link won\'t be bound';
  }

  @override
  String mining_referralMessage2(Object? code) {
    return 'This account can\'t bind an invite code right now, so $code from the invite link wasn\'t submitted';
  }

  @override
  String get mining_referralMessage3 => 'Invite code bound';

  @override
  String get mining_referralMessage4 =>
      'The share sheet didn\'t open. Copy the link instead';

  @override
  String get mining_referralModelsInvalid => 'Invalid';

  @override
  String get mining_referralModelsInvalidated => 'Invalidated';

  @override
  String get mining_referralModelsPending => 'Pending';

  @override
  String get mining_referralModelsPendingActivation => 'Pending activation';

  @override
  String get mining_referralModelsPendingMining => 'Pending mining';

  @override
  String get mining_referralModelsPendingWallet => 'Pending wallet link';

  @override
  String get mining_referralModelsSwitch =>
      'People I invited directly and verified';

  @override
  String get mining_referralModelsSwitch2 => 'People my L1 invited';

  @override
  String get mining_referralModelsSwitch3 => 'People my L2 invited';

  @override
  String get mining_referralModelsSwitch4 => 'People my L3 invited';

  @override
  String get mining_referralModelsSwitch5 => 'People my L4 invited';

  @override
  String get mining_referralModelsSwitch6 => 'Invite relation level';

  @override
  String get mining_referralModelsValid => 'Active';

  @override
  String mining_referralOverviewCounts(Object? pending, Object? valid) {
    return '\n$valid active · $pending pending verification.';
  }

  @override
  String get mining_referralReferralBoostTotalTitle => 'Total boost';

  @override
  String mining_referralReferralBoundRowSubtitle(
    Object? depth,
    Object? launchTimestampLabel,
    Object? referralValidationStatusLabel,
  ) {
    return 'Depth L$depth · $referralValidationStatusLabel · locked $launchTimestampLabel';
  }

  @override
  String get mining_referralReferralBoundRowTitle => 'Inviter bound';

  @override
  String get mining_referralReferralCapabilityInlineMessage =>
      'Invite relations aren\'t available right now';

  @override
  String get mining_referralReferralClaimFailureTitle =>
      'This binding didn\'t finish';

  @override
  String get mining_referralReferralClaimShapeInvalidBody =>
      'An invite code is LOOP- followed by 5 characters. Clearly invalid codes aren\'t submitted, so your one binding isn\'t wasted.';

  @override
  String get mining_referralReferralClaimShapeInvalidTitle =>
      'Invalid invite code format';

  @override
  String get mining_referralReferralClaimSubmitLabel => 'Bind';

  @override
  String get mining_referralReferralClaimSuccessBody =>
      'This relation is confirmed. It can\'t be changed after binding.';

  @override
  String get mining_referralReferralClaimSuccessTitle => 'Relation locked';

  @override
  String get mining_referralReferralClaimWindowTimed =>
      'You can\'t bind an invite code right now. Refresh and try again later';

  @override
  String mining_referralReferralClaimWindowUnavailable(
    Object? launchReasonCodeText,
  ) {
    return 'Can\'t bind yet: $launchReasonCodeText';
  }

  @override
  String get mining_referralReferralCopyCodeLabel => 'Copy invite code';

  @override
  String get mining_referralReferralCopyCodeMessage => 'Invite code copied';

  @override
  String get mining_referralReferralCopyLinkLabel => 'Copy invite link';

  @override
  String get mining_referralReferralCopyLinkMessage => 'Invite link copied';

  @override
  String get mining_referralReferralInfoBindingBody =>
      'Invitees can bind any time after activating their LOOP ID; each account can bind only once, and the relation can\'t be changed once locked. You can\'t bind your own code or a code from someone you invited.';

  @override
  String get mining_referralReferralInfoBindingTitle => 'Bind invite code';

  @override
  String mining_referralReferralInfoDepthBody(Object? rules) {
    return 'People you invite directly and who are verified are L1, people L1 invites are L2, and so on$rules. Each level\'s boost rate follows what the server publishes and counts only that level\'s active relations.';
  }

  @override
  String get mining_referralReferralInfoDepthTitle => 'How depth is counted';

  @override
  String get mining_referralReferralInfoMiningOnlyBody =>
      'Invite boost counts only toward mining power. It isn\'t income, commission or a rebate.';

  @override
  String get mining_referralReferralInfoMiningOnlyTitle =>
      'Counts only toward mining power';

  @override
  String mining_referralReferralInfoRelationshipBody(Object? overview) {
    return 'Each account has one invite code. Sharing doesn\'t create a relation until it\'s verified; \"Active\" counts only verified relations, and the rest show as pending verification and add no boost.$overview';
  }

  @override
  String get mining_referralReferralInfoRelationshipTitle =>
      'How a relation is formed';

  @override
  String mining_referralReferralInfoRulesBody(
    Object? launchTimestampLabel,
    Object? maximumDepth,
    Object? rules,
  ) {
    return 'Effective $launchTimestampLabel · max depth L$maximumDepth · applies to $rules';
  }

  @override
  String get mining_referralReferralInfoRulesTitle => 'Rule version';

  @override
  String mining_referralReferralInfoValidMemberBody(Object? stats) {
    return 'An invitee is an active member only if they had power in the latest settled hour.$stats';
  }

  @override
  String get mining_referralReferralInfoValidMemberTitle => 'Active members';

  @override
  String mining_referralReferralInviteLinkLabel(Object? link) {
    return 'Invite link $link';
  }

  @override
  String get mining_referralReferralPosterLabel => 'Create poster';

  @override
  String mining_referralReferralPosterLabel2(Object? code) {
    return 'LOOP invite poster, invite code $code';
  }

  @override
  String get mining_referralReferralPosterNoLink =>
      'Invite links aren\'t open yet, so the poster shows only the invite code.';

  @override
  String get mining_referralReferralPosterQrSemanticLabel =>
      'Invite link QR code';

  @override
  String get mining_referralReferralPosterShareLabel => 'Creating…';

  @override
  String get mining_referralReferralPosterShareLabel2 => 'Save or share poster';

  @override
  String get mining_referralReferralShareLinkLabel => 'Share link';

  @override
  String get mining_referralRow => 'Hidden member';

  @override
  String mining_referralS(Object? code, Object? link) {
    return 'Mine with me on LOOP. Sign up and enter my invite code $code\n$link';
  }

  @override
  String get mining_referralS2 => 'Scan to open the invite page';

  @override
  String mining_referralSemanticLabel(
    Object? launchTimestampLabel,
    Object? name,
    Object? referralInviteeStatusLabel,
  ) {
    return '$name, joined $launchTimestampLabel, $referralInviteeStatusLabel';
  }

  @override
  String get mining_referralSubject => 'Join me on LOOP';

  @override
  String mining_referralSubtitle(Object? powerFigure, Object? powerFigure2) {
    return 'NFT $powerFigure · Assets $powerFigure2';
  }

  @override
  String mining_referralSubtitle2(Object? launchTimestampLabel) {
    return 'Joined $launchTimestampLabel';
  }

  @override
  String mining_referralTitle(Object? boostPercent, Object? level) {
    return 'L$level · Boost $boostPercent%';
  }

  @override
  String mining_referralValidAsOf(Object? time) {
    return '\nFigures as of $time.';
  }

  @override
  String get mining_referralValidNoHour =>
      '\nNo settled hour yet, so active members are 0 for now.';

  @override
  String get mining_screenCell => 'Token power';

  @override
  String get mining_screenCell2 => 'NFT power';

  @override
  String get mining_screenCell3 => 'Token power · Last hour';

  @override
  String get mining_screenCell4 => 'NFT power · Last hour';

  @override
  String get mining_screenClaimSemanticLabel =>
      'Claim rewards, open rewards and claims';

  @override
  String get mining_screenEmptyLine => 'No power snapshot yet';

  @override
  String get mining_screenEmptyMessage => 'No power data yet';

  @override
  String get mining_screenEmptyMessage2 => 'No power breakdown yet';

  @override
  String get mining_screenEmptyTitle => 'No NFT power yet';

  @override
  String get mining_screenHeading => 'Loading';

  @override
  String get mining_screenKicker => 'Total power';

  @override
  String get mining_screenLabel => 'Total mined';

  @override
  String get mining_screenLabel2 => 'Claimable';

  @override
  String get mining_screenLabel3 => 'Last hour power';

  @override
  String get mining_screenLabel4 => 'Active invites';

  @override
  String get mining_screenLabel5 => 'Today\'s estimate';

  @override
  String get mining_screenLoopInfoNote => 'No power snapshot loaded yet.';

  @override
  String get mining_screenLoopInfoNote2 =>
      'LOOP doesn\'t accumulate points or estimate earnings on this device. Not loaded doesn\'t mean \"zero power\".';

  @override
  String get mining_screenMiningCapabilityUnavailableLabel =>
      'Mining isn\'t available right now';

  @override
  String get mining_screenMiningCompositionNftUnavailableMessage =>
      'NFT power isn\'t provided separately yet';

  @override
  String get mining_screenMiningFormulaEffective =>
      'LOOP doesn\'t accumulate points or estimate earnings on this device. Every number on this page comes from the latest power snapshot.';

  @override
  String mining_screenMiningInfoConditionsBody(
    Object? miningConditionEmbedded,
    Object? miningConditionMember,
    Object? miningConditionVerified,
  ) {
    return 'Token power = amount held × asset weight, not multiplied by price; NFTs use their community factor.\n$miningConditionVerified\n$miningConditionMember\n$miningConditionEmbedded';
  }

  @override
  String get mining_screenMiningInfoConditionsTitle =>
      'Which holdings count toward power';

  @override
  String get mining_screenMiningInfoFormulaTitle => 'Formula version';

  @override
  String get mining_screenMiningInfoOpenRulesLabel => 'View mining rules';

  @override
  String get mining_screenMiningInfoTruthTitle => 'No local estimates';

  @override
  String get mining_screenMiningInviteInfoTitle => 'About invites';

  @override
  String get mining_screenMiningRulesActionTitle => 'About mining';

  @override
  String mining_screenMiningSnapshotComputed(
    Object? groupedFigure,
    Object? launchTimestampLabel,
  ) {
    return 'Block $groupedFigure · $launchTimestampLabel · when power was calculated';
  }

  @override
  String mining_screenMiningSnapshotComputed2(
    Object? launchTimestampLabel,
    Object? stale,
  ) {
    return 'Snapshot · $launchTimestampLabel$stale';
  }

  @override
  String mining_screenParenthetical(Object? text) {
    return ' ($text)';
  }

  @override
  String get mining_screenS => 'No token power yet';

  @override
  String get mining_screenSpoken => 'Not loaded yet';

  @override
  String get mining_screenSpoken2 => 'No settled hour yet';

  @override
  String get mining_screenSwitch =>
      'Mining summary not loaded yet. The formula version appears here once loaded.';

  @override
  String mining_screenSwitch2(Object? launchReasonCodeText) {
    return 'No approved mining formula version: $launchReasonCodeText';
  }

  @override
  String get mining_screenSwitch3 =>
      'Mining formula pending approval. Numbers on this page have a source only after approval.';

  @override
  String get mining_screenSwitch4 => 'Formula version pending approval';

  @override
  String mining_screenSwitch5(Object? launchTimestampLabel, Object? scope) {
    return 'Mining formula in effect$scope · effective $launchTimestampLabel';
  }

  @override
  String get mining_screenSwitch6 => 'Formula version in effect';

  @override
  String mining_screenValue(num invites) {
    String _temp0 = intl.Intl.pluralLogic(
      invites,
      locale: localeName,
      other: '$invites people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get mining_secondaryScreensCell => 'My power';

  @override
  String get mining_secondaryScreensEmptyMessage =>
      'Couldn\'t load this community';

  @override
  String get mining_secondaryScreensEmptyMessage2 => 'Couldn\'t load rules';

  @override
  String get mining_secondaryScreensEmptyReason =>
      'The community may not exist or isn\'t visible to this account.';

  @override
  String get mining_secondaryScreensEmptyReason2 =>
      'Formula version can\'t be loaded right now.';

  @override
  String get mining_secondaryScreensHeading => 'Weights and power rules';

  @override
  String get mining_secondaryScreensIf => 'Daily output';

  @override
  String get mining_secondaryScreensKicker => 'Power rules';

  @override
  String mining_secondaryScreensLabel(
    Object? spokenContribution,
    Object? spokenWeight,
  ) {
    return 'My power, $spokenContribution. Community weight, $spokenWeight';
  }

  @override
  String get mining_secondaryScreensLabel2 => 'Approved formula version';

  @override
  String get mining_secondaryScreensLoopFolioPrimary =>
      'No approved formula and no draft pending approval.';

  @override
  String get mining_secondaryScreensLoopFolioPrimary2 =>
      'No approved formula yet. The one below is a draft pending approval.';

  @override
  String get mining_secondaryScreensLoopFolioPrimary3 =>
      'This version is approved and in effect; no draft pending approval.';

  @override
  String get mining_secondaryScreensLoopFolioPrimary4 =>
      'This version is approved and in effect. A draft pending approval is below.';

  @override
  String get mining_secondaryScreensLoopLabel => 'My contribution';

  @override
  String get mining_secondaryScreensLoopLabel2 => 'Community record';

  @override
  String get mining_secondaryScreensLoopLabel3 => 'Community weight';

  @override
  String get mining_secondaryScreensLoopLabel4 => 'Bound assets';

  @override
  String get mining_secondaryScreensLoopLabel5 => 'Approved version';

  @override
  String get mining_secondaryScreensLoopLabel6 => 'Version pending approval';

  @override
  String get mining_secondaryScreensLoopLabel7 => 'Invite relation rules';

  @override
  String get mining_secondaryScreensLoopLabel8 => 'Asset weights';

  @override
  String get mining_secondaryScreensLoopProvenanceLine => 'LOOP mining rules';

  @override
  String get mining_secondaryScreensMiningCommunityAssetRowSubtitle =>
      'This community has no bound assets yet';

  @override
  String get mining_secondaryScreensMiningCommunityAssetRowTrailing => 'Bound';

  @override
  String get mining_secondaryScreensMiningCommunityLogoKicker =>
      'Community power';

  @override
  String get mining_secondaryScreensMiningCommunityMetricParticipantsTitle =>
      'Holders mining';

  @override
  String get mining_secondaryScreensMiningCommunityMetricPowerTitle =>
      'Community total power';

  @override
  String get mining_secondaryScreensMiningCommunityNoticeBody =>
      'Weights come from review; the review factors are public, the exact scores aren\'t. Communities that aren\'t approved have no weight and no power. Holders must join the community for their holdings to count.';

  @override
  String get mining_secondaryScreensMiningCommunityNoticeTitle =>
      'Weights are set by platform review';

  @override
  String get mining_secondaryScreensMiningCommunityRankActionLabel =>
      'View leaderboard';

  @override
  String get mining_secondaryScreensMiningCommunityReadingLabel =>
      'Community rank';

  @override
  String get mining_secondaryScreensMiningCommunityReadingTrailingLabel =>
      'Participants';

  @override
  String get mining_secondaryScreensMiningCommunityScreenTitle =>
      'Community mining';

  @override
  String get mining_secondaryScreensMiningCommunityWeightNotApplicableMessage =>
      'No weight to review';

  @override
  String get mining_secondaryScreensMiningCommunityWeightPendingMessage =>
      'Weight in review';

  @override
  String mining_secondaryScreensMiningCommunityWeightRowSubtitle(
    Object? launchTimestampLabel,
  ) {
    return 'Reviewed $launchTimestampLabel';
  }

  @override
  String get mining_secondaryScreensMiningCommunityWeightRowTitle =>
      'Weight granted';

  @override
  String mining_secondaryScreensMiningCommunityWeightVersion(
    Object? identifier,
  ) {
    return 'Formula version in effect $identifier';
  }

  @override
  String get mining_secondaryScreensMiningFigureValue =>
      'Sum of members\' power on bound assets';

  @override
  String get mining_secondaryScreensMiningParticipantsCount =>
      'Members with power in the latest power snapshot';

  @override
  String get mining_secondaryScreensMiningRulesNoPendingMessage =>
      'No draft version right now.';

  @override
  String get mining_secondaryScreensMiningRulesNoPendingTitle =>
      'No version pending approval';

  @override
  String get mining_secondaryScreensMiningRulesNoticeBody =>
      'Versions pending approval aren\'t used in any calculation. Weight ranges list rule items only, with no values; values are published after approval.';

  @override
  String get mining_secondaryScreensMiningRulesNoticeTitle =>
      'Drafts aren\'t rules in effect';

  @override
  String get mining_secondaryScreensMiningRulesOpenReferralLabel =>
      'View my invite relations';

  @override
  String mining_secondaryScreensMiningRulesReferralLSubtitle(
    Object? launchTimestampLabel,
  ) {
    return 'Effective $launchTimestampLabel';
  }

  @override
  String get mining_secondaryScreensMiningRulesScreenTitle => 'Mining rules';

  @override
  String get mining_secondaryScreensSubtitle =>
      'Invite boost counts only toward power';

  @override
  String get mining_secondaryScreensSwitch =>
      'Sum of members\' power on bound assets, weights included.';

  @override
  String get mining_secondaryScreensSwitch2 =>
      'Community total power appears here once loaded.';

  @override
  String get mining_secondaryScreensSwitch3 =>
      'This page hasn\'t loaded this community\'s power yet.';

  @override
  String get mining_secondaryScreensSwitch4 =>
      'Weights are granted by platform review and are already included in the power above.';

  @override
  String mining_secondaryScreensSwitch5(Object? launchTimestampLabel) {
    return 'Approved $launchTimestampLabel';
  }

  @override
  String get mining_secondaryScreensText => 'Daily output ';

  @override
  String get mining_secondaryScreensText2 =>
      'Exact scores aren\'t public; weights follow the platform\'s overall review.';

  @override
  String mining_secondaryScreensTitle(Object? subject) {
    return '$subject isn\'t available right now';
  }

  @override
  String get mining_secondaryScreensTitle2 => 'Power formula';

  @override
  String get mining_secondaryScreensTitle3 => 'Invite boost';

  @override
  String get mining_secondaryScreensTitle4 => 'Reviewed community tokens';

  @override
  String get mining_secondaryScreensTrailingCaption =>
      'Published after the LOOP token launches';

  @override
  String get mining_secondaryScreensTrailingCaption2 => 'Estimated output';

  @override
  String get mining_secondaryScreensTrailingCaption3 => 'Daily output';

  @override
  String mining_widgetsLoopRecordRow(Object? amountFigure) {
    return 'Holding $amountFigure';
  }

  @override
  String mining_widgetsLoopRecordRow4(Object? powerFigure) {
    return 'NFT power $powerFigure';
  }

  @override
  String get mining_widgetsMarker => 'Not updated';

  @override
  String mining_widgetsMiningCompositionExpression(
    Object? amountFigure,
    Object? weight,
  ) {
    return '$amountFigure × weight $weight';
  }

  @override
  String get mining_widgetsMiningDemoHoldingsDetail =>
      'This power includes demo holdings: they aren\'t on-chain, nobody actually holds them, and the numbers are for trying things out.';

  @override
  String get mining_widgetsMiningFormulaRowSemanticLabel =>
      'Mining formula not decided yet';

  @override
  String get mining_widgetsMiningFormulaRowSemanticLabel2 =>
      'Mining formula pending approval';

  @override
  String get mining_widgetsMiningFormulaRowSemanticLabel3 =>
      'Mining formula in effect';

  @override
  String get mining_widgetsMiningFormulaRowSubtitle =>
      'The numbers above have a source only after approval.';

  @override
  String mining_widgetsMiningFormulaRowSubtitle2(Object? launchTimestampLabel) {
    return 'In effect · $launchTimestampLabel';
  }

  @override
  String get mining_widgetsMiningFormulaRowTitle => 'Mining formula';

  @override
  String get mining_widgetsMiningFormulaRowTrailing => 'In effect';

  @override
  String get mining_widgetsMiningNetworkKicker => 'Network power · Last hour';

  @override
  String get mining_widgetsMiningNetworkKicker2 => 'Network power';

  @override
  String mining_widgetsMiningNetworkRankActionLabel2(Object? place) {
    return 'Power Ranking, my rank $place';
  }

  @override
  String mining_widgetsMiningNetworkTotalLabel(Object? spoken) {
    return 'Network power, $spoken';
  }

  @override
  String get mining_widgetsMiningSummaryHeroAssetsLabel => 'Power details';

  @override
  String get mining_widgetsMiningSummaryHeroClaimLabel => 'Mining rewards';

  @override
  String get mining_widgetsMiningSummaryHeroClaimLabel2 => 'Claim rewards';

  @override
  String get mining_widgetsMiningSummaryHeroClaimSemanticLabel =>
      'Mining rewards, open the mining rewards page';

  @override
  String get mining_widgetsText => 'My total power';

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
  String get profileAbout_clientRegisterLoopAboutUnknownModuleName =>
      'Other rules';

  @override
  String get profileAbout_clientRegisterPurpose => 'App framework and runtime';

  @override
  String get profileAbout_clientRegisterPurpose10 => 'Push channel';

  @override
  String get profileAbout_clientRegisterPurpose11 =>
      'Local storage for device and session records';

  @override
  String get profileAbout_clientRegisterPurpose12 =>
      'Non-sensitive local display preferences';

  @override
  String get profileAbout_clientRegisterPurpose13 =>
      'Network reachability checks';

  @override
  String get profileAbout_clientRegisterPurpose14 => 'Vector icon rendering';

  @override
  String get profileAbout_clientRegisterPurpose15 => 'System share';

  @override
  String get profileAbout_clientRegisterPurpose16 =>
      'Open campaign links in the system browser';

  @override
  String get profileAbout_clientRegisterPurpose17 =>
      'Locally generated unique IDs';

  @override
  String get profileAbout_clientRegisterPurpose18 => 'iOS-style icon font';

  @override
  String get profileAbout_clientRegisterPurpose19 => 'Interface fonts';

  @override
  String get profileAbout_clientRegisterPurpose2 => 'Network requests';

  @override
  String get profileAbout_clientRegisterPurpose3 =>
      'Exact decimal math for amounts and prices';

  @override
  String get profileAbout_clientRegisterPurpose4 => 'State management';

  @override
  String get profileAbout_clientRegisterPurpose5 => 'Page routing';

  @override
  String get profileAbout_clientRegisterPurpose6 =>
      'Sign-in and built-in wallet';

  @override
  String get profileAbout_clientRegisterPurpose7 =>
      'External wallet connection and signing credentials';

  @override
  String get profileAbout_clientRegisterPurpose8 => 'Community chat';

  @override
  String get profileAbout_clientRegisterPurpose9 => 'Local chat cache';

  @override
  String get profileAbout_clientRegisterSwitch => 'Product policy';

  @override
  String get profileAbout_clientRegisterSwitch10 => 'On-chain write rules';

  @override
  String get profileAbout_clientRegisterSwitch11 =>
      'Version of the five tabs, default landing page and overall product rules';

  @override
  String get profileAbout_clientRegisterSwitch12 =>
      'Operator overrides for this client\'s version, region and terms requirements';

  @override
  String get profileAbout_clientRegisterSwitch13 =>
      'How device sessions are created, limited and revoked';

  @override
  String get profileAbout_clientRegisterSwitch14 =>
      'Rules for community creation, members, roles and governance';

  @override
  String get profileAbout_clientRegisterSwitch15 =>
      'How Market trending is ranked';

  @override
  String get profileAbout_clientRegisterSwitch16 =>
      'Thresholds for new-device alerts';

  @override
  String get profileAbout_clientRegisterSwitch17 =>
      'Which account settings can be changed';

  @override
  String get profileAbout_clientRegisterSwitch18 =>
      'Ticket categories, length and response times';

  @override
  String get profileAbout_clientRegisterSwitch19 =>
      'Swap quote, slippage and fee rules';

  @override
  String get profileAbout_clientRegisterSwitch2 => 'Client policy';

  @override
  String get profileAbout_clientRegisterSwitch20 =>
      'Asset scope and per-transaction limit for on-chain write rollout';

  @override
  String get profileAbout_clientRegisterSwitch3 => 'Sign-in session rules';

  @override
  String get profileAbout_clientRegisterSwitch4 => 'Community rules';

  @override
  String get profileAbout_clientRegisterSwitch5 => 'Market trending rules';

  @override
  String get profileAbout_clientRegisterSwitch6 => 'Device risk alert rules';

  @override
  String get profileAbout_clientRegisterSwitch7 => 'Account settings rules';

  @override
  String get profileAbout_clientRegisterSwitch8 => 'Support ticket rules';

  @override
  String get profileAbout_clientRegisterSwitch9 => 'Swap rules';

  @override
  String get profileAbout_networkDiagnosticsAboutBackendHostSubtitle =>
      'No server address in the build config';

  @override
  String profileAbout_networkDiagnosticsAboutBackendHostSubtitle2(
    Object? backendTier,
  ) {
    return '$backendTier · From this build\'s config';
  }

  @override
  String get profileAbout_networkDiagnosticsAboutBackendHostTitle => 'Server';

  @override
  String profileAbout_networkDiagnosticsAboutBuildModeSubtitle(
    Object? config,
    Object? declaredMode,
    Object? runtimeBuildMode,
  ) {
    return 'Declared $declaredMode · Runtime $runtimeBuildMode · $config';
  }

  @override
  String get profileAbout_networkDiagnosticsAboutBuildModeTitle => 'Build mode';

  @override
  String profileAbout_networkDiagnosticsBuildMode(
    Object? declared,
    Object? runtimeBuildMode,
  ) {
    return 'Declared $declared · Runtime $runtimeBuildMode';
  }

  @override
  String get profileAbout_networkDiagnosticsBuildRows => 'Not declared';

  @override
  String get profileAbout_networkDiagnosticsControllerReason =>
      'No address configured in this build, not checked';

  @override
  String profileAbout_networkDiagnosticsDone(Object? okCount, Object? sent) {
    return '$okCount of $sent reachable';
  }

  @override
  String get profileAbout_networkDiagnosticsDone2 => 'Run again';

  @override
  String profileAbout_networkDiagnosticsHostTier(Object? host, Object? tier) {
    return '$host ($tier)';
  }

  @override
  String get profileAbout_networkDiagnosticsIdle => 'Start diagnosis';

  @override
  String get profileAbout_networkDiagnosticsLoopLabel => 'Checks';

  @override
  String get profileAbout_networkDiagnosticsLoopLabel2 => 'Results';

  @override
  String get profileAbout_networkDiagnosticsMessage => 'Diagnosis copied';

  @override
  String get profileAbout_networkDiagnosticsMessage2 =>
      'Can\'t open share. Copy instead';

  @override
  String get profileAbout_networkDiagnosticsModeMatch => 'match';

  @override
  String get profileAbout_networkDiagnosticsModeMismatch => 'mismatch';

  @override
  String get profileAbout_networkDiagnosticsModelsBlocked =>
      'Not sent: the address doesn\'t meet this device\'s network rules';

  @override
  String get profileAbout_networkDiagnosticsModelsConnect =>
      'Can\'t connect: connection refused or interrupted';

  @override
  String get profileAbout_networkDiagnosticsModelsDns =>
      'Can\'t connect: DNS lookup failed';

  @override
  String get profileAbout_networkDiagnosticsModelsIdle => 'Not started';

  @override
  String get profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport =>
      'LOOP network diagnosis';

  @override
  String profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport2(
    Object? networkDiagnosticsTimestamp,
  ) {
    return 'Time: $networkDiagnosticsTimestamp';
  }

  @override
  String profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport3(
    Object? appVersion,
  ) {
    return 'App version: $appVersion';
  }

  @override
  String profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport4(
    Object? buildMode,
  ) {
    return 'Build mode: $buildMode';
  }

  @override
  String profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport5(
    Object? serverHost,
  ) {
    return 'Server host: $serverHost';
  }

  @override
  String profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport6(
    Object? platform,
  ) {
    return 'Platform: $platform';
  }

  @override
  String profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport7(
    Object? inMilliseconds,
  ) {
    return 'Total time: $inMilliseconds ms';
  }

  @override
  String profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport8(
    Object? okCount,
    Object? results,
  ) {
    return 'Results: $okCount of $results reachable';
  }

  @override
  String get profileAbout_networkDiagnosticsModelsOther => 'Can\'t connect';

  @override
  String get profileAbout_networkDiagnosticsModelsReachable => 'Reachable';

  @override
  String profileAbout_networkDiagnosticsModelsReason(
    Object? reused,
    Object? statusCode,
  ) {
    return 'Connected, but the service returned HTTP $statusCode$reused';
  }

  @override
  String profileAbout_networkDiagnosticsModelsReason2(
    Object? bytesText,
    Object? statusCode,
  ) {
    return 'HTTP $statusCode · Image $bytesText';
  }

  @override
  String profileAbout_networkDiagnosticsModelsReason3(Object? statusCode) {
    return 'Connected, but no image received · HTTP $statusCode';
  }

  @override
  String profileAbout_networkDiagnosticsModelsReason4(
    Object? block,
    Object? statusCode,
  ) {
    return 'HTTP $statusCode · Block $block';
  }

  @override
  String get profileAbout_networkDiagnosticsModelsRunning => 'Checking';

  @override
  String profileAbout_networkDiagnosticsModelsS(Object? inMilliseconds) {
    return ' · First $inMilliseconds ms, connection reused';
  }

  @override
  String get profileAbout_networkDiagnosticsModelsTimeout => 'Timed out';

  @override
  String get profileAbout_networkDiagnosticsModelsTimeout2 =>
      'Timed out, no response in time';

  @override
  String get profileAbout_networkDiagnosticsModelsTls =>
      'Can\'t connect: secure handshake failed';

  @override
  String get profileAbout_networkDiagnosticsNetworkDiagnosticsCopyLabel =>
      'Copy results';

  @override
  String get profileAbout_networkDiagnosticsNetworkDiagnosticsFolioCaption =>
      'This page only tests connectivity and timing. No account info is sent.';

  @override
  String get profileAbout_networkDiagnosticsNetworkDiagnosticsFolioKicker =>
      'Network check';

  @override
  String profileAbout_networkDiagnosticsNetworkDiagnosticsFolioStamp(
    Object? state,
  ) {
    return 'Total ${state}s';
  }

  @override
  String get profileAbout_networkDiagnosticsNetworkDiagnosticsOfflineBody =>
      'Make sure this device is online, then run again.';

  @override
  String get profileAbout_networkDiagnosticsNetworkDiagnosticsOfflineTitle =>
      'No check could connect';

  @override
  String get profileAbout_networkDiagnosticsNetworkDiagnosticsPrivacyText =>
      'Results stay on this device and aren\'t uploaded. Copying or sharing is up to you.';

  @override
  String get profileAbout_networkDiagnosticsNetworkDiagnosticsPrivacyTitle =>
      'Where results go';

  @override
  String get profileAbout_networkDiagnosticsRunning => 'Diagnosing';

  @override
  String get profileAbout_networkDiagnosticsRunning2 => 'Diagnosing';

  @override
  String get profileAbout_networkDiagnosticsText =>
      'Each check times out after 8 seconds. All run at once, 15 seconds at most.';

  @override
  String get profileAbout_networkDiagnosticsTitle => 'About the checks';

  @override
  String get profileAbout_screenAboutClientBuildNoteLabel =>
      'LOOP doesn\'t publish client versions';

  @override
  String get profileAbout_screenAboutClientVersionSubtitle =>
      'No valid version in the build config; none is made up here';

  @override
  String get profileAbout_screenAboutClientVersionSubtitle2 =>
      'From this device\'s build config, not uploaded';

  @override
  String get profileAbout_screenAboutClientVersionTitle => 'Client version';

  @override
  String get profileAbout_screenAboutConfigNoteText =>
      'For viewing only. No version is pinned.';

  @override
  String get profileAbout_screenAboutNetworkDiagnosticsSubtitle =>
      'Test connectivity and timing from this device to each service';

  @override
  String get profileAbout_screenAboutNetworkDiagnosticsTitle =>
      'Network diagnosis';

  @override
  String get profileAbout_screenAboutOpenSourceInfo => 'Open-source licenses';

  @override
  String get profileAbout_screenAboutOpenSourceInfoTitle =>
      'Open-source components in this app';

  @override
  String get profileAbout_screenAboutOpenSourceNoteBody =>
      'Component versions follow this build\'s lockfile; this page doesn\'t show version numbers.';

  @override
  String get profileAbout_screenAboutOpenSourceSummaryBody =>
      'Below are the open-source components the LOOP mobile client depends on directly, with their licenses; exact versions are recorded in this build\'s lockfile. Components used by the LOOP server aren\'t on this page.';

  @override
  String get profileAbout_screenAboutRiskNoticeBody =>
      'Crypto asset prices are highly volatile, and you may lose all your principal. LOOP is a non-custodial tool, gives no investment advice and isn\'t responsible for any trade outcome. Mining output depends on network-wide power competition and isn\'t a promise of returns.';

  @override
  String get profileAbout_screenAboutRiskNoticeTitle => 'Crypto asset risk';

  @override
  String get profileAbout_screenAboutTermsUnavailableLabel =>
      'No document links for the Terms of Service, Privacy Policy and risk disclosure';

  @override
  String get profileAbout_screenAboutTermsVersionSubtitle =>
      'A version exists, but there\'s no document link to open yet.';

  @override
  String get profileAbout_screenAboutTermsVersionTitle => 'Terms version';

  @override
  String get profileAbout_screenEmptyMessage =>
      'Can\'t read product records right now';

  @override
  String get profileAbout_screenLoopLabel => 'Legal';

  @override
  String get profileAbout_screenLoopLabel2 => 'Risk notice';

  @override
  String get profileAbout_screenLoopLabel3 => 'This build';

  @override
  String get profileAbout_screenLoopLabel4 => 'Current rules';

  @override
  String profileAbout_screenLoopRecordRow(Object? number) {
    return 'Version $number';
  }

  @override
  String profileAbout_screenLoopRecordRow2(Object? relativeTime) {
    return 'In effect $relativeTime';
  }

  @override
  String get profileNotificationPreferences_screenBody =>
      'That doesn\'t mean delivery works yet.';

  @override
  String get profileNotificationPreferences_screenBody2 =>
      'You\'ll be asked once your account is ready.';

  @override
  String get profileNotificationPreferences_screenBody3 =>
      'You can turn it on here once your account is in LOOP.';

  @override
  String get profileNotificationPreferences_screenBody4 =>
      'Notifications stay in the in-app notification list.';

  @override
  String get profileNotificationPreferences_screenBody5 =>
      'Turn notifications back on for LOOP in system settings.';

  @override
  String get profileNotificationPreferences_screenBody6 =>
      'This device registers automatically once it has one.';

  @override
  String get profileNotificationPreferences_screenBody7 =>
      'It\'ll try again next time you open LOOP.';

  @override
  String get profileNotificationPreferences_screenCategoryRow =>
      'Not in effect yet';

  @override
  String get profileNotificationPreferences_screenEmptyMessage =>
      'No notification settings yet';

  @override
  String get profileNotificationPreferences_screenLaunchRound =>
      'Once off, you won\'t get consensus badge, launch review or on-chain progress notifications.';

  @override
  String get profileNotificationPreferences_screenLoopOfflineState =>
      'Save notification settings';

  @override
  String get profileNotificationPreferences_screenMessage =>
      'Notification settings saved';

  @override
  String
  get profileNotificationPreferences_screenNotificationCapabilityBlockTitle =>
      'Notification settings aren\'t available right now';

  @override
  String profileNotificationPreferences_screenNotificationDisableTitle(
    Object? label,
  ) {
    return 'Turn off \"$label\" notifications?';
  }

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesConflictBody =>
      'Notification settings changed on another device. Reload before editing.';

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesConflictTitle =>
      'Version conflict. Nothing was overwritten';

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesErrorTitle =>
      'Settings not saved';

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesPushChannelBody =>
      'Push hasn\'t been confirmed on a real device yet. Switches still save and still affect the in-app notification list.';

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesPushOptInBody =>
      'New messages, price alerts and security events are pushed to this device. Tap Turn on and the system asks once.';

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesPushOptInButtonLabel =>
      'Turn on';

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesPushOptInTitle =>
      'Turn on push notifications';

  @override
  String
  profileNotificationPreferences_screenNotificationPreferencesSummaryBody(
    Object? deliveringEnabledCount,
  ) {
    return '$deliveringEnabledCount on and in effect. Only price alerts create in-app notifications for now; security events are always on.';
  }

  @override
  String
  get profileNotificationPreferences_screenNotificationPreferencesVersionText =>
      'Using default settings';

  @override
  String
  profileNotificationPreferences_screenNotificationPreferencesVersionText2(
    Object? relativeTime,
  ) {
    return 'Updated $relativeTime';
  }

  @override
  String
  get profileNotificationPreferences_screenNotificationPushUnavailableLabel =>
      'Push isn\'t available yet';

  @override
  String get profileNotificationPreferences_screenS => 'Off';

  @override
  String get profileNotificationPreferences_screenSwitch =>
      'Once off, you won\'t get this type of notification.';

  @override
  String get profileNotificationPreferences_screenTitle =>
      'This device is registered for push';

  @override
  String get profileNotificationPreferences_screenTitle2 =>
      'Notification permission hasn\'t been requested on this device';

  @override
  String get profileNotificationPreferences_screenTitle3 =>
      'No push channel on this device';

  @override
  String get profileNotificationPreferences_screenTitle4 =>
      'Notification permission denied; this device can\'t get push';

  @override
  String get profileNotificationPreferences_screenTitle5 =>
      'Waiting for the system to assign a push channel';

  @override
  String get profileNotificationPreferences_screenTitle6 =>
      'This device isn\'t registered yet';

  @override
  String get profileNotificationPreferences_screenTitle7 =>
      'This account can\'t change notification settings';

  @override
  String get profilePresentation_avatarEditorAvatarCropConfirmLabel =>
      'Processing…';

  @override
  String get profilePresentation_avatarEditorAvatarCropConfirmLabel2 =>
      'Use this one';

  @override
  String get profilePresentation_avatarEditorBuild =>
      'Drag and pinch to zoom. What\'s inside the frame is your avatar.';

  @override
  String get profilePresentation_avatarEditorLoopAvatarResetLabel =>
      'Use default avatar';

  @override
  String get profilePresentation_avatarEditorLoopAvatarUploadLabel =>
      'Upload avatar';

  @override
  String get profilePresentation_avatarEditorLoopAvatarUploadUnavailable =>
      'Avatar upload isn\'t open yet. Use the default for now.';

  @override
  String get profilePresentation_avatarEditorLoopSheetHeading => 'Crop avatar';

  @override
  String get profilePresentation_avatarMediaInvalidData =>
      'Couldn\'t confirm the upload. Your avatar wasn\'t changed.';

  @override
  String get profilePresentation_avatarMediaOffline =>
      'No network connection. Your avatar wasn\'t uploaded.';

  @override
  String get profilePresentation_avatarMediaRateLimited =>
      'Too many uploads. Try again in a minute.';

  @override
  String get profilePresentation_avatarMediaRejected =>
      'This image can\'t be used: it must be JPG, PNG, WebP or HEIC, up to 5 MB, at least 64 pixels per side.';

  @override
  String get profilePresentation_avatarMediaUnavailable =>
      'Avatar upload isn\'t available right now. Use the default for now.';

  @override
  String get profilePresentation_avatarMediaUnexpected =>
      'Avatar upload failed. Try again.';

  @override
  String get profilePrivacy_modelsCommunities => 'Joined communities';

  @override
  String get profilePrivacy_modelsDirectMessages => 'Let friends message me';

  @override
  String get profilePrivacy_modelsFriendRequests =>
      'Let strangers send friend requests';

  @override
  String get profilePrivacy_modelsGroupInvites =>
      'Let friends add me to groups';

  @override
  String get profilePrivacy_modelsMiningPower => 'Mining power';

  @override
  String get profilePrivacy_modelsTotalAssets => 'Total assets';

  @override
  String get profilePrivacy_modelsTradeHistory => 'Trade history';

  @override
  String get profileSecurity_modelsAutoRecovery => 'Automatic recovery';

  @override
  String get profileSecurity_modelsAutoRecovery2 =>
      'Recovery shares held by the provider.';

  @override
  String get profileSecurity_modelsKeyExport => 'Export private key';

  @override
  String get profileSecurity_modelsKeyExport2 =>
      'Take your private key with you, free of LOOP or Privy.';

  @override
  String get profileSecurity_modelsMfa => 'Multi-factor authentication';

  @override
  String get profileSecurity_modelsMfa2 =>
      'Sign-in and sensitive actions need a second factor.';

  @override
  String get profileSecurity_modelsPasskey =>
      'Use device biometrics instead of a password.';

  @override
  String get profileSecurity_modelsProviderAuthenticated => 'Verified by Privy';

  @override
  String get profileSecurity_modelsRecoveryPassword => 'Recovery password';

  @override
  String get profileSecurity_modelsRecoveryPassword2 =>
      'A passphrase you keep, used to recover your wallet on a new device.';

  @override
  String get profileSecurity_modelsSocialRecovery => 'Social recovery';

  @override
  String get profileSecurity_modelsSocialRecovery2 =>
      'Recovery needs 2 of 3 guardians to confirm.';

  @override
  String get profileSecurity_screensBody =>
      'ERC-20 approvals still active on this wallet.';

  @override
  String get profileSecurity_screensBody2 =>
      'Approvals with no limit carry the highest risk.';

  @override
  String get profileSecurity_screensDeviceRevokeConfirmLabel =>
      'Revoke session';

  @override
  String get profileSecurity_screensDeviceRevokeSheetEffectBody =>
      'LOOP marks this session as revoked, rejects later requests that carry it, and records a security event. The Privy sign-in on that device isn\'t ended.';

  @override
  String get profileSecurity_screensDeviceRevokeSheetEffectTitle =>
      'What happens after revoking';

  @override
  String profileSecurity_screensDeviceRow(Object? relativeTime) {
    return 'Revoked $relativeTime';
  }

  @override
  String get profileSecurity_screensDeviceRow2 => 'In use';

  @override
  String get profileSecurity_screensDevicesCapabilityBlockTitle =>
      'Device management isn\'t available right now';

  @override
  String get profileSecurity_screensDevicesCurrentUnknownBody =>
      'This device has no usable session ID, so no row in the list is marked as this session or this device.';

  @override
  String get profileSecurity_screensDevicesCurrentUnknownTitle =>
      'Can\'t mark this session';

  @override
  String get profileSecurity_screensDevicesEffectNoticeBody =>
      'Revoking marks the session as revoked and makes LOOP reject later requests that carry it. It doesn\'t end the Privy sign-in on that device, so don\'t read it as that device being signed out. To sign out here, use Sign out in Settings.';

  @override
  String get profileSecurity_screensDevicesEffectNoticeTitle =>
      'What revoking does';

  @override
  String get profileSecurity_screensDevicesFolioCaption =>
      'Device names and locations aren\'t shown here, only platform, version, session ID and sign-in time.';

  @override
  String profileSecurity_screensDevicesFolioHeading(
    Object? activeCount,
    Object? deviceCount,
  ) {
    return '$deviceCount devices · $activeCount sessions';
  }

  @override
  String get profileSecurity_screensDevicesFolioKicker => 'Device sessions';

  @override
  String profileSecurity_screensDevicesHighRiskNoticeBody(
    Object? newSessionThreshold,
    Object? newSessions24h,
    Object? windowHours,
  ) {
    return '$newSessions24h sessions were created in the last $windowHours hours, reaching the alert threshold of $newSessionThreshold. This is only an alert; it doesn\'t require two-step verification.';
  }

  @override
  String get profileSecurity_screensDevicesRevokeAllLabel =>
      'Sign out all other devices';

  @override
  String get profileSecurity_screensDevicesRevokeAllUnavailableLabel =>
      'Needs two-step verification, not available now';

  @override
  String profileSecurity_screensDevicesRevokeOutcomeBody(
    Object? providerAccessTerminated,
  ) {
    return 'LOOP marked the session as revoked and rejects later requests that carry it. The Privy access token on that device isn\'t affected (providerAccessTerminated: $providerAccessTerminated).';
  }

  @override
  String get profileSecurity_screensDevicesScreenTitle => 'Devices';

  @override
  String get profileSecurity_screensDevicesStateEmptyMessage =>
      'This account hasn\'t set up a device yet.';

  @override
  String get profileSecurity_screensDevicesStateEmptyTitle =>
      'No device sessions yet';

  @override
  String get profileSecurity_screensDevicesTruncatedBody =>
      'Up to 100 sessions are shown; paging isn\'t available yet.';

  @override
  String get profileSecurity_screensDevicesTruncatedTitle => 'List truncated';

  @override
  String get profileSecurity_screensEmptyMessage =>
      'No security features to show';

  @override
  String get profileSecurity_screensEmptyMessage2 => 'No security summary yet';

  @override
  String get profileSecurity_screensEmptyMessage3 =>
      'No device sessions to show';

  @override
  String get profileSecurity_screensEmptyMessage4 =>
      'Can\'t read export status';

  @override
  String get profileSecurity_screensEmptyMessage5 =>
      'Can\'t read social recovery status';

  @override
  String profileSecurity_screensEventSourceSuffix(Object? source) {
    return ' · Source $source';
  }

  @override
  String profileSecurity_screensIdentity(
    Object? sessionCreatedAtLabel,
    Object? sessionShortId,
  ) {
    return 'Session $sessionShortId · First sign-in $sessionCreatedAtLabel';
  }

  @override
  String get profileSecurity_screensIf =>
      'The sign-in service says this account already has a passkey';

  @override
  String get profileSecurity_screensKeyExportActionLabel => 'Verify and export';

  @override
  String get profileSecurity_screensKeyExportCapabilityBlockTitle =>
      'Private key export isn\'t available right now';

  @override
  String get profileSecurity_screensKeyExportControlDisclosureSummary =>
      'Control notes';

  @override
  String get profileSecurity_screensKeyExportFolioCaption =>
      'Before export: read the risks, verify your identity and confirm local display.';

  @override
  String get profileSecurity_screensKeyExportFolioHeading =>
      'You control your private key';

  @override
  String get profileSecurity_screensKeyExportFolioKicker => 'Wallet key';

  @override
  String get profileSecurity_screensKeyExportFolioStamp => 'Sensitive';

  @override
  String get profileSecurity_screensKeyExportNoKeySubtitle =>
      'This page never renders a masked key sample; that would make it look like a key was already exported.';

  @override
  String get profileSecurity_screensKeyExportNoKeyTitle =>
      'No private key is shown';

  @override
  String get profileSecurity_screensKeyExportNoVerificationSubtitle =>
      'No Face ID, no code: verification only matters when export is actually possible.';

  @override
  String get profileSecurity_screensKeyExportNoVerificationTitle =>
      'You won\'t be asked to verify';

  @override
  String get profileSecurity_screensKeyExportRiskBody =>
      'A leaked private key means losing all your assets. Don\'t screenshot it, send it to anyone or keep it in online notes. No one can recover stolen assets for you.';

  @override
  String get profileSecurity_screensKeyExportRiskTitle =>
      'Exporting moves all responsibility to you';

  @override
  String get profileSecurity_screensLabel => 'Platform';

  @override
  String get profileSecurity_screensLabel2 => 'Client version';

  @override
  String get profileSecurity_screensLabel3 => 'First sign-in';

  @override
  String get profileSecurity_screensLabel4 => 'Belongs to';

  @override
  String get profileSecurity_screensLabel5 => 'Last active';

  @override
  String get profileSecurity_screensListSeparator => ', ';

  @override
  String get profileSecurity_screensLoopBadge => 'Unreadable';

  @override
  String get profileSecurity_screensLoopBadge2 => 'This session';

  @override
  String get profileSecurity_screensLoopBadge3 => 'Revoked';

  @override
  String get profileSecurity_screensLoopBadge4 => 'Old session';

  @override
  String get profileSecurity_screensLoopBadge5 => 'Other device';

  @override
  String get profileSecurity_screensLoopLabel => 'Verification';

  @override
  String get profileSecurity_screensLoopLabel2 => 'Transaction verification';

  @override
  String get profileSecurity_screensLoopLabel3 => 'Devices';

  @override
  String get profileSecurity_screensLoopLabel4 => 'Recent security events';

  @override
  String get profileSecurity_screensLoopLabel5 => 'Session';

  @override
  String get profileSecurity_screensLoopLabel6 => 'All devices';

  @override
  String get profileSecurity_screensLoopLabel7 =>
      'What won\'t happen at this step';

  @override
  String get profileSecurity_screensLoopLabel8 => 'Guardians';

  @override
  String profileSecurity_screensLoopRecordRow(Object? sessionShortId) {
    return 'Session $sessionShortId';
  }

  @override
  String get profileSecurity_screensLoopRecordRow2 =>
      'Old session on this device';

  @override
  String get profileSecurity_screensLoopSheetHeading => 'Revoke this session?';

  @override
  String get profileSecurity_screensMessage =>
      'Revocation recorded; access on that device isn\'t ended';

  @override
  String get profileSecurity_screensMessage2 => 'Revocation didn\'t finish';

  @override
  String get profileSecurity_screensPlatformUnlabeled => 'Platform not labeled';

  @override
  String profileSecurity_screensS(Object? relativeTime) {
    return 'Last active $relativeTime';
  }

  @override
  String get profileSecurity_screensS2 => 'Active';

  @override
  String get profileSecurity_screensScopeNote =>
      'Multi-factor authentication, passkeys, recovery and export are provided by Privy and will show here once open.';

  @override
  String get profileSecurity_screensScopeNote2 =>
      'These protections are provided by Privy.';

  @override
  String profileSecurity_screensScopeNote3(Object? notOpen) {
    return 'These protections are provided by Privy. $notOpen will show here once open.';
  }

  @override
  String get profileSecurity_screensSecurityApprovalsActiveTitle =>
      'Active approvals';

  @override
  String profileSecurity_screensSecurityApprovalsFreshnessText(
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? groupedFigure3,
    Object? relativeTime,
  ) {
    return 'Approvals from block $groupedFigure · Indexed $groupedFigure2 / Head $groupedFigure3 · Seen $relativeTime';
  }

  @override
  String get profileSecurity_screensSecurityApprovalsUnavailableLabel =>
      'Can\'t read token approvals';

  @override
  String get profileSecurity_screensSecurityApprovalsUnlimitedTitle =>
      'Unlimited approvals';

  @override
  String get profileSecurity_screensSecurityCapabilityBlockTitle =>
      'Security Center isn\'t available right now';

  @override
  String profileSecurity_screensSecurityDevicesEntrySubtitle(
    Object? recent,
    Object? sessions,
    Object? windowHours,
  ) {
    return '$sessions active sessions · $recent new in the last $windowHours hours';
  }

  @override
  String get profileSecurity_screensSecurityDevicesEntryTitle =>
      'Signed-in devices';

  @override
  String get profileSecurity_screensSecurityDevicesUnavailableLabel =>
      'Can\'t read devices and sessions';

  @override
  String get profileSecurity_screensSecurityEventsEmptyMessage =>
      'For now, only \"Sign out other devices\" records a security event.';

  @override
  String get profileSecurity_screensSecurityEventsEmptyTitle =>
      'No security events yet';

  @override
  String get profileSecurity_screensSecurityEventsUnavailableLabel =>
      'Can\'t read recent security events';

  @override
  String profileSecurity_screensSecurityHighRiskNoticeBody(
    Object? newSessionThreshold,
    Object? recent,
    Object? windowHours,
  ) {
    return '$recent sessions were created in the last $windowHours hours, reaching the alert threshold of $newSessionThreshold. This is only an alert; it doesn\'t require two-step verification or a cooldown.';
  }

  @override
  String get profileSecurity_screensSecurityHighRiskNoticeTitle =>
      'Several new sessions recently';

  @override
  String get profileSecurity_screensSecurityMethodDefaultLabel =>
      'Default method';

  @override
  String get profileSecurity_screensSecurityMethodDeferredLabel =>
      'Not open yet';

  @override
  String get profileSecurity_screensSecurityMethodOffLabel => 'Off';

  @override
  String get profileSecurity_screensSecurityMethodsGuideSummary =>
      'How to turn these on';

  @override
  String get profileSecurity_screensSecurityNotificationLockSubtitle =>
      'Always on, can\'t be turned off';

  @override
  String get profileSecurity_screensSecurityNotificationLockTitle =>
      'Security event notifications';

  @override
  String profileSecurity_screensSecurityObservedAtText(Object? relativeTime) {
    return 'Seen $relativeTime';
  }

  @override
  String get profileSecurity_screensSecurityScopeInfoTitle =>
      'Who provides these protections';

  @override
  String profileSecurity_screensSemanticLabel(Object? label, Object? reason) {
    return '$label, unavailable, $reason';
  }

  @override
  String profileSecurity_screensSemanticLabel2(Object? label) {
    return '$label, reading the sign-in service\'s answer';
  }

  @override
  String profileSecurity_screensSemanticLabel3(Object? label, Object? reason) {
    return '$label, unreadable, $reason Tap to retry';
  }

  @override
  String profileSecurity_screensSemanticLabel4(Object? label, Object? label2) {
    return '$label, $label2. Tap to turn on';
  }

  @override
  String profileSecurity_screensSemanticLabelDetail(
    Object? detail,
    Object? label,
    Object? state,
  ) {
    return '$label, $state: $detail';
  }

  @override
  String get profileSecurity_screensSocialRecoveryActionLabel => 'Add guardian';

  @override
  String get profileSecurity_screensSocialRecoveryCapabilityBlockTitle =>
      'Social recovery isn\'t available right now';

  @override
  String get profileSecurity_screensSocialRecoveryDisclosureSummary =>
      'Social recovery status notes';

  @override
  String get profileSecurity_screensSocialRecoveryExplainerBody =>
      'Pick 3 people you trust. If you lose your device, any 2 of them can help you recover your account. Guardians must confirm in their own app; unconfirmed ones don\'t count toward 2-of-3.';

  @override
  String get profileSecurity_screensSocialRecoveryExplainerTitle =>
      'What 2-of-3 means';

  @override
  String get profileSecurity_screensSocialRecoveryFolioCaption =>
      'Guardians only confirm recovery. They can\'t see your assets or start transactions.';

  @override
  String get profileSecurity_screensSocialRecoveryFolioHeading =>
      '2-of-3 guardians';

  @override
  String get profileSecurity_screensSocialRecoveryFolioStamp => '2 of 3';

  @override
  String get profileSecurity_screensSocialRecoveryNoGuardiansDetail =>
      'Guardians aren\'t open yet, so no one is listed here.';

  @override
  String get profileSecurity_screensSocialRecoveryNoGuardiansMessage =>
      'No guardians yet';

  @override
  String profileSecurity_screensSubtitle(Object? reason) {
    return '$reason Tap to retry.';
  }

  @override
  String get profileSecurity_screensText =>
      'Export asks for Face ID, MFA and a risk confirmation, and blocks screenshots and screen recording during export. This page never pre-renders a private key sample: a masked string would read as \"already exported\".';

  @override
  String get profileSecurity_screensText2 =>
      'You invite guardians, and they must confirm in their own app; unconfirmed ones don\'t count toward 2-of-3. Guardians can\'t see your assets or start transactions.';

  @override
  String get profileSecurity_screensTitle => 'Recovery';

  @override
  String get profileSecurity_screensTitle2 => 'Revoked a device session';

  @override
  String get profileSecurity_screensTitle3 => 'Security event';

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
  String get profileSupport_modelsAccount => 'Account';

  @override
  String get profileSupport_modelsAnswered => 'Answered';

  @override
  String get profileSupport_modelsAnswered2 => 'Support reply';

  @override
  String get profileSupport_modelsClosed => 'Closed';

  @override
  String get profileSupport_modelsEmpty => 'Describe the problem first.';

  @override
  String get profileSupport_modelsOpen => 'Open';

  @override
  String get profileSupport_modelsOperator => 'LOOP Support';

  @override
  String get profileSupport_modelsOther => 'Other';

  @override
  String get profileSupport_modelsTooLong =>
      'The message is over 2,000 code points. Shorten it and submit again.';

  @override
  String get profileSupport_modelsUnsafeCharacters =>
      'The message has control or invisible characters (such as line breaks or direction marks). Remove them and submit again.';

  @override
  String get profileSupport_modelsUser => 'You';

  @override
  String get profileSupport_modelsWallet => 'Wallet';

  @override
  String get profileSupport_screenBarrierLabel => 'Close ticket details';

  @override
  String get profileSupport_screenEmptyMessage => 'No tickets yet';

  @override
  String get profileSupport_screenHint =>
      'Describe the problem. Never enter a private key, recovery phrase or code';

  @override
  String get profileSupport_screenLoopLabel => 'Contact us';

  @override
  String get profileSupport_screenLoopLabel2 => 'FAQ';

  @override
  String get profileSupport_screenLoopLabel3 => 'Submit a ticket';

  @override
  String get profileSupport_screenLoopLabel4 => 'My tickets';

  @override
  String get profileSupport_screenLoopLabel5 => 'Conversation';

  @override
  String get profileSupport_screenMessage => 'Ticket submitted';

  @override
  String get profileSupport_screenMessage2 => 'Ticket not submitted';

  @override
  String profileSupport_screenSemanticLabel(Object? label, Object? label2) {
    return '$label ticket, $label2. Open full conversation';
  }

  @override
  String profileSupport_screenSubtitle(Object? relativeTime) {
    return 'Submitted $relativeTime · No reply yet';
  }

  @override
  String profileSupport_screenSubtitle2(Object? note) {
    return 'Support reply: $note';
  }

  @override
  String get profileSupport_screenSupportAttachmentsUnavailableLabel =>
      'Attachments aren\'t supported yet';

  @override
  String profileSupport_screenSupportBodyFootnote(
    Object? length,
    Object? maximumBodyLength,
    Object? problem,
  ) {
    return '$length / $maximumBodyLength code points$problem';
  }

  @override
  String get profileSupport_screenSupportBodyLabel => 'Description';

  @override
  String get profileSupport_screenSupportCapabilityBlockLabel =>
      'Support tickets aren\'t available right now';

  @override
  String profileSupport_screenSupportEscalationText(
    Object? responseWindowHours,
  ) {
    return 'Replies within $responseWindowHours hours. For urgent issues, say so in the ticket.';
  }

  @override
  String profileSupport_screenSupportEscalationTextBusinessDays(
    Object? responseWindowHours,
  ) {
    return 'Replies within $responseWindowHours hours on business days. For urgent issues, say so in the ticket.';
  }

  @override
  String get profileSupport_screenSupportEscalationTitle => 'Response time';

  @override
  String get profileSupport_screenSupportMoreTicketsBody =>
      'Only the latest page is shown; older tickets can\'t be viewed yet.';

  @override
  String get profileSupport_screenSupportMoreTicketsTitle =>
      'There are older tickets';

  @override
  String get profileSupport_screenSupportOpenCommunityTitle =>
      'LOOP official community';

  @override
  String get profileSupport_screenSupportScamNoticeBody =>
      'Anyone who asks for your private key, recovery phrase or code in a DM is a scammer. Report them.';

  @override
  String get profileSupport_screenSupportScamNoticeTitle =>
      'We never DM you first';

  @override
  String get profileSupport_screenSupportScreenTitle => 'Help and support';

  @override
  String get profileSupport_screenSupportTicketDetailOpenText =>
      'Support hasn\'t replied to this ticket yet; replies will show above.';

  @override
  String get profileSupport_screenSupportTicketsEmptyMessage =>
      'After you submit, status and replies show here.';

  @override
  String get profileSupport_screenText => 'How is power calculated';

  @override
  String get profileSupport_screenText10 =>
      'A Launch asset that hasn\'t graduated can only be bought, and only through its own channel. A rejection comes with a specific error code, shown as-is on the trade page.';

  @override
  String get profileSupport_screenText2 =>
      'Power comes from the latest power snapshot: each registered asset\'s holding times its weight, not its price, listed line by line in the power breakdown. It counts holdings in wallets linked to your LOOP account; a community token counts only when it\'s bound to an approved community. The Mining page shows that snapshot\'s block and time.';

  @override
  String get profileSupport_screenText3 => 'Why does my token have no weight';

  @override
  String get profileSupport_screenText4 =>
      'Only registered assets count toward mining. Registration follows LOOP\'s registry, not whether a token has appeared in your wallet. Tokens bound to communities under review have no weight.';

  @override
  String get profileSupport_screenText5 => 'How do I join a Launch';

  @override
  String get profileSupport_screenText6 =>
      'Launch rounds, snapshots and limits are set by contract parameters. Until they\'re confirmed, the Launch page only shows existing round status and promises no allocation.';

  @override
  String get profileSupport_screenText7 =>
      'How do I recover my account on a new phone';

  @override
  String get profileSupport_screenText8 =>
      'Your account identity is held by Privy. Passkeys and multi-factor authentication can be turned on in Security Center, and automatic recovery is the default method; social recovery and private key export aren\'t open yet. Security Center shows the current status of each.';

  @override
  String get profileSupport_screenText9 =>
      'Why was my bonding pool buy rejected';

  @override
  String profile_meAttentionStreamChatMessageRequestsEntrySemanticLabel(
    Object? label,
  ) {
    return 'Message requests, $label pending';
  }

  @override
  String profile_meAttentionStreamChatMessageRequestsEntryTrailing(
    Object? label,
  ) {
    return '$label pending';
  }

  @override
  String get profile_screensAliasBlocked =>
      'That name has a word that isn\'t allowed. Try another.';

  @override
  String get profile_screensAliasReserved =>
      'That name is reserved by LOOP. Try another.';

  @override
  String get profile_screensBootstrapRequired =>
      'Your account isn\'t set up yet. Try again later.';

  @override
  String get profile_screensHint =>
      '1–40 characters, doesn\'t have to be unique';

  @override
  String get profile_screensHint2 => 'A line about yourself (optional)';

  @override
  String get profile_screensIdempotencyConflict =>
      'Submission conflict. Reset; try again.';

  @override
  String get profile_screensInvalidData =>
      'The service returned a profile that doesn\'t match the contract. Nothing was applied.';

  @override
  String get profile_screensInvalidData2 =>
      'The service returned privacy settings that don\'t match the contract. Nothing was applied.';

  @override
  String profile_screensJoinedLine(Object? month, Object? year) {
    return 'Joined $month $year';
  }

  @override
  String get profile_screensLabel => 'Reload';

  @override
  String get profile_screensLoopLabel => 'Privacy and security';

  @override
  String get profile_screensLoopLabel2 => 'Review notifications';

  @override
  String get profile_screensLoopLabel3 => 'Identity';

  @override
  String get profile_screensLoopLabel4 => 'Social';

  @override
  String get profile_screensLoopLabel5 => 'Visibility';

  @override
  String get profile_screensLoopOfflineState => 'Save profile';

  @override
  String get profile_screensLoopOfflineState2 => 'Activate LOOP ID';

  @override
  String get profile_screensLoopOfflineState3 => 'Save privacy settings';

  @override
  String profile_screensLoopPreviewModeNoticeBody(Object? resource) {
    return '$resource is kept only in memory for this run. It isn\'t written to your account and calls no provider.';
  }

  @override
  String get profile_screensLoopSoftUpdateDismissLabel =>
      'Dismiss update prompt';

  @override
  String get profile_screensLoopSoftUpdatePromptBody =>
      'Update to the latest version. This version still works.';

  @override
  String profile_screensLoopSoftUpdatePromptBody2(Object? minimum) {
    return 'Update to $minimum or later. This version still works.';
  }

  @override
  String get profile_screensLoopSoftUpdatePromptTitle =>
      'New version available';

  @override
  String get profile_screensMeCommunitiesEmptyTitle =>
      'No communities joined yet';

  @override
  String get profile_screensMeCommunitiesUnavailableMessage =>
      'Communities aren\'t available right now';

  @override
  String get profile_screensMeGroupLabel => 'Joined';

  @override
  String get profile_screensMeGroupLabel2 => 'Created';

  @override
  String get profile_screensMeJoinedAllTitle => 'All joined communities';

  @override
  String profile_screensMembers(Object? groupedFigure) {
    return '$groupedFigure members';
  }

  @override
  String get profile_screensMessage =>
      'Go back to Me and pick another setting.';

  @override
  String get profile_screensMessage2 => 'Profile hasn\'t loaded yet';

  @override
  String profile_screensMessage3(Object? version) {
    return 'Submitted as version $version';
  }

  @override
  String get profile_screensOffLabel => 'Off';

  @override
  String get profile_screensOffline =>
      'This device is offline. Your profile couldn\'t load, and no changes were submitted.';

  @override
  String get profile_screensOffline2 =>
      'This device is offline. Privacy settings couldn\'t load, and no changes were submitted.';

  @override
  String get profile_screensPermissionDenied =>
      'Current policy doesn\'t allow reading or changing your profile. Nothing changed. This permission can\'t be changed in the app.';

  @override
  String get profile_screensPermissionDenied2 =>
      'Current policy doesn\'t allow reading or changing privacy settings. Nothing changed. This permission can\'t be changed in the app; the switches follow LOOP\'s records.';

  @override
  String get profile_screensPrivacyAnonymousModeSubtitle =>
      'Show only your alias, never your wallet address';

  @override
  String get profile_screensPrivacyAnonymousModeTitle => 'Anonymous mode';

  @override
  String get profile_screensPrivacyConflictTitle =>
      'Privacy settings changed elsewhere';

  @override
  String get profile_screensPrivacyDiscoverableSubtitle =>
      'Others can find you by nickname; your LOOP ID is always searchable exactly';

  @override
  String get profile_screensPrivacyDiscoverableSubtitle2 =>
      'Others can\'t find you by nickname; your LOOP ID is always searchable exactly';

  @override
  String get profile_screensPrivacyDiscoverableTitle => 'Discoverable';

  @override
  String get profile_screensPrivacyEmptyMessage =>
      'Privacy preferences haven\'t loaded yet.';

  @override
  String get profile_screensPrivacyEmptyTitle => 'No privacy settings to show';

  @override
  String get profile_screensPrivacyErrorSource => 'Privacy service';

  @override
  String get profile_screensPrivacyPermissionTitle =>
      'Privacy settings can\'t be read or changed in your region';

  @override
  String get profile_screensPrivacyPermissionTitle2 =>
      'This account can\'t read or change privacy settings';

  @override
  String get profile_screensPrivacyPublicHoldingsOffLabel => 'Only me';

  @override
  String get profile_screensPrivacyPublicHoldingsOnLabel => 'Everyone';

  @override
  String get profile_screensPrivacyPublicHoldingsSubtitle =>
      'Others see your holdings and trades on your profile, never your wallet address';

  @override
  String get profile_screensPrivacyPublicHoldingsSubtitle2 =>
      'Only you can see your holdings and trades';

  @override
  String get profile_screensPrivacyPublicHoldingsTitle =>
      'Public holdings and trades';

  @override
  String get profile_screensPrivacySavePermissionTitle =>
      'Privacy settings can\'t be changed in your region';

  @override
  String get profile_screensPrivacySavePermissionTitle2 =>
      'This account can\'t change privacy settings';

  @override
  String get profile_screensPrivacySubtitle => 'Holdings and trades are public';

  @override
  String get profile_screensPrivacyUnavailableTitle =>
      'Privacy settings aren\'t available right now';

  @override
  String get profile_screensPrivacyVisibilityNoteText =>
      'Visibility only affects what\'s shown. It doesn\'t let anyone copy your trades or access your wallet. Your avatar and username always show in chats and on your profile; your wallet address never appears on your profile.';

  @override
  String get profile_screensPrivacyVisibilityNoteTitle => 'About visibility';

  @override
  String get profile_screensProfileAddBioLabel => 'Add a bio';

  @override
  String get profile_screensProfileAlias => 'No alias yet';

  @override
  String get profile_screensProfileAvailabilityBannerBody =>
      'Reloading profile status.';

  @override
  String get profile_screensProfileAvailabilityBannerTitle =>
      'Can\'t read profile status right now';

  @override
  String get profile_screensProfileAvailabilityBrowseSuffix =>
      ' You can keep browsing.';

  @override
  String get profile_screensProfileAvailabilityDismissLabel =>
      'Hide profile status notice';

  @override
  String get profile_screensProfileAvailabilityRetryLabel => 'Retrying…';

  @override
  String get profile_screensProfileAvailabilityRetryLabel2 =>
      'Reload profile status';

  @override
  String get profile_screensProfileAvailabilityRetryableSuffix =>
      ' You can keep browsing or retry now.';

  @override
  String get profile_screensProfileEditAliasLabel => 'Username';

  @override
  String get profile_screensProfileEditAliasSuggestLabel => 'Try another';

  @override
  String get profile_screensProfileEditBioLabel => 'Bio';

  @override
  String get profile_screensProfileEditConflictTitle =>
      'Profile changed elsewhere';

  @override
  String get profile_screensProfileEditFailureTitle => 'Save didn\'t finish';

  @override
  String get profile_screensProfileEditOpenPrivacySubtitle =>
      'Whether holdings and trades are public, who can add you';

  @override
  String get profile_screensProfileEditPermissionTitle =>
      'Your profile can\'t be changed in your region';

  @override
  String get profile_screensProfileEditPermissionTitle2 =>
      'This account can\'t change its profile';

  @override
  String get profile_screensProfileEditSaveLabel => 'Saving…';

  @override
  String get profile_screensProfileEditSaveTitle => 'Edit profile';

  @override
  String get profile_screensProfileEditValidationTitle => 'Can\'t save';

  @override
  String get profile_screensProfileEmptyMessage =>
      'Account profile hasn\'t loaded yet.';

  @override
  String get profile_screensProfileEmptyTitle => 'No profile to show';

  @override
  String get profile_screensProfileErrorSource => 'Profile service';

  @override
  String get profile_screensProfileLoopId => 'LOOP ID unreadable';

  @override
  String get profile_screensProfileOpenEditLabel => 'Edit avatar and profile';

  @override
  String get profile_screensProfileOpenPrivacyTitle => 'Privacy Center';

  @override
  String get profile_screensProfilePermissionTitle =>
      'This step needs two-step verification';

  @override
  String get profile_screensProfilePermissionTitle2 =>
      'Your profile can\'t be read or changed in your region';

  @override
  String get profile_screensProfilePermissionTitle3 =>
      'This account can\'t read or change its profile';

  @override
  String get profile_screensProfileShareLoopIdLabel => 'Share card';

  @override
  String get profile_screensProfileUnavailableTitle =>
      'Profile isn\'t available right now';

  @override
  String get profile_screensRegionBlocked =>
      'Your profile can\'t be read or changed in your region right now. Nothing changed. This isn\'t about your account; switching accounts won\'t change it.';

  @override
  String get profile_screensRegionBlocked2 =>
      'Privacy settings can\'t be read or changed in your region right now. Nothing changed. This isn\'t about your account; switching accounts won\'t change it.';

  @override
  String get profile_screensResource => 'Privacy settings';

  @override
  String get profile_screensS => 'Holdings and trades visible only to you';

  @override
  String get profile_screensS2 => 'Strangers can\'t send you friend requests';

  @override
  String get profile_screensS3 =>
      'When off, friends can\'t open a direct message with you either';

  @override
  String get profile_screensS4 =>
      'When off, friends can\'t add you to small groups';

  @override
  String get profile_screensSemanticLabel => 'Avatar';

  @override
  String get profile_screensStepUpRequired =>
      'This step needs two-step verification, which isn\'t open yet. Nothing changed. Check Security Center for the verification methods available now.';

  @override
  String get profile_screensStepUpRequired2 =>
      'Changing privacy settings needs two-step verification, which isn\'t open yet. Nothing changed. Check Security Center for the verification methods available now.';

  @override
  String get profile_screensSwitch => 'The profile action didn\'t finish.';

  @override
  String get profile_screensSwitch2 => 'The privacy action didn\'t finish.';

  @override
  String get profile_screensSwitch3 => 'Anyone with your LOOP ID can add you';

  @override
  String get profile_screensSwitch4 =>
      'Friends can open a direct message with you';

  @override
  String get profile_screensSwitch5 => 'Friends can add you to small groups';

  @override
  String get profile_screensText => '+ Add a bio';

  @override
  String get profile_screensTitle => 'Nothing was changed';

  @override
  String get profile_screensUnavailable =>
      'The profile service isn\'t available right now. No changes were saved.';

  @override
  String get profile_screensUnavailable2 =>
      'The privacy service isn\'t available right now. No changes were saved.';

  @override
  String get profile_screensUnexpected =>
      'The profile action didn\'t finish. Try again later.';

  @override
  String get profile_screensUnexpected2 =>
      'The privacy action didn\'t finish. Try again later.';

  @override
  String get profile_screensUnknownProfileSurfaceTitle => 'Setting unavailable';

  @override
  String get profile_screensValidationFailed =>
      'Alias or bio is too long. Edit it and try again.';

  @override
  String get profile_screensValidationFailed2 =>
      'The submitted privacy settings weren\'t accepted. Check them and try again.';

  @override
  String get profile_screensValidationMessage =>
      'Alias must be 1–40 characters with no invisible characters.';

  @override
  String get profile_screensValidationMessage2 =>
      'Bio can be up to 160 characters.';

  @override
  String get profile_screensVersionConflict =>
      'Your profile was changed elsewhere. Reload before saving.';

  @override
  String get profile_screensVersionConflict2 =>
      'Privacy settings were changed elsewhere. Reload before saving.';

  @override
  String get profile_signOutButtonConfirmLabel => 'Sign out';

  @override
  String get profile_signOutButtonLabel => 'Signing out…';

  @override
  String get profile_signOutButtonLoopSignOutConfirmBody =>
      'This device will stop getting notifications for this account, and the home screen data saved here will be cleared. Assets, friends and conversations in your account aren\'t affected; sign in again to get them back.';

  @override
  String get profile_signOutButtonLoopSignOutConfirmTitle => 'Sign out?';

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
  String get socialPublicProfile_controllerAlreadyFriends =>
      'You\'re already friends.';

  @override
  String get socialPublicProfile_controllerCommand => 'Friend request sent';

  @override
  String get socialPublicProfile_controllerCommand2 => 'Friend removed';

  @override
  String get socialPublicProfile_controllerCommand3 => 'Blocked';

  @override
  String get socialPublicProfile_controllerCooldown =>
      'Recently declined. Try again later.';

  @override
  String get socialPublicProfile_controllerIncomingRequestPending =>
      'They\'ve sent you a request. Handle it in Friend requests.';

  @override
  String get socialPublicProfile_controllerNotFound => 'User not found.';

  @override
  String get socialPublicProfile_controllerOutcomeUnknown =>
      'Result not confirmed. Refresh to check; don\'t resubmit.';

  @override
  String get socialPublicProfile_controllerOutgoingRequestPending =>
      'Request already sent, waiting for them.';

  @override
  String get socialPublicProfile_controllerPermissionDenied =>
      'They don\'t accept friend requests.';

  @override
  String get socialPublicProfile_controllerProfileRequired =>
      'Activate your LOOP ID first.';

  @override
  String get socialPublicProfile_controllerRateLimited =>
      'Too many attempts. Try again later.';

  @override
  String get socialPublicProfile_controllerS => 'Unfollowed';

  @override
  String get socialPublicProfile_controllerS2 => 'Unblocked';

  @override
  String get socialPublicProfile_controllerSwitch =>
      'Friend request not sent. Try again later.';

  @override
  String get socialPublicProfile_controllerUnavailable =>
      'The friend service isn\'t available right now; no request was sent.';

  @override
  String get socialPublicProfile_modelsTransferIn => 'Transfer in';

  @override
  String get socialPublicProfile_modelsTransferOut => 'Transfer out';

  @override
  String get socialPublicProfile_userBody =>
      'After removing, you\'re no longer friends; direct message history is kept. You can send a request again later.';

  @override
  String get socialPublicProfile_userBody2 =>
      'After blocking, they can\'t see your profile or send you messages or friend requests. You can unblock in Block list.';

  @override
  String get socialPublicProfile_userCountCommunities => 'Communities';

  @override
  String get socialPublicProfile_userCountFollowing => 'Following';

  @override
  String get socialPublicProfile_userDetail =>
      'On-chain data isn\'t available right now; 0 isn\'t shown in its place.';

  @override
  String get socialPublicProfile_userFriends => 'Friends';

  @override
  String get socialPublicProfile_userHoldingsHidden => 'Holdings not public';

  @override
  String get socialPublicProfile_userHoldingsUnavailable =>
      'Couldn\'t load holdings right now';

  @override
  String get socialPublicProfile_userLaunch2Row => 'Launch chain';

  @override
  String socialPublicProfile_userLoopRecordRow(Object? block) {
    return 'Block #$block';
  }

  @override
  String socialPublicProfile_userMembers(Object? formatDecimal) {
    return '$formatDecimal members';
  }

  @override
  String get socialPublicProfile_userNone => 'Add friend';

  @override
  String get socialPublicProfile_userOneMember => '1 member';

  @override
  String get socialPublicProfile_userPendingIn => 'Respond';

  @override
  String get socialPublicProfile_userPendingOut => 'Requested';

  @override
  String socialPublicProfile_userS(Object? launch2StageLabel) {
    return 'Launch chain, $launch2StageLabel';
  }

  @override
  String get socialPublicProfile_userSwitch => 'Total holdings';

  @override
  String socialPublicProfile_userSwitch2(Object? localTimestampLabel) {
    return 'Loaded $localTimestampLabel';
  }

  @override
  String get socialPublicProfile_userTitle => 'Remove friend?';

  @override
  String socialPublicProfile_userTitle2(Object? displayName) {
    return 'Block $displayName?';
  }

  @override
  String get socialPublicProfile_userTitle4 => 'No wallet yet';

  @override
  String get socialPublicProfile_userTradesHidden => 'Trades not public';

  @override
  String get socialPublicProfile_userTradesUnavailable =>
      'Couldn\'t load trades right now';

  @override
  String get socialPublicProfile_userUserProfileBlockLabel => 'Unblock';

  @override
  String get socialPublicProfile_userUserProfileBlockLabel2 => 'Block';

  @override
  String get socialPublicProfile_userUserProfileBlockedBody =>
      'They can\'t send you messages or friend requests, and you can\'t see their holdings or trades.';

  @override
  String get socialPublicProfile_userUserProfileBlockedTitle =>
      'You blocked them';

  @override
  String get socialPublicProfile_userUserProfileCommunitiesEmptyTitle =>
      'No communities joined yet';

  @override
  String get socialPublicProfile_userUserProfileCommunitiesHiddenTitle =>
      'Community list not public';

  @override
  String get socialPublicProfile_userUserProfileCommunitiesUnavailableDetail =>
      'The community service isn\'t available right now; an empty list isn\'t shown in its place.';

  @override
  String get socialPublicProfile_userUserProfileCommunitiesUnavailableMessage =>
      'Couldn\'t load communities right now';

  @override
  String get socialPublicProfile_userUserProfileHoldingsEmptyTitle =>
      'No holdings yet';

  @override
  String
  get socialPublicProfile_userUserProfileHoldingsLaunch2UnavailableLabel =>
      'MEME holdings unavailable';

  @override
  String get socialPublicProfile_userUserProfileHoldingsTotal => 'No quote';

  @override
  String get socialPublicProfile_userUserProfileInvalidTargetMessage =>
      'Enter from a chat, search or member list.';

  @override
  String get socialPublicProfile_userUserProfileInvalidTargetTitle =>
      'No user to open from this link';

  @override
  String get socialPublicProfile_userUserProfileMoreSemanticLabel =>
      'More actions';

  @override
  String get socialPublicProfile_userUserProfileMoreSheetBarrierLabel =>
      'Close more actions';

  @override
  String get socialPublicProfile_userUserProfileNotFoundMessage =>
      'The account doesn\'t exist, or their profile isn\'t visible to you.';

  @override
  String get socialPublicProfile_userUserProfileNotFoundTitle =>
      'User not found';

  @override
  String get socialPublicProfile_userUserProfileRemoveFriendLabel =>
      'Remove friend';

  @override
  String get socialPublicProfile_userUserProfileReportLabel =>
      'Report and block';

  @override
  String get socialPublicProfile_userUserProfileReportUnavailable =>
      'Reporting isn\'t available yet; you can block for now.';

  @override
  String get socialPublicProfile_userUserProfileScreenTitle => 'User profile';

  @override
  String get socialPublicProfile_userUserProfileShareCardSemanticLabel =>
      'Share card';

  @override
  String get socialPublicProfile_userUserProfileTradesEmptyTitle =>
      'No trades yet';

  @override
  String get socialPublicProfile_userUserProfileTradesLaunch2UnavailableLabel =>
      'MEME records unavailable';

  @override
  String get socialPublicProfile_userUserProfileUnavailableDetail =>
      'The profile service isn\'t available yet; this page didn\'t load anything.';

  @override
  String get socialPublicProfile_userUserProfileUnavailableMessage =>
      'User profile unavailable';

  @override
  String get socialPublicProfile_userUserProfileUnblockLabel => 'Unblock';

  @override
  String get socialQr_cardBarrierLabel => 'Close QR card';

  @override
  String get socialQr_cardCopy => 'Invite text copied';

  @override
  String get socialQr_cardDismissed =>
      'Poster created, but no share destination was chosen';

  @override
  String get socialQr_cardFailed =>
      'Couldn\'t create the poster; nothing left this device';

  @override
  String get socialQr_cardLoopCommunityQrCard => 'Community QR card';

  @override
  String get socialQr_cardLoopUserQrCard => 'My QR card';

  @override
  String socialQr_cardQrCardCodeSemanticLabel(Object? name) {
    return '$name\'s QR code';
  }

  @override
  String get socialQr_cardQrCardCopyInviteLabel => 'Copy invite text';

  @override
  String get socialQr_cardQrCardCopyLinkLabel => 'Copy link';

  @override
  String socialQr_cardQrCardPosterLabel(Object? name) {
    return '$name\'s QR card';
  }

  @override
  String get socialQr_cardQrCardSharePosterLabel => 'Creating…';

  @override
  String get socialQr_cardQrCardSharePosterLabel2 => 'Share poster';

  @override
  String get socialQr_cardQrCardUnavailableLabel => 'QR code unavailable';

  @override
  String socialQr_cardS(Object? link, Object? name) {
    return 'Join \"$name\" on LOOP\n$link';
  }

  @override
  String get socialQr_cardShared => 'Poster created. Choose where to share it';

  @override
  String socialQr_cardSwitch(Object? name) {
    return 'Join \"$name\" on LOOP';
  }

  @override
  String get socialQr_cardSwitch2 => 'Scan to add me';

  @override
  String socialQr_cardSwitch3(num memberCount) {
    String _temp0 = intl.Intl.pluralLogic(
      memberCount,
      locale: localeName,
      other: '$memberCount members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get socialQr_cardSwitch4 => 'Scan to join';

  @override
  String get socialQr_cardUnavailable =>
      'System sharing isn\'t available in this run; no poster was created';

  @override
  String get social_blocklistBlocklistCapabilityUnavailableTitle =>
      'Block list unavailable';

  @override
  String get social_blocklistBlocklistDeferredKindsDetail =>
      'These two block types aren\'t available yet, so nothing is listed here.';

  @override
  String get social_blocklistBlocklistDeferredKindsMessage =>
      'Contract and domain blocks aren\'t available yet';

  @override
  String get social_blocklistBlocklistPrecedenceNoticeBody =>
      'Blocking immediately removes follows both ways and hides them from search, follow lists and message requests. Unblocking doesn\'t restore follows; you\'ll need to follow again.';

  @override
  String get social_blocklistBlocklistPrecedenceNoticeTitle =>
      'What blocking does';

  @override
  String get social_blocklistBody =>
      'After unblocking, they can show up in search and message requests again. Removed follows aren\'t restored automatically.';

  @override
  String get social_blocklistCaption =>
      'Blocking overrides follows and direct messages. Unblocking doesn\'t restore follows.';

  @override
  String get social_blocklistConfirmLabel => 'Unblock';

  @override
  String get social_blocklistDetail =>
      'Contract and domain blocks aren\'t available yet, so nothing is listed here.';

  @override
  String get social_blocklistDomain => 'Domain';

  @override
  String get social_blocklistEmptyMessage => 'No blocked accounts';

  @override
  String get social_blocklistEmptyReason =>
      'Choosing Report on a message request blocks the sender automatically.';

  @override
  String social_blocklistHeading(num userCount) {
    String _temp0 = intl.Intl.pluralLogic(
      userCount,
      locale: localeName,
      other: '$userCount blocked accounts',
      one: '1 blocked account',
    );
    return '$_temp0';
  }

  @override
  String social_blocklistLabel(Object? userCount) {
    return 'Users $userCount';
  }

  @override
  String get social_blocklistLoopBadge => 'Unblock';

  @override
  String social_blocklistMessage(Object? segmentLabels) {
    return '\"$segmentLabels\" blocks aren\'t available yet';
  }

  @override
  String get social_blocklistMessage2 => 'Unblocked';

  @override
  String social_blocklistSemanticLabel(Object? blockReasonText, Object? title) {
    return '$title, $blockReasonText, can unblock';
  }

  @override
  String get social_blocklistStamp => 'Private';

  @override
  String social_blocklistTitle(Object? title) {
    return 'Unblock $title?';
  }

  @override
  String get social_connectionsBody =>
      'After unfollowing, you won\'t see their public posts.';

  @override
  String get social_connectionsBody2 =>
      'Following is one-way and doesn\'t need their approval. They need Discoverable on to be followed.';

  @override
  String get social_connectionsCommunityStateEmptyEmptyMessage =>
      'Not following anyone yet';

  @override
  String get social_connectionsCommunityStateEmptyEmptyMessage2 =>
      'No followers yet';

  @override
  String get social_connectionsCommunityStateEmptyEmptyReason =>
      'Accounts you\'ve blocked don\'t appear here.';

  @override
  String get social_connectionsConnectionActionDmLabel => 'Open direct message';

  @override
  String get social_connectionsConnectionActionFollowLabel => 'Unfollow';

  @override
  String get social_connectionsConnectionActionsSheetBarrierLabel =>
      'Close contact actions';

  @override
  String get social_connectionsConnectionsCapabilityUnavailableTitle =>
      'Follows unavailable';

  @override
  String get social_connectionsConnectionsDiscoverableNotice =>
      'Others can find you by nickname once Privacy Center · Discoverable is on; your LOOP ID can always be searched exactly.';

  @override
  String get social_connectionsConnectionsScreenTitle =>
      'Following and followers';

  @override
  String social_connectionsConnectionsSegFollowersLabel(Object? followers) {
    return 'Followers $followers';
  }

  @override
  String social_connectionsConnectionsSegFollowingLabel(Object? following) {
    return 'Following $following';
  }

  @override
  String get social_connectionsMessage => 'Unfollowed';

  @override
  String get social_connectionsResource => 'Follows';

  @override
  String get social_connectionsTitle => 'Unfollow?';

  @override
  String get social_connectionsTitle2 => 'Follow this account?';

  @override
  String get social_dmRequestsAccept => 'Accept';

  @override
  String get social_dmRequestsAccept2 =>
      'Accepting connects you. It can\'t connect if either of you has blocked the other.';

  @override
  String get social_dmRequestsAcceptTitle => 'Accept this request?';

  @override
  String get social_dmRequestsAccepted => 'Accepted';

  @override
  String get social_dmRequestsBarrierLabel => 'Close request actions';

  @override
  String get social_dmRequestsCommunityStateEmptyEmptyMessage =>
      'No pending requests';

  @override
  String get social_dmRequestsDmRequestsActionFailureTitle =>
      'The last decision didn\'t finish';

  @override
  String get social_dmRequestsDmRequestsCapabilityUnavailableTitle =>
      'Message requests unavailable';

  @override
  String get social_dmRequestsEmpty => '0 pending';

  @override
  String get social_dmRequestsIgnore => 'Ignore';

  @override
  String get social_dmRequestsIgnore2 =>
      'After ignoring, they can\'t send another request for 24 hours.';

  @override
  String get social_dmRequestsIgnoreTitle => 'Ignore this request?';

  @override
  String get social_dmRequestsIgnored => 'Ignored';

  @override
  String get social_dmRequestsMessage => 'Reported and blocked';

  @override
  String social_dmRequestsReady(Object? items) {
    return '$items pending';
  }

  @override
  String get social_dmRequestsReport => 'Report and block';

  @override
  String get social_dmRequestsReport2 =>
      'Reporting declines the request, blocks the sender, writes an audit record and removes follows both ways.';

  @override
  String get social_dmRequestsReportTitle => 'Report and block this request?';

  @override
  String get social_idCopyLabel => 'Copy LOOP ID';

  @override
  String get social_idCopyMessage => 'LOOP ID copied';

  @override
  String social_idShareLine(Object? loopId) {
    return 'Add me as a friend on LOOP: $loopId';
  }

  @override
  String get social_modelsSwitch => 'Blocked by you';

  @override
  String get social_modelsSwitch2 =>
      'Blocked automatically when reporting a message request';

  @override
  String get social_modelsSwitch3 => 'Block reason';

  @override
  String get social_profileFaceLinkLabel => 'View my profile';

  @override
  String social_profileFaceLinkLabel2(Object? name) {
    return 'View $name\'s profile';
  }

  @override
  String get social_publicProfileSheetBarrierLabel => 'Close public profile';

  @override
  String get social_publicProfileSheetPublicProfileDmHint =>
      'If you\'re not connected yet, you\'ll send a message request first.';

  @override
  String get social_publicProfileSheetPublicProfileFollowState =>
      'Not following';

  @override
  String get social_publicProfileSheetPublicProfileFollowUnknownBody =>
      'The current follow status can\'t be read here; the result after the action applies.';

  @override
  String get social_publicProfileSheetPublicProfileNotTargetableDetail =>
      'This account has no public profile; it can\'t be followed or acted on.';

  @override
  String get social_publicProfileSheetPublicProfileNotTargetableMessage =>
      'This member has no public profile';

  @override
  String get social_publicProfileSheetPublicProfileOpenPageLabel =>
      'View profile';

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
  String get system_specimensChartRangeLabel => '1H, fixed demo';

  @override
  String get system_specimensCommunityLine =>
      'LOOP community 128,420 members, 0.35×';

  @override
  String get system_specimensCommunityLine2 =>
      'Graduated 08-22, DEX pool liquidity in place';

  @override
  String get system_specimensCommunityLine3 =>
      'This token isn\'t in a LOOP community, no Mining Weight';

  @override
  String get system_specimensFact =>
      'This contract has a mint function; the issuer can mint more';

  @override
  String get system_specimensFact2 =>
      'Contract address doesn\'t match the official PEPE';

  @override
  String get system_specimensLabel => 'State 1, normal';

  @override
  String get system_specimensLabel2 => 'State 2, identifying';

  @override
  String get system_specimensLabel3 => 'State 3, graduated (LOOP Launch asset)';

  @override
  String get system_specimensLabel4 => 'State 4, data missing';

  @override
  String get system_specimensLabel5 => 'State 5, risk facts bar';

  @override
  String get system_specimensLabel6 =>
      'State 1, awaiting confirmation (normal)';

  @override
  String get system_specimensLabel7 => 'State 2, simulation failed';

  @override
  String get system_specimensLabel8 => 'State 3, signing';

  @override
  String get system_specimensLabel9 => 'State 4, rejected by policy';

  @override
  String get system_specimensLoopComponentSpecimenLabel => 'Component specimen';

  @override
  String get system_specimensLoopSignFact => 'Fee';

  @override
  String get system_specimensLoopSignFact2 => 'Passed';

  @override
  String get system_specimensLoopSignFact3 => 'Failed, can\'t simulate';

  @override
  String get system_specimensLoopSignFact4 => 'Transfer 5,000 USDC';

  @override
  String get system_specimensLoopSignFact5 => 'Result';

  @override
  String get system_specimensLoopSignFact6 => 'Rejected';

  @override
  String get system_specimensLoopStateSpecimenLabel =>
      'Component specimen, not the current state';

  @override
  String get system_specimensLoopTokenCardAction => 'Graduation details';

  @override
  String get system_specimensLoopTokenCardAction2 => 'View contract';

  @override
  String get system_specimensLoopTokenCardAction3 => 'Trading unavailable';

  @override
  String get system_specimensLoopTokenCardAction4 => 'Review facts, then buy';

  @override
  String get system_specimensLoopTokenCardAction5 => 'View all facts';

  @override
  String get system_specimensObservedLabel => '2m ago';

  @override
  String get system_specimensReason =>
      'The simulation service didn\'t return a verifiable result. Can\'t confirm right now; retry the simulation or cancel.';

  @override
  String get system_specimensReason2 =>
      'Over your single-transfer limit of \$1,000. This is a wallet policy you set; adjust it in Security Center or lower the amount.';

  @override
  String get system_specimensSemanticLabel =>
      'PEPE 1-hour trend, component specimen';

  @override
  String get system_specimensSource => 'On-chain comparison';

  @override
  String get system_specimensSourceLabel => 'Demo data, development preview';

  @override
  String get system_surfacesBanner => 'Offline, live updates paused';

  @override
  String get system_surfacesBanner2 =>
      'Market data unavailable, prices may be stale';

  @override
  String get system_surfacesBanner3 => 'Trading service down, actions paused';

  @override
  String get system_surfacesBody =>
      'Check Wi-Fi or mobile data. Asset data is cached from the last sync and may be stale.';

  @override
  String get system_surfacesBody10 =>
      'Claims work normally after maintenance; nothing is missed.';

  @override
  String get system_surfacesBody11 =>
      'LOOP doesn\'t infer your region from device language, SIM or IP; without an approved decision, it\'s treated as unknown.';

  @override
  String get system_surfacesBody12 =>
      'Your location isn\'t inferred, and other features aren\'t confirmed to be available.';

  @override
  String get system_surfacesBody13 =>
      'Used for app lock and verification before signing. Biometric data stays with the system; LOOP can\'t access it.';

  @override
  String get system_surfacesBody14 =>
      'Tap a button to show a real toast. It disappears after 2.6 seconds.';

  @override
  String get system_surfacesBody15 =>
      'Normal, identifying and Launch asset share one structure, not one risk judgment. This component appears in chats, community home, market lists and search results, with no route of its own.';

  @override
  String get system_surfacesBody16 =>
      'Every item shows its source and time, with no verdict like \"dangerous\" or \"unsafe\". The call is yours.';

  @override
  String get system_surfacesBody17 =>
      'Send, Swap, Launch buys and approvals all go through this one sheet; staking joins only after its own contract plan is approved.';

  @override
  String get system_surfacesBody18 =>
      'Your wallet stopped it by your own rule, so the copy says which rule and how to change it, not just \"failed\".';

  @override
  String get system_surfacesBody19 => 'Go back and try again.';

  @override
  String get system_surfacesBody2 =>
      'Everything else works. Prices and charts may be off; actions that depend on the current price are paused.';

  @override
  String get system_surfacesBody3 =>
      'Orders and account changes can\'t be submitted; market browsing and chat still work.';

  @override
  String get system_surfacesBody4 =>
      'Other chains are fine. BSC balances may be off, and trading on that chain is paused.';

  @override
  String get system_surfacesBody5 =>
      'A full outage blocks everything; a single-chain outage should leave other chains working. Blocking it all makes people think the whole app is broken.';

  @override
  String get system_surfacesBody6 =>
      'Per-chain status can\'t be read right now. This page won\'t decide for you whether a chain is available.';

  @override
  String get system_surfacesBody7 =>
      'Trace ID 7f3a2c9e. Wallet assets stay on-chain, unaffected.';

  @override
  String system_surfacesBody8(Object? trace) {
    return '$trace. Don\'t assume success or failure; check the latest status before retrying. Wallet assets stay on-chain, unaffected.';
  }

  @override
  String get system_surfacesBody9 =>
      'LOOP only blocks when an approved version policy requires an update and this version is below its floor.';

  @override
  String get system_surfacesCaption =>
      'Everything else still works; affected actions stay disabled until recovery.';

  @override
  String get system_surfacesCaption10 =>
      'Send, Swap, DApp and Bridge all go through one signing exit.';

  @override
  String get system_surfacesCaption11 =>
      'LOOP doesn\'t recognize the requested system page.';

  @override
  String get system_surfacesCaption2 =>
      'Opening this page doesn\'t mean this version is unsupported or unsafe.';

  @override
  String get system_surfacesCaption3 =>
      'An approved version policy requires a supported version. This can\'t be skipped.';

  @override
  String get system_surfacesCaption4 =>
      'Opening this page doesn\'t mean your region or account is restricted.';

  @override
  String get system_surfacesCaption5 =>
      'Assets stay visible read-only; restricted features follow each page\'s current state.';

  @override
  String get system_surfacesCaption6 =>
      'Restricted features follow each page\'s current state; unconfirmed availability isn\'t listed here.';

  @override
  String get system_surfacesCaption7 =>
      'Camera, notifications and biometrics are asked for only when needed.';

  @override
  String get system_surfacesCaption8 =>
      'Success, warning and error share one position and clear meaning.';

  @override
  String get system_surfacesCaption9 =>
      'Lists, details and charts each keep a stable layout so content doesn\'t jump.';

  @override
  String get system_surfacesConnectivitySpecimenCaption =>
      'Cache is still viewable; Send, Swap and Bridge are paused.';

  @override
  String get system_surfacesConnectivitySpecimenHeading =>
      'This device is offline';

  @override
  String get system_surfacesConnectivitySpecimenKicker => 'Last sync 09:38';

  @override
  String get system_surfacesConnectivitySpecimenRetryMessage =>
      'Can\'t connect to the server';

  @override
  String get system_surfacesConnectivitySpecimenStamp => 'Offline';

  @override
  String get system_surfacesConnectivitySpecimenTitle => 'No network';

  @override
  String get system_surfacesDeniedBody =>
      'You won\'t get mining settlement or Launch alerts. Turn it back on in Settings → LOOP → Notifications.';

  @override
  String get system_surfacesDeniedBody2 =>
      'Scanning is unavailable. Turn it back on in Settings → LOOP → Camera.';

  @override
  String get system_surfacesDeniedBody3 =>
      'You can only listen in voice rooms. Turn it back on in Settings → LOOP → Microphone.';

  @override
  String system_surfacesForceUpdateFloorSuffix(Object? version) {
    return ' (force-update floor $version)';
  }

  @override
  String get system_surfacesForceUpdateStoreUnavailableBody =>
      'Can\'t open the store directly right now. Update from the app store manually.';

  @override
  String get system_surfacesForceUpdateStoreUnavailableFootnote =>
      'An approved version policy requires an update. This can\'t be skipped';

  @override
  String get system_surfacesForceUpdateStoreUnavailableTitle =>
      'Update required';

  @override
  String get system_surfacesHeading => 'Version policy isn\'t open yet';

  @override
  String get system_surfacesHeading2 => 'Maintenance notice in effect';

  @override
  String get system_surfacesHeading3 => 'Region policy isn\'t open yet';

  @override
  String get system_surfacesHeading4 => 'Limited in your region';

  @override
  String get system_surfacesHeading5 => 'Asked only when needed';

  @override
  String get system_surfacesHeading6 => '5 card states';

  @override
  String get system_surfacesHeading7 => '4 signing states';

  @override
  String get system_surfacesHeading8 => 'This page isn\'t available';

  @override
  String get system_surfacesKicker => 'Device offline';

  @override
  String get system_surfacesKicker10 => 'Unified signing exit';

  @override
  String get system_surfacesKicker2 => 'Service outage';

  @override
  String get system_surfacesKicker3 => 'Version policy';

  @override
  String get system_surfacesKicker4 => 'Release gate';

  @override
  String get system_surfacesKicker5 => 'Access policy';

  @override
  String get system_surfacesKicker6 => 'Permissions';

  @override
  String get system_surfacesKicker7 => 'Feedback';

  @override
  String get system_surfacesKicker8 => 'Loading states';

  @override
  String get system_surfacesKicker9 => 'Token card';

  @override
  String get system_surfacesLabel => 'Update now';

  @override
  String get system_surfacesLabel10 => 'View assets';

  @override
  String get system_surfacesLabel11 => 'Export private key';

  @override
  String get system_surfacesLabel12 => 'View eligibility policy';

  @override
  String get system_surfacesLabel13 => 'Not now';

  @override
  String system_surfacesLabel14(Object? label) {
    return 'Show $label toast';
  }

  @override
  String get system_surfacesLabel2 => 'View cached content';

  @override
  String get system_surfacesLabel3 => 'Keep using available features';

  @override
  String get system_surfacesLabel4 => 'Contact support';

  @override
  String get system_surfacesLabel5 => 'Force-update floor';

  @override
  String get system_surfacesLabel6 => 'Minimum supported version';

  @override
  String get system_surfacesLabel7 => 'Update';

  @override
  String get system_surfacesLabel8 => 'Check again';

  @override
  String get system_surfacesLabel9 => 'View service status';

  @override
  String system_surfacesLastSyncKicker(Object? hour, Object? minute) {
    return 'Last sync $hour:$minute';
  }

  @override
  String system_surfacesLoadingPresentationActiveBody(Object? kind) {
    return 'The owner chose the $kind skeleton; placeholders don\'t indicate result count, identity or success.';
  }

  @override
  String get system_surfacesLoadingPresentationActiveTitle =>
      'Three skeleton types';

  @override
  String get system_surfacesLoopLabel => 'Partial outage (another state)';

  @override
  String get system_surfacesLoopLabel10 => 'Chart skeleton';

  @override
  String get system_surfacesLoopLabel2 => 'Before asking';

  @override
  String get system_surfacesLoopLabel3 => 'After denial (component specimen)';

  @override
  String get system_surfacesLoopLabel4 => 'After denial';

  @override
  String get system_surfacesLoopLabel5 => 'Current feedback';

  @override
  String get system_surfacesLoopLabel6 => 'Static style comparison';

  @override
  String get system_surfacesLoopLabel7 => 'Current loading';

  @override
  String get system_surfacesLoopLabel8 => 'List skeleton';

  @override
  String get system_surfacesLoopLabel9 => 'Detail skeleton';

  @override
  String get system_surfacesMaintenanceSpecimenCaption =>
      'Community interaction is paused; Wallet and Mining data stay read-only.';

  @override
  String get system_surfacesMaintenanceSpecimenKicker => 'Maintenance window';

  @override
  String get system_surfacesMaintenanceSpecimenReadOnlyLabel =>
      'View read-only content';

  @override
  String get system_surfacesMaintenanceSpecimenStamp => '2 hours';

  @override
  String get system_surfacesMaintenanceSpecimenTitle => 'Scheduled maintenance';

  @override
  String get system_surfacesMessage => 'Allow LOOP in system settings';

  @override
  String get system_surfacesPartialOutageNoticeBody =>
      'Other chains are fine. Balances on this chain may be off, and trading on it is paused.';

  @override
  String system_surfacesPartialOutageNoticeTitle(Object? networkLabel) {
    return '$networkLabel network isn\'t available right now';
  }

  @override
  String get system_surfacesPermissionDeniedSpecimenTitle => 'Permission notes';

  @override
  String get system_surfacesPermissionDeniedSpecimenTitle2 =>
      'Notifications are turned off in system settings';

  @override
  String get system_surfacesPurpose =>
      'For mining settlement, Launch start, @mentions and security events. No marketing.';

  @override
  String get system_surfacesPurpose2 =>
      'Only when scanning a QR code: payment addresses and WalletConnect. Never in the background.';

  @override
  String get system_surfacesPurpose3 =>
      'Only after you tap \"Speak\" in a voice room; the mic is off when you enter.';

  @override
  String get system_surfacesS => 'This request';

  @override
  String get system_surfacesServiceErrorSpecimenCaption =>
      'Your wallet is still on your device. Try again later or contact support.';

  @override
  String get system_surfacesServiceErrorSpecimenHeading =>
      'Service unavailable';

  @override
  String get system_surfacesServiceErrorSpecimenStamp => 'Retryable';

  @override
  String get system_surfacesServiceErrorSpecimenTitle => 'Service status';

  @override
  String get system_surfacesSettingsLabel => 'Open system settings';

  @override
  String get system_surfacesShortName => 'Camera';

  @override
  String get system_surfacesShortName2 => 'Microphone';

  @override
  String get system_surfacesShowLoopForceUpdateDialog =>
      'Update LOOP to continue';

  @override
  String system_surfacesShowLoopForceUpdateDialog2(Object? requirement) {
    return 'An approved version policy requires a supported version$requirement. Install a supported version, then come back to LOOP.';
  }

  @override
  String get system_surfacesSignSheetTriggerPendingLabel =>
      'Show pending sheet';

  @override
  String get system_surfacesSignSheetTriggerPendingTitle =>
      'Four sign sheet states';

  @override
  String get system_surfacesSkeletonChart => 'chart';

  @override
  String get system_surfacesSkeletonDetail => 'detail';

  @override
  String get system_surfacesSkeletonList => 'list';

  @override
  String get system_surfacesStamp => 'Partial outage';

  @override
  String get system_surfacesStamp2 => 'Update needed';

  @override
  String get system_surfacesStamp3 => 'In effect';

  @override
  String get system_surfacesStamp4 => 'Scheduled';

  @override
  String get system_surfacesStamp5 => 'Restricted';

  @override
  String get system_surfacesStamp6 => 'On demand';

  @override
  String get system_surfacesStamp7 => '3 states';

  @override
  String get system_surfacesStamp8 => '3 types';

  @override
  String get system_surfacesStamp9 => '5 states';

  @override
  String get system_surfacesSummary => 'Where this component appears';

  @override
  String get system_surfacesSystemReturnLabel => 'Back to LOOP';

  @override
  String get system_surfacesText => 'Address copied';

  @override
  String get system_surfacesText2 => 'Warning';

  @override
  String get system_surfacesText3 => 'Price changed. Refresh the quote';

  @override
  String get system_surfacesText4 => 'Error';

  @override
  String get system_surfacesText5 => 'Transaction failed: not enough gas';

  @override
  String get system_surfacesTitle => 'Fully offline';

  @override
  String get system_surfacesTitle10 => 'Force update';

  @override
  String get system_surfacesTitle11 => 'No approved minimum version policy';

  @override
  String get system_surfacesTitle12 => 'Mining Power keeps accruing';

  @override
  String get system_surfacesTitle13 => 'Maintenance notes';

  @override
  String get system_surfacesTitle14 => 'Region restriction';

  @override
  String get system_surfacesTitle15 => 'No approved region decision';

  @override
  String get system_surfacesTitle16 => 'No location or reason details here';

  @override
  String get system_surfacesTitle17 => 'Notification permission';

  @override
  String get system_surfacesTitle18 => 'Camera permission';

  @override
  String get system_surfacesTitle19 => 'Biometrics';

  @override
  String get system_surfacesTitle2 => 'Market data unavailable';

  @override
  String system_surfacesTitle20(Object? shortName) {
    return '$shortName permission is turned off in system settings';
  }

  @override
  String system_surfacesTitle21(Object? shortName) {
    return '$shortName permission';
  }

  @override
  String get system_surfacesTitle22 => 'Three toast states';

  @override
  String get system_surfacesTitle23 => 'Five Token Card states';

  @override
  String get system_surfacesTitle24 => 'Risk state lists facts only';

  @override
  String get system_surfacesTitle25 => 'The only signing exit in the product';

  @override
  String get system_surfacesTitle26 => 'A policy rejection isn\'t an error';

  @override
  String get system_surfacesTitle27 => 'System';

  @override
  String get system_surfacesTitle3 => 'Trading service unavailable';

  @override
  String get system_surfacesTitle4 => 'BSC network isn\'t available right now';

  @override
  String get system_surfacesTitle5 => 'Why tell these two apart';

  @override
  String get system_surfacesTitle6 => 'No per-chain outage info';

  @override
  String get system_surfacesTitle7 => 'Error 502';

  @override
  String get system_surfacesTitle8 => 'Result unconfirmed';

  @override
  String system_surfacesTitle9(Object? statusLabel) {
    return 'Error $statusLabel';
  }

  @override
  String system_surfacesTitleBody(Object? body, Object? title) {
    return '$title. $body';
  }

  @override
  String system_surfacesTraceId(Object? trace) {
    return 'Trace ID $trace';
  }

  @override
  String get system_surfacesTraceMissing => 'No trace ID';

  @override
  String get system_surfacesUnavailableReason =>
      'No reviewed store link. Open the app store manually.';

  @override
  String get system_surfacesUnavailableReason2 =>
      'The Wallet page can\'t be reached right now.';

  @override
  String get system_surfacesUnavailableReason3 =>
      'The private key export page can\'t be reached right now.';

  @override
  String get system_surfacesUnavailableReason4 =>
      'The help page can\'t be reached right now.';

  @override
  String get system_surfacesUnavailableReason5 =>
      'No approved eligibility policy link.';

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
  String get wallet_swapMainnetOnly =>
      'Swap supports BNB Chain mainnet assets only.';

  @override
  String get wallet_swapNoMainnetBalanceTitle => 'No BNB Chain mainnet balance';

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

  @override
  String widgets_assetsBuild(Object? slot) {
    return '$slot avatar';
  }

  @override
  String widgets_atmosphereLabel(Object? title) {
    return '$title, view all';
  }

  @override
  String widgets_avatarStackBuild(Object? remaining) {
    return '$remaining more';
  }

  @override
  String get widgets_blocksUnread => 'Not loaded';

  @override
  String get widgets_clauseJoin => '; ';

  @override
  String widgets_componentsBuild(Object? traceId) {
    return 'Trace ID $traceId';
  }

  @override
  String widgets_componentsBuild2(Object? source) {
    return 'Source $source';
  }

  @override
  String get widgets_componentsCacheStale =>
      'Cached values may be out of date.';

  @override
  String get widgets_componentsCachedHeadline => 'Offline · Showing cache';

  @override
  String get widgets_componentsCachedTimeoutHeadline =>
      'LOOP timed out · Showing cache';

  @override
  String get widgets_componentsCard => 'Loading card';

  @override
  String get widgets_componentsChart => 'Loading chart';

  @override
  String get widgets_componentsConnectionHeadline => 'Can\'t reach LOOP';

  @override
  String get widgets_componentsDetail => 'Loading details';

  @override
  String get widgets_componentsFigure => 'Loading figures';

  @override
  String get widgets_componentsHintText => 'Send a message';

  @override
  String widgets_componentsLabel(Object? title, Object? trailing) {
    return '$title, $trailing, can\'t be changed';
  }

  @override
  String get widgets_componentsLabel2 => 'What happened';

  @override
  String get widgets_componentsLabel3 => 'What\'s affected';

  @override
  String get widgets_componentsLabel4 => 'Updating';

  @override
  String get widgets_componentsLabel5 => 'Other options';

  @override
  String get widgets_componentsLabel6 => 'Reconnect';

  @override
  String widgets_componentsLoopOfflineCachedAt(Object? cachedAt) {
    return 'Cached $cachedAt';
  }

  @override
  String widgets_componentsLoopOfflineCachedAtSemanticsLabel(Object? cachedAt) {
    return 'Cached at $cachedAt';
  }

  @override
  String get widgets_componentsNoCacheBody =>
      'This read didn\'t finish and there\'s no cache to show yet.';

  @override
  String get widgets_componentsPriceRow => 'Loading list';

  @override
  String get widgets_componentsRetryFailedMessage =>
      'Still couldn\'t connect. Try again once the network is back.';

  @override
  String get widgets_componentsRetryingLabel => 'Retrying…';

  @override
  String widgets_componentsS(Object? pausedActions) {
    return 'Paused: $pausedActions.';
  }

  @override
  String get widgets_componentsSettingsLabel => 'Open system settings';

  @override
  String widgets_componentsSwitch(Object? happened) {
    return 'What happened: $happened';
  }

  @override
  String widgets_componentsSwitch2(Object? impact) {
    return 'What\'s affected: $impact';
  }

  @override
  String widgets_componentsSwitch3(Object? next) {
    return 'Next: $next';
  }

  @override
  String get widgets_componentsTimeoutHeadline => 'LOOP timed out';

  @override
  String get widgets_componentsTitle => 'Couldn\'t complete right now';

  @override
  String get widgets_componentsUnreachableMessage =>
      'Nothing was loaded on this page and nothing was submitted. Check your network and retry.';

  @override
  String get widgets_componentsUnreachableTitle =>
      'Can\'t reach LOOP right now';

  @override
  String get widgets_enumerationSeparator => ', ';

  @override
  String widgets_environmentTagLabel(Object? label) {
    return 'Server $label';
  }

  @override
  String widgets_flatLoopStepDotsLabel(
    Object? label,
    Object? step,
    Object? total,
  ) {
    return 'Step $step of $total, $label';
  }

  @override
  String get widgets_infoSheetBarrierLabel => 'Close details';

  @override
  String widgets_infoSheetLabel(Object? title) {
    return 'About $title';
  }

  @override
  String get widgets_inlineStatesLabel => 'Scope';

  @override
  String get widgets_inlineStatesLabel2 => 'Source';

  @override
  String get widgets_inlineStatesLabel3 => 'Observed at';

  @override
  String get widgets_inlineStatesLoopInlineUnavailableRetryLabel => 'Retrying';

  @override
  String widgets_inlineStatesLoopProvenanceLineSemanticsLabel(Object? text) {
    return '$text, view data source details';
  }

  @override
  String widgets_inlineStatesLoopProvenanceMarkerLabel(Object? text) {
    return '$text, data source is in the details at the top right';
  }

  @override
  String get widgets_inlineStatesLoopProvenanceSheetBarrierLabel =>
      'Close data source details';

  @override
  String widgets_inlineStatesText2(Object? timeLabel) {
    return 'Observed at $timeLabel';
  }

  @override
  String get widgets_inlineStatesValue => 'Source not labeled';

  @override
  String get widgets_labelColon => ': ';

  @override
  String get widgets_loadingIf => 'Update failed. Showing the last data read';

  @override
  String widgets_loadingIf2(Object? age) {
    return 'Data from $age, updating';
  }

  @override
  String widgets_loadingLoopAgeLabel(Object? inSeconds) {
    return '${inSeconds}s ago';
  }

  @override
  String widgets_loadingLoopAgeLabel2(Object? inMinutes) {
    return '${inMinutes}m ago';
  }

  @override
  String widgets_loadingLoopAgeLabel3(Object? inHours) {
    return '${inHours}h ago';
  }

  @override
  String widgets_loadingLoopAgeLabel4(Object? inDays) {
    return '${inDays}d ago';
  }

  @override
  String widgets_loadingS(Object? ageLabel) {
    return 'Update failed. Last read $ageLabel';
  }

  @override
  String widgets_loadingS2(Object? age) {
    return 'Data from $age';
  }

  @override
  String get widgets_pagesLoopKeyboardDoneLabel => 'Done, hide keyboard';

  @override
  String get widgets_personRowLabel => 'View all';

  @override
  String get widgets_profileSectionCommunities => 'Communities';

  @override
  String get widgets_profileSectionTrades => 'Trades';

  @override
  String get widgets_provenanceScopeLabel => 'Data sources and details';

  @override
  String get widgets_quoteRowSwitch => 'Not reported';

  @override
  String get widgets_roundKeyLabel => ', unavailable';

  @override
  String get widgets_sentenceGap => ' ';

  @override
  String get widgets_sentenceJoin => '. ';

  @override
  String get widgets_sheetBarrierLabel => 'Close sheet';

  @override
  String get widgets_signSheetBuild => 'Don\'t close the app';

  @override
  String get widgets_signSheetConfirmLabel => 'Confirm signature';

  @override
  String get widgets_signSheetLabel => 'Adjust policy';

  @override
  String get widgets_signSheetPolicyRejected => 'Rejected by policy';

  @override
  String get widgets_signSheetSigning => 'Signing';

  @override
  String get widgets_signSheetSigningTitle => 'Signing and broadcasting';

  @override
  String get widgets_signSheetSimulationFailed => 'Simulation failed';

  @override
  String get widgets_signSheetTitle => 'Confirm transaction';

  @override
  String widgets_signStepsLabel(
    Object? caption,
    Object? label,
    Object? number,
  ) {
    return 'Step $number $label, $caption';
  }

  @override
  String widgets_signStepsStep(Object? waitingCaption) {
    return 'Next, $waitingCaption';
  }

  @override
  String get widgets_toastSwitch => 'Warning';

  @override
  String get widgets_toastSwitch2 => 'Error';

  @override
  String widgets_tokenCardBuild(
    Object? fact,
    Object? observedLabel,
    Object? source,
  ) {
    return '$fact — source $source, observed at $observedLabel';
  }

  @override
  String get widgets_tokenCardLoading => 'Identifying';

  @override
  String get widgets_tokenCardPartial => 'Data missing';

  @override
  String get widgets_tokenCardRisk => 'Risk facts';

  @override
  String get widgets_tokenCardSwitch => 'Identifying…';

  @override
  String get widgets_uiDiscover => 'Discover';

  @override
  String get widgets_uiDiscuss => 'Discuss';

  @override
  String get widgets_uiExecute => 'Execute';

  @override
  String widgets_uiLabel(Object? label) {
    return 'Current stage: $label';
  }
}
