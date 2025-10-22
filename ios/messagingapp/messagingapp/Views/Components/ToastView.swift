//
//  ToastView.swift
//  messagingapp
//
//  Toast notification for new messages
//

import SwiftUI
import Combine

// MARK: - Toast Model

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let senderName: String
    let message: String
    let conversationId: String
    let timestamp: Date = Date()
    
    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager

@MainActor
class ToastManager: ObservableObject {
    @Published var currentToast: Toast?
    @Published var activeConversationId: String?
    
    private var hideTask: Task<Void, Never>?
    
    func showToast(senderName: String, message: String, conversationId: String) {
        // Don't show toast if user is viewing this conversation
        guard activeConversationId != conversationId else {
            return
        }
        
        // Cancel previous hide task
        hideTask?.cancel()
        
        // Show new toast
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = Toast(
                senderName: senderName,
                message: message,
                conversationId: conversationId
            )
        }
        
        // Auto-hide after 4 seconds
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if self.currentToast?.conversationId == conversationId {
                        self.currentToast = nil
                    }
                }
            }
        }
    }
    
    func hideToast() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = nil
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: Toast
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(toast.senderName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.senderName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Toast Container Modifier

struct ToastContainerModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager
    let onToastTap: (String) -> Void
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let toast = toastManager.currentToast {
                ToastView(
                    toast: toast,
                    onTap: {
                        onToastTap(toast.conversationId)
                        toastManager.hideToast()
                    },
                    onDismiss: {
                        toastManager.hideToast()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}

extension View {
    func toastContainer(
        toastManager: ToastManager,
        onToastTap: @escaping (String) -> Void
    ) -> some View {
        modifier(ToastContainerModifier(toastManager: toastManager, onToastTap: onToastTap))
    }
}

#Preview {
    VStack {
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toastContainer(toastManager: ToastManager()) { _ in }
    .onAppear {
        let manager = ToastManager()
        manager.showToast(
            senderName: "John Doe",
            message: "Hey! How are you doing today?",
            conversationId: "123"
        )
    }
}

