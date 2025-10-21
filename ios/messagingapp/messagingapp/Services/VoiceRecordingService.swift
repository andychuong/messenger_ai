//
//  VoiceRecordingService.swift
//  messagingapp
//
//  Phase 4: Rich Messaging Features
//  Audio recording, playback, and Firebase Storage upload
//

import Foundation
import AVFoundation
import FirebaseStorage
import FirebaseAuth
import Combine

@MainActor
class VoiceRecordingService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    // Recording state
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingURL: URL?
    @Published var recordingError: String?
    
    // Playback state
    @Published var isPlaying = false
    @Published var playbackProgress: TimeInterval = 0
    @Published var currentlyPlayingURL: URL?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    
    private let storage = Storage.storage()
    private let messageService = MessageService()
    
    // MARK: - Setup
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        // Clean up audio resources
        audioRecorder?.stop()
        audioPlayer?.stop()
        recordingTimer?.invalidate()
        playbackTimer?.invalidate()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            recordingError = "Failed to setup audio session"
        }
    }
    
    // MARK: - Recording
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Start recording audio
    func startRecording() {
        guard !isRecording else { return }
        
        // Check permission
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            recordingError = "Microphone permission not granted"
            return
        }
        
        // Create recording URL
        let fileName = "voice_\(UUID().uuidString).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            isRecording = true
            recordingURL = fileURL
            recordingDuration = 0
            recordingError = nil
            
            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateRecordingDuration()
                }
            }
        } catch {
            recordingError = "Failed to start recording: \(error.localizedDescription)"
            print("Recording error: \(error)")
        }
    }
    
    /// Stop recording audio
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        isRecording = false
    }
    
    /// Cancel recording and delete file
    func cancelRecording() {
        stopRecording()
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingURL = nil
        recordingDuration = 0
    }
    
    private func updateRecordingDuration() {
        if let recorder = audioRecorder, recorder.isRecording {
            recordingDuration = recorder.currentTime
        }
    }
    
    // MARK: - Playback
    
    /// Play audio from URL
    func playAudio(from url: URL) {
        // Stop current playback
        stopPlayback()
        
        do {
            // Download if remote URL
            let localURL: URL
            if url.isFileURL {
                localURL = url
            } else {
                // For remote URLs, download first (simplified - in production, cache this)
                localURL = url
            }
            
            audioPlayer = try AVAudioPlayer(contentsOf: localURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            currentlyPlayingURL = url
            playbackProgress = 0
            
            // Start playback timer
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updatePlaybackProgress()
                }
            }
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    /// Stop playback
    func stopPlayback() {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        isPlaying = false
        currentlyPlayingURL = nil
        playbackProgress = 0
    }
    
    /// Pause playback
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    /// Resume playback
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    private func updatePlaybackProgress() {
        if let player = audioPlayer, player.isPlaying {
            playbackProgress = player.currentTime
        }
    }
    
    /// Get audio duration from URL
    func getAudioDuration(from url: URL) -> TimeInterval? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            return nil
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stopPlayback()
        }
    }
    
    // MARK: - Upload to Firebase Storage
    
    /// Upload voice recording to Firebase Storage
    func uploadVoiceRecording(_ fileURL: URL, conversationId: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw VoiceRecordingError.notAuthenticated
        }
        
        // Create unique filename
        let filename = "\(UUID().uuidString).m4a"
        let path = "voice/\(conversationId)/\(filename)"
        
        // Create storage reference
        let storageRef = storage.reference().child(path)
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        metadata.customMetadata = [
            "uploadedBy": userId,
            "conversationId": conversationId,
            "uploadedAt": "\(Date().timeIntervalSince1970)"
        ]
        
        // Upload
        let data = try Data(contentsOf: fileURL)
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    /// Delete voice recording from Firebase Storage
    func deleteVoiceRecording(urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw VoiceRecordingError.invalidURL
        }
        
        let storageRef = try storage.reference(for: url)
        try await storageRef.delete()
    }
    
    // MARK: - Send Voice Message
    
    /// Upload and send voice message
    func sendVoiceMessage(
        fileURL: URL,
        conversationId: String,
        duration: TimeInterval
    ) async throws -> Message {
        // Upload to storage
        let voiceURL = try await uploadVoiceRecording(fileURL, conversationId: conversationId)
        
        // Create voice message
        let message = try await messageService.sendVoiceMessage(
            conversationId: conversationId,
            voiceURL: voiceURL,
            duration: duration
        )
        
        // Clean up local file
        try? FileManager.default.removeItem(at: fileURL)
        
        return message
    }
    
    // MARK: - Helper Methods
    
    /// Format duration for display
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Voice Recording Error

enum VoiceRecordingError: LocalizedError {
    case notAuthenticated
    case permissionDenied
    case recordingFailed
    case uploadFailed
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to send voice messages"
        case .permissionDenied:
            return "Microphone permission is required"
        case .recordingFailed:
            return "Failed to record audio"
        case .uploadFailed:
            return "Failed to upload voice message"
        case .invalidURL:
            return "Invalid audio URL"
        }
    }
}

