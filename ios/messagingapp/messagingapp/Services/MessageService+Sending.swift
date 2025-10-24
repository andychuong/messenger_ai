//
//  MessageService+Sending.swift
//  messagingapp
//
//  Message sending operations (text, image, voice, system messages)
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension MessageService {
    // MARK: - Send Text Message
    
    /// Send a text message
    /// Phase 9.5 Redesign: Per-message encryption control
    func sendMessage(conversationId: String, text: String, shouldEncrypt: Bool = true) async throws -> Message {
        let currentUserId = try getCurrentUserId()
        let displayName = try await getCurrentUserDisplayName()
        
        // Encrypt message text if shouldEncrypt is true
        let encryptedText = shouldEncrypt ? try await encryptionService.encryptMessage(text, conversationId: conversationId) : text
        
        // Create message with encrypted text
        let message = Message.create(
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: displayName,
            text: encryptedText,
            isEncrypted: shouldEncrypt
        )
        
        // Save to Firestore
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        // Phase 9.5 Redesign: Only save embeddings if message is NOT encrypted
        // When encrypted, we skip AI indexing for privacy
        if !shouldEncrypt {
            do {
                try await db.collection("embeddings").document(docRef.documentID).setData([
                    "conversationId": conversationId,
                    "messageId": docRef.documentID,
                    "text": text,
                    "senderId": currentUserId,
                    "timestamp": Timestamp(date: message.timestamp),
                    "createdAt": FieldValue.serverTimestamp()
                ])
            } catch {
                print("⚠️  Failed to save embedding: \(error). AI features may not work for this message.")
            }
        }
        
        // Create message with ID and original text for local display
        var sentMessage = message
        sentMessage.id = docRef.documentID
        sentMessage.status = .sent
        sentMessage.text = text
        
        // Update conversation's last message
        try await conversationService.updateLastMessage(conversationId: conversationId, message: sentMessage)
        
        return sentMessage
    }
    
    // MARK: - Send Image Message
    
    /// Send an image message
    func sendImageMessage(conversationId: String, imageURL: String, caption: String? = nil) async throws -> Message {
        let currentUserId = try getCurrentUserId()
        let displayName = try await getCurrentUserDisplayName()
        
        var message = Message(
            id: nil,
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: displayName,
            text: caption ?? "",
            timestamp: Date(),
            status: .sending,
            type: .image,
            mediaURL: imageURL,
            mediaType: .image
        )
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        message.id = docRef.documentID
        message.status = .sent
        
        try await conversationService.updateLastMessage(conversationId: conversationId, message: message)
        
        return message
    }
    
    // MARK: - Send Voice Message
    
    /// Send a voice message
    func sendVoiceMessage(conversationId: String, voiceURL: String, duration: TimeInterval) async throws -> Message {
        let currentUserId = try getCurrentUserId()
        let displayName = try await getCurrentUserDisplayName()
        
        var message = Message(
            id: nil,
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: displayName,
            text: "🎤 Voice message",
            timestamp: Date(),
            status: .sending,
            type: .voice,
            mediaURL: voiceURL,
            mediaType: .voice,
            voiceDuration: duration
        )
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        message.id = docRef.documentID
        message.status = .sent
        
        try await conversationService.updateLastMessage(conversationId: conversationId, message: message)
        
        return message
    }
    
    // MARK: - Send System Message
    
    /// Send a system message (for group events, etc.)
    func sendSystemMessage(
        conversationId: String,
        text: String,
        systemType: String? = nil
    ) async throws {
        let message: [String: Any] = [
            "conversationId": conversationId,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "type": "system",
            "systemType": systemType ?? "info",
            "status": "sent"
        ]
        
        try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .addDocument(data: message)
    }
    
    // MARK: - Group Event System Messages
    
    /// Send member added system message
    func sendMemberAddedMessage(conversationId: String, memberName: String) async throws {
        try await sendSystemMessage(
            conversationId: conversationId,
            text: "\(memberName) was added to the group",
            systemType: "member_added"
        )
    }
    
    /// Send member removed system message
    func sendMemberRemovedMessage(conversationId: String, memberName: String) async throws {
        try await sendSystemMessage(
            conversationId: conversationId,
            text: "\(memberName) was removed from the group",
            systemType: "member_removed"
        )
    }
    
    /// Send member left system message
    func sendMemberLeftMessage(conversationId: String, memberName: String) async throws {
        try await sendSystemMessage(
            conversationId: conversationId,
            text: "\(memberName) left the group",
            systemType: "member_left"
        )
    }
    
    /// Send group name changed system message
    func sendGroupNameChangedMessage(conversationId: String, newName: String) async throws {
        try await sendSystemMessage(
            conversationId: conversationId,
            text: "Group name changed to \"\(newName)\"",
            systemType: "name_changed"
        )
    }
    
    /// Send group created system message
    func sendGroupCreatedMessage(conversationId: String, creatorName: String) async throws {
        try await sendSystemMessage(
            conversationId: conversationId,
            text: "\(creatorName) created the group",
            systemType: "group_created"
        )
    }
}

