// S306 · decision 0246: 我的钱包 binds and unbinds external wallets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/wallet/external_wallet_intro_store.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/reown/external_wallet_credential_gateway.dart';
import 'package:loop_mobile/integrations/reown/reown_external_wallet_connector.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const _principal = 'did:privy:s306';

const _config = AppConfig(
  privyAppId: 'privy-app',
  privyAppClientId: 'privy-client',
  reownProjectId: '26a5cc1adad234fcdf7762b8d2a2b28d',
  streamApiKey: '',
  backendBaseUrl: '',
  firebaseConfigured: false,
);

String _externalAddress(int index) =>
    '0x${(index + 1).toRadixString(16).padLeft(40, 'e')}';

String _externalId(int index) =>
    '2d4e3f5a-6b7c-4d8e-9f0a-1b2c3d4e5f${index.toString().padLeft(2, '0')}';

LoopWalletDirectory _directory({
  int externals = 0,
  int archived = 0,
  int? limit,
}) => LoopWalletDirectory(
  wallets: <LoopWalletAccount>[
    LoopWalletAccount(
      walletId: s5WalletId,
      address: s5Address,
      kind: LoopWalletKind.embedded,
      status: LoopWalletStatus.active,
      isActive: true,
      firstSeenAt: DateTime.utc(2026, 10, 1),
      lastSeenAt: DateTime.utc(2026, 10, 1),
    ),
    for (var i = 0; i < externals + archived; i++)
      LoopWalletAccount(
        walletId: _externalId(i),
        address: _externalAddress(i),
        kind: LoopWalletKind.external,
        status: i < externals
            ? LoopWalletStatus.active
            : LoopWalletStatus.archived,
        isActive: false,
        firstSeenAt: DateTime.utc(2026, 10, 1),
        lastSeenAt: DateTime.utc(2026, 10, 1),
      ),
  ],
  activeWalletId: s5WalletId,
  observedAt: DateTime.utc(2026, 10, 25, 8),
  externalWalletLimit: limit,
);

final class _Harness {
  _Harness({this.introSeen});

  final bool? introSeen;
  final external = _ExternalCredentialGateway();
  final credential = _CredentialGateway();
  final sync = _SyncGateway();
  late final InMemoryLoopExternalWalletIntroStore intro =
      InMemoryLoopExternalWalletIntroStore(introSeen);

  late ProviderContainer container;

  Future<FakeWalletReadGateway> pump(
    WidgetTester tester, {
    required LoopWalletDirectory directory,
    List<PrivyExternalEvmCredentialSummary> credentials =
        const <PrivyExternalEvmCredentialSummary>[],
  }) async {
    final wallet = FakeWalletReadGateway(
      directory: S5Answer<LoopWalletDirectory>(value: directory),
    );
    await pumpS5Page(
      tester,
      const WalletManagerScreen(),
      wallet: wallet,
      privy: _SessionGateway(),
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        loopSessionUnauthenticatedGraceProvider.overrideWithValue(
          Duration.zero,
        ),
        privyCredentialGatewayProvider.overrideWithValue(credential),
        externalWalletCredentialGatewayProvider.overrideWithValue(external),
        walletInventorySyncGatewayProvider.overrideWithValue(sync),
        loopExternalWalletIntroStoreProvider.overrideWithValue(intro),
      ],
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(WalletManagerScreen)),
    );
    container
        .read(loopSessionProvider.notifier)
        .acceptAuthenticated(
          PrivyAccountSummary(
            privyUserId: _principal,
            externalEvmCredentials: credentials,
          ),
        );
    await tester.pumpAndSettle();
    return wallet;
  }
}

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('wallets-add-action')));
  await tester.pumpAndSettle();
}

