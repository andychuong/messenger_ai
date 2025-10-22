//
//  CallViewModel.swift
//  messagingapp
//
//  ViewModel for managing call state and actions
//

import Foundation
import Combine
import AVFoundation

class CallViewModel: ObservableObject {
    @Published var isInCall = false
    @Published var currentCall: Call?
    @Published var incomingCall: Call?
    @Published var showIncomingCall = false
    @Published var showActiveCall = false
    @Published var hasPermissions = false
    @Published var errorMessage: String?
    
    private let callService = CallService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        checkPermissions()
    }
    
    private func setupBindings() {
        // Bind to call service state
        callService.$isInCall
            .receive(on: DispatchQueue.main)
            .assign(to: &$isInCall)
        
        callService.$currentCall
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentCall)
        
        callService.$incomingCall
            .receive(on: DispatchQueue.main)
            .sink { [weak self] call in
                self?.incomingCall = call
                self?.showIncomingCall = call != nil
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permissions
    
    func checkPermissions() {
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        hasPermissions = (audioStatus == .authorized) && (videoStatus == .authorized)
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        var audioGranted = false
        var videoGranted = false
        
        let group = DispatchGroup()
        
        // Request audio permission
        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            audioGranted = granted
            group.leave()
        }
        
        // Request video permission
        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            videoGranted = granted
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.hasPermissions = audioGranted && videoGranted
            completion(audioGranted && videoGranted)
        }
    }
    
    // MARK: - Initiate Call
    
    func startAudioCall(to recipientId: String) {
        guard hasPermissions else {
            requestPermissions { [weak self] granted in
                if granted {
                    self?.startAudioCall(to: recipientId)
                } else {
                    self?.errorMessage = "Microphone permission is required for calls"
                }
            }
            return
        }
        
        callService.startCall(to: recipientId, isVideo: false) { [weak self] error in
            if let error = error {
                self?.errorMessage = "Failed to start call: \(error.localizedDescription)"
            } else {
                DispatchQueue.main.async {
                    self?.showActiveCall = true
                }
            }
        }
    }
    
    func startVideoCall(to recipientId: String) {
        guard hasPermissions else {
            requestPermissions { [weak self] granted in
                if granted {
                    self?.startVideoCall(to: recipientId)
                } else {
                    self?.errorMessage = "Camera and microphone permissions are required for video calls"
                }
            }
            return
        }
        
        callService.startCall(to: recipientId, isVideo: true) { [weak self] error in
            if let error = error {
                self?.errorMessage = "Failed to start video call: \(error.localizedDescription)"
            } else {
                DispatchQueue.main.async {
                    self?.showActiveCall = true
                }
            }
        }
    }
    
    // MARK: - Answer Call
    
    func answerCall() {
        guard let call = incomingCall else { return }
        
        // Check if video call requires permissions
        if call.type == .video && !hasPermissions {
            requestPermissions { [weak self] granted in
                if granted {
                    self?.answerCall()
                } else {
                    self?.errorMessage = "Camera permission is required for video calls"
                    self?.declineCall()
                }
            }
            return
        }
        
        callService.answerCall(call) { [weak self] error in
            if let error = error {
                self?.errorMessage = "Failed to answer call: \(error.localizedDescription)"
                self?.showIncomingCall = false
            } else {
                DispatchQueue.main.async {
                    self?.showIncomingCall = false
                    self?.showActiveCall = true
                }
            }
        }
    }
    
    // MARK: - Decline Call
    
    func declineCall() {
        guard let call = incomingCall else { return }
        
        callService.declineCall(call) { [weak self] error in
            if let error = error {
                print("❌ Error declining call: \(error)")
            }
            DispatchQueue.main.async {
                self?.incomingCall = nil
                self?.showIncomingCall = false
            }
        }
    }
    
    // MARK: - Clear Incoming Call (for stale calls)
    
    func clearIncomingCall() {
        DispatchQueue.main.async { [weak self] in
            self?.incomingCall = nil
            self?.showIncomingCall = false
        }
    }
    
    // MARK: - End Call
    
    func endCall() {
        callService.endCall()
        showActiveCall = false
        showIncomingCall = false
    }
    
    // MARK: - Controls
    
    func toggleMute() {
        callService.toggleMute()
    }
    
    func toggleVideo() {
        callService.toggleVideo()
    }
    
    func switchCamera() {
        callService.switchCamera()
    }
}

