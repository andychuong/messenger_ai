//
//  AddFriendView.swift
//  messagingapp
//
//  Created on October 21, 2025.
//

import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var friendshipService = FriendshipService()
    
    @State private var email = ""
    @State private var searchedUser: User?
    @State private var isSearching = false
    @State private var isSendingRequest = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Friend's Email")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("email@example.com", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)
                
                // Search Button
                Button(action: searchUser) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Search User")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || isSearching)
                
                // Search Result
                if let user = searchedUser {
                    VStack(spacing: 16) {
                        Divider()
                        
                        // User Card
                        HStack(spacing: 16) {
                            // Profile Picture
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(user.displayName.prefix(1).uppercased())
                                        .font(.title2)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Send Request Button
                        Button(action: sendFriendRequest) {
                            if isSendingRequest {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Label("Send Friend Request", systemImage: "person.badge.plus")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSendingRequest)
                    }
                }
                
                // Success Message
                if let success = successMessage {
                    Text(success)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func searchUser() {
        isSearching = true
        errorMessage = nil
        searchedUser = nil
        successMessage = nil
        
        Task {
            do {
                searchedUser = try await friendshipService.searchUserByEmail(email)
                if searchedUser == nil {
                    errorMessage = "No user found with that email"
                }
            } catch {
                errorMessage = "Error searching for user: \(error.localizedDescription)"
            }
            isSearching = false
        }
    }
    
    private func sendFriendRequest() {
        guard searchedUser != nil else { return }
        
        isSendingRequest = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                _ = try await friendshipService.sendFriendRequest(to: email)
                successMessage = "Friend request sent successfully!"
                
                // Clear form after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSendingRequest = false
        }
    }
}

#Preview {
    AddFriendView()
}

