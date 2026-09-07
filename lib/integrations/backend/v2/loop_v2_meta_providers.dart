import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

final loopV2MetaRepositoryProvider = Provider<LoopV2MetaRepository?>((ref) {
  final endpoint = ref.watch(loopBackendEndpointProvider);
  if (endpoint == null) return null;

  final repository = DioLoopV2MetaRepository(origin: endpoint.uri);
  ref.onDispose(repository.close);
  return repository;
});

/// Reads both public D0 resources concurrently as one immutable observation.
///
/// No automatic retry is installed, and none of the returned states is mapped
/// onto an application gate here. In particular, unavailable/deferred policy
/// or pending provider evidence stays visible to the owning product boundary.
final loopV2MetaSnapshotProvider =
    FutureProvider.autoDispose<LoopV2MetaSnapshot?>((ref) async {
      final repository = ref.watch(loopV2MetaRepositoryProvider);
      if (repository == null) return null;

      final values = await Future.wait<Object>(<Future<Object>>[
        repository.getClientPolicy(),
        repository.getCapabilities(),
      ]);
      return LoopV2MetaSnapshot(
        clientPolicy: values[0] as LoopV2ClientPolicy,
        capabilities: values[1] as LoopV2Capabilities,
      );
    }, retry: (retryCount, error) => null);
