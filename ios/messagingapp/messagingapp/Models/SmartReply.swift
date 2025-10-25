//
//  SmartReply.swift
//  messagingapp
//
//  Phase 16: Smart Replies & Suggestions
//

import Foundation

struct SmartReply: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let tone: ReplyTone
    let confidence: Double
    let reasoning: String?
    var isCustomized: Bool = false
    
    init(text: String, tone: ReplyTone, confidence: Double, reasoning: String? = nil) {
        self.id = UUID().uuidString
        self.text = text
        self.tone = tone
        self.confidence = confidence
        self.reasoning = reasoning
        self.isCustomized = false
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case tone
        case confidence
        case reasoning
        case isCustomized
    }
}

enum ReplyTone: String, Codable, CaseIterable {
    case friendly = "friendly"
    case professional = "professional"
    case casual = "casual"
    case formal = "formal"
    
    var displayName: String {
        switch self {
        case .friendly:
            return "Friendly"
        case .professional:
            return "Professional"
        case .casual:
            return "Casual"
        case .formal:
            return "Formal"
        }
    }
    
    var icon: String {
        switch self {
        case .friendly:
            return "😊"
        case .professional:
            return "💼"
        case .casual:
            return "👋"
        case .formal:
            return "🎩"
        }
    }
}

enum RelationshipType: String, Codable, CaseIterable {
    case friend = "friend"
    case colleague = "colleague"
    case family = "family"
    case customer = "customer"
    
    var displayName: String {
        switch self {
        case .friend:
            return "Friend"
        case .colleague:
            return "Colleague"
        case .family:
            return "Family"
        case .customer:
            return "Customer"
        }
    }
}

// Response from the Cloud Function
struct SmartRepliesResponse: Codable {
    let suggestions: [SmartReplySuggestion]
    let contextSummary: String?
    let success: Bool
    let error: String?
    
    struct SmartReplySuggestion: Codable {
        let text: String
        let tone: String
        let reasoning: String?
        let confidence: Double
    }
}

// Smart Compose structures
struct SmartComposeRequest: Codable {
    let partialText: String
    let conversationContext: [String]
    let language: String
    let tone: String?
}

struct SmartComposeResponse: Codable {
    let completion: String
    let fullText: String
    let confidence: Double
    let success: Bool
    let error: String?
}

// Settings for smart replies
struct SmartReplySettings: Codable {
    var enabled: Bool = true
    var defaultTone: ReplyTone = .friendly
    var numberOfSuggestions: Int = 3
    var autoGenerateOnNewMessage: Bool = true
    var showConfidenceScores: Bool = false
    
    // Per-conversation settings
    var conversationRelationships: [String: RelationshipType] = [:] // conversationId -> relationship
    
    static let key = "smartReplySettings"
    
    static func load() -> SmartReplySettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(SmartReplySettings.self, from: data) else {
            return SmartReplySettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SmartReplySettings.key)
        }
    }
    
    func getRelationship(for conversationId: String) -> RelationshipType {
        return conversationRelationships[conversationId] ?? .friend
    }
    
    mutating func setRelationship(_ relationship: RelationshipType, for conversationId: String) {
        conversationRelationships[conversationId] = relationship
        save()
    }
}

