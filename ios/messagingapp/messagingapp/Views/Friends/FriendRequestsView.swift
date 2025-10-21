//
//  FriendRequestsView.swift
//  messagingapp
//
//  Created on October 21, 2025.
//

import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: FriendsListViewModel
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.pendingRequests.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Friend Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("When someone sends you a friend request, it will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    // List of Requests
                    List {
                        ForEach(viewModel.pendingRequests, id: \.0.id) { friendship, user in
                            FriendRequestRow(
                                user: user,
                                friendship: friendship,
                                onAccept: {
                                    Task {
                                        await viewModel.acceptFriendRequest(friendship)
                                    }
                                },
                                onDecline: {
                                    Task {
                                        await viewModel.declineFriendRequest(friendship)
                                    }
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FriendRequestRow: View {
    let user: User
    let friendship: Friendship
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Picture
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.title3)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(timeAgo(from: friendship.requestedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                // Decline Button
                Button(action: {
                    isProcessing = true
                    onDecline()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .disabled(isProcessing)
                
                // Accept Button
                Button(action: {
                    isProcessing = true
                    onAccept()
                }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    FriendRequestsView(viewModel: FriendsListViewModel())
}


