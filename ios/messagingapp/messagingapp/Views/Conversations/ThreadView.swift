//
//  ThreadView.swift
//  messagingapp
//
//  Phase 4: Rich Messaging Features - Message Threading
//

import SwiftUI
import FirebaseFirestore
import Combine

struct ThreadView: View {
    let parentMessage: Message
    let conversationId: String
    @StateObject private var viewModel: ThreadViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(parentMessage: Message, conversationId: String, currentUserId: String) {
        self.parentMessage = parentMessage
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ThreadViewModel(
            parentMessage: parentMessage,
            conversationId: conversationId,
            currentUserId: currentUserId
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Thread header with parent message
            parentMessageHeader
            
            Divider()
            
            // Thread replies
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if viewModel.replies.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(viewModel.replies) { reply in
                                MessageRow(
                                    message: reply,
                                    currentUserId: viewModel.currentUserId,
                                    showThreadIndicators: false,
                                    onDelete: {
                                        Task {
                                            await viewModel.deleteReply(reply)
                                        }
                                    },
                                    onReact: { emoji in
                                        Task {
                                            await viewModel.addReaction(to: reply, emoji: emoji)
                                        }
                                    }
                                )
                                .id(reply.id)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .onChange(of: viewModel.replies.count) { _, _ in
                    if let lastReply = viewModel.replies.last {
                        withAnimation {
                            scrollProxy.scrollTo(lastReply.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Reply input bar
            MessageInputBar(
                text: $viewModel.replyText,
                onSend: {
                    Task {
                        await viewModel.sendReply()
                    }
                },
                isSending: viewModel.isSending
            )
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setupListener()
            Task {
                await viewModel.loadReplies()
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
    
    // MARK: - Parent Message Header
    
    private var parentMessageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Thread")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble")
                        .font(.caption2)
                    Text("\(viewModel.replies.count) \(viewModel.replies.count == 1 ? "reply" : "replies")")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Text("Original message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                
                MessageRow(
                    message: parentMessage,
                    currentUserId: viewModel.currentUserId,
                    showThreadIndicators: false,
                    onDelete: {},
                    onReact: { _ in }
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No replies yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Start the conversation!")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Thread ViewModel

@MainActor
class ThreadViewModel: ObservableObject {
    @Published var replies: [Message] = []
    @Published var replyText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    
    let parentMessage: Message
    let conversationId: String
    let currentUserId: String
    
    private let messageService = MessageService()
    private var repliesListener: ListenerRegistration?
    
    init(parentMessage: Message, conversationId: String, currentUserId: String) {
        self.parentMessage = parentMessage
        self.conversationId = conversationId
        self.currentUserId = currentUserId
    }
    
    deinit {
        repliesListener?.remove()
    }
    
    // MARK: - Setup
    
    func setupListener() {
        guard let parentMessageId = parentMessage.id else { return }
        
        repliesListener = messageService.listenToThreadReplies(
            conversationId: conversationId,
            parentMessageId: parentMessageId
        ) { [weak self] messages in
            Task { @MainActor in
                self?.replies = messages
            }
        }
    }
    
    // MARK: - Load Replies
    
    func loadReplies() async {
        guard let parentMessageId = parentMessage.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            replies = try await messageService.fetchThreadReplies(
                conversationId: conversationId,
                parentMessageId: parentMessageId
            )
        } catch {
            errorMessage = "Failed to load replies: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Send Reply
    
    func sendReply() async {
        guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard let parentMessageId = parentMessage.id else {
            errorMessage = "Invalid parent message"
            return
        }
        
        let textToSend = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        replyText = ""
        
        isSending = true
        errorMessage = nil
        
        do {
            let reply = try await messageService.sendThreadReply(
                conversationId: conversationId,
                parentMessageId: parentMessageId,
                text: textToSend
            )
            
            // Optimistically add to replies
            if !replies.contains(where: { $0.id == reply.id }) {
                replies.append(reply)
            }
        } catch {
            errorMessage = "Failed to send reply: \(error.localizedDescription)"
            replyText = textToSend
        }
        
        isSending = false
    }
    
    // MARK: - Delete Reply
    
    func deleteReply(_ reply: Message) async {
        guard let messageId = reply.id else { return }
        
        do {
            try await messageService.deleteMessage(conversationId: conversationId, messageId: messageId)
            replies.removeAll { $0.id == messageId }
        } catch {
            errorMessage = "Failed to delete reply: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Reactions
    
    func addReaction(to reply: Message, emoji: String) async {
        guard let messageId = reply.id else { return }
        
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
}

#Preview {
    NavigationStack {
        ThreadView(
            parentMessage: Message(
                id: "msg1",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Alice",
                text: "Let's discuss the project timeline",
                timestamp: Date(),
                status: .read,
                type: .text
            ),
            conversationId: "conv1",
            currentUserId: "user2"
        )
    }
}

