import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Combine

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

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
    
    // Phase 16: Smart Replies & Suggestions
    @Published var smartReplies: [SmartReply] = []
    @Published var isGeneratingReplies = false
    @Published var showSmartReplies = false
    @Published var smartComposeCompletion: String = ""
    @Published var smartComposeSuggestion: String = ""
    private let smartReplyService = SmartReplyService.shared
    private var smartComposeTask: Task<Void, Never>?
    
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
                
                // Check if this is the initial load (messages were empty)
                let isInitialLoad = self.messages.isEmpty && !messages.isEmpty
                
                // Check for new messages
                let oldMessageIds = Set(self.messages.compactMap { $0.id })
                let newMessages = messages.filter { message in
                    guard let messageId = message.id else { return false }
                    return !oldMessageIds.contains(messageId)
                }
                
                self.messages = messages
                
                // If this is the initial load and auto-translate is enabled, translate all messages
                if isInitialLoad && self.autoTranslateEnabled && !self.isTranslating {
                    print("🌐 Initial load with auto-translate enabled - translating all messages")
                    await self.translateVisibleMessages()
                } else if self.autoTranslateEnabled {
                    // Auto-translate only new messages
                    for message in newMessages {
                        await self.translateNewMessage(message)
                    }
                }
                
                // Mark as read if chat is active and new messages arrived
                if self.isChatActive {
                    await self.markAllMessagesAsRead()
                }
                
                // Phase 16: Generate smart replies for new messages from others
                if !newMessages.isEmpty && self.smartReplyService.shouldGenerateReplies(for: self.conversationId) {
                    // Only generate if the last message is from someone else
                    if let lastMessage = newMessages.last,
                       lastMessage.senderId != currentUserId {
                        await self.generateSmartReplies()
                    }
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
            
            // If auto-translate is enabled, translate the loaded messages
            if autoTranslateEnabled && !messages.isEmpty {
                print("🌐 Auto-translate enabled - translating loaded messages")
                await translateVisibleMessages()
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
            
            // Note: Don't translate here - messages aren't loaded yet
            // Translation will be triggered after loadMessages() completes
        }
    }
    
    /// Save auto-translate preference for this conversation
    private func saveAutoTranslatePreference() {
        UserDefaults.standard.set(autoTranslateEnabled, forKey: autoTranslatePreferenceKey)
        print("💾 Saved auto-translate preference for conversation \(conversationId): \(autoTranslateEnabled ? "enabled" : "disabled")")
    }
    
    /// Translate all visible messages (encrypted and unencrypted)
    /// Optimized to start from most recent messages and use batch translation
    func translateVisibleMessages() async {
        guard autoTranslateEnabled,
              let targetLanguage = SettingsService.shared.settings.preferredLanguage,
              !targetLanguage.isEmpty else {
            print("⚠️ Auto-translation enabled but no preferred language set")
            return
        }
        
        isTranslating = true
        
        // Get all translatable messages (exclude system messages)
        // REVERSED: Start from most recent messages
        let translatableMessages = messages.filter { message in
            return !message.text.isEmpty && message.type != .system
        }.reversed()
        
        // Filter out already translated messages
        let untranslatedMessages = translatableMessages.filter { message in
            guard let messageId = message.id else { return false }
            return translatedMessages[messageId] == nil
        }
        
        let totalCount = Array(untranslatedMessages).count
        print("🌐 Translating \(totalCount) messages to \(targetLanguage) (newest first)")
        
        // Process in batches of 10 for better performance
        let batchSize = 10
        let messageBatches = Array(untranslatedMessages).chunked(into: batchSize)
        
        for (batchIndex, batch) in messageBatches.enumerated() {
            print("📦 Processing batch \(batchIndex + 1)/\(messageBatches.count)")
            
            // Translate batch concurrently
            await withTaskGroup(of: (String, String?)?.self) { group in
                for message in batch {
                    guard let messageId = message.id else { continue }
                    
                    group.addTask {
                        do {
                            // For encrypted messages, pass the decrypted text
                            let result = try await self.translationService.translateMessage(
                                messageId: messageId,
                                conversationId: self.conversationId,
                                targetLanguage: targetLanguage,
                                text: message.text
                            )
                            return (messageId, result.translatedText)
                        } catch {
                            print("❌ Failed to translate message \(messageId): \(error.localizedDescription)")
                            return nil
                        }
                    }
                }
                
                // Collect results and update UI incrementally
                for await result in group {
                    if let (messageId, translatedText) = result {
                        await MainActor.run {
                            self.translatedMessages[messageId] = translatedText
                        }
                    }
                }
            }
            
            // Small delay between batches to avoid overwhelming the API
            if batchIndex < messageBatches.count - 1 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        isTranslating = false
        print("✅ Translation complete!")
    }
    
    /// Translate a single new message (encrypted or unencrypted)
    func translateNewMessage(_ message: Message) async {
        guard autoTranslateEnabled,
              let targetLanguage = SettingsService.shared.settings.preferredLanguage,
              !targetLanguage.isEmpty,
              let messageId = message.id else {
            return
        }
        
        // Only translate non-system messages with text
        guard !message.text.isEmpty && message.type != .system else {
            return
        }
        
        // Skip if already translated
        guard translatedMessages[messageId] == nil else {
            return
        }
        
        do {
            // Pass the decrypted text (message.text is already decrypted when fetched)
            let result = try await translationService.translateMessage(
                messageId: messageId,
                conversationId: conversationId,
                targetLanguage: targetLanguage,
                text: message.text  // Pass the decrypted text
            )
            
            translatedMessages[messageId] = result.translatedText
        } catch {
            print("❌ Failed to translate new message \(messageId): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Phase 16: Smart Replies
    
    /// Generate smart reply suggestions based on recent conversation
    func generateSmartReplies() async {
        guard !isGeneratingReplies else { return }
        
        isGeneratingReplies = true
        showSmartReplies = true
        
        do {
            let replies = try await smartReplyService.generateSmartReplies(
                conversationId: conversationId,
                recentMessages: Array(messages.suffix(10))
            )
            
            // Take only the requested number of suggestions from settings
            let settings = smartReplyService.getSettings()
            smartReplies = Array(replies.prefix(settings.numberOfSuggestions))
            
            print("✨ Generated \(smartReplies.count) smart replies")
        } catch {
            print("❌ Failed to generate smart replies: \(error.localizedDescription)")
            smartReplies = []
        }
        
        isGeneratingReplies = false
    }
    
    /// Send a smart reply
    func sendSmartReply(_ reply: SmartReply) {
        messageText = reply.text
        Task {
            await sendMessage()
            // Clear smart replies after sending
            clearSmartReplies()
        }
    }
    
    /// Clear smart replies
    func clearSmartReplies() {
        smartReplies = []
        showSmartReplies = false
        smartReplyService.clearCache(for: conversationId)
    }
    
    /// Check if smart replies should be shown
    func shouldShowSmartReplies() -> Bool {
        let settings = smartReplyService.getSettings()
        return settings.enabled && showSmartReplies && !smartReplies.isEmpty
    }
    
    // MARK: - Phase 16: Smart Compose
    
    /// Generate type-ahead completion for partially typed text
    func generateSmartCompose(partialText: String) {
        // Cancel any existing task
        smartComposeTask?.cancel()
        
        // Don't suggest for very short text
        let words = partialText.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard words.count >= 3 else {
            smartComposeSuggestion = ""
            return
        }
        
        smartComposeTask = Task {
            // Debounce: wait 500ms before generating
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                // Build context from recent messages
                let recentContext = Array(messages.suffix(5)).map { message in
                    let sender = message.senderId == currentUserId ? "You" : (message.senderName ?? "Other")
                    return "\(sender): \(message.text)"
                }
                
                let settings = smartReplyService.getSettings()
                let response = try await smartReplyService.generateCompletion(
                    partialText: partialText,
                    conversationContext: recentContext,
                    tone: settings.defaultTone
                )
                
                guard !Task.isCancelled, response.success else { return }
                
                await MainActor.run {
                    // Only show if confidence is high enough and text hasn't changed
                    if response.confidence >= 0.6 && messageText.hasPrefix(partialText) {
                        smartComposeSuggestion = response.completion
                    } else {
                        smartComposeSuggestion = ""
                    }
                }
            } catch {
                print("❌ Failed to generate smart compose: \(error.localizedDescription)")
            }
        }
    }
    
    /// Accept smart compose suggestion
    func acceptSmartCompose() {
        if !smartComposeSuggestion.isEmpty {
            messageText += smartComposeSuggestion
            smartComposeSuggestion = ""
            HapticManager.shared.light()
        }
    }
    
    /// Clear smart compose suggestion
    func clearSmartCompose() {
        smartComposeSuggestion = ""
        smartComposeTask?.cancel()
    }
}
