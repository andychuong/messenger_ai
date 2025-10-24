//
//  MainTabView.swift
//  messagingapp
//
//  Main tab navigation after authentication
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @StateObject private var toastManager = ToastManager()
    @StateObject private var messageListener = MessageToastListener()
    @StateObject private var callViewModel = CallViewModel()
    @State private var selectedTab = 0
    @State private var navigationToConversationId: String?
    
    var body: some View {
        ZStack(alignment: .top) {
        TabView(selection: $selectedTab) {
            // Conversations tab
            ConversationListView(navigationToConversationId: $navigationToConversationId)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(0)
                .environmentObject(toastManager)
                .environmentObject(callViewModel)
            
            // Friends tab
            FriendsListView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(1)
                .environmentObject(toastManager)
                .environmentObject(callViewModel)
            
            // AI Assistant tab
            AIAssistantView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(2)
                .environmentObject(callViewModel)
            
            // Profile tab
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(3)
            .environmentObject(callViewModel)
        }
        .toastContainer(toastManager: toastManager) { conversationId in
            // Switch to Messages tab and navigate to conversation
            selectedTab = 0
            navigationToConversationId = conversationId
        }
        .onAppear {
            messageListener.startListening(toastManager: toastManager)
        }
        .onDisappear {
            messageListener.stopListening()
        }
        
        // Global incoming call overlay
        if callViewModel.showIncomingCall, let call = callViewModel.incomingCall {
            IncomingCallView(
                call: call,
                onAnswer: {
                    callViewModel.answerCall()
                },
                onDecline: {
                    callViewModel.declineCall()
                }
            )
            .transition(.move(edge: .bottom))
            .zIndex(100)
        }
        
        // Global active call overlay
        if callViewModel.showActiveCall, let call = callViewModel.currentCall {
            ActiveCallView(call: call)
                .transition(.move(edge: .bottom))
                .zIndex(101)
        }
        
        // Phase 11: Offline banner
        VStack {
            OfflineBanner()
                .environmentObject(networkMonitor)
            Spacer()
        }
        .zIndex(102)
        .allowsHitTesting(false)
        }
    }
}

// MARK: - Placeholder Views (to be replaced in future phases)

struct ConversationsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Conversations")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your messages will appear here")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Messages")
    }
}

struct FriendsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Friends")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Add friends to start messaging")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Friends")
    }
}

// AI Placeholder removed - now using AIAssistantView

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        List {
            // User info section
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text(authService.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authService.currentUser?.displayName ?? "User")
                            .font(.headline)
                        
                        Text(authService.currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Settings section
            Section("Settings") {
                NavigationLink {
                    Text("Edit Profile - Coming Soon")
                } label: {
                    Label("Edit Profile", systemImage: "person.crop.circle")
                }
                
                NavigationLink {
                    Text("Notifications - Coming Soon")
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
                
                NavigationLink {
                    Text("Privacy - Coming Soon")
                } label: {
                    Label("Privacy & Security", systemImage: "lock")
                }
            }
            
            // Logout section
            Section {
                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profile")
        .confirmationDialog("Logout", isPresented: $showLogoutConfirmation) {
            Button("Logout", role: .destructive) {
                Task {
                    try? await authService.logout()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}

