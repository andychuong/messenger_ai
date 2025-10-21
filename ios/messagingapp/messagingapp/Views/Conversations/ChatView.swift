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
    
    init(conversationId: String, otherUserId: String, otherUserName: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            otherUserId: otherUserId,
            otherUserName: otherUserName
        ))
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
                isSending: viewModel.isSending
            )
        }
        .navigationTitle(viewModel.otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
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
        .onAppear {
            viewModel.setupRealtimeListeners()
            Task {
                await viewModel.loadMessages()
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
                                
                                // Message row
                                MessageRow(
                                    message: message,
                                    currentUserId: viewModel.currentUserId ?? "",
                                    onDelete: {
                                        Task {
                                            await viewModel.deleteMessage(message)
                                        }
                                    },
                                    onReact: { emoji in
                                        Task {
                                            await viewModel.addReaction(to: message, emoji: emoji)
                                        }
                                    }
                                )
                                .id(message.id)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // Scroll to bottom when new message arrives
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Scroll to bottom on initial load
                if let lastMessage = viewModel.messages.last {
                    scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
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
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No messages yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Say hi to \(viewModel.otherUserName)!")
                .font(.subheadline)
                .foregroundColor(.gray)
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

