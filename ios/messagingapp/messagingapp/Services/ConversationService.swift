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
            type: message.type ?? .text  // Default to .text for backward compatibility
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
            .addSnapshotListener(includeMetadataChanges: false) { snapshot, error in
                guard let snapshot = snapshot,
                      !snapshot.metadata.hasPendingWrites else {
                    // Ignore local writes that haven't been confirmed by server yet
                    return
                }
                
                if let error = error {
                    print("Error fetching conversations: \(error.localizedDescription)")
                    return
                }
                
                let documents = snapshot.documents
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
    
    // MARK: - Phase 4.5: Group Chat Management
    
    /// Create a new group conversation
    func createGroupConversation(memberIds: [String], groupName: String?) async throws -> Conversation {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Validate minimum members (current user + at least 2 others for a group)
        guard memberIds.count >= 2 else {
            throw NSError(domain: "ConversationService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Group must have at least 2 other members"])
        }
        
        // Include current user in participants
        var allParticipants = memberIds
        if !allParticipants.contains(currentUser.uid) {
            allParticipants.append(currentUser.uid)
        }
        
        // Fetch all participant details
        var participantDetails: [String: ParticipantDetail] = [:]
        
        for userId in allParticipants {
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data() {
                    participantDetails[userId] = ParticipantDetail(
                        name: userData["displayName"] as? String ?? "Unknown",
                        email: userData["email"] as? String ?? "",
                        photoURL: userData["photoURL"] as? String,
                        status: userData["status"] as? String
                    )
                } else {
                    // Add placeholder data if user not found
                    participantDetails[userId] = ParticipantDetail(
                        name: "Unknown User",
                        email: "",
                        photoURL: nil,
                        status: nil
                    )
                }
            } catch {
                // Add placeholder data on error
                participantDetails[userId] = ParticipantDetail(
                    name: "Unknown User",
                    email: "",
                    photoURL: nil,
                    status: nil
                )
            }
        }
        
        let now = Date()
        var unreadCount: [String: Int] = [:]
        for userId in allParticipants {
            unreadCount[userId] = 0
        }
        
        let conversation = Conversation(
            id: nil,
            participants: allParticipants,
            participantDetails: participantDetails,
            type: .group,
            lastMessage: nil,
            lastMessageTime: nil,
            unreadCount: unreadCount,
            createdAt: now,
            updatedAt: now,
            groupName: groupName,
            groupPhotoURL: nil,
            admins: [currentUser.uid],  // Creator is the first admin
            createdBy: currentUser.uid
        )
        
        // Save to Firestore
        let docRef = try await db.collection("conversations").addDocument(data: try Firestore.Encoder().encode(conversation))
        
        // Return conversation with ID
        var newConversation = conversation
        newConversation.id = docRef.documentID
        
        return newConversation
    }
    
    /// Add members to an existing group
    func addMembersToGroup(conversationId: String, userIds: [String]) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        guard var conversation = try? conversationDoc.data(as: Conversation.self) else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        // Check if user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw NSError(domain: "ConversationService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can add members"])
        }
        
        // Fetch new member details
        var newParticipantDetails = conversation.participantDetails
        for userId in userIds {
            if !conversation.participants.contains(userId) {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data() {
                    newParticipantDetails[userId] = ParticipantDetail(
                        name: userData["displayName"] as? String ?? "Unknown",
                        email: userData["email"] as? String ?? "",
                        photoURL: userData["photoURL"] as? String,
                        status: userData["status"] as? String
                    )
                    conversation.participants.append(userId)
                    conversation.unreadCount[userId] = 0
                }
            }
        }
        
        try await conversationRef.updateData([
            "participants": conversation.participants,
            "participantDetails": try Firestore.Encoder().encode(newParticipantDetails),
            "unreadCount": conversation.unreadCount,
            "updatedAt": Date()
        ])
    }
    
    /// Remove a member from group (admin only)
    func removeMemberFromGroup(conversationId: String, userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        guard var conversation = try? conversationDoc.data(as: Conversation.self) else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        // Check if user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw NSError(domain: "ConversationService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can remove members"])
        }
        
        // Remove participant
        conversation.participants.removeAll { $0 == userId }
        conversation.participantDetails.removeValue(forKey: userId)
        conversation.unreadCount.removeValue(forKey: userId)
        
        try await conversationRef.updateData([
            "participants": conversation.participants,
            "participantDetails": try Firestore.Encoder().encode(conversation.participantDetails),
            "unreadCount": conversation.unreadCount,
            "updatedAt": Date()
        ])
    }
    
    /// Leave a group
    func leaveGroup(conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        guard var conversation = try? conversationDoc.data(as: Conversation.self) else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        // Remove current user from participants
        conversation.participants.removeAll { $0 == currentUserId }
        conversation.participantDetails.removeValue(forKey: currentUserId)
        conversation.unreadCount.removeValue(forKey: currentUserId)
        
        // If user was admin, remove from admins
        if var admins = conversation.admins {
            admins.removeAll { $0 == currentUserId }
            conversation.admins = admins
        }
        
        // If no participants left, delete the conversation
        if conversation.participants.isEmpty {
            try await deleteConversation(conversationId: conversationId)
        } else {
            var updateData: [String: Any] = [
                "participants": conversation.participants,
                "participantDetails": try Firestore.Encoder().encode(conversation.participantDetails),
                "unreadCount": conversation.unreadCount,
                "updatedAt": Date()
            ]
            
            if let admins = conversation.admins {
                updateData["admins"] = admins
            }
            
            try await conversationRef.updateData(updateData)
        }
    }
    
    /// Update group name
    func updateGroupName(conversationId: String, name: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        guard let conversation = try? conversationDoc.data(as: Conversation.self) else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        // Check if user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw NSError(domain: "ConversationService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can change group name"])
        }
        
        try await conversationRef.updateData([
            "groupName": name,
            "updatedAt": Date()
        ])
    }
    
    /// Update group photo
    func updateGroupPhoto(conversationId: String, imageURL: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ConversationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        guard let conversation = try? conversationDoc.data(as: Conversation.self) else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        // Check if user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw NSError(domain: "ConversationService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can change group photo"])
        }
        
        try await conversationRef.updateData([
            "groupPhotoURL": imageURL,
            "updatedAt": Date()
        ])
    }
    
    /// Fetch all group members with their details
    func fetchGroupMembers(conversationId: String) async throws -> [User] {
        let conversationRef = db.collection("conversations").document(conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        guard let conversation = try? conversationDoc.data(as: Conversation.self) else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        var members: [User] = []
        for userId in conversation.participants {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let user = try? userDoc.data(as: User.self) {
                members.append(user)
            }
        }
        
        return members
    }
    
}

