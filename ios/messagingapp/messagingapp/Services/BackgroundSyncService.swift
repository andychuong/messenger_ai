//
//  BackgroundSyncService.swift
//  messagingapp
//
//  Phase 11: Offline Support & Sync
//  Manages background sync using BGTaskScheduler
//

import Foundation
import BackgroundTasks
import FirebaseAuth

/// Service responsible for scheduling and managing background sync tasks
class BackgroundSyncService {
    /// Shared singleton instance
    static let shared = BackgroundSyncService()
    
    /// Background task identifier
    private let backgroundTaskIdentifier = "com.messagingapp.backgroundSync"
    
    /// Minimum time between syncs (15 minutes)
    private let minimumSyncInterval: TimeInterval = 15 * 60
    
    /// Flag to track if tasks have been registered
    private var isRegistered = false
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register background tasks (only once)
    func registerBackgroundTasks() {
        // Prevent duplicate registration
        guard !isRegistered else {
            print("🔄 BackgroundSync: Tasks already registered, skipping")
            return
        }
        
        // Register background refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
        
        isRegistered = true
        print("🔄 BackgroundSync: Registered background tasks")
    }
    
    // MARK: - Scheduling
    
    /// Schedule next background sync
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        
        // Schedule to run after minimum interval
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumSyncInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔄 BackgroundSync: Scheduled next background sync")
        } catch {
            print("🔄 BackgroundSync: Failed to schedule background sync: \(error)")
        }
    }
    
    /// Cancel scheduled background sync
    func cancelBackgroundSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        print("🔄 BackgroundSync: Cancelled background sync")
    }
    
    // MARK: - Handling
    
    /// Handle background sync task
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        print("🔄 BackgroundSync: Starting background sync")
        
        // Schedule next sync before performing current one
        scheduleBackgroundSync()
        
        // Create a task to perform sync
        Task {
            // Check if user is authenticated
            guard Auth.auth().currentUser != nil else {
                print("🔄 BackgroundSync: No authenticated user, skipping")
                task.setTaskCompleted(success: true)
                return
            }
            
            // Perform incremental sync
            await SyncService.shared.performIncrementalSync()
            
            // Mark task as completed
            task.setTaskCompleted(success: true)
            print("🔄 BackgroundSync: Completed background sync")
        }
        
        // Set expiration handler
        task.expirationHandler = {
            print("🔄 BackgroundSync: Task expired before completion")
            // Clean up any ongoing operations
        }
    }
    
    // MARK: - Manual Trigger (for testing)
    
    /// Manually trigger a background sync (useful for testing)
    func triggerManualSync() async {
        print("🔄 BackgroundSync: Manually triggering sync")
        await SyncService.shared.performIncrementalSync()
    }
}

// MARK: - App Lifecycle Integration
extension BackgroundSyncService {
    /// Call this when app enters background
    func handleAppDidEnterBackground() {
        scheduleBackgroundSync()
    }
    
    /// Call this when app becomes active
    func handleAppDidBecomeActive() {
        // Sync is already handled by SyncService observing app lifecycle
        // No additional action needed here
    }
}

