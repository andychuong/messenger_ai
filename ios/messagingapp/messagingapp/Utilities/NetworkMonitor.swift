//
//  NetworkMonitor.swift
//  messagingapp
//
//  Phase 11: Offline Support & Sync
//  Monitors network connectivity and notifies observers of changes
//

import Foundation
import Network
import Combine

/// Network status enum
enum NetworkStatus: Equatable {
    case online
    case offline
    case unknown
    
    var isConnected: Bool {
        return self == .online
    }
}

/// NetworkMonitor monitors the device's network connectivity status
/// and publishes changes to any observers
@MainActor
class NetworkMonitor: ObservableObject {
    /// Shared singleton instance
    static let shared = NetworkMonitor()
    
    /// Published network status that views can observe
    @Published private(set) var status: NetworkStatus = .unknown
    
    /// Published boolean for quick connectivity checks
    @Published private(set) var isConnected: Bool = true
    
    /// Published boolean for cellular connection (vs WiFi)
    @Published private(set) var isCellular: Bool = false
    
    /// Published boolean for expensive connection (cellular, hotspot)
    @Published private(set) var isExpensive: Bool = false
    
    /// Network path monitor
    private let monitor: NWPathMonitor
    
    /// Queue for network monitoring
    private let queue = DispatchQueue(label: "com.messagingapp.networkmonitor")
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Private initializer for singleton
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    /// Start monitoring network changes
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.updateStatus(with: path)
            }
        }
        
        monitor.start(queue: queue)
        print("🌐 NetworkMonitor: Started monitoring network status")
    }
    
    /// Stop monitoring network changes
    func stopMonitoring() {
        monitor.cancel()
        print("🌐 NetworkMonitor: Stopped monitoring network status")
    }
    
    /// Update network status based on path
    @MainActor
    private func updateStatus(with path: NWPath) {
        let newStatus: NetworkStatus
        
        switch path.status {
        case .satisfied:
            newStatus = .online
            
            // Check connection type
            if path.usesInterfaceType(.cellular) {
                isCellular = true
            } else {
                isCellular = false
            }
            
            // Check if connection is expensive (cellular, hotspot)
            isExpensive = path.isExpensive
            
        case .unsatisfied, .requiresConnection:
            newStatus = .offline
            isCellular = false
            isExpensive = false
            
        @unknown default:
            newStatus = .unknown
            isCellular = false
            isExpensive = false
        }
        
        // Only update and notify if status actually changed
        if status != newStatus {
            let previousStatus = status
            status = newStatus
            isConnected = newStatus.isConnected
            
            print("🌐 NetworkMonitor: Status changed from \(previousStatus) to \(newStatus)")
            
            // Post notification for status change
            NotificationCenter.default.post(
                name: .networkStatusChanged,
                object: nil,
                userInfo: [
                    "previousStatus": previousStatus,
                    "currentStatus": newStatus,
                    "isConnected": isConnected,
                    "isCellular": isCellular,
                    "isExpensive": isExpensive
                ]
            )
        }
    }
    
    /// Check current connection type description
    var connectionType: String {
        if !isConnected {
            return "No Connection"
        }
        
        if isCellular {
            return "Cellular"
        }
        
        return "WiFi"
    }
    
    /// Check if we should conserve data (cellular or expensive connection)
    var shouldConserveData: Bool {
        return isCellular || isExpensive
    }
}

// MARK: - Notification Names
extension Notification.Name {
    /// Posted when network status changes
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    
    /// Posted when connection is restored
    static let connectionRestored = Notification.Name("connectionRestored")
    
    /// Posted when connection is lost
    static let connectionLost = Notification.Name("connectionLost")
}

// MARK: - Network Status Helpers
extension NetworkStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .online: return "Online"
        case .offline: return "Offline"
        case .unknown: return "Unknown"
        }
    }
}

