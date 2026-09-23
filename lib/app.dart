import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:loop_mobile/core/theme/loop_scroll_behavior.dart';

import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/app/notifications/loop_notification_coordinator.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_coordinator.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_providers.dart';
import 'package:loop_mobile/app/session/loop_community_arrival.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/app/session/loop_communication_retirement.dart';
import 'package:loop_mobile/app/session/onboarding_sequence.dart';
import 'package:loop_mobile/app/session/post_auth_bootstrap_coordinator.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/app/session/wallet_provisioning_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_sheet.dart';
import 'package:loop_mobile/features/security/mfa/passkey_sheet.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/core/navigation/launch_route.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/loop_id_setup_screen.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/features/account/privy_otp_screen.dart';
import 'package:loop_mobile/features/account/wallet_create_step_screen.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/chat.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_ai_screen.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/market/market.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/blocklist_screen.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/public_profile_sheet.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/features/shell/loop_pending_surface.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/features/wallet/wallet_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_coordinator.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_attachments.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_composer.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_presence.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/widgets/loop_page_recovery.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show
        StreamChat,
        StreamChatConfigurationData,
        StreamComponentBuilders,
        StreamMessageListViewConfiguration,
        streamChatComponentBuilders;

final _loopStreamComponentBuilders = StreamComponentBuilders(
  // C-15 (1): a LOOP message is plain text, not a markdown document. Stream's
  // own renderer doubles every newline into a paragraph break and eats `|`,
  // `*` and `_`; this one prints what the member typed, on band 4.
  messageText: loopStreamMessageTextBuilder,
  extensions: streamChatComponentBuilders(
    // S45: a member may send pictures. The composer is the official one,
    // behind LOOP's own gate — images only, four formats, 10 MB each, nine per
    // message — and LOOP's refusal copy. Voice recording stays off: LOOP has
    // proven no recording capability and claims none.
    messageComposer: (context, props) => LoopChatImageComposer(props: props),
    messageItem: loopStreamGroupMessageItemBuilder,
    // S58c: the gutter LOOP reserves beside every bubble is drawn with the
    // label this surface resolved, on the Ink/Lime/Chalk ladder. Stream's own
    // leading would fall back to a gradient keyed to the account id.
    messageLeading: loopStreamMessageLeadingBuilder,
    mentionItem: loopStreamGroupMentionItemBuilder,
    // Decision 0065: LOOP prints a 24-hour clock, so the footer's timestamp
    // no longer follows Jiffy's locale-driven 12-hour format.
    messageFooter: loopStreamMessageFooterBuilder,
    // C-15 (2): the prototype's `.msg-who` sits above the bubble, beside the
    // avatar — not in the metadata row under it.
    messageHeader: loopStreamMessageHeaderBuilder,
    // S45: a picture that will not load says so in Chinese instead of
    // printing the CDN address it failed to fetch, and is bounded by LOOP's
    // own ceiling rather than Stream's.
    imageAttachment: loopStreamImageAttachmentBuilder,
    galleryAttachment: loopStreamGalleryAttachmentBuilder,
    // S45: the full-screen view is LOOP chrome over Stream's zoom and paging.
    // Stream's own viewer offers share and save, which download through a Dio
    // client LOOP does not own; neither capability is proven, so neither is
    // offered.
    mediaGalleryPreview: loopStreamMediaGalleryPreviewBuilder,
  ),
);

/// The configuration every official Stream widget in LOOP reads.
final loopStreamChatConfiguration = StreamChatConfigurationData(
  messagePreviewFormatter: const LoopStreamTokenCardMessagePreviewFormatter(),
  attachmentBuilders: const <LoopStreamTokenCardAttachmentBuilder>[
    LoopStreamTokenCardAttachmentBuilder(),
  ],
  // Stream's draft feature writes the composer's contents to the provider on
  // every keystroke and restores them the next time the channel is opened.
  // LOOP never designed for either half. On the device it meant walking into
  // a group and finding a bare `@` left over from an earlier visit, which
  // opens the whole candidate list on the first tap of the field and is one
  // stray tap away from sending somebody a message they did not write
  // (device report 2026-09-20 · R15-5). And what it restores cannot be
  // trusted anyway: a LOOP `@` is a channel-scoped name, and the stored
  // draft carries no roster to read it back with.
  //
  // So a conversation opens with an empty composer. Nothing a member typed
  // and did not send leaves the device, and nothing from an earlier visit
  // comes back. Text typed in one visit is lost when the page is left — LOOP
  // has no local draft store of its own, and this is the honest cost.
  draftMessagesEnabled: false,
  messageListViewConfiguration: const StreamMessageListViewConfiguration(
    // The floating day pill is off. It is drawn over the thread rather than
    // in it — in `dm` it half-covered the first bubble — and the day it names
    // is read off whichever item the viewport happens to anchor on, offset by
    // the list's own special rows
    // (`floating_date_divider.dart:71`, `messageIndex = index - 2`). Three
    // visits to the same screen of messages printed 周一, 周四 and 今天 on
    // 2026-09-23, and only the first was right.
    //
    // The inline divider stays: it is built from one message's own
    // `createdAt.toLocal()` (`message_list_view.dart:1068`), it sits between
    // the two days it separates, and it scrolls with them.
    showFloatingDateDivider: false,
  ),
);

class LoopApp extends ConsumerStatefulWidget {
  const LoopApp({super.key});

  @override
  ConsumerState<LoopApp> createState() => _LoopAppState();
}

