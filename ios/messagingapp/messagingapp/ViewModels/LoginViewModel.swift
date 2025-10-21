//
//  LoginViewModel.swift
//  messagingapp
//
//  View model for login screen
//

import Foundation
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    let authService: AuthService
    
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
    
    var canLogin: Bool {
        return isValidEmail && isValidPassword && !isLoading
    }
    
    // MARK: - Login
    func login() async {
        guard canLogin else { return }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await authService.login(email: email, password: password)
            print("✅ Login successful")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ Login error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Reset Password
    func resetPassword() async {
        guard isValidEmail else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            try await authService.resetPassword(email: email)
            errorMessage = "Password reset email sent!"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

