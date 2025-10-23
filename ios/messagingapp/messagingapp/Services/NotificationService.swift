//
//  NotificationService.swift
//  messagingapp
//
//  Handles push notification registration and FCM token management
//

import Foundation
import Combine
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications

@MainActor
class NotificationService: NSObject, ObservableObject {
    @Published var fcmToken: String?
    @Published var notificationPermissionGranted = false
    
    private let db = Firestore.firestore()
    
    // Singleton instance
    static let shared = NotificationService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Notification Permission
    
    func requestPermission() async -> Bool {
        // DISABLED FOR TESTING: Push notifications disabled
        print("⚠️ Push notifications disabled - permission request skipped")
        return false
        
        // do {
        //     let center = UNUserNotificationCenter.current()
        //     let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        //     
        //     await MainActor.run {
        //         self.notificationPermissionGranted = granted
        //     }
        //     
        //     if granted {
        //         print("✅ Notification permission granted")
        //         await MainActor.run {
        //             UIApplication.shared.registerForRemoteNotifications()
        //         }
        //     } else {
        //         print("❌ Notification permission denied")
        //     }
        //     
        //     return granted
        // } catch {
        //     print("❌ Error requesting notification permission: \(error)")
        //     return false
        // }
    }
    
    // MARK: - Configure FCM
    
    func configure() {
        // DISABLED FOR TESTING: Push notifications disabled
        print("⚠️ Push notifications disabled - FCM configuration skipped")
        
        // Messaging.messaging().delegate = self
        // Task {
        //     await getFCMToken()
        // }
    }
    
    // MARK: - Get FCM Token
    
    func getFCMToken() async {
        // DISABLED FOR TESTING: Push notifications disabled
        print("⚠️ Push notifications disabled - FCM token request skipped")
        
        // do {
        //     let token = try await Messaging.messaging().token()
        //     await MainActor.run {
        //         self.fcmToken = token
        //         print("✅ FCM Token received: \(token)")
        //     }
        // } catch {
        //     print("❌ Error getting FCM token: \(error)")
        // }
    }
    
    // MARK: - Save Token to Firestore
    
    func saveTokenToFirestore(userId: String) async {
        guard let token = fcmToken else {
            print("⚠️ No FCM token to save")
            return
        }
        
        do {
            try await db.collection("users")
                .document(userId)
                .updateData([
                    "fcmToken": token
                ])
            print("✅ FCM token saved to Firestore for user: \(userId)")
        } catch {
            print("❌ Error saving FCM token to Firestore: \(error)")
        }
    }
    
    // MARK: - Remove Token from Firestore (on logout)
    
    func removeTokenFromFirestore(userId: String) async {
        do {
            try await db.collection("users")
                .document(userId)
                .updateData([
                    "fcmToken": FieldValue.delete()
                ])
            print("✅ FCM token removed from Firestore for user: \(userId)")
        } catch {
            print("❌ Error removing FCM token from Firestore: \(error)")
        }
    }
    
    // MARK: - Handle Notification Tap (Deep Linking)
    
    func handleNotificationTap(userInfo: [AnyHashable: Any]) -> String? {
        // Extract conversationId from notification payload
        if let conversationId = userInfo["conversationId"] as? String {
            print("📱 Opening conversation: \(conversationId)")
            return conversationId
        }
        return nil
    }
}

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 Firebase registration token received: \(String(describing: fcmToken))")
        
        Task { @MainActor in
            self.fcmToken = fcmToken
            
            // If user is logged in, save token immediately
            if let userId = AuthService.shared?.currentUser?.id {
                await self.saveTokenToFirestore(userId: userId)
            }
        }
    }
}

