import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';

/// `about` port. The resource is public: no access token is involved.
abstract interface class AboutGateway {
  LoopChainGatewayMode get mode;

  Future<LoopAbout> load();
}

final class UnavailableAboutGateway implements AboutGateway {
  const UnavailableAboutGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopAbout> load() => Future<LoopAbout>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

final aboutGatewayProvider = Provider<AboutGateway>(
  (ref) => const UnavailableAboutGateway(),
);
