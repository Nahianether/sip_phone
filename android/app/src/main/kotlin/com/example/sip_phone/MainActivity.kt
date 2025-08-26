package com.example.sip_phone

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "background_app_launcher"
    private val NOTIFICATION_CHANNEL_ID = "incoming_call_channel"
    private val FULL_SCREEN_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Create notification channel for full-screen intents
        createNotificationChannel()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchAppFromBackground" -> {
                    val success = launchAppFromBackground()
                    result.success(success)
                }
                "requestOverlayPermission" -> {
                    val success = requestOverlayPermission()
                    result.success(success)
                }
                "hasOverlayPermission" -> {
                    val hasPermission = hasOverlayPermission()
                    result.success(hasPermission)
                }
                "showOnLockScreen" -> {
                    val success = showOnLockScreen()
                    result.success(success)
                }
                "launchFullScreenIntent" -> {
                    val callerName = call.argument<String>("caller_name") ?: "Unknown Caller"
                    val callerId = call.argument<String>("caller_id") ?: "Unknown"
                    val callUuid = call.argument<String>("call_uuid") ?: System.currentTimeMillis().toString()
                    val success = launchFullScreenIntent(callerName, callerId, callUuid)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchAppFromBackground(): Boolean {
        return try {
            // Bring the app to foreground
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
            
            // Turn screen on and show over lock screen
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                )
            }
            
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun requestOverlayPermission(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
                false // Permission not granted yet
            } else {
                true // Permission already granted
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun showOnLockScreen(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Channel for incoming call notifications"
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun launchFullScreenIntent(callerName: String, callerId: String, callUuid: String): Boolean {
        return try {
            // Create full-screen intent that bypasses notification tap requirement
            val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("incoming_call", true)
                putExtra("caller_name", callerName)
                putExtra("caller_id", callerId)
                putExtra("call_uuid", callUuid)
            }

            val fullScreenPendingIntent = PendingIntent.getActivity(
                this,
                FULL_SCREEN_REQUEST_CODE,
                fullScreenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Create high-priority notification with full-screen intent
            val notificationBuilder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle("Incoming call from $callerName")
                .setContentText("Touch to answer")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(fullScreenPendingIntent, true) // This is the key!
                .setOngoing(true)
                .setAutoCancel(false)

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(callUuid.hashCode(), notificationBuilder.build())

            // Also directly start the activity
            startActivity(fullScreenIntent)
            showOnLockScreen()

            println("🔥 Android: Full-screen intent launched for $callerName")
            true
        } catch (e: Exception) {
            e.printStackTrace()
            println("🔥 Android: Error launching full-screen intent: ${e.message}")
            false
        }
    }
}
