//
//  MessageQueueService.swift
//  messagingapp
//
//  Phase 11: Offline Support & Sync
//  Manages queued messages for offline sending
//

import Foundation
import Combine
import FirebaseAuth

/// Represents a queued message waiting to be sent
struct QueuedMessage: Codable, Identifiable {
    let id: String
    let conversationId: String
    let text: String
    let shouldEncrypt: Bool
    let timestamp: Date
    var retryCount: Int
    var lastAttempt: Date?
    
    /// Type of message (for future support of images, voice, etc.)
    enum QueuedMessageType: String, Codable {
        case text
        case image
        case voice
    }
    
    let type: QueuedMessageType
    
    /// Optional fields for different message types
    let imageURL: String?
    let voiceURL: String?
    let voiceDuration: TimeInterval?
    let caption: String?
}

/// Service that manages a queue of messages to send when offline
@MainActor
class MessageQueueService: ObservableObject {
    /// Shared singleton instance
    static let shared = MessageQueueService()
    
    /// Published array of queued messages
    @Published private(set) var queuedMessages: [QueuedMessage] = []
    
    /// Is the service currently processing the queue?
    @Published private(set) var isProcessing: Bool = false
    
    /// User defaults key for persisting queue
    private let queueKey = "com.messagingapp.messageQueue"
    
    /// Maximum retry attempts before giving up
    private let maxRetries = 5
    
