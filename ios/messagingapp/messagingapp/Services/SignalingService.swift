//
//  SignalingService.swift
//  messagingapp
//
//  Service for handling call signaling via Firestore
//

import Foundation
import FirebaseFirestore
import WebRTC
import Combine

class SignalingService: ObservableObject {
    private let db = Firestore.firestore()
    private var callListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var onIncomingCall: ((Call) -> Void)?
    var onCallAnswered: ((String) -> Void)?  // SDP answer
    var onCallEnded: (() -> Void)?
    var onIceCandidate: ((RTCIceCandidate) -> Void)?
    
    // MARK: - Create Call
    
    func createCall(
        callerId: String,
        recipientId: String,
        type: Call.CallType,
        sdpOffer: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let call = Call(
            callerId: callerId,
            recipientId: recipientId,
            type: type,
            status: .ringing
        )
        
        var callData = call.toDictionary()
        callData["sdpOffer"] = sdpOffer
        
        let docRef = db.collection(Call.collectionName).document()
        let callId = docRef.documentID
        
        docRef.setData(callData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Start listening for answer
                self.listenForCallUpdates(callId: callId)
                completion(.success(callId))
            }
        }
    }
    
    // MARK: - Listen for Incoming Calls
    
    func listenForIncomingCalls(userId: String) {
        callListener?.remove()
        
        callListener = db.collection(Call.collectionName)
            .whereField("recipientId", isEqualTo: userId)
            .whereField("status", isEqualTo: Call.CallStatus.ringing.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("❌ Error listening for calls: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                
                for document in documents {
                    do {
                        let call = try document.data(as: Call.self)
                        self?.onIncomingCall?(call)
                        // Listen for updates on this call
                        self?.listenForCallUpdates(callId: document.documentID)
                    } catch {
                        print("❌ Error decoding call: \(error)")
                    }
                }
            }
    }
    
    // MARK: - Listen for Call Updates
    
    private func listenForCallUpdates(callId: String) {
        db.collection(Call.collectionName)
            .document(callId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data() else { return }
                
                // Check for SDP answer
                if let sdpAnswer = data["sdpAnswer"] as? String {
                    self?.onCallAnswered?(sdpAnswer)
                }
                
                // Check for status changes
                if let statusString = data["status"] as? String,
                   let status = Call.CallStatus(rawValue: statusString) {
                    if status == .ended || status == .declined {
                        self?.onCallEnded?()
                    }
                }
                
                // Check for ICE candidates
                if let candidates = data["iceCandidates"] as? [[String: String]] {
                    for candidateDict in candidates {
                        if let sdp = candidateDict["candidate"],
                           let sdpMLineIndex = candidateDict["sdpMLineIndex"],
                           let sdpMid = candidateDict["sdpMid"],
                           let lineIndex = Int32(sdpMLineIndex) {
                            let candidate = RTCIceCandidate(
                                sdp: sdp,
                                sdpMLineIndex: lineIndex,
                                sdpMid: sdpMid
                            )
                            self?.onIceCandidate?(candidate)
                        }
                    }
                }
            }
    }
    
    // MARK: - Answer Call
    
    func answerCall(
        callId: String,
        sdpAnswer: String,
        completion: @escaping (Error?) -> Void
    ) {
        db.collection(Call.collectionName)
            .document(callId)
            .updateData([
                "sdpAnswer": sdpAnswer,
                "status": Call.CallStatus.active.rawValue
            ]) { error in
                completion(error)
            }
    }
    
    // MARK: - Decline Call
    
    func declineCall(callId: String, completion: @escaping (Error?) -> Void) {
        db.collection(Call.collectionName)
            .document(callId)
            .updateData([
                "status": Call.CallStatus.declined.rawValue,
                "endedAt": Timestamp(date: Date())
            ]) { error in
                completion(error)
            }
    }
    
    // MARK: - End Call
    
    func endCall(callId: String, completion: @escaping (Error?) -> Void) {
        let now = Date()
        
        // Fetch the call to calculate duration
        db.collection(Call.collectionName)
            .document(callId)
            .getDocument { snapshot, error in
                guard let data = snapshot?.data(),
                      let startedAtTimestamp = data["startedAt"] as? Timestamp else {
                    completion(error)
                    return
                }
                
                let startedAt = startedAtTimestamp.dateValue()
                let duration = now.timeIntervalSince(startedAt)
                
                self.db.collection(Call.collectionName)
                    .document(callId)
                    .updateData([
                        "status": Call.CallStatus.ended.rawValue,
                        "endedAt": Timestamp(date: now),
                        "duration": duration
                    ]) { error in
                        completion(error)
                    }
            }
    }
    
    // MARK: - Add ICE Candidate
    
    func addIceCandidate(
        callId: String,
        candidate: RTCIceCandidate,
        completion: @escaping (Error?) -> Void
    ) {
        guard !callId.isEmpty else {
            print("❌ Cannot add ICE candidate: callId is empty")
            completion(NSError(domain: "SignalingService", code: -1, 
                             userInfo: [NSLocalizedDescriptionKey: "Call ID is empty"]))
            return
        }
        
        let candidateDict: [String: String] = [
            "candidate": candidate.sdp,
            "sdpMLineIndex": String(candidate.sdpMLineIndex),
            "sdpMid": candidate.sdpMid ?? ""
        ]
        
        db.collection(Call.collectionName)
            .document(callId)
            .updateData([
                "iceCandidates": FieldValue.arrayUnion([candidateDict])
            ]) { error in
                completion(error)
            }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        callListener?.remove()
        callListener = nil
    }
    
    deinit {
        stopListening()
    }
}

