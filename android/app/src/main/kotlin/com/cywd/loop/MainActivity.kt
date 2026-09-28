package com.cywd.loop

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// `local_auth_android` shows the platform BiometricPrompt, which is a
// fragment and therefore needs a FragmentActivity host. FlutterFragmentActivity
// is Flutter's own drop-in for FlutterActivity and changes nothing else about
// how the engine is attached.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureDefaultNotificationChannel()
    }

    // Profile links (decision 0104). `flutter_deeplinking_enabled` is false so
    // Reown's wallet callback is delivered once; that also stops Flutter from
    // routing any other link. Only an https `/u/{id}` link is handed to the
    // router here — as the first route on a cold start, as a pushed route when
    // LOOP is already running. The router decides what the path means.
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
        return if (PROFILE_LINK_PATH.matches(path)) path else null
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
        val PROFILE_LINK_PATH = Regex("^/u/[A-Za-z0-9-]{1,32}/?$")
    }
}
