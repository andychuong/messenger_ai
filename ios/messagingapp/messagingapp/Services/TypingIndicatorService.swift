//
//  TypingIndicatorService.swift
//  messagingapp
//
//  Service for managing typing indicators in conversations
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class TypingIndicatorService: ObservableObject {
    @Published var typingUsers: [String: String] = [:] // userId: displayName
    @Published var typingText: String? = nil
    
    private let db = Firestore.firestore()
    private var typingListener: ListenerRegistration?
    private var typingTimeoutTask: Task<Void, Never>?
    private var lastTypingUpdate: Date?
    
    // MARK: - Set Typing Status
    
    func setTyping(conversationId: String, userId: String, isTyping: Bool) {
        // Throttle updates - only send if it's been more than 2 seconds since last update
        if isTyping {
            let now = Date()
            if let lastUpdate = lastTypingUpdate,
               now.timeIntervalSince(lastUpdate) < 2 {
                return // Skip update - too soon
            }
            lastTypingUpdate = now
        }
        
        let typingRef = db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .document(userId)
        
        if isTyping {
            // Set typing with timestamp
            typingRef.setData([
                "isTyping": true,
                "timestamp": Timestamp(date: Date())
            ], merge: true) { error in
                if let error = error {
                    print("❌ Error setting typing status: \(error.localizedDescription)")
                }
            }
            
            // Auto-clear after 5 seconds
            typingTimeoutTask?.cancel()
            typingTimeoutTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                self.setTyping(conversationId: conversationId, userId: userId, isTyping: false)
            }
        } else {
            // Clear typing status
            typingRef.delete { error in
                if let error = error {
                    print("❌ Error clearing typing status: \(error.localizedDescription)")
                }
            }
            typingTimeoutTask?.cancel()
        }
    }
    
    // MARK: - Listen for Typing
    
    func startListening(conversationId: String, currentUserId: String, userNames: [String: String] = [:]) {
        stopListening()
        
        typingListener = db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    var typing: [String: String] = [:]
                    let now = Date()
                    
                    for document in documents {
                        let userId = document.documentID
                        
                        // Skip current user
                        guard userId != currentUserId else { continue }
                        
                        let data = document.data()
                        guard let isTyping = data["isTyping"] as? Bool,
                              isTyping,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            continue
                        }
                        
                        // Check if typing status is fresh (within last 10 seconds)
                        let age = now.timeIntervalSince(timestamp.dateValue())
                        guard age < 10 else {
                            // Stale - clean it up
                            document.reference.delete()
                            continue
                        }
                        
                        // Get user's display name
                        if let name = userNames[userId] {
                            print("✅ Found typing user: \(name)")
                            typing[userId] = name
                        } else {
                            print("🔍 Fetching name for user: \(userId)")
                            // Fetch name if not provided
                            self.fetchUserName(userId: userId) { name in
                                print("✅ Fetched name: \(name)")
                                typing[userId] = name
                            }
                        }
                    }
                    
                    print("📊 Total typing users: \(typing.count)")
                    self.typingUsers = typing
                    
                    // Update the computed typing text
                    self.updateTypingText()
                }
            }
    }
    
    private func updateTypingText() {
        guard !typingUsers.isEmpty else {
            print("🔇 No typing users - clearing text")
            typingText = nil
            return
        }
        
        let names = Array(typingUsers.values)
        print("✍️ Typing users: \(names.joined(separator: ", "))")
        
        let text: String
        switch names.count {
        case 1:
            text = "\(names[0]) is typing..."
        case 2:
            text = "\(names[0]) and \(names[1]) are typing..."
        case 3:
            text = "\(names[0]), \(names[1]), and \(names[2]) are typing..."
        default:
            text = "\(names.count) people are typing..."
        }
        
        print("💬 Setting typing text: \(text)")
        typingText = text
    }
    
    private func fetchUserName(userId: String, completion: @escaping (String) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            let name = snapshot?.data()?["displayName"] as? String ?? "Someone"
            Task { @MainActor in
                completion(name)
            }
        }
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        typingListener?.remove()
        typingListener = nil
        typingTimeoutTask?.cancel()
        typingUsers.removeAll()
    }
    
    deinit {
        typingTimeoutTask?.cancel()
    }
    
}

