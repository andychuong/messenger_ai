//
//  FormalityAdjusterView.swift
//  messagingapp
//
//  Phase 15.2: Formality Adjuster View
//  Allows users to adjust the formality level of their messages before sending
//

import SwiftUI
import Combine

/// View for adjusting message formality level
struct FormalityAdjusterView: View {
    
    @Binding var messageText: String
    let language: String
    let onApply: (String) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = FormalityAdjusterViewModel()
    @State private var selectedFormality: FormalityLevel = .neutral
    @State private var isAdjusting = false
    
    private let formalityLevels: [FormalityLevel] = [
        .casual, .neutral, .formal
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Original message
                originalMessageSection
                
                Divider()
                
                // Formality selector
                formalitySelector
                
                Divider()
                
                // Adjusted preview
                if viewModel.adjustment != nil {
                    adjustedMessageSection
                    
                    if !viewModel.changes.isEmpty {
                        Divider()
                        changesSection
                    }
                } else if isAdjusting {
                    loadingSection
                } else {
                    emptyStateSection
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("Adjust Formality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .task {
            // Detect current formality
            await viewModel.detectFormality(text: messageText, language: language)
        }
    }
    
    // MARK: - Sections
    
    private var originalMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Original Message")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let detected = viewModel.detectedFormality {
                    FormalityTag(level: detected)
                }
            }
            
            Text(messageText)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
    }
    
    private var formalitySelector: some View {
        VStack(spacing: 16) {
            Text("Choose Formality Level")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Segmented control style selector
            HStack(spacing: 0) {
                ForEach(formalityLevels, id: \.self) { level in
                    FormalityButton(
                        level: level,
                        isSelected: selectedFormality == level,
                        isDetected: level == viewModel.detectedFormality
                    ) {
                        selectedFormality = level
                        adjustMessage()
                    }
                }
            }
            .background(Color(.systemGray5))
            .cornerRadius(10)
            
            // Quick action buttons
            HStack(spacing: 12) {
                Button {
                    selectedFormality = .formal
                    adjustMessage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                        Text("Make More Formal")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button {
                    selectedFormality = .casual
                    adjustMessage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                        Text("Make More Casual")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
    }
    
    private var adjustedMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Adjusted Message")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                FormalityTag(level: selectedFormality)
            }
            
            Text(viewModel.adjustedText)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
        }
        .padding()
    }
    
    private var changesSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Changes Made")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                ForEach(viewModel.changes) { change in
                    ChangeCard(change: change)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Adjusting formality...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Select a formality level")
                .font(.headline)
            
            Text("Choose how formal or casual you want your message to sound")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                onDismiss()
            } label: {
                Text("Keep Original")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
            }
            
            Button {
                if let adjusted = viewModel.adjustment {
                    onApply(adjusted.adjustedText)
                    onDismiss()
                }
            } label: {
                Text("Use Adjusted")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.adjustment != nil ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(viewModel.adjustment == nil)
        }
        .padding()
    }
    
    // MARK: - Methods
    
    private func adjustMessage() {
        guard selectedFormality != viewModel.detectedFormality else { return }
        
        Task {
            isAdjusting = true
            await viewModel.adjustFormality(
                text: messageText,
                language: language,
                targetFormality: selectedFormality
            )
            isAdjusting = false
        }
    }
}

// MARK: - View Model

@MainActor
class FormalityAdjusterViewModel: ObservableObject {
    @Published var detectedFormality: FormalityLevel?
    @Published var adjustment: FormalityAdjustment?
    @Published var isLoading = false
    
    private let service = CulturalContextService.shared
    
    var adjustedText: String {
        adjustment?.adjustedText ?? ""
    }
    
    var changes: [FormalityChange] {
        adjustment?.changes ?? []
    }
    
    func detectFormality(text: String, language: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (level, _) = try await service.detectFormality(text: text, language: language)
            detectedFormality = level
        } catch {
            print("Failed to detect formality: \(error)")
            detectedFormality = .neutral
        }
    }
    
    func adjustFormality(text: String, language: String, targetFormality: FormalityLevel) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            adjustment = try await service.adjustFormality(
                text: text,
                language: language,
                targetFormality: targetFormality
            )
        } catch {
            print("Failed to adjust formality: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct FormalityButton: View {
    let level: FormalityLevel
    let isSelected: Bool
    let isDetected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(level.icon)
                    .font(.title3)
                
                Text(level.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if isDetected {
                    Text("Current")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(8)
        }
    }
}

struct FormalityTag: View {
    let level: FormalityLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Text(level.icon)
                .font(.caption)
            
            Text(level.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}


struct ChangeCard: View {
    let change: FormalityChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Text(change.original)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .strikethrough()
            }
            
            // Adjusted
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text(change.adjusted)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            
            // Reason
            if !change.reason.isEmpty {
                Text(change.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.leading, 20)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    FormalityAdjusterView(
        messageText: .constant("Hey, can you send me that file?"),
        language: "English",
        onApply: { _ in },
        onDismiss: {}
    )
}

