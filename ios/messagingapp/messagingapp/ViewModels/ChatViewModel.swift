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
    
    // Auto-translation state
    @Published var autoTranslateEnabled = false
    @Published var translatedMessages: [String: String] = [:] // messageId -> translatedText
    @Published var isTranslating = false
    
    let voiceService = VoiceRecordingService()
    private var typingIndicator = TypingIndicatorService()
    private var typingCancellable: AnyCancellable?
    private let translationService = TranslationService()
    
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
    
    // UserDefaults key for auto-translation preference
    private var autoTranslatePreferenceKey: String {
        "autoTranslate_\(conversationId)"
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
        loadAutoTranslatePreference()
    }
    
    init(conversationId: String, otherUserId: String, otherUserName: String) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        
        // Phase 12: Load saved encryption preference for this conversation
        loadEncryptionPreference()
        loadAutoTranslatePreference()
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
                guard let self = self else { return }
                
                // Check for new messages
                let oldMessageIds = Set(self.messages.compactMap { $0.id })
                let newMessages = messages.filter { message in
                    guard let messageId = message.id else { return false }
                    return !oldMessageIds.contains(messageId)
                }
                
                self.messages = messages
                
                // Auto-translate new unencrypted messages if enabled
                if self.autoTranslateEnabled {
                    for message in newMessages {
                        await self.translateNewMessage(message)
                    }
                }
                
                // Mark as read if chat is active and new messages arrived
                if self.isChatActive {
                    await self.markAllMessagesAsRead()
                }
            }
        }
        
        conversationListener = conversationService.listenToConversation(conversationId: conversationId) { [weak self] conversation in
            Task { @MainActor in
                guard let self = self, let conversation = conversation else { return }
                self.conversation = conversation
                
                // Set up user status listener when conversation loads (for direct chats)
                if conversation.type == .direct && self.userStatusListener == nil {
                    let otherUserId = conversation.otherParticipantId(currentUserId: currentUserId) ?? ""
                    if !otherUserId.isEmpty {
                        self.setupUserStatusListener(for: otherUserId)
                    }
                }
            }
        }
        
        // Set up user status listener immediately if we have the otherUserId
        if !isGroupChat && !otherUserId.isEmpty {
            setupUserStatusListener(for: otherUserId)
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
    
    private func setupUserStatusListener(for userId: String) {
        // Remove existing listener if any
        userStatusListener?.remove()
        
        userStatusListener = db.collection("users")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      let statusString = data["status"] as? String,
                      let status = User.UserStatus(rawValue: statusString) else {
                    return
                }
                
                Task { @MainActor in
                    self.otherUserStatus = status
                    print("👤 User status updated: \(status.rawValue)")
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
    
    // MARK: - Auto-Translation
    
    /// Toggle auto-translation for this conversation
    func toggleAutoTranslation() {
        autoTranslateEnabled.toggle()
        saveAutoTranslatePreference()
        
        if autoTranslateEnabled {
            print("🌐 Auto-translation enabled for conversation \(conversationId)")
            // Translate all visible unencrypted messages
            Task {
                await translateVisibleMessages()
            }
        } else {
            print("🌐 Auto-translation disabled for conversation \(conversationId)")
            translatedMessages.removeAll()
        }
    }
    
    /// Load saved auto-translate preference for this conversation
    private func loadAutoTranslatePreference() {
        if UserDefaults.standard.object(forKey: autoTranslatePreferenceKey) != nil {
            autoTranslateEnabled = UserDefaults.standard.bool(forKey: autoTranslatePreferenceKey)
            print("📝 Loaded auto-translate preference for conversation \(conversationId): \(autoTranslateEnabled ? "enabled" : "disabled")")
            
            // If auto-translate is enabled, translate messages
            if autoTranslateEnabled {
                Task {
                    await translateVisibleMessages()
                }
            }
        }
    }
    
    /// Save auto-translate preference for this conversation
    private func saveAutoTranslatePreference() {
        UserDefaults.standard.set(autoTranslateEnabled, forKey: autoTranslatePreferenceKey)
        print("💾 Saved auto-translate preference for conversation \(conversationId): \(autoTranslateEnabled ? "enabled" : "disabled")")
    }
    
    /// Translate all visible unencrypted messages
    func translateVisibleMessages() async {
        guard autoTranslateEnabled,
              let targetLanguage = SettingsService.shared.settings.preferredLanguage,
              !targetLanguage.isEmpty else {
            print("⚠️ Auto-translation enabled but no preferred language set")
            return
        }
        
        isTranslating = true
        
        // Get unencrypted messages (messages without encryption or isEncrypted = false)
        let unencryptedMessages = messages.filter { message in
            let isEncrypted = message.isEncrypted ?? true // Default to true for backward compatibility
            return !isEncrypted && !message.text.isEmpty && message.type != .system
        }
        
        print("🌐 Translating \(unencryptedMessages.count) unencrypted messages to \(targetLanguage)")
        
        // Translate each message individually (with caching)
        for message in unencryptedMessages {
            guard let messageId = message.id else { continue }
            
            // Skip if already translated
            if translatedMessages[messageId] != nil {
                continue
            }
            
            do {
                let result = try await translationService.translateMessage(
                    messageId: messageId,
                    conversationId: conversationId,
                    targetLanguage: targetLanguage
                )
                
                translatedMessages[messageId] = result.translatedText
            } catch {
                print("❌ Failed to translate message \(messageId): \(error.localizedDescription)")
            }
        }
        
        isTranslating = false
    }
    
    /// Translate a single new message (called when a new unencrypted message arrives)
    func translateNewMessage(_ message: Message) async {
        guard autoTranslateEnabled,
              let targetLanguage = SettingsService.shared.settings.preferredLanguage,
              !targetLanguage.isEmpty,
              let messageId = message.id else {
            return
        }
        
        // Only translate unencrypted messages
        let isEncrypted = message.isEncrypted ?? true
        guard !isEncrypted && !message.text.isEmpty && message.type != .system else {
            return
        }
        
        // Skip if already translated
        guard translatedMessages[messageId] == nil else {
            return
        }
        
        do {
            let result = try await translationService.translateMessage(
                messageId: messageId,
                conversationId: conversationId,
                targetLanguage: targetLanguage
            )
            
            translatedMessages[messageId] = result.translatedText
        } catch {
            print("❌ Failed to translate new message \(messageId): \(error.localizedDescription)")
        }
    }
}
