import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
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
  const LoopCapabilityProjection({
    required this.decision,
    this.reasonCode,
    this.evidencePending = false,
    this.evidenceReasonCode,
    this.launchChainId,
    this.unreachable = false,
  });

  const LoopCapabilityProjection.unknown({this.unreachable = false})
    : decision = LoopCapabilityDecision.unknown,
      reasonCode = null,
      evidencePending = false,
      evidenceReasonCode = null,
      launchChainId = null;

  final LoopCapabilityDecision decision;
  final String? reasonCode;

  /// The capability observation itself failed: LOOP was not reached.
  ///
  /// This is a third fact, kept apart from the other two on purpose. "LOOP
  /// answered and closed this capability" carries the server's own
  /// `reasonCode` and no retry on this device can change it. "This build never
  /// had a backend to ask" is a configuration fact. "The request did not get
  /// through" is the user's network or LOOP being down, and it is the only one
  /// whose next step is *try again on another network*. None of the three is
  /// derived from either of the others, and an unreachable gate never borrows
  /// a `reasonCode` the server never sent.
  final bool unreachable;

  /// A provider-evidence precondition the backend records separately from
  /// availability. `pending` is the only status that sets it: a capability
  /// with no such precondition (`notApplicable`) and one whose precondition
  /// the operator has recorded as met (`confirmed`, decision 0068) both leave
  /// the surface to its own five states. While it is pending the surface must
  /// stay closed even though the capability itself reads `available`.
  final bool evidencePending;
  final String? evidenceReasonCode;

  /// Decision 0038: the chain slot the `launch` module points at, published
  /// only while it differs from the primary chain. `null` on every other
  /// capability and whenever Launch runs on the primary chain.
  final String? launchChainId;

  /// The single condition for the "BSC 测试网" badge and its one-time
  /// explanation. It never closes a surface.
  bool get isTestnetLaunchChain {
    final chainId = launchChainId;
    return chainId != null && loopIsTestnetChainId(chainId);
  }

  bool get isAvailable => decision == LoopCapabilityDecision.available;

  /// The capability document was never observed, so the server said nothing
  /// about this gate at all. It says nothing about *why*: see [unreachable].
  bool get isUnobserved => decision == LoopCapabilityDecision.unknown;

  /// The only projection a feature may treat as fully open.
  bool get isUsable => isAvailable && !evidencePending;
}

abstract final class LoopCapabilityProjector {
  static LoopCapabilityProjection of(
    LoopV2Capabilities? capabilities,
    LoopV2CapabilityId id, {
    bool unreachable = false,
  }) {
    if (capabilities == null) {
      return LoopCapabilityProjection.unknown(unreachable: unreachable);
    }
    final capability = capabilities[id];
    final evidence = capability.evidence;
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
      // Written as a switch so a status added to the contract has to be
      // classified here rather than defaulting to "open".
      evidencePending: switch (evidence.status) {
        LoopV2CapabilityEvidenceStatus.pending => true,
        LoopV2CapabilityEvidenceStatus.notApplicable ||
        LoopV2CapabilityEvidenceStatus.confirmed => false,
      },
      evidenceReasonCode: evidence.reasonCode,
      launchChainId: evidence.launchChainId,
    );
  }
}

/// Reads the observed capability document without starting a product request.
/// An error or a missing observation projects as `unknown`.
final loopCapabilityProvider =
    Provider.family<LoopCapabilityProjection, LoopV2CapabilityId>((ref, id) {
      final snapshot = ref.watch(loopV2MetaSnapshotProvider).value;
      return LoopCapabilityProjector.of(
        snapshot?.capabilities,
        id,
        // A failed observation is the one case where the client, not the
        // server, is the reason there is no answer.
        unreachable: ref.watch(loopV2MetaUnreachableProvider),
      );
    });

/// Pure projection of the D0 version gate for the dismissible soft prompt.
///
/// `updateRequired` keeps its own dedicated system page; this provider only
/// carries the recommendation. An unavailable or not-yet-effective gate, an
/// unknown platform, or an unparsable client version all project as `unknown`
/// and show nothing.
final loopVersionPolicyProvider = Provider<LoopVersionPolicyProjection>((ref) {
  final snapshot = ref.watch(loopV2MetaSnapshotProvider).value;
  return LoopClientPolicyProjection.version(
    snapshot?.clientPolicy,
    platform: defaultTargetPlatform,
    clientVersion: ref.watch(appConfigProvider).loopClientVersion,
  );
});
