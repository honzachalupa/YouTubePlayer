import Foundation
import AuthenticationServices
import YouTubeKit
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
    private let clientID = "906870749753-ajab2im3jtl2ecfqbp28lo27k2vv0v0t.apps.googleusercontent.com"
    private weak var presentationWindow: UIWindow?
    
    private var accessToken: String? {
        get { 
            let token = UserDefaults.standard.string(forKey: "youtube_access_token")
//             print("YouTubeAuthService: Getting access token: \(token ?? "nil")")
            return token
        }
        set { 
//             print("YouTubeAuthService: Setting access token: \(newValue ?? "nil")")
            UserDefaults.standard.set(newValue, forKey: "youtube_access_token")
            // Set the token in YTM for API calls
            YTM.accessToken = newValue
        }
    }
    
    struct UserInfo: Codable {
        let name: String
        let picture: String
    }
    
    override private init() {
        super.init()
//      print("YouTubeAuthService: Initialized.")
        
        if !YTM.cookies.isEmpty {
            self.isAuthenticated = true
            
            Task {
                await fetchUserInfo()
            }
        } else {
            self.isAuthenticated = false
//          print("YouTubeAuthService: No cookies found, user is not authenticated.")
        }
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            print("YouTubeAuthService: Could not find active window scene")
            return UIWindow(windowScene: UIApplication.shared.connectedScenes.first as! UIWindowScene)
        }
        
        return window
    }
    
    func fetchUserInfo() async {
        guard isAuthenticated else {
            print("YouTubeAuthService: Cannot fetch user info - not authenticated")
            return
        }
        
        isLoading = true
        // print("YouTubeAuthService: Fetching user info...")
        
        do {
            let response = try await AccountInfosResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [:])
            // print("YouTubeAuthService: Raw response: \(response)")
            
            if !response.isDisconnected, let accountName = response.name {
                let pictureURL = response.avatar.first?.url
                self.userInfo = UserInfo(
                    name: accountName,
                    picture: pictureURL?.absoluteString ?? ""
                )
                // print("YouTubeAuthService: Successfully fetched user info: \(String(describing: self.userInfo))")
            } else {
                print("YouTubeAuthService: Could not fetch user info, account may be disconnected. Response: \(response)")
                self.userInfo = nil
            }
        } catch {
            print("YouTubeAuthService: Error fetching user info: \(error)")
            self.userInfo = nil
            authError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func handleSignIn(cookies: String) {
        // print("YouTubeAuthService: Handling sign-in with extracted cookies.")
        isLoading = true
        
        YTM.cookies = cookies
        YTM.alwaysUseCookies = true
        self.isAuthenticated = true
        
        // Fetch user info after signing in
        Task {
            await fetchUserInfo()
        }
    }
    
    func signOut() {
        // print("YouTubeAuthService: Starting sign out...")
        isLoading = true
        
        self.isAuthenticated = false
        self.userInfo = nil
        self.authError = nil
        
        YTM.reset()
        
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.fetchDataRecords(ofTypes: dataTypes) { [weak self] records in
            let youtubeRecords = records.filter { $0.displayName.contains("youtube") || $0.displayName.contains("google") }
            
            if youtubeRecords.isEmpty {
                print("YouTubeAuthService: No YouTube/Google website data to clear.")
                self?.isLoading = false
                return
            }
            
            dataStore.removeData(ofTypes: dataTypes, for: youtubeRecords) {
                print("YouTubeAuthService: Cleared website data for YouTube and Google.")
                self?.isLoading = false
            }
        }
        
        // print("YouTubeAuthService: Sign out complete")
    }
} 
