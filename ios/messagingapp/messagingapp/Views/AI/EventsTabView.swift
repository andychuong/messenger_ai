//
//  EventsTabView.swift
//  messagingapp
//
//  Tab view for displaying extracted events
//

import SwiftUI

struct EventsTabView: View {
    @ObservedObject var viewModel: DataExtractionViewModel
    @State private var selectedEvent: ExtractedEvent?
    
    var body: some View {
        Group {
            if viewModel.events.isEmpty {
                DataExtractionEmptyView(
                    icon: "calendar",
                    title: "No Events Found",
                    message: "Events and meetings will appear here when detected in your conversation."
                )
            } else {
                List {
                    ForEach(viewModel.events) { event in
                        EventRow(event: event)
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event, viewModel: viewModel)
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: ExtractedEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(formattedDate)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    
                    if let time = event.time {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(time)
                                .font(.subheadline)
                            
                            if let duration = event.duration {
                                Text("(\(duration) min)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let location = event.location {
                        HStack {
                            Image(systemName: "location")
                                .font(.caption)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                ConfidenceBadge(confidence: event.confidence)
            }
            
            if !event.participants.isEmpty {
                HStack {
                    Image(systemName: "person.2")
                        .font(.caption)
                    Text(event.participants.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        guard let date = event.dateObject else { return event.date }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    let event: ExtractedEvent
    @ObservedObject var viewModel: DataExtractionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    DataDetailRow(icon: "calendar", label: "Date", value: formattedDate)
                    
                    if let time = event.time {
                        DataDetailRow(icon: "clock", label: "Time", value: time)
                    }
                    
                    if let endTime = event.endTime {
                        DataDetailRow(icon: "clock.arrow.2.circlepath", label: "End Time", value: endTime)
                    } else if let duration = event.duration {
                        DataDetailRow(icon: "hourglass", label: "Duration", value: "\(duration) minutes")
                    }
                    
                    if let location = event.location {
                        DataDetailRow(icon: "location", label: "Location", value: location)
                    }
                }
                
                if !event.participants.isEmpty {
                    Section("Participants") {
                        ForEach(event.participants, id: \.self) { participant in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                Text(participant)
                            }
                        }
                    }
                }
                
                if let description = event.description {
                    Section("Description") {
                        Text(description)
                            .font(.body)
                    }
                }
                
                Section {
                    HStack {
                        Text("Confidence")
                        Spacer()
                        ConfidenceBadge(confidence: event.confidence)
                    }
                }
                
                Section {
                    Button(action: exportToCalendar) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Add to Calendar")
                            
                            if isExporting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle(event.title)
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
    
    private var formattedDate: String {
        guard let date = event.dateObject else { return event.date }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func exportToCalendar() {
        isExporting = true
        Task {
            await viewModel.exportEvent(event)
            isExporting = false
            dismiss()
        }
    }
}

// MARK: - Empty State

struct DataExtractionEmptyView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Detail Row

struct DataDetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon)
                .font(.caption)
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.2))
        .foregroundColor(confidenceColor)
        .cornerRadius(8)
    }
    
    private var confidenceIcon: String {
        if confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if confidence >= 0.5 {
            return "exclamationmark.circle.fill"
        } else {
            return "questionmark.circle.fill"
        }
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

