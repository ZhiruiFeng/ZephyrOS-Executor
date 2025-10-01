//
//  ProfileView.swift
//  ZephyrOS Executor
//
//  User profile view showing account information
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @StateObject private var authService = GoogleAuthService()
    @State private var showingSignOutAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Profile")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // User Info Card
                if executorManager.isAuthenticated {
                    UserInfoCard(authService: authService)
                } else {
                    NotAuthenticatedCard()
                }

                // Account Actions
                if executorManager.isAuthenticated {
                    AccountActionsSection(
                        showingSignOutAlert: $showingSignOutAlert,
                        onSignOut: handleSignOut
                    )
                }

                Spacer()
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                handleSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out? The executor will stop and you'll need to sign in again.")
        }
        .onAppear {
            authService.restoreSession()
        }
    }

    private func handleSignOut() {
        authService.signOut()
        executorManager.signOut()
    }
}

// MARK: - User Info Card

struct UserInfoCard: View {
    @ObservedObject var authService: GoogleAuthService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)

                    if let initials = getInitials(from: authService.userName) {
                        Text(initials)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let userName = authService.userName {
                        Text(userName)
                            .font(.system(size: 22, weight: .semibold))
                    }

                    if let userEmail = authService.userEmail {
                        Text(userEmail)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Signed in")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func getInitials(from name: String?) -> String? {
        guard let name = name else { return nil }
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return initials.isEmpty ? nil : String(initials).uppercased()
    }
}

// MARK: - Not Authenticated Card

struct NotAuthenticatedCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Not Signed In")
                .font(.system(size: 18, weight: .semibold))

            Text("Please sign in to use the executor")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - Account Actions Section

struct AccountActionsSection: View {
    @Binding var showingSignOutAlert: Bool
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Actions")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ActionButton(
                    icon: "arrow.left.square",
                    title: "Sign Out",
                    subtitle: "Sign out of your Google account",
                    isDestructive: true
                ) {
                    showingSignOutAlert = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? .red : .blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDestructive ? .red : .primary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.01)
        )
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(ExecutorManager.shared)
    }
}