class _LoopAppState extends ConsumerState<LoopApp> {
  late final GoRouter router;
  late final LoopNotificationCoordinator notificationCoordinator;
  late final LoopPushRegistrationCoordinator pushRegistrationCoordinator;
  late final PostAuthBootstrapCoordinator postAuthBootstrapCoordinator;
  late final PostAuthProfileRedirectCoordinator postAuthProfileCoordinator;
  late final LoopV2MetaObserver metaObserver;
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<void>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // D0 metadata is a startup observation, not an authentication or feature
    // gate. Keeping the subscription alive starts both public reads while an
    // AsyncError remains isolated inside Riverpod and cannot block routing.
    ref.listenManual(
      loopV2MetaSnapshotProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    // Decision 0064: the observation may now recover from a cold start that
    // hit a dead network. The observer never gates login or routing; it only
    // re-arms a read that already failed.
    metaObserver = ref.read(loopV2MetaObserverProvider);
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        metaObserver.observe(LoopV2MetaObservationTrigger.appResumed);
        // The owner may have added or removed a screen lock while LOOP was
        // away, and the lock's window is measured from the moment it left.
        final lock = ref.read(loopAppLockProvider.notifier);
        lock.onEnteredForeground();
        unawaited(lock.refreshCapability());
        // A registration that stopped at a condition which has since become
        // true — the account was accepted while LOOP was away, the owner
        // turned notifications on in the system settings — has nobody else
        // to re-ask it. An account already registered asks the provider for
        // nothing, and a refusal is only ever *read* again, never put to the
        // owner a second time.
        pushRegistrationCoordinator.onIdentityMayHaveChanged();
      },
      // `onHide` is the outbound half of the pair: `onInactive` also fires on
      // the way back, and marking there would reset the window on return.
      onHide: () => ref.read(loopAppLockProvider.notifier).onLeftForeground(),
    );
    // Reading the lock is a device question and never waits on a session: a
    // locked App is not readable whether or not anybody is signed in.
    unawaited(ref.read(loopAppLockProvider.notifier).load());
    _connectivitySubscription = ref
        .read(loopConnectivitySignalProvider)
        .onRestored
        .listen((_) {
          metaObserver.observe(
            LoopV2MetaObservationTrigger.connectivityRestored,
          );
          // C-30 (3): the SDK reconnects a connection it once had. One that
          // never opened — the device was offline when the session was
          // accepted — has nothing to resume, and the owner would stay
          // invisible to 在线人数 for the rest of the run. Re-attempting on a
          // restored link costs no token when the user is already connected:
          // `authorize` answers from `connectedUserId` before asking for one.
          unawaited(
            connectStreamChatForPresence(
              authorizer: ref.read(streamChatSdkSessionProvider)?.authorizer,
              principalKey: ref.read(streamChatPrincipalKeyProvider),
            ),
          );
        });
    router = _buildRouter(
      () => ref.read(loopSessionProvider),
      () => ref.read(loopProfileLandingProvider),
      () => ref.read(loopOnboardingSequenceProvider),
      ref.read(loopRoutingErrorLogProvider),
      () => metaObserver.observe(LoopV2MetaObservationTrigger.navigation),
      _onProductFrameDrawn,
    );
    // The device registration and the notification ingress are separate
    // owners of the same provider: one says where a message could arrive, the
    // other says what to do with one that did.
    pushRegistrationCoordinator = ref.read(
      loopPushRegistrationCoordinatorProvider,
    );
    notificationCoordinator = LoopNotificationCoordinator(
      source: ref.read(loopNotificationEventSourceProvider),
      readSession: () => ref.read(loopSessionProvider),
      readBootstrapSession: () => ref.read(loopBootstrapSessionProvider),
      navigate: (intent) => router.go(intent.location),
      // Decision 0067: the push payload is a pointer, never a result. Before
      // anything opens, the notification is looked up again in *this*
      // account's feed, and the destination comes from that record. A pointer
      // this account cannot see resolves to a page that names nothing.
      resolveContext: (pointer) => _resolveNotificationContext(ref, pointer),
    );
    postAuthBootstrapCoordinator = PostAuthBootstrapCoordinator(() async {
      // Riverpod invalidates principal-dependent providers after publishing
      // the session state. Yield once so this read cannot observe the retired
      // signed-out bootstrap owner.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final authorization = await ref
          .read(loopBootstrapSessionProvider)
          ?.authorize();
      // Decision 0063: the embedded wallet is created once the LOOP session
      // exists, so the login page's promise holds without the owner having to
      // find a button. A wallet that cannot be created is a wallet fact and
      // never rolls the session back, so the result is deliberately dropped
      // here and read from the provisioning state instead.
      if (!mounted || authorization != LoopBootstrapAuthorization.authorized) {
        return;
      }
      // S73: this is the moment the LOOP identity behind the session starts
      // to exist, and until it does the push registration has no account it
      // may name. The session listener already ran — before the bootstrap
      // was asked for — and the bootstrap provider publishes one owner
      // object whose identity is filled in afterwards, so nothing else ever
      // told the coordinator to look again and no device got as far as the
      // permission prompt.
      pushRegistrationCoordinator.onIdentityMayHaveChanged();
      notificationCoordinator.onIdentityMayHaveChanged();
      // C-30 (3): 在线人数 counts the members connected to Stream right now
      // (decision 0047). Connecting here — not on the first chat page — is
      // what makes an open App count as online. It reports nothing and is
      // never awaited by the wallet step below, so a refused or offline
      // connection cannot delay or fail anything the owner asked for.
      unawaited(
        connectStreamChatForPresence(
          authorizer: ref.read(streamChatSdkSessionProvider)?.authorizer,
          principalKey: ref.read(streamChatPrincipalKeyProvider),
        ),
      );
      await ref.read(loopWalletProvisioningProvider.notifier).ensureWallet();
    });
    postAuthProfileCoordinator = PostAuthProfileRedirectCoordinator(
      readProfile: () async {
        // Riverpod rotates principal-scoped gateways after publishing the
        // session; yield once so this read cannot use a retired owner.
        await Future<void>.delayed(Duration.zero);
        return ref.read(profileGatewayProvider).load();
      },
      // F1: the opening sequence's position is read before the landing is
      // published, so the launch gate opens on a position that already
      // exists. Reading it afterwards let the router see "pending, nowhere
      // to be yet" and put a page on screen the sequence then replaced.
      prepare: (landing) async {
        if (!mounted || landing != LoopProfileLanding.loopIdSetup) return;
        await _beginOnboardingSequence();
      },
      publish: (landing, kind) {
        if (!mounted) return;
        final controller = ref.read(loopProfileLandingProvider.notifier);
        if (landing == null) {
          controller.reset();
          return;
        }
        controller.publish(landing, kind: kind);
      },
      navigate: (landing) {
        if (!mounted) return;
        // The server calling the profile active is the only thing that ends
        // the opening sequence, and it ends it for good.
        if (landing == LoopProfileLanding.community) {
          // Decision 0076: the end of the opening is also an arrival, and on
          // this path it is the first one this account has made.
          _onCommunityArrival();
          unawaited(
            ref
                .read(loopOnboardingSequenceProvider.notifier)
                .complete(
                  principalKey: ref
                      .read(loopSessionProvider)
                      .account
                      ?.privyUserId,
                ),
          );
          return;
        }
        if (landing != LoopProfileLanding.loopIdSetup) return;
        // Only lift an owner out of the credential, launch or landing pages.
        // A deep link the owner opened deliberately is never interrupted.
        const liftable = <String>{
          '/auth',
          '/auth/otp',
          '/community',
          '/splash',
        };
        final location = router.state.matchedLocation;
        if (liftable.contains(location)) _goToOnboardingStep();
      },
    );
    // The banner the failed check raises is the only surface that reports it,
    // so it is also the only one that can ask for the read again. The
    // coordinator keeps ownership of the read; the controller only knows how
    // to start it.
    ref
        .read(loopProfileLandingProvider.notifier)
        .bindRecheck(postAuthProfileCoordinator.resolve);
    // F1: the landing is dropped before the router hears about the session,
    // so a refresh can never re-read the previous account's answer and draw
    // one product frame with it.
    ref.listenManual<LoopSessionState>(loopSessionProvider, (previous, next) {
      postAuthProfileCoordinator.onSessionChanged(previous, next);
      if (previous?.mode != next.mode) router.refresh();
      notificationCoordinator.onIdentityMayHaveChanged();
      pushRegistrationCoordinator.onIdentityMayHaveChanged();
      postAuthBootstrapCoordinator.onSessionChanged(previous, next);
      // Leaving the account drops the in-memory position only. The stored
      // one survives, so signing in again as the same pending account
      // resumes on the step it stopped on.
      if (next.mode == LoopSessionMode.signedOut ||
          next.mode == LoopSessionMode.preview) {
        ref.read(loopOnboardingSequenceProvider.notifier).leave();
        // The next account on this device has not arrived anywhere yet, and
        // must be asked about notifications on its own arrival.
        ref.read(loopCommunityArrivalProvider.notifier).leave();
      }
    });
    // The launch gate reads the landing and the opening position, so a change
    // in either may need the redirect to run again. Neither listener decides
    // anything itself; they only let the router ask.
    //
    // Both are deliberately narrow. A refresh rebuilds the match list from
    // the current location, which flattens a stack the owner pushed — the
    // opening sequence walks 02 … 05 with push and pop, and a detail page
    // opened from a tab is nobody's business but the tab's. So the router is
    // only asked again where the answer actually changes where it belongs.
    ref.listenManual<LoopProfileLandingState>(loopProfileLandingProvider, (
      previous,
      next,
    ) {
      if (next.landing == LoopProfileLanding.community) _onCommunityArrival();
      if (previous?.landing == next.landing) return;
      // Losing the answer has to move the owner off whatever product page the
      // previous one allowed; gaining it only ever moves a page that was
      // waiting for it.
      const waiting = <String>{'/splash', '/auth', '/auth/otp'};
      if (next.isUnknown || waiting.contains(router.state.matchedLocation)) {
        router.refresh();
      }
    });
    ref.listenManual<LoopOnboardingSequenceState>(
      loopOnboardingSequenceProvider,
      (previous, next) {
        if (previous?.step == next.step) return;
        if (router.state.matchedLocation != '/splash') return;
        router.refresh();
      },
    );
    ref.listenManual(loopBootstrapSessionProvider, (previous, next) {
      if (!identical(previous, next)) {
        notificationCoordinator.onIdentityMayHaveChanged();
        pushRegistrationCoordinator.onIdentityMayHaveChanged();
      }
    });
    // The capability document is observed on its own schedule, and a device
    // that was signed in before it arrived would otherwise stay unregistered
    // with nothing left to re-ask it. Only the answer changing matters; the
    // coordinator decides again whether anything is due.
    ref.listenManual<LoopCapabilityProjection>(
      loopCapabilityProvider(LoopV2CapabilityId.pushNotifications),
      (previous, next) {
        if (previous?.isAvailable == next.isAvailable) return;
        pushRegistrationCoordinator.onIdentityMayHaveChanged();
      },
    );
    notificationCoordinator.start();
    pushRegistrationCoordinator.start();
  }

  /// Marks this account's arrival in Community, once per session.
  ///
  /// Decision 0076: this is the moment the device is asked about
  /// notifications. The signal is the landing `GET /v2/profile` produced,
  /// not a location — an account whose answer is Community has arrived
  /// whether the router put it on the tab or on a conversation somewhere
  /// under it, and a location string would miss the second one entirely.
  ///
  /// It is called from both places the answer can become Community: the
  /// landing the profile read publishes, and the end of the five-step
  /// opening. Either order works and neither can double the prompt, because
  /// only the first call marks the arrival.
  ///
  /// Both of those places run *before* the frame that draws Community, so
  /// this is only half of an arrival: the other half is
  /// [_onProductFrameDrawn], and whichever of the two happens second is the
  /// moment the device is asked.
  void _onCommunityArrival() {
    if (!mounted) return;
    if (!ref.read(loopCommunityArrivalProvider.notifier).landed()) return;
    pushRegistrationCoordinator.onIdentityMayHaveChanged();
  }

  /// A product page has been drawn. The other half of the arrival: without
  /// it the landing is only a statement about where the account belongs, and
  /// acting on it raises the dialog over the page the owner is still looking
  /// at — the launch page on a restored session, 创建 LOOP ID at the end of
  /// the opening.
  void _onProductFrameDrawn() {
    if (!mounted) return;
    if (!ref.read(loopCommunityArrivalProvider.notifier).productDrawn()) return;
    pushRegistrationCoordinator.onIdentityMayHaveChanged();
  }

  /// Puts the five-step account sequence on the step this account is on.
  ///
  /// The position comes from device storage, so killing the process and
  /// reopening continues where the owner stopped instead of restarting at
  /// 02. It is only ever reached from a `GET /v2/profile` read that answered
  /// `pending`; an active account cannot enter here. It navigates nowhere:
  /// the landing has not been published yet when this runs, and the launch
  /// gate would send any navigation straight back.
  Future<void> _beginOnboardingSequence() async {
    final principal = ref.read(loopSessionProvider).account?.privyUserId ?? '';
    if (principal.trim().isEmpty) return;
    await ref.read(loopOnboardingSequenceProvider.notifier).begin(principal);
  }

  /// Sends the owner to the step the sequence is on.
  ///
  /// A sequence that could not be opened at all — an account with no
  /// principal to partition a position by — lands in Community instead of
  /// leaving the owner on the launch page with nothing coming.
  void _goToOnboardingStep() {
    final step = ref.read(loopOnboardingSequenceProvider).step;
    router.go(
      step == null
          ? LoopRouteManifest.defaultPath
          : LoopRouteManifest.pathFor(step.slug),
    );
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    unawaited(notificationCoordinator.dispose());
    unawaited(pushRegistrationCoordinator.dispose());
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streamSession = ref.watch(streamChatSdkSessionProvider);
    final reduceMotion = ref.watch(
      loopDisplayPreferencesProvider.select(
        (preferences) => preferences.reduceMotion,
      ),
    );
    return MaterialApp.router(
      title: 'LOOP',
      debugShowCheckedModeBanner: false,
      // The official Stream widgets are the only localized surface in the
      // app; every LOOP page writes its Chinese copy directly. The delegate
      // answers for any locale, so the application locale — and with it
      // `MaterialLocalizations` — stays the framework default.
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        LoopStreamChatLocalizationsDelegate(),
      ],
      theme: LoopTheme.dark,
      darkTheme: LoopTheme.dark,
      themeMode: ThemeMode.dark,
      scrollBehavior: const LoopScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();
        if (reduceMotion && !MediaQuery.disableAnimationsOf(context)) {
          content = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: content,
          );
        }
        if (streamSession != null) {
          // Decision 0065: Stream 10.3 resolves its palette from a
          // `StreamTheme` theme extension that `StreamChat` reads off the
          // ambient Material theme, so the Lime Ledger tokens are injected
          // here, one level above the official widgets.
          final theme = Theme.of(context);
          content = Theme(
            data: theme.copyWith(
              extensions: [
                ...theme.extensions.values,
                loopStreamTheme(platform: theme.platform),
              ],
            ),
            child: StreamChat(
              key: ObjectKey(streamSession.client),
              client: streamSession.client,
              themeData: loopStreamChatThemeData(),
              configData: loopStreamChatConfiguration,
              componentBuilders: _loopStreamComponentBuilders,
              child: content,
            ),
          );
        }
        // The voice room the account is still in outlives the page it was
        // opened from: going back only puts it behind whatever the reader
        // does next. One strip above the router says so on every surface
        // except the room itself, and takes the reader back in one tap.
        content = Column(
          children: <Widget>[
            VoiceRoomMinimizedBanner(
              onOpen: (communityId) => router.push(
                '/chat/voice?id=${Uri.encodeComponent(communityId)}',
              ),
              // The strip is above the router, so it cannot read the tab
              // bar's scope for itself; the route the router is on says
              // whether a toast it raises has a bar to clear.
              onTabRoute: () =>
                  LoopRouteManifest.isTabPath(router.state.matchedLocation),
            ),
            Expanded(child: content),
          ],
        );
        // One toast host above the router: fixed above the tab bar, z 90.
        // The recovery scope sits above it so every page — including one whose
        // whole body is a block — can offer the read again. It re-arms the
        // public capability observation, which is the read that leaves a page
        // unreachable in the first place; it starts no product request and
        // decides nothing about what the answer means.
        // The curtain is above every LOOP surface and below nothing — the
        // toast host included, because a toast that outlived the moment the
        // lock closed would print a line of the App over its own cover. It
        // is drawn over the App rather than replacing it, so unlocking
        // returns the owner to the page they were on.
        return LoopPageRecoveryScope(
          retry: metaObserver.retryObservation,
          child: LoopAppLockGate(child: LoopToastHost(child: content)),
        );
      },
    );
  }
}

