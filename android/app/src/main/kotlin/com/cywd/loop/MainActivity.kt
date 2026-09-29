package com.cywd.loop

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.OnBackPressedCallback
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// `local_auth_android` shows the platform BiometricPrompt, which is a
// fragment and therefore needs a FragmentActivity host. FlutterFragmentActivity
// is Flutter's own drop-in for FlutterActivity and changes nothing else about
// how the engine is attached.
class MainActivity : FlutterFragmentActivity() {
    // Decision 0106: the system back gesture on LOOP's root page finishes this
    // Activity, and a finished Activity takes the voice room with it. While
    // the device holds a voice call, the gesture that has nothing left to pop
    // puts LOOP behind the home screen instead, as the home button would.
    //
    // It is registered before FlutterFragment's own callback, so it has the
    // lowest priority: every page Flutter can still pop is popped by Flutter.
    // Only a back Flutter hands on (its callback disabled at the root, or
    // `SystemNavigator.pop` routed back through the dispatcher) reaches it.
    private val voiceRoomBack = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            moveTaskToBack(true)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        onBackPressedDispatcher.addCallback(voiceRoomBack)
        ensureDefaultNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_ROOM_BACK_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setHoldsVoiceCall") {
                    voiceRoomBack.isEnabled = call.arguments == true
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    // Profile links (decision 0104) and voice-room links (decision 0105).
    // `flutter_deeplinking_enabled` is false so
    // Reown's wallet callback is delivered once; that also stops Flutter from
    // routing any other link. Only an https `/u/{id}` link is handed to the
    // router here — as the first route on a cold start, as a pushed route when
    // LOOP is already running. The router decides what the path means.
    // A `/c/{communityId}/room` link is handed over the same way.
    override fun getInitialRoute(): String? =
        profileLinkPath(intent) ?: super.getInitialRoute()

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val path = profileLinkPath(intent) ?: return
        flutterEngine?.navigationChannel?.pushRouteInformation(path)
    }

    private fun profileLinkPath(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val data = intent.data ?: return null
        if (data.scheme != "https") return null
        val path = data.path ?: return null
        return if (PROFILE_LINK_PATH.matches(path) || ROOM_LINK_PATH.matches(path)) path else null
    }

    // `default_notification_channel_id` in the manifest only tells Firebase
    // which channel to post into; it does not create it. Without this the OS
    // falls back to `fcm_fallback_notification_channel`, which shows up in
    // system settings as "Miscellaneous" and cannot be recognised — or muted —
    // by the person reading it. minSdk is 28, so the channel always applies.
    private fun ensureDefaultNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val id = getString(R.string.loop_notification_channel_id)
        if (manager.getNotificationChannel(id) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                id,
                getString(R.string.loop_notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = getString(R.string.loop_notification_channel_description)
            },
        )
    }

    private companion object {
        // Mirrored by `lib/integrations/device/voice_room_back_guard.dart`.
        const val VOICE_ROOM_BACK_CHANNEL = "com.cywd.loop/voice_room_back"

        val PROFILE_LINK_PATH = Regex("^/u/[A-Za-z0-9-]{1,32}/?$")

        // Voice-room links `/c/{communityId}/room` (decision 0105).
        val ROOM_LINK_PATH = Regex("^/c/[A-Za-z0-9_-]{1,64}/room/?$")
    }
}
