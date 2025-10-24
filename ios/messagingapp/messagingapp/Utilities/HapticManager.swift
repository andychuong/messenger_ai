//
//  HapticManager.swift
//  messagingapp
//
//  Phase 12: Polish & UX Improvements
//  Manages haptic feedback throughout the app
//

import UIKit

/// Manager for haptic feedback
class HapticManager {
    /// Shared singleton instance
    static let shared = HapticManager()
    
    /// Impact feedback generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    /// Selection feedback generator
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    /// Notification feedback generator
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators for better performance
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Haptic Methods
    
    /// Play light impact (for button taps, minor actions)
    func light() {
        guard SettingsService.shared.settings.hapticsEnabled else { return }
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Play medium impact (for important actions)
    func medium() {
        guard SettingsService.shared.settings.hapticsEnabled else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Play heavy impact (for significant actions)
    func heavy() {
        guard SettingsService.shared.settings.hapticsEnabled else { return }
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }
    
    /// Play selection feedback (for picker/toggle changes)
    func selection() {
        guard SettingsService.shared.settings.hapticsEnabled else { return }
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }
    
    /// Play success notification
    func success() {
        guard SettingsService.shared.settings.hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }
    
    /// Play warning notification
    func warning() {
        guard SettingsService.shared.settings.hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
    }
    
    /// Play error notification
    func error() {
        guard SettingsService.shared.settings.hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }
    
    // MARK: - Contextual Haptics
    
    /// Haptic for sending a message
    func messageSent() {
        medium()
    }
    
    /// Haptic for receiving a message
    func messageReceived() {
        light()
    }
    
    /// Haptic for adding a reaction
    func reactionAdded() {
        light()
    }
    
    /// Haptic for call actions
    func callAction() {
        heavy()
    }
    
    /// Haptic for button tap
    func buttonTap() {
        light()
    }
    
    /// Haptic for toggle change
    func toggleChanged() {
        selection()
    }
    
    /// Haptic for navigation
    func navigation() {
        light()
    }
}

