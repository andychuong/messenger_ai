//
//  Friendship.swift
//  messagingapp
//
//  Created on October 21, 2025.
//

import Foundation
import FirebaseFirestore

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case declined
    case blocked
}

struct Friendship: Identifiable, Codable {
    @DocumentID var id: String?
    let userId1: String
    let userId2: String
    var status: FriendshipStatus
    let requestedBy: String
    let requestedAt: Date
    var acceptedAt: Date?
    
    // Computed property to get the friend's user ID
    func friendId(for currentUserId: String) -> String {
        return currentUserId == userId1 ? userId2 : userId1
    }
    
    // Check if current user is the one who sent the request
    func isRequester(userId: String) -> Bool {
        return requestedBy == userId
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId1
        case userId2
        case status
        case requestedBy
        case requestedAt
        case acceptedAt
    }
}

// Extension to help with creating friendships
extension Friendship {
    init(userId1: String, userId2: String, requestedBy: String) {
        self.userId1 = userId1
        self.userId2 = userId2
        self.status = .pending
        self.requestedBy = requestedBy
        self.requestedAt = Date()
        self.acceptedAt = nil
    }
}

