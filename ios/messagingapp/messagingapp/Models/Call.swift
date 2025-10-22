//
//  Call.swift
//  messagingapp
//
//  Call model for voice and video calls
//

import Foundation
import FirebaseFirestore

struct Call: Identifiable, Codable {
    @DocumentID var id: String?
    var callerId: String
    var recipientId: String
    var type: CallType
    var status: CallStatus
    var startedAt: Date
    var endedAt: Date?
    var duration: TimeInterval?
    var sdpOffer: String?
    var sdpAnswer: String?
    var iceCandidates: [[String: String]]
    
    enum CallType: String, Codable {
        case audio
        case video
    }
    
    enum CallStatus: String, Codable {
        case ringing
        case active
        case ended
        case missed
        case declined
        case failed
    }
    
    // Firestore collection name
    static let collectionName = "calls"
    
    // Initialize new call
    init(
        id: String? = nil,
        callerId: String,
        recipientId: String,
        type: CallType,
        status: CallStatus = .ringing
    ) {
        self.id = id
        self.callerId = callerId
        self.recipientId = recipientId
        self.type = type
        self.status = status
        self.startedAt = Date()
        self.endedAt = nil
        self.duration = nil
        self.sdpOffer = nil
        self.sdpAnswer = nil
        self.iceCandidates = []
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "callerId": callerId,
            "recipientId": recipientId,
            "type": type.rawValue,
            "status": status.rawValue,
            "startedAt": Timestamp(date: startedAt),
            "iceCandidates": iceCandidates
        ]
        
        if let endedAt = endedAt {
            dict["endedAt"] = Timestamp(date: endedAt)
        }
        if let duration = duration {
            dict["duration"] = duration
        }
        if let sdpOffer = sdpOffer {
            dict["sdpOffer"] = sdpOffer
        }
        if let sdpAnswer = sdpAnswer {
            dict["sdpAnswer"] = sdpAnswer
        }
        
        return dict
    }
    
    // Helper to check if call is incoming for current user
    func isIncoming(for userId: String) -> Bool {
        return recipientId == userId
    }
    
    // Helper to check if call is active
    var isActive: Bool {
        return status == .active || status == .ringing
    }
    
    // Helper to get other participant ID
    func otherParticipantId(currentUserId: String) -> String {
        return currentUserId == callerId ? recipientId : callerId
    }
}

