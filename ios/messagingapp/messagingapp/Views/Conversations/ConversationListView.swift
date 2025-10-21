//
//  ConversationListView.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingNewChat = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                } else if viewModel.filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    conversationListContent
                }
            }
            .navigationTitle("Messages")
            .searchable(text: $viewModel.searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .refreshable {
                await viewModel.loadConversations()
            }
            .sheet(isPresented: $showingNewChat) {
                NewMessageView()
            }
        }
    }
    
    // MARK: - Conversation List Content
    
    private var conversationListContent: some View {
        List {
            ForEach(viewModel.filteredConversations) { conversation in
                NavigationLink {
                    // Phase 4.5: Use conversation-based initializer for both direct and group chats
                    ChatView(conversation: conversation)
                        .onAppear {
                            Task {
                                await viewModel.markAsRead(conversation)
                            }
                        }
                } label: {
                    ConversationRow(conversation: conversation, currentUserId: viewModel.currentUserId ?? "")
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteConversation(conversation)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a conversation with your friends")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                showingNewChat = true
            } label: {
                Label("New Message", systemImage: "square.and.pencil")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String
    
    private var otherUser: ParticipantDetail? {
        conversation.otherParticipantDetails(currentUserId: currentUserId)
    }
    
    private var unreadCount: Int {
        conversation.unreadCountForUser(currentUserId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture - Phase 4.5: Different icon for groups
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Group {
                            if conversation.type == .group {
                                Image(systemName: "person.3.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            } else {
                                Text(conversation.title(currentUserId: currentUserId).prefix(1).uppercased())
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }
                    )
                
                // Online status indicator (only for direct chats)
                if conversation.type == .direct && otherUser?.status == "online" {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            
            // Conversation details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title(currentUserId: currentUserId))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let lastMessageTime = conversation.lastMessageTime {
                        Text(formatTimestamp(lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    // Phase 4.5: Show sender name in group last messages
                    if let lastMessage = conversation.lastMessage {
                        if conversation.type == .group {
                            Text("\(lastMessage.senderName): \(lastMessage.text)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        } else {
                            Text(lastMessage.text)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    } else {
                        Text("No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ConversationListView()
}

