//
//  Message.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    var conversationId: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    var status: MessageStatus
    var type: MessageType
    
    // Optional fields for rich messaging (Phase 4)
    var mediaURL: String?
    var mediaType: MediaType?
    var voiceTranscript: String?
    var editedAt: Date?
    var originalText: String?
    var replyTo: String?  // messageId for threading
    var reactions: [String: String]?  // userId -> emoji
    var translations: [String: String]?  // languageCode -> translatedText
    
    // Read receipts
    var readBy: [ReadReceipt]?
    var deliveredTo: [DeliveryReceipt]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case senderName
        case text
        case timestamp
        case status
        case type
        case mediaURL
        case mediaType
        case voiceTranscript
        case editedAt
        case originalText
        case replyTo
        case reactions
        case translations
        case readBy
        case deliveredTo
    }
}

enum MessageStatus: String, Codable {
    case sending      // Local optimistic state
    case sent         // Uploaded to Firestore
    case delivered    // Received by recipient device
    case read         // Viewed by recipient
    case failed       // Failed to send
}

enum MessageType: String, Codable, Hashable {
    case text
    case image
    case voice
    case video
    case system  // For system messages like "User joined"
}

enum MediaType: String, Codable {
    case image
    case voice
    case video
}

struct ReadReceipt: Codable {
    var userId: String
    var readAt: Date
}

struct DeliveryReceipt: Codable {
    var userId: String
    var deliveredAt: Date
}

// Extension for Message helpers
extension Message {
    // Check if message is sent by current user
    func isSentByCurrentUser(_ currentUserId: String) -> Bool {
        return senderId == currentUserId
    }
    
    // Check if message has been read
    var isRead: Bool {
        return status == .read
    }
    
    // Check if message has been delivered
    var isDelivered: Bool {
        return status == .delivered || status == .read
    }
    
    // Check if message is still sending
    var isSending: Bool {
        return status == .sending
    }
    
    // Check if message failed to send
    var hasFailed: Bool {
        return status == .failed
    }
    
    // Check if message was edited
    var wasEdited: Bool {
        return editedAt != nil
    }
    
    // Check if message has reactions
    var hasReactions: Bool {
        return reactions != nil && !(reactions?.isEmpty ?? true)
    }
    
    // Get reaction count
    var reactionCount: Int {
        return reactions?.count ?? 0
    }
    
    // Format timestamp for display
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // Check if message can be edited (within 15 minutes)
    func canBeEdited() -> Bool {
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        return timestamp > fifteenMinutesAgo
    }
}

// Extension for creating a new message
extension Message {
    static func create(
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String
    ) -> Message {
        return Message(
            id: nil,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(),
            status: .sending,
            type: .text,
            mediaURL: nil,
            mediaType: nil,
            voiceTranscript: nil,
            editedAt: nil,
            originalText: nil,
            replyTo: nil,
            reactions: nil,
            translations: nil,
            readBy: nil,
            deliveredTo: nil
        )
    }
}

