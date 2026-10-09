import Flutter
import UIKit

// APNs registration is deliberately absent from this file.
//
// `firebase_messaging` registers for remote notifications itself and reads
// the APNs token back through UIApplicationDelegate method swizzling
// (`FirebaseAppDelegateProxyEnabled` is left at its default `YES`). Adding a
// second registration here would give the app two owners of the same
// delegate callbacks and the token would be handed to whichever one ran
// last. The entitlement (`aps-environment`) and the background mode
// (`remote-notification`) are what this target actually has to declare.
//
// CallKit and PushKit stay out: LOOP has no VoIP push.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Decision 0133: Info.plist declares portrait only — the launch and the
  // App are upright, as on Android. The full-screen chart is the one page
  // drawn sideways (decision 0118); UIKit refuses (and throws
  // UIApplicationInvalidInterfaceOrientation on) a view-controller request
  // that shares no orientation with the application's, so the application's
  // set is widened here at run time. Which orientation a page actually gets
  // is still decided in Dart by `SystemChrome.setPreferredOrientations`:
  // portrait from before the first frame (`loopLockPortrait`), landscape only
  // while `chart-full` is open.
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return [.portrait, .landscapeLeft, .landscapeRight]
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
