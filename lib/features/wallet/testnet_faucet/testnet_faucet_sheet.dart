import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

// ---------------------------------------------------------------------------
// The gate
// ---------------------------------------------------------------------------

/// Whether any faucet entry may be drawn (client decision 0154).
///
/// The only condition is the server's `testnetFaucet` capability reading
/// `available` with no pending precondition, plus a mounted adapter to ask.
/// There is no local build flag: a mainnet backend publishes the capability
/// as unavailable (or not at all), so nothing — not even a placeholder — is
/// drawn there.
bool testnetFaucetVisible(WidgetRef ref) {
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.testnetFaucet),
  );
  final gateway = ref.watch(testnetFaucetGatewayProvider);
  return capability.isUsable &&
      gateway.mode != LoopChainGatewayMode.unavailable;
}

// ---------------------------------------------------------------------------
// Copy
// ---------------------------------------------------------------------------

// S237 · decision 0204: the sheet never says 测试 / 水龙头 / 没有价值. It is
// 「获取资金」, opened from 充值 and from the MEME v2 insufficient-balance
// link; symbols go through [loopDisplaySymbol].
String get testnetFaucetTitle =>
    LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetTitle;

String get testnetFaucetBusyLabel =>
    LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetBusyLabel;
String get testnetFaucetOperatorLowText =>
    LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetOperatorLowText;
String get testnetFaucetNotOwnedText =>
    LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetNotOwnedText;
String get testnetFaucetInFlightLaterText =>
    LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetInFlightLaterText;
String get testnetFaucetTimedOutLaterText =>
    LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetTimedOutLaterText;

/// 「HH:mm」 in the device's own time zone, with the day in front when it is
/// not today.
String testnetFaucetNextLabel(DateTime next, {DateTime? now}) {
  final local = next.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final day = DateTime(local.year, local.month, local.day);
  final base = DateTime(today.year, today.month, today.day);
  final days = day.difference(base).inDays;
  if (days == 0) return time;
  if (days == 1) {
    return LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetNextLabel(
      time,
    );
  }
  return LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetNextLabel2(
    local.day,
    loopMonthLabel(local.month),
    time,
  );
}

/// The server's `cooldownSeconds` as a period: 「24 小时」, 「3 天」,
/// 「30 分钟」. Whole days other than one are days, whole hours are hours,
/// whole minutes are minutes, anything else is seconds.
String testnetFaucetCooldownText(int seconds) {
  if (seconds == 86400) {
    return LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetCooldownText;
  }
  if (seconds % 86400 == 0) {
    return LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetCooldownText2(
      seconds ~/ 86400,
    );
  }
  if (seconds % 3600 == 0) {
    return LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetCooldownText3(
      seconds ~/ 3600,
    );
  }
  if (seconds % 60 == 0) {
    return LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetCooldownText4(
      seconds ~/ 60,
    );
  }
  return LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetCooldownText5(
    seconds,
  );
}

/// 「24 小时后可再领」 from the server's cooldown, or 「稍后可再领」 while
/// it is not read.
String _againText(int? cooldownSeconds) => cooldownSeconds == null
    ? LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetCooldownText6
    : LoopL10n.current.walletTestnetFaucet_sheetS(
        testnetFaucetCooldownText(cooldownSeconds),
      );

/// 「这个钱包 24 小时内已经领过」 from the server's cooldown, or 「最近」 while
/// it is not read.
String testnetFaucetClaimedText(int? cooldownSeconds) => cooldownSeconds == null
    ? LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetCooldownText7
    : LoopL10n.current.walletTestnetFaucet_sheetS2(
        testnetFaucetCooldownText(cooldownSeconds),
      );

/// The partial grant, said by what did arrive.
String testnetFaucetPartialText(
  TestnetFaucetPartial partial, {
  int? cooldownSeconds,
}) {
  final again = _againText(cooldownSeconds);
  if (partial.unconfirmed) {
    return LoopL10n.current.walletTestnetFaucet_sheetIf(
      again,
      loopLaunchNativeSymbolText,
      loopLaunchUsd1SymbolText,
    );
  }
  final bnb = partial.bnbTransactionHash != null;
  final usd1 = partial.usd1TransactionHash != null;
  if (partial.readBack && bnb && !usd1) {
    // A record read back proves the native transfer was sent, not that it
    // arrived (decision 0158).
    return LoopL10n.current.walletTestnetFaucet_sheetIf2(
      again,
      loopLaunchNativeSymbolText,
      loopLaunchUsd1SymbolText,
    );
  }
  if (usd1 && !bnb) {
    return LoopL10n.current.walletTestnetFaucet_sheetIf3(
      again,
      loopLaunchNativeSymbolText,
      loopLaunchUsd1SymbolText,
    );
  }
  if (!bnb && !usd1) {
    return LoopL10n.current.walletTestnetFaucet_sheetIf4(again);
  }
  return LoopL10n.current.walletTestnetFaucet_sheetIf3(
    again,
    loopLaunchUsd1SymbolText,
    loopLaunchNativeSymbolText,
  );
}

