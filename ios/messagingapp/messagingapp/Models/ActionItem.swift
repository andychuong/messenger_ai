//
//  ActionItem.swift
//  messagingapp
//
//  Phase 8: AI-powered action item extraction
//

import Foundation
import FirebaseFirestore

/// Represents an action item extracted from conversations
struct ActionItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    
    let task: String
    let assignedTo: String?
    let createdBy: String
    let conversationId: String
    let messageId: String?
    let priority: Priority
    let status: Status
    let dueDate: Date?
    let extractedAt: Date
    let createdAt: Date
    let completedAt: Date?
    let completedBy: String?
    
    enum Priority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "circle"
            case .medium: return "circle.fill"
            case .high: return "exclamationmark.circle.fill"
            }
        }
    }
    
    enum Status: String, Codable, CaseIterable {
        case pending = "pending"
        case completed = "completed"
        case cancelled = "cancelled"
        
        var displayName: String {
            rawValue.capitalized
        }
    }
    
    // Computed properties
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && status == .pending
    }
    
    var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return dueDate < twoDaysFromNow && dueDate > Date() && status == .pending
    }
}

// MARK: - Firestore Conversion
extension ActionItem {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.task = data["task"] as? String ?? ""
        self.assignedTo = data["assignedTo"] as? String
        self.createdBy = data["createdBy"] as? String ?? ""
        self.conversationId = data["conversationId"] as? String ?? ""
        self.messageId = data["messageId"] as? String
        
        let priorityStr = data["priority"] as? String ?? "medium"
        self.priority = Priority(rawValue: priorityStr) ?? .medium
        
        let statusStr = data["status"] as? String ?? "pending"
        self.status = Status(rawValue: statusStr) ?? .pending
        
        self.dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
        self.extractedAt = (data["extractedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        self.completedBy = data["completedBy"] as? String
    }
    
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "task": task,
            "createdBy": createdBy,
            "conversationId": conversationId,
            "priority": priority.rawValue,
            "status": status.rawValue,
            "extractedAt": Timestamp(date: extractedAt),
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let assignedTo = assignedTo {
            data["assignedTo"] = assignedTo
        }
        
        if let messageId = messageId {
            data["messageId"] = messageId
        }
        
        if let dueDate = dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        }
        
        if let completedAt = completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }
        
        if let completedBy = completedBy {
            data["completedBy"] = completedBy
        }
        
        return data
    }
}

