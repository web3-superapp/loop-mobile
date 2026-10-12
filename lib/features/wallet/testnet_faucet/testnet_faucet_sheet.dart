import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
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

const String testnetFaucetTitle = '领取测试币';
const String testnetFaucetEntrySubtitle =
    '测试网专用 · 领 tBNB 与 tUSD1 · 每 24 小时一次';
const String testnetFaucetBusyLabel = '正在发放…（约 30 秒）';
const String testnetFaucetOperatorLowText = '测试币池暂时不足，请稍后再试';
const String testnetFaucetNotOwnedText = '只能给当前登录的内置钱包领取';
const String testnetFaucetInFlightLaterText = '结果稍后在这里查看';
const String testnetFaucetTimedOutLaterText = '发放还在进行，稍后再进来看';

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
  if (days == 1) return '明天 $time';
  return '${local.month}月${local.day}日 $time';
}

/// The partial grant, said by what did arrive.
String testnetFaucetPartialText(TestnetFaucetPartial partial) {
  if (partial.unconfirmed) {
    return 'tBNB 已发出但还没确认，tUSD1 这次没发；24 小时后可再领';
  }
  final bnb = partial.bnbTransactionHash != null;
  final usd1 = partial.usd1TransactionHash != null;
  if (usd1 && !bnb) return 'tUSD1 已到账，tBNB 这次没成功，24 小时后可再领';
  if (!bnb && !usd1) return '这次只发出了一部分测试币，24 小时后可再领';
  return 'tBNB 已到账，tUSD1 这次没成功，24 小时后可再领';
}

/// One refusal or failure, in the owner's words.
String testnetFaucetFailureText(LoopChainException failure) {
  switch (failure.reasonCode) {
    case TestnetFaucetReason.operatorLow:
      return testnetFaucetOperatorLowText;
    case TestnetFaucetReason.walletNotOwned:
      return testnetFaucetNotOwnedText;
    case TestnetFaucetReason.disabled:
      return '测试币领取已关闭';
    case TestnetFaucetReason.wrongChain:
      return '当前网络不是测试网，不能领取测试币';
    case TestnetFaucetReason.operatorNotConfigured:
    case TestnetFaucetReason.capabilityAbsent:
    case TestnetFaucetReason.usd1NotConfigured:
    case TestnetFaucetReason.rpcNotConfigured:
    case TestnetFaucetReason.runtimeUnavailable:
      return '测试币领取暂时不可用，稍后再试';
    case TestnetFaucetReason.usd1Unavailable:
      return 'tUSD1 合约暂时不可用，稍后再试';
    case TestnetFaucetReason.chainReadFailed:
      return '链上读数暂时取不到，稍后再试';
    case TestnetFaucetReason.busy:
      return '正在给别人发放，几秒后再试';
    case TestnetFaucetReason.transferFailed:
      return '这次没有发出，可以重试';
    case TestnetFaucetReason.cooldown:
      return '这个钱包 24 小时内已经领过，稍后再来';
  }
  if (failure.kind == LoopChainFailureKind.permissionDenied) {
    return testnetFaucetNotOwnedText;
  }
  return loopChainFailureReason(failure.kind);
}

// ---------------------------------------------------------------------------
// The wallet entry
// ---------------------------------------------------------------------------

/// The one-row card under the balance on the wallet tab. Its parent draws it
/// only while [testnetFaucetVisible] holds.
class TestnetFaucetEntry extends StatelessWidget {
  const TestnetFaucetEntry({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LoopRecordGroup(
    key: const ValueKey<String>('wallet-faucet-group'),
    rows: <LoopRecordRow>[
      LoopRecordRow(
        key: const ValueKey<String>('wallet-faucet-entry'),
        leading: const LoopRowIcon(icon: 'droplet'),
        title: testnetFaucetTitle,
        subtitle: testnetFaucetEntrySubtitle,
        subtitleMaxLines: 2,
        onTap: onTap,
      ),
    ],
  );
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
  barrierLabel: '关闭领取测试币',
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
          const LoopSheetHeading(testnetFaucetTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              status == null
                  ? '测试网专用。每个内置钱包每 24 小时可以领一次 tBNB 和 tUSD1，'
                        '用来在测试网上付手续费和试用买卖。测试币没有价值。'
                  : '测试网专用。这次会发 ${loopFormatDecimal(status.bnbAmount)} tBNB 和 '
                        '${loopFormatDecimal(status.usd1Amount)} tUSD1，'
                        '每个内置钱包每 24 小时可以领一次。测试币没有价值。',
              key: const ValueKey<String>('testnet-faucet-intro'),
              style: LoopType.bodySm.copyWith(color: secondary),
            ),
          ),
          const SizedBox(height: 12),
          if (address != null)
            LoopKeyValue(
              key: const ValueKey<String>('testnet-faucet-address'),
              label: '收币钱包',
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
              '正在读取领取状态…',
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
          title: '领取状态暂时读不到',
          body: testnetFaucetFailureText(statusFailure),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LoopButton(
            key: const ValueKey<String>('testnet-faucet-retry'),
            label: '重试',
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
              ? '这个钱包 24 小时内已经领过，稍后再来'
              : '这个钱包 24 小时内已经领过，下次可领 ${testnetFaucetNextLabel(next)}',
        ),
      if (_pendingNote case final String note)
        _line(key: 'testnet-faucet-pending', text: note),
      if (claimFailure != null)
        _line(
          key: 'testnet-faucet-failure',
          text: testnetFaucetFailureText(claimFailure),
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
                    ? '24 小时内已领过'
                    : '下次可领 ${testnetFaucetNextLabel(next)}')
              : '领取',
          primary: true,
          block: true,
          onPressed: _claiming || cooling ? null : () => unawaited(_claim()),
        ),
      ),
    ];
  }

  Widget _line({required String key, required String text}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: LoopIcon('warn', size: 15, color: LoopColors.warning),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: ValueKey<String>(key),
              style: LoopType.caption.copyWith(color: LoopColors.warning),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _granted(TestnetFaucetGranted granted) => <Widget>[
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Semantics(
        liveRegion: true,
        child: Text(
          '已发出 ${loopFormatDecimal(granted.bnb.amount)} tBNB 和 '
          '${loopFormatDecimal(granted.usd1.amount)} tUSD1，到账以链上确认为准，余额会自动刷新。',
          key: const ValueKey<String>('testnet-faucet-granted'),
          style: LoopType.bodySm,
        ),
      ),
    ),
    TestnetFaucetTxRow(label: 'tBNB', hash: granted.bnb.transactionHash),
    TestnetFaucetTxRow(label: 'tUSD1', hash: granted.usd1.transactionHash),
  ];

  List<Widget> _partial(TestnetFaucetPartial partial) => <Widget>[
    _line(
      key: 'testnet-faucet-partial',
      text: testnetFaucetPartialText(partial),
    ),
    if (partial.bnbTransactionHash case final String hash)
      TestnetFaucetTxRow(label: 'tBNB', hash: hash),
    if (partial.usd1TransactionHash case final String hash)
      TestnetFaucetTxRow(label: 'tUSD1', hash: hash),
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
            label: '复制 $label 交易哈希',
            onPressed: () =>
                unawaited(LoopCopy.text(context, hash, message: '交易哈希已复制')),
          ),
          LoopIconButton(
            key: ValueKey<String>('testnet-faucet-copy-link-$label'),
            icon: 'link',
            label: '复制 $label 的 BscScan 链接',
            onPressed: () => unawaited(
              LoopCopy.text(context, url, message: 'BscScan 链接已复制'),
            ),
          ),
        ],
      ),
    );
  }
}
