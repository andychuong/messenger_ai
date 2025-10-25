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
    }
    
    // MARK: - Setup
    
    func setupRealtimeListener() {
        conversationsListener = conversationService.listenToConversations { [weak self] conversations in
            Task { @MainActor in
                self?.conversations = conversations
                self?.filterConversations()
                // Set up status listeners for all participants
                self?.setupUserStatusListeners()
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
        for userId in idsToRemove {
            userStatusListeners[userId]?.remove()
            userStatusListeners.removeValue(forKey: userId)
        }
        
        // Add listeners for new users
        for userId in participantIds {
            // Skip if already listening
            guard userStatusListeners[userId] == nil else { continue }
            
            let listener = db.collection("users")
                .document(userId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self,
                          let data = snapshot?.data(),
                          let statusString = data["status"] as? String else {
                        return
                    }
                    
                    Task { @MainActor in
                        self.updateUserStatus(userId: userId, status: statusString)
                    }
                }
            
            userStatusListeners[userId] = listener
        }
    }
    
    /// Update the status for a specific user across all conversations
    private func updateUserStatus(userId: String, status: String) {
        // Update status in all conversations where this user is a participant
        for i in 0..<conversations.count {
            if conversations[i].participantDetails[userId] != nil {
                conversations[i].participantDetails[userId]?.status = status
            }
        }
        // Trigger UI update
        filterConversations()
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

