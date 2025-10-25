//
//  SettingsService.swift
//  messagingapp
//
//  Phase 12: Polish & UX Improvements
//  Manages user preferences and settings
//

import Foundation
import SwiftUI
import Combine

/// Service for managing user settings and preferences
@MainActor
class SettingsService: ObservableObject {
    /// Shared singleton instance
    static let shared = SettingsService()
    
    /// User settings
    @Published var settings: UserSettings {
        didSet {
            let oldValue = Self.loadSettings()
            saveSettings()
            applySettings()
            
            // Sync language preference to Firestore if changed
            if oldValue.preferredLanguage != settings.preferredLanguage {
                Task {
                    if let authService = AuthService.shared {
                        try? await authService.updatePreferredLanguage(settings.preferredLanguage)
                    }
                }
            }
        }
    }
    
    /// UserDefaults key for settings
    private let settingsKey = "com.messagingapp.userSettings"
    
    private init() {
        self.settings = Self.loadSettings()
        applySettings()
    }
    
    // MARK: - Settings Management
    
    /// Load settings from UserDefaults
    private static func loadSettings() -> UserSettings {
        guard let data = UserDefaults.standard.data(forKey: "com.messagingapp.userSettings"),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            print("⚙️ Settings: Loading default settings")
            return .default
        }
        
        print("⚙️ Settings: Loaded saved settings")
        return settings
    }
    
    /// Save settings to UserDefaults
    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else {
            print("⚙️ Settings: Failed to encode settings")
            return
        }
        
        UserDefaults.standard.set(data, forKey: settingsKey)
        print("⚙️ Settings: Saved settings")
    }
    
    /// Apply current settings to the app
    private func applySettings() {
        // Settings are applied reactively through SwiftUI environment
        // Additional system-level settings can be applied here
        print("⚙️ Settings: Applied settings - Haptics: \(settings.hapticsEnabled), Sounds: \(settings.soundEffectsEnabled), Animations: \(settings.animationsEnabled)")
    }
    
    // MARK: - Convenience Methods
    
    /// Update appearance mode
    func updateAppearanceMode(_ mode: AppearanceMode) {
        settings.appearanceMode = mode
    }
    
    /// Toggle haptics
    func toggleHaptics() {
        settings.hapticsEnabled.toggle()
    }
    
    /// Toggle sound effects
    func toggleSoundEffects() {
        settings.soundEffectsEnabled.toggle()
    }
    
    /// Toggle animations
    func toggleAnimations() {
        settings.animationsEnabled.toggle()
    }
    
    /// Toggle reduce motion
    func toggleReduceMotion() {
        settings.reduceMotion.toggle()
    }
    
    /// Update preferred language
    func updatePreferredLanguage(_ language: String?) {
        settings.preferredLanguage = language
        
        // Sync to Firestore
        Task {
            if let authService = AuthService.shared {
                try? await authService.updatePreferredLanguage(language)
            }
        }
    }
    
    /// Reset to default settings
    func resetToDefaults() {
        settings = .default
    }
    
    // MARK: - System Settings Integration
    
    /// Check if system has reduced motion enabled
    var systemReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    /// Should animations be disabled (respects both user setting and system preference)
    var shouldDisableAnimations: Bool {
        !settings.animationsEnabled || settings.reduceMotion || systemReduceMotionEnabled
    }
}

