// S346 · review fixes to the in-app DApp browser (docs/57 §二 M1–M12,
// decision 0270 amendment).
import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/dapp/dapp_bridge.dart';
import 'package:loop_mobile/features/dapp/dapp_browser_screens.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/dapp/dapp_provider_script.dart';
import 'package:loop_mobile/features/dapp/dapp_signing.dart';
import 'package:loop_mobile/features/dapp/dapp_store.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_controller.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/dapp/loop_v2_dapp_api.dart';
import 'package:loop_mobile/integrations/backend/v2/dapp/loop_v2_dapp_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_dapp_browser_store.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s339_nft_send_fixtures.dart';
import 'support/s342_dapp_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

const String _other = 'https://other.example';

/// Secrets in order: boot nonce, then whatever is asked for, numbered.
String Function() _secrets() {
  var index = 0;
  return () => 'secret${index++}';
}

DappBridge _bare(
  FakeDappHost host, {
  FakeDappIntentsGateway? intents,
  Set<String>? connected,
}) {
  final origins = connected ?? <String>{s342Origin, _other};
  return DappBridge(
    host: host,
    intents: intents ?? FakeDappIntentsGateway(),
    reader: FakeDappRpcReader(),
    isConnected: (walletId, origin) => origins.contains(origin),
    setConnected: (walletId, origin, {required bool connected}) async {
      if (connected) {
        origins.add(origin);
      } else {
        origins.remove(origin);
      }
    },
    secrets: _secrets(),
  );
}

/// One document's handshake: its token, or `null` when refused.
String? _handshake(DappBridge bridge, String origin, {String? boot}) {
  final answer = bridge.ready(<Object?>[boot ?? bridge.bootNonce, origin]);
  return answer['ok'] == true ? answer['token']! as String : null;
}

List<Object?> _call(
  String token,
  String method, {
  String origin = s342Origin,
  List<Object?> params = const <Object?>[],
}) => <Object?>[
  token,
  origin,
  true,
  jsonEncode(<String, Object?>{'method': method, 'params': params}),
];

int? _code(Map<String, Object?> answer) =>
    (answer['error'] as Map<String, Object?>?)?['code'] as int?;

/// The guard double: records what the exit asked.
final class _Guard implements LoopStepUpGuard {
  final List<(Decimal?, bool)> asked = <(Decimal?, bool)>[];

  @override
  Future<LoopStepUpPlan> plan(Decimal? usd1) async =>
      const LoopStepUpPlan.none();

  @override
  Future<LoopStepUpVerdict> verify(Decimal? usd1, {bool force = false}) async {
    asked.add((usd1, force));
    return LoopStepUpVerdict.notRequired;
  }

  @override
  void release() {}
}

final class _Device implements LoopDeviceAuthenticator {
  final List<String> reasons = <String>[];

  @override
  Future<LoopDeviceAuthCapability> readCapability() async =>
      const LoopDeviceAuthCapability.available(LoopDeviceAuthFactor.biometric);

  @override
  Future<LoopDeviceAuthResult> authenticate({required String reason}) async {
    reasons.add(reason);
    return const LoopDeviceAuthResult(LoopDeviceAuthOutcome.succeeded);
  }
}

SigningIntent _transfer({Decimal? usd1, bool forced = false}) =>
    SigningIntent.backendCanonical(
      revision: 'intent-1',
      payloadDigest: 'a' * 64,
      title: '确认',
      kind: IntentKind.transfer,
      chainId: loopPrimaryChainId,
      payload: const DeviceTransactionPayload(
        fromAddress: '0x000000000000000000000000000000000000000a',
        transaction: <String, Object?>{'chainId': 56},
      ),
      observedAt: DateTime.utc(2026, 11, 3),
      expiresAt: DateTime.utc(2099),
      fields: const <IntentField>[],
      stepUpUsd1: usd1,
      stepUpRequired: forced,
    );

DappIntent _txIntent({
  List<Object?> flags = const <Object?>[],
  String value = '0x0',
  String reviewValue = '0',
  Map<String, Object?>? policy,
  String functionName = 'approve',
}) {
  final body = s342TxIntentBody(riskFlags: flags, value: value);
  final review = body['review']! as Map<String, Object?>;
  review['value'] = reviewValue;
  (review['decodedCall']! as Map<String, Object?>)['functionName'] =
      functionName;
  if (policy != null) body['policy'] = policy;
  return LoopV2DappCodec.intent(body);
}

