import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';

/// One credential-free client for public Hyperliquid Testnet facts.
///
/// Spot discovery and bounded candle history share this connection policy.
/// The client rejects credentials, another origin, and redirects before a
/// request reaches the network.
final hyperliquidPublicDioProvider = Provider<Dio>((ref) {
  final dio = LoopDioFactory.createCredentialFreePublic(
    origin: Uri.https('api.hyperliquid-testnet.xyz', '/'),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
