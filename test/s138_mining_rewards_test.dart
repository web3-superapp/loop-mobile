import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/crypto/loop_keccak.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_display.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_screen.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_snapshot.dart';
import 'package:loop_mobile/integrations/backend/v2/mining_rewards/loop_v2_mining_rewards_api.dart';
import 'package:loop_mobile/integrations/backend/v2/mining_rewards/loop_v2_mining_rewards_codec.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S138 · 挖矿奖励: hourly two-track rewards, minute display, five invite
// levels, claim (decision 0140), aligned with the loop-api contract
// `frontend-v2-mining-rewards-api.md` (decision 0141)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The hero's folio (decision 0167): kicker, heading, caption and stamp are
/// read off the one `LoopFolioPrimary` inside `MiningMinuteHero`.
LoopFolioPrimary _heroFolio(WidgetTester tester) =>
    tester.widget<LoopFolioPrimary>(
      find.descendant(
        of: find.byType(MiningMinuteHero),
        matching: find.byType(LoopFolioPrimary),
      ),
    );

const String _walletId = 'd64786bb-408d-415d-8a69-6277d56c921b';
const String _walletAddress = '0x000000000000000000000000000000000000000a';
const String _claimId = 'a1b2c3d4-1111-4222-8333-444455556666';
const String _epochId = 'b1b2c3d4-1111-4222-8333-444455556666';
const String _versionId = 'c1b2c3d4-1111-4222-8333-444455556666';
const String _contract = '0x00000000000000000000000000000000000000c1';
const String _asset = 'eip155:97:0x00000000000000000000000000000000000000a5';
const String _graduated =
    'eip155:97:0x00000000000000000000000000000000000000b6';
const String _hash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';

String _loop(int whole) => whole == 0 ? '0' : '$whole${'0' * 18}';

/// `GET /v2/mining/rewards` as the contract publishes it (§3).
Map<String, Object?> _hourlyJson({
  String displayState = 'displaying',
  String serverTime = '2026-10-10T11:20:30.000Z',
  bool lastHour = true,
  int totalLoop = 60,
  bool tracks = true,
  bool referral = true,
  Map<String, Object?>? latestClaim,
  bool executable = true,
  String claimReason = 'MINING_CLAIM_WRITES_DISABLED',
  String claimable = '120',
  bool excluded = false,
  String? displayedRaw,
  bool parameters = true,
  // Decision 0185: `hourly.claim.configurationReasonCode`. Omitted by default
  // (an older backend), so decision 0184's cases still read the inference.
  bool configurationReported = false,
  String? configurationReason,
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
            'displayedRaw': displayedRaw ?? _loop(20),
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
              'excludedAssets': <Object?>[
                if (excluded)
                  <String, Object?>{
                    'assetId': _graduated,
                    'reasonCode': 'MINING_ASSET_GRADUATED_UNREADABLE',
                  },
              ],
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
    'parameters': parameters
        ? <String, Object?>{
            'versionId': _versionId,
            'configVersion': 'miningHourlyV1',
            'effectiveFrom': '2026-10-01T00:00:00.000Z',
            'referralRatiosBps': <Object?>[1000, 500, 300, 200, 100],
            'minimumClaimRaw': _loop(1),
          }
        : null,
    'claim': <String, Object?>{
      'executable': executable,
      'reasonCode': executable ? null : claimReason,
      if (configurationReported) 'configurationReasonCode': configurationReason,
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

/// The contract's digest (§5.2, loop-api decision 0123), written out the way
/// the server's own test builds it: `{"k":v,...}` with keys sorted by code
/// unit, each key and value JSON-encoded on its own, no whitespace, then
/// `0x` + keccak-256 of the UTF-8 bytes. Independent of the codec's
/// `localDigest`, so a drift in either shows up here.
String _contractDigest(Map<String, Object?> transaction) {
  final keys = transaction.keys.toList()..sort();
  final canonical =
      '{${keys.map((key) => '${jsonEncode(key)}:${jsonEncode(transaction[key])}').join(',')}}';
  final bytes = loopKeccak256(utf8.encode(canonical));
  return '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}

Map<String, Object?> _preparedJson({
  String from = _walletAddress,
  String deadline = '2026-10-10T11:30:30.000Z',
}) {
  final transaction = <String, Object?>{
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
    'gasPrice': null,
  };
  return <String, Object?>{
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
      'unsignedTransaction': transaction,
      'payloadDigest': _contractDigest(transaction),
      'signing': <String, Object?>{
        'mode': 'device_eth_send_transaction',
        'allowed': true,
        'reasonCode': null,
      },
    },
    'decimals': 18,
    'contractVersion': '2.0',
  };
}

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
    this.reportAnswers = const <_Answer<MiningClaimRecord>>[],
  });

  /// The reads in order; the last one repeats.
  final List<_Answer<MiningRewardsView>> rewards;
  _Answer<MiningClaimPage>? claims;
  _Answer<MiningClaimPrepareResult>? prepareAnswer;

  /// The reports in order; the last one repeats.
  final List<_Answer<MiningClaimRecord>> reportAnswers;

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
    final index = reportCalls.length;
    reportCalls.add((claimId, txHash));
    if (reportAnswers.isEmpty) {
      return const _Answer<MiningClaimRecord>.fail(
        LoopChainFailureKind.unavailable,
      ).resolve();
    }
    return reportAnswers[index < reportAnswers.length
            ? index
            : reportAnswers.length - 1]
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

/// One preflight sample under `test/fixtures/s138-mining-rewards/`.
Map<String, Object?> _fixture(String name) => jsonDecode(
  File('test/fixtures/s138-mining-rewards/$name.json').readAsStringSync(),
) as Map<String, Object?>;

/// Replays one sample, headers and status included, through Dio.
final class _ReplayAdapter implements HttpClientAdapter {
  _ReplayAdapter(this.record);

  final Map<String, Object?> record;
  RequestOptions? last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    final headers = <String, List<String>>{
      for (final entry in (record['headers']! as Map<String, Object?>).entries)
        entry.key: <String>['${entry.value}'],
    };
    return ResponseBody.fromString(
      jsonEncode(record['body']),
      record['status']! as int,
      headers: headers,
    );
  }
}

DioLoopV2MiningRewardsApi _replay(String name) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.example'));
  dio.httpClientAdapter = _ReplayAdapter(_fixture(name));
  return DioLoopV2MiningRewardsApi(dio);
}

const String _fixtureWalletId = 'd64786bb-408d-415d-8a69-6277d56c921b';

