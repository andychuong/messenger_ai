//
//  PresenceService.swift
//  messagingapp
//
//  Manages user online/offline status with proper lifecycle handling
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit
import Combine

@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()
    
    private let db = Firestore.firestore()
    private var heartbeatTimer: Timer?
    private var appStateObserver: NSObjectProtocol?
    
    private init() {}
    
    // MARK: - Start Presence Monitoring
    
    func startMonitoring() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ PresenceService: Cannot start monitoring, no user authenticated")
            return
        }
        
        print("🟢 PresenceService: Starting monitoring for user: \(userId)")
        
        // Set initial status to online
        Task {
            await setStatus(.online, userId: userId)
        }
        
        // Start heartbeat (update lastSeen every 30 seconds while app is active)
        startHeartbeat(userId: userId)
        
        // Monitor app state changes
        setupAppStateObservers(userId: userId)
    }
    
    // MARK: - Stop Presence Monitoring
    
    func stopMonitoring() {
        print("🔴 PresenceService: Stopping monitoring")
        stopHeartbeat()
        removeAppStateObservers()
    }
    
    // MARK: - Set Status
    
    func setStatus(_ status: User.UserStatus, userId: String) async {
        do {
            try await db.collection(User.collectionName)
                .document(userId)
                .updateData([
                    "status": status.rawValue,
                    "lastSeen": Timestamp(date: Date())
                ])
            print("✅ Presence updated to: \(status.rawValue)")
        } catch {
            print("❌ Failed to update presence: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Heartbeat (Keep lastSeen Updated)
    
    private func startHeartbeat(userId: String) {
        stopHeartbeat() // Clear any existing timer
        
        // Update lastSeen every 30 seconds while app is active
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Only update if user is still authenticated and app is active
                guard Auth.auth().currentUser?.uid == userId,
                      UIApplication.shared.applicationState == .active else {
                    return
                }
                
                // Just update lastSeen, keep status as online
                try? await self.db.collection(User.collectionName)
                    .document(userId)
                    .updateData([
                        "lastSeen": Timestamp(date: Date())
                    ])
            }
        }
        
        // Ensure timer runs in common run loop modes
        if let timer = heartbeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    // MARK: - App State Observers
    
    private func setupAppStateObservers(userId: String) {
        removeAppStateObservers()
        
        print("📱 PresenceService: Setting up app state observers")
        
        // App will resign active (going to background)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔴 PresenceService: App will resign active")
            Task { @MainActor [weak self] in
                await self?.setStatus(.offline, userId: userId)
                self?.stopHeartbeat()
            }
        }
        
        // App did become active (coming to foreground)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🟢 PresenceService: App did become active")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.setStatus(.online, userId: userId)
                self.startHeartbeat(userId: userId)
            }
        }
        
        // App will terminate (force quit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⚫️ PresenceService: App will terminate")
            Task { @MainActor [weak self] in
                await self?.setStatus(.offline, userId: userId)
            }
        }
    }
    
    private func removeAppStateObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
}

