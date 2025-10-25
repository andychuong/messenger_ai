//
//  UserAvatarView.swift
//  messagingapp
//
//  Reusable component for displaying user avatars with profile photos or initials
//

import SwiftUI

struct UserAvatarView: View {
    let photoURL: String?
    let displayName: String
    let size: CGFloat
    let showOnlineStatus: Bool
    let isOnline: Bool
    
    init(
        photoURL: String? = nil,
        displayName: String,
        size: CGFloat = 50,
        showOnlineStatus: Bool = false,
        isOnline: Bool = false
    ) {
        self.photoURL = photoURL
        self.displayName = displayName
        self.size = size
        self.showOnlineStatus = showOnlineStatus
        self.isOnline = isOnline
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let photoURL = photoURL,
               !photoURL.isEmpty,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_), .empty:
                        avatarInitial
                    @unknown default:
                        avatarInitial
                    }
                }
            } else {
                avatarInitial
            }
            
            // Online status indicator
            if showOnlineStatus && isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
        }
    }
    
    private var avatarInitial: some View {
        let initials = ColorGenerator.initials(from: displayName)
        let backgroundColor = ColorGenerator.color(for: displayName)
        
        return Circle()
            .fill(backgroundColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(backgroundColor)
            )
    }
}

// MARK: - Convenience Initializers for User Model

extension UserAvatarView {
    init(user: User, size: CGFloat = 50, showOnlineStatus: Bool = false) {
        self.init(
            photoURL: user.photoURL,
            displayName: user.displayName,
            size: size,
            showOnlineStatus: showOnlineStatus,
            isOnline: user.status == .online
        )
    }
    
    init(participant: ParticipantDetail, size: CGFloat = 50, showOnlineStatus: Bool = false) {
        self.init(
            photoURL: participant.photoURL,
            displayName: participant.name,
            size: size,
            showOnlineStatus: showOnlineStatus,
            isOnline: participant.status == "online"
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // With photo URL
        UserAvatarView(
            photoURL: "https://example.com/photo.jpg",
            displayName: "John Doe",
            size: 60
        )
        
        // Without photo (shows initial)
        UserAvatarView(
            photoURL: nil,
            displayName: "Jane Smith",
            size: 60
        )
        
        // With online status
        UserAvatarView(
            photoURL: nil,
            displayName: "Alice",
            size: 60,
            showOnlineStatus: true,
            isOnline: true
        )
    }
    .padding()
}

