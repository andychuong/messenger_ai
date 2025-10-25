//
//  SmartReplyService.swift
//  messagingapp
//
//  Phase 16: Smart Replies & Suggestions
//  Service to generate and manage smart reply suggestions
//

import Foundation
import FirebaseAuth
import FirebaseFunctions

class SmartReplyService {
    static let shared = SmartReplyService()
    
    private let functions = Functions.functions()
    private var cache: [String: CachedSmartReplies] = [:]
    private let cacheExpirationTime: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {}
    
    // MARK: - Smart Replies
    
    /// Generate smart reply suggestions based on conversation context
    func generateSmartReplies(
        conversationId: String,
        recentMessages: [Message],
        userLanguage: String = "English",
        relationship: RelationshipType = .friend
    ) async throws -> [SmartReply] {
        // Check cache first
        if let cached = getCachedReplies(for: conversationId) {
            return cached
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "SmartReplyService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Prepare messages for the API (only send last 10)
        let messagesToSend = Array(recentMessages.suffix(10))
        let messageData = messagesToSend.map { message in
            return [
                "senderId": message.senderId,
                "senderName": message.senderName ?? "Unknown",
                "text": message.text,
                "timestamp": message.timestamp.timeIntervalSince1970
            ] as [String: Any]
        }
        
        let requestData: [String: Any] = [
            "conversationId": conversationId,
            "recentMessages": messageData,
            "userLanguage": userLanguage,
            "recipientInfo": [
                "relationship": relationship.rawValue,
                "formalityPreference": nil
            ] as [String: Any?],
            "currentUserId": currentUserId
        ]
        
        // Call Cloud Function
        let result = try await functions.httpsCallable("generateSmartReplies").call(requestData)
        
        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success else {
            throw NSError(domain: "SmartReplyService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to generate smart replies"])
        }
        
        guard let suggestionsData = data["suggestions"] as? [[String: Any]] else {
            throw NSError(domain: "SmartReplyService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        // Parse suggestions
        let suggestions = suggestionsData.compactMap { dict -> SmartReply? in
            guard let text = dict["text"] as? String,
                  let toneString = dict["tone"] as? String,
                  let confidence = dict["confidence"] as? Double else {
                return nil
            }
            
            let tone = ReplyTone(rawValue: toneString) ?? .friendly
            let reasoning = dict["reasoning"] as? String
            
            return SmartReply(text: text, tone: tone, confidence: confidence, reasoning: reasoning)
        }
        
        // Cache the results
        cacheReplies(suggestions, for: conversationId)
        
        return suggestions
    }
    
    /// Get cached smart replies if available and not expired
    private func getCachedReplies(for conversationId: String) -> [SmartReply]? {
        guard let cached = cache[conversationId] else {
            return nil
        }
        
        // Check if cache is expired
        if Date().timeIntervalSince(cached.timestamp) > cacheExpirationTime {
            cache.removeValue(forKey: conversationId)
            return nil
        }
        
        return cached.replies
    }
    
    /// Cache smart replies for a conversation
    private func cacheReplies(_ replies: [SmartReply], for conversationId: String) {
        cache[conversationId] = CachedSmartReplies(replies: replies, timestamp: Date())
    }
    
    /// Clear cache for a conversation
    func clearCache(for conversationId: String) {
        cache.removeValue(forKey: conversationId)
    }
    
    /// Clear all cached replies
    func clearAllCache() {
        cache.removeAll()
    }
    
    // MARK: - Smart Compose
    
    /// Generate type-ahead completion for partially typed text
    func generateCompletion(
        partialText: String,
        conversationContext: [String],
        language: String = "English",
        tone: ReplyTone = .casual
    ) async throws -> SmartComposeResponse {
        let requestData: [String: Any] = [
            "partialText": partialText,
            "conversationContext": conversationContext,
            "language": language,
            "tone": tone.rawValue
        ]
        
        let result = try await functions.httpsCallable("generateSmartCompose").call(requestData)
        
        guard let data = result.data as? [String: Any] else {
            throw NSError(domain: "SmartReplyService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        let completion = data["completion"] as? String ?? ""
        let fullText = data["fullText"] as? String ?? partialText
        let confidence = data["confidence"] as? Double ?? 0.0
        let success = data["success"] as? Bool ?? false
        let error = data["error"] as? String
        
        return SmartComposeResponse(
            completion: completion,
            fullText: fullText,
            confidence: confidence,
            success: success,
            error: error
        )
    }
    
    // MARK: - Settings
    
    /// Get smart reply settings
    func getSettings() -> SmartReplySettings {
        return SmartReplySettings.load()
    }
    
    /// Update smart reply settings
    func updateSettings(_ settings: SmartReplySettings) {
        settings.save()
    }
    
    /// Check if smart replies should be generated for a conversation
    func shouldGenerateReplies(for conversationId: String) -> Bool {
        let settings = getSettings()
        return settings.enabled && settings.autoGenerateOnNewMessage
    }
}

// MARK: - Supporting Types

private struct CachedSmartReplies {
    let replies: [SmartReply]
    let timestamp: Date
}

// MARK: - Convenience Extensions

extension SmartReplyService {
    /// Generate smart replies with default parameters
    func generateSmartReplies(
        conversationId: String,
        recentMessages: [Message]
    ) async throws -> [SmartReply] {
        let settings = getSettings()
        let relationship = settings.getRelationship(for: conversationId)
        
        // Detect user's language from settings or default to English
        let userLanguage = Locale.current.language.languageCode?.identifier ?? "English"
        let languageName = Locale.current.localizedString(forLanguageCode: userLanguage) ?? "English"
        
        return try await generateSmartReplies(
            conversationId: conversationId,
            recentMessages: recentMessages,
            userLanguage: languageName,
            relationship: relationship
        )
    }
}

