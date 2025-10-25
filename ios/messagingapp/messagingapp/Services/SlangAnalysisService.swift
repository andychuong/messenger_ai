//
//  SlangAnalysisService.swift
//  messagingapp
//
//  Phase 15.3: Slang Analysis Service
//  Detects and explains slang, idioms, and colloquial expressions
//

import Foundation
import FirebaseFunctions
import Combine

/// Service for analyzing slang and idioms in messages
@MainActor
class SlangAnalysisService: ObservableObject {
    
    static let shared = SlangAnalysisService()
    
    private let functions = Functions.functions()
    private var cache: [String: SlangAnalysis] = [:]
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Analyze a message for slang and idioms
    /// - Parameters:
    ///   - text: The message text to analyze
    ///   - messageId: The message ID for caching
    ///   - conversationId: The conversation ID
    ///   - language: The language of the message
    ///   - userLanguage: The user's preferred language for explanations
    /// - Returns: Slang analysis result
    func analyzeSlang(
        text: String,
        messageId: String,
        conversationId: String,
        language: String,
        userLanguage: String? = nil
    ) async throws -> SlangAnalysis {
        // Check cache first
        let cacheKey = "\(conversationId)_\(messageId)"
        if let cached = cache[cacheKey] {
            print("📚 Slang Analysis: Using cached analysis for message \(messageId)")
            return cached
        }
        
        print("🔍 Slang Analysis: Analyzing message \(messageId)")
        
        var parameters: [String: Any] = [
            "messageId": messageId,
            "conversationId": conversationId,
            "text": text,
            "language": language
        ]
        
        if let userLanguage = userLanguage {
            parameters["userLanguage"] = userLanguage
        }
        
        do {
            let result = try await functions.httpsCallable("explainSlangAndIdioms").call(parameters)
            
            guard let data = result.data as? [String: Any] else {
                throw SlangAnalysisError.invalidResponse
            }
            
            let analysis = try parseSlangAnalysis(from: data)
            
            // Cache the result
            cache[cacheKey] = analysis
            
            print("✅ Slang Analysis: Complete - \(analysis.expressionCount) expressions found")
            
            return analysis
            
        } catch {
            print("❌ Slang Analysis Error: \(error.localizedDescription)")
            throw SlangAnalysisError.analysisFailed(error.localizedDescription)
        }
    }
    
    /// Determine if a message should be analyzed for slang
    /// - Parameters:
    ///   - message: The message to check
    ///   - currentUserId: The current user's ID
    ///   - isEnabled: Whether slang analysis is enabled in settings
    /// - Returns: True if the message should be analyzed
    func shouldAnalyze(message: Message, currentUserId: String, isEnabled: Bool) -> Bool {
        // Only analyze if:
        // 1. Feature is enabled
        // 2. Message is from someone else (not sent by current user)
        // 3. Message is text type
        // 4. Message is not encrypted (or we have decrypted text)
        return isEnabled &&
               message.senderId != currentUserId &&
               message.type == .text &&
               !message.text.isEmpty
    }
    
    /// Get cached slang analysis for a message
    /// - Parameters:
    ///   - messageId: The message ID
    ///   - conversationId: The conversation ID
    /// - Returns: Cached analysis if available
    func getCachedAnalysis(messageId: String, conversationId: String) -> SlangAnalysis? {
        let cacheKey = "\(conversationId)_\(messageId)"
        return cache[cacheKey]
    }
    
    /// Cache a slang analysis
    /// - Parameters:
    ///   - analysis: The analysis to cache
    ///   - messageId: The message ID
    ///   - conversationId: The conversation ID
    func cacheAnalysis(_ analysis: SlangAnalysis, messageId: String, conversationId: String) {
        let cacheKey = "\(conversationId)_\(messageId)"
        cache[cacheKey] = analysis
    }
    
    /// Clear all cached analyses
    func clearCache() {
        cache.removeAll()
        print("🧹 Slang Analysis: Cache cleared")
    }
    
