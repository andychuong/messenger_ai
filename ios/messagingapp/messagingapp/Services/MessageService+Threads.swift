//
//  MessageService+Threads.swift
//  messagingapp
//
//  Message thread/reply operations
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension MessageService {
    // MARK: - Thread Replies
    
    /// Send a reply in a thread
    func sendThreadReply(
        conversationId: String,
        parentMessageId: String,
        text: String
    ) async throws -> Message {
        let currentUserId = try getCurrentUserId()
        let displayName = try await getCurrentUserDisplayName()
        
        // Encrypt message text
        let encryptedText = try await encryptionService.encryptMessage(text, conversationId: conversationId)
        
        // Create thread reply message
        var message = Message.create(
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: displayName,
            text: encryptedText
        )
        message.threadId = parentMessageId
        message.isThreadReply = true
        
        // Save to thread subcollection
        let threadRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(parentMessageId)
            .collection("thread")
        
        let docRef = try await threadRef.addDocument(data: try Firestore.Encoder().encode(message))
        try await docRef.updateData(["status": MessageStatus.sent.rawValue])
        
        // Update parent message's reply count and last reply time
        let parentRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(parentMessageId)
        
        try await parentRef.updateData([
            "threadReplyCount": FieldValue.increment(Int64(1)),
            "lastThreadReplyTime": FieldValue.serverTimestamp(),
            "lastThreadReplyPreview": text.prefix(100)
        ])
        
        // Return message with ID and decrypted text
        var sentMessage = message
        sentMessage.id = docRef.documentID
        sentMessage.status = .sent
        sentMessage.text = text
        
        return sentMessage
    }
    
    /// Fetch thread replies for a message
    func fetchThreadReplies(
        conversationId: String,
        parentMessageId: String,
        limit: Int = 50
    ) async throws -> [Message] {
        let snapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(parentMessageId)
            .collection("thread")
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        var replies: [Message] = []
        for document in snapshot.documents {
            guard let message = try? document.data(as: Message.self) else { continue }
            
            // Decrypt if needed
            let decryptedMessage = try await decryptMessageIfNeeded(message, conversationId: conversationId)
            replies.append(decryptedMessage)
        }
        
        return replies
    }
    
    /// Listen to thread replies in real-time
    func listenToThreadReplies(
        conversationId: String,
        parentMessageId: String,
        completion: @escaping ([Message]) -> Void
    ) -> ListenerRegistration {
        return db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(parentMessageId)
            .collection("thread")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching thread replies: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return
                }
                
                Task {
                    var replies: [Message] = []
                    for document in documents {
                        guard var message = try? document.data(as: Message.self) else { continue }
                        
                        // Decrypt if needed
                        if message.isEncrypted == true {
                            do {
                                let decryptedText = try await self.encryptionService.decryptMessage(
                                    message.text,
                                    conversationId: conversationId
                                )
                                message.text = decryptedText
                            } catch {
                                print("⚠️ Failed to decrypt thread reply: \(error)")
                                message.text = "[Encrypted message - decryption failed]"
                            }
                        }
                        
                        replies.append(message)
                    }
                    
                    await MainActor.run {
                        completion(replies)
                    }
                }
            }
    }
    
    /// Get thread metadata (reply count, participants)
    func getThreadMetadata(
        conversationId: String,
        parentMessageId: String
    ) async throws -> (replyCount: Int, lastReplyTime: Date?) {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(parentMessageId)
        
        let messageDoc = try await messageRef.getDocument()
        guard let data = messageDoc.data() else {
            return (0, nil)
        }
        
        let replyCount = data["threadReplyCount"] as? Int ?? 0
        let lastReplyTime = (data["lastThreadReplyTime"] as? Timestamp)?.dateValue()
        
        return (replyCount, lastReplyTime)
    }
    
    // MARK: - Private Helpers
    
    /// Helper to decrypt message (used by thread methods)
    private func decryptMessageIfNeeded(_ message: Message, conversationId: String) async throws -> Message {
        var decryptedMessage = message
        
        if message.isEncrypted == true && message.type == .text {
            do {
                let decryptedText = try await encryptionService.decryptMessage(
                    message.text,
                    conversationId: conversationId
                )
                decryptedMessage.text = decryptedText
            } catch {
                print("⚠️ Failed to decrypt message: \(error)")
                decryptedMessage.text = "[Encrypted message - decryption failed]"
            }
        }
        
        return decryptedMessage
    }
}

