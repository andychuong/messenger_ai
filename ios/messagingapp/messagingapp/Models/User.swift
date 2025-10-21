//
//  User.swift
//  messagingapp
//
//  User model for authentication and profile
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var photoURL: String?
    var fcmToken: String?
    var lastSeen: Date
    var status: UserStatus
    var createdAt: Date
    
    enum UserStatus: String, Codable {
        case online
        case offline
        case away
    }
    
    // Firestore collection name
    static let collectionName = "users"
    
    // Initialize new user
    init(id: String? = nil, email: String, displayName: String, photoURL: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.fcmToken = nil
        self.lastSeen = Date()
        self.status = .online
        self.createdAt = Date()
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "email": email,
            "displayName": displayName,
            "photoURL": photoURL as Any,
            "fcmToken": fcmToken as Any,
            "lastSeen": Timestamp(date: lastSeen),
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}


