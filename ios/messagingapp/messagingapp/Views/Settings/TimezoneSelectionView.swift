//
//  TimezoneSelectionView.swift
//  messagingapp
//
//  Phase 18: Timezone Coordination
//  View for selecting timezone
//

import SwiftUI

struct TimezoneSelectionView: View {
    @Binding var selectedTimezone: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @StateObject private var timezoneService = TimezoneService.shared
    
    var body: some View {
        List {
            if searchText.isEmpty {
                Section("Common Timezones") {
                    ForEach(timezoneService.getCommonTimezones()) { info in
                        TimezoneRow(
                            info: info,
                            isSelected: selectedTimezone == info.identifier,
                            action: {
                                selectedTimezone = info.identifier
                                dismiss()
                            }
                        )
                    }
                }
            }
            
            Section(searchText.isEmpty ? "All Timezones" : "Search Results") {
                ForEach(filteredTimezones) { info in
                    TimezoneRow(
                        info: info,
                        isSelected: selectedTimezone == info.identifier,
                        action: {
                            selectedTimezone = info.identifier
                            dismiss()
                        }
                    )
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search timezones")
        .navigationTitle("Select Timezone")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var filteredTimezones: [TimezoneInfo] {
        if searchText.isEmpty {
            return timezoneService.searchTimezones(query: "")
        } else {
            return timezoneService.searchTimezones(query: searchText)
        }
    }
}

struct TimezoneRow: View {
    let info: TimezoneInfo
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.shortName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(info.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TimezoneSelectionView(selectedTimezone: .constant("America/New_York"))
    }
}


