//
//  RAGService.swift
//  messagingapp
//
//  Phase 8: Retrieval-Augmented Generation (RAG) Service
//  Handles semantic search and question answering over conversation history
//

import Foundation
import FirebaseAuth
import FirebaseFunctions

/// Service for RAG-powered semantic search and question answering
class RAGService {
    static let shared = RAGService()
    private let functions = Functions.functions()
    
    private init() {}
    
    // MARK: - Semantic Search
    
    /// Perform semantic search across messages
    /// - Parameters:
    ///   - query: Search query
    ///   - conversationId: Optional conversation to limit search to
    ///   - limit: Maximum number of results
    /// - Returns: Array of search results with similarity scores
    func semanticSearch(
        query: String,
        conversationId: String? = nil,
        limit: Int = 10
    ) async throws -> SemanticSearchResponse {
        var data: [String: Any] = [
            "query": query,
            "limit": limit
        ]
        
        if let conversationId = conversationId {
            data["conversationId"] = conversationId
        }
        
        let result = try await functions.httpsCallable("semanticSearch").call(data)
        
        guard let responseData = result.data as? [String: Any] else {
            throw RAGError.invalidResponse
        }
        
        return try parseSemanticSearchResponse(responseData)
    }
    
    /// Answer a question using RAG (semantic search + GPT-4o)
    /// - Parameters:
    ///   - question: Question to answer
    ///   - conversationId: Optional conversation to limit search to
    ///   - limit: Maximum number of context messages to use
    /// - Returns: Answer with sources
    func answerQuestion(
        question: String,
        conversationId: String? = nil,
        limit: Int = 10
    ) async throws -> QuestionAnswerResponse {
        var data: [String: Any] = [
            "question": question,
            "limit": limit
        ]
        
        if let conversationId = conversationId {
            data["conversationId"] = conversationId
        }
        
        let result = try await functions.httpsCallable("answerQuestion").call(data)
        
        guard let responseData = result.data as? [String: Any] else {
            throw RAGError.invalidResponse
        }
        
        return try parseQuestionAnswerResponse(responseData)
    }
    
    // MARK: - Action Items
    
    /// Extract action items from a message
    /// - Parameters:
    ///   - messageText: Text of the message
    ///   - messageId: ID of the message
    ///   - conversationId: ID of the conversation
    ///   - senderId: ID of the sender
    /// - Returns: Extracted action items
    func extractActionItems(
        from messageText: String,
        messageId: String,
        conversationId: String,
        senderId: String
    ) async throws -> [ActionItem] {
        let data: [String: Any] = [
            "messageText": messageText,
            "messageId": messageId,
            "conversationId": conversationId,
            "senderId": senderId
        ]
        
        let result = try await functions.httpsCallable("extractActionItems").call(data)
        
        guard let responseData = result.data as? [String: Any],
              let actionItemsData = responseData["actionItems"] as? [[String: Any]] else {
            throw RAGError.invalidResponse
        }
        
        return try parseActionItems(actionItemsData)
    }
    
    /// Extract action items from entire conversation
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - limit: Maximum number of recent messages to analyze
    /// - Returns: Extracted action items
    func extractActionItemsFromConversation(
        conversationId: String,
        limit: Int = 50
    ) async throws -> [ActionItem] {
        let data: [String: Any] = [
            "conversationId": conversationId,
            "limit": limit
        ]
        
        let result = try await functions.httpsCallable("extractActionItemsFromConversation").call(data)
        
        guard let responseData = result.data as? [String: Any],
              let actionItemsData = responseData["actionItems"] as? [[String: Any]] else {
            throw RAGError.invalidResponse
        }
        
        return try parseActionItems(actionItemsData)
    }
    
    /// Update action item status
    /// - Parameters:
    ///   - actionItemId: ID of the action item
    ///   - status: New status
    ///   - completedBy: User ID who completed it (if applicable)
    func updateActionItemStatus(
        actionItemId: String,
        status: ActionItem.Status,
        completedBy: String? = nil
    ) async throws {
        var data: [String: Any] = [
            "actionItemId": actionItemId,
            "status": status.rawValue
        ]
        
        if let completedBy = completedBy {
            data["completedBy"] = completedBy
        }
        
        _ = try await functions.httpsCallable("updateActionItemStatus").call(data)
    }
    
