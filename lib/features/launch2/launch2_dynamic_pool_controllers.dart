import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';

LoopChainGatewayMode _dynamicMode(Ref ref) => ref.watch(
  launch2DynamicPoolGatewayProvider.select((gateway) => gateway.mode),
);

/// Which Hook an instance's official pool carries (decision 0157).
///
/// `unavailable` and `notFound` are answers, not failures: both are
/// OfficialTax. Any other failure leaves the block failed, which the page
/// also draws as OfficialTax (the S146 panel) and asks again on its next
/// read.
final class Launch2PoolKindController
    extends LoopChainReadController<Launch2PoolKind> {
  Launch2PoolKindController(this.instanceId);

  final String instanceId;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _dynamicMode(ref);

  @override
  Future<Launch2PoolKind> fetch() async {
    try {
      return await ref
          .read(launch2DynamicPoolGatewayProvider)
          .loadPoolKind(instanceId);
    } on LoopChainException catch (failure) {
      if (failure.kind == LoopChainFailureKind.unavailable ||
          failure.kind == LoopChainFailureKind.notFound) {
        return const Launch2OfficialTaxPool();
      }
      rethrow;
    }
  }
}

final launch2PoolKindControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2PoolKindController,
      LoopChainResourceState<Launch2PoolKind>,
      String
    >(Launch2PoolKindController.new);

/// The LoopDynamic state of [instanceId], or `null` while it is not known to
/// be LoopDynamic (OfficialTax, not asked yet, the adapter absent, a failed
/// read). Call from `build`; it starts the first read itself.
Launch2DynamicPoolState? launch2DynamicPoolOf(
  WidgetRef ref,
  String instanceId,
) {
  final provider = launch2PoolKindControllerProvider(instanceId);
  final state = ref.watch(provider);
  if (state.mode == LoopChainGatewayMode.unavailable) return null;
  launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
  final kind = state.value;
  return kind is Launch2LoopDynamicPool ? kind.state : null;
}

/// 外盘奖励 · `GET …/dynamic-pool/rewards`.
final class Launch2DynamicRewardsController
    extends LoopChainReadController<Launch2DynamicRewards> {
  Launch2DynamicRewardsController(this.instanceId);

  final String instanceId;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _dynamicMode(ref);

  @override
  Future<Launch2DynamicRewards> fetch() =>
      ref.read(launch2DynamicPoolGatewayProvider).loadRewards(instanceId);
}

final launch2DynamicRewardsControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2DynamicRewardsController,
      LoopChainResourceState<Launch2DynamicRewards>,
      String
    >(Launch2DynamicRewardsController.new);
