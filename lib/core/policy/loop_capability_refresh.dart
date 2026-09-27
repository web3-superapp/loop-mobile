import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';

/// Asks the server for the current capability document now (decision 0098).
///
/// Capabilities are served from memory for up to
/// [LoopV2MetaCachePolicy.freshFor]. A caller about to sign or write, that
/// must not act on an answer up to a minute old, awaits this first and then
/// reads `loopCapabilityProvider` as usual: the projection is the same one
/// every page reads, so the gate it applies is the existing block rule and not
/// a second one. A read that fails leaves the previous answer in place and
/// reports the failure through the usual unreachable fact; it never opens a
/// gate the previous answer kept closed.
///
/// Calling it performs at most one request pair; a read already running is
/// joined.
final loopCapabilityRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(loopV2MetaObserverProvider).refreshNow();
});

/// The step every signing exit takes before its sheet opens (S88d).
///
/// Send, Swap and the Launch approval and purchase await this, then re-apply
/// the gate the page already applies, reading the projection again. A failed
/// refresh throws nothing and leaves the answer on hand in place (decision
/// 0098, ruling 4): no gate is added for it.
Future<void> loopRefreshCapabilitiesBeforeSigning(WidgetRef ref) async {
  try {
    await ref.read(loopCapabilityRefreshProvider)();
  } on Object {
    // The answer on hand stands; the observation reports the failure itself.
  }
}
