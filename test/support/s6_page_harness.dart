import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'loop_ground_probe.dart';
import 's5_page_harness.dart';

/// A wallet double that records every handoff, so a test can assert that a
/// refused intent never reached a wallet at all.
final class RecordingSigningGateway implements WalletSigningGateway {
  RecordingSigningGateway({
    this.accepted = true,
    this.code = 'wallet_accepted',
    this.value =
        '0x4f2a111111111111111111111111111111111111111111111111111111119c81',
    this.availability = WalletGatewayAvailability.available,
  });

  final bool accepted;
  final String code;
  final String? value;

  @override
  final WalletGatewayAvailability availability;

  final List<SigningIntent> handoffs = <SigningIntent>[];

  /// Holds the wallet open so a test can observe the `signing` state.
  final Completer<void> gate = Completer<void>();
  bool holdOpen = false;

  @override
  String get label => 'Recording wallet';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handoffs.add(intent);
    if (holdOpen) await gate.future;
    return WalletHandoffResult(
      accepted: accepted,
      code: code,
      value: accepted ? value : null,
    );
  }
}

/// Mounts one S6 money-action page with its ports and capability document.
///
/// `sendApprovals` and `privySwap` default to available so the page under test
/// reaches its own content; a test that wants the gate closed flips them.
Future<void> pumpS6Page(
  WidgetTester tester,
  Widget page, {
  WalletReadGateway? wallet,
  WalletIntentsGateway? intents,
  SwapQuoteGateway? quotes,
  ApprovalsGateway? approvals,
  WalletSigningGateway? signing,
  LoopV2CapabilityAvailability sendApprovals =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability privySwap =
      LoopV2CapabilityAvailability.available,
  bool swapEvidencePending = true,
  Size size = const Size(390, 2400),
  bool settle = true,
  // S88d: when given, the capability document is read through this port and
  // the D0 cache, as in production, instead of being pinned.
  LoopV2MetaRepository? metaRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  // Every page this harness mounts is watched for paint that did not
  // survive its ground; no test opts in and no new page has to remember to.
  loopArmGroundProbe(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (wallet != null) walletReadGatewayProvider.overrideWithValue(wallet),
        if (intents != null)
          walletIntentsGatewayProvider.overrideWithValue(intents),
        if (quotes != null) swapQuoteGatewayProvider.overrideWithValue(quotes),
        if (approvals != null)
          approvalsGatewayProvider.overrideWithValue(approvals),
        walletSigningGatewayProvider.overrideWithValue(
          signing ?? RecordingSigningGateway(),
        ),
        if (metaRepository != null)
          loopV2MetaRepositoryProvider.overrideWithValue(metaRepository)
        else
          loopV2MetaSnapshotProvider.overrideWith(
            (ref) async => s5MetaSnapshot(
              sendApprovals: sendApprovals,
              privySwap: privySwap,
              swapEvidencePending: swapEvidencePending,
            ),
          ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

/// Walks a mounted send flow through its first step (decision 0131): types
/// the fixture recipient, lets the automatic check run, and opens step 2.
Future<void> sendToAmountStep(
  WidgetTester tester, {
  String address = '0x000000000000000000000000000000000000dEaD',
  bool settle = true,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('send-recipient-field')),
    address,
  );
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('send-address-next')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}
