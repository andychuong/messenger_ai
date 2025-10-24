//
//  EncryptionService.swift
//  messagingapp
//
//  Phase 6: Security & Encryption
//  Phase 9: Account-level encryption (keys stored in Firestore)
//  End-to-end encryption using AES-256 and RSA
//

import Foundation
import CryptoKit
import Security
import FirebaseFirestore
import FirebaseAuth

class EncryptionService {
    
    static let shared = EncryptionService()
    
    private let keychainService = KeychainService.shared
    private let db = Firestore.firestore()
    
    // Cache keys in memory for performance
    private var keyCache: [String: SymmetricKey] = [:]
    
    private init() {}
    
    // MARK: - AES-256 Encryption/Decryption
    
    /// Encrypt text using AES-256-GCM
    /// - Parameters:
    ///   - text: Plain text to encrypt
    ///   - conversationId: Conversation ID to retrieve encryption key
    /// - Returns: Base64 encoded encrypted data with nonce
    func encryptMessage(_ text: String, conversationId: String) async throws -> String {
        // Get or create conversation key
        let symmetricKey = try await getOrCreateConversationKey(conversationId: conversationId)
        
        // Convert text to data
        guard let data = text.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        // Encrypt with AES-256-GCM
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        
        // Combine nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        // Return as base64
        return combined.base64EncodedString()
    }
    
    /// Decrypt text using AES-256-GCM
    /// - Parameters:
    ///   - encryptedText: Base64 encoded encrypted data
    ///   - conversationId: Conversation ID to retrieve encryption key
    /// - Returns: Decrypted plain text
    func decryptMessage(_ encryptedText: String, conversationId: String) async throws -> String {
        // Get conversation key
        let symmetricKey = try await getOrCreateConversationKey(conversationId: conversationId)
        
        // Decode from base64
        guard let combined = Data(base64Encoded: encryptedText) else {
            throw EncryptionError.invalidData
        }
        
        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        
        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        // Convert to string
        guard let decryptedText = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return decryptedText
    }
    
    // MARK: - Image/File Encryption
    
    /// Encrypt image/file data using AES-256-GCM
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - conversationId: Conversation ID
    /// - Returns: Encrypted data as base64 string
    func encryptFile(_ data: Data, conversationId: String) async throws -> Data {
        let symmetricKey = try await getOrCreateConversationKey(conversationId: conversationId)
        
        // Encrypt with AES-256-GCM
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        
        // Return combined data (nonce + ciphertext + tag)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined
    }
    
    /// Decrypt image/file data using AES-256-GCM
    /// - Parameters:
    ///   - encryptedData: Encrypted data
    ///   - conversationId: Conversation ID
    /// - Returns: Decrypted data
    func decryptFile(_ encryptedData: Data, conversationId: String) async throws -> Data {
        let symmetricKey = try await getOrCreateConversationKey(conversationId: conversationId)
        
        // Create sealed box
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        return decryptedData
    }
    
    // MARK: - Conversation Key Management (Account-Level)
    
    /// Get or create AES-256 key for conversation (stored in Firestore)
    /// Phase 9: Keys are now tied to user account, not device
    /// - Parameter conversationId: Conversation ID
    /// - Returns: SymmetricKey for AES encryption
    private func getOrCreateConversationKey(conversationId: String) async throws -> SymmetricKey {
        // Check memory cache first
        if let cachedKey = keyCache[conversationId] {
            return cachedKey
        }
        
        // Get current user
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EncryptionError.userNotAuthenticated
        }
        
        // Try to retrieve from Firestore
        let keyDocRef = db.collection("users")
            .document(userId)
            .collection("encryptionKeys")
            .document(conversationId)
        
        do {
            let doc = try await keyDocRef.getDocument()
            
            if let data = doc.data(),
               let keyBase64 = data["key"] as? String,
               let keyData = Data(base64Encoded: keyBase64) {
                // Found existing key
                let key = SymmetricKey(data: keyData)
                keyCache[conversationId] = key  // Cache it
                print("🔐 Retrieved encryption key from Firestore for conversation: \(conversationId)")
                return key
            }
        } catch {
            // Key doesn't exist yet, will create below
            print("🔐 No existing key found, generating new one...")
        }
        
        // MIGRATION: Try to retrieve from Keychain (for backward compatibility)
        if let legacyKeyData = keychainService.retrieveConversationKey(conversationId: conversationId) {
            let legacyKey = SymmetricKey(data: legacyKeyData)
            
            // Migrate to Firestore
            let keyBase64 = legacyKeyData.base64EncodedString()
            try await keyDocRef.setData([
                "key": keyBase64,
                "conversationId": conversationId,
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            keyCache[conversationId] = legacyKey  // Cache it
            print("🔐 Migrated encryption key from Keychain to Firestore for conversation: \(conversationId)")
            return legacyKey
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        let keyBase64 = keyData.base64EncodedString()
        
        // Save to Firestore
        try await keyDocRef.setData([
            "key": keyBase64,
            "conversationId": conversationId,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        keyCache[conversationId] = newKey  // Cache it
        print("🔐 Generated new encryption key and saved to Firestore for conversation: \(conversationId)")
        return newKey
    }
    
    /// Delete conversation encryption key (from Firestore)
    /// - Parameter conversationId: Conversation ID
    func deleteConversationKey(conversationId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EncryptionError.userNotAuthenticated
        }
        
        // Remove from cache
        keyCache.removeValue(forKey: conversationId)
        
        // Delete from Firestore
        try await db.collection("users")
            .document(userId)
            .collection("encryptionKeys")
            .document(conversationId)
            .delete()
        
        print("🔐 Deleted encryption key from Firestore for conversation: \(conversationId)")
    }
    
    /// Clear all cached keys from memory
    func clearKeyCache() {
        keyCache.removeAll()
        print("🔐 Cleared encryption key cache")
    }
    
    // MARK: - RSA Key Pair Generation
    
    /// Generate RSA key pair for user (for key exchange)
    /// - Parameter userId: User ID
    /// - Returns: Public key as Data
    func generateRSAKeyPair(userId: String) throws -> Data {
        // Generate 2048-bit RSA key pair
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw EncryptionError.rsaGenerationFailed(error.localizedDescription)
            }
            throw EncryptionError.rsaGenerationFailed("Unknown error")
        }
        
        // Get public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw EncryptionError.rsaGenerationFailed("Failed to extract public key")
        }
        
        // Export keys as data
        var exportError: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &exportError) as Data? else {
            if let error = exportError?.takeRetainedValue() {
                throw EncryptionError.rsaExportFailed(error.localizedDescription)
            }
            throw EncryptionError.rsaExportFailed("Unknown error")
        }
        
