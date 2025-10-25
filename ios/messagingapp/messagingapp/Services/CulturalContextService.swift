//
//  CulturalContextService.swift
//  messagingapp
//
//  Phase 15.1: Cultural Context Service
//  Analyzes and caches cultural context for messages
//

import Foundation
import FirebaseFunctions
import Combine

/// Service for analyzing cultural context of messages
@MainActor
class CulturalContextService: ObservableObject {
    
    static let shared = CulturalContextService()
    
    private let functions = Functions.functions()
    private var cache: [String: CulturalContext] = [:]
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Analyze cultural context for a message
    /// - Parameters:
    ///   - text: The message text to analyze
    ///   - messageId: The message ID for caching
    ///   - conversationId: The conversation ID
    ///   - sourceLanguage: The language of the message
    ///   - targetLanguage: The user's preferred language
    ///   - messageContext: Optional previous messages for context
    /// - Returns: Cultural context information
    func analyzeCulturalContext(
        text: String,
        messageId: String,
        conversationId: String,
        sourceLanguage: String,
        targetLanguage: String,
        messageContext: [String]? = nil
    ) async throws -> CulturalContext {
        // Check cache first
        let cacheKey = "\(conversationId)_\(messageId)"
        if let cached = cache[cacheKey] {
            print("📚 Cultural Context: Using cached context for message \(messageId)")
            return cached
        }
        
        print("🔍 Cultural Context: Analyzing message \(messageId)")
        
        let parameters: [String: Any] = [
            "messageId": messageId,
            "conversationId": conversationId,
            "text": text,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage,
            "messageContext": messageContext ?? []
        ]
        
        do {
            let result = try await functions.httpsCallable("analyzeCulturalContext").call(parameters)
            
            guard let data = result.data as? [String: Any] else {
                throw CulturalContextError.invalidResponse
            }
            
            let context = try parseCulturalContext(from: data)
            
            // Cache the result
            cache[cacheKey] = context
            
            print("✅ Cultural Context: Analysis complete - \(context.culturalNotes.count) notes, \(context.idioms.count) idioms")
            
            return context
            
        } catch {
            print("❌ Cultural Context Error: \(error.localizedDescription)")
            throw CulturalContextError.analysisFailed(error.localizedDescription)
        }
    }
    
    /// Get cached context for a message
    /// - Parameters:
    ///   - messageId: The message ID
    ///   - conversationId: The conversation ID
    /// - Returns: Cached cultural context if available
    func getCachedContext(messageId: String, conversationId: String) -> CulturalContext? {
        let cacheKey = "\(conversationId)_\(messageId)"
        return cache[cacheKey]
    }
    
    /// Cache a cultural context
    /// - Parameters:
    ///   - context: The context to cache
    ///   - messageId: The message ID
    ///   - conversationId: The conversation ID
    func cacheContext(_ context: CulturalContext, messageId: String, conversationId: String) {
        let cacheKey = "\(conversationId)_\(messageId)"
        cache[cacheKey] = context
    }
    
    /// Clear all cached contexts
    func clearCache() {
        cache.removeAll()
        print("🧹 Cultural Context: Cache cleared")
    }
    
    /// Clear cached context for a specific message
    /// - Parameters:
    ///   - messageId: The message ID
    ///   - conversationId: The conversation ID
    func clearCache(messageId: String, conversationId: String) {
        let cacheKey = "\(conversationId)_\(messageId)"
        cache.removeValue(forKey: cacheKey)
    }
    
    // MARK: - Private Methods
    
    private func parseCulturalContext(from data: [String: Any]) throws -> CulturalContext {
        // Parse cultural notes
        let culturalNotes = data["culturalNotes"] as? [String] ?? []
        
        // Parse idioms
        var idioms: [Idiom] = []
        if let idiomsData = data["idioms"] as? [[String: Any]] {
            idioms = idiomsData.compactMap { idiomDict in
                guard let phrase = idiomDict["phrase"] as? String,
                      let meaning = idiomDict["meaning"] as? String else {
                    return nil
                }
                let significance = idiomDict["culturalSignificance"] as? String
                return Idiom(phrase: phrase, meaning: meaning, culturalSignificance: significance)
            }
        }
        
        // Parse formality level
        let formalityString = data["formalityLevel"] as? String ?? "neutral"
        let formalityLevel = FormalityLevel(rawValue: formalityString) ?? .neutral
        
        // Parse recommendations
        let recommendations = data["recommendations"] as? [String]
        
        // Parse metadata
        let timestamp = data["timestamp"] as? String
        let fromCache = data["fromCache"] as? Bool
        
        return CulturalContext(
            culturalNotes: culturalNotes,
            idioms: idioms,
            formalityLevel: formalityLevel,
            recommendations: recommendations,
            timestamp: timestamp,
            fromCache: fromCache
        )
    }
}

