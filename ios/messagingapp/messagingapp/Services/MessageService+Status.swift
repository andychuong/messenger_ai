//
//  MessageService+Status.swift
//  messagingapp
//
//  Message status operations (delivered, read receipts)
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension MessageService {
    // MARK: - Mark as Delivered
    
    /// Mark message as delivered
    func markAsDelivered(conversationId: String, messageId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.updateData([
            "deliveredTo": FieldValue.arrayUnion([
                ["userId": currentUserId, "timestamp": Timestamp(date: Date())]
            ])
        ])
    }
    
    // MARK: - Mark as Read
    
    /// Mark message as read
    func markAsRead(conversationId: String, messageId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.updateData([
            "readBy": FieldValue.arrayUnion([
                ["userId": currentUserId, "timestamp": Timestamp(date: Date())]
            ])
        ])
    }
    
    /// Mark all messages in a conversation as read
    func markAllAsRead(conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Fetch all unread messages
        let snapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .getDocuments()
        
        let batch = db.batch()
        
        for document in snapshot.documents {
            let data = document.data()
            let readBy = data["readBy"] as? [[String: Any]] ?? []
            
            // Check if user has already read this message
            let alreadyRead = readBy.contains { entry in
                entry["userId"] as? String == currentUserId
            }
            
            if !alreadyRead {
                let messageRef = db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .document(document.documentID)
                
                batch.updateData([
                    "readBy": FieldValue.arrayUnion([
                        ["userId": currentUserId, "timestamp": Timestamp(date: Date())]
                    ])
                ], forDocument: messageRef)
            }
        }
        
        try await batch.commit()
        print("✅ Marked all messages as read in conversation: \(conversationId)")
    }
}

