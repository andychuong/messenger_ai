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
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Edit mode indicator
            if isEditing {
                editModeHeader
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Image picker button (only show when not editing)
                if !isEditing, let imagePicker = onImagePick {
                    Button {
                        imagePicker()
                    } label: {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(isSending)
                }
                
                // Voice recorder button (only show when not editing and text is empty)
                if !isEditing, text.isEmpty, let voiceRecorder = onVoiceRecord {
                    Button {
                        voiceRecorder()
                    } label: {
                        Image(systemName: "mic")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(isSending)
                }
                
                // Text input
                TextField(isEditing ? "Edit message" : "Message", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
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
                
                // Send/Update button
                Button {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