    /// Clear cached analysis for a specific message
    /// - Parameters:
    ///   - messageId: The message ID
    ///   - conversationId: The conversation ID
    func clearCache(messageId: String, conversationId: String) {
        let cacheKey = "\(conversationId)_\(messageId)"
        cache.removeValue(forKey: cacheKey)
    }
    
    // MARK: - Batch Operations
    
    /// Analyze multiple messages in batch
    /// - Parameters:
    ///   - messageIds: Array of message IDs to analyze
    ///   - conversationId: The conversation ID
    ///   - language: The language of the messages
    ///   - userLanguage: The user's preferred language for explanations
    /// - Returns: Dictionary of message ID to analysis result
    func batchAnalyze(
        messageIds: [String],
        conversationId: String,
        language: String,
        userLanguage: String? = nil
    ) async throws -> [String: SlangAnalysis] {
        print("🔍 Slang Analysis: Batch analyzing \(messageIds.count) messages")
        
        var parameters: [String: Any] = [
            "messageIds": messageIds,
            "conversationId": conversationId,
            "language": language
        ]
        
        if let userLanguage = userLanguage {
            parameters["userLanguage"] = userLanguage
        }
        
        do {
            let result = try await functions.httpsCallable("batchExplainSlang").call(parameters)
            
            guard let data = result.data as? [String: Any],
                  let analyses = data["analyses"] as? [[String: Any]] else {
                throw SlangAnalysisError.invalidResponse
            }
            
            var results: [String: SlangAnalysis] = [:]
            
            for analysisData in analyses {
                guard let messageId = analysisData["messageId"] as? String,
                      let success = analysisData["success"] as? Bool,
                      success else {
                    continue
                }
                
                if let analysis = try? parseSlangAnalysis(from: analysisData) {
                    results[messageId] = analysis
                    // Cache each result
                    let cacheKey = "\(conversationId)_\(messageId)"
                    cache[cacheKey] = analysis
                }
            }
            
            print("✅ Slang Analysis: Batch complete - \(results.count) analyses")
            
            return results
            
        } catch {
            print("❌ Batch Slang Analysis Error: \(error.localizedDescription)")
            throw SlangAnalysisError.batchAnalysisFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func parseSlangAnalysis(from data: [String: Any]) throws -> SlangAnalysis {
        let hasSlang = data["hasSlang"] as? Bool ?? false
        let timestamp = data["timestamp"] as? String
        let fromCache = data["fromCache"] as? Bool
        
        var expressions: [DetectedExpression] = []
        if let expressionsData = data["detectedExpressions"] as? [[String: Any]] {
            expressions = expressionsData.compactMap { exprDict in
                guard let phrase = exprDict["phrase"] as? String,
                      let typeString = exprDict["type"] as? String,
                      let type = ExpressionType(rawValue: typeString),
                      let explanation = exprDict["explanation"] as? String,
                      let usage = exprDict["usage"] as? String else {
                    return nil
                }
                
                let literalMeaning = exprDict["literalMeaning"] as? String
                let origin = exprDict["origin"] as? String
                let alternatives = exprDict["alternatives"] as? [String]
                let isRegional = exprDict["isRegional"] as? Bool
                let region = exprDict["region"] as? String
                
                return DetectedExpression(
                    phrase: phrase,
                    type: type,
                    explanation: explanation,
                    literalMeaning: literalMeaning,
                    origin: origin,
                    usage: usage,
                    alternatives: alternatives,
                    isRegional: isRegional,
                    region: region
                )
            }
        }
        
        return SlangAnalysis(
            detectedExpressions: expressions,
            hasSlang: hasSlang,
            timestamp: timestamp,
            fromCache: fromCache
        )
    }
}

// MARK: - Errors

enum SlangAnalysisError: LocalizedError {
    case invalidResponse
    case analysisFailed(String)
    case batchAnalysisFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .analysisFailed(let message):
            return "Slang analysis failed: \(message)"
        case .batchAnalysisFailed(let message):
            return "Batch slang analysis failed: \(message)"
        }
    }
}

