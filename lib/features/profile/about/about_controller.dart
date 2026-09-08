import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/profile/about/about_gateway.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';

/// `about` · public `GET /v2/meta/about`.
final class AboutController extends LoopChainReadController<LoopAbout> {
  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(aboutGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopAbout> fetch() => ref.read(aboutGatewayProvider).load();
}

final aboutControllerProvider =
    NotifierProvider<AboutController, LoopChainResourceState<LoopAbout>>(
      AboutController.new,
    );
