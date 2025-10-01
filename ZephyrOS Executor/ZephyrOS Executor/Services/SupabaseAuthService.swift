//
//  SupabaseAuthService.swift
//  ZephyrOS Executor
//
//  Supabase OAuth authentication service
//

import Foundation
import AuthenticationServices

@MainActor
class SupabaseAuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?  // Supabase JWT token
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var userId: String?

    private let supabaseURL: String
    private let redirectURI: String

    private var authSession: ASWebAuthenticationSession?

    // MARK: - Initialization

    override init() {
        self.supabaseURL = Environment.supabaseURL
        self.redirectURI = Environment.googleRedirectURI
        super.init()
    }

    // MARK: - Authentication Methods

    func signIn() async throws {
        // Build Supabase OAuth URL for Google provider
        let authURL = buildSupabaseAuthURL()

        // Extract callback scheme
        let callbackScheme = redirectURI.components(separatedBy: ":").first ?? "com.zephyros.executor"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: SupabaseAuthError.noCallbackURL)
                    return
                }

                _Concurrency.Task { @MainActor in
                    do {
                        try await self.handleCallback(url: callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }
    }

    func signOut() {
        accessToken = nil
        userEmail = nil
        userName = nil
        userId = nil
        isAuthenticated = false

        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
        UserDefaults.standard.removeObject(forKey: "supabase_user_email")
        UserDefaults.standard.removeObject(forKey: "supabase_user_name")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
    }

    func restoreSession() {
        guard let token = UserDefaults.standard.string(forKey: "supabase_access_token") else {
            return
        }

        accessToken = token
        userEmail = UserDefaults.standard.string(forKey: "supabase_user_email")
        userName = UserDefaults.standard.string(forKey: "supabase_user_name")
        userId = UserDefaults.standard.string(forKey: "supabase_user_id")
        isAuthenticated = true
    }

    // MARK: - Private Methods

    private func buildSupabaseAuthURL() -> URL {
        var components = URLComponents(string: "\(supabaseURL)/auth/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirectURI)
        ]
        return components.url!
    }

    private func handleCallback(url: URL) async throws {
        // Parse the callback URL
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // Supabase returns the tokens in the URL fragment
        guard let fragment = components?.fragment else {
            throw SupabaseAuthError.invalidCallback
        }

        // Parse fragment parameters
        let params = fragment.components(separatedBy: "&").reduce(into: [String: String]()) { result, param in
            let parts = param.components(separatedBy: "=")
            if parts.count == 2 {
                result[parts[0]] = parts[1].removingPercentEncoding
            }
        }

        guard let accessToken = params["access_token"] else {
            throw SupabaseAuthError.noAccessToken
        }

        // Store the Supabase JWT token
        self.accessToken = accessToken
        UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")

        if let refreshToken = params["refresh_token"] {
            UserDefaults.standard.set(refreshToken, forKey: "supabase_refresh_token")
        }

        try await fetchUserInfo(token: accessToken)

        isAuthenticated = true
    }

    private func fetchUserInfo(token: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Environment.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, _) = try await URLSession.shared.data(for: request)
        let userInfo = try JSONDecoder().decode(SupabaseUser.self, from: data)

        self.userId = userInfo.id
        self.userEmail = userInfo.email
        self.userName = userInfo.userMetadata.fullName ?? userInfo.email

        // Store user info
        UserDefaults.standard.set(userId, forKey: "supabase_user_id")
        UserDefaults.standard.set(userEmail, forKey: "supabase_user_email")
        if let userName = userName {
            UserDefaults.standard.set(userName, forKey: "supabase_user_name")
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SupabaseAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Supporting Types

struct SupabaseUser: Codable {
    let id: String
    let email: String
    let userMetadata: UserMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }

    struct UserMetadata: Codable {
        let fullName: String?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }
}

enum SupabaseAuthError: LocalizedError {
    case noCallbackURL
    case invalidCallback
    case noAccessToken
    case fetchUserInfoFailed

    var errorDescription: String? {
        switch self {
        case .noCallbackURL:
            return "No callback URL received"
        case .invalidCallback:
            return "Invalid callback URL"
        case .noAccessToken:
            return "No access token in callback"
        case .fetchUserInfoFailed:
            return "Failed to fetch user information"
        }
    }
}
