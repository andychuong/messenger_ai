//
//  messagingappApp.swift
//  messagingapp
//
//  Created by Andy Chuong on 10/20/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFirestore

@main
struct messagingappApp: App {
    
    // AppDelegate for handling notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Auth service (shared across app)
    @StateObject private var authService = AuthService()
    
    // Network monitor (shared across app)
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // Initialize Firebase
    init() {
        FirebaseApp.configure()
        print("✅ Firebase configured!")
        
        // Phase 11: Enable Firestore offline persistence
        configureFirestoreOfflineSupport()
        
        // Initialize call service with user ID once authenticated
        // This will be set properly in the auth flow
    }
    
    /// Configure Firestore for offline support
    private func configureFirestoreOfflineSupport() {
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        
        // Phase 11: Enable offline persistence with persistent cache
        // Using modern cacheSettings API instead of deprecated isPersistenceEnabled
        settings.cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited)
        )
        
        db.settings = settings
        
        print("✅ Firestore offline persistence enabled with unlimited cache")
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Show loading, login, or main app based on auth state
            if authService.isLoading {
                // Show loading screen while checking auth state
                LoadingView()
            } else if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(networkMonitor)
                    .onAppear {
                        // Set current user ID for call service
                        if let userId = authService.currentUser?.id {
                            CallService.shared.currentUserId = userId
                            CallService.shared.startListening()
                        }
                    }
            } else {
                LoginView(authService: authService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
