import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';

/// Pure projection of one D0 capability onto a product gate.
///
/// `unknown` is the honest state while the public capability document has not
/// been observed. It never reads as available, and availability by itself
/// never proves enrollment, configuration, or secure persistence.
enum LoopCapabilityDecision { unknown, available, deferred, unavailable }

@immutable
final class LoopCapabilityProjection {
  const LoopCapabilityProjection({required this.decision, this.reasonCode});

  const LoopCapabilityProjection.unknown()
    : decision = LoopCapabilityDecision.unknown,
      reasonCode = null;

  final LoopCapabilityDecision decision;
  final String? reasonCode;

  bool get isAvailable => decision == LoopCapabilityDecision.available;
}

abstract final class LoopCapabilityProjector {
  static LoopCapabilityProjection of(
    LoopV2Capabilities? capabilities,
    LoopV2CapabilityId id,
  ) {
    if (capabilities == null) return const LoopCapabilityProjection.unknown();
    final capability = capabilities[id];
    return LoopCapabilityProjection(
      decision: switch (capability.availability) {
        LoopV2CapabilityAvailability.available =>
          LoopCapabilityDecision.available,
        LoopV2CapabilityAvailability.deferred =>
          LoopCapabilityDecision.deferred,
        LoopV2CapabilityAvailability.unavailable =>
          LoopCapabilityDecision.unavailable,
      },
      reasonCode: capability.reasonCode,
    );
  }
}

/// Reads the observed capability document without starting a product request.
/// An error or a missing observation projects as `unknown`.
final loopCapabilityProvider =
    Provider.family<LoopCapabilityProjection, LoopV2CapabilityId>((ref, id) {
      final snapshot = ref.watch(loopV2MetaSnapshotProvider).value;
      return LoopCapabilityProjector.of(snapshot?.capabilities, id);
    });
