import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';

/// Resolves the current LOOP session id for `X-Loop-Session-ID`.
///
/// The value lives in the session module's own owner journal, so this source
/// reads it rather than minting a second identity. It is **not** a credential:
/// `GET /v2/devices` uses it only to mark the current row, and a device
/// command uses it to name the caller's own session.
///
/// It is deliberately not cached: a re-bootstrap replaces the active session
/// for the same principal, and a stale id would mark the wrong device.
final class LoopV2SessionIdSource {
  LoopV2SessionIdSource({
    required String principalKey,
    required LoopV2SessionJournalStore store,
  }) : _ownerPartition = LoopV2OwnerPartition.fromPrincipal(principalKey),
       // ignore: prefer_initializing_formals
       _store = store;

  final String _ownerPartition;
  final LoopV2SessionJournalStore _store;

  /// `null` when no active session is recorded or the journal cannot be read.
  /// The caller then omits the header instead of failing the request.
  Future<String?> resolve() async {
    try {
      final journal = await _store.readOwnerJournal(_ownerPartition);
      return journal?.activeSession?.sessionId;
    } catch (_) {
      return null;
    }
  }

  /// The installation device id used by a device command header set.
  Future<String?> resolveDeviceId() async {
    try {
      return await _store.loadOrCreateDeviceId();
    } catch (_) {
      return null;
    }
  }
}
