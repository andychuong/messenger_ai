//
//  Decision.swift
//  messagingapp
//
//  Phase 8: AI-powered decision tracking
//

import Foundation
import FirebaseFirestore

/// Represents a decision detected in conversations
struct Decision: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    
    let decision: String
    let rationale: String?
    let outcome: String?
    let conversationId: String
    let messageId: String
    let decidedBy: String
    let detectedAt: Date
    let createdAt: Date
    
    // Display properties
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - Firestore Conversion
extension Decision {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.decision = data["decision"] as? String ?? ""
        self.rationale = data["rationale"] as? String
        self.outcome = data["outcome"] as? String
        self.conversationId = data["conversationId"] as? String ?? ""
        self.messageId = data["messageId"] as? String ?? ""
        self.decidedBy = data["decidedBy"] as? String ?? ""
        self.detectedAt = (data["detectedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "decision": decision,
            "conversationId": conversationId,
            "messageId": messageId,
            "decidedBy": decidedBy,
            "detectedAt": Timestamp(date: detectedAt),
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let rationale = rationale {
            data["rationale"] = rationale
        }
        
        if let outcome = outcome {
            data["outcome"] = outcome
        }
        
        return data
    }
}

