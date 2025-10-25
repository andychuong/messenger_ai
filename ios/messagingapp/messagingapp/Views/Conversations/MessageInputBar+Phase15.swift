//
//  MessageInputBar+Phase15.swift
//  messagingapp
//
//  Phase 15.2: Message Input Bar Extension for Formality Adjustment
//  Adds formality adjustment button and integration
//

import SwiftUI

/// Phase 15 extension for MessageInputBar
extension MessageInputBar {
    
    /// Formality adjustment button
    @ViewBuilder
    static func formalityAdjustmentButton(
        showingFormalityAdjuster: Binding<Bool>,
        isEnabled: Bool = true,
        isSending: Bool = false
    ) -> some View {
        Button {
            showingFormalityAdjuster.wrappedValue = true
            HapticManager.shared.light()
        } label: {
            Image(systemName: "text.alignleft")
                .font(.title2)
                .foregroundColor(isEnabled ? .purple : .gray)
        }
        .disabled(isSending || !isEnabled)
    }
}

/// Wrapper view for MessageInputBar with Phase 15 features
struct MessageInputBarWithFormality: View {
    @Binding var text: String
    let onSend: () -> Void
    let isSending: Bool
    let language: String
    
    // Standard MessageInputBar properties
    var isEditing: Bool = false
    var editingMessageText: String = ""
    var onCancelEdit: (() -> Void)? = nil
    var onImagePick: (() -> Void)? = nil
    var onVoiceRecord: (() -> Void)? = nil
    var nextMessageEncrypted: Bool = true
    var onToggleEncryption: (() -> Void)? = nil
    
    // Phase 15: Formality adjustment
    @State private var showingFormalityAdjuster = false
    @State private var formalityEnabled: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Edit mode indicator
            if isEditing {
                editModeHeader
            }
            
            HStack(alignment: .center, spacing: 12) {
                // Encryption toggle (only show when not editing)
                if !isEditing, let toggleEncryption = onToggleEncryption {
                    Button {
                        HapticManager.shared.toggleChanged()
                        SoundManager.shared.buttonTap()
                        toggleEncryption()
                    } label: {
                        Image(systemName: nextMessageEncrypted ? "lock.fill" : "lock.open.fill")
                            .font(.title2)
                            .foregroundColor(nextMessageEncrypted ? .orange : .blue)
                    }
                    .disabled(isSending)
                }
                
                // Phase 15: Formality adjustment button (only show when not editing and not encrypted)
                if !isEditing, !nextMessageEncrypted, !text.isEmpty {
                    Button {
                        showingFormalityAdjuster = true
                        HapticManager.shared.light()
                    } label: {
                        Image(systemName: "text.alignleft")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                    .disabled(isSending)
                }
                
                // Image picker button (only show when not editing)
                if !isEditing, let imagePicker = onImagePick {
                    Button {
                        HapticManager.shared.light()
                        imagePicker()
                    } label: {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(isSending)
                }
                
                // Text input with microphone button
                HStack(spacing: 8) {
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused = true
                            }
                        }
                    }
                    
                    // Microphone button inside text field
                    if !isEditing, text.isEmpty, let voiceRecorder = onVoiceRecord {
                        Button {
                            HapticManager.shared.medium()
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
                
                // Send button
                Button {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HapticManager.shared.messageSent()
                        SoundManager.shared.messageSent()
                        onSend()
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
        .sheet(isPresented: $showingFormalityAdjuster) {
            FormalityAdjusterView(
                messageText: $text,
                language: language,
                onApply: { adjustedText in
                    text = adjustedText
                },
                onDismiss: {
                    showingFormalityAdjuster = false
                }
            )
        }
        .onAppear {
            // Check if formality adjustment is enabled in settings
            formalityEnabled = UserDefaults.standard.bool(forKey: "formalityAdjustmentEnabled")
        }
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
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let cancel = onCancelEdit {
                Button {
                    cancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        MessageInputBarWithFormality(
            text: .constant("Hello, how are you?"),
            onSend: {},
            isSending: false,
            language: "English",
            nextMessageEncrypted: false
        )
    }
}

