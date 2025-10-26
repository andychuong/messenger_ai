//
//  TimezoneService.swift
//  messagingapp
//
//  Phase 18: Timezone Coordination
//  Service for managing user timezones and coordinating meetings
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseFunctions

/// Service for timezone management and coordination
class TimezoneService: ObservableObject {
    static let shared = TimezoneService()
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    
    // MARK: - Timezone Detection
    
    /// Detect and return the user's current timezone
    func detectUserTimezone() -> TimeZone {
        return TimeZone.current
    }
    
    /// Get timezone offset from UTC in hours
    func getTimezoneOffset(for timezone: TimeZone, at date: Date = Date()) -> Int {
        return timezone.secondsFromGMT(for: date) / 3600
    }
    
    // MARK: - Timezone Management
    
    /// Update user's timezone in Firestore
    func updateUserTimezone(_ timezone: TimeZone, userId: String) async throws {
        let offset = getTimezoneOffset(for: timezone)
        
        try await db.collection("users").document(userId).updateData([
            "timezone": timezone.identifier,
            "timezoneOffset": offset
        ])
    }
    
    /// Update user's working hours
    func updateWorkingHours(
        userId: String,
        start: String,
        end: String,
        days: [String]
    ) async throws {
        try await db.collection("users").document(userId).updateData([
            "workingHours": [
                "start": start,
                "end": end,
                "days": days
            ]
        ])
    }
    
    // MARK: - Time Conversion
    
    /// Convert a date from one timezone to another
    func convertTime(_ date: Date, from sourceTimezone: TimeZone, to targetTimezone: TimeZone) -> Date {
        let sourceOffset = sourceTimezone.secondsFromGMT(for: date)
        let targetOffset = targetTimezone.secondsFromGMT(for: date)
        let difference = targetOffset - sourceOffset
        
        return date.addingTimeInterval(TimeInterval(difference))
    }
    
    /// Get current time in a specific timezone
    func getCurrentTime(in timezone: TimeZone) -> Date {
        return convertTime(Date(), from: TimeZone.current, to: timezone)
    }
    
