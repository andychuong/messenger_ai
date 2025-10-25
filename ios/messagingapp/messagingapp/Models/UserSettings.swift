//
//  UserSettings.swift
//  messagingapp
//
//  Phase 12: Polish & UX Improvements
//  User preferences and settings model
//

import Foundation
import SwiftUI

/// User preferences and settings
struct UserSettings: Codable {
    // MARK: - Appearance
    var appearanceMode: AppearanceMode = .system
    
    // MARK: - Feedback
    var hapticsEnabled: Bool = true
    var soundEffectsEnabled: Bool = true
    
    // MARK: - Animations
    var animationsEnabled: Bool = true
    var reduceMotion: Bool = false
    
    // MARK: - Translation
    var preferredLanguage: String? = nil // User's preferred language for auto-translation
    
    // MARK: - Notifications (for future use)
    var notificationsEnabled: Bool = true
    var messagePreviewEnabled: Bool = true
    
    // MARK: - Privacy (for future use)
    var readReceiptsEnabled: Bool = true
    var onlineStatusVisible: Bool = true
    var typingIndicatorEnabled: Bool = true
    
    // MARK: - Default Settings
    static let `default` = UserSettings()
}

/// Appearance mode options
enum AppearanceMode: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Uses system default
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
}

