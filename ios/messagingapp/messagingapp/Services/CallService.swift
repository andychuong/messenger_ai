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
            print("❌ Cannot start call: No user ID set")
            completion(NSError(domain: "CallService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID"]))
            return
        }
        
        print("📞 Starting \(isVideo ? "video" : "audio") call from \(callerId) to \(recipientId)")
        
        print("🔧 Setting up WebRTC peer connection...")
        webRTCService.setupPeerConnection(isVideo: isVideo)
        
        print("📝 Creating offer...")
        webRTCService.createOffer { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                print("❌ Failed to create offer: \(error?.localizedDescription ?? "unknown")")
                completion(error)
                return
            }
            
            print("✅ Offer created, creating call in Firestore...")
            self.signalingService.createCall(
                callerId: callerId,
                recipientId: recipientId,
                type: isVideo ? .video : .audio,
                sdpOffer: sdp.sdp
            ) { result in
                switch result {
                case .success(let callId):
                    print("✅ Call created in Firestore with ID: \(callId)")
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
                    
                    print("✅ Call started successfully")
                    completion(nil)
                    
                case .failure(let error):
                    print("❌ Failed to create call in Firestore: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }
    
    func answerCall(_ call: Call, completion: @escaping (Error?) -> Void) {
        guard let callId = call.id else {
            print("❌ Answer failed: No call ID")
            completion(NSError(domain: "CallService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No call ID"]))
            return
        }
        
        print("📞 CallService.answerCall - ID: \(callId), type: \(call.type.rawValue)")
        
        let isVideo = call.type == .video
        print("🔧 Setting up peer connection (video: \(isVideo))...")
        webRTCService.setupPeerConnection(isVideo: isVideo)
        
        guard let sdpOffer = call.sdpOffer else {
            print("❌ Answer failed: No SDP offer in call")
            completion(NSError(domain: "CallService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No SDP offer"]))
            return
        }
        
        print("📝 Setting remote description (offer)...")
        let offerDescription = RTCSessionDescription(type: .offer, sdp: sdpOffer)
        webRTCService.setRemoteDescription(offerDescription) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to set remote description: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            print("✅ Remote description set, creating answer...")
            self.webRTCService.createAnswer { sdp, error in
                guard let sdp = sdp else {
                    print("❌ Failed to create answer: \(error?.localizedDescription ?? "unknown")")
                    completion(error)
                    return
                }
                
                print("📤 Sending answer SDP to Firestore...")
                self.signalingService.answerCall(callId: callId, sdpAnswer: sdp.sdp) { error in
                    if let error = error {
                        print("❌ Failed to send answer: \(error.localizedDescription)")
                        completion(error)
                    } else {
                        print("✅ Answer sent successfully, updating UI...")
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
        print("🔚 CallService.endCall - Cleaning up immediately")
        
        // Capture call ID before clearing state
        let callId = currentCall?.id
        
        // Clean up UI state immediately
        DispatchQueue.main.async {
            self.currentCall = nil
            self.isInCall = false
            self.incomingCall = nil
        }
        
        // Clean up WebRTC immediately
        webRTCService.endCall()
        
        // Update Firestore in background (don't wait for it)
        if let callId = callId {
            print("📤 Updating Firestore call status in background...")
            signalingService.endCall(callId: callId) { error in
                if let error = error {
                    print("❌ Error updating Firestore: \(error)")
                } else {
                    print("✅ Firestore call status updated")
                }
            }
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

