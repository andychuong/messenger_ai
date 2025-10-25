//
//  CreateGroupView.swift
//  messagingapp
//
//  Phase 4.5: Group Chat - Create Group UI
//

import SwiftUI
import FirebaseAuth

struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    private let friendsService = FriendshipService()
    @StateObject private var conversationService = ConversationService()
    @StateObject private var messageService = MessageService()
    
    @State private var friends: [User] = []
    @State private var selectedFriends: Set<String> = []
    @State private var groupName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Callback when group is created
    var onGroupCreated: ((Conversation) -> Void)?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Group name input section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter group name", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Selected friends section
                if !selectedFriends.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected (\(selectedFriends.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(friends.filter { selectedFriends.contains($0.id ?? "") }) { friend in
                                    SelectedFriendChip(friend: friend) {
                                        selectedFriends.remove(friend.id ?? "")
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    
                    Divider()
                }
                
                // Friends list
                if isLoading {
                    Spacer()
                    ProgressView("Loading friends...")
                    Spacer()
                } else if friends.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No friends available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add friends to create a group")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(friends) { friend in
                            FriendSelectionRow(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id ?? "")
                            ) {
                                toggleSelection(friendId: friend.id ?? "")
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(selectedFriends.count < 2 || isLoading)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Failed to create group")
            }
        }
        .onAppear {
            loadFriends()
        }
    }
    
    private func loadFriends() {
        isLoading = true
        Task {
            do {
                let friendships = try await friendsService.fetchFriends()
                friends = friendships.map { $0.1 } // Extract User from (Friendship, User) tuple
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    private func toggleSelection(friendId: String) {
        if selectedFriends.contains(friendId) {
            selectedFriends.remove(friendId)
        } else {
            selectedFriends.insert(friendId)
        }
    }
    
    private func createGroup() {
        guard selectedFriends.count >= 2 else {
            errorMessage = "Please select at least 2 friends"
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                let memberIds = Array(selectedFriends)
                let conversation = try await conversationService.createGroupConversation(
                    memberIds: memberIds,
                    groupName: groupName.isEmpty ? nil : groupName
                )
                
                // Send system message
                if let currentUserId = Auth.auth().currentUser?.uid {
                    // Get current user name from the conversation participant details
                    let userName = conversation.participantDetails[currentUserId]?.name ?? "User"
                    
                    try await messageService.sendGroupCreatedMessage(
                        conversationId: conversation.id ?? "",
                        creatorName: userName
                    )
                }
                
                isLoading = false
                onGroupCreated?(conversation)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

// MARK: - Friend Selection Row

struct FriendSelectionRow: View {
    let friend: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(friend.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                
                // Name and email
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(friend.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Selected Friend Chip

struct SelectedFriendChip: View {
    let friend: User
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(friend.displayName.prefix(1).uppercased())
                        .font(.caption2)
                        .foregroundColor(.blue)
                )
            
            Text(friend.displayName)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    CreateGroupView()
}

