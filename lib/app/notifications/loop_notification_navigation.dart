import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';

/// How a tapped notification is opened (decision 0133).
enum LoopNotificationOpenMode {
  /// Replace the location: a tab, or a stack that is not the product yet.
  go,

  /// Lay the page over what the reader was looking at, so 返回 goes back to
  /// it — a notification is an interruption, not a new start.
  push,
}

/// Decides how [target] opens over the product the reader is on.
///
/// A tab is never pushed (StatefulShellRoute owns tab switches). Nor is
/// anything pushed over the account gates — splash, login, the ID and
/// security setup — because 返回 would then land on a gate the session has
/// already passed. Everywhere else the page is pushed.
LoopNotificationOpenMode loopNotificationOpenMode({
  required String target,
  required String? current,
}) {
  final targetPath = Uri.parse(target).path;
  if (LoopRouteManifest.isTabPath(targetPath)) {
    return LoopNotificationOpenMode.go;
  }
  if (current == null || current.isEmpty || current == '/') {
    return LoopNotificationOpenMode.go;
  }
  final currentPath = Uri.parse(current).path;
  final gates = LoopRouteManifest.forModule(LoopRouteModule.globalAccount)
      .map((entry) => entry.path);
  for (final gate in gates) {
    if (currentPath == gate || currentPath.startsWith('$gate/')) {
      return LoopNotificationOpenMode.go;
    }
  }
  return LoopNotificationOpenMode.push;
}

/// Opens [location] for a tapped notification on [router].
void loopOpenNotificationLocation(GoRouter router, String location) {
  final configuration = router.routerDelegate.currentConfiguration;
  final current = configuration.isEmpty ? null : configuration.uri.toString();
  switch (loopNotificationOpenMode(target: location, current: current)) {
    case LoopNotificationOpenMode.go:
      router.go(location);
    case LoopNotificationOpenMode.push:
      // The returned future completes when the page is popped; nothing
      // waits on a notification's page.
      router.push<void>(location).ignore();
  }
}
