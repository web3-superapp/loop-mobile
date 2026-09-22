import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_coordinator.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_push_device_registrar.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';

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
        platform: switch (metadata?.platform) {
          LoopV2Platform.android => LoopPushPlatform.android,
          LoopV2Platform.ios => LoopPushPlatform.ios,
          null => null,
        },
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
