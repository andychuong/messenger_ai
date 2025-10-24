//
//  MessageService+Reactions.swift
//  messagingapp
//
//  Message reaction operations
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension MessageService {
    // MARK: - Add/Remove Reactions
    
    /// Add or remove a reaction to a message
    func addReaction(conversationId: String, messageId: String, emoji: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw MessageServiceError.userNotAuthenticated
        }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        let messageDoc = try await messageRef.getDocument()
        guard let data = messageDoc.data() else {
            throw MessageServiceError.messageNotFound
        }
        
        var reactions = data["reactions"] as? [String: [String]] ?? [:]
        var userIds = reactions[emoji] ?? []
        
        // Toggle reaction
        if userIds.contains(currentUserId) {
            userIds.removeAll { $0 == currentUserId }
        } else {
            userIds.append(currentUserId)
        }
        
        if userIds.isEmpty {
            reactions.removeValue(forKey: emoji)
        } else {
            reactions[emoji] = userIds
        }
        
        try await messageRef.updateData(["reactions": reactions])
    }
}

