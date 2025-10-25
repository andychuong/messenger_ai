//
//  CulturalContext.swift
//  messagingapp
//
//  Phase 15.1: Cultural Context Models
//  Models for cultural context analysis, idioms, and formality levels
//

import Foundation

// MARK: - Formality Level

/// Represents the formality level of a message
enum FormalityLevel: String, Codable, CaseIterable {
    case veryFormal = "very_formal"
    case formal = "formal"
    case neutral = "neutral"
    case casual = "casual"
    case veryCasual = "very_casual"
    
    var displayName: String {
        switch self {
        case .veryFormal: return "Very Formal"
        case .formal: return "Formal"
        case .neutral: return "Neutral"
        case .casual: return "Casual"
        case .veryCasual: return "Very Casual"
        }
    }
    
    var description: String {
        switch self {
        case .veryFormal:
            return "Highly polite, uses honorifics and formal language"
        case .formal:
            return "Professional and respectful tone"
        case .neutral:
            return "Balanced, neither too formal nor too casual"
        case .casual:
            return "Friendly and conversational"
        case .veryCasual:
            return "Very informal, may include slang"
        }
    }
    
    var icon: String {
        switch self {
        case .veryFormal: return "👔"
        case .formal: return "🎩"
        case .neutral: return "💬"
        case .casual: return "😊"
        case .veryCasual: return "🤙"
        }
    }
}

// MARK: - Idiom

/// Represents an idiom or cultural expression found in a message
struct Idiom: Codable, Identifiable {
    let id: UUID
    let phrase: String
    let meaning: String
    let culturalSignificance: String?
    
    enum CodingKeys: String, CodingKey {
        case phrase, meaning, culturalSignificance
    }
    
    init(phrase: String, meaning: String, culturalSignificance: String? = nil) {
        self.id = UUID()
        self.phrase = phrase
        self.meaning = meaning
        self.culturalSignificance = culturalSignificance
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.phrase = try container.decode(String.self, forKey: .phrase)
        self.meaning = try container.decode(String.self, forKey: .meaning)
        self.culturalSignificance = try container.decodeIfPresent(String.self, forKey: .culturalSignificance)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phrase, forKey: .phrase)
        try container.encode(meaning, forKey: .meaning)
        try container.encodeIfPresent(culturalSignificance, forKey: .culturalSignificance)
    }
}

// MARK: - Cultural Context

/// Cultural context information for a message
struct CulturalContext: Codable {
    let culturalNotes: [String]
    let idioms: [Idiom]
    let formalityLevel: FormalityLevel
    let recommendations: [String]?
    let timestamp: String?
    let fromCache: Bool?
    
    var hasContent: Bool {
        !culturalNotes.isEmpty || !idioms.isEmpty || !(recommendations?.isEmpty ?? true)
    }
    
    init(
        culturalNotes: [String],
        idioms: [Idiom],
        formalityLevel: FormalityLevel,
        recommendations: [String]? = nil,
        timestamp: String? = nil,
        fromCache: Bool? = nil
    ) {
        self.culturalNotes = culturalNotes
        self.idioms = idioms
        self.formalityLevel = formalityLevel
        self.recommendations = recommendations
        self.timestamp = timestamp
        self.fromCache = fromCache
    }
}

// MARK: - Formality Adjustment

/// Represents a change made during formality adjustment
struct FormalityChange: Codable, Identifiable {
    let id: UUID
    let original: String
    let adjusted: String
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case original, adjusted, reason
    }
    
    init(original: String, adjusted: String, reason: String) {
        self.id = UUID()
        self.original = original
        self.adjusted = adjusted
        self.reason = reason
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.original = try container.decode(String.self, forKey: .original)
        self.adjusted = try container.decode(String.self, forKey: .adjusted)
        self.reason = try container.decode(String.self, forKey: .reason)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(original, forKey: .original)
        try container.encode(adjusted, forKey: .adjusted)
        try container.encode(reason, forKey: .reason)
    }
}

/// Response from formality adjustment
struct FormalityAdjustment: Codable {
    let adjustedText: String
    let originalFormality: String
    let targetFormality: String
    let changes: [FormalityChange]
    
    var hasChanges: Bool {
        !changes.isEmpty
    }
}

// MARK: - Slang Expression

/// Type of expression detected
enum ExpressionType: String, Codable {
    case slang = "slang"
    case idiom = "idiom"
    case colloquialism = "colloquialism"
    case culturalReference = "cultural_reference"
    
    var displayName: String {
        switch self {
        case .slang: return "Slang"
        case .idiom: return "Idiom"
        case .colloquialism: return "Colloquialism"
        case .culturalReference: return "Cultural Reference"
        }
    }
    
    var icon: String {
        switch self {
        case .slang: return "💬"
        case .idiom: return "📚"
        case .colloquialism: return "🗣️"
        case .culturalReference: return "🌍"
        }
    }
}

/// A detected slang expression or idiom
struct DetectedExpression: Codable, Identifiable {
    let id: UUID
    let phrase: String
    let type: ExpressionType
    let explanation: String
    let literalMeaning: String?
    let origin: String?
    let usage: String
    let alternatives: [String]?
    let isRegional: Bool?
    let region: String?
    
    enum CodingKeys: String, CodingKey {
        case phrase, type, explanation, literalMeaning, origin, usage
        case alternatives, isRegional, region
    }
    
    init(
        phrase: String,
        type: ExpressionType,
        explanation: String,
        literalMeaning: String? = nil,
        origin: String? = nil,
        usage: String,
        alternatives: [String]? = nil,
        isRegional: Bool? = nil,
        region: String? = nil
    ) {
        self.id = UUID()
        self.phrase = phrase
        self.type = type
        self.explanation = explanation
        self.literalMeaning = literalMeaning
        self.origin = origin
        self.usage = usage
        self.alternatives = alternatives
        self.isRegional = isRegional
        self.region = region
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.phrase = try container.decode(String.self, forKey: .phrase)
        self.type = try container.decode(ExpressionType.self, forKey: .type)
        self.explanation = try container.decode(String.self, forKey: .explanation)
        self.literalMeaning = try container.decodeIfPresent(String.self, forKey: .literalMeaning)
        self.origin = try container.decodeIfPresent(String.self, forKey: .origin)
        self.usage = try container.decode(String.self, forKey: .usage)
        self.alternatives = try container.decodeIfPresent([String].self, forKey: .alternatives)
        self.isRegional = try container.decodeIfPresent(Bool.self, forKey: .isRegional)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phrase, forKey: .phrase)
        try container.encode(type, forKey: .type)
        try container.encode(explanation, forKey: .explanation)
        try container.encodeIfPresent(literalMeaning, forKey: .literalMeaning)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encode(usage, forKey: .usage)
        try container.encodeIfPresent(alternatives, forKey: .alternatives)
        try container.encodeIfPresent(isRegional, forKey: .isRegional)
        try container.encodeIfPresent(region, forKey: .region)
    }
}

/// Slang analysis result for a message
struct SlangAnalysis: Codable {
    let detectedExpressions: [DetectedExpression]
    let hasSlang: Bool
    let timestamp: String?
    let fromCache: Bool?
    
    var expressionCount: Int {
        detectedExpressions.count
    }
    
    init(
        detectedExpressions: [DetectedExpression],
        hasSlang: Bool,
        timestamp: String? = nil,
        fromCache: Bool? = nil
    ) {
        self.detectedExpressions = detectedExpressions
        self.hasSlang = hasSlang
        self.timestamp = timestamp
        self.fromCache = fromCache
    }
}

