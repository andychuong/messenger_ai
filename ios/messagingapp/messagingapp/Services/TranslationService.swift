import Foundation
import FirebaseFunctions
import Combine

/// Service for handling message translation using AI
class TranslationService: ObservableObject {
    private let functions = Functions.functions()
    
    // Cache translations locally to avoid redundant API calls
    @Published var cachedTranslations: [String: [String: String]] = [:] // messageId -> [language: translatedText]
    
    /// Translate a message to the target language
    /// - Parameters:
    ///   - messageId: ID of the message to translate
    ///   - conversationId: ID of the conversation containing the message
    ///   - targetLanguage: Target language for translation (e.g., "Spanish", "French")
    ///   - text: Optional decrypted text to translate (for encrypted messages)
    /// - Returns: Translation result with original and translated text
    func translateMessage(
        messageId: String,
        conversationId: String,
        targetLanguage: String,
        text: String? = nil
    ) async throws -> TranslationResult {
        // Check local cache first
        if let cached = cachedTranslations[messageId]?[targetLanguage] {
            print("Translation found in local cache")
            return TranslationResult(
                originalText: "",
                translatedText: cached,
                targetLanguage: targetLanguage,
                fromCache: true
            )
        }
        
        var data: [String: Any] = [
            "messageId": messageId,
            "conversationId": conversationId,
            "targetLanguage": targetLanguage
        ]
        
        // Include decrypted text if provided (for encrypted messages)
        if let text = text {
            data["text"] = text
        }
        
        do {
            let result = try await functions.httpsCallable("translateMessage").call(data)
            
            guard let resultData = result.data as? [String: Any],
                  let originalText = resultData["originalText"] as? String,
                  let translatedText = resultData["translatedText"] as? String,
                  let language = resultData["targetLanguage"] as? String,
                  let fromCache = resultData["fromCache"] as? Bool else {
                throw TranslationError.invalidResponse
            }
            
            // Cache locally
            if cachedTranslations[messageId] == nil {
                cachedTranslations[messageId] = [:]
            }
            cachedTranslations[messageId]?[targetLanguage] = translatedText
            
            return TranslationResult(
                originalText: originalText,
                translatedText: translatedText,
                targetLanguage: language,
                fromCache: fromCache
            )
        } catch {
            print("Translation error: \(error.localizedDescription)")
            throw TranslationError.translationFailed(error.localizedDescription)
        }
    }
    
    /// Batch translate multiple messages
    /// - Parameters:
    ///   - messageIds: Array of message IDs to translate
    ///   - conversationId: ID of the conversation
    ///   - targetLanguage: Target language for translation
    /// - Returns: Array of translation results
    func batchTranslate(
        messageIds: [String],
        conversationId: String,
        targetLanguage: String
    ) async throws -> [BatchTranslationResult] {
        guard !messageIds.isEmpty else {
            throw TranslationError.invalidInput
        }
        
        guard messageIds.count <= 50 else {
            throw TranslationError.batchTooLarge
        }
        
        let data: [String: Any] = [
            "messageIds": messageIds,
            "conversationId": conversationId,
            "targetLanguage": targetLanguage
        ]
        
        do {
            let result = try await functions.httpsCallable("batchTranslate").call(data)
            
            guard let resultData = result.data as? [String: Any],
                  let translations = resultData["translations"] as? [[String: Any]] else {
                throw TranslationError.invalidResponse
            }
            
            return translations.compactMap { translation in
                guard let messageId = translation["messageId"] as? String,
                      let success = translation["success"] as? Bool else {
                    return nil
                }
                
                if success,
                   let originalText = translation["originalText"] as? String,
                   let translatedText = translation["translatedText"] as? String,
                   let language = translation["targetLanguage"] as? String {
                    // Cache locally
                    if cachedTranslations[messageId] == nil {
                        cachedTranslations[messageId] = [:]
                    }
                    cachedTranslations[messageId]?[targetLanguage] = translatedText
                    
                    return BatchTranslationResult(
                        messageId: messageId,
                        success: true,
                        originalText: originalText,
                        translatedText: translatedText,
                        targetLanguage: language,
                        error: nil
                    )
                } else {
                    let error = translation["error"] as? String ?? "Unknown error"
                    return BatchTranslationResult(
                        messageId: messageId,
                        success: false,
                        originalText: nil,
                        translatedText: nil,
                        targetLanguage: nil,
                        error: error
                    )
                }
            }
        } catch {
            print("Batch translation error: \(error.localizedDescription)")
            throw TranslationError.translationFailed(error.localizedDescription)
        }
    }
    
