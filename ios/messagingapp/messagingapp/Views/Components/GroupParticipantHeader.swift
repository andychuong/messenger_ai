//
//  GroupParticipantHeader.swift
//  messagingapp
//
//  Displays all group chat participants as colored avatar bubbles
//

import SwiftUI

struct GroupParticipantHeader: View {
    let participants: [String: ParticipantDetail]
    let currentUserId: String
    let onTap: () -> Void
    
    private var sortedParticipants: [(String, ParticipantDetail)] {
        // Sort with current user first, then alphabetically
        participants.sorted { lhs, rhs in
            if lhs.key == currentUserId { return true }
            if rhs.key == currentUserId { return false }
            return lhs.value.name < rhs.value.name
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedParticipants, id: \.0) { userId, participant in
                        ParticipantBubble(
                            participant: participant,
                            userId: userId,
                            isCurrentUser: userId == currentUserId
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemGray6).opacity(0.5))
    }
}

struct ParticipantBubble: View {
    let participant: ParticipantDetail
    let userId: String
    let isCurrentUser: Bool
    
    private var displayName: String {
        isCurrentUser ? "You" : participant.name
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Avatar
            ZStack {
                if let photoURL = participant.photoURL,
                   !photoURL.isEmpty,
                   let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        default:
                            avatarInitial
                        }
                    }
                } else {
                    avatarInitial
                }
                
                // Online status indicator
                if participant.status == "online" {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 16, y: 16)
                }
            }
            
            // Name label
            Text(displayName)
                .font(.system(size: 10))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: 50)
        }
    }
    
    private var avatarInitial: some View {
        let initials = ColorGenerator.initials(from: participant.name)
        // Use userId for consistent color generation, not name
        let backgroundColor = ColorGenerator.color(for: userId)
        
        return Circle()
            .fill(backgroundColor)
            .frame(width: 44, height: 44)
            .overlay(
                Text(initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    VStack {
        GroupParticipantHeader(
            participants: [
                "user1": ParticipantDetail(name: "Alice Johnson", email: "alice@example.com", photoURL: nil, status: "online"),
                "user2": ParticipantDetail(name: "Bob Smith", email: "bob@example.com", photoURL: nil, status: "offline"),
                "user3": ParticipantDetail(name: "Charlie Brown", email: "charlie@example.com", photoURL: nil, status: "online"),
                "user4": ParticipantDetail(name: "Diana Prince", email: "diana@example.com", photoURL: nil, status: "offline"),
                "user5": ParticipantDetail(name: "Eve Adams", email: "eve@example.com", photoURL: nil, status: "online")
            ],
            currentUserId: "user1",
            onTap: {
                print("Header tapped")
            }
        )
        
        Spacer()
    }
}

