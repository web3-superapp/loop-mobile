import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_mfa_gateway.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// The EIP-712 exit of the MEME v2 project side (S135, decision 0138).
///
/// One `eth_signTypedData_v4` through the embedded wallet whose address the
/// server bound the request to. It signs, it never broadcasts: the platform
/// executor deploys with the signature later. The typed data reaches the
/// wallet as the server sent it, with one canonical addition — see
/// [launch2TypedDataJson].
final class PrivyLaunch2TypedDataSigner implements Launch2TypedDataSigner {
  const PrivyLaunch2TypedDataSigner(this._user);

  /// The user Privy reports for the current session, read fresh for every
  /// signature so a signed-out session can never sign.
  final PrivyUser? Function() _user;

  static final RegExp _signature = RegExp(r'^0x[0-9a-fA-F]{130}$');

  @override
  bool get available {
    final wallets = _user()?.embeddedEthereumWallets;
    return wallets != null && wallets.isNotEmpty;
  }

  @override
  Future<Launch2TypedDataResult> sign({
    required String ownerAddress,
    required Map<String, Object?> typedData,
    required int chainReference,
  }) async {
    // The chain comes first: the domain must name the chain the Factory was
    // published on, and nothing else.
    final domain = typedData['domain'];
    if (domain is! Map || domain['chainId'] != chainReference) {
      return const Launch2TypedDataResult.refused('privy_chain_mismatch');
    }
    final String json;
    try {
      json = launch2TypedDataJson(typedData);
    } on PrivySigningException catch (error) {
      return Launch2TypedDataResult.refused(error.code);
    }
    final user = _user();
    if (user == null) {
      return const Launch2TypedDataResult.refused('privy_session_required');
    }
    EmbeddedEthereumWallet? match;
    for (final wallet in user.embeddedEthereumWallets) {
      if (wallet.address.toLowerCase() == ownerAddress.toLowerCase()) {
        match = wallet;
        break;
      }
    }
    if (match == null) {
      return const Launch2TypedDataResult.refused('privy_wallet_mismatch');
    }
    final result = await match.provider.request(
      EthereumRpcRequest.ethSignTypedDataV4(match.address, json),
    );
    switch (result) {
      case Success<EthereumRpcResponse>(value: final response):
        final signature = response.data.trim();
        if (!_signature.hasMatch(signature)) {
          return const Launch2TypedDataResult.refused(
            'privy_signature_unreadable',
          );
        }
        return Launch2TypedDataResult.signed(signature);
      case Failure<EthereumRpcResponse>(error: final error):
        // A typed-data signature never leaves the device on its own, so an
        // unmapped failure is a refusal, not an unknown outcome.
        final code = privyWalletFailureCode(error.message);
        return Launch2TypedDataResult.refused(
          code == 'privy_broadcast_rejected'
              ? 'privy_signature_rejected'
              : 'privy_signature_failed',
        );
    }
  }
}

/// The `eth_signTypedData_v4` parameter.
///
/// The server's `types` names `LaunchRequest` only. EIP-712 defines the
/// domain type by the domain's own fields, and viem / ethers derive it the
/// same way, but some signers hash an absent `EIP712Domain` as an empty
/// struct — a different domain separator and a signature the Factory would
/// refuse. So when `EIP712Domain` is absent it is added, listing exactly the
/// domain fields present, in the order EIP-712 fixes (`name`, `version`,
/// `chainId`, `verifyingContract`, `salt`). The hash of the typed data does
/// not change; no other key is touched.
String launch2TypedDataJson(Map<String, Object?> typedData) {
  final types = typedData['types'];
  final domain = typedData['domain'];
  if (types is! Map || domain is! Map) {
    throw const PrivySigningException('privy_payload_unencodable');
  }
  final payload = Map<String, Object?>.of(typedData);
  if (!types.containsKey('EIP712Domain')) {
    const order = <(String, String)>[
      ('name', 'string'),
      ('version', 'string'),
      ('chainId', 'uint256'),
      ('verifyingContract', 'address'),
      ('salt', 'bytes32'),
    ];
    for (final key in domain.keys) {
      if (!order.any((field) => field.$1 == key)) {
        throw const PrivySigningException('privy_payload_unencodable');
      }
    }
    payload['types'] = <String, Object?>{
      'EIP712Domain': <Map<String, String>>[
        for (final (name, type) in order)
          if (domain.containsKey(name))
            <String, String>{'name': name, 'type': type},
      ],
      ...types.cast<String, Object?>(),
    };
  }
  try {
    return jsonEncode(payload);
  } on JsonUnsupportedObjectError {
    throw const PrivySigningException('privy_payload_unencodable');
  }
}

/// The production typed-data signer, or the fail-closed default when Privy
/// is not configured.
final privyLaunch2TypedDataSignerProvider = Provider<Launch2TypedDataSigner>((
  ref,
) {
  if (!ref.watch(appConfigProvider).canInitializePrivy) {
    return const UnavailableLaunch2TypedDataSigner();
  }
  final gateway = ref.watch(privyAuthGatewayProvider);
  if (gateway is! PrivySdkMfaAccount) {
    return const UnavailableLaunch2TypedDataSigner();
  }
  final account = gateway as PrivySdkMfaAccount;
  return PrivyLaunch2TypedDataSigner(() => account.mfaUser);
});
