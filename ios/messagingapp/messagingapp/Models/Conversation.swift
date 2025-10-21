//
//  Conversation.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var participants: [String]  // Array of user IDs
    var participantDetails: [String: ParticipantDetail]  // userId -> details
    var type: ConversationType
    var lastMessage: LastMessage?
    var lastMessageTime: Date?
    var unreadCount: [String: Int]  // userId -> unread count
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case participantDetails
        case type
        case lastMessage
        case lastMessageTime
        case unreadCount
        case createdAt
        case updatedAt
    }
}

enum ConversationType: String, Codable, Hashable {
    case direct
    case group
}

struct ParticipantDetail: Codable, Hashable {
    var name: String
    var email: String
    var photoURL: String?
    var status: String?  // "online", "offline", "away"
}

struct LastMessage: Codable, Hashable {
    var text: String
    var senderId: String
    var senderName: String
    var timestamp: Date
    var type: MessageType
    
    enum CodingKeys: String, CodingKey {
        case text
        case senderId
        case senderName
        case timestamp
        case type
    }
}

// Extension for Conversation helpers
extension Conversation {
    // Get the other participant's ID in a direct conversation
    func otherParticipantId(currentUserId: String) -> String? {
        return participants.first { $0 != currentUserId }
    }
    
    // Get the other participant's details
    func otherParticipantDetails(currentUserId: String) -> ParticipantDetail? {
        guard let otherId = otherParticipantId(currentUserId: currentUserId) else { return nil }
        return participantDetails[otherId]
    }
    
    // Get conversation title (other person's name or group name)
    func title(currentUserId: String) -> String {
        if type == .group {
            // For group chats, show all participant names
            let names = participantDetails.values.map { $0.name }
            return names.joined(separator: ", ")
        } else {
            // For direct chats, show other person's name
            return otherParticipantDetails(currentUserId: currentUserId)?.name ?? "Unknown"
        }
    }
    
    // Get unread count for current user
    func unreadCountForUser(_ userId: String) -> Int {
        return unreadCount[userId] ?? 0
    }
    
    // Check if conversation has unread messages
    func hasUnreadMessages(for userId: String) -> Bool {
        return unreadCountForUser(userId) > 0
    }
}

