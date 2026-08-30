package ae.elrace.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val BATTERY_CHANNEL = "ae.elrace.mobile/battery_optimization"
    private val SYSTEM_UI_CHANNEL = "ae.elrace.mobile/system_ui"
    private val APP_ICON_BADGE_CHANNEL = "ae.elrace.mobile/app_icon_badge"
    private val PLAY_UPDATE_CHANNEL = "ae.elrace.mobile/play_update"
    private val VPN_DETECTION_CHANNEL = "ae.elrace.mobile/vpn_detection"
    private val VPN_DETECTION_EVENTS = "ae.elrace.mobile/vpn_detection_events"
    private val PLAY_UPDATE_REQUEST_CODE = 6317
    private lateinit var appUpdateManager: AppUpdateManager
    private var vpnNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var vpnEventSink: EventChannel.EventSink? = null
    private var lastVpnActive = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val vpnPollRunnable = object : Runnable {
        override fun run() {
            if (vpnEventSink != null) {
                notifyVpnStatusChanged()
                mainHandler.postDelayed(this, 3000)
            }
        }
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_DETECTION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isVpnActive" -> result.success(isVpnTransportActive())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_DETECTION_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    vpnEventSink = events
                    notifyVpnStatusChanged()
                    registerVpnNetworkCallback()
                    mainHandler.removeCallbacks(vpnPollRunnable)
                    mainHandler.postDelayed(vpnPollRunnable, 3000)
                }

                override fun onCancel(arguments: Any?) {
                    mainHandler.removeCallbacks(vpnPollRunnable)
                    unregisterVpnNetworkCallback()
                    vpnEventSink = null
                }
            })
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
        notifyVpnStatusChanged()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(vpnPollRunnable)
        unregisterVpnNetworkCallback()
        super.onDestroy()
    }

    /// True only when a VPN network is actively connected (not merely configured).
    private fun isVpnTransportActive(): Boolean {
        val connectivityManager =
            getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        for (network in connectivityManager.allNetworks) {
            val capabilities = connectivityManager.getNetworkCapabilities(network)
                ?: continue
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return true
            }
        }
        return false
    }

    private fun registerVpnNetworkCallback() {
        unregisterVpnNetworkCallback()
        val connectivityManager =
            getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = notifyVpnStatusChanged()
            override fun onLost(network: Network) = notifyVpnStatusChanged()
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) = notifyVpnStatusChanged()
        }
        vpnNetworkCallback = callback
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            connectivityManager.registerDefaultNetworkCallback(callback)
        } else {
            connectivityManager.registerNetworkCallback(
                NetworkRequest.Builder().build(),
                callback
            )
        }
    }

    private fun unregisterVpnNetworkCallback() {
        val callback = vpnNetworkCallback ?: return
        val connectivityManager =
            getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        try {
            connectivityManager.unregisterNetworkCallback(callback)
        } catch (_: Exception) {
            // Already unregistered.
        }
        vpnNetworkCallback = null
    }

    private fun notifyVpnStatusChanged() {
        mainHandler.post {
            val active = isVpnTransportActive()
            if (active == lastVpnActive) return@post
            lastVpnActive = active
            vpnEventSink?.success(active)
        }
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
