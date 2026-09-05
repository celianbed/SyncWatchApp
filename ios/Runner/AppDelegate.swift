import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    observerPastille()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// La pastille de l'icône porte le nombre de notifications non lues au moment
  /// du push ; une fois l'app ouverte, elle a fait son travail. On l'efface à
  /// chaque activation. On observe la notification système plutôt que de
  /// surcharger le cycle de vie, que Flutter gère lui-même (scènes).
  private func observerPastille() {
    let effacer: (Notification) -> Void = { _ in
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(0)
      } else {
        UIApplication.shared.applicationIconBadgeNumber = 0
      }
    }
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil, queue: .main, using: effacer)
    NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification,
      object: nil, queue: .main, using: effacer)
  }
}
