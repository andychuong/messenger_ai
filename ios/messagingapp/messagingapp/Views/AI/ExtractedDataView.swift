//
//  ExtractedDataView.swift
//  messagingapp
//
//  Main view for displaying extracted structured data
//

import SwiftUI

struct ExtractedDataView: View {
    @StateObject private var viewModel: DataExtractionViewModel
    @Environment(\.dismiss) private var dismiss
    
    let messages: [Message]
    
    init(conversationId: String, messages: [Message]) {
        self.messages = messages
        _viewModel = StateObject(wrappedValue: DataExtractionViewModel(conversationId: conversationId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Extracting data...")
                } else if let error = viewModel.error {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.extractData(from: messages)
                        }
                    }
                } else if !viewModel.hasData {
                    EmptyDataView {
                        Task {
                            await viewModel.extractData(from: messages)
                        }
                    }
                } else {
                    TabView(selection: $viewModel.selectedTab) {
                        EventsTabView(viewModel: viewModel)
                            .tabItem {
                                Label("Events", systemImage: "calendar")
                            }
                            .badge(viewModel.eventsCount)
                            .tag(0)
                        
                        TasksTabView(viewModel: viewModel)
                            .tabItem {
                                Label("Tasks", systemImage: "checklist")
                            }
                            .badge(viewModel.tasksCount)
                            .tag(1)
                        
                        DatesTabView(viewModel: viewModel)
                            .tabItem {
                                Label("Dates", systemImage: "calendar.circle")
                            }
                            .badge(viewModel.datesCount)
                            .tag(2)
                        
                        LocationsTabView(viewModel: viewModel)
                            .tabItem {
                                Label("Places", systemImage: "map")
                            }
                            .badge(viewModel.locationsCount)
                            .tag(3)
                        
                        ContactsTabView(viewModel: viewModel)
                            .tabItem {
                                Label("Contacts", systemImage: "person.2")
                            }
                            .badge(viewModel.contactsCount)
                            .tag(4)
                        
                        DecisionsTabView(viewModel: viewModel)
                            .tabItem {
                                Label("Decisions", systemImage: "checkerboard.shield")
                            }
                            .badge(viewModel.decisionsCount)
                            .tag(5)
                    }
                }
            }
            .navigationTitle("Extracted Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await viewModel.extractData(from: messages)
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button {
                            // Export all data
                        } label: {
                            Label("Export All", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Success", isPresented: $viewModel.showExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.exportMessage)
            }
        }
        .task {
            await viewModel.loadCachedData()
            
            // If no cached data, extract
            if !viewModel.hasData {
                await viewModel.extractData(from: messages)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyDataView: View {
    let onExtract: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Data Extracted")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Extract structured data like events, tasks, and locations from your conversation.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onExtract) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Extract Data")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ExtractedDataView(
        conversationId: "preview-conversation",
        messages: []
    )
}

