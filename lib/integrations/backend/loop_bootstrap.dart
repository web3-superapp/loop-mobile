import 'package:flutter/foundation.dart';

@immutable
final class LoopBootstrapIdentity {
  const LoopBootstrapIdentity({
    required this.loopUserId,
    required this.streamUserId,
  });

  final String loopUserId;
  final String streamUserId;
}

/// Supplies a current Privy access token for one immediate backend request.
///
/// Implementations never expose or access a Privy refresh token. Calling this
/// method again is the only allowed response to one backend authentication
/// failure.
abstract interface class LoopBackendAccessTokenSource {
  Future<String> loadAccessToken();
}

abstract interface class LoopBootstrapRepository {
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken});
}
