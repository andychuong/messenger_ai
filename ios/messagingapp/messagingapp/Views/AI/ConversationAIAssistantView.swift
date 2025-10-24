//
//  ConversationAIAssistantView.swift
//  messagingapp
//
//  AI Assistant scoped to a specific conversation
//

import SwiftUI

struct ConversationAIAssistantView: View {
    let conversationId: String
    @StateObject private var viewModel = AIAssistantViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isTextFieldFocused: Bool
    
    // Conversation-specific quick actions
    let conversationQuickActions = [
        QuickAction(title: "Summarize", icon: "doc.text.magnifyingglass", query: "Summarize this conversation"),
        QuickAction(title: "Action Items", icon: "checklist", query: "What action items are in this conversation?"),
        QuickAction(title: "Decisions", icon: "lightbulb", query: "What decisions were made in this conversation?"),
        QuickAction(title: "Key Points", icon: "list.bullet", query: "What are the key points from this conversation?"),
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            if viewModel.messages.isEmpty {
                                conversationWelcomeView
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
                    // Quick actions
                    if viewModel.inputText.isEmpty && !viewModel.isLoading {
                        conversationQuickActionsView
                    }
                    
                    // Input field
                    HStack(spacing: 12) {
                        TextField("Ask about this conversation...", text: $viewModel.inputText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...5)
                            .disabled(viewModel.isLoading)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                // Send on Enter key
                                if !viewModel.inputText.isEmpty && !viewModel.isLoading {
                                    isTextFieldFocused = false
                                    Task {
                                        await viewModel.sendMessage(conversationId: conversationId)
                                    }
                                }
                            }
                        
                        Button {
                            isTextFieldFocused = false
                            Task {
                                await viewModel.sendMessage(conversationId: conversationId)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
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
            .onAppear {
                // Set conversation context
                viewModel.setConversationContext(conversationId)
            }
        }
    }
    
    // MARK: - Conversation Welcome View
    
    private var conversationWelcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.purple)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Conversation Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Ask me anything about this conversation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text("Try a quick action below or ask a specific question!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Conversation Quick Actions
    
    private var conversationQuickActionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(conversationQuickActions) { action in
                    QuickActionButton(action: action) {
                        Task {
                            await viewModel.sendMessage(action.query, conversationId: conversationId)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Preview

struct ConversationAIAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationAIAssistantView(conversationId: "preview_conversation")
    }
}

