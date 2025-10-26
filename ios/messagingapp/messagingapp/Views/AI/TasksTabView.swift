//
//  TasksTabView.swift
//  messagingapp
//
//  Tab view for displaying extracted tasks
//

import SwiftUI

struct TasksTabView: View {
    @ObservedObject var viewModel: DataExtractionViewModel
    @State private var selectedTask: ExtractedTask?
    
    var body: some View {
        Group {
            if viewModel.tasks.isEmpty {
                DataExtractionEmptyView(
                    icon: "checklist",
                    title: "No Tasks Found",
                    message: "Tasks and action items will appear here when detected in your conversation."
                )
            } else {
                List {
                    ForEach(viewModel.tasks) { task in
                        TaskRow(task: task)
                            .onTapGesture {
                                selectedTask = task
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: ExtractedTask
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(task.task)
                    .font(.body)
                
                HStack {
                    PriorityBadge(priority: task.priority)
                    
                    if let assignee = task.assignee {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.caption)
                            Text(assignee)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let deadline = task.deadline {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption)
                            Text(formattedDeadline(deadline))
                                .font(.caption)
                        }
                        .foregroundColor(isOverdue(deadline) ? .red : .secondary)
                    }
                }
                
                HStack {
                    StatusBadge(status: task.status)
                    Spacer()
                    ConfidenceBadge(confidence: task.confidence)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch task.status {
        case .completed:
            return "checkmark.circle.fill"
        case .inProgress:
            return "circle.lefthalf.filled"
        case .pending:
            return "circle"
        }
    }
    
    private var statusColor: Color {
        switch task.status {
        case .completed:
            return .green
        case .inProgress:
            return .blue
        case .pending:
            return .gray
        }
    }
    
    private func formattedDeadline(_ deadline: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: deadline) else { return deadline }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
    
    private func isOverdue(_ deadline: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: deadline) else { return false }
        return date < Date()
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: ExtractedTask.TaskPriority
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.caption2)
            Text(priority.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch priority {
        case .high:
            return .red.opacity(0.2)
        case .medium:
            return .orange.opacity(0.2)
        case .low:
            return .blue.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ExtractedTask.TaskStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.secondary)
            .cornerRadius(6)
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    let task: ExtractedTask
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text(task.task)
                        .font(.body)
                }
                
                Section {
                    HStack {
                        Image(systemName: "flag.fill")
                        Text("Priority")
                        Spacer()
                        PriorityBadge(priority: task.priority)
                    }
                    
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                        Text("Status")
                        Spacer()
                        StatusBadge(status: task.status)
                    }
                    
                    if let assignee = task.assignee {
                        DataDetailRow(icon: "person.circle", label: "Assignee", value: assignee)
                    }
                    
                    if let deadline = task.deadline {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Deadline")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formattedDeadline)
                                .fontWeight(.medium)
                                .foregroundColor(isOverdue ? .red : .primary)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Confidence")
                        Spacer()
                        ConfidenceBadge(confidence: task.confidence)
                    }
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var formattedDeadline: String {
        guard let deadline = task.deadline else { return "" }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: deadline) else { return deadline }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .long
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
    
    private var isOverdue: Bool {
        guard let deadline = task.deadline else { return false }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: deadline) else { return false }
        return date < Date()
    }
}

