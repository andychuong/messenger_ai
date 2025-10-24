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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMessageForThread: Message?
    @State private var shouldScrollToBottom = false
    @State private var showingGroupInfo = false
    @State private var showingAIAssistant = false
    @FocusState private var isInputFocused: Bool
    
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
            // Messages list
            messagesList
            
            // Typing indicator (positioned above input bar)
            if let typingText = viewModel.typingText {
                TypingIndicatorView(text: typingText)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: typingText)
            }
            
            // Input bar
            MessageInputBar(
                text: $viewModel.messageText,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                        // Re-focus after sending to keep keyboard open
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isInputFocused = true
                        }
                    }
                },
                isSending: viewModel.isSending,
                isEditing: viewModel.isEditingMessage,
                editingMessageText: viewModel.editingMessage?.text ?? "",
                onCancelEdit: {
                    viewModel.cancelEditing()
                },
                onImagePick: {
                    viewModel.showingImagePicker = true
                },
                onVoiceRecord: {
                    viewModel.showingVoiceRecorder = true
                }
            )
            .focused($isInputFocused)
            .onChange(of: viewModel.messageText) { oldValue, newValue in
                viewModel.handleTextChange()
            }
        }
        .navigationTitle(viewModel.conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Custom title with online indicator or group info
            ToolbarItem(placement: .principal) {
                if viewModel.isGroupChat {
                    // Group: Show name and member count
                    Button(action: { showingGroupInfo = true }) {
                        VStack(spacing: 2) {
                            Text(viewModel.conversationTitle)
                                .font(.headline)
                            Text("\(viewModel.memberCount) members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Direct chat: Show name with online indicator
                    HStack(spacing: 6) {
                        Text(viewModel.conversationTitle)
                            .font(.headline)
                        
                        if viewModel.otherUserStatus == .online {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // AI Assistant button
                    Button {
                        showingAIAssistant = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                    }
                    
                    // Group info button for groups
                    if viewModel.isGroupChat {
                        Button {
                            showingGroupInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                    
                    // Call buttons (only for direct conversations)
                    if !viewModel.isGroupChat, !viewModel.otherUserId.isEmpty {
                        // Voice call button
                        Button {
                            callViewModel.startAudioCall(to: viewModel.otherUserId)
                        } label: {
                            Image(systemName: "phone.fill")
                        }
                        
                        // Video call button
                        Button {
                            callViewModel.startVideoCall(to: viewModel.otherUserId)
                        } label: {
                            Image(systemName: "video.fill")
                        }
                    }
                }
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
        .onAppear {
            viewModel.isChatActive = true
            viewModel.setupRealtimeListeners()
            Task {
                await viewModel.loadMessages()
            }
            // Set active conversation to prevent toasts for this chat
            toastManager.activeConversationId = viewModel.conversationId
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
                    currentUserId: currentUserId
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
                                    }
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
            .defaultScrollAnchor(.bottom)
            .onChange(of: viewModel.messages.count) { _, _ in
                // Scroll to bottom when new message arrives
                scrollToBottom(scrollProxy)
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

