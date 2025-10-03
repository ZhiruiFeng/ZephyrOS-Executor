//
//  LoginView.swift
//  ZephyrOS Executor
//
//  Login view with Google OAuth integration
//

import SwiftUI

struct LoginView: View {
    @StateObject private var supabaseAuthService = SupabaseAuthService()
    @EnvironmentObject var executorManager: ExecutorManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var isAuthenticated: Bool

    var body: some View {
        VStack(spacing: 30) {
            // Logo/Header
            VStack(spacing: 10) {
                Image(systemName: "cpu.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)

                Text("ZephyrOS Executor")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sign in to access your tasks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)

            Spacer()

            // Sign In Button
            VStack(spacing: 15) {
                Button(action: handleGoogleSignIn) {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)

                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            // Footer
            VStack(spacing: 5) {
                Text("By signing in, you agree to use")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("the same credentials as ZephyrOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: supabaseAuthService.isAuthenticated) { _, newValue in
            if newValue, let accessToken = supabaseAuthService.accessToken {
                // Use Supabase access token directly
                _Concurrency.Task { @MainActor in
                    executorManager.setSupabaseToken(accessToken)
                    isAuthenticated = executorManager.isAuthenticated
                }
            }
        }
        .onAppear {
            _Concurrency.Task { @MainActor in
                await supabaseAuthService.restoreSession()
                if supabaseAuthService.isAuthenticated, let accessToken = supabaseAuthService.accessToken {
                    executorManager.setSupabaseToken(accessToken)
                    isAuthenticated = executorManager.isAuthenticated
                }
            }
        }
    }

    private func handleGoogleSignIn() {
        isLoading = true
        errorMessage = nil

        _Concurrency.Task { @MainActor in
            do {
                try await supabaseAuthService.signIn()
                // isAuthenticated will be set by onChange
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isAuthenticated: .constant(false))
    }
}
