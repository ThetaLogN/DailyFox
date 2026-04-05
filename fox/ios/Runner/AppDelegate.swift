// AppDelegate.swift
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

    // Registra il MethodChannel per aggiornare il widget
    let controller = window?.rootViewController as! FlutterViewController
    let widgetChannel = FlutterMethodChannel(
      name: "com.giorgiomartucci.DailyFox.FoxWidget",
      binaryMessenger: controller.binaryMessenger
    )

    widgetChannel.setMethodCallHandler { call, result in
    if call.method == "updateWidget" {
        if let args = call.arguments as? [String: Any],
           let rating = args["rating"] as? Int {
            let userDefaults = UserDefaults(suiteName: "group.foxApp")
            userDefaults?.set(rating, forKey: "rating")
            userDefaults?.synchronize()
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        result(nil)
    }
}

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}