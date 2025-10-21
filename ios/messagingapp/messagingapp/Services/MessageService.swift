//
//  MessageService.swift
//  messagingapp
//
//  Phase 3: Core Messaging - Message Management
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class MessageService: ObservableObject {
    private let db = Firestore.firestore()
    private let conversationService = ConversationService()
    
    // MARK: - Send Message
    
    /// Send a text message
    func sendMessage(conversationId: String, text: String) async throws -> Message {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "MessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Fetch current user name
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let displayName = userData["displayName"] as? String else {
            throw NSError(domain: "MessageService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
        }
        
        // Create message
        let message = Message.create(
            conversationId: conversationId,
            senderId: currentUser.uid,
            senderName: displayName,
            text: text
        )
        
        // Save to Firestore
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        
        // Update message status to sent
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        // Create message with ID
        var sentMessage = message
        sentMessage.id = docRef.documentID
        sentMessage.status = .sent
        
        // Update conversation's last message
        try await conversationService.updateLastMessage(conversationId: conversationId, message: sentMessage)
        
        return sentMessage
    }
    
    // MARK: - Fetch Messages
    
    /// Fetch messages for a conversation with pagination
    func fetchMessages(conversationId: String, limit: Int = 50, before lastMessage: Message? = nil) async throws -> [Message] {
        var query = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        // If loading more messages, start after the last message
        if let lastMessage = lastMessage, let lastTimestamp = lastMessage.timestamp as Date? {
            query = query.start(after: [lastTimestamp])
        }
        
        let snapshot = try await query.getDocuments()
        
        let messages = try snapshot.documents.compactMap { document in
            try document.data(as: Message.self)
        }
        
        return messages.reversed()  // Return in chronological order
    }
    
    // MARK: - Mark as Delivered
    
    /// Mark message as delivered
    func markAsDelivered(messageId: String, conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        let deliveryReceipt = DeliveryReceipt(userId: currentUserId, deliveredAt: Date())
        
        try await messageRef.updateData([
            "status": MessageStatus.delivered.rawValue,
            "deliveredTo": FieldValue.arrayUnion([try Firestore.Encoder().encode(deliveryReceipt)])
        ])
    }
    
    // MARK: - Mark as Read
    
    /// Mark message as read
    func markAsRead(messageId: String, conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        let readReceipt = ReadReceipt(userId: currentUserId, readAt: Date())
        
        try await messageRef.updateData([
            "status": MessageStatus.read.rawValue,
            "readBy": FieldValue.arrayUnion([try Firestore.Encoder().encode(readReceipt)])
        ])
    }
    
    /// Mark all messages in conversation as read
    func markAllAsRead(conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Fetch all messages from other users (not sent by current user)
        let snapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .whereField("senderId", isNotEqualTo: currentUserId)
            .getDocuments()
        
        // Filter for unread messages and update them
        let batch = db.batch()
        let readReceipt = ReadReceipt(userId: currentUserId, readAt: Date())
        
        for document in snapshot.documents {
            // Parse the message to check status
            if let message = try? document.data(as: Message.self),
               message.status != .read {
                // Only update if not already read
                batch.updateData([
                    "status": MessageStatus.read.rawValue,
                    "readBy": FieldValue.arrayUnion([try Firestore.Encoder().encode(readReceipt)])
                ], forDocument: document.reference)
            }
        }
        
        try await batch.commit()
        
        // Also mark conversation as read
        try await conversationService.markAsRead(conversationId: conversationId)
    }
    
    // MARK: - Delete Message
    
    /// Delete a message
    func deleteMessage(messageId: String, conversationId: String) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.delete()
    }
    
    // MARK: - Edit Message
    
    /// Edit a message (within 15 minutes)
    func editMessage(messageId: String, conversationId: String, newText: String) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        // Fetch message to check if it can be edited
        let messageDoc = try await messageRef.getDocument()
        guard let message = try? messageDoc.data(as: Message.self) else {
            throw NSError(domain: "MessageService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
        }
        
        // Check if message can be edited
        guard message.canBeEdited() else {
            throw NSError(domain: "MessageService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Message can no longer be edited (15 minute window expired)"])
        }
        
        // Check if user is the sender
        guard message.senderId == Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MessageService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only edit your own messages"])
        }
        
        // Update message
        try await messageRef.updateData([
            "originalText": message.text,
            "text": newText,
            "editedAt": Date()
        ])
    }
    
    // MARK: - Add Reaction
    
    /// Add or update a reaction to a message
    func addReaction(messageId: String, conversationId: String, emoji: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.updateData([
            "reactions.\(currentUserId)": emoji
        ])
    }
    
    /// Remove a reaction from a message
    func removeReaction(messageId: String, conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.updateData([
            "reactions.\(currentUserId)": FieldValue.delete()
        ])
    }
    
    // MARK: - Real-time Listeners
    
    /// Listen to messages in a conversation
    func listenToMessages(conversationId: String, limit: Int = 50, completion: @escaping ([Message]) -> Void) -> ListenerRegistration? {
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: limit)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let messages = documents.compactMap { document in
                    try? document.data(as: Message.self)
                }
                
                completion(messages)
            }
        
        return listener
    }
    
    /// Listen to new messages only (for notifications)
    func listenToNewMessages(conversationId: String, since: Date, completion: @escaping (Message) -> Void) -> ListenerRegistration? {
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .whereField("timestamp", isGreaterThan: since)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documentChanges else {
                    print("Error fetching new messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                for change in documents where change.type == .added {
                    if let message = try? change.document.data(as: Message.self) {
                        completion(message)
                    }
                }
            }
        
        return listener
    }
}