/// Chooses between the labelled Development Preview surface and the V2
/// production page for one chat route.
///
/// The Preview keeps its own fixture conversation, which decision 0025 binds
/// to an exact conversation ID; production never sees it. The two never share
/// a widget, so a fixture cannot leak into a server-backed surface.
Widget _chatSurface({
  required Widget Function() preview,
  required Widget Function() production,
}) => Consumer(
  builder: (context, ref, child) =>
      ref.watch(communicationGatewayProvider).mode == CommunicationMode.preview
      ? preview()
      : production(),
);

GoRouter _buildRouter(
  LoopSessionState Function() readSession,
  LoopProfileLandingState Function() readProfileLanding,
  LoopOnboardingSequenceState Function() readOnboarding,
  LoopRoutingErrorLog routingErrors, [
  VoidCallback? onNavigation,
  VoidCallback? onProductFrameDrawn,
]) {
  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      // Decision 0064: opening a page re-arms a D0 observation that failed.
      // The callback is single-flight inside the observer and never decides
      // this redirect, so routing stays independent of the observation.
      onNavigation?.call();
      final session = readSession();
      final location = state.matchedLocation;
      // Credential pages reachable before a verified session. Everything else
      // stays behind the gate.
      const signedOutRoutes = <String>{
        '/auth',
        '/auth/otp',
        '/auth/wallet',
        '/splash',
      };
      const credentialRoutes = <String>{'/auth', '/auth/otp'};
      if (!session.canEnterProduct) {
        return signedOutRoutes.contains(location) ? null : '/auth';
      }
      // F1: an accepted credential is not yet a place to be. Until
      // `GET /v2/profile` answers, the launch page is the only page a
      // verified session may draw — a pending account that saw Community
      // here was taken away from it a moment later (device report
      // 2026-09-21).
      if (loopPostAuthHoldsAtLaunch(
        session: session,
        landing: readProfileLanding(),
      )) {
        return location == '/splash' ? null : '/splash';
      }
      // The answer arrived: the launch page and the credential pages hand
      // the owner over to where the account actually belongs. An account
      // still opening goes to the step it is on, never through Community.
      if (credentialRoutes.contains(location) || location == '/splash') {
        final step = readOnboarding().step;
        return step == null
            ? '/community'
            : LoopRouteManifest.pathFor(step.slug);
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => '/community'),
      GoRoute(
        path: '/auth',
        builder: (context, state) => PrivyLoginScreen(
          onCodeSent: () => context.push(LoopRouteManifest.pathFor('auth-otp')),
        ),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) => PrivyOtpScreen(
            onBack: () {
              // Leaving the step abandons the pending code on purpose.
              ref.read(emailAuthProvider.notifier).changeEmail();
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go(LoopRouteManifest.pathFor('auth'));
              }
            },
          ),
        ),
      ),
      GoRoute(
        path: '/auth/loop-id',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            final sequence = ref.watch(loopOnboardingSequenceProvider);
            return LoopIdSetupScreen(
              // Step 05 can go back to 04 while the sequence is running.
              // Opened on its own it has nothing behind it, so it shows no
              // back action rather than an action that leads nowhere.
              onBack: sequence.isActive
                  ? () {
                      ref
                          .read(loopOnboardingSequenceProvider.notifier)
                          .moveTo(LoopOnboardingStep.security);
                      if (Navigator.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go(LoopRouteManifest.pathFor('security-setup'));
                      }
                    }
                  : null,
              onActivated: () {
                // Activation is what ends the sequence: the stored position
                // is dropped and Community replaces the whole stack, so no
                // back gesture can re-enter a finished opening. The account
                // the server just activated is also the landing every other
                // surface reads, so the pending answer is replaced here
                // rather than left for the next start to correct.
                ref
                    .read(loopProfileLandingProvider.notifier)
                    .publish(LoopProfileLanding.community);
                unawaited(
                  ref.read(loopOnboardingSequenceProvider.notifier).complete(),
                );
                context.go(LoopRouteManifest.defaultPath);
              },
            );
          },
        ),
      ),
      ShellRoute(
        // Decision 0076: the one place in LOOP that may say a product page is
        // actually on screen. Every tab and every page under one is drawn
        // inside this shell, and nothing above it can tell a router location
        // from a frame.
        builder: (context, state, child) => LoopProductFrameReporter(
          onDrawn: onProductFrameDrawn ?? () {},
          child: LoopShell(
            location: state.uri.path,
            child: Column(
              children: <Widget>[
                const LoopSoftUpdatePrompt(),
                const ProfileAvailabilityBanner(),
                Expanded(child: child),
              ],
            ),
          ),
        ),
        // Peer tabs fade. Every other route is pushed on the root navigator
        // and takes the platform's own push — Cupertino on iOS, predictive
        // back on Android — so the edge-swipe-back works on all of them
        // (decision 0085); nothing here may install a page transition of its
        // own over a route a user can return from.
        routes: <RouteBase>[
          GoRoute(
            path: '/community',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const CommunityScreen(),
            ),
          ),
          GoRoute(
            path: '/mining',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: MiningScreen(
                onOpenAssets: () =>
                    context.push(LoopRouteManifest.pathFor('mining-assets')),
                onOpenRewards: () =>
                    context.push(LoopRouteManifest.pathFor('mining-rewards')),
                onOpenRank: () =>
                    context.push(LoopRouteManifest.pathFor('mining-rank')),
                onOpenRules: () =>
                    context.push(LoopRouteManifest.pathFor('mining-rules')),
                onOpenReferral: () =>
                    context.push(LoopRouteManifest.pathFor('referral')),
                onOpenMarket: () =>
                    context.go(LoopRouteManifest.pathFor('market')),
              ),
            ),
          ),
          GoRoute(
            path: '/launch',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: LaunchScreen(
                onOpenLaunch: (launchId) =>
                    context.push(LaunchRoute.detail(launchId)),
                onOpenStake: () =>
                    context.push(LoopRouteManifest.pathFor('loop-stake')),
                onOpenRules: () =>
                    context.push(LoopRouteManifest.pathFor('launch-rounds')),
                onOpenEconomy: () =>
                    context.push(LoopRouteManifest.pathFor('loop-economy')),
                onOpenApply: () =>
                    context.push(LoopRouteManifest.pathFor('launch-apply')),
              ),
            ),
          ),
          GoRoute(
            path: '/market',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const MarketScreen(),
            ),
          ),
          GoRoute(
            path: '/wallet',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const WalletScreen(),
            ),
          ),
        ],
      ),
      GoRoute(path: '/home', redirect: (context, state) => '/community'),
      GoRoute(path: '/launchpad', redirect: (context, state) => '/launch'),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatInboxPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) =>
              _profileScreen(context, ref, 'profile'),
        ),
      ),
      ..._accountRoutes,
      GoRoute(
        path: '/search',
        builder: (context, state) => GlobalSearchScreen(
          initialQuery: state.uri.queryParameters['q'],
          onBack: () => _popOrHome(context),
          // A `publicProfile` result opens the shared public-profile sheet
          // inside the page; LOOP has no route for another account.
          onOpenCommunity: (communityId) =>
              context.push('/community/profile?id=$communityId'),
          onOpenDirectMessage: (identity) =>
              _openDirectMessageFromProfile(context, identity),
          // An `assetDetail` result carries the registry's own CAIP id, and
          // the token page is the one route that takes one.
          onOpenAsset: (assetId) =>
              context.push(MarketAssetRoute.token(assetId)),
        ),
      ),
      GoRoute(
        path: '/community/discover',
        builder: (context, state) => CommunityDiscoverScreen(
          joinedOnly: state.uri.queryParameters['membership'] == 'joined',
          onBack: () => _popOrHome(context),
          onOpenCommunity: (communityId) =>
              context.push('/community/profile?id=$communityId'),
        ),
      ),
      GoRoute(
        path: '/community/profile',
        builder: (context, state) => CommunityProfileScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
          onOpenMembers: (communityId) =>
              context.push('/community/members?id=$communityId'),
          onOpenChat: (communityId) =>
              context.push('/community/chat?id=$communityId'),
          onOpenAi: (communityId) =>
              context.push('/community/ai?id=$communityId'),
          onOpenVoiceRoom: (communityId) =>
              context.push('/chat/voice?id=$communityId'),
          onOpenMiningPanel: (communityId) =>
              context.push(MiningRoute.community(communityId)),
          onOpenToken: (assetId) =>
              context.push(MarketAssetRoute.token(assetId)),
          onOpenChart: (assetId) =>
              context.push(MarketAssetRoute.chart(assetId)),
        ),
      ),
      GoRoute(
        path: '/community/members',
        builder: (context, state) => CommunityMembersScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
          onOpenDirectMessage: (identity) =>
              _openDirectMessageFromProfile(context, identity),
        ),
      ),
      GoRoute(
        path: '/community/chat',
        builder: (context, state) => CommunityChatScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
          onOpenProfile: (communityId) =>
              context.push('/community/profile?id=$communityId'),
          onOpenVoiceRoom: (communityId) =>
              context.push('/chat/voice?id=$communityId'),
          onOpenSearch: (cid) =>
              context.push('/chat/search?cid=${Uri.encodeComponent(cid)}'),
          onOpenForward: (cid) =>
              context.push('/chat/forward?cid=${Uri.encodeComponent(cid)}'),
        ),
      ),
      GoRoute(
        path: '/community/ai',
        builder: (context, state) => CommunityAiScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
        ),
      ),
      // Manifest `networth` (legacy `/home/net-worth`, retired with Home).
      GoRoute(
        path: '/wallet/networth',
        builder: (context, state) =>
            NetWorthScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: MarketAssetRoute.tokenPath,
        builder: (context, state) => TokenDetailScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.tokenPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: MarketAssetRoute.chartPath,
        builder: (context, state) => FullChartScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.chartPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/market/new',
        builder: (context, state) =>
            NewPairsScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: MarketAssetRoute.holdersPath,
        builder: (context, state) => HolderDistributionScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.holdersPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: MarketAssetRoute.tradesPath,
        builder: (context, state) => TradingActivityScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.tradesPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/market/watchlist',
        builder: (context, state) =>
            WatchlistEditorScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: MarketAssetRoute.alertsPath,
        builder: (context, state) => PriceAlertsScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.alertsPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/market/smart-money',
        builder: (context, state) =>
            SmartMoneyScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/chat/groups/create',
        builder: (context, state) => const CreateFriendGroupPage(),
      ),
      GoRoute(
        path: '/chat/groups/:groupId/alias',
        builder: (context, state) => GroupAliasRoutePage(
          routeGroupId: state.pathParameters['groupId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/chat/group',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
            surfaceLabel: 'Group conversation',
            child: GroupChatPage(
              conversationId:
                  PreviewConversationIdentity.readSingleConversationId(
                    state.uri,
                  ) ??
                  '',
            ),
          ),
          production: () => GroupChatScreen(
            channelCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
            onOpenInfo: (cid) => context.push(
              '/chat/group-info?cid=${Uri.encodeComponent(cid)}',
            ),
            onOpenSearch: (cid) =>
                context.push('/chat/search?cid=${Uri.encodeComponent(cid)}'),
            onOpenForward: (cid) =>
                context.push('/chat/forward?cid=${Uri.encodeComponent(cid)}'),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/dm',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
            surfaceLabel: 'Direct conversation',
            child: DirectMessagePage(
              conversationId:
                  PreviewConversationIdentity.readSingleConversationId(
                    state.uri,
                  ) ??
                  '',
            ),
          ),
          production: () => DirectMessageScreen(
            target: state.extra is DirectMessageTarget
                ? state.extra! as DirectMessageTarget
                : null,
            channelCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/voice',
        builder: (context, state) => _chatSurface(
          preview: () => const VoiceRoomPage(),
          production: () => VoiceRoomScreen(
            communityId: state.uri.queryParameters['id'],
            onBack: () => _popOrHome(context),
            onOpenExpanded: (id) => context.push('/chat/voice/full?id=$id'),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/voice/full',
        builder: (context, state) => _chatSurface(
          preview: () => const VoiceRoomPage(),
          production: () => VoiceRoomScreen(
            communityId: state.uri.queryParameters['id'],
            expanded: true,
            onBack: () => _popOrHome(context),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/group-info',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
            surfaceLabel: 'Group information',
            child: GroupInfoPage(
              conversationId:
                  PreviewConversationIdentity.readSingleConversationId(
                    state.uri,
                  ) ??
                  '',
            ),
          ),
          production: () => GroupInfoScreen(
            channelCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
            onLeft: () => context.go('/community'),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/requests',
        builder: (context, state) =>
            MessageRequestsScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/chat/search',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
            surfaceLabel: 'Message search',
            child: MessageSearchPage(
              key: ValueKey<String>('preview-message-search-${state.uri}'),
              conversationId:
                  PreviewConversationIdentity.hasConversationIdQuery(state.uri)
                  ? PreviewConversationIdentity.readSingleConversationId(
                          state.uri,
                        ) ??
                        ''
                  : null,
            ),
          ),
          production: () => ChatSearchScreen(
            key: ValueKey<String>('chat-search-${state.uri}'),
            originCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
            onOpen: (cid) {
              final location = loopChatLocationForCid(cid);
              if (location != null) context.push(location);
            },
          ),
        ),
      ),
      GoRoute(
        path: '/chat/forward',
        builder: (context, state) => ChatForwardScreen(
          sourceCid: state.uri.queryParameters['cid'],
          onBack: () => _popOrHome(context),
          onOpenMergePreview: () => context.push('/chat/merge-preview'),
        ),
      ),
      GoRoute(
        path: '/chat/merge-preview',
        builder: (context, state) =>
            ChatMergePreviewScreen(onBack: () => _popOrHome(context)),
      ),
      // Compatibility deep link for installed clients and notification
      // payloads: a channel CID resolves to the surface its LOOP-assigned
      // prefix names, and an unknown shape falls through to the unmatched
      // handler rather than opening a generic channel page.
      GoRoute(
        path: '/chat/channel/:cid',
        redirect: (context, state) =>
            loopChatLocationForCid(state.pathParameters['cid'] ?? '') ??
            routingErrors.record(state.uri.toString()),
      ),
      GoRoute(
        path: '/preview/token-card',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Token card preview',
          child: TokenCardPreviewPage(),
        ),
      ),
      GoRoute(
        path: '/preview/contract-facts',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Contract facts preview',
          child: ContractFactsPreviewPage(),
        ),
      ),
      GoRoute(
        path: '/preview/asset-message',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Asset message preview',
          child: AssetMessagePreviewPage(),
        ),
      ),
      GoRoute(
        path: MarketAssetRoute.walletAssetPath,
        builder: (context, state) => WalletAssetScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.walletAssetPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/send',
        builder: (context, state) =>
            SendAssetScreen(onBack: () => _popOrHome(context)),
      ),
      // The Send draft travels as typed navigation state: an asset, a wallet
      // and the exact text the owner typed never belong in a URL.
      GoRoute(
        path: '/wallet/send/to',
        redirect: (context, state) =>
            state.extra is SendDraft ? null : '/wallet/send',
        builder: (context, state) => SendRecipientScreen(
          draft: state.extra! as SendDraft,
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/send/confirm',
        redirect: (context, state) {
          final draft = state.extra;
          return draft is SendDraft && draft.isComplete ? null : '/wallet/send';
        },
        builder: (context, state) => SendConfirmScreen(
          draft: state.extra! as SendDraft,
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: WalletRoute.receivePath,
        builder: (context, state) => ReceiveScreen(
          walletId: WalletRoute.parse(state.uri, WalletRoute.receivePath),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/swap',
        builder: (context, state) =>
            SwapScreen(onBack: () => _popOrHome(context)),
      ),
      // The quote object itself travels to the detail page, so the read-only
      // view can never show a different quote from the one being confirmed.
      GoRoute(
        path: '/wallet/swap/route',
        redirect: (context, state) =>
            state.extra is LoopSwapQuoteView ? null : '/wallet/swap',
        builder: (context, state) => SwapRouteScreen(
          quote: state.extra! as LoopSwapQuoteView,
          onBack: () => _popOrHome(context),
        ),
      ),
      // D21: `bridge` and `bridge-status` are entry points only. The status
      // page is reachable on its own because there is nothing to carry into
      // it: all three steps are pending and none of them has a source.
      GoRoute(
        path: '/wallet/bridge',
        builder: (context, state) => BridgeScreen(
          onBack: () => _popOrHome(context),
          onOpenStatus: () => context.push('/wallet/bridge/status'),
        ),
      ),
      GoRoute(
        path: '/wallet/bridge/status',
        builder: (context, state) => BridgeStatusScreen(
          onBack: () => _popOrHome(context),
          onOpenWallet: () => context.go(LoopRouteManifest.pathFor('wallet')),
        ),
      ),
      // Manifest `tx-result` (legacy `/wallet/transaction`). The intent id is
      // an opaque server id and is the only thing this page needs, so it may
      // travel in the query and survive a cold restore.
      GoRoute(
        path: '/wallet/tx/result',
        builder: (context, state) => TransactionResultScreen(
          intentId: _intentIdOf(state.uri),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: WalletRoute.historyPath,
        builder: (context, state) => TransactionHistoryScreen(
          walletId: WalletRoute.parse(state.uri, WalletRoute.historyPath),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/manage',
        builder: (context, state) =>
            WalletManagerScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/wallet/dapp',
        builder: (context, state) =>
            DappReviewScreen(onBack: () => _popOrHome(context)),
      ),
      // Manifest `approval-guard` (legacy `/preview/approval`). The guard is a
      // real money action now, so it lives under `/wallet`.
      GoRoute(
        path: '/wallet/approval-guard',
        redirect: (context, state) =>
            state.extra is ApprovalGuardRequest ? null : '/wallet/approvals',
        builder: (context, state) => ApprovalGuardScreen(
          request: state.extra! as ApprovalGuardRequest,
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/approvals',
        builder: (context, state) =>
            ApprovalsScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/wallet/networks',
        builder: (context, state) =>
            NetworksScreen(onBack: () => _popOrHome(context)),
      ),
      ..._profileRoutes,
      GoRoute(
        path: '/profile/connections',
        builder: (context, state) => ConnectionsScreen(
          onBack: () => _popOrHome(context),
          // The identity travels as typed navigation state, never in the URL:
          // a deep link must not be able to put an unverified alias in the
          // conversation header. It does have to travel, though — until R14-3
          // this call passed the id alone, so `DirectMessageTarget.identity`
          // was null at the only place in the product that constructs one and
          // every conversation opened under the literal 「私聊」 with no `@`
          // candidates at all.
          onOpenConversation: (profile) {
            final publicProfileId = profile.publicProfileId;
            if (publicProfileId == null) return;
            context.push(
              '/chat/dm',
              extra: DirectMessageTarget(
                publicProfileId: publicProfileId,
                identity: profile,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/profile/blocked',
        builder: (context, state) =>
            BlocklistScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/profile/referral',
        builder: (context, state) => ReferralScreen(
          onBack: () => _popOrHome(context),
          onOpenMining: () => context.go(LoopRouteManifest.pathFor('mining')),
        ),
      ),
      ..._systemRoutes,
      // Manifest `pay`: reached from Wallet, unavailable with the server's own
      // `PAY_RUNTIME_DEFERRED` (fail closed).
      GoRoute(
        path: '/pay',
        builder: (context, state) =>
            PayScreen(onBack: () => _popOrHome(context)),
      ),
      ..._launchRoutes,
      ..._miningRoutes,
      ..._pendingManifestRoutes,
      // Illegal locations are recorded and land on Community.
      GoRoute(
        path: '/:unmatched(.*)',
        redirect: (context, state) {
          routingErrors.record(state.uri.toString());
          return '/community';
        },
      ),
    ],
    errorBuilder: (context, state) =>
        UnknownRouteScreen(location: state.uri.toString()),
  );
}

/// The eleven Launch pages. Each record page carries its subject as the exact
/// `launchId` query parameter produced by [LaunchRoute]; a missing or
/// malformed value fails closed into the page's unavailable state rather than
/// substituting another project.
final List<RouteBase> _launchRoutes = <RouteBase>[
  GoRoute(
    path: LaunchRoute.detailPath,
    builder: (context, state) => LaunchDetailScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.detailPath),
      onBack: () => _popOrHome(context),
      onOpenTier: () => _pushLaunchChild(context, state, LaunchRoute.tierPath),
      onOpenRounds: () =>
          _pushLaunchChild(context, state, LaunchRoute.roundsPath),
      onOpenTrade: () =>
          _pushLaunchChild(context, state, LaunchRoute.tradePath),
      onOpenHolders: () =>
          _pushLaunchChild(context, state, LaunchRoute.holdersPath),
      onOpenGraduation: () =>
          _pushLaunchChild(context, state, LaunchRoute.graduationPath),
      onOpenHistory: () =>
          _pushLaunchChild(context, state, LaunchRoute.historyPath),
    ),
  ),
  GoRoute(
    path: LaunchRoute.tierPath,
    builder: (context, state) => LaunchTierScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.tierPath),
      onBack: () => _popOrHome(context),
      onOpenStake: () => context.push(LoopRouteManifest.pathFor('loop-stake')),
    ),
  ),
  GoRoute(
    path: LaunchRoute.tradePath,
    builder: (context, state) => LaunchTradeScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.tradePath),
      onBack: () => _popOrHome(context),
      onOpenHolders: () =>
          _pushLaunchChild(context, state, LaunchRoute.holdersPath),
    ),
  ),
  GoRoute(
    path: LaunchRoute.holdersPath,
    builder: (context, state) => LaunchHoldersScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.holdersPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: LaunchRoute.graduationPath,
    builder: (context, state) => LaunchGraduationScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.graduationPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: LaunchRoute.historyPath,
    builder: (context, state) => LaunchHistoryScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.historyPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: LaunchRoute.roundsPath,
    builder: (context, state) => LaunchRoundsScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.roundsPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: '/launch/loop-stake',
    builder: (context, state) =>
        LoopStakeScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: '/launch/loop-economy',
    builder: (context, state) =>
        LoopEconomyScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: '/launch/apply',
    builder: (context, state) =>
        LaunchApplyScreen(onBack: () => _popOrHome(context)),
  ),
];

/// Carries the current page's launch identity to a sibling record page. When
/// the current location has no canonical identity the sibling is opened
/// without one and renders its own unavailable state.
void _pushLaunchChild(BuildContext context, GoRouterState state, String path) {
  final launchId = LaunchRoute.parse(state.uri, state.uri.path);
  context.push(launchId == null ? path : LaunchRoute.location(path, launchId));
}

/// The five Mining child pages.
final List<RouteBase> _miningRoutes = <RouteBase>[
  GoRoute(
    path: '/mining/assets',
    builder: (context, state) => MiningAssetsScreen(
      onBack: () => _popOrHome(context),
      onOpenRules: () =>
          context.push(LoopRouteManifest.pathFor('mining-rules')),
    ),
  ),
  GoRoute(
    path: '/mining/rewards',
    builder: (context, state) =>
        MiningRewardsScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: '/mining/rank',
    builder: (context, state) =>
        MiningRankScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: MiningRoute.communityPath,
    builder: (context, state) => MiningCommunityScreen(
      communityId: MiningRoute.parse(state.uri, MiningRoute.communityPath),
      onBack: () => _popOrHome(context),
      onOpenRank: () => context.push(LoopRouteManifest.pathFor('mining-rank')),
    ),
  ),
  GoRoute(
    path: '/mining/rules',
    builder: (context, state) => MiningRulesScreen(
      onBack: () => _popOrHome(context),
      onOpenReferral: () => context.push(LoopRouteManifest.pathFor('referral')),
    ),
  ),
];

/// Every manifest slug without a dedicated screen mounts the pending surface,
/// so all 93 routes are reachable and none silently falls through.
final List<RouteBase> _pendingManifestRoutes =
    LoopRouteManifest.withStatus(LoopRouteStatus.pending)
        .map((entry) {
          return GoRoute(
            path: entry.path,
            builder: (context, state) => LoopPendingSurface(entry: entry),
          );
        })
        .toList(growable: false);

// Manifest 0-global-account pages with an existing screen. Onboarding, seed
// reveal/verify, wallet import and the old profile setup are retired.
final List<RouteBase> _accountRoutes =
    <(String, String)>[
          ('/splash', 'splash'),
          ('/auth/wallet', 'auth-wallet'),
          ('/auth/wallet/create', 'wallet-create'),
          ('/auth/wallet/backup', 'wallet-recovery'),
          ('/auth/security', 'security-setup'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  _accountScreen(context, ref, item.$2),
            ),
          );
        })
        .toList(growable: false);

