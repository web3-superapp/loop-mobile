import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/settings/settings_models.dart';

/// `settings` port. The write exists for the compare-and-set contract; the
/// page offers no editor because both values are fixed in this step.
abstract interface class AccountSettingsGateway {
  LoopChainGatewayMode get mode;

  Future<LoopAccountSettings> load();

  Future<LoopAccountSettings> replace({
    required int expectedVersion,
    required LoopAccountSettingsValues values,
  });
}

final class UnavailableAccountSettingsGateway
    implements AccountSettingsGateway {
  const UnavailableAccountSettingsGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopAccountSettings> load() => Future<LoopAccountSettings>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopAccountSettings> replace({
    required int expectedVersion,
    required LoopAccountSettingsValues values,
  }) => Future<LoopAccountSettings>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

final accountSettingsGatewayProvider = Provider<AccountSettingsGateway>(
  (ref) => const UnavailableAccountSettingsGateway(),
);
