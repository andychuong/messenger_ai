//
//  AIAssistantView.swift
//  messagingapp
//
//  Chat interface for AI Assistant
//

import SwiftUI

struct AIAssistantView: View {
    @StateObject private var viewModel = AIAssistantViewModel()
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message if no conversation
                            if viewModel.messages.isEmpty {
                                welcomeView
                            }
                            
                            // Messages
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Loading indicator
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Thinking...")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        scrollProxy = proxy
                        // Scroll to bottom on initial load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let lastMessage = viewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.messages.count) {
                        // Scroll to bottom when new message arrives
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area
                VStack(spacing: 12) {
                    // Quick actions (show when input is empty)
                    if viewModel.inputText.isEmpty && !viewModel.isLoading {
                        quickActionsView
                    }
                    
                    // Input field
                    HStack(spacing: 12) {
                        TextField("Ask me anything...", text: $viewModel.inputText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...5)
                            .disabled(viewModel.isLoading)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                // Send on Enter key
                                if !viewModel.inputText.isEmpty && !viewModel.isLoading {
                                    isTextFieldFocused = false
                                    Task {
                                        await viewModel.sendMessage()
                                    }
                                }
                            }
                        
                        Button {
                            isTextFieldFocused = false
                            Task {
                                await viewModel.sendMessage()
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(viewModel.inputText.isEmpty ? .gray : .blue)
                        }
                        .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.clearHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("AI Assistant")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("I can help you with:")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "doc.text.magnifyingglass", text: "Summarize conversations")
                FeatureRow(icon: "checklist", text: "Find your action items")
                FeatureRow(icon: "magnifyingglass", text: "Search message history")
                FeatureRow(icon: "lightbulb", text: "Track decisions")
                FeatureRow(icon: "exclamationmark.triangle", text: "Show priority messages")
            }
            .padding()
            
            Text("Try one of the quick actions below or ask me a question!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.quickActions) { action in
                    QuickActionButton(action: action) {
                        Task {
                            await viewModel.sendQuickAction(action)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIConversationMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == "user" ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.title2)
                
                Text(action.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 80, height: 80)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Preview

struct AIAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        AIAssistantView()
    }
}

