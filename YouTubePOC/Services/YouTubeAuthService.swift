import Foundation
import AuthenticationServices
import YouTubeKit
import SwiftUI
import UIKit

class YouTubeAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var authError: String?
    @Published var userInfo: UserInfo?
    
    private var authSession: ASWebAuthenticationSession?
    private let clientID = "906870749753-ajab2im3jtl2ecfqbp28lo27k2vv0v0t.apps.googleusercontent.com"
    private weak var presentationWindow: UIWindow?
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "youtube_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "youtube_access_token") }
    }
    
    struct UserInfo: Codable {
        let name: String
        let email: String
        let picture: String
    }
    
    private func fetchUserInfo() {
        guard let accessToken = accessToken else { return }
        
        let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.authError = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.authError = "No data received"
                    return
                }
                
                do {
                    let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
                    self?.userInfo = userInfo
                    // Store user info
                    if let encoded = try? JSONEncoder().encode(userInfo) {
                        UserDefaults.standard.set(encoded, forKey: "youtube_user_info")
                    }
                } catch {
                    self?.authError = "Failed to decode user info: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = presentationWindow {
            return window
        }
        
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            // Find any available window scene as a fallback
            guard let fallbackScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                fatalError("No window scene available for authentication")
            }
            return ASPresentationAnchor(windowScene: fallbackScene)
        }
        
        return window
    }
    
    @MainActor
    func signIn(from window: UIWindow? = nil) {
        print("Starting sign in process...")
        self.presentationWindow = window
        
        let scope = "https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email"
        let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
        
        // For iOS, we use the bundle ID as the redirect URI scheme
        let redirectScheme = "com.janchalupa.YouTubePOC"
        
        let queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "\(redirectScheme):/oauth2callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope)
        ]
        
        var urlComponents = URLComponents(string: authURL)!
        urlComponents.queryItems = queryItems
        
        print("Auth URL: \(urlComponents.url?.absoluteString ?? "nil")")
        print("Callback URL scheme: \(redirectScheme)")
        
        let session = ASWebAuthenticationSession(
            url: urlComponents.url!,
            callbackURLScheme: redirectScheme
        ) { [self] callbackURL, error in
            print("Auth session callback received")
            
            if let error = error {
                print("Authentication error: \(error)")
                print("Error domain: \(error._domain)")
                print("Error code: \(error._code)")
                Task { @MainActor in
                    self.authError = error.localizedDescription
                }
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("Callback URL is nil")
                return
            }
            
            print("Received callback URL: \(callbackURL)")
            
            guard let code = URLComponents(string: callbackURL.absoluteString)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value
            else {
                print("Failed to extract authorization code from callback URL")
                Task { @MainActor in
                    self.authError = "Failed to get authorization code"
                }
                return
            }
            
            print("Successfully extracted authorization code")
            self.exchangeCodeForToken(code, redirectURI: "\(redirectScheme):/oauth2callback")
        }
        
        // Store the session before presenting it
        self.authSession = session
        
        print("Setting presentation context provider")
        session.presentationContextProvider = self
        
        session.prefersEphemeralWebBrowserSession = true
        print("Starting auth session...")
        session.start()
    }
    
    private func exchangeCodeForToken(_ code: String, redirectURI: String) {
        print("Starting token exchange...")
        let tokenURL = "https://oauth2.googleapis.com/token"
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": clientID,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        print("Token exchange parameters: \(parameters)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            print("Token exchange response received")
            guard let self = self else {
                print("Self is nil in token exchange")
                return
            }
            
            Task { @MainActor in
                if let error = error {
                    print("Token exchange error: \(error)")
                    self.authError = error.localizedDescription
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Token exchange HTTP status: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("Token exchange data is nil")
                    self.authError = "No data received from token endpoint"
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Token exchange response: \(jsonString)")
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accessToken = json["access_token"] as? String else {
                    print("Failed to parse token response")
                    self.authError = "Failed to parse token response"
                    return
                }
                
                print("Successfully received access token")
                self.accessToken = accessToken
                self.isAuthenticated = true
                
                // Fetch user info after successful authentication
                self.fetchUserInfo()
            }
        }.resume()
    }
    
    func signOut() {
        accessToken = nil
        isAuthenticated = false
        userInfo = nil
        // Clear stored user info
        UserDefaults.standard.removeObject(forKey: "youtube_user_info")
    }
    
    func getAccessToken() -> String? {
        return accessToken
    }
    
    override init() {
        super.init()
        
        // Check if we have a stored access token
        if let storedToken = UserDefaults.standard.string(forKey: "youtube_access_token") {
            // Validate the token by making a test request
            let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(storedToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let data = data {
                        do {
                            let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
                            self?.userInfo = userInfo
                            self?.isAuthenticated = true
                            // Store user info
                            if let encoded = try? JSONEncoder().encode(userInfo) {
                                UserDefaults.standard.set(encoded, forKey: "youtube_user_info")
                            }
                        } catch {
                            // Token is invalid or expired
                            self?.signOut()
                        }
                    } else {
                        // Token is invalid or expired
                        self?.signOut()
                    }
                }
            }.resume()
        }
    }
} 
