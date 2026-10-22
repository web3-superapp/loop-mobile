// S281 · decision 0238 (需求方 10-22 第 08 条): the wallet's MEME v2 token
// rows show the holding valued in USD1 when `me/positions` carries it
// (loop-api S280, client first), and a valued row sorts with the other
// valued rows.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_wallet_rows.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_shots.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _instanceC = 'ad1b5e30-4f6c-4b8d-9e0f-3a4b5c6d7e8f';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String? _noMedia(String mediaId) => null;

/// Answers `me/positions` only.
final class _Positions implements Launch2Gateway {
  _Positions(this.answer);

  final Launch2Positions answer;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Positions> loadPositions() async => answer;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

LoopV2MetaSnapshot _metaWithLaunch2() {
  final base = s5MetaSnapshot();
  final launch2 = LoopV2Capability(
    id: LoopV2CapabilityId.launch2,
    availability: LoopV2CapabilityAvailability.available,
    reasonCode: null,
    evidence: const LoopV2CapabilityEvidence(
      status: LoopV2CapabilityEvidenceStatus.notApplicable,
      reasonCode: null,
    ),
  );
  final listed = base.capabilities.capabilities.any(
    (capability) => capability.id == LoopV2CapabilityId.launch2,
  );
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: base.capabilities.contractVersion,
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          capability.id == LoopV2CapabilityId.launch2 ? launch2 : capability,
        if (!listed) launch2,
      ],
    ),
  );
}

/// One `me/positions` row: the fixture row renamed, plus [extra] keys.
Map<String, Object?> _row(
  String id,
  String ticker, {
  String stage = 'public',
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  final base =
      (l2PositionsJson(stage: stage)['positions']! as List<Object?>).single!
          as Map<String, Object?>;
  return <String, Object?>{
    ...base,
    'instanceId': id,
    'ticker': ticker,
    ...extra,
  };
}

Launch2Positions _positions(List<Map<String, Object?>> rows) =>
    LoopV2Launch2Codec.positions(<String, Object?>{
      'positions': rows,
      'contractVersion': '2.0',
    }, mediaUrl: _noMedia);

Launch2Position _one(Map<String, Object?> extra) =>
    _positions(<Map<String, Object?>>[_row(l2InstanceA, 'FROG', extra: extra)])
        .items
        .single;

Future<void> _pumpWallet(
  WidgetTester tester,
  Launch2Positions positions, {
  List<LoopAssetBalanceRow>? rows,
}) => pumpS5Page(
  tester,
  const WalletScreen(),
  wallet: FakeWalletReadGateway(
    balances: S5Answer<LoopWalletBalances>(value: s5Balances(rows: rows)),
  ),
  meta: _metaWithLaunch2(),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(_Positions(positions)),
  ],
);

String _caption(WidgetTester tester, String instanceId) =>
    tester.widget<Text>(_key('launch2-wallet-meme-$instanceId-caption')).data!;

