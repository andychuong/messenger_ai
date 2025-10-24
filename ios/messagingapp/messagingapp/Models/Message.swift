//
//  Message.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var conversationId: String
    var senderId: String
    var senderName: String?  // Phase 9: Optional for backward compatibility
    var text: String
    var timestamp: Date
    var status: MessageStatus
    var type: MessageType?  // Phase 9: Optional for backward compatibility (defaults to .text)
    
    // Optional fields for rich messaging (Phase 4)
    var mediaURL: String?
    var mediaType: MediaType?
    var voiceTranscript: String?
    var voiceDuration: TimeInterval?  // Duration for voice messages
    var editedAt: Date?
    var originalText: String?
    var replyTo: String?  // messageId for threading
    var threadCount: Int?  // Number of replies in thread
    var reactions: [String: String]?  // userId -> emoji
    var translations: [String: String]?  // languageCode -> translatedText
    
    // Read receipts
    var readBy: [ReadReceipt]?
    var deliveredTo: [DeliveryReceipt]?
    
    // Encryption flag (Phase 9: AI-sent messages)
    // Phase 9.5 Redesign: Per-message encryption (true = encrypted/private, false = AI-enhanced)
    var isEncrypted: Bool?  // nil defaults to true for backward compatibility
    
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
        case voiceDuration
        case editedAt
        case originalText
        case replyTo
        case threadCount
        case reactions
        case translations
        case readBy
        case deliveredTo
        case isEncrypted
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

struct ReadReceipt: Codable, Hashable {
    var userId: String
    var timestamp: Date  // Changed from readAt to match Firestore field
    
    enum CodingKeys: String, CodingKey {
        case userId
        case timestamp
    }
}

struct DeliveryReceipt: Codable, Hashable {
    var userId: String
    var timestamp: Date  // Changed from deliveredAt to match Firestore field
    
    enum CodingKeys: String, CodingKey {
        case userId
        case timestamp
    }
}

// Extension for Message helpers
extension Message {
    // Check if message is sent by current user
    func isSentByCurrentUser(_ currentUserId: String) -> Bool {
        return senderId == currentUserId
    }
    
    // Compute actual status based on read receipts
    // This overrides the stored status for better accuracy
    func computedStatus(for otherUserId: String? = nil) -> MessageStatus {
        // If failed, return failed
        if status == .failed {
            return .failed
        }
        
        // If we have readBy receipts, check if anyone has read it
        if let readBy = readBy, !readBy.isEmpty {
            // If checking for specific user
            if let otherUserId = otherUserId {
                let userHasRead = readBy.contains { $0.userId == otherUserId }
                if userHasRead {
                    return .read
                }
            } else {
                // Any read receipt means the message is read
                return .read
            }
        }
        
        // If we have deliveredTo receipts, message is delivered
        if let deliveredTo = deliveredTo, !deliveredTo.isEmpty {
            return .delivered
        }
        
        // Otherwise return the stored status
        return status
    }
    
    // Check if message has been read
    var isRead: Bool {
        return computedStatus() == .read
    }
    
    // Check if message has been delivered
    var isDelivered: Bool {
        let status = computedStatus()
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
        let calendar = Calendar.current
        
        if calendar.isDateInToday(timestamp) {
            // Today: show only time
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            // Yesterday: show "Yesterday" + time
            formatter.timeStyle = .short
            return "Yesterday \(formatter.string(from: timestamp))"
        } else if calendar.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear) {
            // This week: show day name + time
            formatter.dateFormat = "EEE h:mm a"
            return formatter.string(from: timestamp)
        } else if calendar.isDate(timestamp, equalTo: Date(), toGranularity: .year) {
            // This year: show month/day + time
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: timestamp)
        } else {
            // Older: show full date + time
            formatter.dateFormat = "MMM d, yyyy h:mm a"
            return formatter.string(from: timestamp)
        }
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
        text: String,
        isEncrypted: Bool = true  // Phase 9.5 Redesign: Default to encrypted
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
            deliveredTo: nil,
            isEncrypted: isEncrypted
        )
    }
}

