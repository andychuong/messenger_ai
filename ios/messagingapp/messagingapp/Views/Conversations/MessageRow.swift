import SwiftUI

struct MessageRow: View {
    let message: Message
    let currentUserId: String
    var isGroupChat: Bool = false
    var showThreadIndicators: Bool = true
    let onDelete: () -> Void
    let onReact: (String) -> Void
    var onEdit: (() -> Void)? = nil
    var onReplyInThread: (() -> Void)? = nil
    
    @State private var showingActionMenu = false
    @State private var showingEmojiPicker = false
    @StateObject private var voiceService = VoiceRecordingService()
    
    private var isSentByMe: Bool {
        message.senderId == currentUserId
    }
    
    private var isSystemMessage: Bool {
        message.type == .system
    }
    
    var body: some View {
        if isSystemMessage {
            systemMessageView
        } else {
            regularMessageView
        }
    }
    
    private var regularMessageView: some View {
        HStack {
            if isSentByMe {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
                // Thread reply indicator (if this is a reply in a thread)
                if showThreadIndicators && message.replyTo != nil {
                    threadReplyBadge
                }
                
                // Message bubble
                messageBubble
                
                // Reactions
                if message.hasReactions {
                    reactionsView
                }
                
                // Thread indicator (if this message has replies)
                if showThreadIndicators, let threadCount = message.threadCount, threadCount > 0 {
                    threadIndicator(count: threadCount)
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
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiReactionPicker(isPresented: $showingEmojiPicker) { emoji in
                onReact(emoji)
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private var systemMessageView: some View {
        HStack {
            Spacer()
            Text(message.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var messageBubble: some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
            if isGroupChat || !isSentByMe {
                Text(message.senderName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSentByMe ? .blue : .gray)
                    .padding(.leading, 12)
            }
            
            // Image message
            if message.type == .image, let mediaURL = message.mediaURL {
                imageMessageView(url: mediaURL, caption: message.text)
            }
            // Voice message
            else if message.type == .voice, let mediaURL = message.mediaURL {
                voiceMessageView(url: mediaURL, duration: message.voiceDuration ?? 0)
            }
            // Text message
            else if !message.text.isEmpty {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(isSentByMe ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isSentByMe ? Color.blue : Color(.systemGray5)
                    )
                    .cornerRadius(20)
            }
            
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
    
    @ViewBuilder
    private func imageMessageView(url: String, caption: String) -> some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
            // Image
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 250, maxHeight: 300)
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
                    .frame(width: 200, height: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                @unknown default:
                    EmptyView()
                }
            }
            
            // Caption (if exists)
            if !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .foregroundColor(isSentByMe ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isSentByMe ? Color.blue : Color(.systemGray5)
                    )
                    .cornerRadius(20)
            }
        }
    }
    
    @ViewBuilder
    private func voiceMessageView(url: String, duration: TimeInterval) -> some View {
        if let audioURL = URL(string: url) {
            let isCurrentlyPlaying = voiceService.isPlaying && voiceService.currentlyPlayingURL == audioURL
            let progress = isCurrentlyPlaying && duration > 0 ? voiceService.playbackProgress / duration : 0
            
            HStack(spacing: 12) {
            // Play/Pause button
            Button {
                if isCurrentlyPlaying {
                    voiceService.pausePlayback()
                } else {
                    voiceService.playAudio(from: audioURL)
                }
            } label: {
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(isSentByMe ? .white : .blue)
                    .frame(width: 32, height: 32)
            }
            
            // Waveform / Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill((isSentByMe ? Color.white : Color.gray).opacity(0.3))
                            .frame(height: 3)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isSentByMe ? Color.white : Color.blue)
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                
                // Duration
                Text(VoiceRecordingService.formatDuration(isCurrentlyPlaying ? voiceService.playbackProgress : duration))
                    .font(.caption2)
                    .foregroundColor(isSentByMe ? .white.opacity(0.8) : .gray)
            }
            
            // Waveform icon
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundColor(isSentByMe ? .white.opacity(0.6) : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 200)
            .background(
                isSentByMe ? Color.blue : Color(.systemGray5)
            )
            .cornerRadius(20)
        } else {
            Text("Invalid audio URL")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private func threadIndicator(count: Int) -> some View {
        Button {
            onReplyInThread?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption2)
                Text("\(count) \(count == 1 ? "reply" : "replies")")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal, 12)
    }
    
    private var threadReplyBadge: some View {
        Button {
            // Trigger navigation to the parent thread
            onReplyInThread?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.caption2)
                Text("Thread reply")
                    .font(.caption2)
                    .fontWeight(.medium)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
    
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
    
    private var messageMetadata: some View{
        HStack(spacing: 4) {
            // Timestamp
            Text(message.formattedTime())
                .font(.caption2)
                .foregroundColor(.gray)
            
            if isSentByMe {
                if isGroupChat && message.status == .read {
                    readCountIndicator
                } else {
                    statusIndicator
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    private var readCountIndicator: some View {
        Group {
            if let readBy = message.readBy, !readBy.isEmpty {
                Text("Read by \(readBy.count)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else {
                statusIndicator
            }
        }
    }
    
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
    
    private var messageContextMenu: some View {
        Group {
            // Quick reactions
            Button {
                onReact("❤️")
            } label: {
                Label("❤️", systemImage: "heart")
            }
            
            Button {
                onReact("👍")
            } label: {
                Label("👍", systemImage: "hand.thumbsup")
            }
            
            Button {
                onReact("😂")
            } label: {
                Label("😂", systemImage: "face.smiling")
            }
            
            // Full emoji picker
            Button {
                showingEmojiPicker = true
            } label: {
                Label("More Reactions", systemImage: "face.smiling")
            }
            
            Divider()
            
            // Copy
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            // Reply in Thread
            Button {
                onReplyInThread?()
            } label: {
                Label("Reply in Thread", systemImage: "bubble.left.and.bubble.right")
            }
            
            Divider()
            
            // Edit and Delete (only for own messages)
            if isSentByMe {
                Divider()
                
                // Edit (if within time window)
                if message.canBeEdited() {
                    Button {
                        onEdit?()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

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

