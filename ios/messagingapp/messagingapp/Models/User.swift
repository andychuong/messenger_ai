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
    var preferredLanguage: String? // User's preferred language for translations
    
    // Phase 18: Timezone Coordination
    var timezone: String? // e.g., "America/New_York"
    var timezoneOffset: Int? // Offset from UTC in hours
    var workingHours: WorkingHours?
    
    enum UserStatus: String, Codable {
        case online
        case offline
        case away
        case doNotDisturb = "do_not_disturb"
        case busy
    }
    
    struct WorkingHours: Codable {
        var start: String // "09:00" (24-hour format)
        var end: String // "17:00"
        var days: [String] // ["Mon", "Tue", "Wed", "Thu", "Fri"]
    }
    
    // Firestore collection name
    static let collectionName = "users"
    
    // Initialize new user
    init(id: String? = nil, email: String, displayName: String, photoURL: String? = nil, preferredLanguage: String? = nil, timezone: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.fcmToken = nil
        self.lastSeen = Date()
        self.status = .online
        self.createdAt = Date()
        self.preferredLanguage = preferredLanguage
        self.timezone = timezone
        self.timezoneOffset = nil
        self.workingHours = nil
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "photoURL": photoURL as Any,
            "fcmToken": fcmToken as Any,
            "lastSeen": Timestamp(date: lastSeen),
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "preferredLanguage": preferredLanguage as Any,
            "timezone": timezone as Any,
            "timezoneOffset": timezoneOffset as Any
        ]
        
        if let workingHours = workingHours {
            dict["workingHours"] = [
                "start": workingHours.start,
                "end": workingHours.end,
                "days": workingHours.days
            ]
        }
        
        return dict
    }
}


