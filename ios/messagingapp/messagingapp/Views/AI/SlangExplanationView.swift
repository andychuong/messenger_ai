//
//  SlangExplanationView.swift
//  messagingapp
//
//  Phase 15.3: Slang Explanation View
//  Popover view for explaining slang and idioms
//

import SwiftUI

/// Popover view for displaying slang and idiom explanations
struct SlangExplanationView: View {
    
    let expression: DetectedExpression
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            header
            
            Divider()
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Explanation
                    explanationSection
                    
                    // Literal meaning (if different)
                    if let literalMeaning = expression.literalMeaning {
                        literalMeaningSection(literalMeaning)
                    }
                    
                    // Usage
                    usageSection
                    
                    // Origin (if available)
                    if let origin = expression.origin {
                        originSection(origin)
                    }
                    
                    // Alternatives (if available)
                    if let alternatives = expression.alternatives, !alternatives.isEmpty {
                        alternativesSection(alternatives)
                    }
                    
                    // Regional info (if available)
                    if expression.isRegional == true, let region = expression.region {
                        regionalSection(region)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: 400, maxHeight: 600)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10)
    }
    
    // MARK: - Sections
    
    private var header: some View {
        HStack(spacing: 12) {
            // Type icon
            Text(expression.type.icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expression.phrase)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(expression.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Meaning", icon: "text.bubble.fill", color: .blue)
            
            Text(expression.explanation)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func literalMeaningSection(_ literal: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Literal Translation", icon: "character.textbox", color: .green)
            
            Text(literal)
                .font(.body)
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "How to Use", icon: "sparkles", color: .orange)
            
            Text(expression.usage)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func originSection(_ origin: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Origin", icon: "book.closed.fill", color: .purple)
            
            Text(origin)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
    
    private func alternativesSection(_ alternatives: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Alternatives", icon: "arrow.triangle.2.circlepath", color: .cyan)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(alternatives, id: \.self) { alternative in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 6, height: 6)
                        
                        Text(alternative)
                            .font(.callout)
                    }
                }
            }
        }
    }
    
    private func regionalSection(_ region: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "map.fill")
                .foregroundColor(.red)
            
            Text("Regional: \(region)")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Views

struct SectionTitle: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

/// Compact inline view for showing slang within a message
struct InlineSlangIndicator: View {
    let expression: DetectedExpression
    @State private var showExplanation = false
    
    var body: some View {
        Button {
            showExplanation = true
        } label: {
            Text(expression.phrase)
                .underline(pattern: .dot, color: .blue)
                .foregroundColor(.primary)
        }
        .popover(isPresented: $showExplanation) {
            SlangExplanationView(expression: expression)
        }
    }
}

/// Badge showing slang count
struct SlangBadge: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2)
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue)
        .cornerRadius(12)
    }
}

/// Sheet view showing all detected expressions in a message
struct SlangAnalysisSheet: View {
    let analysis: SlangAnalysis
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if !analysis.detectedExpressions.isEmpty {
                        ForEach(analysis.detectedExpressions) { expression in
                            ExpressionCard(expression: expression)
                        }
                    } else {
                        EmptyStateView(
                            icon: "checkmark.circle.fill",
                            title: "No Slang Detected",
                            message: "This message doesn't contain slang or idioms that need explanation."
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Slang & Idioms")
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
}

struct ExpressionCard: View {
    let expression: DetectedExpression
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - always visible
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(expression.type.icon)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expression.phrase)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(expression.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            if !isExpanded {
                // Collapsed - show brief explanation
                Text(expression.explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                // Expanded - show full details
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    // Explanation
                    DetailRow(
                        icon: "text.bubble.fill",
                        title: "Meaning",
                        content: expression.explanation
                    )
                    
                    // Literal meaning
                    if let literal = expression.literalMeaning {
                        DetailRow(
                            icon: "character.textbox",
                            title: "Literal",
                            content: literal
                        )
                    }
                    
                    // Usage
                    DetailRow(
                        icon: "sparkles",
                        title: "Usage",
                        content: expression.usage
                    )
                    
                    // Alternatives
                    if let alternatives = expression.alternatives, !alternatives.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                Text("Alternatives")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            ForEach(alternatives, id: \.self) { alt in
                                Text("• \(alt)")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Region
                    if expression.isRegional == true, let region = expression.region {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("Regional: \(region)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text(content)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Single Expression") {
    SlangExplanationView(
        expression: DetectedExpression(
            phrase: "piece of cake",
            type: .idiom,
            explanation: "Something that is very easy to do",
            literalMeaning: "A slice of cake",
            origin: "Originated in the 1930s from the American custom of giving cakes as prizes",
            usage: "Use this phrase to describe tasks or situations that are simple or effortless",
            alternatives: ["easy", "simple", "a breeze", "no sweat"],
            isRegional: false
        )
    )
}

#Preview("Analysis Sheet") {
    SlangAnalysisSheet(
        analysis: SlangAnalysis(
            detectedExpressions: [
                DetectedExpression(
                    phrase: "break the ice",
                    type: .idiom,
                    explanation: "To initiate conversation in a social setting",
                    usage: "Used when starting conversations with strangers"
                ),
                DetectedExpression(
                    phrase: "beat around the bush",
                    type: .idiom,
                    explanation: "To avoid talking about something directly",
                    usage: "Often used when someone is being indirect"
                )
            ],
            hasSlang: true
        ),
        onDismiss: {}
    )
}

