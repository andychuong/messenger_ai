//
//  ChatViewModel.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var conversation: Conversation?
    @Published var otherUserStatus: User.UserStatus = .offline  // For direct chats
    
    // Edit mode
    @Published var isEditingMessage = false
    @Published var editingMessage: Message?
    
    // Image picking
    @Published var showingImagePicker = false
    @Published var selectedImage: UIImage?
    
    // Voice recording
    @Published var showingVoiceRecorder = false
    let voiceService = VoiceRecordingService()
    
    private let messageService = MessageService()
    private let conversationService = ConversationService()
    private let imageService = ImageService()
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?
    private var userStatusListener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    let conversationId: String
    let otherUserId: String  // Only used for direct chats
    let otherUserName: String  // Only used for direct chats (deprecated)
    
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // Phase 4.5: Group chat support
    var isGroupChat: Bool {
        return conversation?.type == .group
    }
    
    var conversationTitle: String {
        guard let conversation = conversation,
              let currentUserId = currentUserId else {
            return otherUserName
        }
        return conversation.title(currentUserId: currentUserId)
    }
    
    var memberCount: Int {
        return conversation?.memberCount ?? 0
    }
    
    // MARK: - Lifecycle
    
    // Phase 4.5: New conversation-based initializer
    init(conversation: Conversation) {
        self.conversationId = conversation.id ?? ""
        self.conversation = conversation
        
        // For backward compatibility with direct chats
        if conversation.type == .direct, let currentUserId = Auth.auth().currentUser?.uid {
            self.otherUserId = conversation.otherParticipantId(currentUserId: currentUserId) ?? ""
            self.otherUserName = conversation.otherParticipantDetails(currentUserId: currentUserId)?.name ?? ""
        } else {
            self.otherUserId = ""
            self.otherUserName = ""
        }
    }
    
    // Legacy initializer for backward compatibility
    init(conversationId: String, otherUserId: String, otherUserName: String) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
    }
    
    deinit {
        messagesListener?.remove()
        conversationListener?.remove()
        userStatusListener?.remove()
    }
    
    // MARK: - Setup
    
    func setupRealtimeListeners() {
        // Listen to messages
        messagesListener = messageService.listenToMessages(conversationId: conversationId) { [weak self] messages in
            Task { @MainActor in
                self?.messages = messages
                // Mark all messages as read when viewing
                await self?.markAllMessagesAsRead()
            }
        }
        
        // Listen to conversation updates (for typing indicators, online status, etc.)
        conversationListener = conversationService.listenToConversation(conversationId: conversationId) { [weak self] conversation in
            Task { @MainActor in
                self?.conversation = conversation
            }
        }
        
        // Listen to other user's status (for direct chats only)
        if !isGroupChat && !otherUserId.isEmpty {
            setupUserStatusListener()
        }
    }
    
    // MARK: - User Status Listener
    
    private func setupUserStatusListener() {
        userStatusListener = db.collection("users")
            .document(otherUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      let statusString = data["status"] as? String,
                      let status = User.UserStatus(rawValue: statusString) else {
                    return
                }
                
                Task { @MainActor in
                    self.otherUserStatus = status
                }
            }
    }
    
    // MARK: - Load Messages
    
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedMessages = try await messageService.fetchMessages(conversationId: conversationId, limit: 50)
            messages = loadedMessages
            
            // Mark as read
            await markAllMessagesAsRead()
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            print("Error loading messages: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Send Message
    
    func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Check if we're editing or sending new message
        if isEditingMessage, let message = editingMessage {
            await updateEditedMessage(message)
            return
        }
        
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""  // Clear input immediately for better UX
        
        isSending = true
        errorMessage = nil
        
        do {
            let sentMessage = try await messageService.sendMessage(
                conversationId: conversationId,
                text: textToSend
            )
            
            // Optimistically add message to local array if not already there
            if !messages.contains(where: { $0.id == sentMessage.id }) {
                messages.append(sentMessage)
            }
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending message: \(error)")
            // Restore text on failure
            messageText = textToSend
        }
        
        isSending = false
    }
    
    // MARK: - Mark as Read
    
    func markAllMessagesAsRead() async {
        do {
            try await messageService.markAllAsRead(conversationId: conversationId)
        } catch {
            print("Error marking messages as read: \(error)")
        }
    }
    
    // MARK: - Delete Message
    
    func deleteMessage(_ message: Message) async {
        guard let messageId = message.id else { return }
        
        do {
            try await messageService.deleteMessage(messageId: messageId, conversationId: conversationId)
            messages.removeAll { $0.id == messageId }
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
            print("Error deleting message: \(error)")
        }
    }
    
    // MARK: - Edit Message
    
    func startEditing(_ message: Message) {
        isEditingMessage = true
        editingMessage = message
        messageText = message.text
    }
    
    func cancelEditing() {
        isEditingMessage = false
        editingMessage = nil
        messageText = ""
    }
    
    private func updateEditedMessage(_ message: Message) async {
        guard let messageId = message.id else { return }
        
        let newText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear edit mode
        isEditingMessage = false
        editingMessage = nil
        messageText = ""
        
        isSending = true
        errorMessage = nil
        
        do {
            try await messageService.editMessage(
                messageId: messageId,
                conversationId: conversationId,
                newText: newText
            )
        } catch {
            errorMessage = "Failed to update message: \(error.localizedDescription)"
            print("Error editing message: \(error)")
        }
        
        isSending = false
    }
    
    func editMessage(_ message: Message, newText: String) async {
        guard let messageId = message.id else { return }
        
        do {
            try await messageService.editMessage(
                messageId: messageId,
                conversationId: conversationId,
                newText: newText
            )
        } catch {
            errorMessage = error.localizedDescription
            print("Error editing message: \(error)")
        }
    }
    
    // MARK: - Reactions
    
    func addReaction(to message: Message, emoji: String) async {
        guard let messageId = message.id else { return }
        
        do {
            try await messageService.addReaction(
                messageId: messageId,
                conversationId: conversationId,
                emoji: emoji
            )
        } catch {
            print("Error adding reaction: \(error)")
        }
    }
    
    func removeReaction(from message: Message) async {
        guard let messageId = message.id else { return }
        
        do {
            try await messageService.removeReaction(
                messageId: messageId,
                conversationId: conversationId
            )
        } catch {
            print("Error removing reaction: \(error)")
        }
    }
    
    // MARK: - Utility
    
    func shouldShowDateSeparator(for index: Int) -> Bool {
        guard index < messages.count else { return false }
        
        if index == 0 {
            return true
        }
        
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        return !Calendar.current.isDate(
            currentMessage.timestamp,
            inSameDayAs: previousMessage.timestamp
        )
    }
    
    func dateSeparatorText(for message: Message) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(message.timestamp) {
            return "Today"
        } else if calendar.isDateInYesterday(message.timestamp) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: message.timestamp)
        }
    }
    
    // MARK: - Image Messages
    
    func sendImageMessage(_ image: UIImage) async {
        isSending = true
        errorMessage = nil
        
        do {
            let message = try await imageService.sendImageMessage(
                image: image,
                conversationId: conversationId
            )
            
            // Optimistically add to local array
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            errorMessage = "Failed to send image: \(error.localizedDescription)"
            print("Error sending image: \(error)")
        }
        
        isSending = false
    }
    
    // MARK: - Voice Messages
    
    func sendVoiceMessage() async {
        guard let recordingURL = voiceService.recordingURL else {
            errorMessage = "No recording available"
            return
        }
        
        let duration = voiceService.recordingDuration
        
        isSending = true
        errorMessage = nil
        showingVoiceRecorder = false
        
        do {
            let message = try await voiceService.sendVoiceMessage(
                fileURL: recordingURL,
                conversationId: conversationId,
                duration: duration
            )
            
            // Optimistically add to local array
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
            
            // Reset voice service
            voiceService.cancelRecording()
        } catch {
            errorMessage = "Failed to send voice message: \(error.localizedDescription)"
            print("Error sending voice: \(error)")
        }
        
        isSending = false
    }
}