void main() {
  loopWatchGround();

  group('M1 · a document holds the bridge only while it is on screen', () {
    test('the injected script names no nonce or token on window', () {
      final script = dappProviderScript(
        bootNonce: 'b00tb00t',
        chainIdHex: '0x61',
        providerUuid: '11111111-1111-4111-8111-111111111111',
      );
      // Nothing a `Object.getOwnPropertyNames(window)` scan could find.
      expect(script, isNot(contains('__loopEmit_')));
      expect(script, isNot(contains('window[__LOOP')));
      expect(script, isNot(contains('__LOOP_')));
      // The only window properties it defines: the fixed dispatcher and
      // `ethereum`.
      final defined = RegExp(r'Object\.defineProperty\(window, ([^,]+),')
          .allMatches(script)
          .map((match) => match.group(1))
          .toList();
      expect(defined, <String>['"__loopEthereumDispatch"', '"ethereum"']);
      // The boot nonce lives in the closure and is spent on first use.
      expect(script, contains('var BOOT = "b00tb00t";'));
      expect(script, contains('BOOT = null;'));
      expect(script, contains('"loopEthereumReady"'));
      // The dispatcher drops a call that does not present the closure token.
      expect(script, contains('presented !== emitToken'));
    });

    test('the old document asking during a navigation is 4100, and so is '
        'its token afterwards', () async {
      final host = FakeDappHost();
      final bridge = _bare(host);
      final first = _handshake(bridge, s342Origin)!;
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      expect(
        (await bridge.handle(_call(first, 'eth_accounts')))['result'],
        <String>[s342Address],
      );

      // The top frame starts loading another site. iOS reports the start
      // before the commit, while the old document still runs.
      bridge.documentStarting(Uri.parse('$_other/'));
      for (final origin in <String>[s342Origin, _other]) {
        expect(
          _code(
            await bridge.handle(_call(first, 'eth_accounts', origin: origin)),
          ),
          DappRpcErrorCode.unauthorized,
          reason: origin,
        );
      }
      expect(bridge.committedOrigin, isNull);

      // The new document shakes hands; its token waits for the load.
      final second = _handshake(bridge, _other)!;
      expect(
        _code(
          await bridge.handle(_call(second, 'eth_chainId', origin: _other)),
        ),
        DappRpcErrorCode.unauthorized,
      );
      bridge.documentLoaded(Uri.parse('$_other/'));
      expect(
        (await bridge.handle(
          _call(second, 'eth_chainId', origin: _other),
        ))['ok'],
        isTrue,
      );
      // The first document's token is gone for good, whatever it claims.
      for (final origin in <String>[s342Origin, _other]) {
        expect(
          _code(
            await bridge.handle(_call(first, 'eth_chainId', origin: origin)),
          ),
          DappRpcErrorCode.unauthorized,
        );
      }
      // A token is bound to the origin its document read for itself.
      expect(
        _code(
          await bridge.handle(_call(second, 'eth_chainId', origin: s342Origin)),
        ),
        DappRpcErrorCode.unauthorized,
      );
    });

    test('the boot nonce is spent once and replaced for the next document', () {
      final host = FakeDappHost();
      final bridge = _bare(host);
      final boot = bridge.bootNonce;
      expect(_handshake(bridge, s342Origin, boot: boot), isNotNull);
      expect(bridge.bootNonce, isNot(boot));
      expect(host.scriptChanges, 1);
      // Presented again — by the old document or anything that saw it.
      expect(_handshake(bridge, s342Origin, boot: boot), isNull);
      expect(_handshake(bridge, 'http://plain.example'), isNull);
    });

    test(
      'a document whose load stop names another origin is not promoted',
      () async {
        final bridge = _bare(FakeDappHost());
        bridge.documentStarting(Uri.parse('$_other/'));
        final token = _handshake(bridge, _other)!;
        // A stale stop for the page that was being left.
        bridge.documentLoaded(Uri.parse('$s342Origin/'));
        for (final origin in <String>[s342Origin, _other]) {
          expect(
            _code(
              await bridge.handle(_call(token, 'eth_chainId', origin: origin)),
            ),
            DappRpcErrorCode.unauthorized,
          );
        }
        bridge.documentLoaded(Uri.parse('$_other/x'));
        expect(
          (await bridge.handle(
            _call(token, 'eth_chainId', origin: _other),
          ))['ok'],
          isTrue,
        );
      },
    );

    test('Android order: the handshake before the start report keeps its '
        'place', () async {
      final bridge = _bare(FakeDappHost());
      _handshake(bridge, s342Origin);
      bridge.documentLoaded(Uri.parse('$s342Origin/a'));
      // The next same-origin document commits and shakes hands before
      // `onPageStarted` arrives.
      final token = _handshake(bridge, s342Origin)!;
      bridge.documentStarting(Uri.parse('$s342Origin/b'));
      expect(
        _code(await bridge.handle(_call(token, 'eth_chainId'))),
        DappRpcErrorCode.unauthorized,
      );
      bridge.documentLoaded(Uri.parse('$s342Origin/b'));
      expect((await bridge.handle(_call(token, 'eth_chainId')))['ok'], isTrue);
    });

    test('a navigation calls off the open confirmation and the queue, and '
        'every intent is released', () async {
      final host = FakeDappHost()..holdSheets = true;
      final intents = FakeDappIntentsGateway();
      final bridge = _bare(host, intents: intents);
      final token = _handshake(bridge, s342Origin)!;
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      final first = bridge.handle(
        _call(
          token,
          'personal_sign',
          params: <Object?>['0x68656c6c6f', s342Address],
        ),
      );
      final queued = bridge.handle(
        _call(token, 'personal_sign', params: <Object?>['0x6869', s342Address]),
      );
      await pumpEventQueue();
      expect(host.openSheets, hasLength(1));
      bridge.documentStarting(Uri.parse('$_other/'));
      expect(host.dismissals, greaterThan(0));
      expect(_code(await first), DappRpcErrorCode.userRejected);
      // The queued request never prepared anything.
      expect(_code(await queued), DappRpcErrorCode.unauthorized);
      expect(intents.prepared, hasLength(1));
      await pumpEventQueue();
      expect(intents.cancelled, <String>[s342IntentId]);
    });

    test('a prepare that returns after the page left is released', () async {
      final host = FakeDappHost();
      final gate = Completer<void>();
      final intents = _SlowIntents(gate);
      final bridge = _bare(host, intents: intents);
      final token = _handshake(bridge, s342Origin)!;
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      final answer = bridge.handle(
        _call(
          token,
          'personal_sign',
          params: <Object?>['0x68656c6c6f', s342Address],
        ),
      );
      await pumpEventQueue();
      bridge.documentStarting(Uri.parse('$_other/'));
      gate.complete();
      expect(_code(await answer), DappRpcErrorCode.unauthorized);
      await pumpEventQueue();
      expect(host.confirmed, isEmpty);
      expect(intents.cancelled, <String>[s342IntentId]);
    });

    test('events reach only the document on screen', () {
      final bridge = _bare(FakeDappHost());
      expect(bridge.emitScript('chainChanged', '0x38'), isNull);
      final answer = bridge.ready(<Object?>[bridge.bootNonce, s342Origin]);
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      final script = bridge.emitScript('chainChanged', '0x38')!;
      expect(script, contains('"${answer['emitToken']}"'));
      expect(script, isNot(contains(answer['token']! as String)));
      bridge.documentStarting(Uri.parse('$_other/'));
      expect(bridge.emitScript('chainChanged', '0x38'), isNull);
    });
  });

  group('M2 · DApp requests and the large-amount step-up', () {
    test('approval, permit and unreadable-signature flags force it', () {
      for (final flag in <String>[
        'UNLIMITED_APPROVAL',
        'APPROVAL_FOR_ALL',
        'EOA_SPENDER',
      ]) {
        expect(
          dappIntentStepUp(_txIntent(flags: <Object?>[flag])).forced,
          isTrue,
          reason: flag,
        );
      }
      expect(
        dappIntentStepUp(_txIntent(flags: <Object?>['UNVERIFIED_CONTRACT'])),
        (usd1: Decimal.zero, forced: false),
      );
      for (final flag in <String>[
        'PERMIT_SIGNATURE',
        'RAW_HASH_SIGNATURE',
        'UNRECOGNIZED_TYPED_DATA',
      ]) {
        final intent = LoopV2DappCodec.intent(
          s342SignIntentBody(riskFlags: <Object?>[flag]),
        );
        expect(dappIntentStepUp(intent).forced, isTrue, reason: flag);
      }
      expect(dappIntentStepUp(s342SignIntent()), (usd1: null, forced: false));
    });

    test('native coin is the server valuation; unvalued fails closed', () {
      final valued = _txIntent(
        value: '0xde0b6b3a7640000',
        reviewValue: '1000000000000000000',
        policy: <String, Object?>{
          'exposureBasis': 'native',
          'valueUsd': '612.5',
        },
      );
      expect(dappIntentStepUp(valued), (
        usd1: Decimal.parse('612.5'),
        forced: false,
      ));
      final testnet = _txIntent(
        value: '0xde0b6b3a7640000',
        reviewValue: '1000000000000000000',
        policy: <String, Object?>{'exposureBasis': 'none', 'valueUsd': null},
      );
      expect(dappIntentStepUp(testnet), (usd1: null, forced: true));
      // A token transfer has no figure this device can read.
      expect(
        dappIntentStepUp(_txIntent(functionName: 'transfer')).forced,
        isTrue,
      );
      final signing = DappSigner.signingIntent(
        testnet,
        fromAddress: s342Address,
      )!;
      expect(signing.stepUpRequired, isTrue);
    });

    test('the exit hands the forced flag to the guard', () async {
      final guard = _Guard();
      final exit = LoopStepUpWalletSigningGateway(
        inner: RecordingSigningGateway(),
        guard: guard,
      );
      await exit.handoff(
        _transfer(usd1: Decimal.one, forced: true),
        now: DateTime.utc(2026, 11, 3),
      );
      expect(guard.asked.single, (Decimal.one, true));
    });

    test('a forced request asks every time while the rule is on, never '
        'when it is off', () async {
      final device = _Device();
      final store = InMemoryLoopStepUpSettingsStore();
      final container = ProviderContainer(
        overrides: [
          loopDeviceAuthenticatorProvider.overrideWithValue(device),
          loopStepUpSettingsStoreProvider.overrideWithValue(store),
          loopAccountScopeProvider.overrideWithValue('did:privy:s346'),
        ],
      );
      addTearDown(container.dispose);
      final guard = container.read(loopStepUpProvider.notifier);
      expect(
        await guard.verify(Decimal.one, force: true),
        LoopStepUpVerdict.passed,
      );
      expect(
        await guard.verify(Decimal.one, force: true),
        LoopStepUpVerdict.passed,
      );
      expect(device.reasons, hasLength(2));
      // The same small figure without force is not asked.
      expect(await guard.verify(Decimal.one), LoopStepUpVerdict.notRequired);

      await store.write(
        'did:privy:s346',
        const LoopStepUpSettings(enabled: false, thresholdUsd1: 1000),
      );
      final off = ProviderContainer(
        overrides: [
          loopDeviceAuthenticatorProvider.overrideWithValue(device),
          loopStepUpSettingsStoreProvider.overrideWithValue(store),
          loopAccountScopeProvider.overrideWithValue('did:privy:s346'),
        ],
      );
      addTearDown(off.dispose);
      expect(
        await off.read(loopStepUpProvider.notifier).verify(null, force: true),
        LoopStepUpVerdict.notRequired,
      );
      expect(device.reasons, hasLength(2));
    });

    test('the three new flags are read and drawn', () {
      final intent = LoopV2DappCodec.intent(
        s342SignIntentBody(
          riskFlags: <Object?>[
            'UNRECOGNIZED_TYPED_DATA',
            'RAW_HASH_SIGNATURE',
            'EOA_SPENDER',
          ],
        ),
      );
      expect(intent.riskFlags.map((flag) => flag.label), <String>[
        '授权给个人地址',
        '原始哈希签名',
        '不可识别的签名结构',
      ]);
    });

    test('409 INTENT_BUSY is 4001 with the toast', () async {
      final host = FakeDappHost();
      final bridge = _bare(
        host,
        intents: FakeDappIntentsGateway(
          failure: const LoopChainException(
            LoopChainFailureKind.unexpected,
            reasonCode: 'INTENT_BUSY',
          ),
        ),
      );
      final token = _handshake(bridge, s342Origin)!;
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      expect(
        _code(
          await bridge.handle(
            _call(
              token,
              'personal_sign',
              params: <Object?>['0x68656c6c6f', s342Address],
            ),
          ),
        ),
        DappRpcErrorCode.userRejected,
      );
      expect(host.toasts, <String>['钱包有待处理的操作']);
      expect(DioLoopV2DappApi.writeErrors[409], contains('RESOURCE_CONFLICT'));
    });

    test('422 TYPED_DATA_INVALID is -32602 with no network hint', () async {
      final host = FakeDappHost();
      final bridge = _bare(
        host,
        intents: FakeDappIntentsGateway(
          failure: const LoopChainException(
            LoopChainFailureKind.validationFailed,
            reasonCode: 'TYPED_DATA_INVALID',
          ),
        ),
      );
      final token = _handshake(bridge, s342Origin)!;
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      expect(
        _code(
          await bridge.handle(
            _call(
              token,
              'eth_signTypedData_v4',
              params: <Object?>[s342Address, s342TypedData],
            ),
          ),
        ),
        DappRpcErrorCode.invalidParams,
      );
      expect(host.toasts, <String>['这笔请求没有通过检查']);
    });

    test('503 RPC_UPSTREAM_LIMITED and 429 RATE_LIMITED are -32005', () async {
      final bridge = DappBridge(
        host: FakeDappHost(),
        intents: FakeDappIntentsGateway(),
        reader: _LimitedReader(),
        isConnected: (walletId, origin) => true,
        setConnected: (walletId, origin, {required bool connected}) async {},
        secrets: _secrets(),
      );
      final token = _handshake(bridge, s342Origin)!;
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      expect(
        _code(await bridge.handle(_call(token, 'eth_blockNumber'))),
        DappRpcErrorCode.limitExceeded,
      );
      final limited = DappBridge(
        host: FakeDappHost(),
        intents: FakeDappIntentsGateway(),
        reader: _LimitedReader(
          const LoopChainException(
            LoopChainFailureKind.rateLimited,
            reasonCode: 'RATE_LIMITED',
          ),
        ),
        isConnected: (walletId, origin) => true,
        setConnected: (walletId, origin, {required bool connected}) async {},
        secrets: _secrets(),
      );
      final second = _handshake(limited, s342Origin)!;
      limited.documentLoaded(Uri.parse('$s342Origin/'));
      expect(
        _code(await limited.handle(_call(second, 'eth_blockNumber'))),
        DappRpcErrorCode.limitExceeded,
      );
    });
  });

  group('M3 / M4 · local lists per account', () {
    test('two accounts never read each other; sign-out drops connections and '
        'recents; the shared first-build key is dropped', () async {
      final storage = <String, String>{
        SharedPreferencesDappBrowserStore.legacyKey: '{"v":1}',
      };
      final store = SharedPreferencesDappBrowserStore.forTesting(
        (key) async => storage[key],
        (key, value) async => storage[key] = value,
        (key) async => storage.remove(key),
      );
      final a = DappBrowserLocalState()
          .visited(const DappPageEntry(url: 'https://a.example/', title: 'A'))
          .toggledBookmark(
            const DappPageEntry(url: 'https://a.example/?ref=x', title: 'A'),
          )
          .withConnection(s342WalletId, s342Origin, on: true);
      await store.write('did:privy:a', a);
      expect(storage.keys.any((key) => key.contains('did:privy')), isFalse);
      expect((await store.read('did:privy:b')).recents, isEmpty);
      expect(
        storage.containsKey(SharedPreferencesDappBrowserStore.legacyKey),
        isFalse,
      );
      expect(
        (await store.read('did:privy:a')).isConnected(s342WalletId, s342Origin),
        isTrue,
      );
      // Another wallet of the same account is not connected by it.
      expect(
        (await store.read('did:privy:a'))
            .isConnected('9b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e', s342Origin),
        isFalse,
      );
      expect((await store.read(null)).recents, isEmpty);

      await dappForgetAccount(store, 'did:privy:a');
      final after = await store.read('did:privy:a');
      expect(after.recents, isEmpty);
      expect(after.connections, isEmpty);
      expect(after.bookmarks.single.url, 'https://a.example/?ref=x');
    });

    test('recents keep origin and path only; bookmarks the full URL', () {
      final state = DappBrowserLocalState()
          .visited(
            const DappPageEntry(
              url: 'https://app.example.org/swap?session=abc#/pool',
              title: 'Swap',
            ),
          )
          .toggledBookmark(
            const DappPageEntry(
              url: 'https://app.example.org/swap?session=abc#/pool',
              title: 'Swap',
            ),
          );
      expect(state.recents.single.url, 'https://app.example.org/swap');
      expect(
        state.bookmarks.single.url,
        'https://app.example.org/swap?session=abc#/pool',
      );
      final decoded = DappBrowserLocalState.decode(
        jsonEncode(<String, Object?>{
          'v': 2,
          'recents': <Object?>[
            <String, Object?>{
              'url': 'https://b.example/p?token=1',
              'title': 'B',
            },
          ],
        }),
      );
      expect(decoded.recents.single.url, 'https://b.example/p');
    });
  });

  group(
    'M7 / M8 · what is signed is what the page asked and the sheet shows',
    () {
      test('typed data: numbers by literal, past 2^53 refused', () {
        String typed(String value) =>
            '{"types":{"EIP712Domain":[]},"primaryType":"Permit",'
            '"domain":{"name":"Token","chainId":97},'
            '"message":{"owner":"$s342Address","spender":"$s342Spender",'
            '"value":$value}}';
        DappIntent intent(String payload) => LoopV2DappCodec.intent(
          s342SignIntentBody(method: 'eth_signTypedData_v4', payload: payload),
        );
        bool matches(String signed, String asked) => intent(signed).matchesSign(
          DappSignRequest(method: 'eth_signTypedData_v4', payload: asked),
        );
        expect(matches(typed('1000'), typed('1000')), isTrue);
        expect(matches(typed('1000'), typed('1000.0')), isFalse);
        // 2^53 + 1 and 2^53 + 2 are one double; they are not one literal.
        expect(
          matches(typed('9007199254740993'), typed('9007199254740993')),
          isFalse,
        );
        expect(
          () => DappJsonLiteral.parse('{"a":9007199254740993}'),
          throwsFormatException,
        );
        expect(DappJsonLiteral.parse('{"a":9007199254740992}'), isA<Map>());
      });

      test(
        'typed data whose shown leaves differ from the request is refused',
        () {
          final body = s342SignIntentBody(
            method: 'eth_signTypedData_v4',
            payload: s342TypedData,
          );
          final message =
              (body['review']! as Map<String, Object?>)['message']!
                  as Map<String, Object?>;
          final shown = message['typedData']! as Map<String, Object?>;
          (shown['message']! as Map<String, Object?>)['spender'] = s342Address;
          final intent = LoopV2DappCodec.intent(body);
          expect(
            intent.matchesSign(
              const DappSignRequest(
                method: 'eth_signTypedData_v4',
                payload: s342TypedData,
              ),
            ),
            isFalse,
          );
          // The S342-api flattened review: every field path is checked.
          final api = LoopV2DappCodec.intent(s342ApiSignBody());
          expect(
            api.matchesSign(
              const DappSignRequest(
                method: 'eth_signTypedData_v4',
                payload: s342TypedData,
              ),
            ),
            isTrue,
          );
        },
      );

      test('personal_sign: the shown text must decode from the payload', () {
        final body = s342SignIntentBody();
        final message =
            (body['review']! as Map<String, Object?>)['message']!
                as Map<String, Object?>;
        message['text'] = 'transfer all';
        final intent = LoopV2DappCodec.intent(body);
        final refusal = DappSigner.refusalBeforeWallet(
          intent,
          origin: s342Origin,
          fromAddress: s342Address,
          now: DateTime.utc(2026, 11, 3),
          sign: const DappSignRequest(
            method: 'personal_sign',
            payload: '0x68656c6c6f',
          ),
        );
        expect(refusal, 'REVIEW_PAYLOAD_MISMATCH');
      });

      test('an intent bound to another origin is refused', () {
        expect(
          DappSigner.refusalBeforeWallet(
            s342TxIntent(),
            origin: _other,
            fromAddress: s342Address,
            now: DateTime.utc(2026, 11, 3),
            tx: s342TxRequest,
          ),
          'REVIEW_PAYLOAD_MISMATCH',
        );
        expect(
          DappSigner.refusalBeforeWallet(
            s342TxIntent(),
            origin: s342Origin,
            fromAddress: s342Address,
            now: DateTime.utc(2026, 11, 3),
            tx: s342TxRequest,
          ),
          isNull,
        );
      });
    },
  );

  group('M5 · every way out that produced nothing releases the intent', () {
    for (final outcome in <DappSignOutcome>[
      const DappSignOutcome.rejected(),
      const DappSignOutcome(
        status: DappSignStatus.failed,
        reasonCode: 'REVIEW_PAYLOAD_MISMATCH',
      ),
    ]) {
      test('${outcome.status.name} is released', () async {
        final intents = FakeDappIntentsGateway();
        final bridge = _bare(FakeDappHost(outcome: outcome), intents: intents);
        final token = _handshake(bridge, s342Origin)!;
        bridge.documentLoaded(Uri.parse('$s342Origin/'));
        await bridge.handle(
          _call(
            token,
            'personal_sign',
            params: <Object?>['0x68656c6c6f', s342Address],
          ),
        );
        await pumpEventQueue();
        expect(intents.cancelled, <String>[s342IntentId]);
      });
    }

    test('a produced signature is not released', () async {
      final intents = FakeDappIntentsGateway();
      final bridge = _bare(FakeDappHost(), intents: intents);
      final token = _handshake(bridge, s342Origin)!;
      bridge.documentLoaded(Uri.parse('$s342Origin/'));
      await bridge.handle(
        _call(
          token,
          'personal_sign',
          params: <Object?>['0x68656c6c6f', s342Address],
        ),
      );
      await pumpEventQueue();
      expect(intents.cancelled, isEmpty);
    });
  });

  group('pages', () {
    Future<void> pumpPage(
      WidgetTester tester,
      Widget page, {
      DappWebViewFactory? factory,
      DappBrowserStore? store,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      loopArmGroundProbe(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopV2MetaSnapshotProvider.overrideWith(
              (ref) async => s5MetaSnapshot(
                dappBrowser: LoopV2CapabilityAvailability.available,
              ),
            ),
            dappWebViewFactoryProvider.overrideWithValue(
              factory ?? FakeDappWebViewFactory(),
            ),
            loopAccountScopeProvider.overrideWithValue(s342Account),
            dappBrowserStoreProvider.overrideWithValue(
              store ?? MemoryDappBrowserStore(),
            ),
            dappIntentsGatewayProvider.overrideWithValue(
              FakeDappIntentsGateway(),
            ),
            walletReadGatewayProvider.overrideWithValue(
              FakeWalletReadGateway(),
            ),
            walletSigningGatewayProvider.overrideWithValue(
              RecordingSigningGateway(),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => LoopToastHost(child: child!),
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('M1 / M12 · a navigation shuts the old token out; a blocked '
        'target is stopped and never admitted', (tester) async {
      final factory = FakeDappWebViewFactory();
      await pumpPage(
        tester,
        DappBrowserPage(
          key: UniqueKey(),
          request: DappOpenRequest(url: Uri.parse('$s342Origin/swap')),
        ),
        factory: factory,
      );
      final config = factory.config!;
      final controller = factory.controller;
      final first = controller.token!;
      Future<Map<String, Object?>> ask(String token, String origin) async =>
          (await config.onBridgeCall(
                _call(token, 'eth_chainId', origin: origin),
              ))!
              as Map<String, Object?>;
      expect((await ask(first, s342Origin))['result'], '0x61');

      config.onLoadStart(Uri.parse('$_other/'));
      await tester.pump();
      expect(
        _code(await ask(first, s342Origin)),
        DappRpcErrorCode.unauthorized,
      );
      expect(_code(await ask(first, _other)), DappRpcErrorCode.unauthorized);
      // The host keeps naming the page it holds until the new one loads.
      expect(find.text('app.example.org'), findsOneWidget);

      // The new document reads its boot nonce from the replaced script.
      final boot = RegExp(r'var BOOT = "([0-9a-f]+)"')
          .firstMatch(controller.documentScripts.last)!
          .group(1)!;
      final answer = config.onReady(<Object?>[boot, _other])! as Map;
      final second = answer['token']! as String;
      config.onLoadStop(Uri.parse('$_other/'));
      await tester.pump();
      expect(find.text('other.example'), findsOneWidget);
      expect((await ask(second, _other))['ok'], isTrue);
      expect(
        _code(await ask(first, s342Origin)),
        DappRpcErrorCode.unauthorized,
      );

      // M12: a navigation that slipped past the check is stopped.
      config.onLoadStart(Uri.parse('https://user:pw@a.example/'));
      await tester.pump();
      expect(controller.calls, contains('stop'));
      config.onLoadStop(Uri.parse('https://user:pw@a.example/'));
      await tester.pump();
      expect(find.text('a.example'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('M9 · a flagged recent page shows its findings first', (
      tester,
    ) async {
      final opened = <DappOpenRequest>[];
      await pumpPage(
        tester,
        DappEntryScreen(onOpen: opened.add),
        store: MemoryDappBrowserStore(<String, DappBrowserLocalState>{
          s342Account: DappBrowserLocalState(
            recents: const <DappPageEntry>[
              DappPageEntry(url: 'https://app.example.org:8443/', title: 'R'),
            ],
          ),
        }),
      );
      await tester.tap(find.text('R'));
      await tester.pumpAndSettle();
      expect(opened.single.acknowledged, isFalse);
    });

    testWidgets('M10 · the wallet row follows the page: no WebView, no '
        'browser', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        meta: s5MetaSnapshot(
          dappBrowser: LoopV2CapabilityAvailability.available,
        ),
      );
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-dapp-entry')),
      );
      // S349: the key never names the browser; `/wallet/dapp` decides.
      expect(find.text('DApp 浏览器'), findsNothing);
      expect(find.text('DApp'), findsOneWidget);
    });

    for (final (sendApprovals, nftSend, blocked)
        in <(LoopV2CapabilityAvailability, LoopV2CapabilityAvailability, bool)>[
          (
            LoopV2CapabilityAvailability.unavailable,
            LoopV2CapabilityAvailability.available,
            false,
          ),
          (
            LoopV2CapabilityAvailability.available,
            LoopV2CapabilityAvailability.unavailable,
            true,
          ),
        ]) {
      testWidgets('M11 · the NFT send pages follow nftSend '
          '(send ${sendApprovals.name}, nftSend ${nftSend.name})', (
        tester,
      ) async {
        await pumpS6Page(
          tester,
          SendFlowScreen(initialDraft: SendDraft.nft(s339Target)),
          wallet: FakeWalletReadGateway(),
          intents: FakeWalletIntentsGateway(),
          sendApprovals: sendApprovals,
          nftSend: nftSend,
          overrides: const <Override>[],
        );
        expect(
          find.byKey(const ValueKey<String>('send-capability-block')),
          blocked ? findsOneWidget : findsNothing,
        );
        await pumpS6Page(
          tester,
          SendConfirmScreen(
            draft: SendDraft.nft(
              s339Target,
              recipientAddress: s6RecipientChecksum,
            ),
          ),
          wallet: FakeWalletReadGateway(),
          intents: FakeWalletIntentsGateway(preparePending: true),
          sendApprovals: sendApprovals,
          nftSend: nftSend,
          settle: false,
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('send-confirm-capability-block')),
          blocked ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}

/// A prepare held until [gate] opens.
final class _SlowIntents extends FakeDappIntentsGateway {
  _SlowIntents(this.gate);

  final Completer<void> gate;

  @override
  Future<DappIntent> prepareSign({
    required String walletId,
    required String chainId,
    required String origin,
    required DappSignRequest request,
  }) async {
    await gate.future;
    return super.prepareSign(
      walletId: walletId,
      chainId: chainId,
      origin: origin,
      request: request,
    );
  }
}

final class _LimitedReader implements DappRpcReader {
  _LimitedReader([
    this.failure = const LoopChainException(
      LoopChainFailureKind.unavailable,
      reasonCode: 'RPC_UPSTREAM_LIMITED',
    ),
  ]);

  final LoopChainException failure;

  @override
  Future<Object?> read({
    required String chainId,
    required String method,
    required List<Object?> params,
  }) async => throw failure;
}
