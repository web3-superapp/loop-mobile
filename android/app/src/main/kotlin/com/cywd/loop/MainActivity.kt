package com.cywd.loop

import android.app.NotificationChannel
import android.app.NotificationManager
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
}