void main() {
  group('codec: priceUsd1 / valueUsd1 / priceSource (S280 keys)', () {
    test('present keys are read', () {
      final position = _one(<String, Object?>{
        'priceUsd1': '0.0000123',
        'valueUsd1': '1234.56',
        'priceSource': 'curve',
      });
      expect(position.priceUsd1, Decimal.parse('0.0000123'));
      expect(position.valueUsd1, Decimal.parse('1234.56'));
      expect(position.priceSource, Launch2PriceSource.curve);
      expect(
        _one(<String, Object?>{'priceSource': 'pool'}).priceSource,
        Launch2PriceSource.pool,
      );
    });

    test('absent keys are no price (an older server)', () {
      final position = l2Positions().items.single;
      expect(position.priceUsd1, isNull);
      expect(position.valueUsd1, isNull);
      expect(position.priceSource, isNull);
    });

    test('null keys are no price', () {
      final position = _one(<String, Object?>{
        'priceUsd1': null,
        'valueUsd1': null,
        'priceSource': null,
      });
      expect(position.priceUsd1, isNull);
      expect(position.valueUsd1, isNull);
      expect(position.priceSource, isNull);
    });

    test('junk never refuses the row; it reads as no price', () {
      for (final junk in <Object?>[
        42,
        1.5,
        '',
        'abc',
        '-1',
        '1e5',
        '01',
        '1.',
        '0x10',
        true,
        <String, Object?>{},
      ]) {
        final position = _one(<String, Object?>{
          'priceUsd1': junk,
          'valueUsd1': junk,
          'priceSource': junk,
        });
        expect(position.priceUsd1, isNull, reason: '$junk');
        expect(position.valueUsd1, isNull, reason: '$junk');
        expect(position.priceSource, isNull, reason: '$junk');
        expect(position.ticker, 'FROG');
      }
      expect(_one(<String, Object?>{'priceSource': 'dex'}).priceSource, isNull);
    });
  });

  group('value text', () {
    test('grouped to cents, a positive sub-cent value is < 0.01', () {
      expect(
        launch2WalletValueText(Decimal.parse('1234.5678')),
        '≈ 1,234.57 USD1',
      );
      expect(launch2WalletValueText(Decimal.parse('0.004')), '< 0.01 USD1');
      expect(launch2WalletValueText(Decimal.zero), '≈ 0 USD1');
    });
  });

  group('wallet 代币 rows', () {
    testWidgets('valued: amount and ≈ USD1 both shown; stage on the left', (
      tester,
    ) async {
      await _pumpWallet(
        tester,
        l2Positions(
          stage: 'public',
          extra: <String, Object?>{
            'priceUsd1': '0.001097',
            'valueUsd1': '1234.56',
            'priceSource': 'curve',
          },
        ),
      );
      expect(_key('launch2-wallet-meme-$l2InstanceA'), findsOneWidget);
      expect(find.text('1,125,000.5'), findsOneWidget);
      expect(_caption(tester, l2InstanceA), '≈ 1,234.56 USD1');
      expect(find.text('Launch 链 · 内盘持仓 · 公开内盘'), findsOneWidget);
      expect(find.text('Launch 链 · 内盘持仓'), findsNothing);
    });

    testWidgets('unvalued: the stage stays the grey figure', (tester) async {
      await _pumpWallet(tester, l2Positions(stage: 'public'));
      expect(find.text('1,125,000.5'), findsOneWidget);
      expect(_caption(tester, l2InstanceA), '公开内盘');
      expect(find.text('Launch 链 · 内盘持仓'), findsOneWidget);
      expect(find.textContaining(' USD1'), findsNothing);
    });

    testWidgets('graduated with a read balance: valued from the pool', (
      tester,
    ) async {
      await _pumpWallet(
        tester,
        l2Positions(
          stage: 'graduated',
          holding: l2HoldingJson(),
          extra: <String, Object?>{
            'priceUsd1': '0.02',
            'valueUsd1': '146.6636',
            'priceSource': 'pool',
          },
        ),
      );
      expect(find.text('7,333.18'), findsOneWidget);
      expect(_caption(tester, l2InstanceA), '≈ 146.66 USD1');
      expect(find.text('Launch 链 · 已毕业'), findsOneWidget);
    });

    testWidgets('hidden amounts hide the value too', (tester) async {
      await pumpS5Page(
        tester,
        Material(
          child: ListView(
            children: <Widget>[Launch2WalletRows(onOpen: (_) {}, hidden: true)],
          ),
        ),
        meta: _metaWithLaunch2(),
        overrides: <Override>[
          launch2GatewayProvider.overrideWithValue(
            _Positions(
              l2Positions(
                stage: 'public',
                extra: <String, Object?>{'valueUsd1': '1234.56'},
              ),
            ),
          ),
        ],
      );
      expect(_caption(tester, l2InstanceA), '≈ **** USD1');
      expect(find.textContaining('1,234'), findsNothing);
    });

    testWidgets('a valued MEME row sorts by value with the main rows; an '
        'unvalued one stays last', (tester) async {
      // BNB is valued 5,231.73 USD by the fixture.
      await _pumpWallet(
        tester,
        _positions(<Map<String, Object?>>[
          _row(
            l2InstanceA,
            'SMALL',
            extra: <String, Object?>{'valueUsd1': '12.5'},
          ),
          _row(_instanceC, 'NOPRICE'),
          _row(
            l2InstanceB,
            'BIG',
            extra: <String, Object?>{'valueUsd1': '9000'},
          ),
        ]),
      );
      double top(String key) => tester.getTopLeft(_key(key)).dy;
      final order = <String>[
        'launch2-wallet-meme-$l2InstanceB',
        'wallet-balance-open-$s5NativeAssetId',
        'launch2-wallet-meme-$l2InstanceA',
        'launch2-wallet-meme-$_instanceC',
      ];
      for (var i = 0; i + 1 < order.length; i += 1) {
        expect(top(order[i]), lessThan(top(order[i + 1])), reason: order[i]);
      }
      if (_shots) {
        await loopShot(
          tester,
          'wallet-tokens-usd1-value',
          dir: 'docs/integration/S281/shots',
        );
      }
    });
  });
}
