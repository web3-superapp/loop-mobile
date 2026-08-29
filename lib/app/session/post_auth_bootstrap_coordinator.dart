import 'dart:async';

import 'package:loop_mobile/app/session/loop_session_controller.dart';

/// Starts one non-blocking LOOP bootstrap after each newly accepted verified
/// Privy login. Authentication never depends on backend availability.
class PostAuthBootstrapCoordinator {
  PostAuthBootstrapCoordinator(this._request);

  final Future<void> Function() _request;
  String? _requestedPrincipal;

  void onSessionChanged(LoopSessionState? previous, LoopSessionState next) {
    if (next.mode == LoopSessionMode.signedOut ||
        next.mode == LoopSessionMode.preview) {
      _requestedPrincipal = null;
      return;
    }
    final nextPrincipal = _verifiedPrincipal(next);
    if (nextPrincipal == null) return;
    final previousPrincipal = previous == null
        ? null
        : _verifiedPrincipal(previous);
    if (previousPrincipal == nextPrincipal ||
        _requestedPrincipal == nextPrincipal) {
      return;
    }
    _requestedPrincipal = nextPrincipal;
    unawaited(_request().catchError((_) {}));
  }

  String? _verifiedPrincipal(LoopSessionState session) {
    if (!session.canUseProviderBackedFeatures) return null;
    final value = session.account?.privyUserId.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
