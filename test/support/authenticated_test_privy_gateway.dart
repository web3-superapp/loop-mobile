import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

/// Test-only session seam for widget tests that exercise post-login routes.
class AuthenticatedTestPrivyGateway implements PrivyAuthGateway {
  const AuthenticatedTestPrivyGateway({this.walletAddress});

  final String? walletAddress;

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    return PrivySessionSnapshot(
      PrivySessionKind.authenticated,
      account: PrivyAccountSummary(
        privyUserId: 'did:privy:test-widget',
        wallet: walletAddress == null
            ? null
            : PrivyWalletSummary(address: walletAddress!),
      ),
    );
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) {
    throw UnsupportedError('Widget test gateway does not create wallets.');
  }

  @override
  Future<String> getCurrentAccessToken() async => 'test-access-token';

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailCode(String email) {
    throw UnsupportedError('Widget test gateway does not send OTPs.');
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw UnsupportedError('Widget test gateway does not verify OTPs.');
  }
}
