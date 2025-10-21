//
//  SignUpView.swift
//  messagingapp
//
//  Sign up screen
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: SignUpViewModel(authService: authService))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Join MessageAI today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Display name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("Enter your name", text: $viewModel.displayName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    if let error = viewModel.displayNameError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("Enter your email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    if let error = viewModel.emailError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    SecureField("Enter your password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.oneTimeCode)
                        .autocorrectionDisabled()
                    
                    if let error = viewModel.passwordError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Confirm password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    SecureField("Confirm your password", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.oneTimeCode)
                        .autocorrectionDisabled()
                    
                    if let error = viewModel.confirmPasswordError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Sign up button
                Button {
                    Task {
                        await viewModel.signUp()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign Up")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSignUp)
                .padding(.top)
                
                // Terms text
                Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView(authService: AuthService())
    }
}

