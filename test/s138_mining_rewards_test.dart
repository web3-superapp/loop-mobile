import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_display.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_snapshot.dart';
import 'package:loop_mobile/integrations/backend/v2/mining_rewards/loop_v2_mining_rewards_codec.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S138 · 挖矿奖励: hourly two-track rewards, minute display, five invite
// levels, claim (decision 0140)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _walletId = 'd64786bb-408d-415d-8a69-6277d56c921b';
const String _walletAddress = '0x000000000000000000000000000000000000000a';
const String _claimId = 'a1b2c3d4-1111-4222-8333-444455556666';
const String _epochId = 'b1b2c3d4-1111-4222-8333-444455556666';
const String _versionId = 'c1b2c3d4-1111-4222-8333-444455556666';
const String _contract = '0x00000000000000000000000000000000000000c1';
const String _asset = 'eip155:97:0x00000000000000000000000000000000000000a5';
const String _hash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';

String _loop(int whole) => whole == 0 ? '0' : '$whole${'0' * 18}';

/// The hourly block as loop-api decision 0116 drafts it.
Map<String, Object?> _hourlyJson({
  String displayState = 'displaying',
  String serverTime = '2026-10-10T11:20:30.000Z',
  bool lastHour = true,
  int totalLoop = 60,
  bool tracks = true,
  bool referral = true,
  Map<String, Object?>? latestClaim,
  bool executable = true,
  String claimable = '120',
}) => <String, Object?>{
  'claimable': <String, Object?>{
    'status': 'unavailable',
    'reasonCode': 'REWARD_AUTHORITY_PENDING',
  },
  'claimExecutable': false,
  'estimatedToday': null,
  'accumulated': null,
  'ledger': <Object?>[],
  'source': null,
  'contractVersion': '2.0',
  'hourly': <String, Object?>{
    'serverTime': serverTime,
    'decimals': 18,
    'displayState': displayState,
    'reasonCode': null,
    'totals': <String, Object?>{
      'settledRaw': _loop(200),
      'claimedRaw': _loop(80),
      'claimableRaw': _loop(int.parse(claimable)),
    },
    'lastHour': lastHour
        ? <String, Object?>{
            'epochId': _epochId,
            'hourStart': '2026-10-10T10:00:00.000Z',
            'hourEnd': '2026-10-10T11:00:00.000Z',
            'settledAt': '2026-10-10T11:00:05.000Z',
            'nftRewardRaw': _loop(totalLoop * 2 ~/ 3),
            'assetRewardRaw': _loop(totalLoop - totalLoop * 2 ~/ 3),
            'totalRewardRaw': _loop(totalLoop),
          }
        : null,
    'display': lastHour
        ? <String, Object?>{
            'windowStart': '2026-10-10T11:00:00.000Z',
            'windowEnd': '2026-10-10T12:00:00.000Z',
            'totalRaw': _loop(totalLoop),
            'perMinuteRaw': _loop(totalLoop ~/ 60),
            'completedMinutes': 20,
            'displayedRaw': _loop(20),
            'nextUpdateAt': '2026-10-10T11:21:00.000Z',
          }
        : null,
    'tracks': tracks
        ? <String, Object?>{
            'nft': <String, Object?>{
              'realNftCount': '0',
              'selfPower': '0',
              'referralPower': '0.75',
              'totalPower': '0.75',
              'networkPower': '100',
              'budgetRaw': _loop(20833),
              'rewardRaw': _loop(40),
              'holdings': <Object?>[],
            },
            'asset': <String, Object?>{
              'selfPower': '1200.5',
              'referralPower': '35',
              'totalPower': '1235.5',
              'networkPower': '50000',
              'budgetRaw': _loop(20833),
              'rewardRaw': _loop(20),
              'holdings': <Object?>[
                <String, Object?>{
                  'assetId': _asset,
                  'balanceAtEndRaw': _loop(1000),
                  'power': '1200.5',
                },
              ],
              'excludedAssets': <Object?>[],
            },
          }
        : null,
    'referral': referral
        ? <String, Object?>{
            'levels': <Object?>[
              for (final (level, bps) in <(int, int)>[
                (1, 1000),
                (2, 500),
                (3, 300),
                (4, 200),
                (5, 100),
              ])
                <String, Object?>{
                  'level': level,
                  'ratioBps': bps,
                  'effectiveMembers': 6 - level,
                  'nftPower': level == 1 ? '0.5' : '0.0625',
                  'assetPower': '7',
                  'totalPower': '7.5',
                  'nftUnitsByCommunity': <Object?>[],
                },
            ],
          }
        : null,
    'parameters': <String, Object?>{
      'versionId': _versionId,
      'configVersion': 'mining.v1',
      'effectiveFrom': '2026-10-01T00:00:00.000Z',
      'referralRatiosBps': <Object?>[1000, 500, 300, 200, 100],
      'minimumClaimRaw': _loop(1),
    },
    'claim': <String, Object?>{
      'executable': executable,
      'reasonCode': executable ? null : 'MINING_CLAIM_WRITES_DISABLED',
      'latest': latestClaim,
    },
  },
};

