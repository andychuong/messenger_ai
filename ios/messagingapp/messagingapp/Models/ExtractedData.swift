//
//  ExtractedData.swift
//  messagingapp
//
//  Models for structured data extraction from conversations
//

import Foundation
import FirebaseFirestore

// MARK: - Data Type Enum

enum DataType: String, Codable, CaseIterable {
    case events
    case tasks
    case dates
    case locations
    case contacts
    case decisions
}

// MARK: - Extracted Event

struct ExtractedEvent: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let date: String // ISO 8601 format
    let time: String?
    let endTime: String?
    let duration: Int? // in minutes
    let location: String?
    let participants: [String]
    let messageId: String
    let confidence: Double
    let description: String?
    
    init(id: String = UUID().uuidString,
         title: String,
         date: String,
         time: String? = nil,
         endTime: String? = nil,
         duration: Int? = nil,
         location: String? = nil,
         participants: [String] = [],
         messageId: String,
         confidence: Double,
         description: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.time = time
        self.endTime = endTime
        self.duration = duration
        self.location = location
        self.participants = participants
        self.messageId = messageId
        self.confidence = confidence
        self.description = description
    }
    
    // Custom decoding to generate ID if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.title = try container.decode(String.self, forKey: .title)
        self.date = try container.decode(String.self, forKey: .date)
        self.time = try container.decodeIfPresent(String.self, forKey: .time)
        self.endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        self.duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.participants = try container.decode([String].self, forKey: .participants)
        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
    
    // Computed properties
    var dateObject: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: date)
    }
    
    var startDateTime: Date? {
        guard let dateObj = dateObject, let timeStr = time else { return dateObject }
        
        let components = timeStr.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return dateObject
        }
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: dateObj)
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        return calendar.date(from: dateComponents)
    }
    
    var endDateTime: Date? {
        guard let startDate = startDateTime else { return nil }
        
        if let endTimeStr = endTime {
            let components = endTimeStr.split(separator: ":")
            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]) else {
                return nil
            }
            
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            return calendar.date(from: dateComponents)
        } else if let durationMinutes = duration {
            return Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate)
        }
        
        return nil
    }
}

// MARK: - Extracted Task

struct ExtractedTask: Identifiable, Codable, Hashable {
    let id: String
    let task: String
    let assignee: String?
    let deadline: String?
    let priority: TaskPriority
    let status: TaskStatus
    let messageId: String
    let confidence: Double
    
    init(id: String = UUID().uuidString,
         task: String,
         assignee: String? = nil,
         deadline: String? = nil,
         priority: TaskPriority,
         status: TaskStatus,
         messageId: String,
         confidence: Double) {
        self.id = id
        self.task = task
        self.assignee = assignee
        self.deadline = deadline
        self.priority = priority
        self.status = status
        self.messageId = messageId
        self.confidence = confidence
    }
    
    // Custom decoding to generate ID if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.task = try container.decode(String.self, forKey: .task)
        self.assignee = try container.decodeIfPresent(String.self, forKey: .assignee)
        self.deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        self.priority = try container.decode(TaskPriority.self, forKey: .priority)
        self.status = try container.decode(TaskStatus.self, forKey: .status)
        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
    }
    
    enum TaskPriority: String, Codable {
        case high
        case medium
        case low
        
        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "blue"
            }
        }
    }
    
    enum TaskStatus: String, Codable {
        case pending
        case inProgress = "in_progress"
        case completed
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            }
        }
    }
    
    var deadlineDate: Date? {
        guard let deadline = deadline else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: deadline)
    }
}

// MARK: - Extracted Date

struct ExtractedDate: Identifiable, Codable, Hashable {
    let id: String
    let date: String // ISO 8601 format
    let context: String
    let type: DateType
    let messageId: String
    let confidence: Double
    
    init(id: String = UUID().uuidString,
         date: String,
         context: String,
         type: DateType,
         messageId: String,
         confidence: Double) {
        self.id = id
        self.date = date
        self.context = context
        self.type = type
        self.messageId = messageId
        self.confidence = confidence
    }
    