// MARK: - Formality Adjustment Service

extension CulturalContextService {
    
    /// Adjust the formality level of text
    /// - Parameters:
    ///   - text: The text to adjust
    ///   - language: The language of the text
    ///   - targetFormality: The desired formality level
    ///   - context: Optional context (business, personal, etc.)
    /// - Returns: Adjusted text and changes made
    func adjustFormality(
        text: String,
        language: String,
        targetFormality: FormalityLevel,
        context: String? = nil
    ) async throws -> FormalityAdjustment {
        print("🎩 Formality: Adjusting text to \(targetFormality.rawValue)")
        
        var parameters: [String: Any] = [
            "text": text,
            "language": language,
            "targetFormality": targetFormality.rawValue
        ]
        
        if let context = context {
            parameters["context"] = context
        }
        
        do {
            let result = try await functions.httpsCallable("adjustFormality").call(parameters)
            
            guard let data = result.data as? [String: Any] else {
                throw CulturalContextError.invalidResponse
            }
            
            let adjustment = try parseFormalityAdjustment(from: data)
            
            print("✅ Formality: Adjustment complete - \(adjustment.changes.count) changes")
            
            return adjustment
            
        } catch {
            print("❌ Formality Error: \(error.localizedDescription)")
            throw CulturalContextError.formalityAdjustmentFailed(error.localizedDescription)
        }
    }
    
    /// Detect the formality level of text
    /// - Parameters:
    ///   - text: The text to analyze
    ///   - language: The language of the text
    /// - Returns: Detected formality level and reasoning
    func detectFormality(
        text: String,
        language: String
    ) async throws -> (level: FormalityLevel, reasoning: String) {
        print("🔍 Formality: Detecting formality level")
        
        let parameters: [String: Any] = [
            "text": text,
            "language": language
        ]
        
        do {
            let result = try await functions.httpsCallable("detectFormality").call(parameters)
            
            guard let data = result.data as? [String: Any],
                  let levelString = data["formalityLevel"] as? String,
                  let reasoning = data["reasoning"] as? String else {
                throw CulturalContextError.invalidResponse
            }
            
            let level = FormalityLevel(rawValue: levelString) ?? .neutral
            
            print("✅ Formality: Detected level - \(level.rawValue)")
            
            return (level, reasoning)
            
        } catch {
            print("❌ Formality Detection Error: \(error.localizedDescription)")
            throw CulturalContextError.formalityDetectionFailed(error.localizedDescription)
        }
    }
    
    private func parseFormalityAdjustment(from data: [String: Any]) throws -> FormalityAdjustment {
        guard let adjustedText = data["adjustedText"] as? String,
              let originalFormality = data["originalFormality"] as? String,
              let targetFormality = data["targetFormality"] as? String else {
            throw CulturalContextError.invalidResponse
        }
        
        var changes: [FormalityChange] = []
        if let changesData = data["changes"] as? [[String: Any]] {
            changes = changesData.compactMap { changeDict in
                guard let original = changeDict["original"] as? String,
                      let adjusted = changeDict["adjusted"] as? String,
                      let reason = changeDict["reason"] as? String else {
                    return nil
                }
                return FormalityChange(original: original, adjusted: adjusted, reason: reason)
            }
        }
        
        return FormalityAdjustment(
            adjustedText: adjustedText,
            originalFormality: originalFormality,
            targetFormality: targetFormality,
            changes: changes
        )
    }
}

// MARK: - Errors

enum CulturalContextError: LocalizedError {
    case invalidResponse
    case analysisFailed(String)
    case formalityAdjustmentFailed(String)
    case formalityDetectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .analysisFailed(let message):
            return "Cultural context analysis failed: \(message)"
        case .formalityAdjustmentFailed(let message):
            return "Formality adjustment failed: \(message)"
        case .formalityDetectionFailed(let message):
            return "Formality detection failed: \(message)"
        }
    }
}

