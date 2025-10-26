//
//  DataExtractionViewModel.swift
//  messagingapp
//
//  ViewModel for managing extracted data state
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class DataExtractionViewModel: ObservableObject {
    @Published var structuredData: StructuredData?
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTab: Int = 0
    @Published var showExportSuccess = false
    @Published var exportMessage = ""
    
    private let service = DataExtractionService.shared
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    let conversationId: String
    
    init(conversationId: String) {
        self.conversationId = conversationId
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Data Loading
    
    func loadCachedData() async {
        isLoading = true
        error = nil
        
        do {
            structuredData = try await service.getCachedData(conversationId: conversationId)
            
            // Start listening for updates
            startListening()
        } catch {
            self.error = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func extractData(from messages: [Message]) async {
        isLoading = true
        error = nil
        
        do {
            structuredData = try await service.extractData(
                from: messages,
                conversationId: conversationId
            )
            
            // Start listening for updates
            startListening()
        } catch {
            self.error = "Failed to extract data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func startListening() {
        listener?.remove()
        
        listener = service.listenToExtractedData(conversationId: conversationId) { [weak self] data in
            Task { @MainActor in
                self?.structuredData = data
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Export Functions
    
    func exportEvent(_ event: ExtractedEvent) async {
        do {
            _ = try await service.exportToCalendar(event: event)
            showExportSuccess = true
            exportMessage = "Event '\(event.title)' added to Calendar"
        } catch {
            self.error = "Failed to export event: \(error.localizedDescription)"
        }
    }
    
    func exportContact(_ contact: ExtractedContact) async {
        do {
            _ = try await service.exportToContacts(contact: contact)
            showExportSuccess = true
            exportMessage = "Contact '\(contact.name)' added to Contacts"
        } catch {
            self.error = "Failed to export contact: \(error.localizedDescription)"
        }
    }
    
    func openInMaps(_ location: ExtractedLocation) {
        service.openInMaps(location: location)
    }
    
    func getDirections(to location: ExtractedLocation) {
        service.getDirections(to: location)
    }
    
    // MARK: - Computed Properties
    
    var hasData: Bool {
        structuredData?.isEmpty == false
    }
    
    var totalItems: Int {
        structuredData?.totalItems ?? 0
    }
    
    var events: [ExtractedEvent] {
        structuredData?.events ?? []
    }
    
    var tasks: [ExtractedTask] {
        structuredData?.tasks ?? []
    }
    
    var dates: [ExtractedDate] {
        structuredData?.dates ?? []
    }
    
    var locations: [ExtractedLocation] {
        structuredData?.locations ?? []
    }
    
    var contacts: [ExtractedContact] {
        structuredData?.contacts ?? []
    }
    
    var decisions: [ExtractedDecision] {
        structuredData?.decisions ?? []
    }
    
    // MARK: - Tab Counts
    
    var eventsCount: Int { events.count }
    var tasksCount: Int { tasks.count }
    var datesCount: Int { dates.count }
    var locationsCount: Int { locations.count }
    var contactsCount: Int { contacts.count }
    var decisionsCount: Int { decisions.count }
}

