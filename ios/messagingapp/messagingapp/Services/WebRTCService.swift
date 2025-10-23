//
//  WebRTCService.swift
//  messagingapp
//
//  Service for managing WebRTC peer connections
//

import Foundation
import WebRTC
import Combine
import AVFoundation

class WebRTCService: NSObject, ObservableObject {
    // Published properties
    @Published var isConnected = false
    @Published var isMuted = false
    @Published var isVideoEnabled = false
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?
    
    // WebRTC components
    private var peerConnection: RTCPeerConnection?
    private var audioTrack: RTCAudioTrack?
    private var videoTrack: RTCVideoTrack?
    private var videoCapturer: RTCVideoCapturer?
    private var localAudioTrack: RTCAudioTrack?
    
    // Factory for creating WebRTC objects
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )
    }()
    
    // ICE servers configuration
    private let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
    ]
    
    // Callbacks
    var onIceCandidate: ((RTCIceCandidate) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    
    override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    func setupPeerConnection(isVideo: Bool) {
        print("🔧 Setting up peer connection (video: \(isVideo))")
        
        // Configure audio session before WebRTC initialization
        configureAudioSession()
        
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        guard let pc = WebRTCService.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        ) else {
            print("❌ Failed to create peer connection")
            return
        }
        
        self.peerConnection = pc
        print("✅ Peer connection created")
        
        // Setup audio track
        setupAudioTrack()
        
        // Setup video track if video call
        if isVideo {
            setupVideoTrack()
        }
    }
    
    private func configureAudioSession() {
        print("🎵 Configuring audio session...")
        
        #if targetEnvironment(simulator)
        // Simulator has issues with VoIP audio - use simpler config
        print("📱 Running in simulator - using simplified audio config")
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try audioSession.setActive(true, options: [])
            print("✅ Audio session configured (simulator mode)")
        } catch {
            print("⚠️ Audio session error (simulator): \(error.localizedDescription)")
            // In simulator, audio might not work perfectly - that's expected
        }
        #else
        // Real device - full VoIP configuration
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Configure for VoIP with proper options
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
            
            // Set preferred sample rate and buffer duration for better performance
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            // Activate session
            try audioSession.setActive(true, options: [])
            
            print("✅ Audio session configured successfully")
        } catch {
            print("⚠️ Audio session configuration warning: \(error.localizedDescription)")
            // Don't crash - WebRTC might still work with default settings
        }
        #endif
    }
    
    private func setupAudioTrack() {
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCService.factory.audioSource(with: audioConstraints)
        let audioTrack = WebRTCService.factory.audioTrack(with: audioSource, trackId: "audio0")
        
        peerConnection?.add(audioTrack, streamIds: ["stream0"])
        self.localAudioTrack = audioTrack
        self.audioTrack = audioTrack
    }
    
    private func setupVideoTrack() {
        let videoSource = WebRTCService.factory.videoSource()
        
        #if targetEnvironment(simulator)
        // Use file capturer for simulator
        self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
        // Use camera capturer for device
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        
        let videoTrack = WebRTCService.factory.videoTrack(with: videoSource, trackId: "video0")
        self.videoTrack = videoTrack
        self.localVideoTrack = videoTrack
        
        peerConnection?.add(videoTrack, streamIds: ["stream0"])
        
        // Start capturing video
        startCaptureLocalVideo()
        isVideoEnabled = true
    }
    
    private func startCaptureLocalVideo() {
        #if !targetEnvironment(simulator)
        guard let capturer = videoCapturer as? RTCCameraVideoCapturer else { return }
        
        guard let frontCamera = RTCCameraVideoCapturer.captureDevices()
            .first(where: { $0.position == .front }) else { return }
        
        let format = RTCCameraVideoCapturer.supportedFormats(for: frontCamera).last!
        let fps = format.videoSupportedFrameRateRanges.first!.maxFrameRate
        
        capturer.startCapture(with: frontCamera, format: format, fps: Int(fps))
        #endif
    }
    
    // MARK: - Offer/Answer
    
    func createOffer(completion: @escaping (RTCSessionDescription?, Error?) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": isVideoEnabled ? "true" : "false"
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                completion(nil, error)
                return
            }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                completion(sdp, error)
            }
        }
    }
    
    func createAnswer(completion: @escaping (RTCSessionDescription?, Error?) -> Void) {
        // Check if we have a video track to determine video capability
        let hasVideo = videoTrack != nil
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": hasVideo ? "true" : "false"
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                completion(nil, error)
                return
            }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                completion(sdp, error)
            }
        }
    }
    
    func setRemoteDescription(_ sdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        peerConnection?.setRemoteDescription(sdp, completionHandler: completion)
    }
    
    // MARK: - ICE Candidates
    
    func addIceCandidate(_ candidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        peerConnection?.add(candidate, completionHandler: completion)
    }
    
    // MARK: - Controls
    
    func toggleMute() {
        guard let audioTrack = localAudioTrack else { return }
        audioTrack.isEnabled = !audioTrack.isEnabled
        isMuted = !audioTrack.isEnabled
    }
    
    func toggleVideo() {
        guard let videoTrack = videoTrack else { return }
        videoTrack.isEnabled = !videoTrack.isEnabled
        isVideoEnabled = videoTrack.isEnabled
    }
    
    func switchCamera() {
        #if !targetEnvironment(simulator)
        guard let capturer = videoCapturer as? RTCCameraVideoCapturer else { return }
        capturer.stopCapture()
        
        // Get the opposite camera
        let currentDevice = RTCCameraVideoCapturer.captureDevices()
            .first(where: { $0.position == .front })
        let targetPosition: AVCaptureDevice.Position = currentDevice?.position == .front ? .back : .front
        
        guard let targetCamera = RTCCameraVideoCapturer.captureDevices()
            .first(where: { $0.position == targetPosition }) else { return }
        
        let format = RTCCameraVideoCapturer.supportedFormats(for: targetCamera).last!
        let fps = format.videoSupportedFrameRateRanges.first!.maxFrameRate
        
        capturer.startCapture(with: targetCamera, format: format, fps: Int(fps))
        #endif
    }
    
    // MARK: - Cleanup
    
    func endCall() {
        print("🔚 Ending WebRTC call")
        
        // Stop capturing
        #if !targetEnvironment(simulator)
        if let capturer = videoCapturer as? RTCCameraVideoCapturer {
            capturer.stopCapture()
        }
        #endif
        
        // Close peer connection
        peerConnection?.close()
        peerConnection = nil
        
        // Clean up tracks
        localVideoTrack = nil
        remoteVideoTrack = nil
        videoTrack = nil
        audioTrack = nil
        localAudioTrack = nil
        
        isConnected = false
        isVideoEnabled = false
        isMuted = false
        
        // Deactivate audio session
        deactivateAudioSession()
    }
    
    private func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            print("✅ Audio session deactivated")
        } catch {
            print("⚠️ Could not deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    deinit {
        endCall()
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCService: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("📡 Signaling state changed: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("📡 Stream added")
        
        if let videoTrack = stream.videoTracks.first {
            DispatchQueue.main.async {
                self.remoteVideoTrack = videoTrack
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("📡 Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("📡 Should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("📡 ICE connection state changed: \(newState)")
        
        DispatchQueue.main.async {
            switch newState {
            case .connected, .completed:
                self.isConnected = true
                self.onConnected?()
            case .disconnected, .failed, .closed:
                self.isConnected = false
                self.onDisconnected?()
            default:
                break
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("📡 ICE gathering state changed: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("📡 ICE candidate generated")
        onIceCandidate?(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("📡 ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("📡 Data channel opened")
    }
}

