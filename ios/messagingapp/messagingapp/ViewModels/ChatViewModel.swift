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
    @Published var otherUserStatus: User.UserStatus = .offline
    @Published var isEditingMessage = false
    @Published var editingMessage: Message?
    @Published var showingImagePicker = false
    @Published var selectedImage: UIImage?
    @Published var showingVoiceRecorder = false
    @Published var typingText: String? = nil
    
    // Phase 9.5 Redesign: Per-message encryption toggle
    // Phase 12: Changed default to unencrypted, saves user preference
    @Published var nextMessageEncrypted = false // Default to unencrypted (AI-enhanced)
    
    let voiceService = VoiceRecordingService()
    private var typingIndicator = TypingIndicatorService()
    private var typingCancellable: AnyCancellable?
    
    private let messageService = MessageService()
    private let conversationService = ConversationService()
    private let imageService = ImageService()
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?
    private var userStatusListener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var typingDebounceTask: Task<Void, Never>?
    private var markAsReadTask: Task<Void, Never>?
    private var lastMarkAsReadTime: Date = .distantPast
    
    // Track if the chat is actively being viewed
    var isChatActive = false
    
    let conversationId: String
    let otherUserId: String
    let otherUserName: String
    
    // UserDefaults key for encryption preference
    private var encryptionPreferenceKey: String {
        "encryptionPreference_\(conversationId)"
    }
    
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
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
    
    init(conversation: Conversation) {
        self.conversationId = conversation.id ?? ""
        self.conversation = conversation
        
        if conversation.type == .direct, let currentUserId = Auth.auth().currentUser?.uid {
            self.otherUserId = conversation.otherParticipantId(currentUserId: currentUserId) ?? ""
            self.otherUserName = conversation.otherParticipantDetails(currentUserId: currentUserId)?.name ?? ""
        } else {
            self.otherUserId = ""
            self.otherUserName = ""
        }
        
        // Phase 12: Load saved encryption preference for this conversation
        loadEncryptionPreference()
    }
    
    init(conversationId: String, otherUserId: String, otherUserName: String) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        
        // Phase 12: Load saved encryption preference for this conversation
        loadEncryptionPreference()
    }
    
    deinit {
        messagesListener?.remove()
        conversationListener?.remove()
        userStatusListener?.remove()
    }
    
    func setupRealtimeListeners() {
        guard let currentUserId = currentUserId else { return }
        
        messagesListener = messageService.listenToMessages(conversationId: conversationId) { [weak self] messages in
            Task { @MainActor in
                self?.messages = messages
                // Mark as read if chat is active and new messages arrived
                if self?.isChatActive == true {
                    await self?.markAllMessagesAsRead()
                }
            }
        }
        
        conversationListener = conversationService.listenToConversation(conversationId: conversationId) { [weak self] conversation in
            Task { @MainActor in
                self?.conversation = conversation
            }
        }
        
        if !isGroupChat && !otherUserId.isEmpty {
            setupUserStatusListener()
        }
        
        // Start listening for typing indicators
        startTypingListener(currentUserId: currentUserId)
    }
    
    // MARK: - Typing Indicators
    
    private func startTypingListener(currentUserId: String) {
        // Build user names map for group chats
        var userNames: [String: String] = [:]
        if let conversation = conversation {
            for (userId, detail) in conversation.participantDetails {
                userNames[userId] = detail.name
            }
        }
        
        typingIndicator.startListening(
            conversationId: conversationId,
            currentUserId: currentUserId,
            userNames: userNames
        )
        
        // Observe typing text changes and publish to ChatViewModel
        typingCancellable = typingIndicator.$typingText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTypingText in
                self?.typingText = newTypingText
            }
    }
    
    func handleTextChange() {
        guard let currentUserId = currentUserId else { return }
        
        // Cancel previous debounce task
        typingDebounceTask?.cancel()
        
        if !messageText.isEmpty {
            // User is typing - send status
            typingIndicator.setTyping(
                conversationId: conversationId,
                userId: currentUserId,
                isTyping: true
            )
            
            // Debounce - clear typing after 3 seconds of no activity
            typingDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                self.clearTypingStatus()
            }
        } else {
            // Text is empty - clear typing status
            clearTypingStatus()
        }
    }
    
    func clearTypingStatus() {
        guard let currentUserId = currentUserId else { return }
        typingIndicator.setTyping(
            conversationId: conversationId,
            userId: currentUserId,
            isTyping: false
        )
    }
    
    func stopTypingListener() {
        typingIndicator.stopListening()
        typingCancellable?.cancel()
    }
    
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
    
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedMessages = try await messageService.fetchMessages(conversationId: conversationId, limit: 50)
            messages = loadedMessages
            // Only mark as read if chat is actively being viewed
            if isChatActive {
                await markAllMessagesAsRead()
            }
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            print("Error loading messages: \(error)")
        }
        
        isLoading = false
    }
    
    func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        if isEditingMessage, let message = editingMessage {
            await updateEditedMessage(message)
            return
        }
        
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        // Clear typing status immediately when sending
        clearTypingStatus()
        
        isSending = true
        errorMessage = nil
        
        do {
            // Phase 9.5 Redesign: Pass per-message encryption flag
            let sentMessage = try await messageService.sendMessage(
                conversationId: conversationId,
                text: textToSend,
                shouldEncrypt: nextMessageEncrypted
            )
            
            // Phase 12: Keep user's encryption preference (don't reset)
            // User's preference is now saved and persists across messages
            
            if !messages.contains(where: { $0.id == sentMessage.id }) {
                messages.append(sentMessage)
            }
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending message: \(error)")
            messageText = textToSend
        }
        
        isSending = false
    }
    
    func markAllMessagesAsRead() async {
        // Debounce: only mark as read if it's been at least 0.5 seconds since last call
        let now = Date()
        let timeSinceLastCall = now.timeIntervalSince(lastMarkAsReadTime)
        
        guard timeSinceLastCall >= 0.5 else {
            return
        }
        
        // Cancel any pending mark-as-read task
        markAsReadTask?.cancel()
        
        lastMarkAsReadTime = now
        
        do {
            // Mark individual messages as read
            try await messageService.markAllAsRead(conversationId: conversationId)
            
            // Also clear the conversation's unread count
            try await conversationService.markAsRead(conversationId: conversationId)
        } catch {
            // Silently fail for permission errors
            if !error.localizedDescription.contains("permissions") {
                print("Error marking messages as read: \(error)")
            }
        }
    }
    
    func deleteMessage(_ message: Message) async {
        guard let messageId = message.id else { return }
        
        do {
            try await messageService.deleteMessage(conversationId: conversationId, messageId: messageId)
            messages.removeAll { $0.id == messageId }
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
            print("Error deleting message: \(error)")
        }
    }
    
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
        isEditingMessage = false
        editingMessage = nil
        messageText = ""
        
        isSending = true
        errorMessage = nil
        
        do {
            try await messageService.editMessage(
                conversationId: conversationId,
                messageId: messageId,
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
                conversationId: conversationId,
                messageId: messageId,
                newText: newText
            )
        } catch {
            errorMessage = error.localizedDescription
            print("Error editing message: \(error)")
        }
    }
    
    func addReaction(to message: Message, emoji: String) async {
        guard let messageId = message.id else { return }
        
        do {
            try await messageService.addReaction(
                conversationId: conversationId,
                messageId: messageId,
                emoji: emoji
            )
        } catch {
            print("Error adding reaction: \(error)")
        }
    }
    
    func removeReaction(from message: Message, emoji: String) async {
        guard let messageId = message.id else { return }
        
        do {
            // addReaction toggles reactions, so it handles both add and remove
            try await messageService.addReaction(
                conversationId: conversationId,
                messageId: messageId,
                emoji: emoji
            )
        } catch {
            print("Error removing reaction: \(error)")
        }
    }
    
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
    
    func sendImageMessage(_ image: UIImage) async {
        isSending = true
        errorMessage = nil
        
        do {
            let message = try await imageService.sendImageMessage(
                image: image,
                conversationId: conversationId
            )
            
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            errorMessage = "Failed to send image: \(error.localizedDescription)"
            print("Error sending image: \(error)")
        }
        
        isSending = false
    }
    
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
            
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
            
            voiceService.cancelRecording()
        } catch {
            errorMessage = "Failed to send voice message: \(error.localizedDescription)"
            print("Error sending voice: \(error)")
        }
        
        isSending = false
    }
    
    // MARK: - Phase 9.5 Redesign: Per-Message Encryption Toggle
    
    func toggleNextMessageEncryption() {
        nextMessageEncrypted.toggle()
        // Phase 12: Save user's preference for this conversation
        saveEncryptionPreference()
        print(nextMessageEncrypted ? "🔒 Messages will be encrypted" : "🔓 Messages will be AI-enhanced")
    }
    
    // MARK: - Encryption Preference Persistence
    
    /// Load saved encryption preference for this conversation
    private func loadEncryptionPreference() {
        if UserDefaults.standard.object(forKey: encryptionPreferenceKey) != nil {
            nextMessageEncrypted = UserDefaults.standard.bool(forKey: encryptionPreferenceKey)
            print("📝 Loaded encryption preference for conversation \(conversationId): \(nextMessageEncrypted ? "encrypted" : "unencrypted")")
        } else {
            // Use default (unencrypted)
            nextMessageEncrypted = false
            print("📝 Using default encryption preference: unencrypted (AI-enhanced)")
        }
    }
    
    /// Save encryption preference for this conversation
    private func saveEncryptionPreference() {
        UserDefaults.standard.set(nextMessageEncrypted, forKey: encryptionPreferenceKey)
        print("💾 Saved encryption preference for conversation \(conversationId): \(nextMessageEncrypted ? "encrypted" : "unencrypted")")
    }
}
