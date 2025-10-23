//
//  IncomingCallView.swift
//  messagingapp
//
//  View for incoming call screen
//

import SwiftUI
import FirebaseFirestore

struct IncomingCallView: View {
    let call: Call
    @State private var caller: User?
    @State private var isAnswering = false
    @State private var isDeclining = false
    @State private var ringingAnimation = false
    
    var onAnswer: () -> Void
    var onDecline: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Caller info
                VStack(spacing: 16) {
                    // Profile picture
                    if let photoURL = caller?.photoURL, let url = URL(string: photoURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 10)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 120, height: 120)
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 10)
                    }
                    
                    // Caller name
                    Text(caller?.displayName ?? "Unknown")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Debug: Show caller ID if name not loaded
                    if caller == nil {
                        Text("ID: \(call.callerId)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Call type
                    Text(call.type == .video ? "Incoming Video Call" : "Incoming Call")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Ringing animation
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.7))
                                .frame(width: 8, height: 8)
                                .scaleEffect(ringingAnimation ? 1.2 : 0.8)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: ringingAnimation
                                )
                        }
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 80) {
                    // Decline button
                    Button(action: {
                        isDeclining = true
                        onDecline()
                    }) {
                        VStack(spacing: 12) {
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
                            
                            Text("Decline")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isDeclining || isAnswering)
                    
                    // Accept button
                    Button(action: {
                        isAnswering = true
                        onAnswer()
                    }) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 70, height: 70)
                                
                                if isAnswering {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                            }
                            .shadow(radius: 10)
                            
                            Text("Accept")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isDeclining || isAnswering)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            loadCallerInfo()
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                ringingAnimation.toggle()
            }
        }
    }
    
    private func loadCallerInfo() {
        print("📞 IncomingCallView - Call object: callerId=\(call.callerId), recipientId=\(call.recipientId), type=\(call.type.rawValue)")
        print("📞 Loading caller info from collection: '\(User.collectionName)' for userId: '\(call.callerId)'")
        
        let db = Firestore.firestore()
        db.collection(User.collectionName)
            .document(call.callerId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ Error loading caller info: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    print("❌ Caller document doesn't exist for ID: \(self.call.callerId)")
                    return
                }
                
                Task { @MainActor in
                    do {
                        print("✅ Caller data loaded: \(snapshot.data() ?? [:])")
                        self.caller = try snapshot.data(as: User.self)
                        print("✅ Caller decoded: \(self.caller?.displayName ?? "nil")")
                    } catch {
                        print("❌ Error decoding caller: \(error)")
                    }
                }
            }
    }
}