/// One refusal or failure, in the owner's words.
String testnetFaucetFailureText(
  LoopChainException failure, {
  int? cooldownSeconds,
}) {
  switch (failure.reasonCode) {
    case TestnetFaucetReason.operatorLow:
      return testnetFaucetOperatorLowText;
    case TestnetFaucetReason.walletNotOwned:
      return testnetFaucetNotOwnedText;
    case TestnetFaucetReason.disabled:
      return LoopL10n.current.walletTestnetFaucet_sheetDisabled;
    case TestnetFaucetReason.wrongChain:
      return LoopL10n.current.walletTestnetFaucet_sheetWrongChain;
    case TestnetFaucetReason.operatorNotConfigured:
    case TestnetFaucetReason.capabilityAbsent:
    case TestnetFaucetReason.usd1NotConfigured:
    case TestnetFaucetReason.rpcNotConfigured:
    case TestnetFaucetReason.runtimeUnavailable:
      return LoopL10n.current.walletTestnetFaucet_sheetRuntimeUnavailable;
    case TestnetFaucetReason.usd1Unavailable:
      return LoopL10n.current.walletTestnetFaucet_sheetUsd1Unavailable(
        loopLaunchUsd1SymbolText,
      );
    case TestnetFaucetReason.chainReadFailed:
      return LoopL10n.current.walletTestnetFaucet_sheetChainReadFailed;
    case TestnetFaucetReason.busy:
      return LoopL10n.current.walletTestnetFaucet_sheetBusy;
    case TestnetFaucetReason.transferFailed:
      return LoopL10n.current.walletTestnetFaucet_sheetTransferFailed;
    case TestnetFaucetReason.cooldown:
      return LoopL10n.current.walletTestnetFaucet_sheetCooldown(
        testnetFaucetClaimedText(cooldownSeconds),
      );
  }
  if (failure.kind == LoopChainFailureKind.permissionDenied) {
    return testnetFaucetNotOwnedText;
  }
  return loopChainFailureReason(failure.kind);
}

/// Opens the faucet sheet for [walletId]. [address] is what the page already
/// knows about the wallet; the sheet replaces it with the server's own once
/// read. [onGranted] runs after any grant that sent something, next to the
/// wallet balance refresh the sheet does itself.
Future<void> showTestnetFaucetSheet(
  BuildContext context, {
  required String walletId,
  String? address,
  VoidCallback? onGranted,
}) => showLoopSheet<void>(
  context,
  barrierLabel: context.l10n.walletTestnetFaucet_sheetBarrierLabel,
  builder: (_) => TestnetFaucetSheet(
    walletId: walletId,
    address: address,
    onGranted: onGranted,
  ),
);

// ---------------------------------------------------------------------------
// The sheet
// ---------------------------------------------------------------------------

/// `testnet-faucet` sheet · archetype action, layout focus.
///
/// States: loading (the status read), error / offline / permission /
/// unavailable (the read or the claim refused, each in its own words), ready,
/// claiming, granted, cooling down, partial.
class TestnetFaucetSheet extends ConsumerStatefulWidget {
  const TestnetFaucetSheet({
    required this.walletId,
    super.key,
    this.address,
    this.onGranted,
  });

  final String walletId;
  final String? address;
  final VoidCallback? onGranted;

  @override
  ConsumerState<TestnetFaucetSheet> createState() => _TestnetFaucetSheetState();
}

class _TestnetFaucetSheetState extends ConsumerState<TestnetFaucetSheet> {
  TestnetFaucetStatus? _status;
  LoopChainException? _statusFailure;
  bool _loading = true;
  bool _claiming = false;

  /// What the last claim answered: a grant, a cooldown or a partial grant.
  TestnetFaucetClaimResult? _result;
  LoopChainException? _claimFailure;