/// What the launch page is doing for the session that is on it.
///
/// Three states, and only the first two are waits: holding for
/// `GET /v2/profile`, the read having ended with no answer, and the signed-out
/// brand frame.
LoopSplashPhase _splashPhase(WidgetRef ref) {
  final landing = ref.watch(loopProfileLandingProvider);
  if (loopPostAuthHoldsAtLaunch(
    session: ref.watch(loopSessionProvider),
    landing: landing,
  )) {
    return LoopSplashPhase.preparingAccount;
  }
  return landing.isUnavailable
      ? LoopSplashPhase.accountUnavailable
      : LoopSplashPhase.entry;
}

/// Account step pages. Every capability stays fail-closed: this composition
/// never asserts a wallet, recovery or protection capability it has not been
/// told about by the integration layer.
Widget _accountScreen(BuildContext context, WidgetRef ref, String id) {
  final config = ref.watch(appConfigProvider);
  final sequence = ref.watch(loopOnboardingSequenceProvider);
  final step = _onboardingStepFor(id);
  if (sequence.isActive && step != null) {
    return _onboardingStepScreen(context, ref, step, config);
  }
  void back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(LoopRouteManifest.pathFor('auth'));
    }
  }

  return AccountSurfaceScreen.fromId(
    id,
    capabilities: PrivyWalletCapabilities(
      canConnectExternalWallet: config.canConnectExternalWallet,
      // A passkey is offered only where this build has the domain credential
      // one belongs to. Without it the platform refuses every call, so the
      // row says what is missing instead of opening a sheet that cannot work.
      canUsePasskey: config.canUsePasskey,
    ),
    appLock: ref.watch(loopAppLockProvider),
    onToggleAppLock: () => unawaited(_toggleAppLock(ref)),
    mfa: _watchMfa(ref, id),
    onOpenMfa: () => unawaited(showLoopMfaSheet(context)),
    onOpenPasskey: () => unawaited(showLoopPasskeySheet(context)),
    // F1: the launch page is also the page a verified session waits on while
    // `GET /v2/profile` decides where it belongs. It says so instead of
    // offering a way in that leads nowhere.
    splashPhase: _splashPhase(ref),
    // A wait that ran past its ceiling ends here rather than in a rail that
    // keeps moving: the mark settles and the same reason the shell's banner
    // carries is stated on the page the owner is looking at.
    splashUnavailableReason:
        _splashPhase(ref) == LoopSplashPhase.accountUnavailable
        ? profileFailureReason(
            ref.watch(loopProfileLandingProvider).failureKind,
          )
        : null,
    onBack: back,
    onPrimaryAction: id == 'auth-wallet' && config.canConnectExternalWallet
        ? () => unawaited(
            ref.read(emailAuthProvider.notifier).connectExternalWallet(context),
          )
        : null,
    onNavigate: (destination) => context.go(_accountPath(destination)),
  );
}

