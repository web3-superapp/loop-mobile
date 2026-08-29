import 'package:flutter/foundation.dart';

enum LoopStreamTokenProduct {
  chat('chat'),
  video('video');

  const LoopStreamTokenProduct(this.wireName);

  final String wireName;
}

@immutable
final class LoopStreamTokenCredential {
  const LoopStreamTokenCredential({
    required this.token,
    required this.expiresAt,
  });

  final String token;
  final DateTime expiresAt;
}

/// Issues a short-lived Stream user token through the LOOP backend.
///
/// Implementations receive a current Privy access token for one request only.
/// They never persist either credential and never accept a client-selected
/// Stream identity in the HTTP request body or query.
abstract interface class LoopStreamTokenRepository {
  Future<LoopStreamTokenCredential> issue({
    required LoopStreamTokenProduct product,
    required String expectedStreamUserId,
    required String accessToken,
  });
}
