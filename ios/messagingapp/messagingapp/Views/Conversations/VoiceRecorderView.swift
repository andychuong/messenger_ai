//
//  VoiceRecorderView.swift
//  messagingapp
//
//  Phase 4: Rich Messaging Features
//  Voice recording interface with waveform visualization
//

import SwiftUI

struct VoiceRecorderView: View {
    @ObservedObject var voiceService: VoiceRecordingService
    let onSend: () -> Void
    let onCancel: () -> Void
    
    @State private var waveformAmplitudes: [CGFloat] = Array(repeating: 0.3, count: 20)
    @State private var waveformTimer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Voice Message")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding()
            
            Spacer()
            
            // Waveform visualization
            if voiceService.isRecording {
                waveformView
                    .frame(height: 80)
                    .padding(.horizontal, 40)
            }
            
            // Duration
            Text(VoiceRecordingService.formatDuration(voiceService.recordingDuration))
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundColor(.primary)
            
            // Recording indicator
            if voiceService.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text("Recording...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 40) {
                // Cancel button
                Button {
                    onCancel()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.red)
                            .clipShape(Circle())
                        
                        Text("Cancel")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Record/Stop button
                Button {
                    if voiceService.isRecording {
                        voiceService.stopRecording()
                    } else {
                        voiceService.startRecording()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: voiceService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(voiceService.isRecording ? Color.orange : Color.red)
                            .clipShape(Circle())
                        
                        Text(voiceService.isRecording ? "Stop" : "Record")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Send button
                Button {
                    onSend()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(voiceService.recordingURL != nil ? Color.blue : Color.gray)
                            .clipShape(Circle())
                        
                        Text("Send")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .disabled(voiceService.recordingURL == nil || voiceService.recordingDuration < 0.5)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            requestPermissionAndStartRecording()
        }
    }
    
    // MARK: - Waveform View
    
    private var waveformView: some View {
        HStack(spacing: 4) {
            ForEach(0..<waveformAmplitudes.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3)
                    .frame(height: max(8, waveformAmplitudes[index] * 80))
                    .animation(.easeInOut(duration: 0.2), value: waveformAmplitudes[index])
            }
        }
        .onAppear {
            animateWaveform()
        }
        .onDisappear {
            waveformTimer?.invalidate()
            waveformTimer = nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func requestPermissionAndStartRecording() {
        Task {
            let granted = await voiceService.requestMicrophonePermission()
            if granted {
                voiceService.startRecording()
            }
        }
    }
    
    private func animateWaveform() {
        // Invalidate any existing timer
        waveformTimer?.invalidate()
        
        // Create new timer - structs can't use weak self
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak voiceService] _ in
            Task { @MainActor [weak voiceService] in
                guard let voiceService = voiceService,
                      voiceService.isRecording else {
                    return
                }
                
                // Shift amplitudes left and add new random value
                waveformAmplitudes.removeFirst()
                waveformAmplitudes.append(CGFloat.random(in: 0.2...1.0))
            }
        }
        
        // Keep timer alive
        if let timer = waveformTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}

// MARK: - Voice Message Player View

struct VoiceMessagePlayerView: View {
    let audioURL: URL
    let duration: TimeInterval
    @ObservedObject var voiceService: VoiceRecordingService
    
    private var isCurrentlyPlaying: Bool {
        voiceService.isPlaying && voiceService.currentlyPlayingURL == audioURL
    }
    
    private var progress: Double {
        guard isCurrentlyPlaying else { return 0 }
        return duration > 0 ? voiceService.playbackProgress / duration : 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button {
                if isCurrentlyPlaying {
                    voiceService.pausePlayback()
                } else {
                    voiceService.playAudio(from: audioURL)
                }
            } label: {
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
                
                // Duration
                Text(VoiceRecordingService.formatDuration(isCurrentlyPlaying ? voiceService.playbackProgress : duration))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
    }
}

#Preview {
    VStack {
        VoiceRecorderView(
            voiceService: VoiceRecordingService(),
            onSend: {
                print("Send voice message")
            },
            onCancel: {
                print("Cancel recording")
            }
        )
    }
}

