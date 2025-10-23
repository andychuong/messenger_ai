//
//  EncryptionService.swift
//  messagingapp
//
//  Phase 6: Security & Encryption
//  End-to-end encryption using AES-256 and RSA
//

import Foundation
import CryptoKit
import Security

class EncryptionService {
    
    static let shared = EncryptionService()
    
    private let keychainService = KeychainService.shared
    
    private init() {}
    
    // MARK: - AES-256 Encryption/Decryption
    
    /// Encrypt text using AES-256-GCM
    /// - Parameters:
    ///   - text: Plain text to encrypt
    ///   - conversationId: Conversation ID to retrieve encryption key
    /// - Returns: Base64 encoded encrypted data with nonce
    func encryptMessage(_ text: String, conversationId: String) throws -> String {
        // Get or create conversation key
        let symmetricKey = try getOrCreateConversationKey(conversationId: conversationId)
        
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
    func decryptMessage(_ encryptedText: String, conversationId: String) throws -> String {
        // Get conversation key
        let symmetricKey = try getOrCreateConversationKey(conversationId: conversationId)
        
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
    func encryptFile(_ data: Data, conversationId: String) throws -> Data {
        let symmetricKey = try getOrCreateConversationKey(conversationId: conversationId)
        
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
    func decryptFile(_ encryptedData: Data, conversationId: String) throws -> Data {
        let symmetricKey = try getOrCreateConversationKey(conversationId: conversationId)
        
        // Create sealed box
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        return decryptedData
    }
    
    // MARK: - Conversation Key Management
    
    /// Get or create AES-256 key for conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: SymmetricKey for AES encryption
    private func getOrCreateConversationKey(conversationId: String) throws -> SymmetricKey {
        // Try to retrieve existing key
        if let keyData = keychainService.retrieveConversationKey(conversationId: conversationId) {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        // Save to keychain
        guard keychainService.saveConversationKey(keyData, conversationId: conversationId) else {
            throw EncryptionError.keychainError
        }
        
        print("🔐 Generated new encryption key for conversation: \(conversationId)")
        return newKey
    }
    
    /// Delete conversation encryption key
    /// - Parameter conversationId: Conversation ID
    func deleteConversationKey(conversationId: String) {
        keychainService.deleteConversationKey(conversationId: conversationId)
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
        keychainService.deleteUserKeys(userId: userId)
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
        }
    }
}

