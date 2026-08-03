import Firebase
import FirebaseCore
import FirebaseMessaging
import Flutter
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
    setupAppIconBadgeChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var didSetupAppIconBadgeChannel = false
  private var appIconBadgeChannelRetries = 0

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