Future<void> _continueIntro(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('wallets-add-sheet-continue')),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('连接外部钱包 · the + entry', () {
    testWidgets('with no external wallet it explains once, then links', (
      tester,
    ) async {
      final harness = _Harness();
      final wallet = await harness.pump(tester, directory: _directory());
      final readsBefore = wallet.directoryReads;

      await _tapAdd(tester);

      expect(
        find.byKey(const ValueKey<String>('wallets-add-sheet')),
        findsOneWidget,
      );
      expect(find.text('连接外部钱包'), findsOneWidget);
      expect(find.textContaining('不能在 LOOP 内交易或领奖励'), findsOneWidget);
      expect(find.textContaining('LOOP 不会获取你的私钥'), findsOneWidget);
      expect(find.textContaining('大陆网络需要开 VPN'), findsWidgets);
      expect(find.text('所有绑定钱包的持仓都计入算力'), findsOneWidget);
      // The sheet no longer speaks of a future opening.
      expect(find.text('开放之后会发生什么'), findsNothing);
      expect(find.text('暂不支持绑定第二个钱包'), findsNothing);
      expect(harness.external.intents, isEmpty);

      await _continueIntro(tester);

      expect(harness.external.intents, <ExternalWalletCredentialIntent>[
        ExternalWalletCredentialIntent.link,
      ]);
      expect(harness.external.principals, <String?>[_principal]);
      expect(find.text('外部钱包已绑定'), findsOneWidget);
      expect(harness.sync.calls, 1);
      expect(wallet.directoryReads, greaterThan(readsBefore));
      expect(harness.intro.seen, isTrue);
      expect(harness.container.read(emailAuthProvider).errorMessage, isNull);
    });

    testWidgets('closing the note links nothing', (tester) async {
      final harness = _Harness();
      await harness.pump(tester, directory: _directory());

      await _tapAdd(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-add-sheet-close')),
      );
      await tester.pumpAndSettle();

      expect(harness.external.intents, isEmpty);
      expect(harness.intro.seen, isNull);
    });

    testWidgets('with two bound and the note already read it goes straight '
        'to the wallet', (tester) async {
      final harness = _Harness(introSeen: true);
      await harness.pump(tester, directory: _directory(externals: 2));

      await _tapAdd(tester);

      expect(
        find.byKey(const ValueKey<String>('wallets-add-sheet')),
        findsNothing,
      );
      expect(harness.external.intents, <ExternalWalletCredentialIntent>[
        ExternalWalletCredentialIntent.link,
      ]);
    });

    testWidgets('archived rows do not count toward the limit', (tester) async {
      final harness = _Harness(introSeen: true);
      await harness.pump(
        tester,
        directory: _directory(externals: 2, archived: 2),
      );

      await _tapAdd(tester);

      expect(harness.external.intents, hasLength(1));
    });

    testWidgets('with three bound it asks for an unbind first', (tester) async {
      final harness = _Harness(introSeen: true);
      await harness.pump(tester, directory: _directory(externals: 3));

      await _tapAdd(tester);

      expect(
        find.byKey(const ValueKey<String>('wallets-limit-sheet')),
        findsOneWidget,
      );
      expect(find.textContaining('最多绑定 3 个外部钱包，请先解绑一个'), findsOneWidget);
      expect(harness.external.intents, isEmpty);
    });

    testWidgets('the session credentials count when the list lags', (
      tester,
    ) async {
      final harness = _Harness(introSeen: true);
      await harness.pump(
        tester,
        directory: _directory(externals: 2),
        credentials: <PrivyExternalEvmCredentialSummary>[
          for (var i = 0; i < 3; i++)
            PrivyExternalEvmCredentialSummary(address: _externalAddress(i)),
        ],
      );

      await _tapAdd(tester);

      expect(
        find.byKey(const ValueKey<String>('wallets-limit-sheet')),
        findsOneWidget,
      );
      expect(harness.external.intents, isEmpty);
    });

    testWidgets('a server-named limit replaces the default of three', (
      tester,
    ) async {
      final harness = _Harness(introSeen: true);
      await harness.pump(tester, directory: _directory(externals: 2, limit: 2));

      await _tapAdd(tester);

      expect(find.textContaining('最多绑定 2 个外部钱包'), findsWidgets);
      expect(harness.external.intents, isEmpty);
    });
  });

  group('连接外部钱包 · failures', () {
    testWidgets('a wallet bound to another account says how to move it', (
      tester,
    ) async {
      final harness = _Harness(introSeen: true);
      harness.external.error = PrivyGatewayException(
        PrivySdkAuthGateway.siweLinkFailureMessage(
          'Wallet is already linked to another user',
        ),
      );
      await harness.pump(tester, directory: _directory());

      await _tapAdd(tester);

      expect(find.text(externalWalletLinkedElsewhereMessage), findsOneWidget);
      expect(harness.sync.calls, 0);
      // The sentence is handed to the toast, not left for another page.
      expect(harness.container.read(emailAuthProvider).errorMessage, isNull);
    });

    testWidgets('a Reown network failure keeps its own sentence', (
      tester,
    ) async {
      final harness = _Harness(introSeen: true);
      harness.external.error = const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.network,
        '钱包连接网络不可用，请稍后重试。',
      );
      await harness.pump(tester, directory: _directory());

      await _tapAdd(tester);

      expect(find.text('钱包连接网络不可用，请稍后重试。'), findsOneWidget);
    });

    for (final kind in <ExternalWalletConnectorFailure>[
      ExternalWalletConnectorFailure.cancelled,
      ExternalWalletConnectorFailure.rejected,
    ]) {
      testWidgets('a ${kind.name} signature is not an error', (tester) async {
        final harness = _Harness(introSeen: true);
        harness.external.error = ExternalWalletConnectorException(
          kind,
          '已拒绝钱包连接或签名请求。',
        );
        await harness.pump(tester, directory: _directory());

        await _tapAdd(tester);

        expect(find.text('已拒绝钱包连接或签名请求。'), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('wallets-link-error')),
          findsNothing,
        );
        expect(harness.sync.calls, 0);
      });
    }
  });

  group('解绑', () {
    testWidgets('an external row confirms, unlinks through Privy and '
        're-reads the list', (tester) async {
      final harness = _Harness();
      final wallet = await harness.pump(
        tester,
        directory: _directory(externals: 1),
        credentials: <PrivyExternalEvmCredentialSummary>[
          PrivyExternalEvmCredentialSummary(
            address: _externalAddress(0).toUpperCase().replaceFirst('0X', '0x'),
          ),
        ],
      );
      final readsBefore = wallet.directoryReads;

      await tester.tap(
        find.byKey(ValueKey<String>('wallet-row-${_externalId(0)}')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('wallets-external-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-unlink-action')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('解绑后这个钱包的持仓从下一小时起不再计入算力'), findsOneWidget);
      expect(harness.credential.unlinked, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-unlink-confirm')),
      );
      await tester.pumpAndSettle();

      // Privy's own spelling of the address is the one sent.
      expect(harness.credential.unlinked, <String>[
        _externalAddress(0).toUpperCase().replaceFirst('0X', '0x'),
      ]);
      expect(harness.credential.principals, <String>[_principal]);
      expect(find.text('已解绑外部钱包'), findsOneWidget);
      expect(harness.sync.calls, 1);
      expect(wallet.directoryReads, greaterThan(readsBefore));
      expect(
        harness.container
            .read(loopSessionProvider)
            .account
            ?.externalEvmCredentials,
        isEmpty,
      );
    });

    testWidgets('cancelling the confirmation unlinks nothing', (tester) async {
      final harness = _Harness();
      await harness.pump(tester, directory: _directory(externals: 1));

      await tester.tap(
        find.byKey(ValueKey<String>('wallet-row-${_externalId(0)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-unlink-action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-unlink-cancel')),
      );
      await tester.pumpAndSettle();

      expect(harness.credential.unlinked, isEmpty);
      expect(harness.sync.calls, 0);
    });

    testWidgets('a refused unlink says so and keeps the list', (tester) async {
      final harness = _Harness();
      harness.credential.unlinkError = PrivyGatewayException(
        PrivySdkAuthGateway.siweUnlinkFailureMessage('Network request failed'),
      );
      await harness.pump(tester, directory: _directory(externals: 1));

      await tester.tap(
        find.byKey(ValueKey<String>('wallet-row-${_externalId(0)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-unlink-action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-unlink-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('解绑没有完成，请检查网络后重试。'), findsOneWidget);
      expect(harness.sync.calls, 0);
    });

    testWidgets('an archived external row offers nothing', (tester) async {
      final harness = _Harness();
      await harness.pump(tester, directory: _directory(archived: 1));

      await tester.tap(
        find.byKey(ValueKey<String>('wallet-row-${_externalId(0)}')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('wallets-external-sheet')),
        findsNothing,
      );
    });
  });

  group('Privy error mapping', () {
    test('a wallet already linked elsewhere', () {
      for (final message in <String>[
        'Wallet is already linked to another user',
        'This account has already been linked to another user.',
        'linked_to_another_user',
        'User already exists',
      ]) {
        expect(
          PrivySdkAuthGateway.siweLinkFailureMessage(message),
          externalWalletLinkedElsewhereMessage,
          reason: message,
        );
      }
    });

    test('network and unknown link failures', () {
      expect(
        PrivySdkAuthGateway.siweLinkFailureMessage('Request timed out'),
        '钱包凭据提交失败，请检查网络后重试。',
      );
      expect(
        PrivySdkAuthGateway.siweLinkFailureMessage('Invalid signature'),
        '钱包绑定没有完成，请重试。',
      );
    });

    test('unlink failures', () {
      expect(
        PrivySdkAuthGateway.siweUnlinkFailureMessage(
          'Cannot unlink the last linked account',
        ),
        contains('唯一的登录方式'),
      );
      expect(
        PrivySdkAuthGateway.siweUnlinkFailureMessage('internal error'),
        '解绑没有完成，请稍后重试。',
      );
    });
  });

  group('wallet list codec · externalWalletLimit', () {
    test('absent reads as not said', () {
      final directory = DioLoopV2WalletApi.decodeDirectory(
        s5WalletDirectoryBody(),
      );
      expect(directory.externalWalletLimit, isNull);
    });

    test('a whole number is carried', () {
      final directory = DioLoopV2WalletApi.decodeDirectory(<String, Object?>{
        ...s5WalletDirectoryBody(),
        'externalWalletLimit': 3,
      });
      expect(directory.externalWalletLimit, 3);
    });

    test('a malformed limit is ignored, never fatal', () {
      for (final raw in <Object?>[null, -1, 51, '3', 2.5]) {
        final directory = DioLoopV2WalletApi.decodeDirectory(<String, Object?>{
          ...s5WalletDirectoryBody(),
          'externalWalletLimit': raw,
        });
        expect(directory.externalWalletLimit, isNull, reason: '$raw');
      }
    });
  });
}

class _SessionGateway implements PrivyAuthGateway {
  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<String> getCurrentAccessToken() async => 'access-token';

  @override
  Future<void> logout() async {}

  @override
  Future<PrivySessionSnapshot> restoreSession() async =>
      const PrivySessionSnapshot(PrivySessionKind.unauthenticated);

  @override
  Future<void> sendEmailCode(String email) async {}

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}

class _CredentialGateway implements PrivyCredentialGateway {
  final unlinked = <String>[];
  final principals = <String>[];
  Object? unlinkError;

  @override
  Future<String> generateSiweMessage(PrivySiweRequest request) =>
      throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> loginWithOAuth(
    PrivyOAuthLoginProvider provider,
  ) => throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) => throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> unlinkSiwe({
    required String address,
    required String expectedPrivyUserId,
  }) async {
    final failure = unlinkError;
    if (failure != null) throw failure;
    unlinked.add(address);
    principals.add(expectedPrivyUserId);
    return PrivyAccountSummary(privyUserId: expectedPrivyUserId);
  }
}

class _ExternalCredentialGateway implements ExternalWalletCredentialGateway {
  final intents = <ExternalWalletCredentialIntent>[];
  final principals = <String?>[];
  Object? error;

  @override
  Future<PrivyAccountSummary> authenticate({
    required BuildContext context,
    required ExternalWalletCredentialIntent intent,
    String? expectedPrivyUserId,
  }) async {
    intents.add(intent);
    principals.add(expectedPrivyUserId);
    final failure = error;
    if (failure != null) throw failure;
    return PrivyAccountSummary(
      privyUserId: expectedPrivyUserId ?? 'did:privy:login',
      externalEvmCredentials: <PrivyExternalEvmCredentialSummary>[
        PrivyExternalEvmCredentialSummary(address: _externalAddress(9)),
      ],
    );
  }
}

class _SyncGateway implements WalletInventorySyncGateway {
  int calls = 0;

  @override
  Future<bool> requestSync() async {
    calls += 1;
    return false;
  }
}
