import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_providers.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/about/about_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/support/support_gateway.dart';
import 'package:loop_mobile/integrations/device/local_auth_device_authenticator.dart';
import 'package:loop_mobile/integrations/privy/privy_mfa_gateway.dart';
import 'package:loop_mobile/integrations/device/secure_storage_app_lock_store.dart';
import 'package:loop_mobile/integrations/notifications/firebase_notification_ingress.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_display_store.dart';
import 'package:loop_mobile/integrations/personalization/loop_personalization_providers.dart';
import 'package:loop_mobile/integrations/social/loop_social_providers.dart';
import 'package:loop_mobile/integrations/social/loop_group_alias_providers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_activity_export.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s6_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s8_providers.dart';
import 'package:loop_mobile/app/session/onboarding_sequence.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_onboarding_store.dart';
import 'package:loop_mobile/integrations/sharing/system_chat_merge_export_sink.dart';
import 'package:loop_mobile/integrations/sharing/system_wallet_activity_export_sink.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/community/community_ai_gateway.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final displayBootstrap = await bootstrapSharedPreferencesDisplayPreferences();
  // Firebase is brought up here and nowhere else, and only when this build was
  // given a configuration. `FIREBASE_CONFIGURED=false`, a build-profile
  // mismatch, and an initialization the device refused all end in the same
  // place: the notification source stays disabled, no token is read, and no
  // registration is attempted. The offline Preview entry point has its own
  // `main` and never reaches this line.
  final config = AppConfig.fromEnvironment();
  // The device's own record of why it may not be addressable. It is created
  // before the scope because the first thing that can go wrong — a Firebase
  // that never came up — happens before there is one, and a device with no
  // push provider must be able to say that rather than look registered.
  final pushDiagnostics = LoopPushRegistrationDiagnosticsRecorder();
  final firebaseApp = config.canInitializeFirebase
      ? await LoopFirebaseIngress.ensureApp(diagnostics: pushDiagnostics)
      : null;
  // `ensureApp` records the two failures it can tell apart. This is the
  // third: a build that was never given a configuration to try.
  if (!config.canInitializeFirebase) {
    pushDiagnostics.record(LoopPushRegistrationGate.tokenSourceDisabled);
  }
  runApp(
    ProviderScope(
      overrides: [
        loopPushRegistrationDiagnosticsProvider.overrideWithValue(
          pushDiagnostics,
        ),
        if (firebaseApp != null) ...[
          loopNotificationEventSourceProvider.overrideWithValue(
            FirebaseLoopNotificationEventSource.forDefaultApp(),
          ),
          loopPushTokenSourceProvider.overrideWithValue(
            FirebaseLoopPushTokenSource.forDefaultApp(),
          ),
        ],
        loopDisplayPreferencesStoreProvider.overrideWithValue(
          displayBootstrap.store,
        ),
        loopDisplayPreferencesInitialProvider.overrideWithValue(
          displayBootstrap.initial,
        ),
        // The device-local application lock. The authenticator is the
        // operating system's own prompt; the store keeps one boolean and
        // nothing else, because LOOP holds no PIN and no biometric material.
        loopDeviceAuthenticatorProvider.overrideWithValue(
          const LocalAuthDeviceAuthenticator(),
        ),
        loopAppLockStoreProvider.overrideWithValue(
          const SecureStorageLoopAppLockStore(),
        ),
        // The account's second factor lives at Privy. Production resolves it
        // from the same SDK session the rest of the account reads; a build
        // with no session keeps the unavailable gateway.
        loopMfaGatewayProvider.overrideWith(
          (ref) => ref.watch(loopPrivyMfaGatewayProvider),
        ),
        // Where the five-step opening got to, per account. A device that
        // refuses the write falls back to the in-process default, which
        // simply restarts the sequence at 02 after a cold start.
        loopOnboardingProgressStoreProvider.overrideWithValue(
          SharedPreferencesLoopOnboardingProgressStore(),
        ),
        friendGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProductionFriendGatewayProvider),
        ),
        groupAliasGatewayProvider.overrideWith(
          (ref) => ref.watch(loopGroupAliasGatewayProvider),
        ),
        profileGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProfileGatewayProvider),
        ),
        profileActivationGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProfileActivationGatewayProvider),
        ),
        avatarCatalogGatewayProvider.overrideWith(
          (ref) => ref.watch(loopAvatarCatalogGatewayProvider),
        ),
        privacyGatewayProvider.overrideWith(
          (ref) => ref.watch(loopPrivacyGatewayProvider),
        ),
        communityGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2CommunityGatewayProvider),
        ),
        communityAiGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2CommunityAiGatewayProvider),
        ),
        socialGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SocialGatewayProvider),
        ),
        searchGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SearchGatewayProvider),
        ),
        chatV2GatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ChatGatewayProvider),
        ),
        voiceRoomGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2VoiceRoomGatewayProvider),
        ),
        // The merged image is encoded on device and handed to the operating
        // system; it never reaches a LOOP service, in either composition.
        chatMergeExportSinkProvider.overrideWithValue(
          const SystemChatMergeExportSink(),
        ),
        // The wallet-activity CSV is encoded on device from rows already on
        // screen and handed to the same share sheet; it never reaches a LOOP
        // service either.
        walletActivityExportSinkProvider.overrideWithValue(
          const SystemWalletActivityExportSink(),
        ),
        // S5 read modules. Each stays fail-closed until its Dio client,
        // client metadata and authenticated session all exist.
        chainGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ChainGatewayProvider),
        ),
        walletReadGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2WalletReadGatewayProvider),
        ),
        marketReadGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2MarketReadGatewayProvider),
        ),
        watchlistGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2WatchlistGatewayProvider),
        ),
        alertsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2AlertsGatewayProvider),
        ),
        notificationsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2NotificationsGatewayProvider),
        ),
        // Where a notification could be delivered, which is not the same as
        // what the account asked to hear about; the preferences resource owns
        // that and stays where it was.
        pushDeviceGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2PushDeviceGatewayProvider),
        ),
        // S6 money actions. Availability here is transport assembly only: the
        // write switch, the canary ceiling and the device evidence stay
        // server-owned, and every page still reads its capability gate.
        walletIntentsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2WalletIntentsGatewayProvider),
        ),
        swapQuoteGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SwapQuoteGatewayProvider),
        ),
        approvalsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ApprovalsGatewayProvider),
        ),
        // S7 launch catalogue, mining skeleton and referral graph. Each stays
        // fail-closed until its Dio client, client metadata and authenticated
        // session all exist.
        launchGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2LaunchGatewayProvider),
        ),
        miningGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2MiningGatewayProvider),
        ),
        referralGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ReferralGatewayProvider),
        ),
        // S8 security / settings / support. `about` is public and needs only a
        // backend origin; the other three also need an authenticated session.
        securityGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SecurityGatewayProvider),
        ),
        accountSettingsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2AccountSettingsGatewayProvider),
        ),
        supportGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SupportGatewayProvider),
        ),
        aboutGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2AboutGatewayProvider),
        ),
      ],
      child: const LoopApp(),
    ),
  );
}