/// The account's second factor, read once when 04 is mounted.
///
/// The read is started from the page that shows it rather than at start-up:
/// it costs a provider round trip, and nothing else in the product depends on
/// the answer. A page that is not 04 never asks.
LoopMfaState? _watchMfa(WidgetRef ref, String id) {
  // 03 asks the same question for a different reason: whether this account
  // already has a passkey it can get back in with.
  if (id != 'security-setup' && id != 'wallet-recovery') return null;
  final state = ref.watch(loopMfaProvider);
  if (state.phase == LoopMfaPhase.unknown) {
    Future<void>.microtask(() => ref.read(loopMfaProvider.notifier).load());
  }
  return state;
}

/// Turns the device-local lock on or off.
///
/// Both directions run the system's own prompt first, inside the controller.
/// This is only the wire from a row to it: the page decides nothing about
/// whether anybody was authenticated.
Future<void> _toggleAppLock(WidgetRef ref) {
  final controller = ref.read(loopAppLockProvider.notifier);
  return ref.read(loopAppLockProvider).enabled
      ? controller.disable()
      : controller.enable();
}

/// Which of the four opening steps a manifest slug renders, or `null` for a
/// page that is not part of the sequence.
LoopOnboardingStep? _onboardingStepFor(String id) => switch (id) {
  'wallet-create' => LoopOnboardingStep.walletCreate,
  'wallet-recovery' => LoopOnboardingStep.walletBackup,
  'security-setup' => LoopOnboardingStep.security,
  'loop-id-setup' => LoopOnboardingStep.loopId,
  _ => null,
};

