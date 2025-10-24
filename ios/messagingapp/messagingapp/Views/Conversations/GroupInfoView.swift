//
//  GroupInfoView.swift
//  messagingapp
//
//  Phase 4.5: Group Chat - Group Info & Management
//

import SwiftUI
import FirebaseAuth

struct GroupInfoView: View {
    let conversation: Conversation
    @Environment(\.dismiss) var dismiss
    
    private let conversationService = ConversationService()
    private let messageService = MessageService()
    
    @State private var members: [User] = []
    @State private var isLoading = true
    @State private var showEditSheet = false
    @State private var showAddMembersSheet = false
    @State private var showLeaveAlert = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var isAdmin: Bool {
        guard let userId = currentUserId else { return false }
        return conversation.isAdmin(userId: userId)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Group Header Section
                Section {
                    VStack(spacing: 16) {
                        // Group avatar
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.blue)
                            )
                        
                        // Group name
                        Text(conversation.title(currentUserId: currentUserId ?? ""))
                            .font(.title2)
                            .bold()
                        
                        // Member count
                        Text("\(conversation.memberCount) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Edit button (admin only)
                        if isAdmin {
                            Button(action: { showEditSheet = true }) {
                                Label("Edit Group Info", systemImage: "pencil")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
                
                // Members Section
                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(members) { member in
                            MemberRow(
                                member: member,
                                isAdmin: conversation.isAdmin(userId: member.id ?? ""),
                                canRemove: isAdmin && member.id != currentUserId
                            ) {
                                removeMember(member)
                            }
                        }
                    }
                } header: {
                    Text("Members")
                }
                
                // Add Members (admin only)
                if isAdmin {
                    Section {
                        Button(action: { showAddMembersSheet = true }) {
                            Label("Add Members", systemImage: "person.badge.plus")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Actions Section
                Section {
                    Button(action: { showLeaveAlert = true }) {
                        Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Leave Group", isPresented: $showLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    leaveGroup()
                }
            } message: {
                Text("Are you sure you want to leave this group? You won't be able to see messages from this group anymore.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showEditSheet) {
                EditGroupView(conversation: conversation) {
                    // Reload when edit is complete
                    loadMembers()
                }
            }
            .sheet(isPresented: $showAddMembersSheet) {
                AddMembersToGroupView(conversation: conversation) {
                    // Reload when members are added
                    loadMembers()
                }
            }
        }
        .onAppear {
            loadMembers()
        }
    }
    
    private func loadMembers() {
        isLoading = true
        Task {
            do {
                members = try await conversationService.fetchGroupMembers(conversationId: conversation.id ?? "")
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    private func removeMember(_ member: User) {
        Task {
            do {
                guard let conversationId = conversation.id,
                      let memberId = member.id,
                      Auth.auth().currentUser != nil else { return }
                
                try await conversationService.removeMemberFromGroup(
                    conversationId: conversationId,
                    userId: memberId
                )
                
                // Send system message
                try await messageService.sendMemberRemovedMessage(
                    conversationId: conversationId,
                    memberName: member.displayName
                )
                
                loadMembers()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func leaveGroup() {
        Task {
            do {
                guard let conversationId = conversation.id,
                      let currentUser = Auth.auth().currentUser else { return }
                
                let userName = currentUser.displayName ?? "User"
                
                // Send system message before leaving
                try await messageService.sendMemberLeftMessage(
                    conversationId: conversationId,
                    memberName: userName
                )
                
                try await conversationService.leaveGroup(conversationId: conversationId)
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: User
    let isAdmin: Bool
    let canRemove: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(member.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                )
            
            // Name and admin badge
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.displayName)
                        .font(.body)
                    
                    if isAdmin {
                        Text("Admin")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                Text(member.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Remove button (admin only, can't remove self)
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Group View

struct EditGroupView: View {
    let conversation: Conversation
    var onComplete: (() -> Void)?
    
    @Environment(\.dismiss) var dismiss
    private let conversationService = ConversationService()
    private let messageService = MessageService()
    
    @State private var groupName: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    init(conversation: Conversation, onComplete: (() -> Void)? = nil) {
        self.conversation = conversation
        self.onComplete = onComplete
        _groupName = State(initialValue: conversation.groupName ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Group Name", text: $groupName)
                        .autocapitalization(.words)
                } header: {
                    Text("Group Name")
                }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(groupName.isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Failed to update group")
            }
        }
    }
    
    private func saveChanges() {
        isLoading = true
        Task {
            do {
                guard let conversationId = conversation.id else { return }
                
                try await conversationService.updateGroupName(
                    conversationId: conversationId,
                    name: groupName
                )
                
                // Send system message
                if Auth.auth().currentUser != nil {
                    try await messageService.sendGroupNameChangedMessage(
                        conversationId: conversationId,
                        newName: groupName
                    )
                }
                
                isLoading = false
                onComplete?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

// MARK: - Add Members to Group View

struct AddMembersToGroupView: View {
    let conversation: Conversation
    var onComplete: (() -> Void)?
    
    @Environment(\.dismiss) var dismiss
    private let friendsService = FriendshipService()
    private let conversationService = ConversationService()
    private let messageService = MessageService()
    
    @State private var availableFriends: [User] = []
    @State private var selectedFriends: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading friends...")
                } else if availableFriends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No friends available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("All your friends are already in this group")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(availableFriends) { friend in
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
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addMembers()
                    }
                    .disabled(selectedFriends.isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Failed to add members")
            }
        }
        .onAppear {
            loadAvailableFriends()
        }
    }
    
    private func loadAvailableFriends() {
        isLoading = true
        Task {
            do {
                let friendships = try await friendsService.fetchFriends()
                let allFriends = friendships.map { $0.1 } // Extract User from (Friendship, User) tuple
                // Filter out friends who are already in the group
                availableFriends = allFriends.filter { friend in
                    !conversation.participants.contains(friend.id ?? "")
                }
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
    
    private func addMembers() {
        guard !selectedFriends.isEmpty else { return }
        
        isLoading = true
        Task {
            do {
                guard let conversationId = conversation.id else { return }
                
                let memberIds = Array(selectedFriends)
                try await conversationService.addMembersToGroup(
                    conversationId: conversationId,
                    userIds: memberIds
                )
                
                // Send system messages for each added member
                if Auth.auth().currentUser != nil {
                    for memberId in memberIds {
                        if let friend = availableFriends.first(where: { $0.id == memberId }) {
                            try await messageService.sendMemberAddedMessage(
                                conversationId: conversationId,
                                memberName: friend.displayName
                            )
                        }
                    }
                }
                
                isLoading = false
                onComplete?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GroupInfoView(conversation: Conversation(
        id: "1",
        participants: ["user1", "user2", "user3"],
        participantDetails: [:],
        type: .group,
        unreadCount: [:],
        createdAt: Date(),
        updatedAt: Date(),
        groupName: "Study Group",
        admins: ["user1"]
    ))
}

