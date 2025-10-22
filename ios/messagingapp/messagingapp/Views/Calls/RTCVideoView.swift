//
//  RTCVideoView.swift
//  messagingapp
//
//  SwiftUI wrapper for WebRTC video rendering
//

import SwiftUI
import WebRTC

struct RTCVideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack?
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView(frame: .zero)
        videoView.contentMode = .scaleAspectFill
        #if arch(arm64)
        videoView.videoContentMode = .scaleAspectFill
        #endif
        return videoView
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let track = videoTrack {
            track.add(uiView)
        }
    }
    
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        uiView.removeFromSuperview()
    }
}

