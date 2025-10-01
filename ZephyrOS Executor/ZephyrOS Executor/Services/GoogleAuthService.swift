//
//  GoogleAuthService.swift
//  ZephyrOS Executor
//
//  Google OAuth authentication service
//

import Foundation
import AuthenticationServices

@MainActor
class GoogleAuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userToken: String?
    @Published var idToken: String?  // Google ID token for Supabase exchange
    @Published var userEmail: String?
    @Published var userName: String?

    // Google OAuth configuration - loaded from environment variables
    private let clientId: String
    private let redirectURI: String
    private let scope = "openid email profile"

    private var authSession: ASWebAuthenticationSession?

    // MARK: - Initialization

    override init() {
        // Load credentials from environment variables
        self.clientId = Environment.googleClientID
        self.redirectURI = Environment.googleRedirectURI
        super.init()
    }

    // MARK: - Authentication Methods

    func signIn() async throws {
        let authURL = buildAuthURL()

        // Extract just the scheme part (without :/oauth/callback)
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
                    continuation.resume(throwing: AuthError.noCallbackURL)
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
        userToken = nil
        idToken = nil
        userEmail = nil
        userName = nil
        isAuthenticated = false

        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: "google_access_token")
        UserDefaults.standard.removeObject(forKey: "google_id_token")
        UserDefaults.standard.removeObject(forKey: "google_refresh_token")
        UserDefaults.standard.removeObject(forKey: "google_user_email")
        UserDefaults.standard.removeObject(forKey: "google_user_name")
    }

    func restoreSession() async {
        // Try to restore from stored credentials
        guard let token = UserDefaults.standard.string(forKey: "google_access_token") else {
            return
        }

        // Validate the token by attempting to fetch user info
        do {
            try await fetchUserInfo(accessToken: token)

            // If successful, restore the session
            // Note: fetchUserInfo already sets userEmail and userName
            // from the API response, so we only need to set the tokens
            userToken = token
            idToken = UserDefaults.standard.string(forKey: "google_id_token")
            isAuthenticated = true
        } catch {
            // Token is invalid or expired - clear stored credentials and sign out
            signOut()
        }
    }

    // MARK: - Private Methods

    private func buildAuthURL() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }

    private func handleCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.invalidCallback
        }

        // Exchange authorization code for access token
        try await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async throws {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.tokenExchangeFailed
        }

        guard httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Get user info
        try await fetchUserInfo(accessToken: tokenResponse.accessToken)

        // Store credentials
        userToken = tokenResponse.accessToken
        idToken = tokenResponse.idToken  // Store ID token for Supabase exchange
        UserDefaults.standard.set(tokenResponse.accessToken, forKey: "google_access_token")
        if let idToken = tokenResponse.idToken {
            UserDefaults.standard.set(idToken, forKey: "google_id_token")
        }
        if let refreshToken = tokenResponse.refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "google_refresh_token")
        }

        isAuthenticated = true
    }

    private func fetchUserInfo(accessToken: String) async throws {
        let userInfoURL = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
        var request = URLRequest(url: userInfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.userInfoFetchFailed
        }

        let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)

        userEmail = userInfo.email
        userName = userInfo.name

        UserDefaults.standard.set(userInfo.email, forKey: "google_user_email")
        UserDefaults.standard.set(userInfo.name, forKey: "google_user_name")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Response Models

private struct TokenResponse: Decodable {
    let accessToken: String
    let idToken: String?  // ID token for Supabase exchange
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct UserInfo: Decodable {
    let email: String
    let name: String
    let picture: String?
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case noCallbackURL
    case invalidCallback
    case tokenExchangeFailed
    case userInfoFetchFailed

    var errorDescription: String? {
        switch self {
        case .noCallbackURL:
            return "No callback URL received"
        case .invalidCallback:
            return "Invalid callback URL"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token"
        case .userInfoFetchFailed:
            return "Failed to fetch user information"
        }
    }
}
