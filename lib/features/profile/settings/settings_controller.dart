import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/settings/settings_models.dart';

/// `settings` · `GET /v2/settings`.
///
/// The page is read-only in this step, so there is no editing command: both
/// account values are fixed constants published with the resource.
final class AccountSettingsController
    extends LoopChainReadController<LoopAccountSettings> {
  @override
  LoopChainGatewayMode watchMode() => ref.watch(
    accountSettingsGatewayProvider.select((gateway) => gateway.mode),
  );

  @override
  Future<LoopAccountSettings> fetch() =>
      ref.read(accountSettingsGatewayProvider).load();
}

final accountSettingsControllerProvider =
    NotifierProvider<
      AccountSettingsController,
      LoopChainResourceState<LoopAccountSettings>
    >(AccountSettingsController.new);
