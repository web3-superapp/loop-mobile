import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/perp/account/perp_account_controller.dart';
import 'package:loop_mobile/features/perp/perp_account_screens.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  testWidgets('explicit Preview keeps labelled fixtures and makes no request', (
    tester,
  ) async {
    final gateway = _Gateway();

    await tester.pumpWidget(
      _app(gateway: gateway, session: _SignedOutSession.new, preview: true),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('perp-preview-account')),
      findsOne,
    );
    expect(find.textContaining('开发预览'), findsOne);
    expect(find.text('ACCOUNT EQUITY · FIXTURE'), findsOne);
    expect(find.text('WATCH · FIXTURE'), findsOne);
    expect(gateway.events, isEmpty);
  });

  testWidgets('production requires an explicit two-step wallet bind', (
    tester,
  ) async {
    final gateway = _Gateway();

    await tester.pumpWidget(
      _app(gateway: gateway, session: _AuthenticatedSession.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Wallet binding required'), findsOne);
    expect(gateway.events, <String>['binding:get']);
    expect(find.textContaining('FIXTURE'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('perp-bind-wallet')));
    await tester.pumpAndSettle();
    expect(find.text('Bind this Privy wallet?'), findsOne);
    expect(find.textContaining('will freshly query Privy'), findsOne);
    expect(find.textContaining('is not selection authority'), findsOne);
    expect(
      find.textContaining('will be verified by the LOOP backend'),
      findsNothing,
    );
    expect(gateway.events, <String>['binding:get']);

    await tester.tap(find.byKey(const ValueKey<String>('perp-confirm-bind')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(gateway.events, <String>[
      'binding:get',
      'binding:put:0',
      'config:get',
      'account:get',
    ]);
    expect(find.byKey(const ValueKey<String>('perp-account-facts')), findsOne);
    expect(find.text(r'$1000.25'), findsNWidgets(2));
    expect(find.text('900.25 USDC'), findsOne);
    expect(find.text('Disabled'), findsOne);
    expect(find.text('Config expires'), findsOne);
    expect(find.text('Account expires'), findsOne);
    expect(find.text('Projection expires'), findsOne);
    expect(find.text('32.4%'), findsNothing);
    expect(find.textContaining('FIXTURE'), findsNothing);
  });

  testWidgets('wallet creation never silently performs wallet binding', (
    tester,
  ) async {
    final gateway = _Gateway();
    final privy = _PrivyGateway();

    await tester.pumpWidget(
      _app(gateway: gateway, session: _WalletlessSession.new, privy: privy),
    );
    await tester.pump();

    expect(find.text('Create a Privy wallet first'), findsOne);
    expect(gateway.events, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('perp-create-wallet')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(privy.createCalls, 1);
    expect(find.text('Wallet binding required'), findsOne);
    expect(gateway.events, <String>['binding:get']);
    expect(
      gateway.events.where((event) => event.startsWith('binding:put')),
      isEmpty,
    );
  });

  testWidgets('an open binding confirmation cannot cross an account rotation', (
    tester,
  ) async {
    final gateway = _Gateway();

    await tester.pumpWidget(
      _app(gateway: gateway, session: _MutableAuthenticatedSession.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('perp-bind-wallet')));
    await tester.pumpAndSettle();
    expect(find.text('Bind this Privy wallet?'), findsOne);

    final context = tester.element(find.byType(PerpAccountScreen));
    final container = ProviderScope.containerOf(context);
    container
        .read(loopSessionProvider.notifier)
        .acceptAuthenticated(
          const PrivyAccountSummary(
            privyUserId: 'did:privy:user-b',
            wallet: PrivyWalletSummary(
              address: '0x2222222222222222222222222222222222222222',
            ),
          ),
        );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('perp-confirm-bind')));
    await tester.pump();

    expect(
      gateway.events.where((event) => event.startsWith('binding:put')),
      isEmpty,
    );
    expect(
      find.textContaining('Identity, wallet, or binding changed'),
      findsOne,
    );
  });

  testWidgets('live account remains usable at narrow width and large text', (
    tester,
  ) async {
    final gateway = _Gateway(initiallyBound: true);

    await tester.pumpWidget(
      _app(
        gateway: gateway,
        session: _AuthenticatedSession.new,
        mediaQuery: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('perp-account-facts')), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume clears expired facts even when the timer did not fire', (
    tester,
  ) async {
    final gateway = _Gateway(initiallyBound: true);
    var currentTime = gateway.now;

    await tester.pumpWidget(
      _app(
        gateway: gateway,
        session: _AuthenticatedSession.new,
        clock: () => currentTime,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('perp-account-facts')), findsOne);

    currentTime = currentTime.add(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('perp-account-facts')),
      findsNothing,
    );
    expect(find.text('Account projection expired'), findsOne);
  });
}

Widget _app({
  required _Gateway gateway,
  required LoopSessionController Function() session,
  bool preview = false,
  PrivyAuthGateway? privy,
  MediaQueryData? mediaQuery,
  PerpAccountClock? clock,
}) {
  return ProviderScope(
    overrides: [
      developmentPreviewEnabledProvider.overrideWithValue(preview),
      loopSessionProvider.overrideWith(session),
      perpPrivateGatewayProvider.overrideWithValue(gateway),
      if (clock != null) perpAccountClockProvider.overrideWithValue(clock),
      if (privy != null) privyAuthGatewayProvider.overrideWithValue(privy),
    ],
    child: MaterialApp(
      theme: LoopTheme.dark,
      home: mediaQuery == null
          ? const PerpAccountScreen()
          : MediaQuery(data: mediaQuery, child: const PerpAccountScreen()),
    ),
  );
}

final class _Gateway implements PerpPrivateGateway {
  _Gateway({this.initiallyBound = false});

  final bool initiallyBound;
  final events = <String>[];
  late final DateTime now = DateTime.now().toUtc();

  @override
  PerpGatewayMode get mode => PerpGatewayMode.production;

  PerpWalletBinding get _unbound => PerpWalletBinding(
    state: PerpWalletBindingState.unbound,
    bindingVersion: '0',
    accountKind: null,
    lastVerifiedAt: null,
  );

  PerpWalletBinding get _bound => PerpWalletBinding(
    state: PerpWalletBindingState.bound,
    bindingVersion: '1',
    accountKind: PerpAccountKind.master,
    lastVerifiedAt: now,
  );

  PerpDataSource _source(PerpSourceDataset dataset) => PerpDataSource(
    dataset: dataset,
    fetchedAt: now.subtract(const Duration(milliseconds: 100)),
    expiresAt: now.add(
      dataset == PerpSourceDataset.config
          ? const Duration(seconds: 50)
          : const Duration(seconds: 2),
    ),
  );

  @override
  Future<PerpWalletBinding> getWalletBinding() async {
    events.add('binding:get');
    return initiallyBound ? _bound : _unbound;
  }

  @override
  Future<PerpWalletBinding> bindWallet({
    required String expectedBindingVersion,
  }) async {
    events.add('binding:put:$expectedBindingVersion');
    return _bound;
  }

  @override
  Future<PerpWalletBinding> unbindWallet({
    required String expectedBindingVersion,
  }) => throw UnsupportedError('not used');

  @override
  Future<PerpConfig> getConfig() async {
    events.add('config:get');
    return PerpConfig(
      scope: PerpScope(coins: PerpCoin.values),
      assets: const <PerpAssetConfig>[],
      fees: const PerpFees(
        makerRate: PerpDecimalFact.unavailable(),
        takerRate: PerpDecimalFact.unavailable(),
      ),
      capabilities: const PerpCapabilities(
        privateReadsAvailable: true,
        tradingMutationsEnabled: false,
      ),
      source: _source(PerpSourceDataset.config),
    );
  }

  @override
  Future<PerpAccount> getAccount() async {
    events.add('account:get');
    final summary = PerpMarginSummary(
      accountValue: Decimal.fromInt(1000),
      totalMarginUsed: Decimal.fromInt(100),
      totalNotionalPosition: Decimal.fromInt(500),
      totalRawUsd: Decimal.fromInt(1000),
    );
    return PerpAccount(
      marginSummary: PerpMarginSummary(
        accountValue: Decimal.parse('1000.25'),
        totalMarginUsed: Decimal.parse('100.00'),
        totalNotionalPosition: Decimal.parse('500.75'),
        totalRawUsd: Decimal.parse('1000.25'),
      ),
      crossMarginSummary: summary,
      withdrawable: Decimal.parse('900.25'),
      crossMaintenanceMarginUsed: null,
      source: _source(PerpSourceDataset.account),
    );
  }

  @override
  Future<PerpPage<PerpFill>> listFills({int? limit, String? cursor}) =>
      throw UnsupportedError('not used');

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    int? limit,
    String? cursor,
  }) => throw UnsupportedError('not used');

  @override
  Future<PerpPage<PerpOrder>> listOrders({int? limit, String? cursor}) =>
      throw UnsupportedError('not used');

  @override
  Future<PerpPage<PerpPosition>> listPositions({int? limit, String? cursor}) =>
      throw UnsupportedError('not used');
}

class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(
      privyUserId: 'did:privy:user-a',
      wallet: PrivyWalletSummary(
        address: '0x1111111111111111111111111111111111111111',
      ),
    ),
  );
}

class _WalletlessSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

class _MutableAuthenticatedSession extends _AuthenticatedSession {}

class _SignedOutSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.signedOut();
}

final class _PrivyGateway implements PrivyAuthGateway {
  var createCalls = 0;

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) async {
    createCalls += 1;
    return PrivyWalletCreationResult(
      privyUserId: expectedPrivyUserId,
      wallet: const PrivyWalletSummary(
        address: '0x2222222222222222222222222222222222222222',
      ),
    );
  }

  @override
  Future<String> getCurrentAccessToken() => throw UnsupportedError('not used');

  @override
  Future<void> logout() async {}

  @override
  Future<PrivySessionSnapshot> restoreSession() =>
      throw UnsupportedError('not used');

  @override
  Future<void> sendEmailCode(String email) =>
      throw UnsupportedError('not used');

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) => throw UnsupportedError('not used');

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}
