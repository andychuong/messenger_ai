//
//  SettingsView.swift
//  messagingapp
//
//  Phase 12: Polish & UX Improvements
//  Main settings screen
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false
    
    var body: some View {
        List {
            // Appearance Section
            appearanceSection
            
            // Translation Section
            translationSection
            
            // Phase 15: Enhanced Translation Features
            enhancedTranslationSection
            
            // Feedback Section
            feedbackSection
            
            // Animations Section
            animationsSection
            
            // Privacy Section (Future)
            // privacySection
            
            // About Section
            aboutSection
            
            // Reset Section
            resetSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset Settings", isPresented: $showResetConfirmation) {
            Button("Reset to Defaults", role: .destructive) {
                withAnimation {
                    settingsService.resetToDefaults()
                    HapticManager.shared.success()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to reset all settings to their default values?")
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $settingsService.settings.appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .onChange(of: settingsService.settings.appearanceMode) { _, _ in
                HapticManager.shared.selection()
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Choose how the app looks. System follows your device's appearance setting.")
        }
    }
    
    // MARK: - Translation Section
    
    private var translationSection: some View {
        Section {
            NavigationLink {
                LanguageSelectionView(selectedLanguage: $settingsService.settings.preferredLanguage)
            } label: {
                HStack {
                    Label("Preferred Language", systemImage: "globe")
                    Spacer()
                    if let languageName = settingsService.settings.preferredLanguage {
                        Text(languageName)
                            .foregroundColor(.secondary)
                    } else {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Translation")
        } footer: {
            Text("Set your preferred language for auto-translation of messages. You can enable auto-translation per conversation in the chat view.")
        }
    }
    
    // MARK: - Phase 15: Enhanced Translation Section
    
    private var enhancedTranslationSection: some View {
        Section {
            Toggle(isOn: $settingsService.settings.culturalContextEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Cultural Context", systemImage: "info.circle")
                    Text("Show cultural notes and idioms for translated messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: settingsService.settings.culturalContextEnabled) { _, newValue in
                HapticManager.shared.selection()
                // Update UserDefaults for services
                UserDefaults.standard.set(newValue, forKey: "culturalContextEnabled")
            }
            
            Toggle(isOn: $settingsService.settings.slangAnalysisEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Slang Detection", systemImage: "sparkles")
                    Text("Detect and explain slang, idioms, and colloquial expressions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: settingsService.settings.slangAnalysisEnabled) { _, newValue in
                HapticManager.shared.selection()
                // Update UserDefaults for services
                UserDefaults.standard.set(newValue, forKey: "slangAnalysisEnabled")
            }
            
            Toggle(isOn: $settingsService.settings.formalityAdjustmentEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Formality Adjustment", systemImage: "text.alignleft")
                    Text("Adjust the formality level of your messages before sending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: settingsService.settings.formalityAdjustmentEnabled) { _, newValue in
                HapticManager.shared.selection()
                // Update UserDefaults for services
                UserDefaults.standard.set(newValue, forKey: "formalityAdjustmentEnabled")
            }
        } header: {
            Text("AI-Enhanced Translation")
        } footer: {
            Text("Advanced AI features to help you communicate more effectively across cultures and languages. These features require an active internet connection.")
        }
    }
    
    // MARK: - Feedback Section
    
    private var feedbackSection: some View {
        Section {
            Toggle(isOn: $settingsService.settings.hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "waveform")
            }
            .onChange(of: settingsService.settings.hapticsEnabled) { _, newValue in
                if newValue {
                    HapticManager.shared.success()
                }
            }
            
            Toggle(isOn: $settingsService.settings.soundEffectsEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.2.fill")
            }
            .onChange(of: settingsService.settings.soundEffectsEnabled) { _, newValue in
                if newValue {
                    SoundManager.shared.notification()
                }
            }
        } header: {
            Text("Feedback")
        } footer: {
            Text("Control haptic and audio feedback when you interact with the app.")
        }
    }
    
    // MARK: - Animations Section
    
    private var animationsSection: some View {
        Section {
            Toggle(isOn: $settingsService.settings.animationsEnabled) {
                Label("Animations", systemImage: "sparkles")
            }
            .onChange(of: settingsService.settings.animationsEnabled) { _, _ in
                HapticManager.shared.selection()
            }
            
            Toggle(isOn: $settingsService.settings.reduceMotion) {
                Label("Reduce Motion", systemImage: "figure.walk")
            }
            .onChange(of: settingsService.settings.reduceMotion) { _, _ in
                HapticManager.shared.selection()
            }
            
            if settingsService.systemReduceMotionEnabled {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("System Reduce Motion is enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Animations")
        } footer: {
            Text("Control animation behavior. Reduce Motion limits motion effects for better accessibility.")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Reset All Settings")
                    Spacer()
                }
            }
        } footer: {
            Text("Reset all settings to their default values. This cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