Map<String, Object?> _claimJson({
  String status = 'succeeded',
  String? tx = _hash,
  String amount = '40',
}) => <String, Object?>{
  'claimId': _claimId,
  'walletId': _walletId,
  'status': status,
  'chainId': 'eip155:97',
  'chainReference': 97,
  'contractAddress': _contract,
  'cumulativeAmountRaw': _loop(120),
  'amountRaw': _loop(int.parse(amount)),
  'nonce': '1',
  'deadline': '2026-10-10T11:30:30.000Z',
  'transactionHash': tx,
  'blockNumber': tx == null ? null : '123',
  'failureReasonCode': status == 'failed' ? 'MINING_CLAIM_REVERTED' : null,
  'createdAt': '2026-10-10T11:20:30.000Z',
  'updatedAt': '2026-10-10T11:20:31.000Z',
};

Map<String, Object?> _preparedJson({
  String from = _walletAddress,
  String deadline = '2026-10-10T11:30:30.000Z',
}) => <String, Object?>{
  'claim': <String, Object?>{
    ..._claimJson(status: 'claimable', tx: null, amount: '120'),
    'deadline': deadline,
  },
  'intent': <String, Object?>{
    'calldata': <String, Object?>{
      'to': _contract,
      'data': '0xabcdef',
      'value': '0',
    },
    'unsignedTransaction': <String, Object?>{
      'chainId': 97,
      'to': _contract,
      'data': '0xabcdef',
      'from': from,
      'value': '0x0',
      'gas': '0x5208',
      'nonce': '0x1',
      'type': 'eip1559',
      'maxFeePerGas': '0x1',
      'maxPriorityFeePerGas': '0x1',
    },
    'signing': <String, Object?>{
      'mode': 'device_eth_send_transaction',
      'allowed': true,
      'reasonCode': null,
    },
  },
  'decimals': 18,
  'contractVersion': '2.0',
};

/// The S138 work order's flat draft, with every optional key omitted.
Map<String, Object?> _flatJson() => <String, Object?>{
  'settledTotal': '200',
  'claimedTotal': '80',
  'claimable': '120',
  'lastEpoch': <String, Object?>{
    'epochStart': '2026-10-10T10:00:00Z',
    'epochEnd': '2026-10-10T11:00:00Z',
    'totalReward': '60',
    'nftReward': '40',
    'assetReward': '20',
  },
  'display': <String, Object?>{
    'state': 'showing',
    'minutesElapsed': 20,
    'minuteIncrement': '1',
    'nextUpdateAt': '2026-10-10T11:21:00Z',
  },
  'nft': <String, Object?>{
    'realCount': 2,
    'ownPower': '3.5',
    'invitePower': '0.5',
    'totalPower': '4',
    'reward': '40',
  },
  'asset': <String, Object?>{
    'assets': <Object?>[
      <String, Object?>{'assetId': _asset, 'power': '10'},
    ],
    'ownPower': '10',
    'invitePower': '0',
    'totalPower': '10',
    'reward': '20',
  },
  'invites': <String, Object?>{
    'levels': <Object?>[
      for (var level = 1; level <= 5; level += 1)
        <String, Object?>{
          'level': level,
          'ratePercent': <int>[10, 5, 3, 2, 1][level - 1],
          'activeMembers': 1,
          'nftPower': '0.1',
          'assetPower': '1',
        },
    ],
    'total': <String, Object?>{'nftPower': '0.5', 'assetPower': '5'},
  },
  'claim': <String, Object?>{'status': 'none', 'lastTx': null},
  'serverTime': '2026-10-10T11:20:30Z',
};

MiningRewardsView _view([Map<String, Object?>? json]) =>
    LoopV2MiningRewardsCodec.rewards(json ?? _hourlyJson());

