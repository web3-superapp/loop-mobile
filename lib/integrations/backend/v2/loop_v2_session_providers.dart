import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_coordinator.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';

final loopV2ClientMetadataProvider = Provider<LoopV2ClientMetadata?>((ref) {
  final clientVersion = ref.watch(
    appConfigProvider.select(
      (config) => config.loopClientVersionForCurrentBuild,
    ),
  );
  if (clientVersion.isEmpty) return null;
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => LoopV2Platform.android,
    TargetPlatform.iOS => LoopV2Platform.ios,
    _ => null,
  };
  if (platform == null) return null;
  return LoopV2ClientMetadata(clientVersion: clientVersion, platform: platform);
});

final loopV2SessionJournalStoreProvider = Provider<LoopV2SessionJournalStore>((
  ref,
) {
  return FlutterSecureLoopV2SessionJournalStore();
});

final loopV2SessionApiProvider = Provider<LoopV2SessionApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2SessionApi(dio);
});

final loopV2LogoutCoordinatorProvider = Provider<LoopV2LogoutCoordinator?>((
  ref,
) {
  final api = ref.watch(loopV2SessionApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  if (api == null || metadata == null) return null;
  return LoopV2LogoutCoordinator(
    clientMetadata: metadata,
    api: api,
    store: ref.watch(loopV2SessionJournalStoreProvider),
    accessTokens: ref.watch(loopBackendAccessTokenSourceProvider),
  );
});
