import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this installation has already been shown the one-time note in
/// front of 连接外部钱包 (S306, decision 0246).
///
/// One installation-scoped Boolean, device-local and never an account fact.
/// It only records that the note was read; it says nothing about which
/// wallets are bound.
abstract interface class LoopExternalWalletIntroStore {
  Future<bool?> readSeen();

  Future<void> writeSeen();
}

/// The default for any composition that installed no adapter. The read fails,
/// which the page treats as "not seen yet", so the note is shown rather than
/// skipped.
final class UnavailableLoopExternalWalletIntroStore
    implements LoopExternalWalletIntroStore {
  const UnavailableLoopExternalWalletIntroStore();

  @override
  Future<bool?> readSeen() => Future<bool?>.error(
    UnsupportedError('local_external_wallet_intro_unavailable'),
  );

  @override
  Future<void> writeSeen() => Future<void>.error(
    UnsupportedError('local_external_wallet_intro_unavailable'),
  );
}

final class InMemoryLoopExternalWalletIntroStore
    implements LoopExternalWalletIntroStore {
  InMemoryLoopExternalWalletIntroStore([this.seen]);

  bool? seen;

  @override
  Future<bool?> readSeen() async => seen;

  @override
  Future<void> writeSeen() async => seen = true;
}

final loopExternalWalletIntroStoreProvider =
    Provider<LoopExternalWalletIntroStore>(
      (ref) => const UnavailableLoopExternalWalletIntroStore(),
    );
