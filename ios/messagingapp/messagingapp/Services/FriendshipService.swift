//
//  FriendshipService.swift
//  messagingapp
//
//  Created on October 21, 2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FriendshipService {
    private let db = Firestore.firestore()
    
    // MARK: - Send Friend Request
    
    func sendFriendRequest(to email: String) async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Search for user by email
        let usersSnapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        guard let targetUser = usersSnapshot.documents.first else {
            throw NSError(domain: "FriendshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        let targetUserId = targetUser.documentID
        
        // Can't send friend request to yourself
        if targetUserId == currentUserId {
            throw NSError(domain: "FriendshipService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request to yourself"])
        }
        
        // Check if friendship already exists
        let existingFriendship = try await checkExistingFriendship(userId1: currentUserId, userId2: targetUserId)
        if let existing = existingFriendship {
            if existing.status == .accepted {
                throw NSError(domain: "FriendshipService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Already friends"])
            } else if existing.status == .pending {
                throw NSError(domain: "FriendshipService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Friend request already sent"])
            } else if existing.status == .blocked {
                throw NSError(domain: "FriendshipService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request"])
            }
        }
        
        // Create friendship document
        // Always store with smaller userId first for consistency
        let (userId1, userId2) = currentUserId < targetUserId ? (currentUserId, targetUserId) : (targetUserId, currentUserId)
        
        let friendship = Friendship(userId1: userId1, userId2: userId2, requestedBy: currentUserId)
        
        let docRef = try await db.collection("friendships").addDocument(from: friendship)
        
        return docRef.documentID
    }
    
    // MARK: - Accept Friend Request
    
    func acceptFriendRequest(friendshipId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let friendshipRef = db.collection("friendships").document(friendshipId)
        
        // Verify the request is for current user
        let doc = try await friendshipRef.getDocument()
        guard let friendship = try? doc.data(as: Friendship.self) else {
            throw NSError(domain: "FriendshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friend request not found"])
        }
        
        // Make sure current user is the recipient (not the requester)
        if friendship.requestedBy == currentUserId {
            throw NSError(domain: "FriendshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot accept your own friend request"])
        }
        
        // Update status to accepted
        try await friendshipRef.updateData([
            "status": FriendshipStatus.accepted.rawValue,
            "acceptedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Decline Friend Request
    
    func declineFriendRequest(friendshipId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let friendshipRef = db.collection("friendships").document(friendshipId)
        
        // Verify the request is for current user
        let doc = try await friendshipRef.getDocument()
        guard let friendship = try? doc.data(as: Friendship.self) else {
            throw NSError(domain: "FriendshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friend request not found"])
        }
        
        // Make sure current user is the recipient
        if friendship.requestedBy == currentUserId {
            throw NSError(domain: "FriendshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot decline your own friend request"])
        }
        
        // Update status to declined
        try await friendshipRef.updateData([
            "status": FriendshipStatus.declined.rawValue
        ])
    }
    
    // MARK: - Remove Friend
    
    func removeFriend(friendshipId: String) async throws {
        guard Auth.auth().currentUser?.uid != nil else {
            throw NSError(domain: "FriendshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Delete the friendship document
        try await db.collection("friendships").document(friendshipId).delete()
    }
    
    // MARK: - Block User
    
    func blockUser(friendshipId: String) async throws {
        guard Auth.auth().currentUser?.uid != nil else {
            throw NSError(domain: "FriendshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let friendshipRef = db.collection("friendships").document(friendshipId)
        
        // Update status to blocked
        try await friendshipRef.updateData([
            "status": FriendshipStatus.blocked.rawValue
        ])
    }
    
    // MARK: - Fetch Friends List
    
    func fetchFriends() async throws -> [(Friendship, User)] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Fetch friendships where current user is involved and status is accepted
        let snapshot1 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()
        
        let snapshot2 = try await db.collection("friendships")
            .whereField("userId2", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()
        
        var friendships = snapshot1.documents.compactMap { try? $0.data(as: Friendship.self) }
        friendships.append(contentsOf: snapshot2.documents.compactMap { try? $0.data(as: Friendship.self) })
        
        // Fetch user details for each friend
        var friendsWithUsers: [(Friendship, User)] = []
        for friendship in friendships {
            let friendId = friendship.friendId(for: currentUserId)
            if let user = try? await fetchUser(userId: friendId) {
                friendsWithUsers.append((friendship, user))
            }
        }
        
        return friendsWithUsers
    }
    
    // MARK: - Fetch Pending Friend Requests
    
    func fetchPendingRequests() async throws -> [(Friendship, User)] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Fetch friendships where current user is userId1 or userId2, status is pending, and they didn't send it
        let snapshot1 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .getDocuments()
        
        let snapshot2 = try await db.collection("friendships")
            .whereField("userId2", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .getDocuments()
        
        var allPendingFriendships = snapshot1.documents.compactMap { try? $0.data(as: Friendship.self) }
        allPendingFriendships.append(contentsOf: snapshot2.documents.compactMap { try? $0.data(as: Friendship.self) })
        
        // Filter to only requests where current user is NOT the requester
        let incomingRequests = allPendingFriendships.filter { !$0.isRequester(userId: currentUserId) }
        
        // Fetch user details for each requester
        var requestsWithUsers: [(Friendship, User)] = []
        for friendship in incomingRequests {
            if let user = try? await fetchUser(userId: friendship.requestedBy) {
                requestsWithUsers.append((friendship, user))
            }
        }
        
        return requestsWithUsers
    }
    
    // MARK: - Search Users by Email
    
    func searchUserByEmail(_ email: String) async throws -> User? {
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        return try? document.data(as: User.self)
    }
    
    // MARK: - Helper Methods
    
    private func checkExistingFriendship(userId1: String, userId2: String) async throws -> Friendship? {
        // Check both orderings since we don't know which way it was stored
        let snapshot1 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: userId1)
            .whereField("userId2", isEqualTo: userId2)
            .getDocuments()
        
        if let doc = snapshot1.documents.first {
            return try? doc.data(as: Friendship.self)
        }
        
        let snapshot2 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: userId2)
            .whereField("userId2", isEqualTo: userId1)
            .getDocuments()
        
        if let doc = snapshot2.documents.first {
            return try? doc.data(as: Friendship.self)
        }
        
        return nil
    }
    
    private func fetchUser(userId: String) async throws -> User {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let user = try? document.data(as: User.self) else {
            throw NSError(domain: "FriendshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return user
    }
}

