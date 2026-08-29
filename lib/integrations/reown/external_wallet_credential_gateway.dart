import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/reown/reown_external_wallet_connector.dart';

enum ExternalWalletCredentialIntent { login, link }

/// Combines an ephemeral external-wallet proof with Privy's identity API.
/// Reown never becomes an identity source or a LOOP transaction signer.
abstract interface class ExternalWalletCredentialGateway {
  Future<PrivyAccountSummary> authenticate({
    required BuildContext context,
    required ExternalWalletCredentialIntent intent,
    String? expectedPrivyUserId,
  });
}

final externalWalletCredentialGatewayProvider =
    Provider<ExternalWalletCredentialGateway>((ref) {
      return PrivyExternalWalletCredentialGateway(
        ref.watch(externalWalletConnectorProvider),
        ref.watch(privyCredentialGatewayProvider),
      );
    });

class PrivyExternalWalletCredentialGateway
    implements ExternalWalletCredentialGateway {
  const PrivyExternalWalletCredentialGateway(this._connector, this._privy);

  final ExternalWalletConnector _connector;
  final PrivyCredentialGateway _privy;

  @override
  Future<PrivyAccountSummary> authenticate({
    required BuildContext context,
    required ExternalWalletCredentialIntent intent,
    String? expectedPrivyUserId,
  }) async {
    if (intent == ExternalWalletCredentialIntent.link &&
        (expectedPrivyUserId == null ||
            expectedPrivyUserId.isEmpty ||
            expectedPrivyUserId != expectedPrivyUserId.trim())) {
      throw const PrivyGatewayException('缺少当前 Privy 账号，钱包未绑定。');
    }

    var messageRequested = false;
    ExternalWalletIdentity? generatedIdentity;
    PrivySiweRequest? generatedRequest;
    String? generatedMessage;
    final proof = await _connector.connectAndSign(
      context: context,
      createMessage: (identity) async {
        if (messageRequested) {
          throw const ExternalWalletConnectorException(
            ExternalWalletConnectorFailure.invalidResponse,
            '钱包返回了重复的登录请求，请重新连接。',
          );
        }
        messageRequested = true;
        final request = _requestFor(identity);
        final message = await _privy.generateSiweMessage(request);
        generatedIdentity = identity;
        generatedRequest = request;
        generatedMessage = message;
        return message;
      },
    );
    final identity = generatedIdentity;
    final request = generatedRequest;
    final message = generatedMessage;
    if (identity == null ||
        request == null ||
        message == null ||
        !_sameIdentity(identity, proof.identity) ||
        proof.message != message ||
        !ExternalWalletProtocol.isSignature(proof.signature)) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.invalidResponse,
        '钱包返回的地址、消息或签名与本次登录请求不匹配。',
      );
    }

    return switch (intent) {
      ExternalWalletCredentialIntent.login => _privy.loginWithSiwe(
        request: request,
        message: message,
        signature: proof.signature,
      ),
      ExternalWalletCredentialIntent.link => _privy.linkWithSiwe(
        request: request,
        message: message,
        signature: proof.signature,
        expectedPrivyUserId: expectedPrivyUserId!,
      ),
    };
  }

  PrivySiweRequest _requestFor(ExternalWalletIdentity identity) =>
      PrivySiweRequest(
        appDomain: Uri.parse(AppConfig.reownMetadataUrl).host,
        appUri: AppConfig.reownMetadataUrl,
        chainId: identity.chainId,
        walletAddress: identity.address,
        walletClientType: identity.walletClientType,
      );

  bool _sameIdentity(
    ExternalWalletIdentity expected,
    ExternalWalletIdentity actual,
  ) =>
      expected.address == actual.address &&
      expected.chainId == actual.chainId &&
      expected.walletClientType == actual.walletClientType &&
      expected.walletLabel == actual.walletLabel;
}