/// The same account pages, mounted as the opening sequence.
///
/// The sequence exists because the prototype opens an account in five steps
/// and the product promised them: 01 verify, 02 wallet, 03 recovery, 04
/// protection, 05 LOOP ID. Routing straight to 05 — which is what shipped —
/// skipped three of them on a real first login (device report 2026-09-20).
///
/// 02 has no back action: the credential behind it is already accepted, so
/// there is no login page to return to. 03, 04 and 05 step back one page and
/// record the move, so a process killed there resumes on the same step.
Widget _onboardingStepScreen(
  BuildContext context,
  WidgetRef ref,
  LoopOnboardingStep step,
  AppConfig config,
) {
  final controller = ref.read(loopOnboardingSequenceProvider.notifier);

  void advance(LoopOnboardingStep next) {
    controller.moveTo(next);
    context.push(LoopRouteManifest.pathFor(next.slug));
  }

  void retreat(LoopOnboardingStep previous) {
    controller.moveTo(previous);
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(LoopRouteManifest.pathFor(previous.slug));
    }
  }

  return switch (step) {
    LoopOnboardingStep.walletCreate => WalletCreateStepScreen(
      onContinue: () => advance(LoopOnboardingStep.walletBackup),
    ),
    LoopOnboardingStep.walletBackup => AccountSurfaceScreen.fromId(
      'wallet-recovery',
      capabilities: PrivyWalletCapabilities(
        canConnectExternalWallet: config.canConnectExternalWallet,
        canUsePasskey: config.canUsePasskey,
      ),
      mfa: _watchMfa(ref, 'wallet-recovery'),
      onOpenPasskey: () => unawaited(showLoopPasskeySheet(context)),
      onBack: () => retreat(LoopOnboardingStep.walletCreate),
      onRecoveryDecision: (method) =>
          controller.recordRecoveryDecision(method?.name),
      onNavigate: (_) => advance(LoopOnboardingStep.security),
    ),
    LoopOnboardingStep.security => AccountSurfaceScreen.fromId(
      'security-setup',
      capabilities: PrivyWalletCapabilities(
        canConnectExternalWallet: config.canConnectExternalWallet,
      ),
      appLock: ref.watch(loopAppLockProvider),
      onToggleAppLock: () => unawaited(_toggleAppLock(ref)),
      mfa: _watchMfa(ref, 'security-setup'),
      onOpenMfa: () => unawaited(showLoopMfaSheet(context)),
      onBack: () => retreat(LoopOnboardingStep.walletBackup),
      onNavigate: (_) => advance(LoopOnboardingStep.loopId),
    ),
    // 05 is mounted by `/auth/loop-id`, which owns the activation call.
    LoopOnboardingStep.loopId => const UnknownAccountScreen(),
  };
}

