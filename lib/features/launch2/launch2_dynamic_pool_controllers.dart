import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';

LoopChainGatewayMode _dynamicMode(Ref ref) => ref.watch(
  launch2DynamicPoolGatewayProvider.select((gateway) => gateway.mode),
);

/// Which Hook an instance's official pool carries (decisions 0157 / 0159).
///
/// `unavailable` (no adapter) and `notFound` (a server without the route)
/// are answers, not failures: both are OfficialTax. Any other failure
/// leaves the block failed; while the kind was never read the page draws
/// the S146 panel and asks again on its next read.
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
    // Decision 0159: once the server said LoopDynamic, no later failure turns
    // the page back into the OfficialTax panel; a closed capability is
    // 「外盘暂不可用」 (§3.12: a 503 for a LoopDynamic instance, any reason).
    final known = state.value;
    final dynamicKnown = known != null && known is! Launch2OfficialTaxPool;
    try {
      return await ref
          .read(launch2DynamicPoolGatewayProvider)
          .loadPoolKind(instanceId);
    } on LoopChainException catch (failure) {
      if (dynamicKnown) {
        if (failure.kind == LoopChainFailureKind.unavailable) {
          return Launch2LoopDynamicUnavailable(
            failure.reasonCode ?? 'CAPABILITY_UNAVAILABLE',
          );
        }
        rethrow;
      }
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

/// What `dynamic-pool` said about [instanceId], or `null` while it said
/// nothing yet (not asked, the adapter absent, a failed read). Call from
/// `build`; it starts the first read itself.
Launch2PoolKind? launch2PoolKindOf(WidgetRef ref, String instanceId) {
  final provider = launch2PoolKindControllerProvider(instanceId);
  final state = ref.watch(provider);
  if (state.mode == LoopChainGatewayMode.unavailable) return null;
  launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
  return state.value;
}

/// Which wallet's rounds of which instance (`walletId` is required).
typedef Launch2DynamicRewardsKey = ({String instanceId, String walletId});

/// 外盘奖励 · `GET …/dynamic-pool/rewards?walletId=`.
final class Launch2DynamicRewardsController
    extends LoopChainReadController<Launch2DynamicRewards> {
  Launch2DynamicRewardsController(this.key);

  final Launch2DynamicRewardsKey key;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _dynamicMode(ref);

  @override
  Future<Launch2DynamicRewards> fetch() => ref
      .read(launch2DynamicPoolGatewayProvider)
      .loadRewards(instanceId: key.instanceId, walletId: key.walletId);
}

final launch2DynamicRewardsControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2DynamicRewardsController,
      LoopChainResourceState<Launch2DynamicRewards>,
      Launch2DynamicRewardsKey
    >(Launch2DynamicRewardsController.new);
