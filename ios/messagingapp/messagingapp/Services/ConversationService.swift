//
//  ConversationService.swift
//  messagingapp
//
//  Phase 3: Core Messaging - Conversation Management
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class ConversationService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Create or Get Conversation
    
    /// Create a new conversation or return existing one between two users
    func getOrCreateConversation(with userId: String, userName: String, userEmail: String) async throws -> Conversation {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if conversation already exists
        if let existingConversation = try await findExistingConversation(withUserId: userId) {
            return existingConversation
        }
        
        // Fetch current user details
        let currentUserDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let currentUserData = currentUserDoc.data(),
              let currentUserName = currentUserData["displayName"] as? String,
              let currentUserEmail = currentUserData["email"] as? String else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Current user data not found"])
        }
        
        // Create new conversation
        let participants = [currentUser.uid, userId].sorted()  // Sort for consistency
        let participantDetails: [String: ParticipantDetail] = [
            currentUser.uid: ParticipantDetail(
                name: currentUserName,
                email: currentUserEmail,
                photoURL: currentUserData["photoURL"] as? String,
                status: currentUserData["status"] as? String
            ),
            userId: ParticipantDetail(
                name: userName,
                email: userEmail,
                photoURL: nil,
                status: nil
            )
        ]
        
        let now = Date()
        let conversation = Conversation(
            id: nil,
            participants: participants,
            participantDetails: participantDetails,
            type: .direct,
            lastMessage: nil,
            lastMessageTime: nil,
            unreadCount: [currentUser.uid: 0, userId: 0],
            createdAt: now,
            updatedAt: now
        )
        
        // Save to Firestore
        let docRef = try await db.collection("conversations").addDocument(data: try Firestore.Encoder().encode(conversation))
        
        // Return conversation with ID
        var newConversation = conversation
        newConversation.id = docRef.documentID
        return newConversation
    }
    
    // MARK: - Find Existing Conversation
    
    /// Find existing conversation between current user and another user
    func findExistingConversation(withUserId userId: String) async throws -> Conversation? {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return nil
        }
        
        let snapshot = try await db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .whereField("type", isEqualTo: "direct")
            .getDocuments()
        
        for document in snapshot.documents {
            let conversation = try document.data(as: Conversation.self)
            if conversation.participants.contains(userId) {
                return conversation
            }
        }
        
        return nil
    }
    
    // MARK: - Fetch Conversations
    
    /// Fetch all conversations for current user
    func fetchConversations() async throws -> [Conversation] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let snapshot = try await db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastMessageTime", descending: true)
            .getDocuments()
        
        let conversations = try snapshot.documents.compactMap { document in
            try document.data(as: Conversation.self)
        }
        
        return conversations
    }
    
    // MARK: - Update Last Message
    
    /// Update the last message in conversation
    func updateLastMessage(conversationId: String, message: Message) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let lastMessage = LastMessage(
            text: message.text,
            senderId: message.senderId,
            senderName: message.senderName,
            timestamp: message.timestamp,
            type: message.type
        )
        
        // Get current conversation to preserve unread counts
        let conversationRef = db.collection("conversations").document(conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        guard let conversation = try? conversationDoc.data(as: Conversation.self) else {
            return
        }
        
        // Update unread count for all participants except sender
        var unreadCount = conversation.unreadCount
        for participantId in conversation.participants {
            if participantId != currentUserId {
                unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1
            }
        }
        
        try await conversationRef.updateData([
            "lastMessage": try Firestore.Encoder().encode(lastMessage),
            "lastMessageTime": message.timestamp,
            "unreadCount": unreadCount,
            "updatedAt": Date()
        ])
    }
    
    // MARK: - Mark as Read
    
    /// Mark conversation as read for current user
    func markAsRead(conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        
        try await conversationRef.updateData([
            "unreadCount.\(currentUserId)": 0,
            "updatedAt": Date()
        ])
    }
    
    // MARK: - Delete Conversation
    
    /// Delete a conversation
    func deleteConversation(conversationId: String) async throws {
        // Delete all messages first
        let messagesSnapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .getDocuments()
        
        // Delete messages in batches
        let batch = db.batch()
        for document in messagesSnapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
        
        // Delete conversation document
        try await db.collection("conversations").document(conversationId).delete()
    }
    
    // MARK: - Real-time Listeners
    
    /// Listen to conversations for current user
    func listenToConversations(completion: @escaping ([Conversation]) -> Void) -> ListenerRegistration? {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return nil
        }
        
        let listener = db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching conversations: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let conversations = documents.compactMap { document in
                    try? document.data(as: Conversation.self)
                }
                
                completion(conversations)
            }
        
        return listener
    }
    
    /// Listen to a specific conversation
    func listenToConversation(conversationId: String, completion: @escaping (Conversation?) -> Void) -> ListenerRegistration? {
        let listener = db.collection("conversations")
            .document(conversationId)
            .addSnapshotListener { snapshot, error in
                guard let document = snapshot else {
                    print("Error fetching conversation: \(error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                    return
                }
                
                let conversation = try? document.data(as: Conversation.self)
                completion(conversation)
            }
        
        return listener
    }
}