    /// Clear cached translations
    func clearCache() {
        cachedTranslations.removeAll()
    }
    
    /// Clear cache for a specific message
    func clearCache(for messageId: String) {
        cachedTranslations.removeValue(forKey: messageId)
    }
}

// MARK: - Models

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let targetLanguage: String
    let fromCache: Bool
}

struct BatchTranslationResult {
    let messageId: String
    let success: Bool
    let originalText: String?
    let translatedText: String?
    let targetLanguage: String?
    let error: String?
}

enum TranslationError: LocalizedError {
    case invalidResponse
    case invalidInput
    case batchTooLarge
    case translationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from translation service"
        case .invalidInput:
            return "Invalid input provided"
        case .batchTooLarge:
            return "Maximum 50 messages per batch"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        }
    }
}

// MARK: - Language List

struct Language: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let nativeName: String
    let emoji: String
    
    static let common: [Language] = [
        Language(name: "Spanish", nativeName: "Español", emoji: "🇪🇸"),
        Language(name: "French", nativeName: "Français", emoji: "🇫🇷"),
        Language(name: "German", nativeName: "Deutsch", emoji: "🇩🇪"),
        Language(name: "Italian", nativeName: "Italiano", emoji: "🇮🇹"),
        Language(name: "Portuguese", nativeName: "Português", emoji: "🇵🇹"),
        Language(name: "Chinese (Simplified)", nativeName: "简体中文", emoji: "🇨🇳"),
        Language(name: "Chinese (Traditional)", nativeName: "繁體中文", emoji: "🇹🇼"),
        Language(name: "Japanese", nativeName: "日本語", emoji: "🇯🇵"),
        Language(name: "Korean", nativeName: "한국어", emoji: "🇰🇷"),
        Language(name: "Arabic", nativeName: "العربية", emoji: "🇸🇦"),
        Language(name: "Russian", nativeName: "Русский", emoji: "🇷🇺"),
        Language(name: "Hindi", nativeName: "हिन्दी", emoji: "🇮🇳"),
        Language(name: "Dutch", nativeName: "Nederlands", emoji: "🇳🇱"),
        Language(name: "Swedish", nativeName: "Svenska", emoji: "🇸🇪"),
        Language(name: "Polish", nativeName: "Polski", emoji: "🇵🇱")
    ]
    
    static let all: [Language] = common + [
        Language(name: "Danish", nativeName: "Dansk", emoji: "🇩🇰"),
        Language(name: "Finnish", nativeName: "Suomi", emoji: "🇫🇮"),
        Language(name: "Norwegian", nativeName: "Norsk", emoji: "🇳🇴"),
        Language(name: "Turkish", nativeName: "Türkçe", emoji: "🇹🇷"),
        Language(name: "Greek", nativeName: "Ελληνικά", emoji: "🇬🇷"),
        Language(name: "Czech", nativeName: "Čeština", emoji: "🇨🇿"),
        Language(name: "Hungarian", nativeName: "Magyar", emoji: "🇭🇺"),
        Language(name: "Romanian", nativeName: "Română", emoji: "🇷🇴"),
        Language(name: "Thai", nativeName: "ไทย", emoji: "🇹🇭"),
        Language(name: "Vietnamese", nativeName: "Tiếng Việt", emoji: "🇻🇳"),
        Language(name: "Indonesian", nativeName: "Bahasa Indonesia", emoji: "🇮🇩"),
        Language(name: "Malay", nativeName: "Bahasa Melayu", emoji: "🇲🇾"),
        Language(name: "Hebrew", nativeName: "עברית", emoji: "🇮🇱"),
        Language(name: "Ukrainian", nativeName: "Українська", emoji: "🇺🇦"),
        Language(name: "Bulgarian", nativeName: "Български", emoji: "🇧🇬"),
        Language(name: "Croatian", nativeName: "Hrvatski", emoji: "🇭🇷"),
        Language(name: "Slovak", nativeName: "Slovenčina", emoji: "🇸🇰"),
        Language(name: "Bengali", nativeName: "বাংলা", emoji: "🇧🇩"),
        Language(name: "Urdu", nativeName: "اردو", emoji: "🇵🇰"),
        Language(name: "Farsi", nativeName: "فارسی", emoji: "🇮🇷")
    ]
}

