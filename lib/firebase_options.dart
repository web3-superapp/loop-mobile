import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// The Firebase project LOOP's mobile clients belong to.
///
/// Derived by hand from the two files the Firebase console produced for
/// project `loop-d4746` — `android/app/google-services.json` (package
/// `com.cywd.loop`) and `ios/Runner/GoogleService-Info.plist` (bundle
/// `com.cywd.loop`) — and kept identical to what `flutterfire configure`
/// would have written. Both files are committed next to this one, so a
/// mismatch between the Dart values and the native ones is visible in a diff
/// rather than at runtime on a device.
///
/// None of these values is a secret. An `apiKey` here is a project
/// identifier: it authorises nothing on its own, and Firebase's own generated
/// files ship it in the application bundle. Service accounts, APNs `.p8` keys
/// and the FCM server key are the credentials, and none of them may ever
/// appear in this repository.
abstract final class DefaultFirebaseOptions {
  static const String projectId = 'loop-d4746';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPB1b1u7gf0omomAI4bHULxear14Ogrfs',
    appId: '1:225868941577:android:fe779e131119af7c64abd8',
    messagingSenderId: '225868941577',
    projectId: projectId,
    storageBucket: 'loop-d4746.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB-hoTeevMjvZrxy91WuRnU3FdJHmnbQUE',
    appId: '1:225868941577:ios:7d96d5ce4f5679a464abd8',
    messagingSenderId: '225868941577',
    projectId: projectId,
    storageBucket: 'loop-d4746.firebasestorage.app',
    iosBundleId: 'com.cywd.loop',
  );

  /// The options for the platform this build is running on, or `null`.
  ///
  /// LOOP registered two applications with Firebase and ships two platforms.
  /// Anywhere else — web, desktop, a test host — there is no application to
  /// initialise, and the answer is the absence of one rather than an
  /// exception the caller would have to catch to stay fail-closed.
  static FirebaseOptions? get currentPlatformOrNull {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  /// The `flutterfire configure` shape, for parity with generated code.
  ///
  /// Prefer [currentPlatformOrNull]: a thrown `UnsupportedError` at startup is
  /// a crash, and an unconfigured platform is a fact LOOP already knows how to
  /// report as "push is unavailable here".
  static FirebaseOptions get currentPlatform {
    final options = currentPlatformOrNull;
    if (options == null) {
      throw UnsupportedError(
        'LOOP registered Firebase applications for Android and iOS only.',
      );
    }
    return options;
  }
}
