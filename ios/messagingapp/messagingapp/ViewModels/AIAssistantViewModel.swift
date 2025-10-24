//
//  AIAssistantViewModel.swift
//  messagingapp
//
//  ViewModel for AI Assistant chat interface
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AIAssistantViewModel: ObservableObject {
    @Published var messages: [AIConversationMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentConversationId: String?
    
    private let aiService = AIService.shared
    
    // Suggested quick actions
    let quickActions = [
        QuickAction(title: "Summarize", icon: "doc.text.magnifyingglass", query: "Summarize this conversation"),
        QuickAction(title: "Action Items", icon: "checklist", query: "What are my pending action items?"),
        QuickAction(title: "Decisions", icon: "lightbulb", query: "What decisions have been made?"),
        QuickAction(title: "Priority", icon: "exclamationmark.triangle", query: "Show me priority messages"),
    ]
    
    init() {
        loadHistory()
    }
    
    // MARK: - Actions
    
    /// Send a message to the AI assistant
    func sendMessage(_ text: String? = nil, conversationId: String? = nil) async {
        let messageText = text ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !messageText.isEmpty else { return }
        
        // Clear input if using the input field
        if text == nil {
            inputText = ""
        }
        
        // Add user message immediately for better UX
        let userMessage = AIConversationMessage(
            role: "user",
            content: messageText,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Add temporary "thinking..." message
        let thinkingMessage = AIConversationMessage(
            role: "assistant",
            content: "Thinking...",
            timestamp: Date()
        )
        messages.append(thinkingMessage)
        
        isLoading = true
        error = nil
        
        do {
            let response = try await aiService.chatWithAssistant(
                query: messageText,
                conversationId: conversationId ?? currentConversationId,
                includeHistory: true
            )
            
            // Remove thinking message
            if let thinkingIndex = messages.lastIndex(where: { $0.content == "Thinking..." && $0.role == "assistant" }) {
                messages.remove(at: thinkingIndex)
            }
            
            // Validate response is not empty
            let responseContent = response.response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if responseContent.isEmpty {
                // Handle empty response
                let errorMessage = AIConversationMessage(
                    role: "assistant",
                    content: "I received your message but wasn't able to generate a response. Please try again.",
                    timestamp: Date()
                )
                messages.append(errorMessage)
            } else {
                // Add assistant response
                let assistantMessage = AIConversationMessage(
                    role: "assistant",
                    content: responseContent,
                    timestamp: Date(timeIntervalSince1970: response.timestamp / 1000)
                )
                messages.append(assistantMessage)
            }
            
            // Save history
            saveHistory()
            
            isLoading = false
        } catch {
            print("Error sending message to assistant:", error)
            self.error = error.localizedDescription
            
            // Remove thinking message
            if let thinkingIndex = messages.lastIndex(where: { $0.content == "Thinking..." && $0.role == "assistant" }) {
                messages.remove(at: thinkingIndex)
            }
            
            // Add error message
            let errorMessage = AIConversationMessage(
                role: "assistant",
                content: "Sorry, I encountered an error: \(error.localizedDescription)",
                timestamp: Date()
            )
            messages.append(errorMessage)
            
            isLoading = false
        }
    }
    
    /// Send a quick action query
    func sendQuickAction(_ action: QuickAction) async {
        await sendMessage(action.query, conversationId: currentConversationId)
    }
    
    /// Set context for conversation-specific queries
    func setConversationContext(_ conversationId: String?) {
        currentConversationId = conversationId
    }
    
    /// Clear conversation history
    func clearHistory() {
        messages.removeAll()
        aiService.clearHistory()
        UserDefaults.standard.removeObject(forKey: "aiAssistantMessages")
    }
    
    /// Save messages to local storage
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: "aiAssistantMessages")
        }
    }
    
    /// Load messages from local storage
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "aiAssistantMessages"),
           let decoded = try? JSONDecoder().decode([AIConversationMessage].self, from: data) {
            messages = decoded
        }
        
        // Also load AIService history
        aiService.loadHistory()
    }
}

// MARK: - Quick Action Model

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let query: String
}

