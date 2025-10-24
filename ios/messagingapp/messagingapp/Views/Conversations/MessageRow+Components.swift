//
//  MessageRow+Components.swift
//  messagingapp
//
//  Reusable message row components
//

import SwiftUI

// MARK: - Image Message View
struct ImageMessageView: View {
    let url: String
    let caption: String?
    let maxWidth: CGFloat = 250
    let maxHeight: CGFloat = 300
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: maxWidth, height: maxHeight)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(width: maxWidth, height: maxHeight)
                @unknown default:
                    EmptyView()
                }
            }
            
            if let caption = caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .padding(.horizontal, 8)
            }
        }
    }
}

// MARK: - Voice Message View
struct VoiceMessageView: View {
    let url: String
    let duration: TimeInterval
    @State private var isPlaying = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                isPlaying.toggle()
                // Note: Actual playback would be handled by VoiceRecordingService
                // This is a simplified UI representation
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isPlaying {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: 3, height: CGFloat.random(in: 10...20))
                                .animation(
                                    .easeInOut(duration: 0.5)
                                        .repeatForever()
                                        .delay(Double(index) * 0.1),
                                    value: isPlaying
                                )
                        }
                    }
                } else {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .frame(minWidth: 200)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Thread Indicator
struct ThreadIndicatorView: View {
    let count: Int
    let lastReplyPreview: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("\(count) \(count == 1 ? "reply" : "replies")")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                if let preview = lastReplyPreview {
                    Text("· \(preview)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }
}

// MARK: - Thread Reply Badge
struct ThreadReplyBadgeView: View {
    let replyToSender: String?
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2)
            Text("Reply to \(replyToSender ?? "message")")
                .font(.caption)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Reactions View
struct MessageReactionsView: View {
    let reactions: [String: [String]]
    let currentUserId: String
    let onReact: (String) -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(reactions.keys.sorted()), id: \.self) { emoji in
                if let userIds = reactions[emoji], !userIds.isEmpty {
                    reactionButton(emoji: emoji, userIds: userIds)
                }
            }
        }
    }
    
    private func reactionButton(emoji: String, userIds: [String]) -> some View {
        Button(action: {
            onReact(emoji)
        }) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption)
                Text("\(userIds.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(userIds.contains(currentUserId) ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(userIds.contains(currentUserId) ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Message Status Indicator
struct MessageStatusIndicatorView: View {
    let status: MessageStatus
    let readCount: Int
    
    var body: some View {
        HStack(spacing: 2) {
            switch status {
            case .sending:
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .delivered:
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.blue)
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                if readCount > 1 {
                    Text("\(readCount)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - System Message View
struct SystemMessageView: View {
    let text: String
    
    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

