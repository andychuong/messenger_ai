//
//  ChatView.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMessageForThread: Message?
    @State private var shouldScrollToBottom = false
    @State private var showingGroupInfo = false
    
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
            
            // Input bar
            MessageInputBar(
                text: $viewModel.messageText,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
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
                    // Group info button for groups
                    if viewModel.isGroupChat {
                        Button {
                            showingGroupInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                    
                    // Voice call button (Phase 5)
                    Button {
                        // Will implement in Phase 5
                    } label: {
                        Image(systemName: "phone.fill")
                    }
                    .disabled(true)
                    
                    // Video call button (Phase 5)
                    Button {
                        // Will implement in Phase 5
                    } label: {
                        Image(systemName: "video.fill")
                    }
                    .disabled(true)
                }
            }
        }
        .sheet(isPresented: $showingGroupInfo) {
            if let conversation = viewModel.conversation {
                GroupInfoView(conversation: conversation)
            }
        }
        .onAppear {
            viewModel.setupRealtimeListeners()
            Task {
                await viewModel.loadMessages()
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
    }
}

