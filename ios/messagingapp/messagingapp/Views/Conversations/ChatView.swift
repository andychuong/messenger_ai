//
//  ChatView.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var callViewModel: CallViewModel
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMessageForThread: Message?
    @State private var shouldScrollToBottom = false
    @State private var showingGroupInfo = false
    @State private var showingAIAssistant = false
    @State private var previousMessageCount = 0
    @State private var showingLanguageQuickPicker = false
    @State private var showingFormalityAdjuster = false
    @State private var showingSendTranslatedMenu = false
    @State private var isTranslatingSend = false
    @State private var languagePickerMode: LanguagePickerMode = .preference
    @State private var showingExtractedData = false  // Phase 17: Data Extraction
    @FocusState private var isInputFocused: Bool
    
    enum LanguagePickerMode {
        case preference  // Normal mode: set preferred language
        case translateSend  // Translate and send the current message
    }
    
    // Phase 4.5: Support for both direct and group conversations
    init(conversation: Conversation) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }
    
    // Legacy initializer for direct conversations
    init(conversationId: String, otherUserId: String, otherUserName: String) {
        // Create a minimal conversation object for direct chat
        let conversation = Conversation(
            id: conversationId,
            participants: [otherUserId],
            participantDetails: [otherUserId: ParticipantDetail(name: otherUserName, email: "", photoURL: nil, status: nil)],
            type: .direct,
            lastMessage: nil,
            lastMessageTime: nil,
            unreadCount: [:],
            createdAt: Date(),
            updatedAt: Date()
        )
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Group participant header
            if viewModel.isGroupChat,
               let participants = viewModel.conversation?.participantDetails,
               !participants.isEmpty {
                GroupParticipantHeader(
                    participants: participants,
                    currentUserId: viewModel.currentUserId ?? "",
                    onTap: {
                        showingGroupInfo = true
                    }
                )
            }
            
            // Messages list
            messagesList
            
            // Typing indicator (positioned above input bar)
            if let typingText = viewModel.typingText {
                TypingIndicatorView(text: typingText)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: typingText)
            }
            
            // Phase 16: Smart Replies (positioned above input bar)
            if viewModel.shouldShowSmartReplies() {
                SmartRepliesView(
                    smartReplies: viewModel.smartReplies,
                    onSelectReply: { reply in
                        viewModel.sendSmartReply(reply)
                    },
                    onRegenerate: {
                        Task {
                            await viewModel.generateSmartReplies()
                        }
                    },
                    isGenerating: viewModel.isGeneratingReplies
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showSmartReplies)
            }
            
            // Input bar with encryption toggle and formality adjustment
            VStack(spacing: 0) {
                // Edit mode indicator
                if viewModel.isEditingMessage {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Edit Message")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            
                            Text(viewModel.editingMessage?.text ?? "")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.cancelEditing()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                
                HStack(alignment: .center, spacing: 12) {
                    // Encryption toggle
                    if !viewModel.isEditingMessage {
                        Button {
                            HapticManager.shared.toggleChanged()
                            SoundManager.shared.buttonTap()
                            viewModel.toggleNextMessageEncryption()
                        } label: {
                            Image(systemName: viewModel.nextMessageEncrypted ? "lock.fill" : "lock.open.fill")
                                .font(.title2)
                                .foregroundColor(viewModel.nextMessageEncrypted ? .orange : .blue)
                        }
                        .disabled(viewModel.isSending)
                    }
                    
                    // Image picker button
                    if !viewModel.isEditingMessage {
                        Button {
                            HapticManager.shared.light()
                            viewModel.showingImagePicker = true
                        } label: {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(viewModel.isSending)
                    }
                    
                    // Phase 15: Formality adjustment button
                    if !viewModel.isEditingMessage,
                       !viewModel.nextMessageEncrypted,
                       !viewModel.messageText.isEmpty,
                       SettingsService.shared.settings.formalityAdjustmentEnabled {
                        Button {
                            showingFormalityAdjuster = true
                            HapticManager.shared.light()
                        } label: {
                            Image(systemName: "text.alignleft")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                        .disabled(viewModel.isSending)
                    }
                    
                    // Text input with microphone button and smart compose
                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            // Smart Compose suggestion (gray text)
                            if !viewModel.smartComposeSuggestion.isEmpty && !viewModel.isEditingMessage {
                                Text(viewModel.messageText + viewModel.smartComposeSuggestion)
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.leading, 12)
                                    .padding(.vertical, 8)
                                    .lineLimit(1...5)
                            }
                            
                            // Actual text field
                            TextField(
                                viewModel.isEditingMessage ? "Edit message" : (viewModel.nextMessageEncrypted ? "Encrypted message" : "AI-enhanced message"),
                                text: $viewModel.messageText,
                                axis: .vertical
                            )
                            .textFieldStyle(.plain)
                            .padding(.leading, 12)
                            .padding(.vertical, 8)
                            .lineLimit(1...5)
                            .focused($isInputFocused)
                            .disabled(viewModel.isSending)
                            .onSubmit {
                                if !viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Task {
                                        await viewModel.sendMessage()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            isInputFocused = true
                                        }
                                    }
                                }
                            }
                            .onChange(of: viewModel.messageText) { oldValue, newValue in
                                // Handle typing indicators
                                viewModel.handleTextChange()
                                
                                // Phase 16: Trigger smart compose
                                if SmartReplyService.shared.getSettings().enabled && !viewModel.isEditingMessage {
                                    viewModel.generateSmartCompose(partialText: newValue)
                                }
                            }
                            
                            // Smart compose accept button (Tab key alternative)
                            if !viewModel.smartComposeSuggestion.isEmpty {
                                HStack {
                                    Spacer()
                                    Button {
                                        viewModel.acceptSmartCompose()
                                    } label: {
                                        Image(systemName: "arrow.forward.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.trailing, 8)
                                }
                            }
                        }
                        
                        // Microphone button inside text field
                        if !viewModel.isEditingMessage, viewModel.messageText.isEmpty {
                            Button {
                                HapticManager.shared.medium()
                                viewModel.showingVoiceRecorder = true
                            } label: {
                                Image(systemName: "mic.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            .disabled(viewModel.isSending)
                            .padding(.trailing, 8)
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                    
                    // Send button with long-press for translation
                    ZStack {
                        if viewModel.isSending || isTranslatingSend {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: viewModel.isEditingMessage ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                        }
                    }
                    .contentShape(Circle())
                    .onLongPressGesture(minimumDuration: 0.5, pressing: { isPressing in
                        if isPressing {
                            HapticManager.shared.light()
                        }
                    }) {
                        // Long press action - show translation menu
                        if !viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isEditingMessage {
                            HapticManager.shared.medium()
                            showingSendTranslatedMenu = true
                        }
                    }
                    .onTapGesture {
                        // Regular tap action - send message
                        if !viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HapticManager.shared.messageSent()
                            SoundManager.shared.messageSent()
                            Task {
                                await viewModel.sendMessage()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    isInputFocused = true
                                }
                            }
                        }
                    }
                    .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending || isTranslatingSend)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .focused($isInputFocused)
        }
        .navigationTitle(viewModel.conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                navigationTitleView
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                trailingToolbarButtons
            }
        }
        .sheet(isPresented: $showingGroupInfo) {
            if let conversation = viewModel.conversation {
                GroupInfoView(conversation: conversation)
            }
        }
        .sheet(isPresented: $showingAIAssistant) {
            ConversationAIAssistantView(conversationId: viewModel.conversationId)
        }
        .sheet(isPresented: $showingExtractedData) {
            ExtractedDataView(conversationId: viewModel.conversationId, messages: viewModel.messages)
        }
        .sheet(isPresented: $showingLanguageQuickPicker) {
            LanguageQuickPickerView(
                currentLanguage: SettingsService.shared.settings.preferredLanguage,
                autoTranslateEnabled: viewModel.autoTranslateEnabled,
                onLanguageSelected: { language in
                    showingLanguageQuickPicker = false
                    
                    // Handle based on mode
                    if languagePickerMode == .translateSend {
                        // Translate and send
                        if let selectedLanguage = language {
                            sendTranslatedMessage(to: selectedLanguage)
                        }
                        languagePickerMode = .preference // Reset mode
                    } else {
                        // Normal preference setting
                        SettingsService.shared.updatePreferredLanguage(language)
                        // Enable auto-translation if a language is selected
                        if language != nil && !viewModel.autoTranslateEnabled {
                            viewModel.toggleAutoTranslation()
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingFormalityAdjuster) {
            FormalityAdjusterView(
                messageText: $viewModel.messageText,
                language: SettingsService.shared.settings.preferredLanguage ?? "English",
                onApply: { adjustedText in
                    viewModel.messageText = adjustedText
                },
                onDismiss: {
                    showingFormalityAdjuster = false
                }
            )
        }
        .confirmationDialog("Send Translated Message", isPresented: $showingSendTranslatedMenu, titleVisibility: .visible) {
            // Popular languages
            Button("Spanish") {
                sendTranslatedMessage(to: "Spanish")
            }
            
            Button("French") {
                sendTranslatedMessage(to: "French")
            }
            
            Button("German") {
                sendTranslatedMessage(to: "German")
            }
            
            Button("Japanese") {
                sendTranslatedMessage(to: "Japanese")
            }
            
            Button("Chinese") {
                sendTranslatedMessage(to: "Chinese")
            }
            
            Button("Italian") {
                sendTranslatedMessage(to: "Italian")
            }
            
            Button("Portuguese") {
                sendTranslatedMessage(to: "Portuguese")
            }
            
            Button("More Languages...") {
                showingSendTranslatedMenu = false
                languagePickerMode = .translateSend
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingLanguageQuickPicker = true
                }
            }
            
            Button("Cancel", role: .cancel) {
                showingSendTranslatedMenu = false
            }
        } message: {
            Text("Choose a language to translate your message to before sending")
        }
        .onAppear {
            viewModel.isChatActive = true
            viewModel.setupRealtimeListeners()
            Task {
                await viewModel.loadMessages()
            }
            // Set active conversation to prevent toasts for this chat
            toastManager.activeConversationId = viewModel.conversationId
            // Initialize message count tracking
            previousMessageCount = viewModel.messages.count
        }
        .onDisappear {
            viewModel.isChatActive = false
            // Clear active conversation when leaving
            toastManager.activeConversationId = nil
            
            // Clear typing status when leaving chat
            viewModel.clearTypingStatus()
            viewModel.stopTypingListener()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Track when app goes to background/foreground
            switch newPhase {
            case .active:
                viewModel.isChatActive = true
                Task {
                    // Mark messages as read when returning to foreground
                    await viewModel.markAllMessagesAsRead()
                }
            case .background, .inactive:
                viewModel.isChatActive = false
            @unknown default:
                break
            }
        }
        .navigationDestination(item: $selectedMessageForThread) { message in
            if let currentUserId = viewModel.currentUserId {
                ThreadView(
                    parentMessage: message,
                    conversationId: viewModel.conversationId,
                    currentUserId: currentUserId,
                    participantDetails: viewModel.conversation?.participantDetails ?? [:]
                )
            }
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(image: $viewModel.selectedImage, isPresented: $viewModel.showingImagePicker)
        }
        .fullScreenCover(isPresented: $viewModel.showingVoiceRecorder) {
            VoiceRecorderView(
                voiceService: viewModel.voiceService,
                onSend: {
                    Task {
                        await viewModel.sendVoiceMessage()
                    }
                },
                onCancel: {
                    viewModel.voiceService.cancelRecording()
                    viewModel.showingVoiceRecorder = false
                }
            )
        }
        .onChange(of: viewModel.selectedImage) { _, newImage in
            if let image = newImage {
                Task {
                    await viewModel.sendImageMessage(image)
                    viewModel.selectedImage = nil
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Messages List
    
    private var messagesList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            VStack(spacing: 8) {
                                // Date separator
                                if viewModel.shouldShowDateSeparator(for: index) {
                                    dateSeparator(for: message)
                                }
                                
                                // Message row - Phase 4.5: Show sender names in groups
                                MessageRow(
                                    message: message,
                                    currentUserId: viewModel.currentUserId ?? "",
                                    isGroupChat: viewModel.isGroupChat,
                                    participantDetails: viewModel.conversation?.participantDetails ?? [:],
                                    onDelete: {
                                        Task {
                                            await viewModel.deleteMessage(message)
                                        }
                                    },
                                    onReact: { emoji in
                                        Task {
                                            await viewModel.addReaction(to: message, emoji: emoji)
                                        }
                                    },
                                    onEdit: {
                                        viewModel.startEditing(message)
                                    },
                                    onReplyInThread: {
                                        // If this is a thread reply, navigate to the parent thread
                                        if let parentId = message.replyTo {
                                            // Find the parent message
                                            if let parentMessage = viewModel.messages.first(where: { $0.id == parentId }) {
                                                selectedMessageForThread = parentMessage
                                            }
                                        } else {
                                            // This is a parent message, navigate to its thread
                                            selectedMessageForThread = message
                                        }
                                    },
                                    autoTranslateEnabled: viewModel.autoTranslateEnabled,
                                    translatedText: message.id != nil ? viewModel.translatedMessages[message.id!] : nil,
                                    senderTimezone: viewModel.participantTimezones[message.senderId],
                                    currentUserTimezone: viewModel.currentUserId != nil ? viewModel.participantTimezones[viewModel.currentUserId!] : nil
                                )
                                .id(message.id)
                            }
                        }
                        
                        // Invisible anchor at the very bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .padding(.top, 8)
            }
            .refreshable {
                await viewModel.loadMessages()
                await viewModel.fetchParticipantTimezones()
                HapticManager.shared.success()
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                // Always scroll to bottom when new messages arrive
                if newCount > previousMessageCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollToBottom(scrollProxy)
                    }
                }
                previousMessageCount = newCount
            }
            .onChange(of: shouldScrollToBottom) { _, newValue in
                // Scroll to bottom when returning from thread
                if newValue {
                    scrollToBottom(scrollProxy)
                    shouldScrollToBottom = false
                }
            }
            .onChange(of: selectedMessageForThread) { oldValue, newValue in
                // When returning from thread (newValue becomes nil)
                if oldValue != nil && newValue == nil {
                    shouldScrollToBottom = true
                }
            }
            .task {
                // Scroll to bottom on initial load with delay
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                scrollToBottom(scrollProxy)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func scrollToBottom(_ scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
    
    // MARK: - Toolbar Components
    
    @ViewBuilder
    private var navigationTitleView: some View {
        if viewModel.isGroupChat {
            Button(action: { showingGroupInfo = true }) {
                VStack(spacing: 1) {
                    Text(viewModel.conversationTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text("\(viewModel.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: 200)
            }
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(viewModel.conversationTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if viewModel.otherUserStatus == .online {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                
                // Phase 18: Timezone difference display
                if let timezoneText = otherUserTimezoneText {
                    Text(timezoneText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Phase 18: Calculate timezone difference text for other user
    private var otherUserTimezoneText: String? {
        guard let currentUserId = viewModel.currentUserId,
              let otherUserTimezone = viewModel.participantTimezones[viewModel.otherUserId],
              let currentUserTimezone = viewModel.participantTimezones[currentUserId],
              let otherTZ = TimeZone(identifier: otherUserTimezone),
              let currentTZ = TimeZone(identifier: currentUserTimezone) else {
            return nil
        }
        
        let currentOffset = currentTZ.secondsFromGMT() / 3600
        let otherOffset = otherTZ.secondsFromGMT() / 3600
        let difference = otherOffset - currentOffset
        
        // Check if offsets are the same (more reliable than timezone equality)
        if difference == 0 {
            return "Same timezone"
        } else if difference > 0 {
            return "\(difference) hour\(difference == 1 ? "" : "s") ahead"
        } else {
            return "\(abs(difference)) hour\(abs(difference) == 1 ? "" : "s") behind"
        }
    }
    
    @ViewBuilder
    private var trailingToolbarButtons: some View {
        HStack(spacing: 16) {
            // Primary actions - visible
            translationButton
            aiAssistantButton
            
            if !viewModel.isGroupChat && !viewModel.otherUserId.isEmpty {
                callButtons
            }
            
            // Group chat info
            if viewModel.isGroupChat {
                groupInfoButton
            }
            
            // More menu (Extract Data)
            Button {
                showingExtractedData = true
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // Phase 17: Data Extraction Button
    private var dataExtractionButton: some View {
        Button {
            showingExtractedData = true
            HapticManager.shared.selection()
        } label: {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(.blue)
        }
        .accessibilityLabel("Extract Data")
        .accessibilityHint("Extract structured data from conversation")
    }
    
    private var translationButton: some View {
        Button {
            viewModel.toggleAutoTranslation()
            HapticManager.shared.selection()
        } label: {
            Image(systemName: "translate")
                .foregroundColor(viewModel.autoTranslateEnabled ? .blue : .gray)
                .symbolEffect(.bounce, value: viewModel.autoTranslateEnabled)
        }
        .help("Auto-translate messages")
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    HapticManager.shared.medium()
                    languagePickerMode = .preference
                    showingLanguageQuickPicker = true
                }
        )
    }
    
    private var aiAssistantButton: some View {
        Button {
            showingAIAssistant = true
        } label: {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
        }
    }
    
    private var groupInfoButton: some View {
        Button {
            showingGroupInfo = true
        } label: {
            Image(systemName: "info.circle")
        }
    }
    
    @ViewBuilder
    private var callButtons: some View {
        // Voice call button
        Button {
            if networkMonitor.isConnected {
                callViewModel.startAudioCall(to: viewModel.otherUserId)
            }
        } label: {
            Image(systemName: "phone.fill")
                .foregroundColor(networkMonitor.isConnected ? .primary : .gray)
        }
        .disabled(!networkMonitor.isConnected)
        
        // Video call button - commented out (function preserved in code)
        // Uncomment the block below to re-enable video calling
        /*
        Button {
            if networkMonitor.isConnected {
                callViewModel.startVideoCall(to: viewModel.otherUserId)
            }
        } label: {
            Image(systemName: "video.fill")
                .foregroundColor(networkMonitor.isConnected ? .primary : .gray)
        }
        .disabled(!networkMonitor.isConnected)
        */
    }
    
    // MARK: - Date Separator
    
    private func dateSeparator(for message: Message) -> some View {
        Text(viewModel.dateSeparatorText(for: message))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.isGroupChat ? "person.3" : "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No messages yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            if viewModel.isGroupChat {
                Text("Start the conversation!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Text("Say hi to \(viewModel.conversationTitle)!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Functions
    
    /// Translates the current message and sends it
    /// - Parameter targetLanguage: The language to translate to
    private func sendTranslatedMessage(to targetLanguage: String) {
        guard !viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let originalText = viewModel.messageText
        
        Task {
            isTranslatingSend = true
            
            do {
                // Call translation service
                let translationService = TranslationService.shared
                let result = try await translationService.translateText(
                    text: originalText,
                    targetLanguage: targetLanguage
                )
                
                // Replace message text with translated version
                await MainActor.run {
                    viewModel.messageText = result.translatedText
                }
                
                // Send the translated message
                HapticManager.shared.messageSent()
                SoundManager.shared.messageSent()
                
                await viewModel.sendMessage()
                
                // Re-focus after sending
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isInputFocused = true
                    isTranslatingSend = false
                }
                
            } catch {
                print("Translation error: \(error)")
                // Show error through view model
                await MainActor.run {
                    viewModel.errorMessage = "Failed to translate message: \(error.localizedDescription)"
                    isTranslatingSend = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            conversationId: "conv123",
            otherUserId: "user456",
            otherUserName: "Alice"
        )
        .environmentObject(ToastManager())
        .environmentObject(CallViewModel())
    }
}

