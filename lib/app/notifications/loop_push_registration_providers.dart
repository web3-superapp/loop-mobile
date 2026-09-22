import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_coordinator.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/app/session/loop_community_arrival.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_push_device_registrar.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';

/// Where this device's push registration stopped.
///
/// One per application ProviderScope, and the only writer is the coordinator
/// below — except at startup, where `lib/main.dart` records a push provider
/// that could not be brought up at all, before this scope exists. That is why
/// the recorder is a value the entry point may override rather than something
/// the coordinator creates for itself.
final loopPushRegistrationDiagnosticsProvider =
    Provider<LoopPushRegistrationDiagnosticsRecorder>((ref) {
      final recorder = LoopPushRegistrationDiagnosticsRecorder();
      ref.onDispose(recorder.dispose);
      return recorder;
    });

/// The one push registration owner per application ProviderScope.
///
/// Reading it registers nothing: the coordinator asks the device for a
/// permission and the server for a registration only after [LoopApp] starts it
/// and an authenticated, backend-verified account exists.
final loopPushRegistrationCoordinatorProvider =
    Provider<LoopPushRegistrationCoordinator>((ref) {
      final metadata = ref.watch(loopV2ClientMetadataProvider);
      final coordinator = LoopPushRegistrationCoordinator(
        source: ref.watch(loopPushTokenSourceProvider),
        readGateway: () => ref.read(pushDeviceGatewayProvider),
        readStreamRegistrar: () {
          final session = ref.read(streamChatSdkSessionProvider);
          if (session == null) return null;
          return StreamChatPushDeviceRegistrar(session.client);
        },
        readPrincipalKey: () => _verifiedPrincipalKey(ref),
        // Availability, not usability: `pushNotifications` keeps
        // `PUSH_DEVICE_DELIVERY_EVIDENCE_PENDING` as pending evidence until a
        // real device has received a notification, and nothing can be
        // received before it is registered.
        readPushCapabilityAvailable: () => ref
            .read(loopCapabilityProvider(LoopV2CapabilityId.pushNotifications))
            .isAvailable,
        // Decision 0076: the permission is asked for at Community,
        // not at the moment the account becomes addressable.
        readCommunityReached: () => ref.read(loopCommunityArrivalProvider),
        platform: switch (metadata?.platform) {
          LoopV2Platform.android => LoopPushPlatform.android,
          LoopV2Platform.ios => LoopPushPlatform.ios,
          null => null,
        },
        diagnostics: ref.watch(loopPushRegistrationDiagnosticsProvider),
        appVersion: ref.watch(
          appConfigProvider.select(
            (config) => config.loopClientVersionForCurrentBuild,
          ),
        ),
      );
      ref.onDispose(() => unawaited(coordinator.dispose()));
      return coordinator;
    });

/// The account a push token may be registered against, or `null`.
///
/// Both halves are required. The Privy session says somebody signed in; the
/// bootstrap identity says the LOOP backend agreed. Registering on the first
/// alone would name an account the server has not accepted.
String? _verifiedPrincipalKey(Ref ref) {
  final session = ref.read(loopSessionProvider);
  if (session.mode != LoopSessionMode.authenticated) return null;
  if (ref.read(loopBootstrapSessionProvider)?.identity == null) return null;
  final principalKey = session.account?.privyUserId;
  if (principalKey == null ||
      principalKey.isEmpty ||
      principalKey != principalKey.trim()) {
    return null;
  }
  return principalKey;
}