    /// Network monitor for connectivity changes
    private let networkMonitor = NetworkMonitor.shared
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadQueue()
        observeNetworkChanges()
    }
    
    // MARK: - Queue Management
    
    /// Add a text message to the queue
    func queueTextMessage(
        id: String,
        conversationId: String,
        text: String,
        shouldEncrypt: Bool = true
    ) {
        let queuedMessage = QueuedMessage(
            id: id,
            conversationId: conversationId,
            text: text,
            shouldEncrypt: shouldEncrypt,
            timestamp: Date(),
            retryCount: 0,
            lastAttempt: nil,
            type: .text,
            imageURL: nil,
            voiceURL: nil,
            voiceDuration: nil,
            caption: nil
        )
        
        queuedMessages.append(queuedMessage)
        saveQueue()
        
        print("📤 MessageQueue: Queued text message for conversation \(conversationId)")
        
        // Try to process immediately if online
        if networkMonitor.isConnected {
            Task {
                await processQueue()
            }
        }
    }
    
    /// Add an image message to the queue
    func queueImageMessage(
        id: String,
        conversationId: String,
        imageURL: String,
        caption: String?
    ) {
        let queuedMessage = QueuedMessage(
            id: id,
            conversationId: conversationId,
            text: caption ?? "",
            shouldEncrypt: true,
            timestamp: Date(),
            retryCount: 0,
            lastAttempt: nil,
            type: .image,
            imageURL: imageURL,
            voiceURL: nil,
            voiceDuration: nil,
            caption: caption
        )
        
        queuedMessages.append(queuedMessage)
        saveQueue()
        
        print("📤 MessageQueue: Queued image message for conversation \(conversationId)")
        
        // Try to process immediately if online
        if networkMonitor.isConnected {
            Task {
                await processQueue()
            }
        }
    }
    
    /// Add a voice message to the queue
    func queueVoiceMessage(
        id: String,
        conversationId: String,
        voiceURL: String,
        duration: TimeInterval
    ) {
        let queuedMessage = QueuedMessage(
            id: id,
            conversationId: conversationId,
            text: "🎤 Voice message",
            shouldEncrypt: true,
            timestamp: Date(),
            retryCount: 0,
            lastAttempt: nil,
            type: .voice,
            imageURL: nil,
            voiceURL: voiceURL,
            voiceDuration: duration,
            caption: nil
        )
        
        queuedMessages.append(queuedMessage)
        saveQueue()
        
        print("📤 MessageQueue: Queued voice message for conversation \(conversationId)")
        
        // Try to process immediately if online
        if networkMonitor.isConnected {
            Task {
                await processQueue()
            }
        }
    }
    
    /// Remove a message from the queue
    func removeFromQueue(messageId: String) {
        queuedMessages.removeAll { $0.id == messageId }
        saveQueue()
        print("📤 MessageQueue: Removed message \(messageId) from queue")
    }
    
    /// Get count of queued messages for a specific conversation
    func queuedMessageCount(for conversationId: String) -> Int {
        return queuedMessages.filter { $0.conversationId == conversationId }.count
    }
    
    /// Check if a message is queued
    func isMessageQueued(messageId: String) -> Bool {
        return queuedMessages.contains { $0.id == messageId }
    }
    
    /// Clear all queued messages
    func clearQueue() {
        queuedMessages.removeAll()
        saveQueue()
        print("📤 MessageQueue: Cleared all queued messages")
    }
    
    // MARK: - Queue Processing
    
    /// Process the queue and attempt to send all queued messages
    func processQueue() async {
        guard !isProcessing else {
            print("📤 MessageQueue: Already processing, skipping")
            return
        }
        
        guard networkMonitor.isConnected else {
            print("📤 MessageQueue: Offline, skipping queue processing")
            return
        }
        
        guard !queuedMessages.isEmpty else {
            return
        }
        
        isProcessing = true
        print("📤 MessageQueue: Processing \(queuedMessages.count) queued messages")
        
        // Process messages in order (FIFO)
        let messagesToProcess = queuedMessages
        
        for queuedMessage in messagesToProcess {
            do {
                try await sendQueuedMessage(queuedMessage)
                removeFromQueue(messageId: queuedMessage.id)
            } catch {
                print("📤 MessageQueue: Failed to send message \(queuedMessage.id): \(error)")
                await handleFailedMessage(queuedMessage, error: error)
            }
        }
        
        isProcessing = false
        print("📤 MessageQueue: Finished processing queue")
    }
    
    /// Send a queued message
    private func sendQueuedMessage(_ queuedMessage: QueuedMessage) async throws {
        // Import MessageService
        let messageService = MessageService.shared
        
        switch queuedMessage.type {
        case .text:
            _ = try await messageService.sendMessage(
                conversationId: queuedMessage.conversationId,
                text: queuedMessage.text,
                shouldEncrypt: queuedMessage.shouldEncrypt
            )
            
        case .image:
            guard let imageURL = queuedMessage.imageURL else {
                throw NSError(domain: "MessageQueue", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing image URL"])
            }
            _ = try await messageService.sendImageMessage(
                conversationId: queuedMessage.conversationId,
                imageURL: imageURL,
                caption: queuedMessage.caption
            )
            
        case .voice:
            guard let voiceURL = queuedMessage.voiceURL,
                  let duration = queuedMessage.voiceDuration else {
                throw NSError(domain: "MessageQueue", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing voice URL or duration"])
            }
            _ = try await messageService.sendVoiceMessage(
                conversationId: queuedMessage.conversationId,
                voiceURL: voiceURL,
                duration: duration
            )
        }
        
        print("📤 MessageQueue: Successfully sent message \(queuedMessage.id)")
    }
    
    /// Handle a failed message send attempt
    private func handleFailedMessage(_ queuedMessage: QueuedMessage, error: Error) async {
        var updatedMessage = queuedMessage
        updatedMessage.retryCount += 1
        updatedMessage.lastAttempt = Date()
        
        // If exceeded max retries, remove from queue
        if updatedMessage.retryCount >= maxRetries {
            print("📤 MessageQueue: Message \(queuedMessage.id) exceeded max retries, removing from queue")
            removeFromQueue(messageId: queuedMessage.id)
            
            // Post notification that message failed
            NotificationCenter.default.post(
                name: .messageSendFailed,
                object: nil,
                userInfo: ["messageId": queuedMessage.id, "error": error]
            )
        } else {
            // Update the message in the queue
            if let index = queuedMessages.firstIndex(where: { $0.id == queuedMessage.id }) {
                queuedMessages[index] = updatedMessage
                saveQueue()
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    /// Observe network changes and process queue when connection is restored
    private func observeNetworkChanges() {
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                if let isConnected = notification.userInfo?["isConnected"] as? Bool, isConnected {
                    print("📤 MessageQueue: Connection restored, processing queue")
                    Task {
                        await self.processQueue()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    /// Save queue to UserDefaults
    private func saveQueue() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(queuedMessages)
            UserDefaults.standard.set(data, forKey: queueKey)
        } catch {
            print("📤 MessageQueue: Failed to save queue: \(error)")
        }
    }
    
    /// Load queue from UserDefaults
    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            queuedMessages = try decoder.decode([QueuedMessage].self, from: data)
            print("📤 MessageQueue: Loaded \(queuedMessages.count) queued messages")
        } catch {
            print("📤 MessageQueue: Failed to load queue: \(error)")
            queuedMessages = []
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    /// Posted when a message fails to send after max retries
    static let messageSendFailed = Notification.Name("messageSendFailed")
}

