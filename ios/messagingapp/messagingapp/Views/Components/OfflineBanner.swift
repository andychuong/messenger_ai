//
//  OfflineBanner.swift
//  messagingapp
//
//  Phase 11: Offline Support & Sync
//  Displays a banner when the user is offline
//

import SwiftUI

struct OfflineBanner: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @ObservedObject var messageQueue = MessageQueueService.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Internet Connection")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if messageQueue.queuedMessages.count > 0 {
                        Text("\(messageQueue.queuedMessages.count) message\(messageQueue.queuedMessages.count == 1 ? "" : "s") queued")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Text("Messages will be sent when connection is restored")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                if messageQueue.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.9))
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if messageQueue.queuedMessages.count > 0 {
            // Show processing banner when reconnected
            HStack(spacing: 8) {
                if messageQueue.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
                
                Text(messageQueue.isProcessing ? "Sending queued messages..." : "Connection restored")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.9))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        OfflineBanner()
            .environmentObject(NetworkMonitor.shared)
        
        Spacer()
    }
}

