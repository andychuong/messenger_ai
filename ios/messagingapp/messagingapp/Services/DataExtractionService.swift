//
//  DataExtractionService.swift
//  messagingapp
//
//  Service for extracting structured data from conversations
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseFunctions
import EventKit
import Contacts

class DataExtractionService: ObservableObject {
    static let shared = DataExtractionService()
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private let eventStore = EKEventStore()
    
    @Published var isExtracting = false
    @Published var lastError: String?
    
    private init() {}
    
    // MARK: - Data Extraction
    
    /// Extract structured data from conversation messages
    func extractData(
        from messages: [Message],
        conversationId: String,
        dataTypes: [DataType] = DataType.allCases,
        userTimezone: String? = nil
    ) async throws -> StructuredData {
        isExtracting = true
        lastError = nil
        
        defer {
            Task { @MainActor in
                isExtracting = false
            }
        }
        
        // Prepare timezone
        let timezone = userTimezone ?? TimeZone.current.identifier
        
        // Prepare messages for API
        let messagesData = messages.map { message in
            [
                "id": message.id,
                "text": message.text,
                "senderId": message.senderId,
                "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
            ] as [String: Any]
        }
        
        // Call Cloud Function
        let callable = functions.httpsCallable("extractStructuredData")
        
        do {
            let result = try await callable.call([
                "messages": messagesData,
                "conversationId": conversationId,
                "dataTypes": dataTypes.map { $0.rawValue },
                "userTimezone": timezone
            ])
            
            guard let data = result.data as? [String: Any] else {
                throw NSError(domain: "DataExtractionService", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            // Parse response
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let structuredData = try JSONDecoder().decode(StructuredData.self, from: jsonData)
            
            // Cache in Firestore
            try await cacheExtractedData(structuredData, conversationId: conversationId)
            
            return structuredData
        } catch {
            let errorMessage = "Failed to extract data: \(error.localizedDescription)"
            await MainActor.run {
                self.lastError = errorMessage
            }
            throw error
        }
    }
    
    /// Get cached extracted data for a conversation
    func getCachedData(conversationId: String) async throws -> StructuredData? {
        let docRef = db.collection("conversations")
            .document(conversationId)
            .collection("extractedData")
            .document("latest")
        
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists, var data = snapshot.data() else {
            return nil
        }
        
        // Convert Firestore Timestamps to ISO strings and remove updatedAt
        if let updatedAt = data["updatedAt"] as? Timestamp {
            data["updatedAt"] = ISO8601DateFormatter().string(from: updatedAt.dateValue())
        }
        data.removeValue(forKey: "updatedAt")
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(StructuredData.self, from: jsonData)
    }
    
    /// Listen to extracted data updates
    func listenToExtractedData(
        conversationId: String,
        completion: @escaping (StructuredData?) -> Void
    ) -> ListenerRegistration {
        let docRef = db.collection("conversations")
            .document(conversationId)
            .collection("extractedData")
            .document("latest")
        
        return docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                NSLog("Error listening to extracted data: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists, var data = snapshot.data() else {
                completion(nil)
                return
            }
            
            do {
                // Convert Firestore Timestamps to ISO strings
                if let updatedAt = data["updatedAt"] as? Timestamp {
                    data["updatedAt"] = ISO8601DateFormatter().string(from: updatedAt.dateValue())
                }
                
                // Remove updatedAt field as it's not part of StructuredData model
                data.removeValue(forKey: "updatedAt")
                
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let structuredData = try JSONDecoder().decode(StructuredData.self, from: jsonData)
                completion(structuredData)
            } catch {
                NSLog("Error decoding extracted data: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Calendar Integration
    
    /// Request calendar access
    func requestCalendarAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    /// Export event to calendar
    func exportToCalendar(event: ExtractedEvent) async throws -> String {
        let hasAccess = try await requestCalendarAccess()
        
        guard hasAccess else {
            throw NSError(domain: "DataExtractionService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])
        }
        
        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = event.title
        calendarEvent.notes = event.description
        
        if let startDate = event.startDateTime {
            calendarEvent.startDate = startDate
            
            if let endDate = event.endDateTime {
                calendarEvent.endDate = endDate
            } else {
                // Default to 1 hour duration
                calendarEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)
            }
        } else if let dateObj = event.dateObject {
            calendarEvent.startDate = dateObj
            calendarEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dateObj)
            calendarEvent.isAllDay = true
        }
        
        if let location = event.location {
            calendarEvent.location = location
        }
        
        // Use default calendar
        calendarEvent.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(calendarEvent, span: .thisEvent)
        
        return calendarEvent.eventIdentifier
    }
    
    /// Check if event exists in calendar
    func isEventInCalendar(eventId: String) -> Bool {
        return eventStore.event(withIdentifier: eventId) != nil
    }
    
    // MARK: - Contacts Integration
    
    /// Request contacts access
    func requestContactsAccess() async throws -> Bool {
        let store = CNContactStore()
        
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// Export contact to contacts app
    func exportToContacts(contact: ExtractedContact) async throws -> String {
        let hasAccess = try await requestContactsAccess()
        
        guard hasAccess else {
            throw NSError(domain: "DataExtractionService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Contacts access denied"])
        }
        
        let store = CNContactStore()
        let newContact = CNMutableContact()
        
        // Parse name
        let nameComponents = contact.name.components(separatedBy: " ")
        if nameComponents.count > 0 {
            newContact.givenName = nameComponents[0]
            if nameComponents.count > 1 {
                newContact.familyName = nameComponents[1...].joined(separator: " ")
            }
        }
        
        // Add phone number
        if let phone = contact.phone {
            let phoneNumber = CNLabeledValue(
                label: CNLabelPhoneNumberMain,
                value: CNPhoneNumber(stringValue: phone)
            )
            newContact.phoneNumbers = [phoneNumber]
        }
        
        // Add email
        if let email = contact.email {
            let emailValue = CNLabeledValue(
                label: CNLabelWork,
                value: email as NSString
            )
            newContact.emailAddresses = [emailValue]
        }
        
        // Add company
        if let company = contact.company {
            newContact.organizationName = company
        }
        
        // Add note with context
        newContact.note = "From MessageAI: \(contact.context)"
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(newContact, toContainerWithIdentifier: nil)
        
        try store.execute(saveRequest)
        
        return newContact.identifier
    }
    
    /// Check if contact exists
    func findContact(name: String, email: String? = nil, phone: String? = nil) -> CNContact? {
        let store = CNContactStore()
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]
        
        // Try to find by email
        if let email = email {
            let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
            if let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch),
               let contact = contacts.first {
                return contact
            }
        }
        
        // Try to find by name
        let predicate = CNContact.predicateForContacts(matchingName: name)
        if let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch),
           let contact = contacts.first {
            return contact
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func cacheExtractedData(_ data: StructuredData, conversationId: String) async throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        
        guard let dictionary = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }
        
        var mutableDict = dictionary
        mutableDict["updatedAt"] = FieldValue.serverTimestamp()
        
        try await db.collection("conversations")
            .document(conversationId)
            .collection("extractedData")
            .document("latest")
            .setData(mutableDict)
    }
    
    // MARK: - Automatic Extraction
    
    /// Schedule automatic extraction for a conversation
    func scheduleAutoExtraction(conversationId: String) {
        // Auto extraction is handled by the Cloud Function trigger
        // This method is here for future client-side scheduling if needed
    }
    
    // MARK: - Maps Integration
    
    /// Open location in Maps app
    func openInMaps(location: ExtractedLocation) {
        var urlString = ""
        
        if let coordinates = location.coordinates {
            // Use coordinates if available
            urlString = "http://maps.apple.com/?ll=\(coordinates.lat),\(coordinates.lng)&q=\(location.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        } else if let address = location.address {
            // Use address
            urlString = "http://maps.apple.com/?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        } else {
            // Just search for the name
            urlString = "http://maps.apple.com/?q=\(location.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        if let url = URL(string: urlString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    /// Get directions to location
    func getDirections(to location: ExtractedLocation) {
        var urlString = ""
        
        if let coordinates = location.coordinates {
            urlString = "http://maps.apple.com/?daddr=\(coordinates.lat),\(coordinates.lng)"
        } else if let address = location.address {
            urlString = "http://maps.apple.com/?daddr=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        } else {
            urlString = "http://maps.apple.com/?daddr=\(location.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        if let url = URL(string: urlString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
}