// Manifest 7-profile pages with an existing screen. Copy permissions, seed
// backup and profile rewards are retired; `/profile/social-privacy` retired
// with V2 privacy (step 2).
final List<RouteBase> _profileRoutes =
    <(String, String)>[
          ('/profile/edit', 'profile-edit'),
          ('/profile/privacy', 'privacy'),
          ('/profile/security', 'security'),
          ('/profile/devices', 'devices'),
          ('/profile/key-export', 'key-export'),
          ('/profile/social-recovery', 'social-recovery'),
          ('/profile/notifications', 'notif-settings'),
          ('/profile/settings', 'settings'),
          ('/profile/about', 'about'),
          ('/profile/help', 'support'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  _profileScreen(context, ref, item.$2),
            ),
          );
        })
        .toList(growable: false);

// Manifest module 8 plus the two module-0 gates. `force-update` and
// `region-blocked` read the D0 client-policy projection; the component-state
// showcases read the preview-only showcase provider (null in production).
final List<RouteBase> _systemRoutes =
    <(String, String)>[
          ('/system/offline', 'offline'),
          ('/system/error', 'server-error'),
          ('/system/update', 'force-update'),
          ('/system/maintenance', 'maintenance'),
          ('/system/region', 'region-restricted'),
          ('/system/permission', 'permission'),
          ('/preview/toast', 'toast'),
          ('/preview/loading', 'loading'),
          ('/system/token-card', 'token-card-states'),
          ('/system/sign-sheet', 'sign-sheet-states'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  _systemSurface(context, ref, item.$2),
            ),
          );
        })
        .toList(growable: false);

Widget _systemSurface(BuildContext context, WidgetRef ref, String id) {
  final policy = ref.watch(loopV2MetaSnapshotProvider).value?.clientPolicy;
  final version = LoopClientPolicyProjection.version(
    policy,
    platform: defaultTargetPlatform,
    clientVersion: ref.watch(appConfigProvider).loopClientVersion,
  );
  final region = LoopClientPolicyProjection.region(policy);
  void returnToCommunity() => context.go(LoopRouteManifest.defaultPath);
  void back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      returnToCommunity();
    }
  }

  return SystemSurfaceScreen.fromId(
    id,
    onBack: back,
    onSecondaryAction: returnToCommunity,
    // The three state pages own real exits. 重试 has no request of its own
    // to repeat from here, so it returns to the page that opened this one —
    // that page reads again as it rebuilds; 联系客服 and 查看只读内容 are the
    // prototype's `data-go="support"` / `data-go="community"`.
    onRetry: back,
    onServiceRetry: back,
    onServiceSupport: () => context.go(LoopRouteManifest.pathFor('support')),
    onMaintenanceReadOnly: returnToCommunity,
    forceUpdateRequirement:
        version.decision == LoopVersionPolicyDecision.updateRequired
        ? LoopForceUpdateRequirement(
            forceUpdateBelow: version.forceUpdateBelow,
            minimumSupportedVersion: version.minimumVersion,
            configVersion: version.configVersion,
            storeUrl: version.storeUrl,
          )
        : null,
    featureAvailabilityRestriction:
        region.decision == LoopRegionPolicyDecision.blocked
        ? LoopFeatureAvailabilityRestriction(
            reasonCode: region.reasonCode,
            supportUrl: region.supportUrl,
            readOnlyAssetAccess: region.readOnlyAssetAccess,
          )
        : null,
    // The three prototype exits. They are wired only while the decision is
    // actually blocked, so an unknown region never grows an action.
    onRegionViewAssets: region.decision == LoopRegionPolicyDecision.blocked
        ? () => context.go(LoopRouteManifest.pathFor('wallet'))
        : null,
    onRegionExportKey: region.decision == LoopRegionPolicyDecision.blocked
        ? () => context.go(LoopRouteManifest.pathFor('key-export'))
        : null,
    onRegionSupport: region.decision == LoopRegionPolicyDecision.blocked
        ? () => context.go(LoopRouteManifest.pathFor('support'))
        : null,
    showcase: ref.watch(loopSystemShowcaseProvider),
  );
}

/// Pops when the page was pushed, otherwise lands on the manifest default.
/// The opaque intent id carried by `/wallet/tx/result?intentId=`.
///
/// A value that is not a canonical UUIDv4 is dropped rather than requested:
/// the result page then renders its empty state instead of asking the server
/// about an id a deep link invented.
String? _intentIdOf(Uri uri) {
  final value = uri.queryParameters['intentId'];
  if (value == null || !LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
    return null;
  }
  return value;
}

/// Opens the direct conversation the public-profile card asked for.
///
/// The prototype makes a member row, a global-search user row and a group
/// member row `dm` entries. LOOP puts the shared public-profile card in
/// between; this is where that card's control becomes the one route that
/// opens a conversation. The peer's own projection travels as typed
/// navigation state — never in the URL — so the header and the `@`
/// candidates name the same person the card drew (R15-1).
void _openDirectMessageFromProfile(
  BuildContext context,
  PublicProfileIdentity identity,
) {
  final publicProfileId = identity.publicProfileId;
  if (publicProfileId == null) return;
  context.push(
    '/chat/dm',
    extra: DirectMessageTarget(
      publicProfileId: publicProfileId,
      identity: identity.profile,
    ),
  );
}

