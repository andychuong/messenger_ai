//
//  ActiveCallView.swift
//  messagingapp
//
//  View for active call screen (audio or video)
//

import SwiftUI
import FirebaseFirestore

struct ActiveCallView: View {
    let call: Call
    @StateObject private var callService = CallService.shared
    @State private var otherUser: User?
    @State private var callDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            if call.type == .video {
                // Video call UI
                videoCallContent
            } else {
                // Audio call UI
                audioCallContent
            }
            
            // Controls overlay
            if showControls {
                VStack {
                    // Top bar
                    topBar
                    
                    Spacer()
                    
                    // Bottom controls
                    controlsBar
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            loadOtherUserInfo()
            startCallTimer()
            startControlsTimer()
        }
        .onDisappear {
            stopTimers()
        }
        .onTapGesture {
            if call.type == .video {
                toggleControls()
            }
        }
        .statusBar(hidden: !showControls)
    }
    
    // MARK: - Video Call Content
    
    private var videoCallContent: some View {
        ZStack {
            // Remote video (full screen)
            if let remoteTrack = callService.remoteVideoTrack {
                RTCVideoView(videoTrack: remoteTrack)
                    .ignoresSafeArea()
            } else {
                // Placeholder while connecting
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Connecting...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
            
            // Local video (picture-in-picture)
            if let localTrack = callService.localVideoTrack {
                VStack {
                    HStack {
                        Spacer()
                        RTCVideoView(videoTrack: localTrack)
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(radius: 10)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Audio Call Content
    
    private var audioCallContent: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Profile picture
            if let photoURL = otherUser?.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(radius: 15)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 140, height: 140)
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 15)
            }
            
            // Name
            Text(otherUser?.displayName ?? "Unknown")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white)
            
            // Status
            Text(callStatusText)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack(spacing: 4) {
            // Duration
            Text(formattedDuration)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
            
            // Connection status
            if callService.isConnected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
            }
        }
        .padding(.top, 50)
    }
    
    // MARK: - Controls Bar
    
    private var controlsBar: some View {
        VStack(spacing: 30) {
            // Main controls
            HStack(spacing: 40) {
                // Mute button
                ControlButton(
                    icon: callService.isMuted ? "mic.slash.fill" : "mic.fill",
                    isActive: callService.isMuted,
                    action: {
                        callService.toggleMute()
                    }
                )
                
                // End call button
                Button(action: {
                    callService.endCall()
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(135))
                    }
                    .shadow(radius: 10)
                }
                
                // Video toggle (only for video calls)
                if call.type == .video {
                    ControlButton(
                        icon: callService.isVideoEnabled ? "video.fill" : "video.slash.fill",
                        isActive: !callService.isVideoEnabled,
                        action: {
                            callService.toggleVideo()
                        }
                    )
                } else {
                    // Speaker button for audio calls
                    ControlButton(
                        icon: "speaker.wave.2.fill",
                        isActive: false,
                        action: {
                            // Toggle speaker (implementation needed)
                        }
                    )
                }
            }
            
            // Additional controls for video calls
            if call.type == .video {
                Button(action: {
                    callService.switchCamera()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        Text("Flip Camera")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Helper Views
    
    struct ControlButton: View {
        let icon: String
        let isActive: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var callStatusText: String {
        if callService.isConnected {
            return formattedDuration
        } else {
            return "Connecting..."
        }
    }
    
    private var formattedDuration: String {
        let minutes = Int(callDuration) / 60
        let seconds = Int(callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func loadOtherUserInfo() {
        guard let currentUserId = callService.currentUserId else { return }
        let otherUserId = call.otherParticipantId(currentUserId: currentUserId)
        
        let db = Firestore.firestore()
        db.collection(User.collectionName)
            .document(otherUserId)
            .getDocument { snapshot, error in
                Task { @MainActor in
                    if let data = snapshot?.data() {
                        self.otherUser = try? Firestore.Decoder().decode(User.self, from: data)
                    }
                }
            }
    }
    
    private func startCallTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDuration += 1
        }
    }
    
    private func startControlsTimer() {
        // Auto-hide controls after 3 seconds for video calls
        if call.type == .video {
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation {
                    showControls = false
                }
            }
        }
    }
    
    private func toggleControls() {
        withAnimation {
            showControls.toggle()
        }
        
        // Reset controls timer
        controlsTimer?.invalidate()
        if showControls {
            startControlsTimer()
        }
    }
    
    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        controlsTimer?.invalidate()
        controlsTimer = nil
    }
}

