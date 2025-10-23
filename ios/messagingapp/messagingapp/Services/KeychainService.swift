//
//  KeychainService.swift
//  messagingapp
//
//  Phase 6: Security & Encryption
//  Secure storage of encryption keys in iOS Keychain
//

import Foundation
import Security

class KeychainService {
    
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Key Types
    
    enum KeyType: String {
        case conversationKey = "conversationKey"
        case privateKey = "privateKey"
        case publicKey = "publicKey"
    }
    
    // MARK: - Save Key
    
    /// Save encryption key to Keychain
    /// - Parameters:
    ///   - key: Key data to save
    ///   - identifier: Unique identifier (e.g., conversationId or userId)
    ///   - type: Type of key being stored
    /// - Returns: Success status
    @discardableResult
    func saveKey(_ key: Data, identifier: String, type: KeyType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "\(type.rawValue)_\(identifier)",
            kSecAttrService as String: "com.messagingapp.encryption",
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Delete any existing key first
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Saved \(type.rawValue) for \(identifier)")
            return true
        } else {
            print("❌ Failed to save \(type.rawValue): \(status)")
            return false
        }
    }
    
    // MARK: - Retrieve Key
    
    /// Retrieve encryption key from Keychain
    /// - Parameters:
    ///   - identifier: Unique identifier
    ///   - type: Type of key to retrieve
    /// - Returns: Key data if found
    func retrieveKey(identifier: String, type: KeyType) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "\(type.rawValue)_\(identifier)",
            kSecAttrService as String: "com.messagingapp.encryption",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            print("✅ Retrieved \(type.rawValue) for \(identifier)")
            return data
        } else if status == errSecItemNotFound {
            print("⚠️ \(type.rawValue) not found for \(identifier)")
            return nil
        } else {
            print("❌ Failed to retrieve \(type.rawValue): \(status)")
            return nil
        }
    }
    
    // MARK: - Delete Key
    
    /// Delete encryption key from Keychain
    /// - Parameters:
    ///   - identifier: Unique identifier
    ///   - type: Type of key to delete
    /// - Returns: Success status
    @discardableResult
    func deleteKey(identifier: String, type: KeyType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "\(type.rawValue)_\(identifier)",
            kSecAttrService as String: "com.messagingapp.encryption"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            print("✅ Deleted \(type.rawValue) for \(identifier)")
            return true
        } else if status == errSecItemNotFound {
            print("⚠️ \(type.rawValue) not found for deletion")
            return true // Already deleted
        } else {
            print("❌ Failed to delete \(type.rawValue): \(status)")
            return false
        }
    }
    
    // MARK: - Delete All Keys
    
    /// Delete all encryption keys (e.g., on logout)
    /// - Returns: Success status
    @discardableResult
    func deleteAllKeys() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.messagingapp.encryption"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ Deleted all encryption keys")
            return true
        } else {
            print("❌ Failed to delete all keys: \(status)")
            return false
        }
    }
    
    // MARK: - Conversation Keys
    
    /// Save conversation-specific encryption key
    func saveConversationKey(_ key: Data, conversationId: String) -> Bool {
        return saveKey(key, identifier: conversationId, type: .conversationKey)
    }
    
    /// Retrieve conversation-specific encryption key
    func retrieveConversationKey(conversationId: String) -> Data? {
        return retrieveKey(identifier: conversationId, type: .conversationKey)
    }
    
    /// Delete conversation-specific encryption key
    func deleteConversationKey(conversationId: String) -> Bool {
        return deleteKey(identifier: conversationId, type: .conversationKey)
    }
    
    // MARK: - User RSA Keys
    
    /// Save user's private RSA key
    func savePrivateKey(_ key: Data, userId: String) -> Bool {
        return saveKey(key, identifier: userId, type: .privateKey)
    }
    
    /// Retrieve user's private RSA key
    func retrievePrivateKey(userId: String) -> Data? {
        return retrieveKey(identifier: userId, type: .privateKey)
    }
    
    /// Save user's public RSA key (for backup, usually stored in Firestore)
    func savePublicKey(_ key: Data, userId: String) -> Bool {
        return saveKey(key, identifier: userId, type: .publicKey)
    }
    
    /// Retrieve user's public RSA key
    func retrievePublicKey(userId: String) -> Data? {
        return retrieveKey(identifier: userId, type: .publicKey)
    }
    
    /// Delete user's RSA keys
    func deleteUserKeys(userId: String) -> Bool {
        let privateDeleted = deleteKey(identifier: userId, type: .privateKey)
        let publicDeleted = deleteKey(identifier: userId, type: .publicKey)
        return privateDeleted && publicDeleted
    }
}