        guard let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &exportError) as Data? else {
            if let error = exportError?.takeRetainedValue() {
                throw EncryptionError.rsaExportFailed(error.localizedDescription)
            }
            throw EncryptionError.rsaExportFailed("Unknown error")
        }
        
        // Save keys to keychain
        guard keychainService.savePrivateKey(privateKeyData, userId: userId),
              keychainService.savePublicKey(publicKeyData, userId: userId) else {
            throw EncryptionError.keychainError
        }
        
        print("🔐 Generated RSA key pair for user: \(userId)")
        return publicKeyData
    }
    
    /// Retrieve user's public key
    /// - Parameter userId: User ID
    /// - Returns: Public key data
    func getPublicKey(userId: String) -> Data? {
        return keychainService.retrievePublicKey(userId: userId)
    }
    
    /// Retrieve user's private key
    /// - Parameter userId: User ID
    /// - Returns: Private key data
    func getPrivateKey(userId: String) -> Data? {
        return keychainService.retrievePrivateKey(userId: userId)
    }
    
    // MARK: - RSA Encryption/Decryption (for key exchange)
    
    /// Encrypt data with RSA public key (for sharing conversation keys)
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - publicKeyData: Recipient's public key
    /// - Returns: Encrypted data
    func encryptWithRSA(data: Data, publicKeyData: Data) throws -> Data {
        // Import public key
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(publicKeyData as CFData, attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw EncryptionError.rsaEncryptionFailed(error.localizedDescription)
            }
            throw EncryptionError.rsaEncryptionFailed("Failed to import public key")
        }
        
        // Encrypt with public key
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionOAEPSHA256,
            data as CFData,
            &error
        ) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw EncryptionError.rsaEncryptionFailed(error.localizedDescription)
            }
            throw EncryptionError.rsaEncryptionFailed("Encryption failed")
        }
        
        return encryptedData
    }
    
    /// Decrypt data with RSA private key
    /// - Parameters:
    ///   - encryptedData: Encrypted data
    ///   - userId: User ID to retrieve private key
    /// - Returns: Decrypted data
    func decryptWithRSA(encryptedData: Data, userId: String) throws -> Data {
        // Get private key from keychain
        guard let privateKeyData = keychainService.retrievePrivateKey(userId: userId) else {
            throw EncryptionError.privateKeyNotFound
        }
        
        // Import private key
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(privateKeyData as CFData, attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw EncryptionError.rsaDecryptionFailed(error.localizedDescription)
            }
            throw EncryptionError.rsaDecryptionFailed("Failed to import private key")
        }
        
        // Decrypt with private key
        guard let decryptedData = SecKeyCreateDecryptedData(
            privateKey,
            .rsaEncryptionOAEPSHA256,
            encryptedData as CFData,
            &error
        ) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw EncryptionError.rsaDecryptionFailed(error.localizedDescription)
            }
            throw EncryptionError.rsaDecryptionFailed("Decryption failed")
        }
        
        return decryptedData
    }
    
    // MARK: - Cleanup
    
    /// Delete all encryption keys for user (on logout)
    /// - Parameter userId: User ID
    func deleteAllUserKeys(userId: String) {
        _ = keychainService.deleteUserKeys(userId: userId)
        keychainService.deleteAllKeys() // Delete all conversation keys too
        print("🔐 Deleted all encryption keys for user: \(userId)")
    }
}

// MARK: - Encryption Errors

enum EncryptionError: LocalizedError {
    case invalidData
    case encryptionFailed
    case decryptionFailed
    case keychainError
    case rsaGenerationFailed(String)
    case rsaExportFailed(String)
    case rsaEncryptionFailed(String)
    case rsaDecryptionFailed(String)
    case privateKeyNotFound
    case userNotAuthenticated  // Phase 9: For Firestore key storage
    case firestoreError(String)  // Phase 9: For Firestore operations
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .keychainError:
            return "Failed to save key to keychain"
        case .rsaGenerationFailed(let detail):
            return "Failed to generate RSA key pair: \(detail)"
        case .rsaExportFailed(let detail):
            return "Failed to export RSA key: \(detail)"
        case .rsaEncryptionFailed(let detail):
            return "RSA encryption failed: \(detail)"
        case .rsaDecryptionFailed(let detail):
            return "RSA decryption failed: \(detail)"
        case .privateKeyNotFound:
            return "Private key not found in keychain"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .firestoreError(let detail):
            return "Firestore error: \(detail)"
        }
    }
}

