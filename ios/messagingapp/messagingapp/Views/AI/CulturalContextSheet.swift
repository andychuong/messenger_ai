//
//  CulturalContextSheet.swift
//  messagingapp
//
//  Phase 15.1: Cultural Context Sheet
//  Bottom sheet displaying cultural context, idioms, and formality information
//

import SwiftUI

/// Bottom sheet view for displaying cultural context information
struct CulturalContextSheet: View {
    
    let context: CulturalContext
    let onDismiss: () -> Void
    
    @State private var selectedTab: Tab = .overview
    
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case idioms = "Idioms"
        case formality = "Formality"
        case recommendations = "Tips"
        
        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .idioms: return "book.fill"
            case .formality: return "text.alignleft"
            case .recommendations: return "lightbulb.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .idioms:
                            idiomsContent
                        case .formality:
                            formalityContent
                        case .recommendations:
                            recommendationsContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Cultural Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    // Only show tabs with content
                    if shouldShow(tab: tab) {
                        TabButton(
                            title: tab.rawValue,
                            icon: tab.icon,
                            isSelected: selectedTab == tab
                        ) {
                            withAnimation {
                                selectedTab = tab
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Formality indicator at top
            formalityIndicator
            
            if !context.culturalNotes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Cultural Notes", icon: "globe")
                    
                    ForEach(Array(context.culturalNotes.enumerated()), id: \.offset) { _, note in
                        NoteCard(text: note)
                    }
                }
            }
            
            if !context.idioms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Key Expressions", icon: "quote.bubble")
                    
                    ForEach(context.idioms.prefix(3)) { idiom in
                        IdiomPreviewCard(idiom: idiom)
                    }
                    
                    if context.idioms.count > 3 {
                        Button {
                            selectedTab = .idioms
                        } label: {
                            Text("See all \(context.idioms.count) expressions →")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            if context.culturalNotes.isEmpty && context.idioms.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle.fill",
                    title: "No Special Notes",
                    message: "This message doesn't contain culturally-specific content that requires explanation."
                )
            }
        }
    }
    
    @ViewBuilder
    private var idiomsContent: some View {
        if !context.idioms.isEmpty {
            VStack(spacing: 16) {
                ForEach(context.idioms) { idiom in
                    IdiomCard(idiom: idiom)
                }
            }
        } else {
            EmptyStateView(
                icon: "book.closed",
                title: "No Idioms Found",
                message: "This message doesn't contain any idiomatic expressions."
            )
        }
    }
    
    @ViewBuilder
    private var formalityContent: some View {
        VStack(spacing: 20) {
            // Formality level display
            VStack(spacing: 12) {
                Text(context.formalityLevel.icon)
                    .font(.system(size: 60))
                
                Text(context.formalityLevel.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(context.formalityLevel.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Formality scale
            FormalityScale(currentLevel: context.formalityLevel)
        }
    }
    
    @ViewBuilder
    private var recommendationsContent: some View {
        if let recommendations = context.recommendations, !recommendations.isEmpty {
            VStack(spacing: 16) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    RecommendationCard(
                        number: index + 1,
                        text: recommendation
                    )
                }
            }
        } else {
            EmptyStateView(
                icon: "lightbulb",
                title: "No Recommendations",
                message: "No specific recommendations for this message."
            )
        }
    }
    
    // MARK: - Components
    
    private var formalityIndicator: some View {
        HStack(spacing: 8) {
            Text(context.formalityLevel.icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Formality Level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(context.formalityLevel.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Button {
                selectedTab = .formality
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Methods
    
    private func shouldShow(tab: Tab) -> Bool {
        switch tab {
        case .overview:
            return true
        case .idioms:
            return !context.idioms.isEmpty
        case .formality:
            return true
        case .recommendations:
            return context.recommendations?.isEmpty == false
        }
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.blue : Color(.systemGray5)
            )
            .cornerRadius(20)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

struct NoteCard: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct IdiomPreviewCard: View {
    let idiom: Idiom
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\"\(idiom.phrase)\"")
                    .font(.body)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(idiom.meaning)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct IdiomCard: View {
    let idiom: Idiom
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Phrase
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.purple)
                
                Text(idiom.phrase)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            Divider()
            
            // Meaning
            VStack(alignment: .leading, spacing: 6) {
                Text("Meaning")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(idiom.meaning)
                    .font(.subheadline)
            }
            
            // Cultural significance (if available)
            if let significance = idiom.culturalSignificance {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cultural Context")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(significance)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecommendationCard: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct FormalityScale: View {
    let currentLevel: FormalityLevel
    
    private let levels: [FormalityLevel] = [
        .veryCasual, .casual, .neutral, .formal, .veryFormal
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Formality Scale")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(levels, id: \.self) { level in
                    HStack(spacing: 12) {
                        // Indicator
                        Circle()
                            .fill(level == currentLevel ? Color.blue : Color(.systemGray4))
                            .frame(width: 12, height: 12)
                        
                        // Level info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.displayName)
                                .font(.subheadline)
                                .fontWeight(level == currentLevel ? .semibold : .regular)
                            
                            if level == currentLevel {
                                Text("Current level")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        Text(level.icon)
                            .font(.title3)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    CulturalContextSheet(
        context: CulturalContext(
            culturalNotes: [
                "This phrase is commonly used in formal business settings.",
                "The honorific form shows respect to the recipient."
            ],
            idioms: [
                Idiom(
                    phrase: "break the ice",
                    meaning: "to initiate conversation in a social setting",
                    culturalSignificance: "Commonly used in Western cultures"
                ),
                Idiom(
                    phrase: "beat around the bush",
                    meaning: "to avoid talking about something directly"
                )
            ],
            formalityLevel: .formal,
            recommendations: [
                "Consider using a more casual tone for better rapport.",
                "This message style is appropriate for professional contexts."
            ]
        ),
        onDismiss: {}
    )
}

