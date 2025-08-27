import Flutter
import UIKit
import UserNotifications
import AVFoundation
import Contacts

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if granted {
        print("Notification permission granted")
      } else {
        print("Notification permission denied")
      }
    }
    
    // Request microphone permission
    AVAudioSession.sharedInstance().requestRecordPermission { granted in
      if granted {
        print("Microphone permission granted")
      } else {
        print("Microphone permission denied")
      }
    }
    
    // Request contacts permission
    let contactStore = CNContactStore()
    contactStore.requestAccess(for: .contacts) { granted, error in
      if granted {
        print("Contacts permission granted")
      } else {
        print("Contacts permission denied: \(error?.localizedDescription ?? "Unknown error")")
      }
    }
    
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
