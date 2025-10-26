//
//  FriendsListViewModel.swift
//  messagingapp
//
//  Created on October 21, 2025.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FriendsListViewModel: ObservableObject {
    @Published var friends: [(Friendship, User)] = []
    @Published var pendingRequests: [(Friendship, User)] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    
    private let friendshipService = FriendshipService()
    private var friendsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private var userStatusListeners: [String: ListenerRegistration] = [:]
    private let db = Firestore.firestore()
    
    var filteredFriends: [(Friendship, User)] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { _, user in
            user.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    init() {
        setupRealtimeListeners()
    }
    
    deinit {
        friendsListener?.remove()
        requestsListener?.remove()
        userStatusListeners.values.forEach { $0.remove() }
    }
    
    // MARK: - Real-time Listeners
    
    func setupRealtimeListeners() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen for changes to friendships involving current user
        friendsListener = db.collection("friendships")
            .whereField("userId1", isEqualTo: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    await self?.handleFriendshipsUpdate()
                }
            }
        
        // Also listen for friendships where user is userId2
        requestsListener = db.collection("friendships")
            .whereField("userId2", isEqualTo: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    await self?.handleFriendshipsUpdate()
                }
            }
    }
    
    private func handleFriendshipsUpdate() async {
        await loadFriends()
        await loadPendingRequests()
    }
    
    // MARK: - Load Friends
    
    func loadFriends() async {
        isLoading = true
        errorMessage = nil
        
        do {
            friends = try await friendshipService.fetchFriends()
            // Sort by display name
            friends.sort { $0.1.displayName < $1.1.displayName }
            
            // Set up status listeners for each friend
            setupUserStatusListeners()
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading friends: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - User Status Listeners
    
    private func setupUserStatusListeners() {
        // Remove old listeners
        userStatusListeners.values.forEach { $0.remove() }
        userStatusListeners.removeAll()
        
        print("👥 Friends: Setting up real-time listeners for \(friends.count) friend(s)")
        
        // Set up listener for each friend
        for (_, user) in friends {
            guard let userId = user.id else { continue }
            
            let listener = db.collection("users")
                .document(userId)
                .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                    guard let self = self,
                          let snapshot = snapshot,
                          !snapshot.metadata.isFromCache, // Ignore cached data
                          !snapshot.metadata.hasPendingWrites else { // Ignore local writes
                        return
                    }
                    
                    guard let updatedUser = try? snapshot.data(as: User.self) else {
                        print("❌ Friends: Failed to decode user data for \(userId)")
                        return
                    }
                    
                    Task { @MainActor in
                        // Update the entire user object in our friends array
                        if let index = self.friends.firstIndex(where: { $0.1.id == userId }) {
                            let oldUser = self.friends[index].1
                            
                            // Check if anything changed
                            let statusChanged = oldUser.status != updatedUser.status
                            let photoChanged = oldUser.photoURL != updatedUser.photoURL
                            let nameChanged = oldUser.displayName != updatedUser.displayName
                            
                            if statusChanged || photoChanged || nameChanged {
                                print("🔄 Friends: User data updated for \(updatedUser.displayName)")
                                if statusChanged {
                                    print("   📍 Status: \(oldUser.status.rawValue) → \(updatedUser.status.rawValue)")
                                }
                                if photoChanged {
                                    print("   🖼️ Photo: \(oldUser.photoURL ?? "nil") → \(updatedUser.photoURL ?? "nil")")
                                }
                                if nameChanged {
                                    print("   ✏️ Name: \(oldUser.displayName) → \(updatedUser.displayName)")
                                }
                                
                                // Create a new array to trigger SwiftUI update
                                var updatedFriends = self.friends
                                updatedFriends[index].1 = updatedUser
                                self.friends = updatedFriends
                                
                                print("✅ Friends: UI refreshed for \(updatedUser.displayName)")
                            }
                        }
                    }
                }
            
            userStatusListeners[userId] = listener
        }
    }
    
    // MARK: - Load Pending Requests
    
    func loadPendingRequests() async {
        do {
            pendingRequests = try await friendshipService.fetchPendingRequests()
            // Sort by request date, newest first
            pendingRequests.sort { $0.0.requestedAt > $1.0.requestedAt }
        } catch {
            print("Error loading pending requests: \(error)")
        }
    }
    
    // MARK: - Accept Friend Request
    
    func acceptFriendRequest(_ friendship: Friendship) async {
        guard let friendshipId = friendship.id else { return }
        
        do {
            try await friendshipService.acceptFriendRequest(friendshipId: friendshipId)
            // Remove from pending list
            pendingRequests.removeAll { $0.0.id == friendshipId }
            // Refresh friends list
            await loadFriends()
        } catch {
            errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Decline Friend Request
    
    func declineFriendRequest(_ friendship: Friendship) async {
        guard let friendshipId = friendship.id else { return }
        
        do {
            try await friendshipService.declineFriendRequest(friendshipId: friendshipId)
            // Remove from pending list
            pendingRequests.removeAll { $0.0.id == friendshipId }
        } catch {
            errorMessage = "Failed to decline friend request: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Remove Friend
    
    func removeFriend(_ friendship: Friendship) async {
        guard let friendshipId = friendship.id else { return }
        
        do {
            try await friendshipService.removeFriend(friendshipId: friendshipId)
            // Remove from friends list
            friends.removeAll { $0.0.id == friendshipId }
        } catch {
            errorMessage = "Failed to remove friend: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Block User
    
    func blockUser(_ friendship: Friendship) async {
        guard let friendshipId = friendship.id else { return }
        
        do {
            try await friendshipService.blockUser(friendshipId: friendshipId)
            // Remove from friends list
            friends.removeAll { $0.0.id == friendshipId }
        } catch {
            errorMessage = "Failed to block user: \(error.localizedDescription)"
        }
    }
}


