import Foundation
import SwiftUI
import Combine

/// ViewModel for managing translation state and UI interactions
class TranslationViewModel: ObservableObject {
    @Published var isTranslating = false
    @Published var translationError: String?
    @Published var currentTranslation: TranslationResult?
    @Published var showTranslation = false
    @Published var selectedLanguage: Language?
    @Published var recentLanguages: [Language] = []
    
    private let translationService: TranslationService
    private let maxRecentLanguages = 5
    
    init(translationService: TranslationService = TranslationService()) {
        self.translationService = translationService
        loadRecentLanguages()
    }
    
    /// Translate a message to the selected language
    @MainActor
    func translateMessage(
        messageId: String,
        conversationId: String,
        targetLanguage: Language,
        text: String? = nil
    ) async {
        guard !isTranslating else { return }
        
        isTranslating = true
        translationError = nil
        
        do {
            let result = try await translationService.translateMessage(
                messageId: messageId,
                conversationId: conversationId,
                targetLanguage: targetLanguage.name,
                text: text
            )
            
            currentTranslation = result
            showTranslation = true
            addToRecentLanguages(targetLanguage)
            
        } catch let error as TranslationError {
            translationError = error.errorDescription
            print("Translation error: \(error.errorDescription ?? "Unknown error")")
        } catch {
            translationError = "Failed to translate message"
            print("Unexpected error: \(error.localizedDescription)")
        }
        
        isTranslating = false
    }
    
    /// Batch translate multiple messages
    @MainActor
    func batchTranslateMessages(
        messageIds: [String],
        conversationId: String,
        targetLanguage: Language
    ) async -> [BatchTranslationResult] {
        guard !isTranslating else { return [] }
        
        isTranslating = true
        translationError = nil
        
        var results: [BatchTranslationResult] = []
        
        do {
            results = try await translationService.batchTranslate(
                messageIds: messageIds,
                conversationId: conversationId,
                targetLanguage: targetLanguage.name
            )
            
            addToRecentLanguages(targetLanguage)
            
        } catch let error as TranslationError {
            translationError = error.errorDescription
            print("Batch translation error: \(error.errorDescription ?? "Unknown error")")
        } catch {
            translationError = "Failed to batch translate messages"
            print("Unexpected error: \(error.localizedDescription)")
        }
        
        isTranslating = false
        return results
    }
    
    /// Clear current translation
    func clearTranslation() {
        currentTranslation = nil
        showTranslation = false
        translationError = nil
    }
    
    /// Add language to recent languages list
    private func addToRecentLanguages(_ language: Language) {
        // Remove if already exists
        recentLanguages.removeAll { $0.name == language.name }
        
        // Add to beginning
        recentLanguages.insert(language, at: 0)
        
        // Keep only max recent languages
        if recentLanguages.count > maxRecentLanguages {
            recentLanguages = Array(recentLanguages.prefix(maxRecentLanguages))
        }
        
        saveRecentLanguages()
    }
    
    /// Save recent languages to UserDefaults
    private func saveRecentLanguages() {
        let languageNames = recentLanguages.map { $0.name }
        UserDefaults.standard.set(languageNames, forKey: "RecentTranslationLanguages")
    }
    
    /// Load recent languages from UserDefaults
    private func loadRecentLanguages() {
        guard let languageNames = UserDefaults.standard.array(forKey: "RecentTranslationLanguages") as? [String] else {
            return
        }
        
        recentLanguages = languageNames.compactMap { name in
            Language.all.first { $0.name == name }
        }
    }
    
    /// Clear all cached translations
    func clearAllCache() {
        translationService.clearCache()
    }
    
    /// Get cached translation for a message
    func getCachedTranslation(messageId: String, language: String) -> String? {
        return translationService.cachedTranslations[messageId]?[language]
    }
}

