import 'package:flutter/services.dart';

/// The orientations LOOP is drawn in (decision 0128, S123 M13).
///
/// Every page is laid out for a phone held upright; on its side the floating
/// tab bar took a third of the screen. The App is held in portrait from
/// before its first frame, and the one page that is drawn sideways — the
/// full-screen chart — turns itself and comes back here when it is left.
const List<DeviceOrientation> loopAppOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
];

/// The full-screen chart's own orientations.
const List<DeviceOrientation> loopChartOrientations = <DeviceOrientation>[
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Holds the App in [loopAppOrientations].
Future<void> loopLockPortrait() =>
    SystemChrome.setPreferredOrientations(loopAppOrientations);
