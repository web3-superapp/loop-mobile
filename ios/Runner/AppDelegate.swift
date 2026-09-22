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

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
