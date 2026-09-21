package com.cywd.loop

import io.flutter.embedding.android.FlutterFragmentActivity

// `local_auth_android` shows the platform BiometricPrompt, which is a
// fragment and therefore needs a FragmentActivity host. FlutterFragmentActivity
// is Flutter's own drop-in for FlutterActivity and changes nothing else about
// how the engine is attached.
class MainActivity : FlutterFragmentActivity()