  /// What a claim whose answer never came back in time says.
  String? _pendingNote;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _statusFailure = null;
    });
    try {
      final status = await ref
          .read(testnetFaucetGatewayProvider)
          .loadStatus(walletId: widget.walletId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _statusFailure = failure;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusFailure = const LoopChainException(
          LoopChainFailureKind.readFailed,
        );
        _loading = false;
      });
    }
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() {
      _claiming = true;
      _claimFailure = null;
      _result = null;
      _pendingNote = null;
    });
    try {
      final result = await ref
          .read(testnetFaucetGatewayProvider)
          .claim(walletId: widget.walletId);
      if (!mounted) return;
      if (result is TestnetFaucetPending) {
        await _awaitGrant(result.reason);
        return;
      }
      setState(() {
        _result = result;
        _claiming = false;
      });
      if (result is TestnetFaucetGranted || result is TestnetFaucetPartial) {
        _refreshBalances();
      }
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _claimFailure = failure;
        _claiming = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _claimFailure = const LoopChainException(
          LoopChainFailureKind.unexpected,
        );
        _claiming = false;
      });
    }
  }

  /// The claim was accepted and its answer is not in yet: the button stays
  /// on 正在发放 and the status is read again until the grant appears. It
  /// never claims a second time.
  ///
  /// In flight: every 3 s, the last read at 20 s. Timed out (LOOP finishes and records
  /// the grant anyway): once now, once 3 s later.
  Future<void> _awaitGrant(TestnetFaucetPendingReason reason) async {
    final baseline = _status?.lastGrant?.grantedAt;
    final delays = switch (reason) {
      TestnetFaucetPendingReason.inFlight => const <int>[3, 3, 3, 3, 3, 3, 2],
      TestnetFaucetPendingReason.timedOut => const <int>[0, 3],
    };
    TestnetFaucetStatus? latest;
    for (final seconds in delays) {
      if (seconds > 0) await Future<void>.delayed(Duration(seconds: seconds));
      if (!mounted) return;
      try {
        latest = await ref
            .read(testnetFaucetGatewayProvider)
            .loadStatus(walletId: widget.walletId);
      } on Object {
        continue;
      }
      if (!mounted) return;
      final grant = latest.lastGrant;
      if (grant != null && grant.grantedAt != baseline) {
        final status = latest;
        setState(() {
          _status = status;
          _result = _resultOf(status, grant);
          _claiming = false;
        });
        _refreshBalances();
        return;
      }
    }
    if (!mounted) return;
    final status = latest;
    setState(() {
      if (status != null) _status = status;
      _pendingNote = switch (reason) {
        TestnetFaucetPendingReason.inFlight => testnetFaucetInFlightLaterText,
        TestnetFaucetPendingReason.timedOut => testnetFaucetTimedOutLaterText,
      };
      _claiming = false;
    });
  }

  /// A grant read back from the status, said the way the claim would have.
  TestnetFaucetClaimResult _resultOf(
    TestnetFaucetStatus status,
    TestnetFaucetLastGrant grant,
  ) {
    final next =
        status.nextAvailableAt ??
        grant.grantedAt.add(Duration(seconds: status.cooldownSeconds));
    final usd1 = grant.usd1TransactionHash;
    if (usd1 == null) {
      return TestnetFaucetPartial(
        bnbTransactionHash: grant.bnbTransactionHash,
        nextAvailableAt: next,
        readBack: true,
      );
    }
    return TestnetFaucetGranted(
      walletId: status.walletId,
      address: status.address,
      bnb: TestnetFaucetTransfer(
        amount: status.bnbAmount,
        transactionHash: grant.bnbTransactionHash,
      ),
      usd1: TestnetFaucetTransfer(
        amount: status.usd1Amount,
        transactionHash: usd1,
      ),
      grantedAt: grant.grantedAt,
      nextAvailableAt: next,
    );
  }

  /// The grant changed the wallet: its balances are read again on the spot,
  /// and the opener refreshes whatever else it shows.
  void _refreshBalances() {
    final provider = walletBalancesControllerProvider(widget.walletId);
    if (ref.exists(provider)) {
      unawaited(ref.read(provider.notifier).reload());
    }
    widget.onGranted?.call();
  }

  /// The server's cooldown, once the status is read (decision 0158).
  int? get _cooldownSeconds => _status?.cooldownSeconds;

  /// When the wallet can claim again, from the freshest answer.
  DateTime? get _nextAvailableAt => switch (_result) {
    TestnetFaucetGranted(:final nextAvailableAt) => nextAvailableAt,
    TestnetFaucetCoolingDown(:final nextAvailableAt) => nextAvailableAt,
    TestnetFaucetPartial(:final nextAvailableAt?) => nextAvailableAt,
    _ => _status?.available == false ? _status?.nextAvailableAt : null,
  };

  /// Whether the button is off: a cooldown the server named, or a grant
  /// that just went out.
  bool get _coolingDown {
    final result = _result;
    if (result is TestnetFaucetGranted ||
        result is TestnetFaucetCoolingDown ||
        result is TestnetFaucetPartial) {
      return true;
    }
    return _status?.available == false;
  }

  @override
  Widget build(BuildContext context) {
    final secondary = LoopGround.secondaryOf(context);
    final status = _status;
    final address = status?.address ?? widget.address;
    return Padding(
      key: const ValueKey<String>('testnet-faucet-sheet'),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(testnetFaucetTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              status == null
                  ? context.l10n.walletTestnetFaucet_sheetTestnetFaucetIntro(
                      loopLaunchNativeSymbolText,
                      loopLaunchUsd1SymbolText,
                    )
                  : context.l10n.walletTestnetFaucet_sheetTestnetFaucetIntro2(
                      loopFormatDecimal(status.bnbAmount),
                      loopFormatDecimal(status.usd1Amount),
                      loopLaunchNativeSymbolText,
                      loopLaunchUsd1SymbolText,
                      testnetFaucetCooldownText(status.cooldownSeconds),
                    ),
              key: const ValueKey<String>('testnet-faucet-intro'),
              style: LoopType.bodySm.copyWith(color: secondary),
            ),
          ),
          const SizedBox(height: 12),
          if (address != null)
            LoopKeyValue(
              key: const ValueKey<String>('testnet-faucet-address'),
              label: context
                  .l10n
                  .walletTestnetFaucet_sheetTestnetFaucetAddressLabel,
              value: loopTruncatedAddress(address),
            ),
          ..._body(context),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (_loading) {
      return <Widget>[
        Padding(
          key: const ValueKey<String>('testnet-faucet-loading'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              context.l10n.walletTestnetFaucet_sheetIf6,
              style: LoopType.bodySm.copyWith(
                color: LoopGround.secondaryOf(context),
              ),
            ),
          ),
        ),
      ];
    }
    final statusFailure = _statusFailure;
    if (statusFailure != null) {
      final offline = loopChainIsOffline(statusFailure.kind);
      return <Widget>[
        LoopNotice(
          key: ValueKey<String>(
            offline
                ? 'testnet-faucet-offline'
                : statusFailure.kind == LoopChainFailureKind.permissionDenied
                ? 'testnet-faucet-permission'
                : statusFailure.kind == LoopChainFailureKind.unavailable
                ? 'testnet-faucet-unavailable'
                : 'testnet-faucet-error',
          ),
          icon: offline ? 'offline' : 'warn',
          tone: LoopNoticeTone.warn,
          title: context.l10n.walletTestnetFaucet_sheetTitle,
          body: testnetFaucetFailureText(
            statusFailure,
            cooldownSeconds: _cooldownSeconds,
          ),
          margin: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            8,
            LoopSpacing.page,
            12,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LoopButton(
            key: const ValueKey<String>('testnet-faucet-retry'),
            label: context.l10n.common_retry,
            block: true,
            onPressed: () => unawaited(_load()),
          ),
        ),
      ];
    }

    final result = _result;
    final next = _nextAvailableAt;
    final cooling = _coolingDown;
    final claimFailure = _claimFailure;
    return <Widget>[
      if (result is TestnetFaucetGranted) ..._granted(result),
      if (result is TestnetFaucetPartial) ..._partial(result),
      if (result is TestnetFaucetCoolingDown)
        _line(
          key: 'testnet-faucet-cooldown',
          text: next == null
              ? context.l10n.walletTestnetFaucet_sheetCooldown(
                  testnetFaucetClaimedText(_cooldownSeconds),
                )
              : context.l10n.walletTestnetFaucet_sheetText(
                  testnetFaucetClaimedText(_cooldownSeconds),
                  testnetFaucetNextLabel(next),
                ),
        ),
      if (_pendingNote case final String note)
        _line(key: 'testnet-faucet-pending', text: note),
      if (claimFailure != null)
        _line(
          key: 'testnet-faucet-failure',
          text: testnetFaucetFailureText(
            claimFailure,
            cooldownSeconds: _cooldownSeconds,
          ),
        ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LoopButton(
          key: const ValueKey<String>('testnet-faucet-claim'),
          label: _claiming
              ? testnetFaucetBusyLabel
              : cooling
              ? (next == null
                    ? (_cooldownSeconds == null
                          ? context.l10n.walletTestnetFaucet_sheetLabel
                          : context.l10n.walletTestnetFaucet_sheetLabel2(
                              testnetFaucetCooldownText(_cooldownSeconds!),
                            ))
                    : context.l10n.walletTestnetFaucet_sheetLabel3(
                        testnetFaucetNextLabel(next),
                      ))
              : context.l10n.common_claim,
          primary: true,
          block: true,
          onPressed: _claiming || cooling ? null : () => unawaited(_claim()),
        ),
      ),
    ];
  }

  /// One warn line (docs/33 L17): the shared `.notice-warn`, never the v1
  /// warning yellow. It is still a live region, so a cooldown or a failure
  /// that arrives while the sheet is open is read out.
  Widget _line({required String key, required String text}) => Semantics(
    liveRegion: true,
    container: true,
    child: LoopNotice(
      key: ValueKey<String>(key),
      tone: LoopNoticeTone.warn,
      icon: 'warn',
      body: text,
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        4,
      ),
    ),
  );

  List<Widget> _granted(TestnetFaucetGranted granted) => <Widget>[
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Semantics(
        liveRegion: true,
        child: Text(
          LoopL10n.current.walletTestnetFaucet_sheetTestnetFaucetGranted(
            loopFormatDecimal(granted.bnb.amount),
            loopFormatDecimal(granted.usd1.amount),
            loopLaunchNativeSymbolText,
            loopLaunchUsd1SymbolText,
          ),
          key: const ValueKey<String>('testnet-faucet-granted'),
          style: LoopType.bodySm,
        ),
      ),
    ),
    TestnetFaucetTxRow(
      label: loopLaunchNativeSymbolText,
      hash: granted.bnb.transactionHash,
    ),
    TestnetFaucetTxRow(
      label: loopLaunchUsd1SymbolText,
      hash: granted.usd1.transactionHash,
    ),
  ];

  List<Widget> _partial(TestnetFaucetPartial partial) => <Widget>[
    _line(
      key: 'testnet-faucet-partial',
      text: testnetFaucetPartialText(
        partial,
        cooldownSeconds: _cooldownSeconds,
      ),
    ),
    if (partial.bnbTransactionHash case final String hash)
      TestnetFaucetTxRow(label: loopLaunchNativeSymbolText, hash: hash),
    if (partial.usd1TransactionHash case final String hash)
      TestnetFaucetTxRow(label: loopLaunchUsd1SymbolText, hash: hash),
  ];
}

