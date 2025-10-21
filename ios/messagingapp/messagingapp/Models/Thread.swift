//
//  Thread.swift
//  messagingapp
//
//  Phase 4: Rich Messaging Features - Message Threading
//

import Foundation
import FirebaseFirestore

struct Thread: Codable, Identifiable {
    @DocumentID var id: String?
    let conversationId: String
    let parentMessageId: String
    var participants: [String]
    var messageCount: Int
    var lastMessageTime: Date
    var lastMessageText: String
    var lastMessageSenderId: String
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case parentMessageId
        case participants
        case messageCount
        case lastMessageTime
        case lastMessageText
        case lastMessageSenderId
        case createdAt
        case updatedAt
    }
}

extension Thread {
    /// Create a new thread for a message
    static func create(conversationId: String, parentMessageId: String, participants: [String]) -> Thread {
        return Thread(
            id: nil,
            conversationId: conversationId,
            parentMessageId: parentMessageId,
            participants: participants,
            messageCount: 0,
            lastMessageTime: Date(),
            lastMessageText: "",
            lastMessageSenderId: "",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

