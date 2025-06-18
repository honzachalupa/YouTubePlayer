import Foundation
import AuthenticationServices
import SwiftUI
import UIKit
import CryptoKit
import WebKit

enum YouTubeAuthError: LocalizedError {
    case invalidCallbackURL
    case authenticationFailed
    case tokenVerificationFailed
    
    var errorDescription: String? {
        switch self {
            case .invalidCallbackURL: "Invalid callback URL received"
            case .authenticationFailed: "Authentication verification failed after multiple attempts"
            case .tokenVerificationFailed: "Failed to verify access token"
        }
    }
}

@MainActor
class YouTubeAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = YouTubeAuthService()
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    @Published var userInfo: UserInfo?
    @Published private(set) var isLoading = false
    
    private var authSession: ASWebAuthenticationSession?
    private let clientID = "1078839058958-f8aaiu3kbdkcjspf6ji93ve86he0ejvn.apps.googleusercontent.com"
    private let redirectURI = "com.janchalupa.YouTubePOC://"
    private let scope = "https://www.googleapis.com/auth/youtube"
    private weak var presentationWindow: UIWindow?
    
    private(set) var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "youtube_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "youtube_access_token") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "youtube_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "youtube_refresh_token") }
    }
    
    struct UserInfo: Codable {
        let name: String
        let picture: String
    }
    
    override private init() {
        super.init()
        
        if accessToken != nil {
            self.isAuthenticated = true
            
            Task {
                await fetchUserInfo()
            }
        } else {
            self.isAuthenticated = false
        }
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = presentationWindow {
            return window
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = windowScene.windows.first
        else {
            let windowScene = UIApplication.shared.connectedScenes.first as! UIWindowScene
            return UIWindow(windowScene: windowScene)
        }
        
        return window
    }
    
    func setPresentationWindow(_ window: UIWindow) {
        presentationWindow = window
    }
    
    func signIn() async {
        isLoading = true
        authError = nil
        
        let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: true)!
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope)
        ]
        
        guard let signInURL = components.url else {
            authError = "Failed to create sign in URL"
            isLoading = false
            return
        }
        
        do {
            let callbackURL = try await signInWithBrowser(url: signInURL)
            guard let code = extractCode(from: callbackURL) else {
                authError = "Failed to get authorization code"
                isLoading = false
                return
            }
            
            await exchangeCodeForTokens(code: code)
        } catch {
            authError = error.localizedDescription
            isLoading = false
        }
    }
    
    private func signInWithBrowser(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "com.janchalupa.youtubepoc"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: YouTubeAuthError.authenticationFailed)
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }
    
    private func extractCode(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .first { $0.name == "code" }?
            .value
    }
    
    private func exchangeCodeForTokens(code: String) async {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "client_id": clientID,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            self.accessToken = response.accessToken
            self.refreshToken = response.refreshToken
            self.isAuthenticated = true
            
            await fetchUserInfo()
        } catch {
            authError = "Failed to exchange code for tokens: \(error.localizedDescription)"
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    private func refreshAccessToken() async {
        guard let refreshToken = refreshToken else {
            authError = "No refresh token available"
            return
        }
        
        isLoading = true
        authError = nil
        
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            self.accessToken = response.accessToken
            self.isAuthenticated = true
            
            await fetchUserInfo()
        } catch {
            authError = "Failed to refresh token: \(error.localizedDescription)"
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func fetchUserInfo() async {
        guard let token = accessToken else {
            print("YouTubeAuthService: No access token available")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        let userInfoURL = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!
        var request = URLRequest(url: userInfoURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    authError = "Invalid response"
                    isLoading = false
                }
                return
            }
            
            if httpResponse.statusCode == 401 {
                // Token expired, try to refresh
                await refreshAccessToken()
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                await MainActor.run {
                    authError = "Failed to fetch user info: \(httpResponse.statusCode)"
                    isLoading = false
                }
                return
            }
            
            let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
            await MainActor.run {
                self.userInfo = userInfo
                isLoading = false
            }
        } catch {
            await MainActor.run {
                authError = "Failed to fetch user info: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func signOut() {
        Task { @MainActor in
            isLoading = true
            
            self.isAuthenticated = false
            self.userInfo = nil
            self.authError = nil
            self.accessToken = nil
            self.refreshToken = nil
            
            YouTubePlaylistService.shared.clearData()
            PlayerManager.shared.clearPlaylistData()
            
            let dataStore = WKWebsiteDataStore.default()
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            
            await withCheckedContinuation { continuation in
                dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
                    let youtubeRecords = records.filter { $0.displayName.contains("youtube") || $0.displayName.contains("google") }
                    
                    if youtubeRecords.isEmpty {
                        continuation.resume()
                        return
                    }
                    
                    dataStore.removeData(ofTypes: dataTypes, for: youtubeRecords) {
                        continuation.resume()
                    }
                }
            }
            
            isLoading = false
        }
    }
    
    nonisolated func cleanup() {
        Task { @MainActor in
            isLoading = false
            authError = nil
            userInfo = nil
            isAuthenticated = false
            accessToken = nil
            refreshToken = nil
            authSession = nil
        }
    }
}

// MARK: - Response Models

private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct GoogleUserInfo: Codable {
    let sub: String
    let name: String
    let picture: String
    let email: String
}

private struct GoogleErrorResponse: Codable {
    let error: ErrorDetails
    
    struct ErrorDetails: Codable {
        let code: Int
        let message: String
        let status: String
    }
} 

