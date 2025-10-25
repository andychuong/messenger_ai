//
//  EditProfileView.swift
//  messagingapp
//
//  Edit user profile information
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var photoURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        Form {
            Section {
                // Profile Photo Preview
                profilePhotoSection
            }
            
            Section {
                TextField("Display Name", text: $displayName)
                    .autocapitalization(.words)
                    .textContentType(.name)
                    .disabled(isLoading)
                
                TextField("Photo URL", text: $photoURL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .disabled(isLoading)
            } header: {
                Text("Profile Information")
            } footer: {
                Text("Enter a valid image URL for your profile photo. The display name will be visible to your friends.")
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveProfile()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isLoading || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isLoading)
            }
        }
        .alert("Profile Updated", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been updated successfully.")
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    // MARK: - Profile Photo Section
    
    private var profilePhotoSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                // Profile photo preview
                AsyncImage(url: URL(string: photoURL.trimmingCharacters(in: .whitespaces))) { phase in
                    switch phase {
                    case .empty:
                        profilePlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    case .failure(_):
                        profilePlaceholder
                    @unknown default:
                        profilePlaceholder
                    }
                }
                .frame(width: 100, height: 100)
                
                Text("Photo Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
    
    private var profilePlaceholder: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 100, height: 100)
            .overlay {
                if let initial = displayName.first?.uppercased() {
                    Text(initial)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.6))
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentProfile() {
        guard let user = authService.currentUser else { return }
        displayName = user.displayName
        photoURL = user.photoURL ?? ""
    }
    
    private func saveProfile() {
        errorMessage = nil
        
        // Validate display name
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Display name cannot be empty"
            return
        }
        
        // Validate photo URL if provided
        let trimmedURL = photoURL.trimmingCharacters(in: .whitespaces)
        if !trimmedURL.isEmpty {
            guard URL(string: trimmedURL) != nil else {
                errorMessage = "Please enter a valid URL"
                return
            }
        }
        
        isLoading = true
        
        Task {
            do {
                // Update profile
                let photoURLToSave = trimmedURL.isEmpty ? nil : trimmedURL
                try await authService.updateProfile(
                    displayName: trimmedName,
                    photoURL: photoURLToSave
                )
                
                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticManager.shared.error()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthService())
    }
}

