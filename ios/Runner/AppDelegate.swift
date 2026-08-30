import Firebase
import FirebaseCore
import FirebaseMessaging
import Flutter
import NetworkExtension
import SystemConfiguration
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    AmplifyLivenessBootstrap.configureIfNeeded()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
        if let error = error {
          print("Notification permission request failed: \(error.localizedDescription)")
        } else {
          print(granted ? "Notification permission granted" : "Notification permission denied")
        }
      }
    }

    application.registerForRemoteNotifications()
    GeneratedPluginRegistrant.register(with: self)
    let launched =
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Channels need the FlutterViewController; register after super so the window exists.
    setupAppIconBadgeChannel()
    setupVpnDetectionChannel()
    return launched
  }

  private var didSetupAppIconBadgeChannel = false
  private var didSetupVpnDetectionChannel = false
  private var appIconBadgeChannelRetries = 0
  private var vpnDetectionChannelRetries = 0

  /// Syncs iOS springboard badge with Dart (clear on open/seen, match bell count).
  private func setupAppIconBadgeChannel() {
    if didSetupAppIconBadgeChannel { return }
    guard let controller = window?.rootViewController as? FlutterViewController else {
      appIconBadgeChannelRetries += 1
      if appIconBadgeChannelRetries > 20 { return }
      DispatchQueue.main.async { [weak self] in
        self?.setupAppIconBadgeChannel()
      }
      return
    }
    didSetupAppIconBadgeChannel = true

    let channel = FlutterMethodChannel(
      name: "ae.elrace.mobile/app_icon_badge",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setBadge" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let count = max(0, (args?["count"] as? Int) ?? 0)
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
          if let error = error {
            result(FlutterError(
              code: "badge",
              message: error.localizedDescription,
              details: nil
            ))
          } else {
            result(nil)
          }
        }
      } else {
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
      }
    }
  }

  /// VPN detection for Flutter security checks (App Store–safe, no Network Extension entitlement).
  /// Uses CFNetworkCopySystemProxySettings `__SCOPED__` — only active VPN tunnels appear there
  /// (avoids false positives from system utun interfaces used by iCloud / push).
  private func setupVpnDetectionChannel() {
    if didSetupVpnDetectionChannel { return }
    guard let controller = window?.rootViewController as? FlutterViewController else {
      vpnDetectionChannelRetries += 1
      if vpnDetectionChannelRetries > 20 { return }
      DispatchQueue.main.async { [weak self] in
        self?.setupVpnDetectionChannel()
      }
      return
    }
    didSetupVpnDetectionChannel = true
    VpnDetectionBridge.shared.register(with: controller)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    print("Registered for remote notifications")
    Messaging.messaging().token { _, error in
      if let error = error {
        print("Failed to fetch FCM token after APNs registration: \(error.localizedDescription)")
      } else {
        print("FCM token received")
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    completionHandler(.newData)
  }
}

/// Native VPN bridge: Settings VPN (NEVPNManager) + __SCOPED__ routing + live events.
private final class VpnDetectionBridge: NSObject, FlutterStreamHandler {
  static let shared = VpnDetectionBridge()

  private var eventSink: FlutterEventSink?
  private var vpnStatusObserver: NSObjectProtocol?
  private var foregroundObserver: NSObjectProtocol?
  private var pollTimer: Timer?
  private var lastEvaluatedVpnActive = false

  func register(with controller: FlutterViewController) {
    let methodChannel = FlutterMethodChannel(
      name: "ae.elrace.mobile/vpn_detection",
      binaryMessenger: controller.binaryMessenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "isVpnActive" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.evaluateVpnConnected { active in
        DispatchQueue.main.async {
          result(active)
        }
      }
    }

    let eventChannel = FlutterEventChannel(
      name: "ae.elrace.mobile/vpn_detection_events",
      binaryMessenger: controller.binaryMessenger
    )
    eventChannel.setStreamHandler(self)

    startMonitoring()
    evaluateVpnConnected { [weak self] active in
      self?.publishVpnStatus(active)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    events(lastEvaluatedVpnActive)
    startMonitoring()
    evaluateVpnConnected { [weak self] active in
      self?.publishVpnStatus(active)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopPolling()
    eventSink = nil
    return nil
  }

  private func startMonitoring() {
    if vpnStatusObserver == nil {
      vpnStatusObserver = NotificationCenter.default.addObserver(
        forName: .NEVPNStatusDidChange,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.reevaluateAndPublish()
      }
    }

    if foregroundObserver == nil {
      foregroundObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.reevaluateAndPublish()
      }
    }

    startPolling()
  }

  private func startPolling() {
    stopPolling()
    let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
      self?.reevaluateAndPublish()
    }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
  }

  private func stopPolling() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  private func reevaluateAndPublish() {
    evaluateVpnConnected { [weak self] active in
      self?.publishVpnStatus(active)
    }
  }

  private func publishVpnStatus(_ active: Bool) {
    let changed = active != lastEvaluatedVpnActive
    lastEvaluatedVpnActive = active
    guard eventSink != nil else { return }
    // Always re-push when VPN is active so mid-session Flutter can't miss it.
    if active || changed {
      DispatchQueue.main.async { [weak self] in
        self?.eventSink?(active)
      }
    }
  }

  private func evaluateVpnConnected(completion: @escaping (Bool) -> Void) {
    checkSettingsVpnActive { [weak self] settingsVpn in
      guard let self else {
        completion(false)
        return
      }
      completion(settingsVpn || self.checkScopedVPNInterfaces())
    }
  }

  /// Personal VPN toggled in Settings or Shortcuts.
  private func checkSettingsVpnActive(completion: @escaping (Bool) -> Void) {
    let manager = NEVPNManager.shared()
    manager.loadFromPreferences { error in
      if error != nil {
        completion(false)
        return
      }
      switch manager.connection.status {
      case .connected, .connecting, .reasserting:
        completion(true)
      default:
        completion(false)
      }
    }
  }

  private func checkScopedVPNInterfaces() -> Bool {
    guard let cfDict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
          let scoped = cfDict["__SCOPED__"] as? [String: Any]
    else {
      return false
    }

    for interface in scoped.keys {
      if isKnownNonVpnScopedInterface(interface.lowercased()) {
        continue
      }
      return true
    }
    return false
  }

  private func isKnownNonVpnScopedInterface(_ name: String) -> Bool {
    name.hasPrefix("en") ||
      name.hasPrefix("pdp_ip") ||
      name.hasPrefix("bridge") ||
      name.hasPrefix("ap") ||
      name.hasPrefix("awdl") ||
      name.hasPrefix("llw") ||
      name.hasPrefix("lo")
  }
}
