//
//  MessageService+Fetching.swift
//  messagingapp
//
//  Message fetching and decryption operations
//

import Foundation
import FirebaseFirestore

extension MessageService {
    // MARK: - Fetch Messages
    
    /// Fetch messages for a conversation with pagination
    func fetchMessages(conversationId: String, limit: Int = 50, before lastMessage: Message? = nil) async throws -> [Message] {
        var query = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        if let lastMessage = lastMessage, let lastTimestamp = lastMessage.timestamp as Date? {
            query = query.start(after: [lastTimestamp])
        }
        
        let snapshot = try await query.getDocuments()
        
        var messages: [Message] = []
        for document in snapshot.documents {
            guard let message = try? document.data(as: Message.self) else { continue }
            
            let decryptedMessage = try await decryptMessageIfNeeded(message, conversationId: conversationId)
            messages.append(decryptedMessage)
        }
        
        return messages.reversed()
    }
    
    // MARK: - Real-time Message Listener
    
    /// Listen to messages in real-time
    func listenToMessages(conversationId: String, limit: Int = 50, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: limit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return
                }
                
                Task {
                    var messages: [Message] = []
                    for document in documents {
                        guard var message = try? document.data(as: Message.self) else { continue }
                        
                        let messageType = message.type ?? .text
                        let shouldDecrypt = message.isEncrypted ?? true
                        
                        if shouldDecrypt && messageType == .text {
                            do {
                                let decryptedText = try await self.encryptionService.decryptMessage(
                                    message.text,
                                    conversationId: conversationId
                                )
                                message.text = decryptedText
                            } catch {
                                print("⚠️ Failed to decrypt message: \(error)")
                                message.text = "[Encrypted message - decryption failed]"
                            }
                        } else if !shouldDecrypt {
                            print("ℹ️  Message \(message.id ?? "unknown") is not encrypted (legacy or system message)")
                        } else {
                            print("ℹ️  Skipping decryption for non-text message: \(message.id ?? "unknown") of type \(messageType.rawValue)")
                        }
                        
                        messages.append(message)
                    }
                    
                    await MainActor.run {
                        completion(messages)
                    }
                }
            }
    }
    
    // MARK: - Helper: Decrypt Message
    
    /// Decrypt message text if needed
    private func decryptMessageIfNeeded(_ message: Message, conversationId: String) async throws -> Message {
        var decryptedMessage = message
        
        let messageType = message.type ?? .text
        // Skip decryption for non-text messages
        guard messageType == .text else {
            print("ℹ️  Skipping decryption for non-text message: \(message.id ?? "unknown") of type \(messageType.rawValue)")
            return decryptedMessage
        }
        
        // Check if message is encrypted
        let shouldDecrypt = message.isEncrypted ?? true
        if shouldDecrypt {
            do {
                let decryptedText = try await encryptionService.decryptMessage(
                    message.text,
                    conversationId: conversationId
                )
                decryptedMessage.text = decryptedText
                print("✅ Decrypted message: \(message.id ?? "unknown")")
            } catch {
                print("⚠️ Failed to decrypt message \(message.id ?? "unknown"): \(error)")
                // For debugging, show error in UI
                decryptedMessage.text = "[Encrypted message - decryption failed]"
            }
        } else {
            // Message is not encrypted (legacy or system message)
            print("ℹ️  Message \(message.id ?? "unknown") is not encrypted (legacy or system message)")
        }
        
        return decryptedMessage
    }
}

