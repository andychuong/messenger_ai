//
//  DatesTabView.swift
//  messagingapp
//
//  Tab view for displaying extracted dates
//

import SwiftUI

struct DatesTabView: View {
    @ObservedObject var viewModel: DataExtractionViewModel
    
    var body: some View {
        Group {
            if viewModel.dates.isEmpty {
                DataExtractionEmptyView(
                    icon: "calendar.circle",
                    title: "No Dates Found",
                    message: "Important dates and deadlines will appear here when detected in your conversation."
                )
            } else {
                List {
                    ForEach(viewModel.dates) { date in
                        DateRow(date: date)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Date Row

struct DateRow: View {
    let date: ExtractedDate
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: date.type.icon)
                .foregroundColor(typeColor)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(formattedDate)
                        .font(.headline)
                    
                    Spacer()
                    
                    ConfidenceBadge(confidence: date.confidence)
                }
                
                Text(date.context)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                TypeBadge(type: date.type)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        guard let dateObj = date.dateObject else { return date.date }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dateObj)
    }
    
    private var typeColor: Color {
        switch date.type {
        case .deadline:
            return .red
        case .meeting:
            return .blue
        case .reminder:
            return .orange
        case .event:
            return .green
        case .reference:
            return .gray
        }
    }
}

// MARK: - Type Badge

struct TypeBadge: View {
    let type: ExtractedDate.DateType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption2)
            Text(type.rawValue.capitalized)
                .font(.caption)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch type {
        case .deadline:
            return .red.opacity(0.2)
        case .meeting:
            return .blue.opacity(0.2)
        case .reminder:
            return .orange.opacity(0.2)
        case .event:
            return .green.opacity(0.2)
        case .reference:
            return .gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch type {
        case .deadline:
            return .red
        case .meeting:
            return .blue
        case .reminder:
            return .orange
        case .event:
            return .green
        case .reference:
            return .gray
        }
    }
}

