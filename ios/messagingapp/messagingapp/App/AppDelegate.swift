//
//  AppDelegate.swift
//  messagingapp
//
//  Handles app lifecycle and notification callbacks
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - App Launch
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // DISABLED FOR TESTING: Push notifications disabled to allow device testing without APNs
        // Set notification center delegate
        // UNUserNotificationCenter.current().delegate = self
        
        // Configure notification service
        // NotificationService.shared.configure()
        
        // Phase 11: Register background tasks
        BackgroundSyncService.shared.registerBackgroundTasks()
        
        print("✅ AppDelegate: didFinishLaunchingWithOptions (Push notifications disabled)")
        return true
    }
    
    // MARK: - Background Tasks (Phase 11)
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 App entered background")
        BackgroundSyncService.shared.handleAppDidEnterBackground()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 App became active")
        BackgroundSyncService.shared.handleAppDidBecomeActive()
    }
    
    // MARK: - Remote Notification Registration
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // DISABLED FOR TESTING
        // print("✅ APNs device token received")
        // Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // DISABLED FOR TESTING
        // print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Notification Handling (Foreground)
    
    // Called when notification arrives while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // DISABLED FOR TESTING
        // let userInfo = notification.request.content.userInfo
        // print("📬 Notification received in foreground: \(userInfo)")
        completionHandler([])
    }
    
    // MARK: - Notification Tap Handling
    
    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // DISABLED FOR TESTING
        // let userInfo = response.notification.request.content.userInfo
        // print("👆 Notification tapped: \(userInfo)")
        // if let conversationId = NotificationService.shared.handleNotificationTap(userInfo: userInfo) {
        //     NotificationCenter.default.post(
        //         name: NSNotification.Name("OpenConversation"),
        //         object: nil,
        //         userInfo: ["conversationId": conversationId]
        //     )
        // }
        
        completionHandler()
    }
}

