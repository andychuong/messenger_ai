//
//  messagingappApp.swift
//  messagingapp
//
//  Created by Andy Chuong on 10/20/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct messagingappApp: App {
    
    // Auth service (shared across app)
    @StateObject private var authService = AuthService()
    
    // Initialize Firebase
    init() {
        FirebaseApp.configure()
        print("✅ Firebase configured!")
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
            // Show login or main app based on auth state
            if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(authService)
            } else {
                LoginView(authService: authService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
