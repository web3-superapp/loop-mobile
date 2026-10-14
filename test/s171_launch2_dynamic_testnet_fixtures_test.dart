// S171 · the BSC testnet's own answers for the first LoopDynamic instance
// (8cf88c44…, loop-api ee58f98, 2026-10-13T21Z, evidence
// `docs/integration/S171/runs/testnet-2026-10-13T2116Z`) run through the
// strict codecs: the contract-alignment check decision 0159 wanted on a
// device, done against the real wire shapes instead. The walkthrough
// shortened trader addresses to `0xabcd…wxyz`; those are expanded with
// zeros to stay valid addresses, nothing else in the fixtures is edited.
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_dynamic_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';

const String _instance = '8cf88c44-adf8-4c3f-9de2-46a895af3d1d';
const String _wallet = '7dd2bf27-5c36-428d-95cb-54298d0fa974';
const String _hook = '0x3257cf5512f52ca1ecf4addb062b341d80a810c4';
const String _router = '0x7d1577a63007620db1cbee3eab3572b9d148aefe';
const String _zero = '0x0000000000000000000000000000000000000000';
const String _intentId = '7dff2656-55d0-44c0-91d4-b8b9e406bb00';
const String _claimTx =
    '0x060a3f321561571591d665674fe831a7de5b6aa9830488754f27e8b0a38d4003';
final Decimal _claimable = Decimal.parse('13.14340921477541523');

Map<String, Object?> _fx(String name) => jsonDecode(
  File('test/fixtures/s171-launch2-dynamic-testnet/$name.json')
      .readAsStringSync(),
) as Map<String, Object?>;

void main() {
  test('graduated detail: contracts.hook stays zero, the bound Hook is in '
      'graduation.hookAddress, the pool router is LoopRouter', () {
    final body = _fx('instance_detail_graduated');
    final contracts =
        (body['instance']! as Map<String, Object?>)['contracts']!
            as Map<String, Object?>;
    expect(contracts['hook'], _zero);
    expect(contracts['priceRecorder'], _zero);
    final detail = LoopV2Launch2Codec.detail(body, mediaUrl: (_) => null);
    expect(detail.stage, Launch2Stage.graduated);
    expect(detail.graduation!.hookAddress, _hook);
    expect(detail.pool, isNotNull);
    expect(detail.recentTrades, isNotEmpty);
  });

  test('dynamic-pool: a closed round (idle again) and the state after the '
      'claim decode as LoopDynamic', () {
    for (final name in <String>[
      'dynamic_pool_round_closed',
      'dynamic_pool_after_claim',
    ]) {
      final kind = LoopV2Launch2DynamicPoolCodec.pool(
        _fx(name),
        instanceId: _instance,
      );
      expect(kind, isA<Launch2LoopDynamicPool>(), reason: name);
      final state = (kind as Launch2LoopDynamicPool).state;
      expect(state.hook, _hook);
      expect(state.router, _router);
      expect(state.armed, isFalse);
      expect(state.currentRoundId, isNull);
      expect(state.viewer?.walletId, _wallet);
    }
  });

  test('rewards: round 1 claimable before the claim, claimed after it', () {
    final before = LoopV2Launch2DynamicPoolCodec.rewards(
      _fx('rewards_claimable'),
      instanceId: _instance,
      walletId: _wallet,
    );
    expect(before.claimableUsd1, _claimable);
    expect(before.claimedUsd1, Decimal.zero);
    expect(before.rounds, hasLength(1));
    expect(before.rounds.single.roundId, BigInt.one);
    expect(before.rounds.single.status.wireName, 'claimable');
    expect(before.rounds.single.weightUsd1, Decimal.fromInt(150));
    expect(before.rounds.single.totalBuyWeightUsd1, Decimal.fromInt(170));

    final after = LoopV2Launch2DynamicPoolCodec.rewards(
      _fx('rewards_after_claim'),
      instanceId: _instance,
      walletId: _wallet,
    );
    expect(after.claimableUsd1, Decimal.zero);
    expect(after.claimedUsd1, _claimable);
    expect(after.rounds.single.status.wireName, 'claimed');
    expect(after.rounds.single.claimTransactionHash, _claimTx);
  });

  test('claim: the prepared intent targets the Hook; the report confirms', () {
    final prepared = LoopV2Launch2DynamicPoolCodec.claimPrepared(
      _fx('claim_prepare'),
      instanceId: _instance,
      walletId: _wallet,
      roundId: BigInt.one,
    );
    expect(prepared.intent.contractAddress, _hook);
    expect(prepared.claim.hook, _hook);
    expect(prepared.claim.claimableUsd1, _claimable);

    final report = LoopV2Launch2DynamicPoolCodec.report(
      _fx('claim_report_confirmed'),
      instanceId: _instance,
      walletId: _wallet,
      roundId: BigInt.one,
      intentId: _intentId,
      transactionHash: _claimTx,
    );
    expect(report.status.wireName, 'confirmed');
    expect(report.amountUsd1, _claimable);
    expect(report.blockNumber, BigInt.from(136621714));
  });

  test('a buy quote on the LoopDynamic pool decodes', () {
    final quote = LoopV2Launch2PoolCodec.quote(
      _fx('pool_quote_buy'),
      instanceId: _instance,
      side: Launch2Side.buy,
      mode: Launch2PoolMode.exactIn,
      walletId: _wallet,
    );
    expect(quote, isA<Launch2PoolQuote>());
  });
}