    // Custom decoding to generate ID if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.date = try container.decode(String.self, forKey: .date)
        self.context = try container.decode(String.self, forKey: .context)
        self.type = try container.decode(DateType.self, forKey: .type)
        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
    }
    
    enum DateType: String, Codable {
        case deadline
        case meeting
        case reminder
        case event
        case reference
        
        var icon: String {
            switch self {
            case .deadline: return "exclamationmark.triangle"
            case .meeting: return "calendar.badge.clock"
            case .reminder: return "bell"
            case .event: return "calendar"
            case .reference: return "calendar.circle"
            }
        }
    }
    
    var dateObject: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: date)
    }
}

// MARK: - Extracted Location

struct ExtractedLocation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let address: String?
    let coordinates: Coordinates?
    let context: String
    let messageId: String
    let confidence: Double
    
    init(id: String = UUID().uuidString,
         name: String,
         address: String? = nil,
         coordinates: Coordinates? = nil,
         context: String,
         messageId: String,
         confidence: Double) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinates = coordinates
        self.context = context
        self.messageId = messageId
        self.confidence = confidence
    }
    
    // Custom decoding to generate ID if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.coordinates = try container.decodeIfPresent(Coordinates.self, forKey: .coordinates)
        self.context = try container.decode(String.self, forKey: .context)
        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
    }
    
    struct Coordinates: Codable, Hashable {
        let lat: Double
        let lng: Double
    }
    
    var hasCoordinates: Bool {
        coordinates != nil
    }
}

// MARK: - Extracted Contact

struct ExtractedContact: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let company: String?
    let context: String
    let messageId: String
    let confidence: Double
    
    init(id: String = UUID().uuidString,
         name: String,
         phone: String? = nil,
         email: String? = nil,
         company: String? = nil,
         context: String,
         messageId: String,
         confidence: Double) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.company = company
        self.context = context
        self.messageId = messageId
        self.confidence = confidence
    }
    
    // Custom decoding to generate ID if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.company = try container.decodeIfPresent(String.self, forKey: .company)
        self.context = try container.decode(String.self, forKey: .context)
        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
    }
    
    var hasContactInfo: Bool {
        phone != nil || email != nil
    }
}

// MARK: - Extracted Decision

struct ExtractedDecision: Identifiable, Codable, Hashable {
    let id: String
    let decision: String
    let context: String
    let participants: [String]
    let date: String
    let messageId: String
    let confidence: Double
    
    init(id: String = UUID().uuidString,
         decision: String,
         context: String,
         participants: [String] = [],
         date: String,
         messageId: String,
         confidence: Double) {
        self.id = id
        self.decision = decision
        self.context = context
        self.participants = participants
        self.date = date
        self.messageId = messageId
        self.confidence = confidence
    }
    
    // Custom decoding to generate ID if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.decision = try container.decode(String.self, forKey: .decision)
        self.context = try container.decode(String.self, forKey: .context)
        self.participants = try container.decode([String].self, forKey: .participants)
        self.date = try container.decode(String.self, forKey: .date)
        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
    }
    
    var dateObject: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: date)
    }
}

// MARK: - Structured Data Container

struct StructuredData: Codable {
    var events: [ExtractedEvent]
    var tasks: [ExtractedTask]
    var dates: [ExtractedDate]
    var locations: [ExtractedLocation]
    var contacts: [ExtractedContact]
    var decisions: [ExtractedDecision]
    let extractedAt: String
    let conversationId: String
    
    init(events: [ExtractedEvent] = [],
         tasks: [ExtractedTask] = [],
         dates: [ExtractedDate] = [],
         locations: [ExtractedLocation] = [],
         contacts: [ExtractedContact] = [],
         decisions: [ExtractedDecision] = [],
         extractedAt: String = ISO8601DateFormatter().string(from: Date()),
         conversationId: String) {
        self.events = events
        self.tasks = tasks
        self.dates = dates
        self.locations = locations
        self.contacts = contacts
        self.decisions = decisions
        self.extractedAt = extractedAt
        self.conversationId = conversationId
    }
    
    var isEmpty: Bool {
        events.isEmpty && tasks.isEmpty && dates.isEmpty && 
        locations.isEmpty && contacts.isEmpty && decisions.isEmpty
    }
    
    var totalItems: Int {
        events.count + tasks.count + dates.count + 
        locations.count + contacts.count + decisions.count
    }
}

