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
        
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Configure notification service
        NotificationService.shared.configure()
        
        print("✅ AppDelegate: didFinishLaunchingWithOptions")
        return true
    }
    
    // MARK: - Remote Notification Registration
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNs device token received")
        
        // Pass device token to Firebase
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Notification Handling (Foreground)
    
    // Called when notification arrives while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        print("📬 Notification received in foreground: \(userInfo)")
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - Notification Tap Handling
    
    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        print("👆 Notification tapped: \(userInfo)")
        
        // Handle deep linking
        if let conversationId = NotificationService.shared.handleNotificationTap(userInfo: userInfo) {
            // Post notification for app to handle navigation
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenConversation"),
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }
        
        completionHandler()
    }
}

