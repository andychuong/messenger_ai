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
    private let encryptionService = EncryptionService.shared
    
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
        
        // Encrypt message text
        let encryptedText = try await encryptionService.encryptMessage(text, conversationId: conversationId)
        
        // Create message with encrypted text
        let message = Message.create(
            conversationId: conversationId,
            senderId: currentUser.uid,
            senderName: displayName,
            text: encryptedText  // Store encrypted text
        )
        
        // Save to Firestore
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        
        // Update message status to sent
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        // IMPORTANT: Also save unencrypted text to embeddings collection for AI features
        // This allows AI assistant to access message content without compromising E2E encryption
        do {
            try await db.collection("embeddings").document(docRef.documentID).setData([
                "conversationId": conversationId,
                "messageId": docRef.documentID,
                "text": text,  // Store UNENCRYPTED text for AI processing
                "senderId": currentUser.uid,
                "timestamp": Timestamp(date: message.timestamp),
                "createdAt": FieldValue.serverTimestamp()
            ])
            print("✅ Saved unencrypted text to embeddings for AI access")
        } catch {
            print("⚠️  Failed to save embedding: \(error). AI features may not work for this message.")
            // Don't fail the whole message send if embedding fails
        }
        
        // Create message with ID and decrypted text for local display
        var sentMessage = message
        sentMessage.id = docRef.documentID
        sentMessage.status = .sent
        sentMessage.text = text  // Use original unencrypted text for local display
        
        // Update conversation's last message (with decrypted preview)
        try await conversationService.updateLastMessage(conversationId: conversationId, message: sentMessage)
        
        return sentMessage
    }
    
    /// Send an image message
    func sendImageMessage(conversationId: String, imageURL: String, caption: String? = nil) async throws -> Message {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "MessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Fetch current user name
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let displayName = userData["displayName"] as? String else {
            throw NSError(domain: "MessageService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
        }
        
        // Create image message
        var message = Message(
            id: nil,
            conversationId: conversationId,
            senderId: currentUser.uid,
            senderName: displayName,
            text: caption ?? "",
            timestamp: Date(),
            status: .sending,
            type: .image,
            mediaURL: imageURL,
            mediaType: .image
        )
        
        // Save to Firestore
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        
        // Update message status to sent
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        // Update message with ID
        message.id = docRef.documentID
        message.status = MessageStatus.sent
        
        // Update conversation's last message
        try await conversationService.updateLastMessage(conversationId: conversationId, message: message)
        
        return message
    }
    
    /// Send a voice message
    func sendVoiceMessage(conversationId: String, voiceURL: String, duration: TimeInterval) async throws -> Message {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "MessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Fetch current user name
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let displayName = userData["displayName"] as? String else {
            throw NSError(domain: "MessageService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
        }
        
        // Create voice message
        var message = Message(
            id: nil,
            conversationId: conversationId,
            senderId: currentUser.uid,
            senderName: displayName,
            text: "🎤 Voice message",
            timestamp: Date(),
            status: .sending,
            type: .voice,
            mediaURL: voiceURL,
            mediaType: .voice,
            voiceDuration: duration
        )
        
        // Save to Firestore
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        
        // Update message status to sent
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        // Update message with ID
        message.id = docRef.documentID
        message.status = MessageStatus.sent
        
        // Update conversation's last message
        try await conversationService.updateLastMessage(conversationId: conversationId, message: message)
        
        return message
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
        
        var messages: [Message] = []
        for document in snapshot.documents {
            guard let message = try? document.data(as: Message.self) else { continue }
            
            // Decrypt message using helper that handles both encrypted and legacy plain text
            let decryptedMessage = await decryptMessage(message, conversationId: conversationId)
            messages.append(decryptedMessage)
        }
        
        return messages.reversed()  // Return in chronological order
    }
    
    // MARK: - Helper: Decrypt Message
    
    /// Decrypt a single message
    /// Handles both encrypted (new) and plain text (legacy) messages
    private func decryptMessage(_ message: Message, conversationId: String) async -> Message {
        var decryptedMessage = message
        
        // Phase 9: Skip decryption for AI-sent messages
        // isEncrypted == false means message is already plain text (sent by Cloud Function)
        // nil defaults to true for backward compatibility
        if message.isEncrypted == false {
            // AI-sent message - already plain text, no decryption needed
            return decryptedMessage
        }
        
        // Skip decryption for system messages or empty text
        let messageType = message.type ?? .text  // Default to .text for backward compatibility
        if messageType != .system && !message.text.isEmpty {
            // Try to decrypt - if it fails, assume it's a legacy plain text message
            if let decrypted = try? await encryptionService.decryptMessage(message.text, conversationId: conversationId) {
                decryptedMessage.text = decrypted
            } else {
                // If decryption fails, check if it looks like base64 (encrypted)
                // Base64 strings (including URL-safe variant) contain alphanumeric + / = - _
                let isLikelyEncrypted = message.text.count > 50 && 
                                       message.text.range(of: "^[A-Za-z0-9+/=_-]+$", options: .regularExpression) != nil
                
                if isLikelyEncrypted {
                    // Looks encrypted but failed to decrypt - show fallback
                    decryptedMessage.text = "[Encrypted - Lost Keys]"
                } else {
                    // Looks like plain text - use as-is (legacy message)
                    decryptedMessage.text = message.text
                }
            }
        }
        
        return decryptedMessage
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
        
        // Encrypt new text
        let encryptedNewText = try await encryptionService.encryptMessage(newText, conversationId: conversationId)
        
        // Update message
        try await messageRef.updateData([
            "originalText": message.text,  // Keep encrypted original
            "text": encryptedNewText,
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
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Decrypt messages asynchronously
                Task {
                    var messages: [Message] = []
                    for document in documents {
                        guard let message = try? document.data(as: Message.self) else { continue }
                        // Decrypt using helper that handles both encrypted and legacy plain text
                        let decryptedMessage = await self.decryptMessage(message, conversationId: conversationId)
                        messages.append(decryptedMessage)
                    }
                    completion(messages)
                }
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
    
    // MARK: - Thread Replies
    
    /// Send a reply in a thread
    func sendThreadReply(conversationId: String, parentMessageId: String, text: String) async throws -> Message {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "MessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Fetch current user name
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let displayName = userData["displayName"] as? String else {
            throw NSError(domain: "MessageService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
        }
        
        // Encrypt message text
        let encryptedText = try await encryptionService.encryptMessage(text, conversationId: conversationId)
        
        // Create message with thread reference and encrypted text
        var message = Message.create(
            conversationId: conversationId,
            senderId: currentUser.uid,
            senderName: displayName,
            text: encryptedText
        )
        message.replyTo = parentMessageId
        
        // Save to Firestore
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        
        // Update message status to sent
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        // Create message with ID and decrypted text
        var sentMessage = message
        sentMessage.id = docRef.documentID
        sentMessage.status = .sent
        sentMessage.text = text  // Use original unencrypted text for local display
        
        // Update thread count on parent message
        try await updateThreadCount(conversationId: conversationId, parentMessageId: parentMessageId)
        
        return sentMessage
    }
    
    /// Fetch replies for a thread
    func fetchThreadReplies(conversationId: String, parentMessageId: String, limit: Int = 50) async throws -> [Message] {
        let snapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .whereField("replyTo", isEqualTo: parentMessageId)
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        var messages: [Message] = []
        for document in snapshot.documents {
            guard let message = try? document.data(as: Message.self) else { continue }
            
            // Decrypt using helper that handles both encrypted and legacy plain text
            let decryptedMessage = await decryptMessage(message, conversationId: conversationId)
            messages.append(decryptedMessage)
        }
        
        return messages
    }
    
    /// Listen to thread replies
    func listenToThreadReplies(conversationId: String, parentMessageId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration? {
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .whereField("replyTo", isEqualTo: parentMessageId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching thread replies: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Decrypt messages asynchronously
                Task {
                    var messages: [Message] = []
                    for document in documents {
                        guard let message = try? document.data(as: Message.self) else { continue }
                        // Decrypt using helper that handles both encrypted and legacy plain text
                        let decryptedMessage = await self.decryptMessage(message, conversationId: conversationId)
                        messages.append(decryptedMessage)
                    }
                    completion(messages)
                }
            }
        
        return listener
    }
    
    /// Update thread count on parent message
    private func updateThreadCount(conversationId: String, parentMessageId: String) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(parentMessageId)
        
        // Count thread replies
        let repliesSnapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .whereField("replyTo", isEqualTo: parentMessageId)
            .getDocuments()
        
        let count = repliesSnapshot.documents.count
        
        try await messageRef.updateData([
            "threadCount": count
        ])
    }
    
    // MARK: - Phase 4.5: System Messages for Group Events
    
    /// Send a system message (e.g., "Alice added Bob", "Charlie left the group")
    func sendSystemMessage(conversationId: String, text: String) async throws -> Message {
        // Create system message - no sender required
        var message = Message(
            id: nil,
            conversationId: conversationId,
            senderId: "system",
            senderName: "System",
            text: text,
            timestamp: Date(),
            status: .sent,
            type: .system
        )
        
        // Save to Firestore
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
        
        let docRef = try await messageRef.addDocument(data: try Firestore.Encoder().encode(message))
        
        // Update message with ID
        message.id = docRef.documentID
        
        // Note: Don't update conversation's lastMessage for system messages
        // to avoid cluttering the conversation list
        
        return message
    }
    
    /// Helper: Send "member added" system message
    @discardableResult
    func sendMemberAddedMessage(conversationId: String, addedByName: String, addedUserName: String) async throws -> Message {
        let text = "\(addedByName) added \(addedUserName) to the group"
        return try await sendSystemMessage(conversationId: conversationId, text: text)
    }
    
    /// Helper: Send "member left" system message
    @discardableResult
    func sendMemberLeftMessage(conversationId: String, userName: String) async throws -> Message {
        let text = "\(userName) left the group"
        return try await sendSystemMessage(conversationId: conversationId, text: text)
    }
    
    /// Helper: Send "member removed" system message
    @discardableResult
    func sendMemberRemovedMessage(conversationId: String, removedByName: String, removedUserName: String) async throws -> Message {
        let text = "\(removedByName) removed \(removedUserName) from the group"
        return try await sendSystemMessage(conversationId: conversationId, text: text)
    }
    
    /// Helper: Send "group name changed" system message
    @discardableResult
    func sendGroupNameChangedMessage(conversationId: String, changedByName: String, newName: String) async throws -> Message {
        let text = "\(changedByName) changed the group name to \"\(newName)\""
        return try await sendSystemMessage(conversationId: conversationId, text: text)
    }
    
    /// Helper: Send "group created" system message
    @discardableResult
    func sendGroupCreatedMessage(conversationId: String, creatorName: String) async throws -> Message {
        let text = "\(creatorName) created the group"
        return try await sendSystemMessage(conversationId: conversationId, text: text)
    }
}

