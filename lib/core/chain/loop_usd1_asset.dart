/// The canonical CAIP `assetId` of USD1 on the primary chain.
///
/// Wallet Send, Swap and approvals are bound to the primary chain
/// (decision 0062), so this is the only USD1 a wallet intent can carry. The
/// address is World Liberty Financial USD on BNB Smart Chain, confirmed in
/// LOOP docs/24 §7.4; it is written the way loop-api's `assetIdForAddress`
/// writes it (chain id, a colon, the lower-case address).
///
/// A symbol is not an identity (AGENTS rule 25): any token may call itself
/// `USD1`, so the large-amount step-up reads USD1 only by this id
/// (decision 0158).
library;

import 'package:loop_mobile/core/chain/loop_chain_ids.dart';

const String loopPrimaryUsd1AssetId =
    '$loopPrimaryChainId:0x8d0d000ee44948fc98c9b98a4fa4921476f08b0d';

/// Whether [assetId] is USD1 on the primary chain. The address half is
/// compared without case, as the server may publish either.
bool loopIsUsd1AssetId(String assetId) =>
    assetId.toLowerCase() == loopPrimaryUsd1AssetId;
