//
//  LocationsTabView.swift
//  messagingapp
//
//  Tab view for displaying extracted locations
//

import SwiftUI

struct LocationsTabView: View {
    @ObservedObject var viewModel: DataExtractionViewModel
    @State private var selectedLocation: ExtractedLocation?
    
    var body: some View {
        Group {
            if viewModel.locations.isEmpty {
                DataExtractionEmptyView(
                    icon: "map",
                    title: "No Locations Found",
                    message: "Places and addresses will appear here when detected in your conversation."
                )
            } else {
                List {
                    ForEach(viewModel.locations) { location in
                        LocationRow(location: location)
                            .onTapGesture {
                                selectedLocation = location
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(item: $selectedLocation) { location in
            LocationDetailView(location: location, viewModel: viewModel)
        }
    }
}

// MARK: - Location Row

struct LocationRow: View {
    let location: ExtractedLocation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: location.hasCoordinates ? "mappin.circle.fill" : "mappin.circle")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(location.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    ConfidenceBadge(confidence: location.confidence)
                }
                
                if let address = location.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(location.context)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if location.hasCoordinates {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text("GPS coordinates available")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Location Detail View

struct LocationDetailView: View {
    let location: ExtractedLocation
    @ObservedObject var viewModel: DataExtractionViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Location") {
                    DataDetailRow(icon: "mappin", label: "Name", value: location.name)
                    
                    if let address = location.address {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("Address")
                                    .foregroundColor(.secondary)
                            }
                            Text(address)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let coordinates = location.coordinates {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("Coordinates")
                                    .foregroundColor(.secondary)
                            }
                            Text("\(coordinates.lat), \(coordinates.lng)")
                                .fontWeight(.medium)
                                .font(.caption)
                        }
                    }
                }
                
                Section("Context") {
                    Text(location.context)
                        .font(.body)
                }
                
                Section {
                    HStack {
                        Text("Confidence")
                        Spacer()
                        ConfidenceBadge(confidence: location.confidence)
                    }
                }
                
                Section("Actions") {
                    Button(action: {
                        viewModel.openInMaps(location)
                    }) {
                        HStack {
                            Image(systemName: "map")
                            Text("Open in Maps")
                        }
                    }
                    
                    Button(action: {
                        viewModel.getDirections(to: location)
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                            Text("Get Directions")
                        }
                    }
                    
                    if let address = location.address {
                        Button(action: {
                            UIPasteboard.general.string = address
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Address")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Location Details")
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
}

