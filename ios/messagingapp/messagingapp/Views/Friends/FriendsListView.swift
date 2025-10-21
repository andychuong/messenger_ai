//
//  FriendsListView.swift
//  messagingapp
//
//  Created on October 21, 2025.
//

import SwiftUI

struct FriendsListView: View {
    @StateObject private var viewModel = FriendsListViewModel()
    @State private var showingAddFriend = false
    @State private var showingFriendRequests = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search friends...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Friend Requests Badge
                if !viewModel.pendingRequests.isEmpty {
                    Button(action: { showingFriendRequests = true }) {
                        HStack {
                            Image(systemName: "person.2.badge.gearshape")
                                .foregroundColor(.blue)
                            
                            Text("\(viewModel.pendingRequests.count) pending request\(viewModel.pendingRequests.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                
                // Friends List
                if viewModel.isLoading && viewModel.friends.isEmpty {
                    Spacer()
                    ProgressView("Loading friends...")
                    Spacer()
                } else if viewModel.friends.isEmpty {
                    // Empty State
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Friends Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add friends to start messaging")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingAddFriend = true }) {
                            Label("Add Friend", systemImage: "person.badge.plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filteredFriends, id: \.0.id) { friendship, user in
                            FriendRow(user: user, friendship: friendship, viewModel: viewModel)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showingFriendRequests) {
                FriendRequestsView(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.loadFriends()
                await viewModel.loadPendingRequests()
            }
            .task {
                await viewModel.loadFriends()
                await viewModel.loadPendingRequests()
            }
        }
    }
}

struct FriendRow: View {
    let user: User
    let friendship: Friendship
    @ObservedObject var viewModel: FriendsListViewModel
    @State private var showingActionSheet = false
    
    var body: some View {
        Button(action: {
            // TODO: Navigate to chat with this friend
        }) {
            HStack(spacing: 16) {
                // Profile Picture with online status
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.title3)
                                .foregroundColor(.white)
                        )
                    
                    // Online status indicator
                    Circle()
                        .fill(user.status == .online ? Color.green : Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // More options button
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Friend Options", isPresented: $showingActionSheet) {
            Button("Message", role: .none) {
                // TODO: Navigate to chat
            }
            
            Button("Remove Friend", role: .destructive) {
                Task {
                    await viewModel.removeFriend(friendship)
                }
            }
            
            Button("Block User", role: .destructive) {
                Task {
                    await viewModel.blockUser(friendship)
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var statusText: String {
        switch user.status {
        case .online:
            return "Online"
        case .offline:
            if let lastSeen = user.lastSeen {
                return "Last seen \(timeAgo(from: lastSeen))"
            }
            return "Offline"
        case .away:
            return "Away"
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            if days == 1 {
                return "yesterday"
            } else if days < 7 {
                return "\(days)d ago"
            } else {
                let weeks = days / 7
                return "\(weeks)w ago"
            }
        }
    }
}

#Preview {
    FriendsListView()
}

