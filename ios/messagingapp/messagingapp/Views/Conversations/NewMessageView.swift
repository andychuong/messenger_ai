//
//  NewMessageView.swift
//  messagingapp
//
//  Friend selector for starting new conversations
//

import SwiftUI

struct NewMessageView: View {
    @StateObject private var friendsViewModel = FriendsListViewModel()
    @StateObject private var conversationViewModel = ConversationListViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var isCreatingConversation = false
    @State private var selectedConversation: Conversation?
    @State private var navigateToChat = false
    @State private var showingCreateGroup = false  // Phase 4.5
    
    var body: some View {
        NavigationStack {
            ZStack {
                if friendsViewModel.isLoading && friendsViewModel.friends.isEmpty {
                    ProgressView("Loading friends...")
                } else if friendsViewModel.friends.isEmpty {
                    emptyStateView
                } else {
                    friendsList
                }
                
                if isCreatingConversation {
                    ProgressView("Opening chat...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search friends")
            .task {
                await friendsViewModel.loadFriends()
            }
            .navigationDestination(isPresented: $navigateToChat) {
                if let conversation = selectedConversation {
                    ChatView(conversation: conversation)
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { conversation in
                    selectedConversation = conversation
                    navigateToChat = true
                }
            }
        }
    }
    
    // MARK: - Friends List
    
    private var friendsList: some View {
        List {
            // Phase 4.5: Create Group Button
            Section {
                Button {
                    showingCreateGroup = true
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.3.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create Group")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text("Start a group conversation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Direct message friends list
            Section {
                ForEach(filteredFriends, id: \.0.id) { friendship, user in
                    Button {
                        Task {
                            await openChat(with: user)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Profile picture
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(user.displayName.prefix(1).uppercased())
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    )
                                
                                // Online status
                                if user.status == .online {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                }
                            }
                            
                            // User details
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Friends")
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Friends Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add friends to start messaging")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                dismiss()
            } label: {
                Text("Go to Friends")
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
    
    // MARK: - Filtered Friends
    
    private var filteredFriends: [(Friendship, User)] {
        if searchText.isEmpty {
            return friendsViewModel.friends
        } else {
            return friendsViewModel.friends.filter { _, user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Open Chat
    
    private func openChat(with user: User) async {
        guard let userId = user.id else { return }
        
        isCreatingConversation = true
        
        if let conversation = await conversationViewModel.getOrCreateConversation(
            with: userId,
            userName: user.displayName,
            userEmail: user.email
        ) {
            selectedConversation = conversation
            navigateToChat = true
        }
        
        isCreatingConversation = false
    }
}

#Preview {
    NewMessageView()
}

