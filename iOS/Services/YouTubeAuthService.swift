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
    private let youtubeService = YouTubeService.shared
    
    private var accessToken: String? {
        get { 
            let token = UserDefaults.standard.string(forKey: "youtube_access_token")
            
            return token
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "youtube_access_token")
            
            youtubeService.accessToken = newValue
        }
    }
    
    struct UserInfo: Codable {
        let name: String
        let picture: String
    }
    
    override private init() {
        super.init()
        
        if !youtubeService.cookies.isEmpty {
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
    
    func fetchUserInfo() async {
        guard !youtubeService.cookies.isEmpty else {
            print("YouTubeAuthService: No cookies available")
            return
        }
        
        isLoading = true
        
        if youtubeService.model.visitorData.isEmpty {
            print("YouTubeAuthService: No visitor data, fetching...")
            await youtubeService.getVisitorData()
            
            if youtubeService.model.visitorData.isEmpty {
                print("YouTubeAuthService: Failed to get visitor data")
                isLoading = false
                return
            }
        }
        
        do {
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            let localeComponents = locale.components(separatedBy: "_")
            let languageCode = localeComponents[0]
            let countryCode = localeComponents.count > 1 ? localeComponents[1] : "US"
            
            youtubeService.model.selectedLocale = "\(languageCode)_\(countryCode)"
            
            let customHeaders = HeadersList(
                url: URL(string: "https://www.youtube.com/youtubei/v1/account/account_menu")!,
                method: .POST,
                headers: [
                    .init(name: "Accept", content: "*/*"),
                    .init(name: "Accept-Encoding", content: "gzip, deflate, br"),
                    .init(name: "Host", content: "www.youtube.com"),
                    .init(name: "User-Agent", content: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15"),
                    .init(name: "Accept-Language", content: "\(youtubeService.model.selectedLocale);q=0.9"),
                    .init(name: "Origin", content: "https://www.youtube.com/"),
                    .init(name: "Referer", content: "https://www.youtube.com/"),
                    .init(name: "Content-Type", content: "application/json"),
                    .init(name: "X-Origin", content: "https://www.youtube.com")
                ],
                addQueryAfterParts: [],
                httpBody: [
                    "{\"context\":{\"client\":{\"hl\":\"\(languageCode)\",\"gl\":\"\(countryCode)\",\"visitorData\":\"\(youtubeService.model.visitorData)\",\"userAgent\":\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15,gzip(gfe)\",\"clientName\":\"WEB\",\"clientVersion\":\"2.20230201.01.00\",\"osName\":\"Macintosh\",\"osVersion\":\"10_15_7\",\"platform\":\"DESKTOP\",\"clientFormFactor\":\"UNKNOWN_FORM_FACTOR\",\"userInterfaceTheme\":\"USER_INTERFACE_THEME_DARK\",\"timeZone\":\"Europe/Zurich\",\"browserName\":\"Safari\",\"browserVersion\":\"16.2\",\"acceptHeader\":\"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\",\"utcOffsetMinutes\":60,\"mainAppWebInfo\":{\"webDisplayMode\":\"WEB_DISPLAY_MODE_BROWSER\",\"isWebNativeShareAvailable\":true}},\"user\":{\"lockedSafetyMode\":false},\"request\":{\"useSsl\":true,\"internalExperimentFlags\":[],\"consistencyTokenJars\":[]}},\"userInterfaceTheme\":\"USER_INTERFACE_THEME_DARK\",\"deviceTheme\":\"DEVICE_THEME_SELECTED\"}"
                ],
                parameters: [
                    .init(name: "prettyPrint", content: "false")
                ]
            )
            
            youtubeService.model.customHeaders[.userAccountHeaders] = customHeaders
            
            let response = try await AccountInfosResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [:],
                useCookies: true
            )
            
            if !response.isDisconnected, let accountName = response.name {
                let pictureURL = response.avatar.first?.url
                
                await MainActor.run {
                    self.userInfo = UserInfo(
                        name: accountName,
                        picture: pictureURL?.absoluteString ?? ""
                    )
                }
            } else {
                print("YouTubeAuthService: Could not fetch user info, account may be disconnected. Response: \(response)")
                await MainActor.run {
                    self.userInfo = nil
                }
            }
        } catch {
            print("YouTubeAuthService: Error fetching user info: \(error)")
            await MainActor.run {
                self.userInfo = nil
                self.authError = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    func handleSignIn(cookies: String) async {
        isLoading = true
        
        youtubeService.cookies = cookies
        youtubeService.alwaysUseCookies = true
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        
        await youtubeService.getVisitorData()
        
        if youtubeService.model.visitorData.isEmpty {
            print("YouTubeAuthService: Failed to get visitor data")
            
            isLoading = false
            
            return
        }
        
        self.isAuthenticated = true
        
        for attempt in 1...3 {
            print("YouTubeAuthService: Fetching user info attempt \(attempt)")
            await fetchUserInfo()
            
            if userInfo != nil {
                break
            }
            
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second between retries
            }
        }
        
        if userInfo == nil {
            print("YouTubeAuthService: Failed to fetch user info after 3 attempts")
            
            self.isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func signOut() {
        isLoading = true
        
        self.isAuthenticated = false
        self.userInfo = nil
        self.authError = nil
        
        youtubeService.reset()
        YouTubePlaylistService.shared.clearData()
        VideoManager.shared.clearPlaylistData()
        
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.fetchDataRecords(ofTypes: dataTypes) { [weak self] records in
            let youtubeRecords = records.filter { $0.displayName.contains("youtube") || $0.displayName.contains("google") }
            
            if youtubeRecords.isEmpty {
                self?.isLoading = false
                
                return
            }
            
            dataStore.removeData(ofTypes: dataTypes, for: youtubeRecords) {
                self?.isLoading = false
            }
        }
    }
} 
