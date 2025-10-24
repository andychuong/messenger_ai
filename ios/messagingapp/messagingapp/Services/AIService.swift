//
//  AIService.swift
//  messagingapp
//
//  AI Assistant Service for chatting with GPT-4o powered assistant
//

import Foundation
import FirebaseFunctions
import Combine

// MARK: - Models

struct AIConversationMessage: Codable, Identifiable {
    var id = UUID()
    let role: String // "user", "assistant", "system"
    let content: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case role, content, timestamp
    }
}

struct AIAssistantResponse: Codable {
    let response: String?  // Optional to handle potential null responses
    let toolsUsed: [String]
    let timestamp: Double
}

struct ConversationSummary: Codable {
    let summary: String
    let messageCount: Int
    let participants: [String]
    let timeRange: TimeRange?
    
    struct TimeRange: Codable {
        let start: Double?
        let end: Double?
    }
}

// MARK: - AI Service

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    
    private let functions = Functions.functions()
    
    // Conversation history for multi-turn conversations
    @Published var conversationHistory: [AIConversationMessage] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - Main Chat Function
    
    /// Chat with AI assistant
    func chatWithAssistant(
        query: String,
        conversationId: String? = nil,
        includeHistory: Bool = true
    ) async throws -> AIAssistantResponse {
        isLoading = true
        defer { isLoading = false }
        
        guard let userId = AuthService.shared?.currentUser?.id else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Add user message to history
        let userMessage = AIConversationMessage(
            role: "user",
            content: query,
            timestamp: Date()
        )
        conversationHistory.append(userMessage)
        
        // Prepare request data
        var requestData: [String: Any] = [
            "query": query,
            "userId": userId
        ]
        
        if let conversationId = conversationId {
            requestData["conversationId"] = conversationId
        }
        
        // Include conversation history if requested
        if includeHistory && !conversationHistory.isEmpty {
            let history = conversationHistory.suffix(10).map { msg in
                [
                    "role": msg.role,
                    "content": msg.content,
                    "timestamp": msg.timestamp.timeIntervalSince1970
                ]
            }
            requestData["conversationHistory"] = history
        }
        
        print("🤖 Sending request to chatWithAssistant:", requestData)
        
        do {
            let result = try await functions.httpsCallable("chatWithAssistant").call(requestData)
            
            guard let data = result.data as? [String: Any],
                  let response = data["response"] as? String,
                  let timestamp = data["timestamp"] as? Double else {
                throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let toolsUsed = data["toolsUsed"] as? [String] ?? []
            
            let assistantResponse = AIAssistantResponse(
                response: response,
                toolsUsed: toolsUsed,
                timestamp: timestamp
            )
            
            // Add assistant response to history
            let assistantMessage = AIConversationMessage(
                role: "assistant",
                content: response,
                timestamp: Date(timeIntervalSince1970: timestamp / 1000)
            )
            conversationHistory.append(assistantMessage)
            
            print("✅ Received response from assistant")
            print("🔧 Tools used:", toolsUsed)
            
            return assistantResponse
        } catch {
            print("❌ Error chatting with assistant:", error)
            self.error = error
            throw error
        }
    }
    
    // MARK: - Specialized Commands
    
    /// Summarize a specific conversation
    func summarizeConversation(conversationId: String) async throws -> ConversationSummary {
        let query = "Please summarize this conversation."
        let response = try await chatWithAssistant(query: query, conversationId: conversationId, includeHistory: false)
        
        // Parse summary from response (GPT will use the summarize_conversation tool)
        // For now, return a simple structure
        return ConversationSummary(
            summary: response.response ?? "No summary available",
            messageCount: 0,
            participants: [],
            timeRange: nil
        )
    }
    
    /// Get user's action items
    func getActionItems(status: String = "pending") async throws -> String {
        let query = "What are my \(status) action items?"
        let response = try await chatWithAssistant(query: query, includeHistory: false)
        return response.response ?? "No action items found"
    }
    
    /// Search messages semantically
    func searchMessages(query: String, conversationId: String? = nil) async throws -> String {
        var searchQuery = "Find messages about: \(query)"
        if let convId = conversationId {
            searchQuery += " in conversation \(convId)"
        }
        let response = try await chatWithAssistant(query: searchQuery, conversationId: conversationId, includeHistory: false)
        return response.response ?? "No results found"
    }
    
    /// Get decisions from conversations
    func getDecisions(conversationId: String? = nil) async throws -> String {
        var query = "What decisions have been made"
        if conversationId != nil {
            query += " in this conversation?"
        } else {
            query += "?"
        }
        let response = try await chatWithAssistant(query: query, conversationId: conversationId, includeHistory: false)
        return response.response ?? "No decisions found"
    }
    
    /// Get priority messages
    func getPriorityMessages() async throws -> String {
        let query = "What are my priority messages?"
        let response = try await chatWithAssistant(query: query, includeHistory: false)
        return response.response ?? "No priority messages found"
    }
    
    // MARK: - History Management
    
    /// Clear conversation history
    func clearHistory() {
        conversationHistory.removeAll()
    }
    
    /// Save conversation history to UserDefaults
    func saveHistory() {
        if let encoded = try? JSONEncoder().encode(conversationHistory) {
            UserDefaults.standard.set(encoded, forKey: "aiConversationHistory")
        }
    }
    
    /// Load conversation history from UserDefaults
    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "aiConversationHistory"),
           let decoded = try? JSONDecoder().decode([AIConversationMessage].self, from: data) {
            conversationHistory = decoded
        }
    }
    
    /// Get formatted history for display
    func getFormattedHistory() -> [(role: String, content: String, date: Date)] {
        return conversationHistory.map { msg in
            (role: msg.role, content: msg.content, date: msg.timestamp)
        }
    }
}

