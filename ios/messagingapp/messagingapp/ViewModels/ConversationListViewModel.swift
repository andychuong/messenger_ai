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
    
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // MARK: - Lifecycle
    
    init() {
        setupRealtimeListener()
    }
    
    deinit {
        conversationsListener?.remove()
    }
    
    // MARK: - Setup
    
    func setupRealtimeListener() {
        conversationsListener = conversationService.listenToConversations { [weak self] conversations in
            Task { @MainActor in
                self?.conversations = conversations
                self?.filterConversations()
            }
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
}

