import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';

/// Feature-facing port for the MEME v2 project side (S135, decision 0138).
///
/// It covers the S125 Hooks routes and the one `launch2` read the project
/// side needs. The catalogue project itself (create, edit, submit, list) is
/// the existing `LaunchGateway`. No transport type, route literal or
/// idempotency detail crosses this boundary; every failure is a
/// [LoopChainException] carrying the server's `detailsSafe.reasonCode`.
abstract interface class Launch2CreatorGateway {
  LoopChainGatewayMode get mode;

  /// The latest Hooks draft, or `null` when none was saved.
  Future<Launch2HooksDraft?> loadConfig(String projectId);

  /// Appends one draft version under [expectedVersion] (`0` for the first).
  Future<Launch2HooksDraft> saveConfig({
    required String projectId,
    required int expectedVersion,
    required Launch2ConfigInput input,
  });

  Future<Launch2SigningRequest> loadSigningRequest({
    required String projectId,
    required String walletId,
  });

  /// Submits the signed request. One user action is one idempotency key; the
  /// key is replayed only while the outcome of that action is unresolved.
  Future<Launch2DeploymentJob> submitDeployment({
    required String projectId,
    required String walletId,
    required Launch2SigningRequest request,
    required String signature,
  });

  Future<Launch2DeploymentJob> loadDeployment({
    required String projectId,
    required String jobId,
  });

  /// The activated instance this project became, or `null` while the read
  /// model has not indexed it.
  Future<Launch2InstanceRef?> findInstance(String projectId);
}

/// Production default: every call fails closed.
final class UnavailableLaunch2CreatorGateway implements Launch2CreatorGateway {
  const UnavailableLaunch2CreatorGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<Launch2HooksDraft?> loadConfig(String projectId) => _unavailable();

  @override
  Future<Launch2HooksDraft> saveConfig({
    required String projectId,
    required int expectedVersion,
    required Launch2ConfigInput input,
  }) => _unavailable();

  @override
  Future<Launch2SigningRequest> loadSigningRequest({
    required String projectId,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2DeploymentJob> submitDeployment({
    required String projectId,
    required String walletId,
    required Launch2SigningRequest request,
    required String signature,
  }) => _unavailable();

  @override
  Future<Launch2DeploymentJob> loadDeployment({
    required String projectId,
    required String jobId,
  }) => _unavailable();

  @override
  Future<Launch2InstanceRef?> findInstance(String projectId) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launch2CreatorGatewayProvider = Provider<Launch2CreatorGateway>(
  (ref) => const UnavailableLaunch2CreatorGateway(),
);

/// The outcome of one EIP-712 signature.
final class Launch2TypedDataResult {
  const Launch2TypedDataResult.signed(String this.signature) : refusal = null;
  const Launch2TypedDataResult.refused(String this.refusal) : signature = null;

  /// `0x` + 130 hex characters.
  final String? signature;

  /// A stable, non-provider reason code.
  final String? refusal;

  bool get signed => signature != null;
}

/// The device's EIP-712 signer (Privy `eth_signTypedData_v4`).
///
/// A typed-data signature moves no funds and broadcasts nothing: the
/// executor deploys with it later. It still goes through the sign sheet, and
/// it is bound to the wallet the server built the request for.
abstract interface class Launch2TypedDataSigner {
  bool get available;

  /// Signs [typedData] with the embedded wallet whose address is
  /// [ownerAddress]. [chainReference] is the chain the domain must name.
  Future<Launch2TypedDataResult> sign({
    required String ownerAddress,
    required Map<String, Object?> typedData,
    required int chainReference,
  });
}

final class UnavailableLaunch2TypedDataSigner
    implements Launch2TypedDataSigner {
  const UnavailableLaunch2TypedDataSigner();

  @override
  bool get available => false;

  @override
  Future<Launch2TypedDataResult> sign({
    required String ownerAddress,
    required Map<String, Object?> typedData,
    required int chainReference,
  }) async => const Launch2TypedDataResult.refused('privy_wallet_unavailable');
}

/// Overridden by the composition root with the Privy signer.
final launch2TypedDataSignerProvider = Provider<Launch2TypedDataSigner>(
  (ref) => const UnavailableLaunch2TypedDataSigner(),
);
