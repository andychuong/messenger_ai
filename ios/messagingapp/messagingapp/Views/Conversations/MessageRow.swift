//
//  MessageRow.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//

import SwiftUI

struct MessageRow: View {
    let message: Message
    let currentUserId: String
    let onDelete: () -> Void
    let onReact: (String) -> Void
    
    @State private var showingActionMenu = false
    
    private var isSentByMe: Bool {
        message.senderId == currentUserId
    }
    
    var body: some View {
        HStack {
            if isSentByMe {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
                // Message bubble
                messageBubble
                
                // Reactions
                if message.hasReactions {
                    reactionsView
                }
                
                // Metadata (time and status)
                messageMetadata
            }
            
            if !isSentByMe {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contextMenu {
            messageContextMenu
        }
    }
    
    // MARK: - Message Bubble
    
    private var messageBubble: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
            // Sender name (for received messages)
            if !isSentByMe {
                Text(message.senderName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .padding(.leading, 12)
            }
            
            // Message text
            Text(message.text)
                .font(.body)
                .foregroundColor(isSentByMe ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSentByMe ? Color.blue : Color(.systemGray5)
                )
                .cornerRadius(20)
            
            // Edited indicator
            if message.wasEdited {
                Text("Edited")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal, 12)
            }
        }
    }
    
    // MARK: - Reactions View
    
    private var reactionsView: some View {
        HStack(spacing: 4) {
            if let reactions = message.reactions {
                ForEach(Array(reactions.values).uniqued(), id: \.self) { emoji in
                    let count = reactions.values.filter { $0 == emoji }.count
                    HStack(spacing: 2) {
                        Text(emoji)
                            .font(.caption)
                        if count > 1 {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Message Metadata
    
    private var messageMetadata: some View {
        HStack(spacing: 4) {
            // Timestamp
            Text(message.formattedTime())
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Status indicators (for sent messages)
            if isSentByMe {
                statusIndicator
            }
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.gray)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.gray)
            case .delivered:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.gray)
            case .read:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Context Menu
    
    private var messageContextMenu: some View {
        Group {
            // React
            Button {
                onReact("❤️")
            } label: {
                Label("❤️ React", systemImage: "heart")
            }
            
            Button {
                onReact("👍")
            } label: {
                Label("👍 React", systemImage: "hand.thumbsup")
            }
            
            Button {
                onReact("😂")
            } label: {
                Label("😂 React", systemImage: "face.smiling")
            }
            
            Divider()
            
            // Copy
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            // Delete (only for own messages)
            if isSentByMe {
                Divider()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Array Extension for Unique Values

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Sent message
        MessageRow(
            message: Message(
                id: "1",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Me",
                text: "Hey! How are you doing?",
                timestamp: Date(),
                status: .read,
                type: .text
            ),
            currentUserId: "user1",
            onDelete: {},
            onReact: { _ in }
        )
        
        // Received message
        MessageRow(
            message: Message(
                id: "2",
                conversationId: "conv1",
                senderId: "user2",
                senderName: "Alice",
                text: "I'm doing great! Thanks for asking 😊",
                timestamp: Date(),
                status: .delivered,
                type: .text
            ),
            currentUserId: "user1",
            onDelete: {},
            onReact: { _ in }
        )
    }
    .padding()
}

