//
//  SoundManager.swift
//  messagingapp
//
//  Phase 12: Polish & UX Improvements
//  Manages sound effects throughout the app
//

import AVFoundation

/// Manager for sound effects
class SoundManager {
    /// Shared singleton instance
    static let shared = SoundManager()
    
    /// Audio players for different sounds
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Sound Types
    
    enum SoundType: String {
        case messageSent = "message_sent"
        case messageReceived = "message_received"
        case callRinging = "call_ringing"
        case callConnected = "call_connected"
        case callEnded = "call_ended"
        case notification = "notification"
        case buttonTap = "button_tap"
        case whoosh = "whoosh"
        
        var systemSoundID: SystemSoundID {
            // Using system sounds for now (no need for audio files)
            switch self {
            case .messageSent:
                return 1004 // SMS sent
            case .messageReceived:
                return 1003 // SMS received
            case .callRinging:
                return 1005 // Voicemail
            case .callConnected:
                return 1113 // Begin recording
            case .callEnded:
                return 1114 // End recording
            case .notification:
                return 1007 // Tink
            case .buttonTap:
                return 1104 // Keyboard tap
            case .whoosh:
                return 1018 // Anticipate
            }
        }
    }
    
    // MARK: - Audio Session Setup
    
    /// Setup audio session
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("🔊 SoundManager: Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Play Sounds
    
    /// Play a system sound
    func playSound(_ soundType: SoundType) {
        guard SettingsService.shared.settings.soundEffectsEnabled else { return }
        
        // Play system sound
        AudioServicesPlaySystemSound(soundType.systemSoundID)
    }
    
    /// Play sound with vibration
    func playSoundWithVibration(_ soundType: SoundType) {
        guard SettingsService.shared.settings.soundEffectsEnabled else { return }
        
        // Play system sound with vibration
        AudioServicesPlayAlertSound(soundType.systemSoundID)
    }
    
    // MARK: - Contextual Sounds
    
    /// Play message sent sound
    func messageSent() {
        playSound(.messageSent)
    }
    
    /// Play message received sound
    func messageReceived() {
        playSound(.messageReceived)
    }
    
    /// Play call ringing sound
    func callRinging() {
        playSound(.callRinging)
    }
    
    /// Play call connected sound
    func callConnected() {
        playSound(.callConnected)
    }
    
    /// Play call ended sound
    func callEnded() {
        playSound(.callEnded)
    }
    
    /// Play notification sound
    func notification() {
        playSound(.notification)
    }
    
    /// Play button tap sound
    func buttonTap() {
        playSound(.buttonTap)
    }
    
    /// Play whoosh sound (for animations, transitions)
    func whoosh() {
        playSound(.whoosh)
    }
    
    // MARK: - Volume Control
    
    /// Set volume (0.0 to 1.0)
    func setVolume(_ volume: Float) {
        // System sound volume is controlled by device volume
        // This would be implemented for custom audio files
    }
}

