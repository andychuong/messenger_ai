//
//  DecisionsTabView.swift
//  messagingapp
//
//  Tab view for displaying extracted decisions
//

import SwiftUI

struct DecisionsTabView: View {
    @ObservedObject var viewModel: DataExtractionViewModel
    
    var body: some View {
        Group {
            if viewModel.decisions.isEmpty {
                DataExtractionEmptyView(
                    icon: "checkerboard.shield",
                    title: "No Decisions Found",
                    message: "Important decisions and agreements will appear here when detected in your conversation."
                )
            } else {
                List {
                    ForEach(viewModel.decisions) { decision in
                        DecisionRow(decision: decision)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Decision Row

struct DecisionRow: View {
    let decision: ExtractedDecision
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "checkerboard.shield")
                    .foregroundColor(.purple)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(decision.decision)
                            .font(.headline)
                        
                        Spacer()
                        
                        ConfidenceBadge(confidence: decision.confidence)
                    }
                    
                    Text(decision.context)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(formattedDate)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        if !decision.participants.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.caption)
                                Text("\(decision.participants.count) participants")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if !decision.participants.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Participants:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(decision.participants, id: \.self) { participant in
                            Text(participant)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.leading, 36)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        guard let dateObj = decision.dateObject else { return decision.date }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateObj)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