/// The BscScan testnet page of one faucet transfer.
String testnetFaucetExplorerUrl(String hash) =>
    'https://testnet.bscscan.com/tx/$hash';

/// One transfer: its short hash, and two controls that copy the hash and its
/// BscScan testnet address — the same pair the MEME v2 deployment page uses
/// (the App opens no browser).
class TestnetFaucetTxRow extends StatelessWidget {
  const TestnetFaucetTxRow({
    required this.label,
    required this.hash,
    super.key,
  });

  final String label;
  final String hash;

  @override
  Widget build(BuildContext context) {
    final url = testnetFaucetExplorerUrl(hash);
    return Padding(
      key: ValueKey<String>('testnet-faucet-tx-$label'),
      padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 2, 8, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: LoopKeyValue(
              label: label,
              value: loopTruncatedAddress(hash),
              padding: EdgeInsets.zero,
            ),
          ),
          LoopIconButton(
            key: ValueKey<String>('testnet-faucet-copy-hash-$label'),
            icon: 'copy',
            label: context.l10n.walletTestnetFaucet_sheetLabel4(label),
            onPressed: () => unawaited(
              LoopCopy.text(
                context,
                hash,
                message: context.l10n.walletTestnetFaucet_sheetMessage,
              ),
            ),
          ),
          LoopIconButton(
            key: ValueKey<String>('testnet-faucet-copy-link-$label'),
            icon: 'link',
            label: context.l10n.walletTestnetFaucet_sheetLabel5(label),
            onPressed: () => unawaited(
              LoopCopy.text(
                context,
                url,
                message: context.l10n.walletTestnetFaucet_sheetMessage2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
