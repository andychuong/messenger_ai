//
//  SignUpViewModel.swift
//  messagingapp
//
//  View model for sign up screen
//

import Foundation
import Combine

@MainActor
class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let authService: AuthService
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    // MARK: - Validation
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var isValidPassword: Bool {
        return password.count >= 6
    }
    
    var passwordsMatch: Bool {
        return password == confirmPassword
    }
    
    var isValidDisplayName: Bool {
        return displayName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    
    var canSignUp: Bool {
        return isValidEmail && isValidPassword && passwordsMatch && isValidDisplayName && !isLoading
    }
    
    // MARK: - Validation Messages
    var emailError: String? {
        guard !email.isEmpty else { return nil }
        return isValidEmail ? nil : "Invalid email address"
    }
    
    var passwordError: String? {
        guard !password.isEmpty else { return nil }
        return isValidPassword ? nil : "Password must be at least 6 characters"
    }
    
    var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return passwordsMatch ? nil : "Passwords don't match"
    }
    
    var displayNameError: String? {
        guard !displayName.isEmpty else { return nil }
        return isValidDisplayName ? nil : "Name must be at least 2 characters"
    }
    
    // MARK: - Sign Up
    func signUp() async {
        guard canSignUp else { return }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            print("✅ Sign up successful")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ Sign up error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