    /// Get user's action items
    /// - Parameters:
    ///   - status: Filter by status
    ///   - limit: Maximum number of items
    /// - Returns: Array of action items
    func getUserActionItems(
        status: ActionItem.Status = .pending,
        limit: Int = 50
    ) async throws -> [ActionItem] {
        let data: [String: Any] = [
            "status": status.rawValue,
            "limit": limit
        ]
        
        let result = try await functions.httpsCallable("getUserActionItems").call(data)
        
        guard let responseData = result.data as? [String: Any],
              let actionItemsData = responseData["actionItems"] as? [[String: Any]] else {
            throw RAGError.invalidResponse
        }
        
        return try parseActionItems(actionItemsData)
    }
    
    // MARK: - Decisions
    
    /// Detect decision in a message
    /// - Parameters:
    ///   - messageText: Text of the message
    ///   - messageId: ID of the message
    ///   - conversationId: ID of the conversation
    ///   - senderId: ID of the sender
    /// - Returns: Detected decision (if any)
    func detectDecision(
        in messageText: String,
        messageId: String,
        conversationId: String,
        senderId: String
    ) async throws -> Decision? {
        let data: [String: Any] = [
            "messageText": messageText,
            "messageId": messageId,
            "conversationId": conversationId,
            "senderId": senderId
        ]
        
        let result = try await functions.httpsCallable("detectDecision").call(data)
        
        guard let responseData = result.data as? [String: Any] else {
            throw RAGError.invalidResponse
        }
        
        let hasDecision = responseData["hasDecision"] as? Bool ?? false
        
        if !hasDecision {
            return nil
        }
        
        guard let decisionData = responseData["decision"] as? [String: Any] else {
            return nil
        }
        
        return try parseDecision(decisionData)
    }
    
    /// Get decisions from a conversation
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - limit: Maximum number of decisions
    /// - Returns: Array of decisions
    func getConversationDecisions(
        conversationId: String,
        limit: Int = 20
    ) async throws -> [Decision] {
        let data: [String: Any] = [
            "conversationId": conversationId,
            "limit": limit
        ]
        
        let result = try await functions.httpsCallable("getConversationDecisions").call(data)
        
        guard let responseData = result.data as? [String: Any],
              let decisionsData = responseData["decisions"] as? [[String: Any]] else {
            throw RAGError.invalidResponse
        }
        
        return parseDecisions(decisionsData)
    }
    
    // MARK: - Priority Classification
    
    /// Classify message priority
    /// - Parameters:
    ///   - messageText: Text of the message
    ///   - messageId: ID of the message
    ///   - conversationId: ID of the conversation
    ///   - mentions: Array of mentioned user IDs
    /// - Returns: Priority classification result
    func classifyPriority(
        messageText: String,
        messageId: String,
        conversationId: String,
        mentions: [String] = []
    ) async throws -> PriorityClassification {
        let data: [String: Any] = [
            "messageText": messageText,
            "messageId": messageId,
            "conversationId": conversationId,
            "mentions": mentions
        ]
        
        let result = try await functions.httpsCallable("classifyPriority").call(data)
        
        guard let responseData = result.data as? [String: Any] else {
            throw RAGError.invalidResponse
        }
        
        return try parsePriorityClassification(responseData)
    }
    
    // MARK: - Parsing Helpers
    
    private func parseSemanticSearchResponse(_ data: [String: Any]) throws -> SemanticSearchResponse {
        guard let query = data["query"] as? String,
              let resultsData = data["results"] as? [[String: Any]] else {
            throw RAGError.invalidResponse
        }
        
        let results = resultsData.compactMap { resultData -> SearchResult? in
            guard let messageId = resultData["messageId"] as? String,
                  let conversationId = resultData["conversationId"] as? String,
                  let text = resultData["text"] as? String,
                  let similarity = resultData["similarity"] as? Double else {
                return nil
            }
            
            return SearchResult(
                messageId: messageId,
                conversationId: conversationId,
                text: text,
                similarity: similarity,
                timestamp: parseDate(resultData["timestamp"])
            )
        }
        
        return SemanticSearchResponse(query: query, results: results)
    }
    
