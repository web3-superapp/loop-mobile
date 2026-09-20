import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/wallet_creation_facts.dart';

/// Step 02 of the opening sequence, mounted with live wallet observations.
///
/// Opening the page is what starts the wallet watch; nothing else on the
/// device polls the directory for this. The watch is single-flight, so
/// returning to 02 from 03 rejoins the running one instead of starting a
/// second poll, and a wallet already seen is never looked for again.
class WalletCreateStepScreen extends ConsumerStatefulWidget {
  const WalletCreateStepScreen({
    required this.onContinue,
    super.key,
    this.onBack,
  });

  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  ConsumerState<WalletCreateStepScreen> createState() =>
      _WalletCreateStepScreenState();
}

class _WalletCreateStepScreenState
    extends ConsumerState<WalletCreateStepScreen> {
  @override
  void initState() {
    super.initState();
    // The watch reports its own outcome through the provider; a failure here
    // is a wallet fact and may never reach the sequence as an error.
    unawaited(
      Future<void>.microtask(
        () => ref.read(loopEmbeddedWalletWatchProvider.notifier).start(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WalletCreateScreen(
      facts: ref.watch(loopWalletCreationFactsProvider),
      onBack: widget.onBack,
      onContinue: widget.onContinue,
    );
  }
}
