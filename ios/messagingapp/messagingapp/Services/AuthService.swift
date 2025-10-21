//
//  AuthService.swift
//  messagingapp
//
//  Handles Firebase authentication
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.fetchUserData(userId: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, displayName: String) async throws {
        // Create auth account
        let result = try await auth.createUser(withEmail: email, password: password)
        
        // Create user document in Firestore
        let user = User(id: result.user.uid, email: email, displayName: displayName)
        try await db.collection(User.collectionName)
            .document(result.user.uid)
            .setData(user.toDictionary())
        
        // Fetch user data
        await fetchUserData(userId: result.user.uid)
    }
    
    // MARK: - Login
    func login(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        await fetchUserData(userId: result.user.uid)
    }
    
    // MARK: - Logout
    func logout() throws {
        try auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - Fetch User Data
    private func fetchUserData(userId: String) async {
        do {
            let document = try await db.collection(User.collectionName)
                .document(userId)
                .getDocument()
            
            if let user = try? document.data(as: User.self) {
                self.currentUser = user
                self.isAuthenticated = true
                print("✅ User data loaded: \(user.displayName)")
            }
        } catch {
            print("❌ Error fetching user data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(displayName: String? = nil, photoURL: String? = nil) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updates: [String: Any] = [:]
        if let displayName = displayName {
            updates["displayName"] = displayName
        }
        if let photoURL = photoURL {
            updates["photoURL"] = photoURL
        }
        
        try await db.collection(User.collectionName)
            .document(userId)
            .updateData(updates)
        
        await fetchUserData(userId: userId)
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
}

