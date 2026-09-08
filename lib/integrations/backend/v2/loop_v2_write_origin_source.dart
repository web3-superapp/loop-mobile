import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';

/// Resolves the optional `X-Loop-Platform` / `X-Loop-Device-ID` annotation an
/// S5 write may carry.
///
/// The device id lives in the same journal the session module owns, so this
/// source reads it rather than minting a second installation identity. It is
/// resolved once and cached; a failure simply omits the optional headers
/// instead of failing the write.
final class LoopV2WriteOriginSource {
  LoopV2WriteOriginSource(this._platform, this._store);

  final LoopV2Platform _platform;
  final LoopV2SessionJournalStore _store;
  Future<LoopV2WriteOrigin?>? _resolution;

  Future<LoopV2WriteOrigin?> resolve() =>
      _resolution ??= _resolve().catchError((Object _) => null);

  Future<LoopV2WriteOrigin?> _resolve() async {
    final deviceId = await _store.loadOrCreateDeviceId();
    return LoopV2WriteOrigin.tryCreate(
      platform: _platform.wireName,
      deviceId: deviceId,
    );
  }
}
