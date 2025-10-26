//
//  ConversationListViewModel.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var filteredConversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            filterConversations()
        }
    }
    
    private let conversationService = ConversationService()
    private var conversationsListener: ListenerRegistration?
    private var userStatusListeners: [String: ListenerRegistration] = [:] // userId -> listener
    private var userDataCache: [String: (status: String, photoURL: String?, name: String)] = [:] // userId -> cached user data
    private let db = Firestore.firestore()
    
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // MARK: - Lifecycle
    
    init() {
        setupRealtimeListener()
        // Sync unread counts on app launch
        Task {
            await syncUnreadCounts()
        }
    }
    
    deinit {
        conversationsListener?.remove()
        // Remove all user status listeners
        userStatusListeners.values.forEach { $0.remove() }
        userStatusListeners.removeAll()
        userDataCache.removeAll()
    }
    
    // MARK: - Setup
    
    func setupRealtimeListener() {
        conversationsListener = conversationService.listenToConversations { [weak self] conversations in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Initialize cache from conversation data if cache is empty
                if self.userDataCache.isEmpty {
                    print("📦 Messages: Initializing cache from conversation data")
                    for conversation in conversations {
                        for (userId, detail) in conversation.participantDetails {
                            if self.userDataCache[userId] == nil {
                                self.userDataCache[userId] = (
                                    status: detail.status ?? "offline",
                                    photoURL: detail.photoURL,
                                    name: detail.name
                                )
                            }
                        }
                    }
                    print("✅ Messages: Initialized cache with \(self.userDataCache.count) user(s)")
                }
                
                // Apply cached user data to incoming conversations
                var updatedConversations = conversations
                var cacheApplied = 0
                for i in 0..<updatedConversations.count {
                    for (userId, cachedData) in self.userDataCache {
                        if updatedConversations[i].participantDetails[userId] != nil {
                            updatedConversations[i].participantDetails[userId]?.status = cachedData.status
                            updatedConversations[i].participantDetails[userId]?.photoURL = cachedData.photoURL
                            updatedConversations[i].participantDetails[userId]?.name = cachedData.name
                            cacheApplied += 1
                        }
                    }
                }
                if cacheApplied > 0 {
                    print("✅ Messages: Applied cached data for \(cacheApplied) participant(s)")
                }
                
                // Only update if conversations actually changed
                let conversationsChanged = self.conversations != updatedConversations
                
                self.conversations = updatedConversations
                
                if conversationsChanged {
                    self.filterConversations()
                    // Set up status listeners only when participant list changes
                    self.setupUserStatusListeners()
                }
            }
        }
    }
    
    // MARK: - User Status Tracking
    
    /// Set up real-time listeners for all participants' online status
    private func setupUserStatusListeners() {
        guard let currentUserId = currentUserId else { return }
        
        // Collect all unique participant IDs (excluding current user)
        var participantIds = Set<String>()
        for conversation in conversations {
            for participantId in conversation.participants where participantId != currentUserId {
                participantIds.insert(participantId)
            }
        }
        
        // Remove listeners for users no longer in any conversation
        let existingIds = Set(userStatusListeners.keys)
        let idsToRemove = existingIds.subtracting(participantIds)
        if !idsToRemove.isEmpty {
            print("🗑️ Removing \(idsToRemove.count) status listener(s)")
            for userId in idsToRemove {
                userStatusListeners[userId]?.remove()
                userStatusListeners.removeValue(forKey: userId)
                userDataCache.removeValue(forKey: userId) // Also remove from cache
            }
        }
        
        // Add listeners for new users
        let idsToAdd = participantIds.subtracting(existingIds)
        if !idsToAdd.isEmpty {
            print("➕ Adding \(idsToAdd.count) new status listener(s)")
        }
        
        for userId in idsToAdd {
            let listener = db.collection("users")
                .document(userId)
                .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                    guard let self = self,
                          let snapshot = snapshot,
                          !snapshot.metadata.isFromCache, // Ignore cached data
                          !snapshot.metadata.hasPendingWrites else { // Ignore local writes
                        return
                    }
                    
                    guard let updatedUser = try? snapshot.data(as: User.self) else {
                        print("❌ Messages: Failed to decode user data for \(userId)")
                        return
                    }
                    
                    Task { @MainActor in
                        self.updateUserData(userId: userId, user: updatedUser)
                    }
                }
            
            userStatusListeners[userId] = listener
        }
    }
    
    /// Update user data (status, photo, name) for a specific user across all conversations
    private func updateUserData(userId: String, user: User) {
        // Check if anything changed
        let cachedData = userDataCache[userId]
        let statusChanged = cachedData?.status != user.status.rawValue
        let photoChanged = cachedData?.photoURL != user.photoURL
        let nameChanged = cachedData?.name != user.displayName
        
        if !statusChanged && !photoChanged && !nameChanged {
            return // Nothing changed
        }
        
        print("🔄 Messages: User data updated for \(user.displayName)")
        
        // Log what changed
        if statusChanged {
            print("   📍 Status: \(cachedData?.status ?? "nil") → \(user.status.rawValue)")
        }
        if photoChanged {
            print("   🖼️ Photo: \(cachedData?.photoURL ?? "nil") → \(user.photoURL ?? "nil")")
        }
        if nameChanged {
            print("   ✏️ Name: \(cachedData?.name ?? "unknown") → \(user.displayName)")
        }
        
        // Update the cache
        userDataCache[userId] = (status: user.status.rawValue, photoURL: user.photoURL, name: user.displayName)
        
        // Update all fields in conversations where this user is a participant
        var conversationsToUpdate: [Int] = []
        for (index, conversation) in conversations.enumerated() {
            if conversation.participantDetails[userId] != nil {
                conversationsToUpdate.append(index)
            }
        }
        
        if !conversationsToUpdate.isEmpty {
            print("✅ Messages: Updating \(conversationsToUpdate.count) conversation(s)")
            for index in conversationsToUpdate {
                conversations[index].participantDetails[userId]?.status = user.status.rawValue
                conversations[index].participantDetails[userId]?.photoURL = user.photoURL
                conversations[index].participantDetails[userId]?.name = user.displayName
            }
            
            // Trigger UI update
            filterConversations()
            print("✅ Messages: UI refreshed")
        }
    }
    
    // MARK: - Load Conversations
    
    func loadConversations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedConversations = try await conversationService.fetchConversations()
            conversations = loadedConversations
            filterConversations()
        } catch {
            errorMessage = "Failed to load conversations: \(error.localizedDescription)"
            print("Error loading conversations: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Filter
    
    func filterConversations() {
        if searchText.isEmpty {
            filteredConversations = conversations
        } else {
            filteredConversations = conversations.filter { conversation in
                guard let currentUserId = currentUserId else { return false }
                let title = conversation.title(currentUserId: currentUserId)
                return title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Delete Conversation
    
    func deleteConversation(_ conversation: Conversation) async {
        guard let conversationId = conversation.id else { return }
        
        do {
            try await conversationService.deleteConversation(conversationId: conversationId)
            // Remove from local array
            conversations.removeAll { $0.id == conversationId }
            filterConversations()
        } catch {
            errorMessage = "Failed to delete conversation: \(error.localizedDescription)"
            print("Error deleting conversation: \(error)")
        }
    }
    
    // MARK: - Mark as Read
    
    func markAsRead(_ conversation: Conversation) async {
        guard let conversationId = conversation.id else { return }
        
        do {
            try await conversationService.markAsRead(conversationId: conversationId)
        } catch {
            print("Error marking conversation as read: \(error)")
        }
    }
    
    // MARK: - Get or Create Conversation
    
    func getOrCreateConversation(with userId: String, userName: String, userEmail: String) async -> Conversation? {
        do {
            let conversation = try await conversationService.getOrCreateConversation(
                with: userId,
                userName: userName,
                userEmail: userEmail
            )
            return conversation
        } catch {
            errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            print("Error creating conversation: \(error)")
            return nil
        }
    }
    
    // MARK: - Computed Properties
    
    var totalUnreadCount: Int {
        guard let currentUserId = currentUserId else { return 0 }
        return conversations.reduce(0) { total, conversation in
            total + conversation.unreadCountForUser(currentUserId)
        }
    }
    
    var hasUnreadMessages: Bool {
        return totalUnreadCount > 0
    }
    
    // MARK: - Sync Unread Counts
    
    /// Sync unread counts with actual message read receipts
    /// This fixes the issue where unreadCount persists after app restart even though messages are read
    private func syncUnreadCounts() async {
        guard let currentUserId = currentUserId else { return }
        
        for conversation in conversations {
            guard let conversationId = conversation.id else { continue }
            
            // Check if this conversation has unread messages according to the stored count
            let storedUnreadCount = conversation.unreadCountForUser(currentUserId)
            if storedUnreadCount == 0 {
                continue // Already marked as read
            }
            
            // Check actual unread messages by querying messages without readBy for current user
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .getDocuments()
                
                var actualUnreadCount = 0
                
                for document in snapshot.documents {
                    let data = document.data()
                    let senderId = data["senderId"] as? String ?? ""
                    
                    // Skip messages sent by current user
                    if senderId == currentUserId {
                        continue
                    }
                    
                    let readBy = data["readBy"] as? [[String: Any]] ?? []
                    let isRead = readBy.contains { entry in
                        entry["userId"] as? String == currentUserId
                    }
                    
                    if !isRead {
                        actualUnreadCount += 1
                    }
                }
                
                // If actual count is 0 but stored count is > 0, clear it
                if actualUnreadCount == 0 && storedUnreadCount > 0 {
                    try await conversationService.markAsRead(conversationId: conversationId)
                }
            } catch {
                // Silently fail
            }
        }
    }
}


