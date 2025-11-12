package pl.a2ti.galeriakazimierz

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Log package name for debugging
        android.util.Log.d("MainActivity", "Package name: ${packageName}")
        android.util.Log.d("MainActivity", "Application ID: ${applicationContext.packageName}")
        
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "fcm_default_channel"
            val channelName = "Default Notifications"
            val channelDescription = "Default notification channel for Firebase Cloud Messaging"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
            android.util.Log.d("MainActivity", "Notification channel '$channelId' created with importance $importance")
        } else {
            android.util.Log.d("MainActivity", "Notification channels not supported (API < 26)")
        }
    }
}
