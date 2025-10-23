//
//  TypingIndicatorView.swift
//  messagingapp
//
//  Animated typing indicator with three bouncing dots
//

import SwiftUI

struct TypingIndicatorView: View {
    let text: String
    @State private var dotCount: Int = 1
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(spacing: 8) {
            Text(animatedText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private var animatedText: String {
        // Replace "..." with animated dots
        let baseText = text.replacingOccurrences(of: "...", with: "")
        let dots = String(repeating: ".", count: dotCount)
        return baseText + dots
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Cycle through 1, 2, 3 dots
            dotCount = (dotCount % 3) + 1
        }
        
        if let timer = animationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

#Preview {
    VStack {
        Spacer()
        TypingIndicatorView(text: "Alice is typing...")
        TypingIndicatorView(text: "Bob and Charlie are typing...")
    }
}

