// S309 · decision 0249: the bound-token field takes a bare contract address
// and the App completes the `eip155:{ref}:` prefix with the primary chain the
// server published. A full key still works and keeps its own chain.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';

import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const _lower = '0x040ecd2c604cfa86b35f817d845f441b97f46666';
const _mixed = '0x040ECD2C604CFA86B35F817D845F441B97F46666';

LoopChainStatus _statusOn(String chainId) {
  final base = s5Status();
  return LoopChainStatus(
    chain: LoopChainInfo(
      chainId: chainId,
      name: base.chain.name,
      reference: loopChainReference(chainId),
      nativeAssetId: base.chain.nativeAssetId,
      confirmations: base.chain.confirmations,
      reorgDepthBlocks: base.chain.reorgDepthBlocks,
    ),
    rpc: base.rpc,
    indexer: base.indexer,
    registry: base.registry,
  );
}

List<Override> _publishing(String chainId) => <Override>[
  chainGatewayProvider.overrideWithValue(
    FakeChainGateway(
      status: S5Answer<LoopChainStatus>(value: _statusOn(chainId)),
    ),
  ),
];

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> _openApply(
  WidgetTester tester,
  void Function(CommunityApplication?) onResult, {
  List<Override> overrides = const <Override>[],
}) async {
  await pumpCommunityPage(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                unawaited(showCommunityApplySheet(context).then(onResult)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    overrides: overrides,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(WidgetTester tester, String assetKey) async {
  await tester.enterText(_key('community-apply-name'), 'Frog Holders');
  await tester.enterText(_key('community-apply-slug'), 'frog-holders');
  await tester.enterText(_key('community-apply-asset-key'), assetKey);
  await tester.pump();
  await tester.ensureVisible(_key('community-apply-submit'));
  await tester.tap(_key('community-apply-submit'));
  await tester.pumpAndSettle();
}

String _hintOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key(key)).decoration!.hintText!;

void main() {
  group('normalizeCommunityBoundAssetKey', () {
    test('a bare address gets the chain prefix', () {
      expect(
        normalizeCommunityBoundAssetKey(_lower, chainId: 'eip155:97'),
        'eip155:97:$_lower',
      );
      expect(
        normalizeCommunityBoundAssetKey(_lower, chainId: loopPrimaryChainId),
        'eip155:56:$_lower',
      );
    });

    test('a full key keeps its own chain', () {
      expect(
        normalizeCommunityBoundAssetKey(
          'eip155:56:$_lower',
          chainId: 'eip155:97',
        ),
        'eip155:56:$_lower',
      );
    });

    test('upper case is lowered, whitespace trimmed', () {
      expect(
        normalizeCommunityBoundAssetKey(
          '  EIP155:97:$_mixed \n',
          chainId: 'eip155:56',
        ),
        'eip155:97:$_lower',
      );
      expect(
        normalizeCommunityBoundAssetKey(' $_mixed ', chainId: 'eip155:97'),
        'eip155:97:$_lower',
      );
    });

    test('anything else is null', () {
      for (final typed in <String>[
        '',
        '   ',
        '0x1234',
        '${_lower}00',
        'eip155:56:0xnothex',
        'eip155:0:$_lower',
        'solana:$_lower',
        '040ecd2c604cfa86b35f817d845f441b97f46666',
        'eip155:56:$_lower:extra',
      ]) {
        expect(
          normalizeCommunityBoundAssetKey(typed, chainId: 'eip155:97'),
          isNull,
          reason: typed,
        );
      }
    });

    test('the result always matches the wire shape', () {
      final key = normalizeCommunityBoundAssetKey(
        _mixed,
        chainId: 'eip155:97',
      )!;
      expect(CommunityApplication.boundAssetKeyPattern.hasMatch(key), isTrue);
    });
  });

  group('创建社区 · 绑定代币', () {
    tearDown(() => debugSetLoopTestHintsVisible(null));

    testWidgets('no chain status: falls back to the primary slot, said aloud', (
      tester,
    ) async {
      CommunityApplication? result;
      await _openApply(tester, (value) => result = value);

      expect(
        _hintOf(tester, 'community-apply-asset-key'),
        '绑定代币（选填）0x…（也可粘贴 eip155:56:0x… 整串）',
      );
      expect(
        find.textContaining('暂未取到链状态，只填地址时将按 BNB Smart Chain 补全。'),
        findsOneWidget,
      );

      await _fillAndSubmit(tester, 'not-an-address');
      expect(find.text('需要 40 位十六进制合约地址，可带 eip155:56: 前缀。'), findsOneWidget);
      expect(result, isNull);

      await _fillAndSubmit(tester, _mixed);
      expect(result?.boundAssetKey, 'eip155:56:$_lower');
    });

    testWidgets('published testnet primary: a bare address gets eip155:97', (
      tester,
    ) async {
      debugSetLoopTestHintsVisible(false);
      CommunityApplication? result;
      await _openApply(
        tester,
        (value) => result = value,
        overrides: _publishing(loopLaunchTestnetChainId),
      );

      expect(
        _hintOf(tester, 'community-apply-asset-key'),
        '绑定代币（选填）0x…（也可粘贴 eip155:97:0x… 整串）',
      );
      // Decision 0204: switch off, the testnet is named BNB Smart Chain.
      expect(
        find.textContaining('只填合约地址即可，将按 BNB Smart Chain 补全。'),
        findsOneWidget,
      );

      await _fillAndSubmit(tester, '  $_lower  ');
      expect(result?.boundAssetKey, 'eip155:97:$_lower');
    });

    testWidgets('test hints on: the testnet name is drawn', (tester) async {
      debugSetLoopTestHintsVisible(true);
      await _openApply(
        tester,
        (_) {},
        overrides: _publishing(loopLaunchTestnetChainId),
      );
      expect(
        find.textContaining('将按 $loopTestnetChainLabel 补全。'),
        findsOneWidget,
      );
    });

    testWidgets('a full key keeps the chain it names', (tester) async {
      CommunityApplication? result;
      await _openApply(
        tester,
        (value) => result = value,
        overrides: _publishing(loopLaunchTestnetChainId),
      );
      await _fillAndSubmit(tester, 'eip155:56:$_mixed');
      expect(result?.boundAssetKey, 'eip155:56:$_lower');
    });
  });

  group('编辑社区资料 · 绑定代币', () {
    Future<void> openEdit(
      WidgetTester tester,
      void Function(CommunityProfileEdit?) onResult, {
      String? boundAssetKey,
    }) async {
      await pumpCommunityPage(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => unawaited(
                  showCommunityProfileEditSheet(
                    context,
                    community: testCommunity(boundAssetKey: boundAssetKey),
                    includeBoundAsset: true,
                  ).then(onResult),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: _publishing(loopLaunchTestnetChainId),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String typed) async {
      await tester.enterText(_key('community-edit-bound-asset'), typed);
      await tester.pump();
      await tester.ensureVisible(_key('community-edit-submit'));
      await tester.tap(_key('community-edit-submit'));
      await tester.pumpAndSettle();
    }

    testWidgets('the bound key is shown whole; its bare address is no change', (
      tester,
    ) async {
      CommunityProfileEdit? result;
      await openEdit(
        tester,
        (value) => result = value,
        boundAssetKey: 'eip155:97:$_lower',
      );
      expect(
        tester
            .widget<TextField>(_key('community-edit-bound-asset'))
            .controller!
            .text,
        'eip155:97:$_lower',
      );
      expect(
        tester
            .widget<TextField>(_key('community-edit-bound-asset'))
            .decoration!
            .hintText,
        '0x…（也可粘贴 eip155:97:0x… 整串）',
      );
      await submit(tester, _mixed);
      expect(result, isNotNull);
      expect(result!.boundAssetKey, isNull);
      expect(result!.clearBoundAssetKey, isFalse);
    });

    testWidgets('a bare address on an unbound community binds on the '
        'published chain; junk is refused', (tester) async {
      CommunityProfileEdit? result;
      await openEdit(tester, (value) => result = value);
      await submit(tester, '0x12');
      expect(find.text('需要 40 位十六进制合约地址，可带 eip155:97: 前缀。'), findsOneWidget);
      expect(result, isNull);
      await submit(tester, _lower);
      expect(result?.boundAssetKey, 'eip155:97:$_lower');
    });
  });
}
