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
    
    // Phase 4.5: Group chat properties
    var groupName: String?
    var groupPhotoURL: String?
    var admins: [String]?  // Array of user IDs who are admins
    var createdBy: String?  // User ID of the creator
    
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
        case groupName
        case groupPhotoURL
        case admins
        case createdBy
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
    var senderName: String?  // Phase 9: Optional for backward compatibility
    var timestamp: Date
    var type: MessageType?  // Phase 9: Optional for backward compatibility (defaults to .text)
    
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
            // Use group name if available, otherwise show participant names
            if let groupName = groupName, !groupName.isEmpty {
                return groupName
            }
            // Fallback: show limited participant names
            let otherParticipants = participantDetails.filter { $0.key != currentUserId }
            let names = otherParticipants.values.map { $0.name }.sorted()
            
            if names.count <= 2 {
                return names.joined(separator: ", ")
            } else {
                // Show first 2 names and count of others
                let firstTwo = names.prefix(2).joined(separator: ", ")
                let remaining = names.count - 2
                return "\(firstTwo) +\(remaining)"
            }
        } else {
            // For direct chats, show other person's name
            return otherParticipantDetails(currentUserId: currentUserId)?.name ?? "Unknown"
        }
    }
    
    // Check if user is admin
    func isAdmin(userId: String) -> Bool {
        return admins?.contains(userId) ?? false
    }
    
    // Get member count
    var memberCount: Int {
        return participants.count
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

