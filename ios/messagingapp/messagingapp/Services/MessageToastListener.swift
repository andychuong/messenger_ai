//
//  MessageToastListener.swift
//  messagingapp
//
//  Listens for new messages and triggers toast notifications
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class MessageToastListener: ObservableObject {
    private var conversationsListener: ListenerRegistration?
    private var messageListeners: [String: ListenerRegistration] = [:]
    private let db = Firestore.firestore()
    private let encryptionService = EncryptionService.shared
    
    private var lastMessageTimestamps: [String: Date] = [:]
    
    func startListening(toastManager: ToastManager) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen to all conversations for the current user
        conversationsListener = db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    for document in documents {
                        let conversationId = document.documentID
                        
                        // Only set up listener if we don't have one already
                        if self.messageListeners[conversationId] == nil {
                            self.listenToConversationMessages(
                                conversationId: conversationId,
                                currentUserId: currentUserId,
                                toastManager: toastManager
                            )
                        }
                    }
                }
            }
    }
    
    private func listenToConversationMessages(
        conversationId: String,
        currentUserId: String,
        toastManager: ToastManager
    ) {
        // Listen to new messages in this conversation
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let changes = snapshot?.documentChanges else { return }
                
                Task { @MainActor in
                    for change in changes {
                        // Only process new messages
                        guard change.type == .added else { continue }
                        
                        let data = change.document.data()
                        
                        // Skip if message is from current user
                        guard let senderId = data["senderId"] as? String,
                              senderId != currentUserId else {
                            continue
                        }
                        
                        // Skip if message is too old (prevent showing toasts on initial load)
                        guard let timestamp = data["timestamp"] as? Timestamp else { continue }
                        let messageDate = timestamp.dateValue()
                        
                        // Check if this message is newer than the last one we processed
                        if let lastTimestamp = self.lastMessageTimestamps[conversationId],
                           messageDate <= lastTimestamp {
                            continue
                        }
                        
                        // Only show toasts for messages within the last 30 seconds
                        let timeInterval = Date().timeIntervalSince(messageDate)
                        guard timeInterval < 30 else {
                            // Update timestamp but don't show toast
                            self.lastMessageTimestamps[conversationId] = messageDate
                            continue
                        }
                        
                        // Update last message timestamp
                        self.lastMessageTimestamps[conversationId] = messageDate
                        
                        // Get sender name
                        self.getSenderName(senderId: senderId) { senderName in
                            Task {
                                // Get message text - decrypt if encrypted
                                let messageText: String
                                if let text = data["text"] as? String, !text.isEmpty {
                                    // Check if message is encrypted
                                    let isEncrypted = data["isEncrypted"] as? Bool ?? true
                                    
                                    if isEncrypted {
                                        // Try to decrypt
                                        do {
                                            let decryptedText = try await self.encryptionService.decryptMessage(
                                                text,
                                                conversationId: conversationId
                                            )
                                            messageText = decryptedText
                                        } catch {
                                            print("⚠️ Failed to decrypt toast message: \(error)")
                                            messageText = "🔒 Encrypted message"
                                        }
                                    } else {
                                        messageText = text
                                    }
                                } else if data["imageURL"] != nil {
                                    messageText = "📷 Sent a photo"
                                } else if data["voiceURL"] != nil {
                                    messageText = "🎤 Sent a voice message"
                                } else {
                                    messageText = "Sent a message"
                                }
                                
                                // Show toast on main actor
                                await MainActor.run {
                                    toastManager.showToast(
                                        senderName: senderName,
                                        message: messageText,
                                        conversationId: conversationId
                                    )
                                }
                            }
                        }
                    }
                }
            }
        
        messageListeners[conversationId] = listener
    }
    
    private func getSenderName(senderId: String, completion: @escaping (String) -> Void) {
        db.collection("users").document(senderId).getDocument { snapshot, error in
            let name = snapshot?.data()?["displayName"] as? String ?? "Someone"
            Task { @MainActor in
                completion(name)
            }
        }
    }
    
    func stopListening() {
        conversationsListener?.remove()
        conversationsListener = nil
        
        for (_, listener) in messageListeners {
            listener.remove()
        }
        messageListeners.removeAll()
        lastMessageTimestamps.removeAll()
    }
}