/// One scripted answer.
final class _Answer<T> {
  const _Answer.value(T this.value) : failure = null, pending = false;
  const _Answer.fail(LoopChainFailureKind kind, {String? reasonCode})
    : value = null,
      failure = (kind, reasonCode),
      pending = false;
  const _Answer.pending() : value = null, failure = null, pending = true;

  final T? value;
  final (LoopChainFailureKind, String?)? failure;
  final bool pending;

  Future<T> resolve() {
    if (pending) return Completer<T>().future;
    final f = failure;
    if (f != null) {
      return Future<T>.error(LoopChainException(f.$1, reasonCode: f.$2));
    }
    return Future<T>.value(value as T);
  }
}

final class _FakeRewards implements MiningRewardsGateway {
  _FakeRewards({
    required this.rewards,
    this.claims,
    this.prepareAnswer,
    this.reportAnswer,
  });

  /// The reads in order; the last one repeats.
  final List<_Answer<MiningRewardsView>> rewards;
  _Answer<MiningClaimPage>? claims;
  _Answer<MiningClaimPrepareResult>? prepareAnswer;
  _Answer<MiningClaimRecord>? reportAnswer;

  int rewardReads = 0;
  final List<String> prepareCalls = <String>[];
  final List<(String, String)> reportCalls = <(String, String)>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<MiningRewardsView> loadRewards() {
    final index = rewardReads;
    rewardReads += 1;
    return rewards[index < rewards.length ? index : rewards.length - 1]
        .resolve();
  }

  @override
  Future<MiningClaimPage> loadClaims({String? cursor}) =>
      (claims ??
              const _Answer<MiningClaimPage>.value(
                MiningClaimPage(items: <MiningClaimRecord>[]),
              ))
          .resolve();

  @override
  Future<MiningClaimPrepareResult> prepareClaim({required String walletId}) {
    prepareCalls.add(walletId);
    return (prepareAnswer ??
            const _Answer<MiningClaimPrepareResult>.fail(
              LoopChainFailureKind.unavailable,
            ))
        .resolve();
  }

  @override
  Future<MiningClaimRecord> reportClaim({
    required String claimId,
    required String txHash,
  }) {
    reportCalls.add((claimId, txHash));
    return (reportAnswer ??
            const _Answer<MiningClaimRecord>.fail(
              LoopChainFailureKind.unavailable,
            ))
        .resolve();
  }
}

final class _RecordingWallet implements WalletSigningGateway {
  final List<SigningIntent> handed = <SigningIntent>[];

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.available;

  @override
  String get label => 'test';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handed.add(intent);
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return const WalletHandoffResult(
      accepted: true,
      code: 'wallet_accepted',
      value: _hash,
    );
  }
}

final class _Restorer implements LoopSnapshotRestorer {
  _Restorer(this.value, this.observedAt);

  final Object value;
  final DateTime observedAt;
  final List<String> asked = <String>[];

  @override
  LoopRestoredSnapshot? restore(String resource) {
    asked.add(resource);
    return resource == LoopSnapshotResource.miningRewards
        ? LoopRestoredSnapshot(value: value, observedAt: observedAt)
        : null;
  }
}

/// The device clock the page reads. Tests move it by hand.
DateTime _now = DateTime.utc(2026, 10, 10, 11, 20, 30);

Future<void> _pump(
  WidgetTester tester, {
  required _FakeRewards rewards,
  _RecordingWallet? wallet,
  bool settle = true,
  void Function(MiningSuggestedSwap?)? onOpenSwap,
  VoidCallback? onOpenReceive,
  List<Override> overrides = const <Override>[],
}) => pumpS7Page(
  tester,
  MiningRewardsHourlyScreen(
    onOpenSwap: onOpenSwap,
    onOpenReceive: onOpenReceive,
  ),
  settle: settle,
  wallet: FakeWalletDirectory(
    activeWalletId: _walletId,
    wallets: <LoopWalletAccount>[
      LoopWalletAccount(
        walletId: _walletId,
        address: _walletAddress,
        kind: LoopWalletKind.embedded,
        status: LoopWalletStatus.active,
        isActive: true,
        firstSeenAt: DateTime.utc(2026, 9),
        lastSeenAt: DateTime.utc(2026, 10, 8),
      ),
    ],
  ),
  overrides: <Override>[
    miningRewardsGatewayProvider.overrideWithValue(rewards),
    loopReadClockProvider.overrideWithValue(() => _now),
    miningClaimPollingProvider.overrideWithValue(
      const MiningClaimPolling(
        interval: Duration(milliseconds: 10),
        maxAttempts: 5,
      ),
    ),
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
    ...overrides,
  ],
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 5));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 240, scrollable: find.byType(Scrollable).first);

