import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_share.dart';
import 'package:loop_mobile/features/community/community_link.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';

/// What one scanned QR payload means to LOOP (decision 0113, S109b §3.2).
///
/// Text rules only: the scanner page, the photo-library path and the tests
/// read one definition. A payload is never fetched, never opened in a
/// browser and never executed; it either names a LOOP page or it is shown
/// back to the reader as text.
@immutable
sealed class LoopScanResult {
  const LoopScanResult();
}

/// Something LOOP opens: a location and, for the send flow, its typed state.
sealed class LoopScanDestination extends LoopScanResult {
  const LoopScanDestination();

  String get location;
  Object? get extra => null;
}

/// `/u/{loopId}` or a bare `LOOP-XXXXXXXX`: that account's profile page.
final class LoopScanUser extends LoopScanDestination {
  const LoopScanUser(this.loopId);

  final String loopId;

  @override
  String get location => userProfileLoopIdLocation(loopId);
}

/// `/c/{communityId}`: the community's record.
final class LoopScanCommunity extends LoopScanDestination {
  const LoopScanCommunity(this.communityId);

  final String communityId;

  @override
  String get location => communityProfileLocation(communityId);
}

/// `/c/{communityId}/room`: the community's record, asked to open its room.
final class LoopScanRoom extends LoopScanDestination {
  const LoopScanRoom(this.communityId);

  final String communityId;

  @override
  String get location => voiceRoomLinkLocation(communityId);
}

/// A wallet address: the send flow, with the recipient filled in. The
/// address is a prefill only — the server's preflight still checks it, and
/// the reader still picks the asset and the amount.
final class LoopScanAddress extends LoopScanDestination {
  const LoopScanAddress(this.address);

  final String address;

  @override
  String get location => '/wallet/send';

  @override
  Object? get extra => SendRecipientPrefill(address);
}

/// Anything else. The page says 不是 LOOP 二维码 and shows the text.
final class LoopScanUnknown extends LoopScanResult {
  const LoopScanUnknown(this.text);

  final String text;
}

final RegExp _address = RegExp(r'^0x[0-9a-fA-F]{40}$');

/// `ethereum:0x…` or `ethereum:0x…@56` — the plain EIP-681 form LOOP's own
/// receive page draws. A request that names a function (`/transfer?…`) or
/// any parameter is not read as an address: in a token transfer the address
/// after `ethereum:` is the token contract, not the person being paid.
final RegExp _eip681 = RegExp(
  r'^ethereum:(?:pay-)?(0x[0-9a-fA-F]{40})(?:@(\d+))?$',
);

/// The chains LOOP sends on: BNB Smart Chain and its testnet.
const Set<String> _sendChains = <String>{'56', '97'};

LoopScanResult loopScanResultFor(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return LoopScanUnknown(raw);
  final uri = Uri.tryParse(text);
  if (uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty) {
    final path = uri.path;
    final loopId = loopIdFromLinkPath(path);
    if (loopId != null) return LoopScanUser(loopId);
    final room = communityIdFromRoomLinkPath(path);
    if (room != null) return LoopScanRoom(room);
    final community = communityIdFromLinkPath(path);
    if (community != null) return LoopScanCommunity(community);
    return LoopScanUnknown(text);
  }
  final loopId = loopIdFromText(text);
  if (loopId != null && loopId.length == text.length) {
    return LoopScanUser(loopId);
  }
  if (_address.hasMatch(text)) return LoopScanAddress(text);
  final request = _eip681.firstMatch(text);
  if (request != null) {
    final chain = request.group(2);
    if (chain == null || _sendChains.contains(chain)) {
      return LoopScanAddress(request.group(1)!);
    }
  }
  return LoopScanUnknown(text);
}
