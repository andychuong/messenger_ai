//
//  ActionItemsView.swift
//  messagingapp
//
//  Phase 8: Action Items UI
//  Displays and manages AI-extracted action items
//

import SwiftUI
import FirebaseAuth
import Combine

struct ActionItemsView: View {
    @StateObject private var viewModel = ActionItemsViewModel()
    @State private var selectedFilter: ActionItem.Status = .pending
    @State private var showingExtractSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Segmented Control
                Picker("Status", selection: $selectedFilter) {
                    ForEach(ActionItem.Status.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredActionItems.isEmpty {
                    emptyStateView
                } else {
                    actionItemsList
                }
            }
            .navigationTitle("Action Items")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExtractSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingExtractSheet) {
                ExtractActionItemsSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadActionItems(status: selectedFilter)
            }
            .onChange(of: selectedFilter) {
                viewModel.loadActionItems(status: selectedFilter)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private var filteredActionItems: [ActionItem] {
        viewModel.actionItems.filter { $0.status == selectedFilter }
    }
    
    private var actionItemsList: some View {
        List {
            // Overdue section (for pending items)
            if selectedFilter == .pending {
                let overdueItems = filteredActionItems.filter { $0.isOverdue }
                if !overdueItems.isEmpty {
                    Section("Overdue") {
                        ForEach(overdueItems) { item in
                            ActionItemRow(item: item, viewModel: viewModel)
                        }
                    }
                }
                
                let dueSoonItems = filteredActionItems.filter { $0.isDueSoon }
                if !dueSoonItems.isEmpty {
                    Section("Due Soon") {
                        ForEach(dueSoonItems) { item in
                            ActionItemRow(item: item, viewModel: viewModel)
                        }
                    }
                }
            }
            
            // All items
            Section(selectedFilter == .pending ? "All Pending" : selectedFilter.displayName) {
                ForEach(filteredActionItems) { item in
                    ActionItemRow(item: item, viewModel: viewModel)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.loadActionItems(status: selectedFilter)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedFilter == .pending ? "checkmark.circle" : "list.bullet")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(emptyStateSubtext)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .pending:
            return "No Pending Action Items"
        case .completed:
            return "No Completed Items Yet"
        case .cancelled:
            return "No Cancelled Items"
        }
    }
    
    private var emptyStateSubtext: String {
        switch selectedFilter {
        case .pending:
            return "AI will extract action items from your conversations automatically"
        case .completed:
            return "Mark items as complete to see them here"
        case .cancelled:
            return "Cancelled items will appear here"
        }
    }
}

// MARK: - Action Item Row
struct ActionItemRow: View {
    let item: ActionItem
    @ObservedObject var viewModel: ActionItemsViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: toggleComplete) {
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.status == .completed ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                // Task
                Text(item.task)
                    .font(.body)
                    .strikethrough(item.status == .completed)
                    .foregroundColor(item.status == .completed ? .secondary : .primary)
                
                // Metadata
                HStack(spacing: 12) {
                    // Priority
                    Label(item.priority.rawValue.capitalized, systemImage: item.priority.icon)
                        .font(.caption)
                        .foregroundColor(Color(item.priority.color))
                    
                    // Due date
                    if let dueDate = item.dueDate {
                        Label(formatDueDate(dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(item.isOverdue ? .red : .secondary)
                    }
                    
                    // Assignee
                    if let assignee = item.assignedTo {
                        Label(assignee, systemImage: "person")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if item.status == .pending {
                Button("Complete") {
                    viewModel.completeActionItem(item)
                }
                .tint(.green)
            }
            
            Button("Delete") {
                viewModel.deleteActionItem(item)
            }
            .tint(.red)
        }
    }
    
    private func toggleComplete() {
        if item.status == .completed {
            viewModel.updateActionItemStatus(item, newStatus: .pending)
        } else {
            viewModel.completeActionItem(item)
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Extract Action Items Sheet
struct ExtractActionItemsSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ActionItemsViewModel
    @State private var selectedConversationId: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Extract action items from a conversation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                
                // TODO: Add conversation picker
                Text("Select a conversation to extract action items from")
                    .font(.headline)
                
                Spacer()
                
                Button(action: extractActionItems) {
                    if viewModel.isExtracting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Extract Action Items")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedConversationId == nil || viewModel.isExtracting)
                .padding()
            }
            .navigationTitle("Extract Action Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func extractActionItems() {
        guard let conversationId = selectedConversationId else { return }
        
        Task {
            await viewModel.extractFromConversation(conversationId: conversationId)
            dismiss()
        }
    }
}

// MARK: - ViewModel
@MainActor
class ActionItemsViewModel: ObservableObject {
    @Published var actionItems: [ActionItem] = []
    @Published var isLoading = false
    @Published var isExtracting = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let ragService = RAGService.shared
    
    func loadActionItems(status: ActionItem.Status) {
        isLoading = true
        
        Task {
            do {
                let items = try await ragService.getUserActionItems(status: status, limit: 50)
                self.actionItems = items
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
            self.isLoading = false
        }
    }
    
    func completeActionItem(_ item: ActionItem) {
        guard let itemId = item.id,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                try await ragService.updateActionItemStatus(
                    actionItemId: itemId,
                    status: .completed,
                    completedBy: userId
                )
                
                // Update local state
                if let index = actionItems.firstIndex(where: { $0.id == itemId }) {
                    actionItems.remove(at: index)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    func updateActionItemStatus(_ item: ActionItem, newStatus: ActionItem.Status) {
        guard let itemId = item.id else { return }
        
        Task {
            do {
                try await ragService.updateActionItemStatus(
                    actionItemId: itemId,
                    status: newStatus
                )
                
                // Remove from current list
                if let index = actionItems.firstIndex(where: { $0.id == itemId }) {
                    actionItems.remove(at: index)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    func deleteActionItem(_ item: ActionItem) {
        // TODO: Implement delete in RAGService
        if let index = actionItems.firstIndex(where: { $0.id == item.id }) {
            actionItems.remove(at: index)
        }
    }
    
    func extractFromConversation(conversationId: String) async {
        isExtracting = true
        
        do {
            let items = try await ragService.extractActionItemsFromConversation(
                conversationId: conversationId,
                limit: 50
            )
            
            self.actionItems.insert(contentsOf: items, at: 0)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
        
        isExtracting = false
    }
}

#Preview {
    ActionItemsView()
}

