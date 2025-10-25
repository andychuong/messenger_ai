//
//  ReadReceiptAvatars.swift
//  messagingapp
//
//  Displays small avatar bubbles for users who have read a message
//

import SwiftUI

struct ReadReceiptAvatars: View {
    let readBy: [ReadReceipt]
    let participantDetails: [String: ParticipantDetail]
    let maxVisible: Int = 3
    let avatarSize: CGFloat = 14
    
    var body: some View {
        HStack(spacing: -5) {
            ForEach(Array(readBy.prefix(maxVisible)), id: \.userId) { receipt in
                if let participant = participantDetails[receipt.userId] {
                    ReadReceiptAvatar(
                        participant: participant,
                        userId: receipt.userId,
                        size: avatarSize
                    )
                }
            }
            
            // Show "+X" if there are more
            if readBy.count > maxVisible {
                Text("+\(readBy.count - maxVisible)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}

struct MessageReadReceipt: View {
    let readBy: [ReadReceipt]
    let participantDetails: [String: ParticipantDetail]
    let totalParticipants: Int
    let currentUserId: String
    
    private var otherParticipantsCount: Int {
        // Total participants minus the sender
        max(0, totalParticipants - 1)
    }
    
    private var allHaveRead: Bool {
        // Check if all other participants have read (excluding sender)
        readBy.count >= otherParticipantsCount
    }
    
    var body: some View {
        HStack(spacing: 3) {
            // Show checkmark if not everyone has read yet
            if !allHaveRead && !readBy.isEmpty {
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            // Show viewer circles if anyone has read
            if !readBy.isEmpty {
                ReadReceiptAvatars(
                    readBy: readBy,
                    participantDetails: participantDetails
                )
            }
        }
    }
}

struct ReadReceiptAvatar: View {
    let participant: ParticipantDetail
    let userId: String
    let size: CGFloat
    
    var body: some View {
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
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                    default:
                        avatarInitial
                    }
                }
            } else {
                avatarInitial
            }
        }
    }
    
    private var avatarInitial: some View {
        let initials = ColorGenerator.initials(from: participant.name)
        // Use userId for unique color generation
        let backgroundColor = ColorGenerator.color(for: userId)
        
        return ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.white)
            
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: size, height: size)
        }
    }
}

#Preview {
    let sampleParticipants = [
        "user1": ParticipantDetail(name: "Alice", email: "alice@example.com", photoURL: nil, status: nil),
        "user2": ParticipantDetail(name: "Bob", email: "bob@example.com", photoURL: nil, status: nil),
        "user3": ParticipantDetail(name: "Charlie", email: "charlie@example.com", photoURL: nil, status: nil),
        "sender": ParticipantDetail(name: "Me", email: "me@example.com", photoURL: nil, status: nil)
    ]
    
    return VStack(spacing: 20) {
        VStack(alignment: .leading) {
            Text("No one read yet:")
                .font(.caption)
            HStack {
                Text("8:09 PM")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        
        VStack(alignment: .leading) {
            Text("1 person read (out of 3):")
                .font(.caption)
            HStack {
                Text("8:09 PM")
                    .font(.caption2)
                    .foregroundColor(.gray)
                MessageReadReceipt(
                    readBy: [
                        ReadReceipt(userId: "user1", timestamp: Date())
                    ],
                    participantDetails: sampleParticipants,
                    totalParticipants: 4,
                    currentUserId: "sender"
                )
            }
        }
        
        VStack(alignment: .leading) {
            Text("2 people read (out of 3):")
                .font(.caption)
            HStack {
                Text("8:09 PM")
                    .font(.caption2)
                    .foregroundColor(.gray)
                MessageReadReceipt(
                    readBy: [
                        ReadReceipt(userId: "user1", timestamp: Date()),
                        ReadReceipt(userId: "user2", timestamp: Date())
                    ],
                    participantDetails: sampleParticipants,
                    totalParticipants: 4,
                    currentUserId: "sender"
                )
            }
        }
        
        VStack(alignment: .leading) {
            Text("All 3 read (checkmark gone):")
                .font(.caption)
            HStack {
                Text("8:09 PM")
                    .font(.caption2)
                    .foregroundColor(.gray)
                MessageReadReceipt(
                    readBy: [
                        ReadReceipt(userId: "user1", timestamp: Date()),
                        ReadReceipt(userId: "user2", timestamp: Date()),
                        ReadReceipt(userId: "user3", timestamp: Date())
                    ],
                    participantDetails: sampleParticipants,
                    totalParticipants: 4,
                    currentUserId: "sender"
                )
            }
        }
    }
    .padding()
}

