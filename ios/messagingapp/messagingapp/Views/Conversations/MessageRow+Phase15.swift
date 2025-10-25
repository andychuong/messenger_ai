//
//  MessageRow+Phase15.swift
//  messagingapp
//
//  Phase 15: Message Row Extensions for Enhanced Translation Features
//  Adds cultural context, formality indicators, and slang detection
//

import SwiftUI
import Combine

// MARK: - Phase 15 State Management

extension MessageRow {
    /// State manager for Phase 15 features
    @MainActor
    class Phase15State: ObservableObject {
        @Published var showingCulturalContext = false
        @Published var showingSlangAnalysis = false
        @Published var culturalContext: CulturalContext?
        @Published var slangAnalysis: SlangAnalysis?
        @Published var isLoadingContext = false
        @Published var isLoadingSlang = false
        
        let culturalService = CulturalContextService.shared
        let slangService = SlangAnalysisService.shared
    }
}

// MARK: - Cultural Context Views

extension MessageRow {
    
    /// Cultural context indicator button
    @ViewBuilder
    func culturalContextIndicator(phase15State: Phase15State) -> some View {
        if let context = phase15State.culturalContext, context.hasContent {
            Button {
                phase15State.showingCulturalContext = true
                HapticManager.shared.selection()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                    
                    Text("Cultural Context")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        } else if phase15State.isLoadingContext {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Analyzing...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    /// Sheet for displaying cultural context
    @ViewBuilder
    func culturalContextSheet(phase15State: Phase15State) -> some View {
        if let context = phase15State.culturalContext {
            CulturalContextSheet(
                context: context,
                onDismiss: {
                    phase15State.showingCulturalContext = false
                }
            )
        }
    }
}

// MARK: - Slang Detection Views

extension MessageRow {
    
    /// Slang badge indicator
    @ViewBuilder
    func slangIndicator(phase15State: Phase15State) -> some View {
        if let analysis = phase15State.slangAnalysis, analysis.hasSlang {
            Button {
                phase15State.showingSlangAnalysis = true
                HapticManager.shared.selection()
            } label: {
                SlangBadge(count: analysis.expressionCount)
            }
        } else if phase15State.isLoadingSlang {
            ProgressView()
                .scaleEffect(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
    
    /// Text with underlined slang expressions
    @ViewBuilder
    func textWithSlangUnderlines(
        text: String,
        analysis: SlangAnalysis?,
        isSentByMe: Bool
    ) -> some View {
        if let analysis = analysis, !analysis.detectedExpressions.isEmpty {
            // If we have slang, create an attributed string with underlines
            slangHighlightedText(
                text: text,
                expressions: analysis.detectedExpressions,
                isSentByMe: isSentByMe
            )
        } else {
            // Regular text
            Text(text)
                .font(.body)
                .foregroundColor(isSentByMe ? .white : .primary)
        }
    }
    
    /// Text view with slang expressions underlined
    @ViewBuilder
    private func slangHighlightedText(
        text: String,
        expressions: [DetectedExpression],
        isSentByMe: Bool
    ) -> some View {
        // For simplicity, show regular text with a badge
        // A more advanced implementation would parse and underline specific phrases
        Text(text)
            .font(.body)
            .foregroundColor(isSentByMe ? .white : .primary)
    }
    
    /// Sheet for displaying slang analysis
    @ViewBuilder
    func slangAnalysisSheet(phase15State: Phase15State) -> some View {
        if let analysis = phase15State.slangAnalysis {
            SlangAnalysisSheet(
                analysis: analysis,
                onDismiss: {
                    phase15State.showingSlangAnalysis = false
                }
            )
        }
    }
}

// MARK: - Helper Methods

extension MessageRow {
    
    /// Load cultural context for a message
    func loadCulturalContext(
        phase15State: Phase15State,
        sourceLanguage: String,
        targetLanguage: String,
        messageContext: [String]? = nil
    ) async {
        // Only analyze messages from others
        guard message.senderId != currentUserId,
              !message.text.isEmpty,
              let messageId = message.id else {
            return
        }
        
        phase15State.isLoadingContext = true
        defer { phase15State.isLoadingContext = false }
        
        do {
            let context = try await phase15State.culturalService.analyzeCulturalContext(
                text: message.text,
                messageId: messageId,
                conversationId: message.conversationId,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                messageContext: messageContext
            )
            
            phase15State.culturalContext = context
        } catch {
            print("Failed to load cultural context: \(error)")
        }
    }
    
    /// Load slang analysis for a message
    func loadSlangAnalysis(
        phase15State: Phase15State,
        language: String,
        userLanguage: String?
    ) async {
        // Only analyze messages from others
        guard message.senderId != currentUserId,
              !message.text.isEmpty,
              let messageId = message.id else {
            return
        }
        
        phase15State.isLoadingSlang = true
        defer { phase15State.isLoadingSlang = false }
        
        do {
            let analysis = try await phase15State.slangService.analyzeSlang(
                text: message.text,
                messageId: messageId,
                conversationId: message.conversationId,
                language: language,
                userLanguage: userLanguage
            )
            
            phase15State.slangAnalysis = analysis
        } catch {
            print("Failed to load slang analysis: \(error)")
        }
    }
}

// MARK: - Context Menu Extensions

extension MessageRow {
    
    /// Additional context menu items for Phase 15
    @ViewBuilder
    func phase15ContextMenuItems(phase15State: Phase15State) -> some View {
        // Show cultural context option for messages from others
        if message.senderId != currentUserId {
            Button {
                phase15State.showingCulturalContext = true
            } label: {
                Label("Cultural Context", systemImage: "info.circle")
            }
            
            Button {
                phase15State.showingSlangAnalysis = true
            } label: {
                Label("Explain Slang", systemImage: "sparkles")
            }
        }
    }
}

// MARK: - Settings Keys

extension MessageRow {
    
    /// Check if cultural context is enabled in settings
    var isCulturalContextEnabled: Bool {
        UserDefaults.standard.bool(forKey: "culturalContextEnabled")
    }
    
    /// Check if slang analysis is enabled in settings
    var isSlangAnalysisEnabled: Bool {
        UserDefaults.standard.bool(forKey: "slangAnalysisEnabled")
    }
}

