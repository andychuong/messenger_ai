//
//  MessageService+Core.swift
//  messagingapp
//
//  Core MessageService with shared properties and initialization
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class MessageService: ObservableObject {
    // MARK: - Singleton
    // Phase 11: Shared instance for message queue service
    static let shared = MessageService()
    
    // MARK: - Shared Properties
    let db = Firestore.firestore()
    let conversationService = ConversationService()
    let encryptionService = EncryptionService.shared
    
    // MARK: - Initialization
    // Note: Public init allows instance creation in ViewModels, but shared instance available for services
    init() {}
    
    // MARK: - Helper Methods
    
    /// Get current user display name
    func getCurrentUserDisplayName() async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw MessageServiceError.userNotAuthenticated
        }
        
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let displayName = userData["displayName"] as? String else {
            throw MessageServiceError.userDataNotFound
        }
        
        return displayName
    }
    
    /// Get current user ID
    func getCurrentUserId() throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw MessageServiceError.userNotAuthenticated
        }
        return currentUser.uid
    }
}

// MARK: - Error Types
enum MessageServiceError: LocalizedError {
    case userNotAuthenticated
    case userDataNotFound
    case messageNotFound
    case invalidMessageType
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .userDataNotFound:
            return "User data not found"
        case .messageNotFound:
            return "Message not found"
        case .invalidMessageType:
            return "Invalid message type"
        }
    }
}

