package ae.elrace.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val BATTERY_CHANNEL = "ae.elrace.mobile/battery_optimization"
    private val SYSTEM_UI_CHANNEL = "ae.elrace.mobile/system_ui"
    private val APP_ICON_BADGE_CHANNEL = "ae.elrace.mobile/app_icon_badge"
    private val PLAY_UPDATE_CHANNEL = "ae.elrace.mobile/play_update"
    private val PLAY_UPDATE_REQUEST_CODE = 6317
    private lateinit var appUpdateManager: AppUpdateManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimizationIgnored" -> {
                        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                        val isIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            powerManager.isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true // Below Android M, no battery optimization
                        }
                        result.success(isIgnored)
                    }
                    "requestBatteryOptimization" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // System UI channel: hide only navigation bar with edge-swipe behavior
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_UI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hideNavigationBar" -> {
                        hideNavigationBarOnly()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Launcher badge channel (parity with iOS). Android badges are OEM-
        // specific; we acknowledge so Dart does not throw MissingPluginException.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_ICON_BADGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBadge" -> result.success(null)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAY_UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startImmediateUpdateIfAvailable" -> {
                        startImmediateUpdateIfAvailable(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        appUpdateManager = AppUpdateManagerFactory.create(this)

        // Draw app content behind system bars (edge-to-edge)
        // This prevents layout shift/lag when navigation bar appears
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Hide navigation bar immediately on launch
        hideNavigationBarOnly()
        
        // Create notification channels for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager: NotificationManager =
                getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            
            // High importance channel for general notifications
            val highChannel = NotificationChannel(
                "high_importance_channel",
                "High Importance Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "This channel is used for important notifications"
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(highChannel)
            
            // Prayer Adhan channel with maximum importance
            val adhanChannel = NotificationChannel(
                "prayer_adhan_channel_v2",
                "Prayer Adhan",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for prayer adhan times"
                enableLights(true)
                enableVibration(true)
                val soundUri = Uri.parse("android.resource://$packageName/raw/athan")
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(soundUri, audioAttributes)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(adhanChannel)
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Important: update the activity's intent
        // Flutter will handle the notification through its listeners
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideNavigationBarOnly()
        }
    }

    override fun onResume() {
        super.onResume()
        resumeImmediateUpdateIfNeeded()
    }

    private fun startImmediateUpdateIfAvailable(result: MethodChannel.Result) {
        if (!::appUpdateManager.isInitialized) {
            appUpdateManager = AppUpdateManagerFactory.create(this)
        }

        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { appUpdateInfo ->
                val updateAvailable =
                    appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                val immediateAllowed =
                    appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)

                if (!updateAvailable || !immediateAllowed) {
                    result.success(false)
                    return@addOnSuccessListener
                }

                try {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        this,
                        AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE),
                        PLAY_UPDATE_REQUEST_CODE
                    )
                    result.success(true)
                } catch (error: Exception) {
                    result.error(
                        "PLAY_UPDATE_START_FAILED",
                        error.localizedMessage,
                        null
                    )
                }
            }
            .addOnFailureListener { error ->
                result.error(
                    "PLAY_UPDATE_CHECK_FAILED",
                    error.localizedMessage,
                    null
                )
            }
    }

    private fun resumeImmediateUpdateIfNeeded() {
        if (!::appUpdateManager.isInitialized) return

        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { appUpdateInfo ->
                if (appUpdateInfo.updateAvailability() ==
                    UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                ) {
                    try {
                        appUpdateManager.startUpdateFlowForResult(
                            appUpdateInfo,
                            this,
                            AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE),
                            PLAY_UPDATE_REQUEST_CODE
                        )
                    } catch (_: Exception) {
                        // If Play cannot resume, Dart/backend force-update gate remains active.
                    }
                }
            }
    }

    /**
     * Hide only the navigation bar (bottom) while keeping the status bar (top) visible.
     * Uses BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE so the nav bar only appears
     * when the user swipes from the very bottom edge, and auto-hides after.
     */
    private fun hideNavigationBarOnly() {
        val decorView = window.decorView
        val controller = WindowInsetsControllerCompat(window, decorView)
        controller.hide(WindowInsetsCompat.Type.navigationBars())
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }
}