    /// Format time for display in a timezone
    func formatTime(_ date: Date, in timezone: TimeZone, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.timeStyle = style
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    /// Format date and time for display in a timezone
    func formatDateTime(_ date: Date, in timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Working Hours
    
    /// Check if a user is within their working hours at a given time
    func isWithinWorkingHours(user: User, at date: Date = Date()) -> Bool {
        guard let workingHours = user.workingHours else {
            return false // No working hours set
        }
        
        // Get the user's timezone
        let userTimezone: TimeZone
        if let timezoneIdentifier = user.timezone,
           let tz = TimeZone(identifier: timezoneIdentifier) {
            userTimezone = tz
        } else {
            return false
        }
        
        // Convert current date to user's timezone
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: userTimezone, from: date)
        
        // Check if it's a working day
        let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard let weekday = components.weekday,
              weekday >= 1 && weekday <= 7 else {
            return false
        }
        let dayString = weekdaySymbols[weekday - 1]
        
        if !workingHours.days.contains(dayString) {
            return false // Not a working day
        }
        
        // Check if it's within working hours
        guard let hour = components.hour,
              let minute = components.minute else {
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        
        // Parse start and end times
        let startComponents = workingHours.start.split(separator: ":")
        let endComponents = workingHours.end.split(separator: ":")
        
        guard startComponents.count == 2,
              endComponents.count == 2,
              let startHour = Int(startComponents[0]),
              let startMinute = Int(startComponents[1]),
              let endHour = Int(endComponents[0]),
              let endMinute = Int(endComponents[1]) else {
            return false
        }
        
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        return currentMinutes >= startMinutes && currentMinutes < endMinutes
    }
    
    /// Get availability status for a user
    func getAvailabilityStatus(for user: User) -> AvailabilityStatus {
        if user.status == .doNotDisturb {
            return .doNotDisturb
        }
        
        if user.status == .busy {
            return .busy
        }
        
        if user.status == .offline {
            return .offline
        }
        
        guard user.workingHours != nil else {
            // No working hours set, use online status
            return user.status == .online ? .available : .away
        }
        
        if isWithinWorkingHours(user: user) {
            return .available
        } else {
            return .outsideHours
        }
    }
    
    // MARK: - Meeting Time Suggestions
    
    /// Suggest meeting times for multiple participants
    func suggestMeetingTimes(
        participants: [User],
        duration: TimeInterval,
        preferredDates: [Date] = [],
        onlyWorkingHours: Bool = true
    ) async throws -> [MeetingTimeSuggestion] {
        
        // Prepare request
        let participantData = participants.compactMap { user -> [String: Any]? in
            guard let userId = user.id,
                  let timezone = user.timezone else {
                return nil
            }
            
            var data: [String: Any] = [
                "userId": userId,
                "timezone": timezone
            ]
            
            if let workingHours = user.workingHours {
                data["workingHours"] = [
                    "start": workingHours.start,
                    "end": workingHours.end,
                    "days": workingHours.days
                ]
            }
            
            return data
        }
        
        let requestData: [String: Any] = [
            "participants": participantData,
            "duration": Int(duration / 60), // Convert to minutes
            "preferredDates": preferredDates.map { ISO8601DateFormatter().string(from: $0) },
            "onlyWorkingHours": onlyWorkingHours
        ]
        
        // Call Cloud Function
        let result = try await functions.httpsCallable("suggestMeetingTimes").call(requestData)
        
        guard let data = result.data as? [String: Any],
              let suggestions = data["suggestions"] as? [[String: Any]] else {
            throw TimezoneError.invalidResponse
        }
        
        // Parse suggestions
        return suggestions.compactMap { suggestionData in
            guard let startTimeString = suggestionData["startTime"] as? String,
                  let endTimeString = suggestionData["endTime"] as? String,
                  let score = suggestionData["score"] as? Double else {
                return nil
            }
            
            let formatter = ISO8601DateFormatter()
            guard let startTime = formatter.date(from: startTimeString),
                  let endTime = formatter.date(from: endTimeString) else {
                return nil
            }
            
            let availability = suggestionData["participantAvailability"] as? [String: String] ?? [:]
            let reasoning = suggestionData["reasoning"] as? String ?? ""
            
            return MeetingTimeSuggestion(
                startTime: startTime,
                endTime: endTime,
                participantAvailability: availability,
                score: score,
                reasoning: reasoning
            )
        }
    }
    
    // MARK: - Timezone Information
    
    /// Get list of common timezones
    func getCommonTimezones() -> [TimezoneInfo] {
        let identifiers = [
            "America/New_York",
            "America/Chicago",
            "America/Denver",
            "America/Los_Angeles",
            "America/Anchorage",
            "Pacific/Honolulu",
            "Europe/London",
            "Europe/Paris",
            "Europe/Berlin",
            "Europe/Moscow",
            "Asia/Dubai",
            "Asia/Kolkata",
            "Asia/Singapore",
            "Asia/Shanghai",
            "Asia/Tokyo",
            "Australia/Sydney",
            "Pacific/Auckland"
        ]
        
        return identifiers.compactMap { identifier in
            guard let timezone = TimeZone(identifier: identifier) else {
                return nil
            }
            return TimezoneInfo(timezone: timezone)
        }
    }
    
    /// Search timezones by name or abbreviation
    func searchTimezones(query: String) -> [TimezoneInfo] {
        guard !query.isEmpty else {
            return getCommonTimezones()
        }
        
        let lowercaseQuery = query.lowercased()
        
        return TimeZone.knownTimeZoneIdentifiers
            .filter { identifier in
                identifier.lowercased().contains(lowercaseQuery)
            }
            .prefix(20)
            .compactMap { identifier in
                guard let timezone = TimeZone(identifier: identifier) else {
                    return nil
                }
                return TimezoneInfo(timezone: timezone)
            }
    }
}

// MARK: - Supporting Types

enum AvailabilityStatus {
    case available
    case busy
    case away
    case offline
    case outsideHours
    case doNotDisturb
    
    var displayText: String {
        switch self {
        case .available: return "Available"
        case .busy: return "Busy"
        case .away: return "Away"
        case .offline: return "Offline"
        case .outsideHours: return "Outside working hours"
        case .doNotDisturb: return "Do not disturb"
        }
    }
    
    var color: String {
        switch self {
        case .available: return "green"
        case .busy: return "yellow"
        case .away: return "orange"
        case .offline: return "gray"
        case .outsideHours: return "blue"
        case .doNotDisturb: return "red"
        }
    }
}

struct MeetingTimeSuggestion: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let participantAvailability: [String: String] // userId -> status
    let score: Double
    let reasoning: String
}

struct TimezoneInfo: Identifiable {
    let id = UUID()
    let timezone: TimeZone
    
    var identifier: String {
        timezone.identifier
    }
    
    var displayName: String {
        // Format: "America/New_York (EST, UTC-5)"
        let abbreviation = timezone.abbreviation() ?? ""
        let offset = timezone.secondsFromGMT() / 3600
        let offsetString = offset >= 0 ? "+\(offset)" : "\(offset)"
        
        let name = timezone.identifier.replacingOccurrences(of: "_", with: " ")
        return "\(name) (\(abbreviation), UTC\(offsetString))"
    }
    
    var shortName: String {
        // Just the city name
        let components = timezone.identifier.components(separatedBy: "/")
        return components.last?.replacingOccurrences(of: "_", with: " ") ?? timezone.identifier
    }
}

enum TimezoneError: Error {
    case invalidResponse
    case invalidTimezone
    case noWorkingHours
    case apiError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidTimezone:
            return "Invalid timezone"
        case .noWorkingHours:
            return "No working hours set"
        case .apiError(let message):
            return message
        }
    }
}