    private func parseQuestionAnswerResponse(_ data: [String: Any]) throws -> QuestionAnswerResponse {
        guard let answer = data["answer"] as? String,
              let sourcesData = data["sources"] as? [[String: Any]] else {
            throw RAGError.invalidResponse
        }
        
        let sources = sourcesData.compactMap { sourceData -> AnswerSource? in
            guard let messageId = sourceData["messageId"] as? String,
                  let conversationId = sourceData["conversationId"] as? String,
                  let sender = sourceData["sender"] as? String,
                  let text = sourceData["text"] as? String,
                  let similarity = sourceData["similarity"] as? Double else {
                return nil
            }
            
            return AnswerSource(
                messageId: messageId,
                conversationId: conversationId,
                sender: sender,
                text: text,
                similarity: similarity
            )
        }
        
        let contextUsed = data["contextUsed"] as? Int ?? sources.count
        
        return QuestionAnswerResponse(
            answer: answer,
            sources: sources,
            contextUsed: contextUsed
        )
    }
    
    private func parseActionItems(_ data: [[String: Any]]) throws -> [ActionItem] {
        return data.compactMap { itemData in
            guard let task = itemData["task"] as? String,
                  let createdBy = itemData["createdBy"] as? String,
                  let conversationId = itemData["conversationId"] as? String else {
                return nil
            }
            
            let priorityStr = itemData["priority"] as? String ?? "medium"
            let priority = ActionItem.Priority(rawValue: priorityStr) ?? .medium
            
            let statusStr = itemData["status"] as? String ?? "pending"
            let status = ActionItem.Status(rawValue: statusStr) ?? .pending
            
            return ActionItem(
                id: itemData["id"] as? String,
                task: task,
                assignedTo: itemData["assignedTo"] as? String,
                createdBy: createdBy,
                conversationId: conversationId,
                messageId: itemData["messageId"] as? String,
                priority: priority,
                status: status,
                dueDate: parseDate(itemData["dueDate"]),
                extractedAt: parseDate(itemData["extractedAt"]) ?? Date(),
                createdAt: parseDate(itemData["createdAt"]) ?? Date(),
                completedAt: parseDate(itemData["completedAt"]),
                completedBy: itemData["completedBy"] as? String
            )
        }
    }
    
    private func parseDecision(_ data: [String: Any]) throws -> Decision {
        guard let decision = data["decision"] as? String,
              let conversationId = data["conversationId"] as? String,
              let messageId = data["messageId"] as? String,
              let decidedBy = data["decidedBy"] as? String else {
            throw RAGError.invalidResponse
        }
        
        return Decision(
            id: data["id"] as? String,
            decision: decision,
            rationale: data["rationale"] as? String,
            outcome: data["outcome"] as? String,
            conversationId: conversationId,
            messageId: messageId,
            decidedBy: decidedBy,
            detectedAt: parseDate(data["detectedAt"]) ?? Date(),
            createdAt: parseDate(data["createdAt"]) ?? Date()
        )
    }
    
    private func parseDecisions(_ data: [[String: Any]]) -> [Decision] {
        return data.compactMap { try? parseDecision($0) }
    }
    
    private func parsePriorityClassification(_ data: [String: Any]) throws -> PriorityClassification {
        guard let priorityStr = data["priority"] as? String,
              let reason = data["reason"] as? String else {
            throw RAGError.invalidResponse
        }
        
        let priority: MessagePriority
        switch priorityStr {
        case "high": priority = .high
        case "low": priority = .low
        default: priority = .medium
        }
        
        let requiresResponse = data["requiresResponse"] as? Bool ?? false
        
        return PriorityClassification(
            priority: priority,
            reason: reason,
            requiresResponse: requiresResponse
        )
    }
    
    private func parseDate(_ value: Any?) -> Date? {
        if let timestamp = value as? [String: Any],
           let seconds = timestamp["_seconds"] as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}

// MARK: - Data Models

struct SemanticSearchResponse {
    let query: String
    let results: [SearchResult]
}

struct SearchResult: Identifiable {
    let messageId: String
    let conversationId: String
    let text: String
    let similarity: Double
    let timestamp: Date?
    
    var id: String { messageId }
}

struct QuestionAnswerResponse {
    let answer: String
    let sources: [AnswerSource]
    let contextUsed: Int
}

struct AnswerSource: Identifiable {
    let messageId: String
    let conversationId: String
    let sender: String
    let text: String
    let similarity: Double
    
    var id: String { messageId }
}

struct PriorityClassification {
    let priority: MessagePriority
    let reason: String
    let requiresResponse: Bool
}

enum MessagePriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "circle"
        case .medium: return "circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Errors

enum RAGError: LocalizedError {
    case invalidResponse
    case networkError
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network error occurred"
        case .authenticationRequired:
            return "Authentication required"
        }
    }
}