void main() {
  setUp(() => _now = DateTime.utc(2026, 10, 10, 11, 20, 30));

  group('minute display derivation (contract §3.2)', () {
    final total = BigInt.parse(_loop(60));

    test('floor(total × m / 60), the 60th minute is the whole hour', () {
      expect(miningMinuteShown(total, 0), BigInt.zero);
      expect(miningMinuteShown(total, 20), BigInt.parse(_loop(20)));
      // 100 units do not divide by 60: floor(100 × 59 / 60) = 98, and minute
      // 60 lands on the whole hour.
      final odd = BigInt.from(100);
      expect(miningMinuteShown(odd, 1), BigInt.one);
      expect(miningMinuteShown(odd, 30), BigInt.from(50));
      expect(miningMinuteShown(odd, 59), BigInt.from(98));
      expect(miningMinuteShown(odd, 60), odd);
      expect(miningMinuteShown(odd, 75), odd);
    });

    test('derived from the server clock, not a counter', () {
      final view = _view();
      final at = miningMinuteProgress(
        view,
        serverNow: DateTime.utc(2026, 10, 10, 11, 20, 30),
      );
      expect(at.phase, MiningMinutePhase.displaying);
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

    test('the server displayedRaw wins for its own minute only', () {
      // A total that does not divide by 60 in whole LOOP: the two agree, and
      // the server's figure is used as it is for minute 20.
      final odd = _view(
        _hourlyJson(totalLoop: 61, displayedRaw: '20333333333333333333'),
      );
      final at20 = miningMinuteProgress(
        odd,
        serverNow: DateTime.utc(2026, 10, 10, 11, 20, 10),
      );
      expect(at20.shown, BigInt.parse('20333333333333333333'));
      expect(
        at20.shown,
        miningMinuteShown(BigInt.parse(_loop(61)), 20),
        reason: 'the client formula is the server formula',
      );
      // A server figure that disagrees is still the server's for its minute;
      // the next minute is the formula's.
      final skewed = _view(_hourlyJson(displayedRaw: _loop(19)));
      expect(
        miningMinuteProgress(
          skewed,
          serverNow: DateTime.utc(2026, 10, 10, 11, 20, 30),
        ).shown,
        BigInt.parse(_loop(19)),
      );
      expect(
        miningMinuteProgress(
          skewed,
          serverNow: DateTime.utc(2026, 10, 10, 11, 21, 0),
        ).shown,
        BigInt.parse(_loop(21)),
      );
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

    test('settling: the server says so, or windowEnd has passed', () {
      final settling = _view(_hourlyJson(displayState: 'settling'));
      final a = miningMinuteProgress(
        settling,
        serverNow: DateTime.utc(2026, 10, 10, 12, 0, 30),
      );
      expect(a.phase, MiningMinutePhase.settling);
      expect(a.shown, BigInt.parse(_loop(60)));
      final displaying = _view();
      final b = miningMinuteProgress(
        displaying,
        serverNow: DateTime.utc(2026, 10, 10, 12, 0, 0),
      );
      expect(b.phase, MiningMinutePhase.settling);
      expect(b.shown, BigInt.parse(_loop(60)));
      expect(b.nextUpdateAt, isNull);
    });
  });

  group('codec (contract §3, §5)', () {
    test('the hourly block decodes into the six modules', () {
      final view = _view(_hourlyJson(excluded: true));
      expect(view.settledTotal, BigInt.parse(_loop(200)));
      expect(view.claimedTotal, BigInt.parse(_loop(80)));
      expect(view.claimable, BigInt.parse(_loop(120)));
      expect(view.lastEpoch!.totalReward, BigInt.parse(_loop(60)));
      expect(view.display.state, MiningDisplayState.displaying);
      expect(view.display.window!.displayed, BigInt.parse(_loop(20)));
      expect(view.display.window!.windowEnd, DateTime.utc(2026, 10, 10, 12));
      expect(view.nft!.realCount, BigInt.zero);
      expect(view.nft!.invitePower, Decimal.parse('0.75'));
      expect(view.asset!.assets.single.assetId, _asset);
      expect(view.asset!.assets.single.balanceAtEnd, BigInt.parse(_loop(1000)));
      expect(view.asset!.excluded.single.assetId, _graduated);
      expect(
        view.asset!.excluded.single.reasonCode,
        'MINING_ASSET_GRADUATED_UNREADABLE',
      );
      expect(
        view.invites!.levels.map((l) => l.ratePercent.toString()),
        <String>['10', '5', '3', '2', '1'],
      );
      expect(view.invites!.total.activeMembers, 15);
      expect(view.invites!.total.assetPower, Decimal.fromInt(35));
      expect(view.claim.status, MiningClaimStatus.none);
      expect(view.claim.executable, isTrue);
      expect(view.minimumClaim, BigInt.parse(_loop(1)));
    });

    test('the legacy daily keys may be absent; hourly is required', () {
      final json = _hourlyJson();
      for (final key in LoopV2MiningRewardsCodec.legacyRootKeys) {
        json.remove(key);
      }
      expect(_view(json).claimable, BigInt.parse(_loop(120)));
      final noHourly = _hourlyJson()..remove('hourly');
      expect(() => _view(noHourly), throwsA(isA<LoopBackendFailure>()));
      final noVersion = _hourlyJson()..remove('contractVersion');
      expect(() => _view(noVersion), throwsA(isA<LoopBackendFailure>()));
    });

    test('the retired flat draft is no longer read', () {
      expect(
        () => _view(<String, Object?>{
          'settledTotal': '200',
          'claimedTotal': '80',
          'claimable': '120',
          'lastEpoch': null,
          'display': <String, Object?>{
            'state': 'showing',
            'minutesElapsed': 0,
            'minuteIncrement': '0',
            'nextUpdateAt': null,
          },
          'nft': null,
          'asset': null,
          'invites': null,
          'claim': <String, Object?>{'status': 'none', 'lastTx': null},
          'serverTime': '2026-10-10T11:20:30Z',
        }),
        throwsA(isA<LoopBackendFailure>()),
      );
      final showing = _hourlyJson();
      (showing['hourly']! as Map<String, Object?>)['displayState'] = 'showing';
      expect(() => _view(showing), throwsA(isA<LoopBackendFailure>()));
    });

    test('an unknown key, a missing key or a bad amount is invalid', () {
      final extra = _hourlyJson();
      (extra['hourly']! as Map<String, Object?>)['surprise'] = 1;
      expect(() => _view(extra), throwsA(isA<LoopBackendFailure>()));
      final missing = _hourlyJson();
      ((missing['hourly']! as Map<String, Object?>)['display']!
              as Map<String, Object?>)
          .remove('displayedRaw');
      expect(() => _view(missing), throwsA(isA<LoopBackendFailure>()));
      final decimals = _hourlyJson();
      (decimals['hourly']! as Map<String, Object?>)['decimals'] = 6;
      expect(() => _view(decimals), throwsA(isA<LoopBackendFailure>()));
      final fraction = _hourlyJson();
      ((fraction['hourly']! as Map<String, Object?>)['totals']!
              as Map<String, Object?>)['claimableRaw'] =
          '1.5';
      expect(() => _view(fraction), throwsA(isA<LoopBackendFailure>()));
      final fourLevels = _hourlyJson();
      (((fourLevels['hourly']! as Map<String, Object?>)['referral']!
                  as Map<String, Object?>)['levels']!
              as List<Object?>)
          .removeLast();
      expect(() => _view(fourLevels), throwsA(isA<LoopBackendFailure>()));
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
      // The server's digest, recomputed on the device (decision 0143).
      expect(
        intent.payloadDigest,
        '0x${LoopV2MiningRewardsCodec.localDigest(intent.transaction.wire)}',
      );
      expect(intent.payloadDigest, _contractDigest(intent.transaction.wire));
      expect(intent.localPayloadDigest, intent.payloadDigest);
      expect(intent.digestMatches, isTrue);
      expect(intent.payloadDigest, hasLength(66));
      final other = _preparedJson();
      ((other['intent']! as Map<String, Object?>)['calldata']!
              as Map<String, Object?>)['data'] =
          '0xabcd';
      expect(
        LoopV2MiningRewardsCodec.prepared(other).payloadMatchesReview,
        isFalse,
      );
    });

    test('prepare: payloadDigest is required and must be the device\'s', () {
      Map<String, Object?> intentOf(Map<String, Object?> json) =>
          json['intent']! as Map<String, Object?>;
      // Missing: the 0141 shape is now an invalid payload.
      final missing = _preparedJson();
      intentOf(missing).remove('payloadDigest');
      expect(
        () => LoopV2MiningRewardsCodec.prepared(missing),
        throwsA(isA<LoopBackendFailure>()),
      );
      // Well-formed but naming another object: refused, nothing to sign.
      final other = _preparedJson();
      intentOf(other)['payloadDigest'] = '0x${'a' * 64}';
      expect(
        () => LoopV2MiningRewardsCodec.prepared(other),
        throwsA(isA<LoopBackendFailure>()),
      );
      // The transaction changed after the server hashed it.
      final drifted = _preparedJson();
      (intentOf(drifted)['unsignedTransaction']!
              as Map<String, Object?>)['gas'] =
          '0x5209';
      expect(
        () => LoopV2MiningRewardsCodec.prepared(drifted),
        throwsA(isA<LoopBackendFailure>()),
      );
      // Malformed: no prefix, upper case, wrong length, not a string.
      final right = intentOf(_preparedJson())['payloadDigest']! as String;
      for (final bad in <Object?>[
        right.substring(2),
        '0x${right.substring(2).toUpperCase()}',
        '${right}0',
        null,
        42,
      ]) {
        final json = _preparedJson();
        intentOf(json)['payloadDigest'] = bad;
        expect(
          () => LoopV2MiningRewardsCodec.prepared(json),
          throwsA(isA<LoopBackendFailure>()),
          reason: '$bad',
        );
      }
      // A fifth intent key is still refused.
      final extra = _preparedJson();
      intentOf(extra)['reviewSha256'] = 'a' * 64;
      expect(
        () => LoopV2MiningRewardsCodec.prepared(extra),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('canonical digest: sorted keys, numeric chainId, nulls kept', () {
      // The fixture's digest was produced by viem keccak256 on the server's
      // canonical form; both the codec and the independent builder agree.
      final body = _fixture('prepare_201')['body']! as Map<String, Object?>;
      final intent = body['intent']! as Map<String, Object?>;
      final transaction =
          intent['unsignedTransaction']! as Map<String, Object?>;
      const viem =
          '0x398f74e0ce056d7112714d1e5b9116e14d72269f3edb25647c036ab10dbc8f44';
      expect(intent['payloadDigest'], viem);
      expect(_contractDigest(transaction), viem);
      expect('0x${LoopV2MiningRewardsCodec.localDigest(transaction)}', viem);
      // Key order on the wire does not matter; the chainId's JSON type does.
      final reversed = <String, Object?>{
        for (final key in transaction.keys.toList().reversed)
          key: transaction[key],
      };
      expect('0x${LoopV2MiningRewardsCodec.localDigest(reversed)}', viem);
      expect(
        '0x${LoopV2MiningRewardsCodec.localDigest(<String, Object?>{...transaction, 'chainId': '97'})}',
        isNot(viem),
      );
      expect(
        '0x${LoopV2MiningRewardsCodec.localDigest(<String, Object?>{...transaction}..remove('maxFeePerGas'))}',
        isNot(viem),
      );
    });

    test('signer refuses a claim whose two digests differ', () async {
      final good = LoopV2MiningRewardsCodec.prepared(_preparedJson());
      final forged = MiningClaimIntent(
        claimId: good.claimId,
        walletId: good.walletId,
        chainId: good.chainId,
        contractAddress: good.contractAddress,
        amount: good.amount,
        cumulativeAmount: good.cumulativeAmount,
        deadline: good.deadline,
        createdAt: good.createdAt,
        transaction: good.transaction,
        payloadDigest: '0x${'a' * 64}',
        localPayloadDigest: good.localPayloadDigest,
        signingAllowed: true,
        payloadMatchesReview: true,
      );
      expect(forged.digestMatches, isFalse);
      expect(
        MiningClaimSigner.refusalBeforeWallet(
          forged,
          fromAddress: _walletAddress,
          now: _now,
        ),
        'REVIEW_PAYLOAD_MISMATCH',
      );
      final wallet = _RecordingWallet();
      final gateway = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
      );
      final outcome = await MiningClaimSigner(
        wallet: wallet,
        gateway: gateway,
      ).sign(forged, fromAddress: _walletAddress, now: _now);
      expect(outcome.status, MoneySignStatus.refused);
      expect(outcome.reasonCode, 'REVIEW_PAYLOAD_MISMATCH');
      expect(wallet.handed, isEmpty);
      expect(gateway.reportCalls, isEmpty);
      expect(
        MiningClaimSigner.refusalBeforeWallet(
          good,
          fromAddress: _walletAddress,
          now: _now,
        ),
        isNull,
      );
    });

    test('prepare: all eleven transaction keys, fee by type', () {
      Map<String, Object?> tx(Map<String, Object?> json) =>
          (json['intent']! as Map<String, Object?>)['unsignedTransaction']!
              as Map<String, Object?>;
      final missing = _preparedJson();
      tx(missing).remove('gasPrice');
      expect(
        () => LoopV2MiningRewardsCodec.prepared(missing),
        throwsA(isA<LoopBackendFailure>()),
      );
      final extra = _preparedJson();
      tx(extra)['accessList'] = <Object?>[];
      expect(
        () => LoopV2MiningRewardsCodec.prepared(extra),
        throwsA(isA<LoopBackendFailure>()),
      );
      final mixed = _preparedJson();
      tx(mixed)['gasPrice'] = '0x1';
      expect(
        () => LoopV2MiningRewardsCodec.prepared(mixed),
        throwsA(isA<LoopBackendFailure>()),
      );
      final noEnvelope = _preparedJson()..remove('decimals');
      expect(
        () => LoopV2MiningRewardsCodec.prepared(noEnvelope),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('gas refusals: INSUFFICIENT_BALANCE + detailsSafe.reasonCode', () {
      final swap = LoopV2MiningRewardsCodec.gasRefusal(
        _fixture('prepare_409_gas_insufficient')['body'],
      );
      expect(swap!.reason, 'CLAIM_GAS_INSUFFICIENT');
      expect(swap.swap!.fromSymbol, 'USDT');
      expect(swap.swap!.toAssetId, 'eip155:97:native');
      expect(swap.swap!.amount, '0.0018');
      expect(swap.requiredNative, '0.0012');
      final none = LoopV2MiningRewardsCodec.gasRefusal(
        _fixture('prepare_409_no_gas_source')['body'],
      );
      expect(none!.reason, 'CLAIM_NO_GAS_SOURCE');
      expect(none.swap, isNull);
      expect(none.requiredNative, '0.0012');
      // Another INSUFFICIENT_BALANCE reason is an ordinary refusal.
      expect(
        LoopV2MiningRewardsCodec.gasRefusal(
          _fixture('prepare_409_below_minimum')['body'],
        ),
        isNull,
      );
      // The retired drafts: the reason as the envelope code, or nested.
      expect(
        LoopV2MiningRewardsCodec.gasRefusal(<String, Object?>{
          'code': 'CLAIM_GAS_INSUFFICIENT',
          'detailsSafe': <String, Object?>{
            'reasonCode': 'CLAIM_GAS_INSUFFICIENT',
          },
        }),
        isNull,
      );
      final nested = LoopV2MiningRewardsCodec.gasRefusal(<String, Object?>{
        'code': 'INSUFFICIENT_BALANCE',
        'detailsSafe': <String, Object?>{
          'reasonCode': 'CLAIM_GAS_INSUFFICIENT',
          'suggestedSwap': <String, Object?>{'toAssetId': 'eip155:97:native'},
        },
      });
      expect(nested!.swap!.toAssetId, isNull);
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

  group('preflight samples (test/fixtures/s138-mining-rewards)', () {
    test('every sample says where it came from', () {
      final directory = Directory('test/fixtures/s138-mining-rewards');
      final names = directory
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .toList();
      expect(names, hasLength(12));
      for (final name in names) {
        final record = _fixture(name.replaceAll('.json', ''));
        expect(
          record.containsKey('_captured') || record.containsKey('_handwritten'),
          isTrue,
          reason: name,
        );
      }
    });

    test('Development capture: awaiting the first settlement', () async {
      final view = await _replay('rewards_awaiting_captured')
          .getRewards(accessToken: 't', clientVersion: '1.0.0');
      expect(view.display.state, MiningDisplayState.awaitingFirstSettlement);
      expect(view.display.reasonCode, 'MINING_PARAMETERS_PENDING');
      expect(view.claimable, BigInt.zero);
      expect(view.minimumClaim, isNull);
      final page = await _replay('claims_empty_captured')
          .getClaims(accessToken: 't', clientVersion: '1.0.0');
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('displaying, with an excluded graduated asset', () async {
      final view = await _replay('rewards_displaying')
          .getRewards(accessToken: 't', clientVersion: '1.0.0');
      expect(view.display.state, MiningDisplayState.displaying);
      expect(view.nft!.realCount, BigInt.from(5));
      expect(
        view.asset!.excluded.single.reasonCode,
        'MINING_ASSET_GRADUATED_UNREADABLE',
      );
      expect(view.claim.status, MiningClaimStatus.succeeded);
      expect(view.claim.lastTx!.explorerUrl, startsWith('https://testnet.'));
      expect(
        miningMinuteProgress(
          view,
          serverNow: DateTime.utc(2026, 10, 10, 11, 20),
        ).shown,
        BigInt.parse(_loop(20)),
      );
    });

    test('unavailable: totals and tracks withheld', () async {
      final view = await _replay('rewards_unavailable')
          .getRewards(accessToken: 't', clientVersion: '1.0.0');
      expect(view.display.state, MiningDisplayState.unavailable);
      expect(view.nft, isNull);
      expect(view.claim.executable, isFalse);
      expect(view.claim.reasonCode, 'MINING_SETTLEMENT_UNAVAILABLE');
    });

    test('0123: approved rules, nothing settled yet', () async {
      final view = await _replay('rewards_nothing_settled')
          .getRewards(accessToken: 't', clientVersion: '1.0.0');
      expect(view.display.state, MiningDisplayState.awaitingFirstSettlement);
      expect(view.display.reasonCode, isNull);
      expect(view.claim.executable, isFalse);
      expect(view.claim.reasonCode, 'MINING_NOTHING_SETTLED');
      expect(view.claimable, BigInt.zero);
      expect(view.minimumClaim, BigInt.parse(_loop(1)));
      expect(miningAwaitingReason(view), 'MINING_NOTHING_SETTLED');
    });

    test('0123: a claim in flight closes the gate', () async {
      final view = await _replay('rewards_in_flight')
          .getRewards(accessToken: 't', clientVersion: '1.0.0');
      expect(view.claim.executable, isFalse);
      expect(view.claim.reasonCode, 'MINING_CLAIM_IN_FLIGHT');
      expect(view.claim.status, MiningClaimStatus.confirming);
      expect(view.claimable, BigInt.parse(_loop(120)));
    });

    test('claims page, prepare and report', () async {
      final page = await _replay('claims_page')
          .getClaims(accessToken: 't', clientVersion: '1.0.0');
      expect(page.items.map((item) => item.status), <MiningClaimStatus>[
        MiningClaimStatus.failed,
        MiningClaimStatus.succeeded,
      ]);
      expect(page.items.first.failureReasonCode, 'MINING_CLAIM_REVERTED');
      expect(page.nextCursor, isNotNull);
      final prepared = await _replay('prepare_201').postPrepare(
        accessToken: 't',
        clientVersion: '1.0.0',
        idempotencyKey: '0f8fad5b-d9cb-469f-a165-70867728950e',
        walletId: _fixtureWalletId,
      );
      final intent = (prepared as MiningClaimPrepared).intent;
      expect(intent.payloadMatchesReview, isTrue);
      expect(
        intent.payloadDigest,
        '0x398f74e0ce056d7112714d1e5b9116e14d72269f3edb25647c036ab10dbc8f44',
      );
      expect(intent.digestMatches, isTrue);
      expect(intent.transaction.wire['type'], 'legacy');
      expect(intent.chainId, loopLaunchTestnetChainId);
      final reported = await _replay('report_200_submitting').postReport(
        accessToken: 't',
        clientVersion: '1.0.0',
        idempotencyKey: '0f8fad5b-d9cb-469f-a165-70867728950f',
        claimId: intent.claimId,
        txHash: '0x${'ef' * 32}',
      );
      expect(reported.status, MiningClaimStatus.submitting);
    });

    test('prepare 409: two gas refusals, one ordinary refusal', () async {
      final swap = await _replay('prepare_409_gas_insufficient').postPrepare(
        accessToken: 't',
        clientVersion: '1.0.0',
        idempotencyKey: '0f8fad5b-d9cb-469f-a165-70867728950e',
        walletId: _fixtureWalletId,
      );
      expect(swap, isA<MiningClaimGasInsufficient>());
      expect((swap as MiningClaimGasInsufficient).swap!.toSymbol, 'BNB');
      final none = await _replay('prepare_409_no_gas_source').postPrepare(
        accessToken: 't',
        clientVersion: '1.0.0',
        idempotencyKey: '0f8fad5b-d9cb-469f-a165-70867728950e',
        walletId: _fixtureWalletId,
      );
      expect(none, isA<MiningClaimNoGasSource>());
      await expectLater(
        _replay('prepare_409_below_minimum').postPrepare(
          accessToken: 't',
          clientVersion: '1.0.0',
          idempotencyKey: '0f8fad5b-d9cb-469f-a165-70867728950e',
          walletId: _fixtureWalletId,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.code,
            'code',
            'INSUFFICIENT_BALANCE',
          ),
        ),
      );
    });
  });

  group('signing kind (decision 0141)', () {
    test('a claim is a miningClaim, admitted on the published slot only', () {
      final intent = LoopV2MiningRewardsCodec.prepared(_preparedJson());
      final signing = MiningClaimSigner.signingIntent(
        intent,
        fromAddress: _walletAddress,
      );
      expect(signing.kind, IntentKind.miningClaim);
      expect(signing.chainIsPermitted, isTrue);
      expect(launchSlotIntentKinds, contains(IntentKind.miningClaim));
      final transaction = intent.transaction.wire;
      expect(
        privyChainRefusal(
          kind: IntentKind.miningClaim,
          chainId: loopLaunchTestnetChainId,
          launchChainId: loopLaunchTestnetChainId,
          transaction: transaction,
        ),
        isNull,
      );
      expect(
        privyChainRefusal(
          kind: IntentKind.miningClaim,
          chainId: loopLaunchTestnetChainId,
          launchChainId: null,
          transaction: transaction,
        ),
        'privy_chain_switch_unsupported',
      );
    });
  });

  group('page', () {
    loopWatchGround();

    testWidgets('six modules render from the answer', (tester) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(_view(_hourlyJson(excluded: true))),
        ],
      );
      await _pump(tester, rewards: rewards);
      expect(_key('mining-minute-displaying'), findsOneWidget);
      expect(_key('mining-minute-figure-20.0000'), findsOneWidget);
      expect(find.text('上一小时 60.0000 LOOP'), findsOneWidget);
      expect(_key('mining-summary-settled'), findsOneWidget);
      expect(find.text('200.0000'), findsOneWidget);
      expect(find.text('80.0000'), findsOneWidget);
      expect(_key('mining-claim-amount'), findsOneWidget);
      expect(find.text('120.0000 LOOP'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('mining-claim-minimum'),
          matching: find.text('1.0000 LOOP'),
        ),
        findsOneWidget,
      );
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
      await _scrollTo(tester, _key('mining-asset-excluded-$_graduated'));
      expect(_key('mining-asset-$_asset'), findsOneWidget);
      expect(find.text('已退出（已毕业，外盘持有数量暂读不到）'), findsOneWidget);
      // Decision 0123: the asset track is weighted by quantity, never value.
      expect(find.text('按持有数量加权：算力 = 该小时平均持有数量 × 挖矿权重'), findsOneWidget);
      // Decision 0183: the NFT track and the conditions, one line each.
      expect(find.text('NFT 算力 = 持有数量 × 所属社区系数'), findsOneWidget);
      expect(find.text('只算内置钱包，社区币须加入已通过审核的绑定社区。'), findsOneWidget);
      expect(find.textContaining('估值'), findsNothing);
      expect(find.textContaining('价格'), findsNothing);
      await _scrollTo(tester, _key('mining-invite-total'));
      expect(_key('mining-invite-level-5'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('1%'), findsOneWidget);
      await _scrollTo(tester, _key('mining-claims-empty'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await _drain(tester);
    });

    testWidgets('0167 the page speaks the ledger folio family', (tester) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(_view(_hourlyJson(excluded: true))),
        ],
      );
      await _pump(tester, rewards: rewards);
      // H2: a full Lime record folio welded into a ledger composite; the
      // minute progress lives in the strip beneath it.
      final hero = find.byType(MiningMinuteHero);
      expect(
        find.descendant(of: hero, matching: find.byType(LoopLedgerComposite)),
        findsOneWidget,
      );
      final folio = _heroFolio(tester);
      // S241b (decision 0210): the flat dark card, not a full-Yellow block.
      expect(folio.variant, LoopFolioVariant.quiet);
      expect(folio.archetype, LoopFolioArchetype.record);
      expect(folio.kicker, '上一小时奖励');
      expect(folio.heading, '20.0000 LOOP');
      expect(folio.caption, matches(RegExp(r'^20/60 · 下次 \d\d:\d\d$')));
      expect(folio.stamp, isNull);
      expect(
        find.descendant(
          of: find.byType(LoopLedgerComposite),
          matching: _key('mining-minute-bar'),
        ),
        findsOneWidget,
      );
      // No full-Yellow block on the screen (S241b, decision 0210): the folio
      // is the flat dark card. The claim is not a Yellow button.
      expect(
        tester
            .widgetList<LoopFolioPrimary>(find.byType(LoopFolioPrimary))
            .where((f) => f.variant == LoopFolioVariant.lime),
        isEmpty,
      );
      expect(
        tester.widget<LoopButton>(_key('mining-claim-button')).primary,
        isFalse,
      );
      // M4: the summary is a stat grid; 可领取 > 0 takes the up tone.
      final grid = tester.widget<MemeStatFigures>(find.byType(MemeStatFigures));
      expect(grid.stats.map((s) => s.value), <String>[
        '200.0000',
        '80.0000',
        '120.0000',
      ]);
      expect(grid.stats.last.tone, LoopStatTone.up);
      // M5: the claim panel is a record card with a badge and key/values.
      final panel = _key('mining-claim-panel');
      expect(tester.widget(panel), isA<LoopRecordCard>());
      expect(
        find.descendant(of: panel, matching: find.byType(LoopBadge)),
        findsOneWidget,
      );
      expect(tester.widget(_key('mining-claim-amount')), isA<LoopKeyValue>());
      expect(tester.widget(_key('mining-claim-minimum')), isA<LoopKeyValue>());
      // M6: the tracks and the invite table are record cards of key/values.
      for (final key in <String>[
        'mining-nft-track',
        'mining-asset-track',
        'mining-invite-table',
      ]) {
        await _scrollTo(tester, _key(key));
        expect(
          find.descendant(of: _key(key), matching: find.byType(LoopRecordCard)),
          findsOneWidget,
          reason: key,
        );
      }
      expect(tester.widget(_key('mining-nft-reward')), isA<LoopKeyValue>());
      expect(
        tester.widget(_key('mining-asset-excluded-$_graduated')),
        isA<LoopKeyValue>(),
      );
      // Rise / fall belong to price moves only (0117).
      final painted = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style?.color)
          .whereType<Color>();
      expect(painted, isNot(contains(LoopColors.rise)));
      expect(painted, isNot(contains(LoopColors.fall)));
      await _drain(tester);
    });

    testWidgets('0167 awaiting and unavailable are quiet, neutral folios', (
      tester,
    ) async {
      await _pump(
        tester,
        rewards: _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[
            _Answer.value(
              LoopV2MiningRewardsCodec.rewards(
                _fixture('rewards_nothing_settled')['body'],
              ),
            ),
          ],
        ),
      );
      var folio = _heroFolio(tester);
      expect(folio.variant, LoopFolioVariant.quiet);
      expect(folio.headingTone, LoopFolioHeadingTone.neutral);
      expect(folio.kicker, '上一小时算力');
      expect(folio.heading, '你有算力的小时还没有结算');
      await _drain(tester);

      await _pump(
        tester,
        rewards: _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[
            _Answer.value(
              LoopV2MiningRewardsCodec.rewards(
                _fixture('rewards_unavailable')['body'],
              ),
            ),
          ],
        ),
      );
      folio = _heroFolio(tester);
      expect(folio.variant, LoopFolioVariant.quiet);
      expect(folio.headingTone, LoopFolioHeadingTone.neutral);
      expect(folio.heading, '暂时读不到结算结果');
      await _drain(tester);
    });

    testWidgets('below the minimum and a closed claim say why', (tester) async {
      final below = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            _view(
              _hourlyJson()..update(
                'hourly',
                (hourly) => <String, Object?>{
                  ...hourly! as Map<String, Object?>,
                  'totals': <String, Object?>{
                    'settledRaw': '500000000000000000',
                    'claimedRaw': '0',
                    'claimableRaw': '500000000000000000',
                  },
                },
              ),
            ),
          ),
        ],
      );
      await _pump(tester, rewards: below);
      expect(find.text('满 1.0000 LOOP 可领取'), findsOneWidget);
      expect(
        tester.widget<LoopButton>(_key('mining-claim-button')).onPressed,
        isNull,
      );
      await _drain(tester);

      final closed = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(_view(_hourlyJson(executable: false))),
        ],
      );
      await _pump(tester, rewards: closed);
      expect(find.text('链上写入暂时关闭，暂不能领取'), findsOneWidget);
      // The balance is still shown.
      expect(find.text('120.0000 LOOP'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('0123 claim gate: each reason in the contract order', (
      tester,
    ) async {
      const expected = <String, String>{
        'MINING_SETTLEMENT_UNAVAILABLE': '结算服务暂时不可用，暂不能领取',
        'MINING_PARAMETERS_PENDING': '挖矿规则待生效，暂不能领取',
        'MINING_NOTHING_SETTLED': '有算力的小时结算后可领取',
        'MINING_CLAIM_NOTHING_TO_CLAIM': '暂无可领取',
        'MINING_CLAIM_BELOW_MINIMUM': '满 1.0000 LOOP 可领取',
        'MINING_CLAIM_IN_FLIGHT': '上一笔领取还在处理中，完成后再领取',
        'MINING_CLAIM_MAINNET_CLOSED': '主网领取尚未开放',
        // MINING_CLAIM_CONTRACT_NOT_CONFIGURED is the power-only page (0184).
        'MINING_CLAIM_CHAIN_NOT_CONFIGURED': '领取所在的链尚未配置，暂不能领取',
        'MINING_CLAIM_SIGNER_NOT_CONFIGURED': '领取凭证签发尚未配置，暂不能领取',
      };
      for (final MapEntry(key: reason, value: text) in expected.entries) {
        expect(
          miningClaimUnavailableText(reason, minimum: BigInt.from(10).pow(18)),
          text,
          reason: reason,
        );
        // Decision 0184: a gate that stops before the contract check does not
        // say the token is live, so the page draws no claim block for it.
        if (miningTokenStage(
              MiningClaimSummary(
                status: MiningClaimStatus.none,
                executable: false,
                reasonCode: reason,
              ),
            ) !=
            MiningTokenStage.live) {
          continue;
        }
        final rewards = _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[
            _Answer.value(
              _view(_hourlyJson(executable: false, claimReason: reason)),
            ),
          ],
        );
        await _pump(tester, rewards: rewards);
        expect(
          tester.widget<Text>(_key('mining-claim-disabled')).data,
          text,
          reason: reason,
        );
        expect(
          tester.widget<LoopButton>(_key('mining-claim-button')).onPressed,
          isNull,
          reason: reason,
        );
        // The balance is still shown.
        expect(find.text('120.0000 LOOP'), findsOneWidget, reason: reason);
        await _drain(tester);
      }
      // Without a minimum the below-minimum line still says why.
      expect(
        miningClaimUnavailableText('MINING_CLAIM_BELOW_MINIMUM'),
        '可领取数量未达到最低领取数量',
      );
      expect(miningClaimUnavailableText('SOMETHING_NEW'), '领取暂不可用');
    });

    testWidgets('0123 nothing settled: hero and claim both say so', (
      tester,
    ) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            LoopV2MiningRewardsCodec.rewards(
              _fixture('rewards_nothing_settled')['body'],
            ),
          ),
        ],
      );
      await _pump(tester, rewards: rewards);
      expect(_key('mining-minute-awaiting'), findsOneWidget);
      // Decision 0184: this answer does not say the token is live, so the
      // page counts power only and the claim block is one notice.
      expect(_heroFolio(tester).caption, '挖矿规则已生效。每个整点统计上一小时的算力，统计后显示在这里。');
      expect(_key('mining-power-only-notice'), findsOneWidget);
      expect(_key('mining-claim-button'), findsNothing);
      expect(_key('mining-rewards-unavailable'), findsNothing);
      // The live wording is unchanged.
      expect(
        miningDisplayReasonText('MINING_NOTHING_SETTLED'),
        '挖矿规则已生效。每个整点结算上一小时，结算后这里按分钟展示，并可领取。',
      );
      expect(
        miningClaimUnavailableText('MINING_NOTHING_SETTLED'),
        '有算力的小时结算后可领取',
      );
      await _drain(tester);

      // No approved rules: the captured Development answer.
      final pending = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            LoopV2MiningRewardsCodec.rewards(
              _fixture('rewards_awaiting_captured')['body'],
            ),
          ),
        ],
      );
      await _pump(tester, rewards: pending);
      expect(_heroFolio(tester).caption, '挖矿规则待生效，暂时没有结算。');
      await _drain(tester);

      // The store is down: the inline notice names that cause.
      final down = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            LoopV2MiningRewardsCodec.rewards(
              _fixture('rewards_unavailable')['body'],
            ),
          ),
        ],
      );
      await _pump(tester, rewards: down);
      expect(_key('mining-rewards-unavailable'), findsOneWidget);
      expect(find.textContaining('结算服务暂时不可用，下面的数字可能不是最新的。'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('0123 in flight: progress shown, no new claim', (tester) async {
      // Decision 0184: the captured claim is on the testnet, which does not
      // say the token is live; the same claim on mainnet does.
      final body =
          _fixture('rewards_in_flight')['body']! as Map<String, Object?>;
      final latest =
          ((body['hourly']! as Map<String, Object?>)['claim']!
                  as Map<String, Object?>)['latest']!
              as Map<String, Object?>;
      latest['chainId'] = 'eip155:56';
      latest['chainReference'] = 56;
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(LoopV2MiningRewardsCodec.rewards(body)),
        ],
        // The chain has not answered yet: the claim stays where it is.
        reportAnswers: const <_Answer<MiningClaimRecord>>[_Answer.pending()],
      );
      await _pump(tester, rewards: rewards, settle: false);
      for (var i = 0; i < 3; i += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(_key('mining-claim-status-confirming'), findsOneWidget);
      expect(
        tester.widget<LoopButton>(_key('mining-claim-button')).onPressed,
        isNull,
      );
      expect(find.text('已上链，正在等待确认。不要重复领取。'), findsOneWidget);
      // The same claim is followed; nothing new is prepared.
      expect(rewards.prepareCalls, isEmpty);
      expect(
        rewards.reportCalls.first.$2,
        '0xcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      );
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
      // 「结算中」 is the folio's stamp, inside the settling composite.
      expect(_key('mining-minute-settling'), findsOneWidget);
      expect(_heroFolio(tester).stamp, '结算中');
      expect(_heroFolio(tester).caption, '下一小时结算后更新');
      expect(
        find.descendant(
          of: _key('mining-minute-settling'),
          matching: find.text('结算中'),
        ),
        findsOneWidget,
      );
      expect(_key('mining-minute-figure-60.0000'), findsOneWidget);
      // It asks again at once instead of waiting a whole interval.
      expect(settling.rewardReads, greaterThanOrEqualTo(2));
      await _drain(tester);
    });

    testWidgets('settlement unavailable carries the server reason', (
      tester,
    ) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            LoopV2MiningRewardsCodec.rewards(
              _fixture('rewards_unavailable')['body'],
            ),
          ),
        ],
      );
      await _pump(tester, rewards: rewards);
      expect(_key('mining-minute-unavailable'), findsOneWidget);
      expect(_key('mining-rewards-unavailable'), findsOneWidget);
      expect(find.text('结算服务暂时不可用，下面的数字可能不是最新的。'), findsOneWidget);
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
        // Decision 0167: the status is a `.badge`, never a rise / fall pill.
        expect(tester.widget<LoopBadge>(_key(key)).kind, switch (status) {
          'succeeded' => LoopBadgeKind.up,
          'failed' => LoopBadgeKind.down,
          _ => LoopBadgeKind.mining,
        }, reason: status);
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

    testWidgets('a claim in flight elsewhere is followed by re-reporting it', (
      tester,
    ) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(
            _view(_hourlyJson(latestClaim: _claimJson(status: 'confirming'))),
          ),
        ],
        reportAnswers: <_Answer<MiningClaimRecord>>[
          _Answer.value(
            LoopV2MiningRewardsCodec.claimRecord(
              _claimJson(status: 'succeeded'),
            ),
          ),
        ],
      );
      await _pump(tester, rewards: rewards, settle: false);
      for (var i = 0; i < 5; i += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      // The same hash, reported again (contract §5.3), never a new prepare.
      expect(rewards.reportCalls.first, (_claimId, _hash));
      expect(rewards.prepareCalls, isEmpty);
      expect(_key('mining-claim-status-succeeded'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('claim: prepare, confirm wallet and amount, report, succeed', (
      tester,
    ) async {
      final prepared = LoopV2MiningRewardsCodec.prepared(_preparedJson());
      final wallet = _RecordingWallet();
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(_view()),
          _Answer.value(
            _view(_hourlyJson(latestClaim: _claimJson(amount: '120'))),
          ),
        ],
        prepareAnswer: _Answer.value(MiningClaimPrepared(prepared)),
        reportAnswers: <_Answer<MiningClaimRecord>>[
          _Answer.value(
            LoopV2MiningRewardsCodec.claimRecord(
              _claimJson(status: 'submitting', amount: '120'),
            ),
          ),
          _Answer.value(
            LoopV2MiningRewardsCodec.claimRecord(
              _claimJson(status: 'confirming', amount: '120'),
            ),
          ),
          _Answer.value(
            LoopV2MiningRewardsCodec.claimRecord(
              _claimJson(status: 'succeeded', amount: '120'),
            ),
          ),
        ],
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
      expect(wallet.handed.single.kind, IntentKind.miningClaim);
      expect(rewards.reportCalls.single, (_claimId, _hash));
      await tester.tap(
        find.text('关闭').hitTestable().first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      // The page closed the sheet with the outcome; the same hash was
      // reported again until the claim settled.
      for (var i = 0; i < 5; i += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(rewards.reportCalls, hasLength(3));
      expect(rewards.reportCalls.toSet(), <(String, String)>{
        (_claimId, _hash),
      });
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
        reportAnswers: const <_Answer<MiningClaimRecord>>[
          _Answer.fail(LoopChainFailureKind.offline),
        ],
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
      // Locked: the page does not report on its own; only the owner's
      // 「重新上报」 does.
      expect(rewards.reportCalls, hasLength(1));
      await _drain(tester);
    });
  });

  // Decision 0147: loop-api S148 (Decision 0125) §8, samples under
  // test/fixtures/s149-s148-api/.
  group('S148 values (0125 §8)', () {
    Map<String, Object?> s148(String name) => jsonDecode(
      File('test/fixtures/s149-s148-api/$name.json').readAsStringSync(),
    ) as Map<String, Object?>;

    MiningRewardsView parse(String name) =>
        LoopV2MiningRewardsCodec.rewards(s148(name)['body']);

    test('§8.1 awaiting the first own hour parses with null blocks', () {
      final view = parse('rewards_awaiting_first_own_hour');
      expect(view.display.state, MiningDisplayState.awaitingFirstSettlement);
      expect(view.display.reasonCode, isNull);
      expect(view.display.window, isNull);
      expect(view.lastEpoch, isNull);
      expect(view.nft, isNull);
      expect(view.asset, isNull);
      expect(view.settledTotal, BigInt.zero);
      expect(view.claimable, BigInt.zero);
      expect(view.invites, isNotNull);
      expect(view.claim.executable, isFalse);
      expect(view.claim.reasonCode, 'MINING_NOTHING_SETTLED');
      expect(miningAwaitingReason(view), 'MINING_NOTHING_SETTLED');
    });

    testWidgets('§8.1 the page waits for the first own hour', (tester) async {
      final rewards = _FakeRewards(
        rewards: <_Answer<MiningRewardsView>>[
          _Answer.value(parse('rewards_awaiting_first_own_hour')),
        ],
      );
      await _pump(tester, rewards: rewards);
      expect(tester.takeException(), isNull);
      expect(_key('mining-minute-awaiting'), findsOneWidget);
      expect(find.text('你有算力的小时还没有结算'), findsOneWidget);
      // Decision 0184: the gate stopped before the contract check.
      expect(_heroFolio(tester).caption, '挖矿规则已生效。每个整点统计上一小时的算力，统计后显示在这里。');
      expect(_key('mining-power-only-notice'), findsOneWidget);
      expect(_key('mining-claim-button'), findsNothing);
      expect(_key('mining-rewards-unavailable'), findsNothing);
      await _drain(tester);
    });

    testWidgets('§8.2 a paused or unreadable contract closes the claim', (
      tester,
    ) async {
      for (final (name, code, line) in <(String, String, String)>[
        (
          'rewards_claim_contract_paused',
          'MINING_CLAIM_CONTRACT_PAUSED',
          '领取合约已暂停，暂不能领取',
        ),
        (
          'rewards_claim_chain_read_failed',
          'MINING_CLAIM_CHAIN_READ_FAILED',
          '领取合约暂时读不到，暂不能领取',
        ),
      ]) {
        final view = parse(name);
        expect(view.claim.executable, isFalse, reason: name);
        expect(view.claim.reasonCode, code, reason: name);
        expect(miningClaimUnavailableText(code), line);
        final rewards = _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[_Answer.value(view)],
        );
        await _pump(tester, rewards: rewards);
        expect(
          tester.widget<Text>(_key('mining-claim-disabled')).data,
          line,
          reason: name,
        );
        expect(
          tester.widget<LoopButton>(_key('mining-claim-button')).onPressed,
          isNull,
          reason: name,
        );
        await _drain(tester);
      }
    });

    test('§8.2 prepare refusals keep their own copy', () {
      expect(
        miningClaimPrepareFailureText(
          const LoopChainException(
            LoopChainFailureKind.unavailable,
            reasonCode: 'MINING_CLAIM_CHAIN_READ_FAILED',
          ),
        ),
        '领取合约暂时读不到，没有生成领取凭证，余额不变。',
      );
      expect(
        miningClaimPrepareFailureText(
          const LoopChainException(
            LoopChainFailureKind.validationFailed,
            reasonCode: 'MINING_CLAIM_CONTRACT_PAUSED',
          ),
        ),
        '领取合约已暂停，余额不变。',
      );
    });
  });

  group('S191 · power only before the LOOP token (decision 0184)', () {
    const reason = miningClaimContractNotConfiguredCode;

    _FakeRewards closedWith(String code) => _FakeRewards(
      rewards: <_Answer<MiningRewardsView>>[
        _Answer.value(_view(_hourlyJson(executable: false, claimReason: code))),
      ],
    );

    /// Every painted string on screen that states a LOOP quantity: a figure
    /// followed by LOOP (「60.0000 LOOP」, 「领取 40 LOOP」).
    final loopAmount = RegExp(r'\d[\d,]*(\.\d+)?\s*LOOP');
    List<String> loopAmounts(WidgetTester tester) => <String>[
      for (final text in tester.widgetList<RichText>(find.byType(RichText)))
        if (loopAmount.hasMatch(text.text.toPlainText()))
          text.text.toPlainText(),
    ];

    testWidgets('the rewards page draws power and one notice, no LOOP amount '
        'and no claim block', (tester) async {
      await _pump(tester, rewards: closedWith(reason));

      expect(loopAmounts(tester), isEmpty);
      // The hero is the hour's power.
      final folio = _heroFolio(tester);
      expect(folio.kicker, '上一小时算力');
      expect(folio.heading, '1,236.25 算力');
      expect(folio.caption, '上一小时有效，已计入算力统计');
      expect(_key('mining-minute-bar'), findsNothing);
      expect(
        tester
            .widget<LoopCompositeDetailNote>(_key('mining-power-tracks'))
            .text,
        'NFT 算力 0.75 · Meme 币算力 1,235.5',
      );
      // 奖励汇总 is 算力汇总.
      expect(find.text('算力汇总'), findsOneWidget);
      expect(find.text('奖励汇总'), findsNothing);
      expect(_key('mining-power-summary-total'), findsOneWidget);
      expect(_key('mining-summary-settled'), findsNothing);
      expect(_key('mining-summary-claimable'), findsNothing);
      // The claim block, whole, is one notice.
      final notice = tester.widget<LoopNotice>(
        _key('mining-power-only-notice'),
      );
      expect(notice.body, 'LOOP 代币上线后开始正式开挖，上线前只统计算力');
      expect(_key('mining-claim-panel'), findsNothing);
      expect(_key('mining-claim-button'), findsNothing);
      expect(find.text('Coming soon'), findsNothing);
      expect(find.textContaining('尚未配置'), findsNothing);
      expect(find.textContaining(reason), findsNothing);

      await _scrollTo(tester, _key('mining-rewards-provenance'));
      expect(loopAmounts(tester), isEmpty);
      expect(_key('mining-nft-track'), findsOneWidget);
      expect(_key('mining-nft-reward'), findsNothing);
      expect(_key('mining-asset-reward'), findsNothing);
      expect(_key('mining-invite-table'), findsOneWidget);
      expect(find.text('领取记录'), findsNothing);
      expect(find.textContaining('已记在账上'), findsNothing);
      await _drain(tester);
    });

    testWidgets('an answer that does not say keeps the page on power only', (
      tester,
    ) async {
      // The claim gate stops on a ledger fact before it checks the contract,
      // so these answers do not say whether the token is live.
      for (final code in <String>[
        'MINING_CLAIM_NOTHING_TO_CLAIM',
        'MINING_CLAIM_BELOW_MINIMUM',
        'MINING_NOTHING_SETTLED',
        'MINING_CLAIM_MAINNET_CLOSED',
      ]) {
        await _pump(tester, rewards: closedWith(code));
        expect(loopAmounts(tester), isEmpty, reason: code);
        expect(_key('mining-power-only-notice'), findsOneWidget, reason: code);
        expect(_key('mining-claim-panel'), findsNothing, reason: code);
        await _drain(tester);
      }
    });

    testWidgets('once the contract is configured the page is as before', (
      tester,
    ) async {
      await _pump(
        tester,
        rewards: _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
        ),
      );
      expect(_heroFolio(tester).heading, '20.0000 LOOP');
      expect(find.text('奖励汇总'), findsOneWidget);
      expect(_key('mining-summary-settled'), findsOneWidget);
      expect(_key('mining-power-only-notice'), findsNothing);
      expect(_key('mining-power-summary'), findsNothing);
      final button = tester.widget<LoopButton>(_key('mining-claim-button'));
      expect(button.label, '领取');
      expect(button.onPressed, isNotNull);
      await _scrollTo(tester, find.text('领取记录'));
      expect(_key('mining-nft-reward'), findsOneWidget);
      await _drain(tester);

      // A reason the server checks only past the contract is live too.
      for (final code in <String>[
        'MINING_CLAIM_CHAIN_NOT_CONFIGURED',
        'MINING_CLAIM_SIGNER_NOT_CONFIGURED',
        'MINING_CLAIM_WRITES_DISABLED',
        'MINING_CLAIM_CONTRACT_PAUSED',
      ]) {
        await _pump(tester, rewards: closedWith(code));
        final closed = tester.widget<LoopButton>(_key('mining-claim-button'));
        expect(closed.label, '领取', reason: code);
        expect(closed.onPressed, isNull, reason: code);
        expect(
          tester.widget<Text>(_key('mining-claim-disabled')).data,
          miningClaimUnavailableText(code),
          reason: code,
        );
        expect(find.text('120.0000 LOOP'), findsOneWidget, reason: code);
        expect(_key('mining-power-only-notice'), findsNothing, reason: code);
        await _drain(tester);
      }
    });

    test('the token stage is read from the claim gate alone', () {
      MiningTokenStage stage({
        bool executable = false,
        String? code,
        MiningClaimStatus status = MiningClaimStatus.none,
        String? chainId,
      }) => miningTokenStage(
        MiningClaimSummary(
          status: status,
          executable: executable,
          reasonCode: code,
          lastTx: chainId == null
              ? null
              : MiningClaimTx(txHash: _hash, chainId: chainId),
        ),
      );
      expect(stage(code: reason), MiningTokenStage.preToken);
      expect(
        stage(code: 'MINING_CLAIM_MAINNET_CLOSED'),
        MiningTokenStage.preToken,
      );
      expect(stage(executable: true), MiningTokenStage.live);
      for (final code in <String>[
        'MINING_CLAIM_CHAIN_NOT_CONFIGURED',
        'MINING_CLAIM_SIGNER_NOT_CONFIGURED',
        'MINING_CLAIM_WRITES_DISABLED',
        'MINING_CLAIM_CONTRACT_PAUSED',
        'MINING_CLAIM_CHAIN_READ_FAILED',
        'MINING_CLAIM_FUNDING_INSUFFICIENT',
      ]) {
        expect(stage(code: code), MiningTokenStage.live, reason: code);
      }
      for (final code in <String>[
        'MINING_SETTLEMENT_UNAVAILABLE',
        'MINING_PARAMETERS_PENDING',
        'MINING_NOTHING_SETTLED',
        'MINING_CLAIM_NOTHING_TO_CLAIM',
        'MINING_CLAIM_BELOW_MINIMUM',
        'MINING_CLAIM_IN_FLIGHT',
      ]) {
        expect(stage(code: code), MiningTokenStage.unknown, reason: code);
      }
      // A mainnet claim proves the token contract; a testnet one does not.
      expect(
        stage(
          code: 'MINING_CLAIM_NOTHING_TO_CLAIM',
          status: MiningClaimStatus.succeeded,
          chainId: 'eip155:56',
        ),
        MiningTokenStage.live,
      );
      expect(
        stage(
          code: 'MINING_CLAIM_NOTHING_TO_CLAIM',
          status: MiningClaimStatus.succeeded,
          chainId: 'eip155:97',
        ),
        MiningTokenStage.unknown,
      );
      expect(miningTokenLive(null), isFalse);
      // No copy path names the configuration, or a reward kept on the books.
      expect(miningClaimUnavailableText(reason), miningPowerOnlyNotice);
      expect(
        miningClaimPrepareFailureText(
          const LoopChainException(
            LoopChainFailureKind.unavailable,
            reasonCode: reason,
          ),
        ),
        miningPowerOnlyNotice,
      );
    });

    Future<void> pumpMining(WidgetTester tester, _FakeRewards rewards) =>
        pumpS7Page(
          tester,
          MiningScreen(onOpenRewards: () {}),
          mining: FakeMiningGateway(
            summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
          ),
          size: const Size(390, 4000),
          overrides: <Override>[
            miningRewardsGatewayProvider.overrideWithValue(rewards),
            loopReadClockProvider.overrideWithValue(() => _now),
          ],
        );

    testWidgets('我的挖矿 counts power, place and invites before the token', (
      tester,
    ) async {
      final rewards = closedWith(reason);
      await pumpMining(tester, rewards);
      expect(rewards.rewardReads, 1);
      expect(loopAmounts(tester), isEmpty);
      for (final slug in <String>[
        'estimated-today',
        'accumulated',
        'claimable',
      ]) {
        expect(_key('mining-summary-hero-$slug'), findsNothing, reason: slug);
      }
      expect(find.text('今日预估'), findsNothing);
      expect(find.text('累计已挖'), findsNothing);
      expect(find.text('待领取'), findsNothing);
      expect(
        tester.widget<Text>(_key('mining-summary-hero-last-hour-power')).data,
        '1,236.25',
      );
      expect(
        tester.widget<Text>(_key('mining-summary-hero-active-invites')).data,
        '15 人',
      );
      expect(_key('mining-summary-hero-network-power'), findsOneWidget);
      // The first step opens the hour's power, still a way in.
      final claim = _key('mining-summary-hero-claim');
      expect(
        find.descendant(of: claim, matching: find.text('小时算力')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: claim, matching: find.byType(InkWell)),
            )
            .onTap,
        isNotNull,
      );
      final note = tester.widget<Text>(_key('mining-summary-hero-power-only'));
      expect(note.data, miningPowerOnlyNotice);
      expect(find.text('Coming soon'), findsNothing);
      expect(find.textContaining('Coming soon'), findsNothing);
      await _drain(tester);
    });

    testWidgets('我的挖矿 is as before once the token is live', (tester) async {
      await pumpMining(
        tester,
        _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[_Answer.value(_view())],
        ),
      );
      final claim = _key('mining-summary-hero-claim');
      expect(
        find.descendant(of: claim, matching: find.text('领取奖励')),
        findsOneWidget,
      );
      expect(_key('mining-summary-hero-estimated-today'), findsOneWidget);
      expect(_key('mining-summary-hero-claimable'), findsOneWidget);
      expect(_key('mining-summary-hero-power-only'), findsNothing);
      expect(_key('mining-summary-hero-last-hour-power'), findsNothing);
      await _drain(tester);
    });
  });

  group('S195 · token stage by configurationReasonCode (decision 0185)', () {
    const notConfigured = miningClaimContractNotConfiguredCode;

    MiningRewardsView reported({
      required String? configuration,
      bool executable = false,
      String claimReason = 'MINING_NOTHING_SETTLED',
    }) => _view(
      _hourlyJson(
        executable: executable,
        claimReason: claimReason,
        configurationReported: true,
        configurationReason: configuration,
      ),
    );

    test('the codec reads the key, null, and its absence apart', () {
      final configured = reported(configuration: null).claim;
      expect(configured.configurationReported, isTrue);
      expect(configured.configurationReasonCode, isNull);

      final closed = reported(configuration: notConfigured).claim;
      expect(closed.configurationReported, isTrue);
      expect(closed.configurationReasonCode, notConfigured);

      final legacy = _view(
        _hourlyJson(executable: false, claimReason: 'MINING_NOTHING_SETTLED'),
      ).claim;
      expect(legacy.configurationReported, isFalse);
      expect(legacy.configurationReasonCode, isNull);

      // Lenient: a value that is not a reason code reads as an older backend
      // instead of failing the whole resource.
      for (final odd in <Object?>['lower_case', 7, true]) {
        final json = _hourlyJson(executable: false);
        ((json['hourly']! as Map<String, Object?>)['claim']!
                as Map<String, Object?>)['configurationReasonCode'] =
            odd;
        final claim = _view(json).claim;
        expect(claim.configurationReported, isFalse, reason: '$odd');
        expect(claim.configurationReasonCode, isNull, reason: '$odd');
      }
      // Any other unknown key is still rejected.
      final extra = _hourlyJson();
      ((extra['hourly']! as Map<String, Object?>)['claim']!
              as Map<String, Object?>)['configured'] =
          true;
      expect(() => _view(extra), throwsA(isA<LoopBackendFailure>()));
    });

    test('the new field alone decides, whatever the ledger reason', () {
      const ledger = <String>[
        'MINING_SETTLEMENT_UNAVAILABLE',
        'MINING_PARAMETERS_PENDING',
        'MINING_NOTHING_SETTLED',
        'MINING_CLAIM_NOTHING_TO_CLAIM',
        'MINING_CLAIM_BELOW_MINIMUM',
        'MINING_CLAIM_IN_FLIGHT',
      ];
      for (final code in ledger) {
        expect(
          miningTokenStage(
            reported(configuration: null, claimReason: code).claim,
          ),
          MiningTokenStage.live,
          reason: code,
        );
        for (final configuration in <String>[
          notConfigured,
          'MINING_CLAIM_MAINNET_CLOSED',
        ]) {
          expect(
            miningTokenStage(
              reported(configuration: configuration, claimReason: code).claim,
            ),
            MiningTokenStage.preToken,
            reason: '$code + $configuration',
          );
        }
      }
      for (final configuration in <String>[
        'MINING_CLAIM_CHAIN_NOT_CONFIGURED',
        'MINING_CLAIM_SIGNER_NOT_CONFIGURED',
        'MINING_CLAIM_WRITES_DISABLED',
      ]) {
        expect(
          miningTokenStage(
            reported(
              configuration: configuration,
              claimReason: configuration,
            ).claim,
          ),
          MiningTokenStage.live,
          reason: configuration,
        );
      }
      // The settlement store is checked before the contract: no answer.
      expect(
        miningTokenStage(
          reported(
            configuration: 'MINING_SETTLEMENT_UNAVAILABLE',
            claimReason: 'MINING_SETTLEMENT_UNAVAILABLE',
          ).claim,
        ),
        MiningTokenStage.unknown,
      );
      // A mainnet claim is no longer read when the field is there.
      expect(
        miningTokenStage(
          const MiningClaimSummary(
            status: MiningClaimStatus.succeeded,
            executable: false,
            reasonCode: 'MINING_CLAIM_NOTHING_TO_CLAIM',
            lastTx: MiningClaimTx(txHash: _hash, chainId: 'eip155:56'),
            configurationReported: true,
            configurationReasonCode: notConfigured,
          ),
        ),
        MiningTokenStage.preToken,
      );
    });

    testWidgets('a ledger reason with the contract configured is the full '
        'page; with it absent, power only', (tester) async {
      await _pump(
        tester,
        rewards: _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[
            _Answer.value(
              reported(
                configuration: null,
                claimReason: 'MINING_CLAIM_BELOW_MINIMUM',
              ),
            ),
          ],
        ),
      );
      expect(_key('mining-power-only-notice'), findsNothing);
      expect(_key('mining-summary-settled'), findsOneWidget);
      final closed = tester.widget<LoopButton>(_key('mining-claim-button'));
      expect(closed.label, '领取');
      expect(closed.onPressed, isNull);
      await _drain(tester);

      await _pump(
        tester,
        rewards: _FakeRewards(
          rewards: <_Answer<MiningRewardsView>>[
            _Answer.value(
              reported(
                configuration: notConfigured,
                claimReason: 'MINING_NOTHING_SETTLED',
              ),
            ),
          ],
        ),
      );
      expect(_key('mining-power-only-notice'), findsOneWidget);
      expect(_key('mining-claim-panel'), findsNothing);
      expect(_key('mining-summary-settled'), findsNothing);
      await _drain(tester);
    });
  });
}
