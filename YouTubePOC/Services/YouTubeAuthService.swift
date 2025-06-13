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
        case .invalidCallbackURL:
            return "Invalid callback URL received"
        case .authenticationFailed:
            return "Authentication verification failed after multiple attempts"
        case .tokenVerificationFailed:
            return "Failed to verify access token"
        }
    }
}

@MainActor
class YouTubeAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = YouTubeAuthService()
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    @Published var userInfo: UserInfo?
    
    private var authSession: ASWebAuthenticationSession?
    private let clientID = "906870749753-ajab2im3jtl2ecfqbp28lo27k2vv0v0t.apps.googleusercontent.com"
    private weak var presentationWindow: UIWindow?
    
    private var accessToken: String? {
        get { 
            let token = UserDefaults.standard.string(forKey: "youtube_access_token")
            print("YouTubeAuthService: Getting access token: \(token ?? "nil")")
            return token
        }
        set { 
            print("YouTubeAuthService: Setting access token: \(newValue ?? "nil")")
            UserDefaults.standard.set(newValue, forKey: "youtube_access_token")
            // Set the token in YTM for API calls
            YTM.accessToken = newValue
        }
    }
    
    struct UserInfo: Codable {
        let name: String
        let email: String
        let picture: String
    }
    
    override private init() {
        super.init()
        print("YouTubeAuthService: Initialized.")
        // All automatic token validation has been removed.
        // The app now relies on cookies provided in YouTubePOCApp.swift.
        
        // We can check if cookies are present and set the isAuthenticated flag accordingly.
        if !YTM.cookies.isEmpty {
            self.isAuthenticated = true
            print("YouTubeAuthService: Found existing cookies, user is considered authenticated.")
        } else {
            self.isAuthenticated = false
            print("YouTubeAuthService: No cookies found, user is not authenticated.")
        }
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.presentationWindow ?? ASPresentationAnchor()
    }
    
    func handleSignIn(cookies: String) {
        print("YouTubeAuthService: Handling sign-in with extracted cookies.")
        YTM.cookies = cookies
        YTM.alwaysUseCookies = true
        self.isAuthenticated = true
    }
    
    func signOut() {
        print("YouTubeAuthService: Starting sign out...")
        
        self.isAuthenticated = false
        self.userInfo = nil
        
        YTM.reset()
        
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            let youtubeRecords = records.filter { $0.displayName.contains("youtube") || $0.displayName.contains("google") }
            
            if youtubeRecords.isEmpty {
                print("YouTubeAuthService: No YouTube/Google website data to clear.")
                return
            }
            
            dataStore.removeData(ofTypes: dataTypes, for: youtubeRecords) {
                print("YouTubeAuthService: Cleared website data for YouTube and Google.")
            }
        }
        
        print("YouTubeAuthService: Sign out complete")
    }
} 
