import UIKit
import Flutter
import flutter_local_notifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Il widget riapre l'app con lo schema dailyfox://. Consumiamo qui l'URL
  // restituendo true: senza gestirlo, nessun plugin lo consuma (home_widget lo
  // ignora perché privo del parametro `homeWidget`) e iOS lo tratta come non
  // gestito, re-istanziando il FlutterViewController dallo storyboard e
  // impilando una nuova home sopra quella corrente ad ogni riapertura.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "dailyfox" {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}