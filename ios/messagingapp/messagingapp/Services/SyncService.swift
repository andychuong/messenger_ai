//
//  SyncService.swift
//  messagingapp
//
//  Phase 11: Offline Support & Sync
//  Manages data synchronization between local and remote data
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Service responsible for synchronizing data between local cache and Firestore
@MainActor
class SyncService: ObservableObject {
    /// Shared singleton instance
    static let shared = SyncService()
    
    /// Is sync currently in progress?
    @Published private(set) var isSyncing: Bool = false
    
    /// Last sync timestamp
    @Published private(set) var lastSyncTime: Date?
    
    /// Firebase Firestore instance
    private let db = Firestore.firestore()
    
    /// User defaults key for last sync time
    private let lastSyncKey = "com.messagingapp.lastSyncTime"
    
    /// Network monitor
    private let networkMonitor = NetworkMonitor.shared
    
    /// Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadLastSyncTime()
        observeAppLifecycle()
    }
    
    // MARK: - Main Sync
    
    /// Perform a full sync of all data
    func performFullSync() async {
        guard !isSyncing else {
            print("🔄 SyncService: Sync already in progress, skipping")
            return
        }
        
        guard networkMonitor.isConnected else {
            print("🔄 SyncService: Offline, skipping sync")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🔄 SyncService: No authenticated user, skipping sync")
            return
        }
        
        isSyncing = true
        print("🔄 SyncService: Starting full sync for user \(userId)")
        
        // Sync in priority order
        await syncConversations(userId: userId)
        await syncMessages(userId: userId)
        await syncReadReceipts(userId: userId)
        await syncFriendships(userId: userId)
        
        // Process any queued messages
        await MessageQueueService.shared.processQueue()
        
        // Update last sync time
        updateLastSyncTime()
        
        print("🔄 SyncService: Full sync completed successfully")
        
        isSyncing = false
    }
    
    /// Perform an incremental sync (only fetch updates since last sync)
    func performIncrementalSync() async {
        guard !isSyncing else {
            print("🔄 SyncService: Sync already in progress, skipping")
            return
        }
        
        guard networkMonitor.isConnected else {
            print("🔄 SyncService: Offline, skipping sync")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🔄 SyncService: No authenticated user, skipping sync")
            return
        }
        
        guard let lastSync = lastSyncTime else {
            // If no last sync time, perform full sync
            await performFullSync()
            return
        }
        
        isSyncing = true
        print("🔄 SyncService: Starting incremental sync since \(lastSync)")
        
        // Only fetch data modified since last sync
        await syncConversationsSince(userId: userId, since: lastSync)
        await syncMessagesSince(userId: userId, since: lastSync)
        await syncReadReceiptsSince(userId: userId, since: lastSync)
        
        // Process any queued messages
        await MessageQueueService.shared.processQueue()
        
        // Update last sync time
        updateLastSyncTime()
        
        print("🔄 SyncService: Incremental sync completed successfully")
        
        isSyncing = false
    }
    
    // MARK: - Sync Conversations
    
    /// Sync all conversations
    private func syncConversations(userId: String) async {
        print("🔄 SyncService: Syncing conversations")
        
        do {
            // Query conversations where user is a participant
            let snapshot = try await db.collection("conversations")
                .whereField("participants", arrayContains: userId)
                .order(by: "lastMessageTime", descending: true)
                .limit(to: 50) // Limit to recent 50 conversations
                .getDocuments()
            
            print("🔄 SyncService: Fetched \(snapshot.documents.count) conversations")
            
            // Conversations are automatically cached by Firestore
            // Additional processing can be done here if needed
        } catch {
            print("🔄 SyncService: Failed to sync conversations: \(error)")
        }
    }
    
    /// Sync conversations modified since a specific date
    private func syncConversationsSince(userId: String, since: Date) async {
        print("🔄 SyncService: Syncing conversations since \(since)")
        
        do {
            let snapshot = try await db.collection("conversations")
                .whereField("participants", arrayContains: userId)
                .whereField("lastMessageTime", isGreaterThan: Timestamp(date: since))
                .order(by: "lastMessageTime", descending: true)
                .getDocuments()
            
            print("🔄 SyncService: Fetched \(snapshot.documents.count) updated conversations")
        } catch {
            print("🔄 SyncService: Failed to sync conversations: \(error)")
        }
    }
    
    // MARK: - Sync Messages
    
    /// Sync recent messages for all conversations
    private func syncMessages(userId: String) async {
        print("🔄 SyncService: Syncing messages")
        
        do {
            // First get user's conversations
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participants", arrayContains: userId)
                .limit(to: 10) // Sync messages for 10 most recent conversations
                .getDocuments()
            
            // For each conversation, fetch recent messages
            for conversationDoc in conversationsSnapshot.documents {
                let conversationId = conversationDoc.documentID
                
                // Fetch last 50 messages for each conversation
                _ = try await db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 50)
                    .getDocuments()
            }
            
            print("🔄 SyncService: Synced messages for \(conversationsSnapshot.documents.count) conversations")
        } catch {
            print("🔄 SyncService: Failed to sync messages: \(error)")
        }
    }
    
    /// Sync messages modified since a specific date
    private func syncMessagesSince(userId: String, since: Date) async {
        print("🔄 SyncService: Syncing messages since \(since)")
        
        do {
            // Get user's conversations
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participants", arrayContains: userId)
                .limit(to: 20)
                .getDocuments()
            
            // For each conversation, fetch messages since last sync
            for conversationDoc in conversationsSnapshot.documents {
                let conversationId = conversationDoc.documentID
                
                _ = try await db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .whereField("timestamp", isGreaterThan: Timestamp(date: since))
                    .order(by: "timestamp", descending: true)
                    .getDocuments()
            }
            
            print("🔄 SyncService: Synced updated messages")
        } catch {
            print("🔄 SyncService: Failed to sync messages: \(error)")
        }
    }
    
    // MARK: - Sync Read Receipts
    
    /// Sync read receipts
    private func syncReadReceipts(userId: String) async {
        print("🔄 SyncService: Syncing read receipts")
        
        // Read receipts are automatically synced with messages
        // This is a placeholder for any additional receipt processing
    }
    
    /// Sync read receipts since a specific date
    private func syncReadReceiptsSince(userId: String, since: Date) async {
        print("🔄 SyncService: Syncing read receipts since \(since)")
        
        // Read receipts are automatically synced with messages
    }
    
    // MARK: - Sync Friendships
    
    /// Sync friendships
    private func syncFriendships(userId: String) async {
        print("🔄 SyncService: Syncing friendships")
        
        do {
            // Fetch friendships where user is involved
            _ = try await db.collection("friendships")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("userId1", isEqualTo: userId),
                    Filter.whereField("userId2", isEqualTo: userId)
                ]))
                .getDocuments()
            
            print("🔄 SyncService: Synced friendships")
        } catch {
            print("🔄 SyncService: Failed to sync friendships: \(error)")
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Handle sync conflicts (server always wins)
    private func resolveConflict<T>(local: T, remote: T, lastModified: Date) -> T {
        // Phase 11: Server-wins strategy
        // In a more sophisticated implementation, we could use timestamps
        // or version numbers to determine which data is newer
        print("🔄 SyncService: Conflict detected, using server data (server-wins)")
        return remote
    }
    
    // MARK: - Background Sync
    
    /// Schedule background sync
    func scheduleBackgroundSync() {
        // TODO: Implement using BGTaskScheduler
        print("🔄 SyncService: Background sync scheduling (to be implemented)")
    }
    
    // MARK: - App Lifecycle
    
    /// Observe app lifecycle events
    private func observeAppLifecycle() {
        // Sync when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.performIncrementalSync()
                }
            }
            .store(in: &cancellables)
        
        // Listen for network status changes
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                if let isConnected = notification.userInfo?["isConnected"] as? Bool, isConnected {
                    print("🔄 SyncService: Connection restored, performing sync")
                    Task {
                        await self.performIncrementalSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Sync Time Management
    
    /// Update last sync time
    private func updateLastSyncTime() {
        let now = Date()
        lastSyncTime = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastSyncKey)
        print("🔄 SyncService: Updated last sync time to \(now)")
    }
    
    /// Load last sync time from UserDefaults
    private func loadLastSyncTime() {
        let timestamp = UserDefaults.standard.double(forKey: lastSyncKey)
        if timestamp > 0 {
            lastSyncTime = Date(timeIntervalSince1970: timestamp)
            print("🔄 SyncService: Loaded last sync time: \(String(describing: lastSyncTime))")
        }
    }
    
    /// Reset sync time (useful for testing)
    func resetSyncTime() {
        lastSyncTime = nil
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        print("🔄 SyncService: Reset sync time")
    }
}

