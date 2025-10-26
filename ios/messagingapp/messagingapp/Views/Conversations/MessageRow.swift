import SwiftUI

struct MessageRow: View {
    let message: Message
    let currentUserId: String
    var isGroupChat: Bool = false
    var showThreadIndicators: Bool = true
    var participantDetails: [String: ParticipantDetail] = [:]
    let onDelete: () -> Void
    let onReact: (String) -> Void
    var onEdit: (() -> Void)? = nil
    var onReplyInThread: (() -> Void)? = nil
    
    // Auto-translation support
    var autoTranslateEnabled: Bool = false
    var translatedText: String? = nil
    
    // Timezone support (Phase 18)
    var senderTimezone: String? = nil
    var currentUserTimezone: String? = nil
    
    @State private var showingActionMenu = false
    @State private var showingEmojiPicker = false
    @State private var showingTranslationMenu = false
    @State private var showingTranslation = false
    @State private var showingTranslationError = false
    @State private var showingOriginal = false // Toggle between original and translated
    @State private var showingFilePreview = false  // Phase 19: File preview
    @State private var showingVoiceTranslation = false  // Phase 19.2: Voice translation toggle
    @State private var selectedVoiceLanguage: String?  // Phase 19.2: Selected language for voice translation
    @StateObject private var voiceService = VoiceRecordingService()
    @StateObject private var translationViewModel = TranslationViewModel()
    
    private var isSentByMe: Bool {
        message.senderId == currentUserId
    }
    
    private var isSystemMessage: Bool {
        message.type == .system
    }
    
    private var messageType: MessageType {
        message.type ?? .text  // Default to .text for backward compatibility
    }
    
    private var translationErrorMessage: String {
        translationViewModel.translationError ?? "An error occurred"
    }
    
    // Determine which text to display based on auto-translation state
    private var displayedText: String {
        if autoTranslateEnabled && !showingOriginal, let translated = translatedText {
            return translated
        }
        return message.text
    }
    
    // Calculate timezone difference
    private var timezoneDifference: String? {
        guard let senderTZ = senderTimezone,
              let currentTZ = currentUserTimezone,
              let senderTimezone = TimeZone(identifier: senderTZ),
              let currentTimezone = TimeZone(identifier: currentTZ) else {
            return nil
        }
        
        let currentOffset = currentTimezone.secondsFromGMT() / 3600
        let senderOffset = senderTimezone.secondsFromGMT() / 3600
        let difference = senderOffset - currentOffset
        
        // If same offset, don't show anything
        if difference == 0 {
            return nil
        } else if difference > 0 {
            return "+\(difference)h"
        } else {
            return "\(difference)h"
        }
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
        .sheet(isPresented: $showingTranslationMenu) {
            if let messageId = message.id {
                TranslationMenuView(
                    messageId: messageId,
                    conversationId: message.conversationId,
                    translationViewModel: translationViewModel,
                    onTranslate: { language in
                        Task {
                            await translationViewModel.translateMessage(
                                messageId: messageId,
                                conversationId: message.conversationId,
                                targetLanguage: language,
                                text: message.text
                            )
                            if translationViewModel.currentTranslation != nil {
                                showingTranslation = true
                            }
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingTranslation) {
            if let translation = translationViewModel.currentTranslation {
                TranslationOverlayView(
                    originalText: translation.originalText,
                    translatedText: translation.translatedText,
                    targetLanguage: translation.targetLanguage,
                    fromCache: translation.fromCache
                )
            }
        }
        .overlay {
            if translationViewModel.isTranslating {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.4)
                    
                    // Loading card
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        
                        Text("Translating...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    )
                }
            }
        }
        .alert(
            "Translation Error",
            isPresented: $showingTranslationError,
            actions: {
                Button("OK") {
                    translationViewModel.translationError = nil
                    showingTranslationError = false
                }
            },
            message: {
                Text(translationErrorMessage)
            }
        )
        .onChange(of: translationViewModel.translationError) { oldValue, newValue in
            showingTranslationError = newValue != nil
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
            if isGroupChat && !isSentByMe {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Small avatar circle
                        let senderName = message.senderName ?? "Unknown"
                        let senderColor = ColorGenerator.color(for: message.senderId)
                        let initials = ColorGenerator.initials(from: senderName)
                        
                        Circle()
                            .fill(senderColor)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text(initials)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        Text(senderName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(senderColor)
                    }
                    
                    // Show timezone difference if exists
                    if let tzDiff = timezoneDifference {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 8))
                            Text(tzDiff)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)  // Align with name after avatar
                    }
                }
                .padding(.leading, 12)
            }
            
            // Image message
            if messageType == .image, let mediaURL = message.mediaURL {
                imageMessageView(url: mediaURL, caption: message.text)
            }
            // Voice message
            else if messageType == .voice, let mediaURL = message.mediaURL {
                voiceMessageView(url: mediaURL, duration: message.voiceDuration ?? 0)
            }
            // File message (Phase 19)
            else if messageType == .file, let fileMetadata = message.fileMetadata {
                fileMessageView(fileMetadata: fileMetadata)
            }
            // Text message
            else if !message.text.isEmpty {
                VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
                    // Display translated or original text
                    Text(displayedText)
                        .font(.body)
                        .foregroundColor(isSentByMe ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            isSentByMe ? Color.blue : Color(.systemGray5)
                        )
                        .cornerRadius(20)
                    
                    // Translation indicator
                    if autoTranslateEnabled && translatedText != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "translate")
                                .font(.caption2)
                            Text(showingOriginal ? "Original" : "Translated")
                                .font(.caption2)
                            
                            // Toggle button
                            Button {
                                showingOriginal.toggle()
                                HapticManager.shared.selection()
                            } label: {
                                Text(showingOriginal ? "Show Translation" : "Show Original")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    }
                }
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
            // Encrypted Image
            EncryptedImageView(
                url: url,
                conversationId: message.conversationId,
                maxWidth: 250,
                maxHeight: 300
            )
            
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
            
            VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 8) {
                // Voice player
                HStack(spacing: 12) {
                // Play/Pause button
                Button {
                    if isCurrentlyPlaying {
                        voiceService.pausePlayback()
                    } else {
                        // Pass conversation context and encryption status for proper playback
                        voiceService.playAudio(
                            from: audioURL,
                            conversationId: message.conversationId,
                            isEncrypted: message.isEncrypted ?? false
                        )
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
                
                // Phase 19.2: Voice transcript with translation toggle
                if let transcript = message.voiceTranscript {
                    voiceTranscriptView(transcript: transcript)
                }
            }
        } else {
            Text("Invalid audio URL")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // Phase 19.2: Voice transcript view with translation toggle
    @ViewBuilder
    private func voiceTranscriptView(transcript: String) -> some View {
        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
            // Determine which transcript to show (original or translated)
            let displayTranscript: String = {
                if showingVoiceTranslation, 
                   let selectedLang = selectedVoiceLanguage,
                   let translatedText = message.voiceTranslations?[selectedLang] {
                    return translatedText
                }
                return transcript
            }()
            
            // Transcript text
            Text(displayTranscript)
                .font(.caption)
                .foregroundColor(isSentByMe ? .white.opacity(0.9) : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (isSentByMe ? Color.blue : Color(.systemGray5)).opacity(0.7)
                )
                .cornerRadius(12)
            
            // Translation controls if translations exist
            if let translations = message.voiceTranslations, !translations.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble")
                        .font(.caption2)
                    
                    if showingVoiceTranslation, let lang = selectedVoiceLanguage {
                        Text("Translated to \(lang)")
                            .font(.caption2)
                    } else {
                        if let detectedLang = message.detectedLanguage {
                            Text("Original (\(detectedLang))")
                                .font(.caption2)
                        } else {
                            Text("Original")
                                .font(.caption2)
                        }
                    }
                    
                    // Toggle button
                    Menu {
                        Button("Original") {
                            showingVoiceTranslation = false
                            selectedVoiceLanguage = nil
                        }
                        
                        ForEach(Array(translations.keys.sorted()), id: \.self) { lang in
                            Button(languageDisplayName(lang)) {
                                showingVoiceTranslation = true
                                selectedVoiceLanguage = lang
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            }
        }
    }
    
    // Helper to get display name for language code
    private func languageDisplayName(_ code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code
    }
    
    // Phase 19: File attachment view
    @ViewBuilder
    private func fileMessageView(fileMetadata: FileMetadata) -> some View {
        Button {
            showingFilePreview = true
        } label: {
            HStack(spacing: 12) {
                // File icon
                ZStack {
                    Circle()
                        .fill(fileCategoryColor(for: fileMetadata.fileCategory))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: fileMetadata.fileCategory.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileMetadata.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSentByMe ? .white : .primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(fileMetadata.formattedFileSize())
                            .font(.caption)
                            .foregroundColor(isSentByMe ? .white.opacity(0.7) : .secondary)
                        
                        Text(fileMetadata.fileCategory.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(isSentByMe ? .white.opacity(0.7) : .secondary)
                    }
                }
                
                Spacer()
                
                // Download/view icon
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundColor(isSentByMe ? .white.opacity(0.8) : .blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 250, maxWidth: 300)
            .background(
                isSentByMe ? Color.blue : Color(.systemGray5)
            )
            .cornerRadius(20)
        }
        .sheet(isPresented: $showingFilePreview) {
            if let messageId = message.id {
                FilePreviewSheet(
                    messageId: messageId,
                    fileMetadata: fileMetadata,
                    conversationId: message.conversationId,
                    isPresented: $showingFilePreview
                )
            }
        }
    }
    
    private func fileCategoryColor(for category: FileCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        default: return .gray
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
                MessageReactionsView(
                    reactions: reactions,
                    currentUserId: currentUserId,
                    onReact: onReact
                )
            }
        }
        .padding(.horizontal, 12)
    }
    
    private var messageMetadata: some View{
        HStack(spacing: 4) {
            // Phase 9.5 Redesign: Encryption indicator
            if let isEncrypted = message.isEncrypted {
                Image(systemName: isEncrypted ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 8))
                    .foregroundColor(isEncrypted ? .orange : .blue)
            }
            
            // Timestamp
            Text(message.formattedTime())
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Show timezone difference in direct chats (not group chats)
            if !isGroupChat && !isSentByMe, let tzDiff = timezoneDifference {
                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                    Text(tzDiff)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            if isSentByMe {
                if isGroupChat {
                    // Group chat: show read receipts with viewer circles
                    readCountIndicator
                } else {
                    // Direct chat: show standard status indicator
                    statusIndicator
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    private var readCountIndicator: some View {
        Group {
            if let readBy = message.readBy, !readBy.isEmpty {
                MessageReadReceipt(
                    readBy: readBy,
                    participantDetails: participantDetails,
                    totalParticipants: participantDetails.count,
                    currentUserId: currentUserId
                )
            } else {
                // Show gray checkmark when sent but no one has read yet
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var statusIndicator: some View {
        Group {
            // Use computed status based on read receipts
            let currentStatus = message.computedStatus()
            
            switch currentStatus {
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
            
            // Translate (only for text messages with valid IDs)
            if !message.text.isEmpty && messageType != .system && message.id != nil {
                Button {
                    showingTranslationMenu = true
                } label: {
                    Label("Translate", systemImage: "globe")
                }
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

