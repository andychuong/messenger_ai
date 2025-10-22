import Foundation
import Combine
import WebRTC

class CallService: ObservableObject {
    static let shared = CallService()
    
    @Published var currentCall: Call?
    @Published var isInCall = false
    @Published var incomingCall: Call?
    
    private let webRTCService = WebRTCService()
    private let signalingService = SignalingService()
    
    var isConnected: Bool {
        webRTCService.isConnected
    }
    
    var currentUserId: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        signalingService.onIncomingCall = { [weak self] call in
            guard let self = self else { return }
            
            let callAge = Date().timeIntervalSince(call.startedAt)
            if callAge > 60 {
                print("⚠️ Ignoring stale call (age: \(callAge)s)")
                self.signalingService.declineCall(callId: call.id ?? "") { _ in }
                return
            }
            
            if !self.isInCall {
                DispatchQueue.main.async {
                    self.incomingCall = call
                }
            }
        }
        
        signalingService.onCallAnswered = { [weak self] sdpAnswer in
            guard let self = self else { return }
            
            let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdpAnswer)
            self.webRTCService.setRemoteDescription(sessionDescription) { error in
                if let error = error {
                    print("❌ Error setting remote description: \(error)")
                } else {
                    print("✅ Remote description set successfully")
                }
            }
        }
        
        signalingService.onCallEnded = { [weak self] in
            self?.endCall()
        }
        
        signalingService.onIceCandidate = { [weak self] candidate in
            self?.webRTCService.addIceCandidate(candidate) { error in
                if let error = error {
                    print("❌ Error adding ICE candidate: \(error)")
                }
            }
        }
        
        webRTCService.onIceCandidate = { [weak self] candidate in
            guard let self = self, 
                  let callId = self.currentCall?.id,
                  !callId.isEmpty else {
                print("⚠️ Skipping ICE candidate - no valid call ID yet")
                return
            }
            
            self.signalingService.addIceCandidate(callId: callId, candidate: candidate) { error in
                if let error = error {
                    print("❌ Error sending ICE candidate: \(error)")
                }
            }
        }
        
        webRTCService.onConnected = {
            print("✅ WebRTC connected")
        }
        
        webRTCService.onDisconnected = { [weak self] in
            print("⚠️ WebRTC disconnected")
            self?.endCall()
        }
    }
    
    func startListening() {
        guard let userId = currentUserId else {
            print("❌ Cannot start listening: no user ID")
            return
        }
        
        print("🎧 Starting to listen for incoming calls for user: \(userId)")
        signalingService.listenForIncomingCalls(userId: userId)
    }
    
    func startCall(to recipientId: String, isVideo: Bool, completion: @escaping (Error?) -> Void) {
        guard let callerId = currentUserId else {
            completion(NSError(domain: "CallService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID"]))
            return
        }
        
        webRTCService.setupPeerConnection(isVideo: isVideo)
        
        webRTCService.createOffer { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                completion(error)
                return
            }
            
            self.signalingService.createCall(
                callerId: callerId,
                recipientId: recipientId,
                type: isVideo ? .video : .audio,
                sdpOffer: sdp.sdp
            ) { result in
                switch result {
                case .success(let callId):
                    var call = Call(
                        id: callId,
                        callerId: callerId,
                        recipientId: recipientId,
                        type: isVideo ? .video : .audio
                    )
                    call.sdpOffer = sdp.sdp
                    
                    DispatchQueue.main.async {
                        self.currentCall = call
                        self.isInCall = true
                    }
                    
                    completion(nil)
                    
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    func answerCall(_ call: Call, completion: @escaping (Error?) -> Void) {
        guard let callId = call.id else {
            completion(NSError(domain: "CallService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No call ID"]))
            return
        }
        
        let isVideo = call.type == .video
        webRTCService.setupPeerConnection(isVideo: isVideo)
        
        guard let sdpOffer = call.sdpOffer else {
            completion(NSError(domain: "CallService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No SDP offer"]))
            return
        }
        
        let offerDescription = RTCSessionDescription(type: .offer, sdp: sdpOffer)
        webRTCService.setRemoteDescription(offerDescription) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                completion(error)
                return
            }
            
            self.webRTCService.createAnswer { sdp, error in
                guard let sdp = sdp else {
                    completion(error)
                    return
                }
                
                self.signalingService.answerCall(callId: callId, sdpAnswer: sdp.sdp) { error in
                    if let error = error {
                        completion(error)
                    } else {
                        DispatchQueue.main.async {
                            self.currentCall = call
                            self.isInCall = true
                            self.incomingCall = nil
                        }
                        completion(nil)
                    }
                }
            }
        }
    }
    
    func declineCall(_ call: Call, completion: @escaping (Error?) -> Void) {
        guard let callId = call.id else {
            completion(NSError(domain: "CallService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No call ID"]))
            return
        }
        
        signalingService.declineCall(callId: callId) { error in
            DispatchQueue.main.async {
                self.incomingCall = nil
            }
            completion(error)
        }
    }
    
    func clearIncomingCall() {
        DispatchQueue.main.async {
            self.incomingCall = nil
        }
    }
    
    func endCall() {
        guard let callId = currentCall?.id else {
            cleanup()
            return
        }
        
        signalingService.endCall(callId: callId) { [weak self] error in
            if let error = error {
                print("❌ Error ending call: \(error)")
            }
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        webRTCService.endCall()
        
        DispatchQueue.main.async {
            self.currentCall = nil
            self.isInCall = false
            self.incomingCall = nil
        }
    }
    
    func toggleMute() {
        webRTCService.toggleMute()
    }
    
    func toggleVideo() {
        webRTCService.toggleVideo()
    }
    
    func switchCamera() {
        webRTCService.switchCamera()
    }
    
    var localVideoTrack: RTCVideoTrack? {
        webRTCService.localVideoTrack
    }
    
    var remoteVideoTrack: RTCVideoTrack? {
        webRTCService.remoteVideoTrack
    }
    
    var isMuted: Bool {
        webRTCService.isMuted
    }
    
    var isVideoEnabled: Bool {
        webRTCService.isVideoEnabled
    }
}