void main() {
  setUp(() => _now = DateTime.utc(2026, 10, 10, 11, 20, 30));

  group('minute display derivation', () {
    final total = BigInt.parse(_loop(60));

    test('one sixtieth per completed minute, the remainder on the 60th', () {
      expect(miningMinuteShown(total, 0), BigInt.zero);
      expect(miningMinuteShown(total, 20), BigInt.parse(_loop(20)));
      // 100 units do not divide by 60: each minute adds 1, minute 60 lands on
      // the whole hour.
      final odd = BigInt.from(100);
      expect(miningMinuteShown(odd, 59), BigInt.from(59));
      expect(miningMinuteShown(odd, 60), odd);
      expect(miningMinuteShown(odd, 75), odd);
    });

    test('derived from the server clock, not a counter', () {
      final view = _view();
      final at = miningMinuteProgress(
        view,
        serverNow: DateTime.utc(2026, 10, 10, 11, 20, 30),
      );
      expect(at.phase, MiningMinutePhase.showing);
      expect(at.completedMinutes, 20);
      expect(at.shown, BigInt.parse(_loop(20)));
      expect(at.nextUpdateAt, DateTime.utc(2026, 10, 10, 11, 21));
      // The same instant from another device gives the same figure.
      final again = miningMinuteProgress(
        view,
        serverNow: DateTime.utc(2026, 10, 10, 11, 20, 59),
      );
      expect(again.shown, at.shown);
      final last = miningMinuteProgress(
        view,
        serverNow: DateTime.utc(2026, 10, 10, 11, 59, 59),
      );
      expect(last.completedMinutes, 59);
      expect(last.shown, BigInt.parse(_loop(59)));
    });

    test('the server clock follows device durations, not its wall clock', () {
      // A phone set a day wrong: only the elapsed time since the answer
      // counts.
      final serverNow = miningServerNow(
        serverTime: DateTime.utc(2026, 10, 10, 11, 20, 30),
        receivedAt: DateTime.utc(2026, 10, 9, 8),
        deviceNow: DateTime.utc(2026, 10, 9, 8, 2),
      );
      expect(serverNow, DateTime.utc(2026, 10, 10, 11, 22, 30));
      // A clock moved backwards does not run the server clock backwards.
      expect(
        miningServerNow(
          serverTime: DateTime.utc(2026, 10, 10, 11),
          receivedAt: DateTime.utc(2026, 10, 10, 12),
          deviceNow: DateTime.utc(2026, 10, 10, 11),
        ),
        DateTime.utc(2026, 10, 10, 11),
      );
    });

    test('first hour: nothing to grow and nothing faked', () {
      final view = _view(
        _hourlyJson(displayState: 'awaiting_first_settlement', lastHour: false),
      );
      final progress = miningMinuteProgress(
        view,
        serverNow: DateTime.utc(2026, 10, 10, 11, 20),
      );
      expect(progress.phase, MiningMinutePhase.awaitingFirstSettlement);
      expect(progress.shown, BigInt.zero);
    });

    test('settling: the server says so, or the window has closed', () {
      final settling = _view(_hourlyJson(displayState: 'settling'));
      final a = miningMinuteProgress(
        settling,
        serverNow: DateTime.utc(2026, 10, 10, 12, 0, 30),
      );
      expect(a.phase, MiningMinutePhase.settling);
      expect(a.shown, BigInt.parse(_loop(60)));
      final showing = _view();
      final b = miningMinuteProgress(
        showing,
        serverNow: DateTime.utc(2026, 10, 10, 12, 0, 1),
      );
      expect(b.phase, MiningMinutePhase.settling);
      expect(b.nextUpdateAt, isNull);
    });
  });

  group('codec', () {
    test('hourly block decodes into the six modules', () {
      final view = _view();
      expect(view.settledTotal, BigInt.parse(_loop(200)));
      expect(view.claimedTotal, BigInt.parse(_loop(80)));
      expect(view.claimable, BigInt.parse(_loop(120)));
      expect(view.lastEpoch!.totalReward, BigInt.parse(_loop(60)));
      expect(view.display.state, MiningDisplayState.showing);
      expect(view.nft!.realCount, BigInt.zero);
      expect(view.nft!.invitePower, Decimal.parse('0.75'));
      expect(view.asset!.assets.single.assetId, _asset);
      expect(
        view.invites!.levels.map((l) => l.ratePercent.toString()),
        <String>['10', '5', '3', '2', '1'],
      );
      expect(view.invites!.total.activeMembers, 15);
      expect(view.invites!.total.assetPower, Decimal.fromInt(35));
      expect(view.claim.status, MiningClaimStatus.none);
      expect(view.minimumClaim, BigInt.parse(_loop(1)));
    });

    test('flat draft decodes with every optional key absent', () {
      final view = _view(_flatJson());
      expect(view.claimable, BigInt.parse(_loop(120)));
      expect(view.display.minuteIncrement, BigInt.parse(_loop(1)));
      expect(view.nft!.realCount, BigInt.two);
      expect(view.invites!.total.activeMembers, 5);
      expect(view.claim.executable, isTrue);
      expect(view.claim.lastTx, isNull);
      expect(view.minimumClaim, isNull);
    });

    test('flat draft accepts its optional keys when sent', () {
      final json = _flatJson()
        ..['contractVersion'] = '2.0'
        ..['minimumClaim'] = '1'
        ..['claim'] = <String, Object?>{
          'status': 'succeeded',
          'lastTx': <String, Object?>{'txHash': _hash, 'chainId': 'eip155:97'},
          'executable': false,
          'claimId': _claimId,
        };
      final view = _view(json);
      expect(view.claim.status, MiningClaimStatus.succeeded);
      expect(
        view.claim.lastTx!.explorerUrl,
        'https://testnet.bscscan.com/tx/$_hash',
      );
      expect(view.claim.executable, isFalse);
      expect(view.minimumClaim, BigInt.parse(_loop(1)));
    });

    test('an unknown key or a bad amount is an invalid payload', () {
      final extra = _flatJson()..['surprise'] = 1;
      expect(() => _view(extra), throwsA(isA<LoopBackendFailure>()));
      final bad = _flatJson()..['claimable'] = '1.0000000000000000001';
      expect(() => _view(bad), throwsA(isA<LoopBackendFailure>()));
      final hourly = _hourlyJson();
      (hourly['hourly']! as Map<String, Object?>)['decimals'] = 6;
      expect(() => _view(hourly), throwsA(isA<LoopBackendFailure>()));
    });

    test('snapshot restore runs the live decoder', () {
      final restored = LoopV2SnapshotSession.decode(
        LoopSnapshotResource.miningRewards,
        _hourlyJson(),
      );
      expect(restored, isA<MiningRewardsView>());
      expect(
        LoopSnapshotResource.isStable(LoopSnapshotResource.miningRewards),
        isTrue,
      );
    });

    test('prepared claim binds the transaction to the reviewed contract', () {
      final intent = LoopV2MiningRewardsCodec.prepared(_preparedJson());
      expect(intent.claimId, _claimId);
      expect(intent.amount, BigInt.parse(_loop(120)));
      expect(intent.payloadMatchesReview, isTrue);
      expect(intent.payloadDigest, hasLength(64));
      final other = _preparedJson();
      ((other['intent']! as Map<String, Object?>)['calldata']!
              as Map<String, Object?>)['data'] =
          '0xabcd';
      expect(
        LoopV2MiningRewardsCodec.prepared(other).payloadMatchesReview,
        isFalse,
      );
    });

    test('gas refusals: envelope code or detailsSafe, nested or flat', () {
      final flat = LoopV2MiningRewardsCodec.gasRefusal(<String, Object?>{
        'code': 'INSUFFICIENT_BALANCE',
        'detailsSafe': <String, Object?>{
          'reasonCode': 'CLAIM_GAS_INSUFFICIENT',
          'requiredNativeAmount': '0.0004',
          'suggestedSwapFromSymbol': 'USDT',
          'suggestedSwapFromAssetId':
              'eip155:56:0x55d398326f99059ff775485246999027b3197955',
          'suggestedSwapToSymbol': 'BNB',
          'suggestedSwapToAssetId': 'eip155:56:native',
          'suggestedSwapToAmount': '0.0005',
        },
      });
      expect(flat!.reason, 'CLAIM_GAS_INSUFFICIENT');
      expect(flat.swap!.toAssetId, 'eip155:56:native');
      expect(flat.requiredNative, '0.0004');
      final nested = LoopV2MiningRewardsCodec.gasRefusal(<String, Object?>{
        'code': 'CLAIM_GAS_INSUFFICIENT',
        'detailsSafe': <String, Object?>{
          'suggestedSwap': <String, Object?>{
            'fromAssetId':
                'eip155:56:0x55d398326f99059ff775485246999027b3197955',
            'toAssetId': 'eip155:56:native',
          },
        },
      });
      expect(nested!.swap!.fromAssetId, startsWith('eip155:56:0x55d3'));
      final none = LoopV2MiningRewardsCodec.gasRefusal(<String, Object?>{
        'code': 'CLAIM_NO_GAS_SOURCE',
      });
      expect(none!.reason, 'CLAIM_NO_GAS_SOURCE');
      expect(
        LoopV2MiningRewardsCodec.gasRefusal(<String, Object?>{
          'code': 'INSUFFICIENT_BALANCE',
          'detailsSafe': <String, Object?>{
            'reasonCode': 'MINING_CLAIM_NOTHING_TO_CLAIM',
          },
        }),
        isNull,
      );
    });

    test('figures: 4 decimals, truncated, grouped', () {
      expect(
        miningLoopFigure(BigInt.parse('1234567890000000000000')),
        '1,234.5678',
      );
      expect(miningLoopFigure(BigInt.parse('99999')), '0.0000');
      expect(miningPowerFigure(Decimal.parse('1235.50')), '1,235.5');
    });
  });

  group('page', () {
    loopWatchGround();

    testWidgets('six modules render from the answer', (tester) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
      );
      await _pump(tester, rewards: rewards);
      expect(_key('mining-minute-showing'), findsOneWidget);
      expect(_key('mining-minute-figure-20.0000'), findsOneWidget);
      expect(find.text('上一小时 60.0000 LOOP'), findsOneWidget);
      expect(_key('mining-summary-settled'), findsOneWidget);
      expect(find.text('200.0000'), findsOneWidget);
      expect(find.text('80.0000'), findsOneWidget);
      expect(_key('mining-claim-amount'), findsOneWidget);
      expect(find.text('120.0000 LOOP'), findsOneWidget);
      await _scrollTo(tester, _key('mining-nft-track'));
      // No real NFT, but invite power: the two are separate rows.
      expect(
        find.descendant(
          of: _key('mining-nft-real-count'),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(find.text('0.75'), findsWidgets);
      await _scrollTo(tester, _key('mining-asset-track'));
      expect(_key('mining-asset-$_asset'), findsOneWidget);
      await _scrollTo(tester, _key('mining-invite-total'));
      expect(_key('mining-invite-level-5'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('1%'), findsOneWidget);
      await _scrollTo(tester, _key('mining-claims-empty'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await _drain(tester);
    });

    testWidgets('claim records list the server\'s claims', (tester) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
        claims: _Answer.value(
          LoopV2MiningRewardsCodec.claims(<String, Object?>{
            'items': <Object?>[_claimJson()],
            'nextCursor': null,
            'decimals': 18,
            'contractVersion': '2.0',
          }),
        ),
      );
      await _pump(tester, rewards: rewards);
      await _scrollTo(tester, _key('mining-claim-record-$_claimId'));
      expect(find.text('领取 40.0000 LOOP'), findsOneWidget);
      expect(find.textContaining(miningShortHash(_hash)), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the figure steps once a minute and survives a re-read', (
      tester,
    ) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
      );
      await _pump(tester, rewards: rewards);
      expect(_key('mining-minute-figure-20.0000'), findsOneWidget);
      _now = _now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(_key('mining-minute-figure-21.0000'), findsOneWidget);
      // Ten minutes in the background: derived again, not counted.
      _now = _now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_key('mining-minute-figure-31.0000'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('first hour and settling say so', (tester) async {
      final awaiting = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            _view(
              _hourlyJson(
                displayState: 'awaiting_first_settlement',
                lastHour: false,
                tracks: false,
                referral: false,
                claimable: '0',
              ),
            ),
          ),
        ],
      );
      await _pump(tester, rewards: awaiting);
      expect(find.text('首个小时结算后开始展示奖励'), findsOneWidget);
      expect(_key('mining-nft-pending'), findsOneWidget);
      await _drain(tester);

      _now = DateTime.utc(2026, 10, 10, 12, 0, 20);
      final settling = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            _view(
              _hourlyJson(
                displayState: 'settling',
                serverTime: '2026-10-10T12:00:20.000Z',
              ),
            ),
          ),
        ],
      );
      await _pump(tester, rewards: settling);
      expect(_key('mining-minute-settling-tag'), findsOneWidget);
      expect(find.text('结算中'), findsOneWidget);
      expect(_key('mining-minute-figure-60.0000'), findsOneWidget);
      // It asks again at once instead of waiting a whole interval.
      expect(settling.rewardReads, greaterThanOrEqualTo(2));
      await _drain(tester);
    });

    testWidgets('first frame draws the stored answer; claim waits for live', (
      tester,
    ) async {
      // Stored five minutes ago at 11:15:30 server time: the minute is
      // derived from it, 20 minutes in, with no live answer yet.
      final stored = _view(_hourlyJson(serverTime: '2026-10-10T11:15:30.000Z'));
      final restorer = _Restorer(
        stored,
        _now.subtract(const Duration(minutes: 5)),
      );
      await _pump(
        tester,
        rewards: _FakeRewards(
          rewards: const <_Answer<MiningRewardsView>>[_Answer.pending()],
        ),
        settle: false,
        overrides: <Override>[
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ],
      );
      expect(restorer.asked, contains(LoopSnapshotResource.miningRewards));
      expect(_key('mining-rewards-state-loading'), findsNothing);
      expect(_key('mining-minute-figure-20.0000'), findsOneWidget);
      expect(find.text('120.0000 LOOP'), findsOneWidget);
      expect(_key('mining-claim-disabled'), findsOneWidget);
      expect(find.text('正在读取最新的可领取数量'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('loading, error, offline, unavailable, permission', (
      tester,
    ) async {
      await _pump(
        tester,
        rewards: _FakeRewards(
          rewards: const <_Answer<MiningRewardsView>>[_Answer.pending()],
        ),
        settle: false,
      );
      expect(_key('mining-rewards-state-loading'), findsOneWidget);
      await _drain(tester);

      for (final (kind, key) in <(LoopChainFailureKind, String)>[
        (LoopChainFailureKind.invalidData, 'mining-rewards-state-error'),
        (LoopChainFailureKind.offline, 'mining-rewards-state-offline'),
        (LoopChainFailureKind.unavailable, 'mining-rewards-state-unavailable'),
        (
          LoopChainFailureKind.permissionDenied,
          'mining-rewards-state-permission',
        ),
      ]) {
        await _pump(
          tester,
          rewards: _FakeRewards(
            rewards: <_Answer<MiningRewardsView>>[_Answer.fail(kind)],
          ),
        );
        expect(_key(key), findsOneWidget, reason: kind.name);
        await _drain(tester);
      }
    });

    testWidgets('claim status shows the five states the server reports', (
      tester,
    ) async {
      for (final (status, key) in <(String?, String)>[
        (null, 'mining-claim-status-none'),
        ('submitting', 'mining-claim-status-submitting'),
        ('confirming', 'mining-claim-status-confirming'),
        ('succeeded', 'mining-claim-status-succeeded'),
        ('failed', 'mining-claim-status-failed'),
      ]) {
        final latest = status == null
            ? null
            : _claimJson(
                status: status,
                tx: status == 'submitting' ? null : _hash,
              );
        final rewards = _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[
            _Answer.value(_view(_hourlyJson(latestClaim: latest))),
          ],
        );
        await _pump(tester, rewards: rewards, settle: false);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(_key(key), findsOneWidget, reason: status);
        if (status == 'succeeded') {
          expect(_key('mining-claim-tx'), findsOneWidget);
        }
        if (status == 'submitting' || status == 'confirming') {
          // In flight: no second claim is offered.
          final button = tester.widget<Widget>(_key('mining-claim-button'));
          expect((button as dynamic).onPressed, isNull);
        }
        await _drain(tester);
      }
    });

    testWidgets('claim: prepare, confirm wallet and amount, report, succeed', (
      tester,
    ) async {
      final prepared = LoopV2MiningRewardsCodec.prepared(_preparedJson());
      final wallet = _RecordingWallet();
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(_view()),
          _Answer.value(_view()),
          _Answer.value(
            _view(_hourlyJson(latestClaim: _claimJson(amount: '120'))),
          ),
        ],
        prepareAnswer: _Answer.value(MiningClaimPrepared(prepared)),
        reportAnswer: _Answer.value(
          LoopV2MiningRewardsCodec.claimRecord(
            _claimJson(status: 'submitting', amount: '120'),
          ),
        ),
      );
      await _pump(tester, rewards: rewards, wallet: wallet);
      await tester.tap(_key('mining-claim-button'));
      await tester.pumpAndSettle();
      expect(rewards.prepareCalls, <String>[_walletId]);
      expect(_key('mining-claim-sign-sheet'), findsOneWidget);
      expect(find.text('120.0000 LOOP'), findsWidgets);
      expect(find.text(miningShortHash(_walletAddress)), findsOneWidget);
      final sheet = tester.widget<LoopSignSheet>(
        _key('mining-claim-sign-sheet'),
      );
      sheet.onConfirm!();
      await tester.pump();
      await tester.pump();
      expect(wallet.handed.single.payloadDigest, prepared.payloadDigest);
      expect(rewards.reportCalls.single, (_claimId, _hash));
      await tester.tap(
        find.text('关闭').hitTestable().first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      // The page closed the sheet with the outcome; the claim was read
      // until it settled.
      for (var i = 0; i < 5; i += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(_key('mining-claim-status-succeeded'), findsOneWidget);
      expect(find.text('领取成功，LOOP 已到账。'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('cancel before the wallet: nothing sent, balance kept', (
      tester,
    ) async {
      final prepared = LoopV2MiningRewardsCodec.prepared(_preparedJson());
      final wallet = _RecordingWallet();
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
        prepareAnswer: _Answer.value(MiningClaimPrepared(prepared)),
      );
      await _pump(tester, rewards: rewards, wallet: wallet);
      await tester.tap(_key('mining-claim-button'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<LoopSignSheet>(
        _key('mining-claim-sign-sheet'),
      );
      sheet.onCancel!();
      await tester.pumpAndSettle();
      expect(wallet.handed, isEmpty);
      expect(rewards.reportCalls, isEmpty);
      expect(find.text('120.0000 LOOP'), findsOneWidget);
      expect(_key('mining-claim-status-none'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('BNB short: one sheet, 「去兑换」 opens the swap pair', (
      tester,
    ) async {
      const swap = MiningSuggestedSwap(
        fromAssetId: 'eip155:56:0x55d398326f99059ff775485246999027b3197955',
        toAssetId: 'eip155:56:native',
        fromSymbol: 'USDT',
        toSymbol: 'BNB',
      );
      MiningSuggestedSwap? opened;
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
        prepareAnswer: const _Answer.value(
          MiningClaimGasInsufficient(swap: swap, requiredNative: '0.0004'),
        ),
      );
      await _pump(tester, rewards: rewards, onOpenSwap: (s) => opened = s);
      await tester.tap(_key('mining-claim-button'));
      await tester.pumpAndSettle();
      expect(_key('mining-claim-gas-swap'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('mining-claim-gas-swap'),
          matching: find.textContaining('BNB 不足以支付网络费，先用 USDT 兑换'),
        ),
        findsOneWidget,
      );
      await tester.tap(_key('mining-claim-gas-go'));
      await tester.pumpAndSettle();
      expect(opened, same(swap));
      expect(_key('mining-claim-status-none'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('no BNB and no USDT: 「去充值」', (tester) async {
      var receive = 0;
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
        prepareAnswer: const _Answer.value(MiningClaimNoGasSource()),
      );
      await _pump(tester, rewards: rewards, onOpenReceive: () => receive += 1);
      await tester.tap(_key('mining-claim-button'));
      await tester.pumpAndSettle();
      expect(_key('mining-claim-gas-none'), findsOneWidget);
      await tester.tap(_key('mining-claim-gas-go'));
      await tester.pumpAndSettle();
      expect(receive, 1);
      await _drain(tester);
    });

    testWidgets('a lost report keeps the hash and offers 重新上报, not a resign', (
      tester,
    ) async {
      final prepared = LoopV2MiningRewardsCodec.prepared(_preparedJson());
      final wallet = _RecordingWallet();
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
        prepareAnswer: _Answer.value(MiningClaimPrepared(prepared)),
        reportAnswer: const _Answer.fail(LoopChainFailureKind.offline),
      );
      await _pump(tester, rewards: rewards, wallet: wallet);
      await tester.tap(_key('mining-claim-button'));
      await tester.pumpAndSettle();
      tester
          .widget<LoopSignSheet>(_key('mining-claim-sign-sheet'))
          .onConfirm!();
      await tester.pump();
      await tester.pump();
      tester.widget<LoopSignSheet>(_key('mining-claim-sign-sheet')).onCancel!();
      await tester.pumpAndSettle();
      expect(_key('mining-claim-retry-report'), findsOneWidget);
      expect(_key('mining-claim-button'), findsNothing);
      expect(wallet.handed, hasLength(1));
      await _drain(tester);
    });
  });
}
