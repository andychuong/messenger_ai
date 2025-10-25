//
//  MessageInputBar.swift
//  messagingapp
//
//  Phase 3: Core Messaging
//  Phase 4: Added edit mode support
//

import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let isSending: Bool
    
    // Edit mode
    var isEditing: Bool = false
    var editingMessageText: String = ""
    var onCancelEdit: (() -> Void)? = nil
    
    // Image picking
    var onImagePick: (() -> Void)? = nil
    
    // Voice recording
    var onVoiceRecord: (() -> Void)? = nil
    
    // Phase 9.5 Redesign: Encryption toggle
    var nextMessageEncrypted: Bool = true
    var onToggleEncryption: (() -> Void)? = nil
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Edit mode indicator
            if isEditing {
                editModeHeader
            }
            
            HStack(alignment: .center, spacing: 12) {
                // Phase 9.5 Redesign: Lock/Unlock toggle (only show when not editing)
                if !isEditing, let toggleEncryption = onToggleEncryption {
                    Button {
                        HapticManager.shared.toggleChanged() // Phase 12: Haptic feedback
                        SoundManager.shared.buttonTap() // Phase 12: Sound effect
                        toggleEncryption()
                    } label: {
                        Image(systemName: nextMessageEncrypted ? "lock.fill" : "lock.open.fill")
                            .font(.title2)
                            .foregroundColor(nextMessageEncrypted ? .orange : .blue)
                    }
                    .disabled(isSending)
                }
                
                // Image picker button (only show when not editing)
                if !isEditing, let imagePicker = onImagePick {
                    Button {
                        HapticManager.shared.light() // Phase 12: Haptic feedback
                        imagePicker()
                    } label: {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(isSending)
                }
                
                // Phase 9.5 Redesign: Text input with microphone button inside (iOS Messenger style)
                HStack(spacing: 8) {
                    // Text input with encryption-aware placeholder
                    TextField(
                        isEditing ? "Edit message" : (nextMessageEncrypted ? "Encrypted message" : "AI-enhanced message"),
                        text: $text,
                        axis: .vertical
                    )
                        .textFieldStyle(.plain)
                        .padding(.leading, 12)
                        .padding(.vertical, 8)
                        .lineLimit(1...5)
                        .focused($isTextFieldFocused)
                        .disabled(isSending)
                        .onSubmit {
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSend()
                                // Keep keyboard open after sending
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                }
                            }
                        }
                    
                    // Microphone button inside text field (only when empty and not editing)
                    if !isEditing, text.isEmpty, let voiceRecorder = onVoiceRecord {
                        Button {
                            HapticManager.shared.medium() // Phase 12: Haptic feedback
                            voiceRecorder()
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(isSending)
                        .padding(.trailing, 8)
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                
                // Send/Update button
                Button {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HapticManager.shared.messageSent() // Phase 12: Haptic feedback
                        SoundManager.shared.messageSent() // Phase 12: Sound effect
                        onSend()
                        // Keep keyboard open after sending
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Edit Mode Header
    
    private var editModeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Message")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(editingMessageText)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                onCancelEdit?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

#Preview {
    VStack {
        Spacer()
        MessageInputBar(
            text: .constant("Hello!"),
            onSend: {},
            isSending: false
        )
    }
}