void _popOrHome(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    context.pop();
  } else {
    context.go(LoopRouteManifest.defaultPath);
  }
}

Widget _profileScreen(BuildContext context, WidgetRef ref, String id) {
  final session = ref.watch(loopSessionProvider);
  final account = session.account;
  final identity = ProfileIdentity(
    alias: account == null
        ? (session.isPreview ? 'Development preview' : 'Restricted session')
        : 'Privy session',
    address: account?.wallet?.address ?? 'No wallet connected',
    bio: 'Bio is not part of the reviewed Profile presentation contract.',
    connections: 0,
    groups: 0,
    watchlistItems: 0,
  );
  void back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(LoopRouteManifest.defaultPath);
    }
  }

  return ProfileSurfaceScreen.fromId(
    id,
    identity: identity,
    onBack: back,
    onNavigate: (destination) {
      final path = _profilePath(destination);
      // Tab destinations replace the stack; only child pages push.
      if (LoopRouteManifest.isTabPath(path)) {
        context.go(path);
      } else {
        context.push(path);
      }
    },
    onSignOut: () => _signOut(ref),
  );
}

/// Re-reads the notification feed and answers what it says about [pointer].
///
/// `null` is the honest answer for every way this can fail to confirm: the
/// gateway is unavailable, the read failed, or the account signed in now has
/// no such notification. None of them authorises using the payload's own
/// `contextRoute`, and the caller falls back to a destination that carries no
/// identifier from it.
Future<LoopNotificationContext?> _resolveNotificationContext(
  WidgetRef ref,
  LoopNotificationPointer pointer,
) async {
  final gateway = ref.read(notificationsGatewayProvider);
  if (gateway.mode != LoopChainGatewayMode.production) return null;
  final LoopNotificationFeed feed;
  try {
    feed = await gateway.loadFeed();
  } catch (_) {
    return null;
  }
  for (final entry in feed.items) {
    if (entry.entityRef != pointer.entityRef) continue;
    return LoopNotificationContext(
      contextRoute: entry.contextRoute,
      assetId: entry.contextParams[MarketAssetRoute.assetParameter],
      communityId: entry.contextParams['communityId'],
    );
  }
  return null;
}

Future<void> _signOut(WidgetRef ref) async {
  // Both push registrations have to be dropped while the credentials that
  // created them still exist: LOOP's own revoke needs the session's access
  // token and Stream's `removeDevice` needs a connected user. Doing it after
  // `exit()` would leave this device addressable for the account that left it.
  // It is bounded; sign-out is the owner's decision and never waits on a
  // provider.
  await ref.read(loopPushRegistrationCoordinatorProvider).revokeForSignOut();
  final retirement = ref
      .read(loopCommunicationRetirementRegistryProvider)
      .capture();
  final bootstrapRepository = ref.read(loopBootstrapRepositoryProvider);
  final bootstrapQuiescence = bootstrapRepository is LoopV2BootstrapRepository
      ? bootstrapRepository.prepareForLogout()
      : Future<void>.value();
  final backend = ref.read(loopV2LogoutCoordinatorProvider);
  return ref
      .read(loopSessionProvider.notifier)
      .exit(
        revokeBackend: backend == null
            ? null
            : (principalKey) async {
                await bootstrapQuiescence;
                final result = await backend.logout(principalKey);
                return switch (result) {
                  LoopV2LogoutDisposition.notRequired =>
                    LoopBackendLogoutResult.notRequired,
                  LoopV2LogoutDisposition.confirmed =>
                    LoopBackendLogoutResult.confirmed,
                  LoopV2LogoutDisposition.unconfirmed =>
                    LoopBackendLogoutResult.unconfirmed,
                };
              },
        retireCommunications: retirement.retire,
      );
}

// Account screen destinations. Retired ids (onboarding, seed reveal/verify,
// wallet import) resolve to the nearest manifest page instead of a dead route.
String _accountPath(String id) => switch (id) {
  'splash' => LoopRouteManifest.pathFor('splash'),
  'onboarding' => LoopRouteManifest.pathFor('auth'),
  'auth' => LoopRouteManifest.pathFor('auth'),
  'auth-otp' => LoopRouteManifest.pathFor('auth-otp'),
  'auth-wallet' => LoopRouteManifest.pathFor('auth-wallet'),
  'wallet-create' => LoopRouteManifest.pathFor('wallet-create'),
  'wallet-recovery' => LoopRouteManifest.pathFor('wallet-recovery'),
  'security-setup' => LoopRouteManifest.pathFor('security-setup'),
  'loop-id-setup' => LoopRouteManifest.pathFor('loop-id-setup'),
  'profile-setup' => LoopRouteManifest.pathFor('loop-id-setup'),
  'community' => LoopRouteManifest.defaultPath,
  'home' => LoopRouteManifest.defaultPath,
  _ => LoopRouteManifest.pathFor('auth'),
};

/// Prefix of the one profile destination that carries a parameter.
const String _communityRecordDestination = 'community-profile:';

// Profile screen destinations. Copy permissions live inside Privacy, seed
// backup is replaced by the manifest `key-export` page and rewards by the
// Mining tab; none of the retired ids reaches a dead route.
String _profilePath(String id) => switch (id) {
  'profile' => LoopRouteManifest.pathFor('profile'),
  // `community-profile:<communityId>`: one created community's own record.
  // The 我创建的 group hands the id over rather than a page-less destination,
  // because `community-profile` addresses exactly one community and this is
  // the only place that knows which.
  final String scoped when scoped.startsWith(_communityRecordDestination) =>
    '${LoopRouteManifest.pathFor('community-profile')}?id='
        '${Uri.encodeQueryComponent(scoped.substring(_communityRecordDestination.length))}',
  // `/profile/friends` and `/chat/friends/add` were folded into `search`
  // and `connections` in step 3; step 4 folded the V1 request inbox into the
  // `dm-requests` page, so the profile row now opens that manifest slug.
  'friend-requests' => LoopRouteManifest.pathFor('dm-requests'),
  'wallets' => LoopRouteManifest.pathFor('wallets'),
  'community-discover' => LoopRouteManifest.pathFor('community-discover'),
  // Not a route of its own: the same manifest page narrowed to the owner's
  // memberships, which is what 我的社区 opens once the aggregate reports any.
  'community-joined' =>
    '${LoopRouteManifest.pathFor('community-discover')}?membership=joined',
  'launch-history' => LoopRouteManifest.pathFor('launch-history'),
  'launch-tier' => LoopRouteManifest.pathFor('launch-tier'),
  'profile-edit' => LoopRouteManifest.pathFor('profile-edit'),
  'privacy' => LoopRouteManifest.pathFor('privacy'),
  'social-privacy' => LoopRouteManifest.pathFor('privacy'),
  'copytrade-perms' => LoopRouteManifest.pathFor('privacy'),
  'security' => LoopRouteManifest.pathFor('security'),
  'devices' => LoopRouteManifest.pathFor('devices'),
  'key-export' => LoopRouteManifest.pathFor('key-export'),
  'social-recovery' => LoopRouteManifest.pathFor('social-recovery'),
  'networks' => LoopRouteManifest.pathFor('networks'),
  'notif-settings' => LoopRouteManifest.pathFor('notif-settings'),
  'connections' => LoopRouteManifest.pathFor('connections'),
  'blocklist' => LoopRouteManifest.pathFor('blocklist'),
  'settings' => LoopRouteManifest.pathFor('settings'),
  'about' => LoopRouteManifest.pathFor('about'),
  'support' => LoopRouteManifest.pathFor('support'),
  'mining' => LoopRouteManifest.pathFor('mining'),
  'referral' => LoopRouteManifest.pathFor('referral'),
  _ => LoopRouteManifest.pathFor('profile'),
};

class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Route not found',
      eyebrow: '404',
      subtitle: location,
      children: <Widget>[
        LoopStateCard(
          title: 'This location is not in the 93-route product map',
          message: 'Return to Community. The request has been recorded.',
          icon: Icons.route_outlined,
          tone: LoopTone.warning,
          action: FilledButton(
            onPressed: () => context.go(LoopRouteManifest.defaultPath),
            child: const Text('Go to Community'),
          ),
        ),
      ],
    );
  }
}
