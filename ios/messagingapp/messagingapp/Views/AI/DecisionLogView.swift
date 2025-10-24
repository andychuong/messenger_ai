//
//  DecisionLogView.swift
//  messagingapp
//
//  Phase 8: Decision Tracking UI
//  Displays AI-detected decisions from conversations
//

import SwiftUI
import Combine

struct DecisionLogView: View {
    @StateObject private var viewModel = DecisionLogViewModel()
    @State private var searchText = ""
    @State private var selectedConversationId: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredDecisions.isEmpty {
                    emptyStateView
                } else {
                    decisionsList
                }
            }
            .navigationTitle("Decision Log")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search decisions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("All Conversations") {
                            selectedConversationId = nil
                            viewModel.loadAllDecisions()
                        }
                        
                        // TODO: Add conversation filter options
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .onAppear {
                viewModel.loadAllDecisions()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private var filteredDecisions: [Decision] {
        if searchText.isEmpty {
            return viewModel.decisions
        } else {
            return viewModel.decisions.filter {
                $0.decision.localizedCaseInsensitiveContains(searchText) ||
                ($0.rationale?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.outcome?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private var decisionsList: some View {
        List {
            ForEach(filteredDecisions) { decision in
                DecisionCard(decision: decision)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.loadAllDecisions()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Decisions Logged")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("AI will detect and log important decisions from your conversations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Decision Card
struct DecisionCard: View {
    let decision: Decision
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Decision")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(decision.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Decision Text
            Text(decision.decision)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(isExpanded ? nil : 3)
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let rationale = decision.rationale {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Rationale", systemImage: "bubble.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(rationale)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let outcome = decision.outcome {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Outcome", systemImage: "arrow.right.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(outcome)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: { /* Navigate to conversation */ }) {
                            Label("View in Chat", systemImage: "bubble.left.and.bubble.right")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { /* Share decision */ }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - ViewModel
@MainActor
class DecisionLogViewModel: ObservableObject {
    @Published var decisions: [Decision] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let ragService = RAGService.shared
    
    func loadAllDecisions() {
        // For MVP, this would load from a local cache or fetch from multiple conversations
        // TODO: Implement a Cloud Function to get all user's decisions across conversations
        isLoading = true
        
        Task {
            // Placeholder: In production, you'd fetch from a user-wide decisions collection
            // or aggregate from all accessible conversations
            self.isLoading = false
        }
    }
    
    func loadDecisions(for conversationId: String) {
        isLoading = true
        
        Task {
            do {
                let decisions = try await ragService.getConversationDecisions(
                    conversationId: conversationId,
                    limit: 50
                )
                self.decisions = decisions
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
            self.isLoading = false
        }
    }
}

#Preview {
    DecisionLogView()
}

