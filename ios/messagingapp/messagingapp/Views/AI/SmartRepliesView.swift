//
//  SmartRepliesView.swift
//  messagingapp
//
//  Phase 16: Smart Replies & Suggestions
//  Horizontal scrollable quick reply chips
//

import SwiftUI

struct SmartRepliesView: View {
    let smartReplies: [SmartReply]
    let onSelectReply: (SmartReply) -> Void
    let onRegenerate: () -> Void
    let isGenerating: Bool
    
    @State private var selectedReplyId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
            
            // Header with regenerate button
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("Quick Replies")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onRegenerate) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                        Text("Regenerate")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .disabled(isGenerating)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Replies scroll view
            if isGenerating {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    Text("Generating replies...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 50)
            } else if smartReplies.isEmpty {
                Text("No suggestions available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 50)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(smartReplies) { reply in
                            SmartReplyChip(
                                reply: reply,
                                isSelected: selectedReplyId == reply.id,
                                onTap: {
                                    selectedReplyId = reply.id
                                    onSelectReply(reply)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

struct SmartReplyChip: View {
    let reply: SmartReply
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Reply text
                Text(reply.text)
                    .font(.system(size: 15))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Tone indicator
                HStack(spacing: 4) {
                    Text(reply.tone.icon)
                        .font(.system(size: 10))
                    Text(reply.tone.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    // Confidence indicator (if > 0.8)
                    if reply.confidence >= 0.8 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 250, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State View

struct SmartRepliesEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.gray)
            Text("Smart Replies")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("AI will suggest replies to messages")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct SmartRepliesView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            SmartRepliesView(
                smartReplies: [
                    SmartReply(text: "Thanks! I'll check it out.", tone: .casual, confidence: 0.9),
                    SmartReply(text: "Sounds good to me!", tone: .friendly, confidence: 0.85),
                    SmartReply(text: "I appreciate your help with this.", tone: .professional, confidence: 0.75)
                ],
                onSelectReply: { _ in },
                onRegenerate: {},
                isGenerating: false
            )
            .frame(height: 100)
        }
        
        VStack {
            Spacer()
            
            SmartRepliesView(
                smartReplies: [],
                onSelectReply: { _ in },
                onRegenerate: {},
                isGenerating: true
            )
            .frame(height: 100)
        }
    }
}
#endif

