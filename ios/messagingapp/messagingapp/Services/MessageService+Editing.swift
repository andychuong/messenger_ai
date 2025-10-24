//
//  MessageService+Editing.swift
//  messagingapp
//
//  Message editing and deletion operations
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension MessageService {
    // MARK: - Delete Message
    
    /// Delete a message
    func deleteMessage(conversationId: String, messageId: String) async throws {
        try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
            .delete()
    }
    
    // MARK: - Edit Message
    
    /// Edit a message
    func editMessage(conversationId: String, messageId: String, newText: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw MessageServiceError.userNotAuthenticated
        }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        // Get the original message to verify ownership
        let messageDoc = try await messageRef.getDocument()
        guard let data = messageDoc.data(),
              let senderId = data["senderId"] as? String,
              senderId == currentUserId else {
            throw NSError(domain: "MessageService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "You can only edit your own messages"
            ])
        }
        
        // Encrypt the new text
        let encryptedText = try await encryptionService.encryptMessage(newText, conversationId: conversationId)
        
        try await messageRef.updateData([
            "text": encryptedText,
            "isEdited": true,
            "editedAt": FieldValue.serverTimestamp()
        ])
    }
}

