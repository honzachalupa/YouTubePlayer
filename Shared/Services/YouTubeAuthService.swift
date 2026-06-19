import Foundation
import AuthenticationServices
import YouTubeKit
import SwiftUI
import SwiftData
import Combine

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

// Moved outside of the actor-isolated class to avoid data races
struct YouTubeUserInfo: Codable, Sendable {
    let name: String
    let picture: String
}

// Platform-specific functionality delegate
protocol YouTubeAuthPlatformDelegate: AnyObject {
    func performPlatformSpecificSignOut()
}

@MainActor
final class YouTubeAuthService: NSObject, ObservableObject {
    static let shared = YouTubeAuthService()
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    @Published var userInfo: YouTubeUserInfo?
    @Published private(set) var isLoading = false
    
    let youtubeService = YouTubeService.shared
    private var modelContext: ModelContext?
    weak var platformDelegate: YouTubeAuthPlatformDelegate?
    
    override private init() {
        super.init()
        
        Task {
            await loadAuthenticationData()
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        Task {
            await loadAuthenticationData()
        }
    }
    
    func refreshAuthenticationFromStoredCookies() async {
        if isAuthenticated {
            if !youtubeService.cookies.isEmpty {
                await YouTubeCloudAuthStore.save(cookies: youtubeService.cookies)
            }
            return
        }

        youtubeService.reloadStoredCookies()

        if youtubeService.cookies.isEmpty,
           let cloudCookies = await YouTubeCloudAuthStore.loadCookies(),
           !cloudCookies.isEmpty {
            youtubeService.cookies = cloudCookies
            youtubeService.alwaysUseCookies = true
        }

        await bootstrapAuthenticationFromStoredCookies()
    }
    
    private func loadAuthenticationData() async {
        guard let context = modelContext else { return }
        
        do {
            var descriptor = FetchDescriptor<AuthenticationModel>(
                sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            
            let authData = try context.fetch(descriptor).first
            
            if let authData = authData {
                let legacyCookies = authData.cookies
                if youtubeService.cookies.isEmpty, !legacyCookies.isEmpty {
                    youtubeService.cookies = legacyCookies
                }
                if !legacyCookies.isEmpty {
                    authData.cookies = ""
                    try? context.save()
                }

                let storedCookies = youtubeService.cookies
                youtubeService.alwaysUseCookies = !storedCookies.isEmpty
                youtubeService.model.visitorData = authData.visitorData
                
                if hasAuthCookies(storedCookies) {
                    self.isAuthenticated = true
                    self.userInfo = authData.userInfo

                    if userInfo == nil {
                        await fetchUserInfo()
                        if userInfo != nil {
                            saveAuthenticationData()
                        }
                    }
                } else {
                    self.isAuthenticated = false
                    self.userInfo = nil
                    youtubeService.cookies = ""
                    youtubeService.alwaysUseCookies = false
                }
            } else {
                await bootstrapAuthenticationFromStoredCookies()
            }
        } catch {
            authError = error.localizedDescription
        }
    }
    
    private func bootstrapAuthenticationFromStoredCookies() async {
        let storedCookies = youtubeService.cookies
        youtubeService.alwaysUseCookies = !storedCookies.isEmpty
        debugLogCookies(storedCookies, reason: "bootstrapAuthenticationFromStoredCookies")

        guard hasAuthCookies(storedCookies) else {
            isAuthenticated = false
            userInfo = nil
            return
        }

        isAuthenticated = true
        await fetchUserInfo()

        if userInfo != nil {
            saveAuthenticationData()
        }
    }
    
    private func saveAuthenticationData() {
        guard let context = modelContext else { return }
        
        do {
            // Delete old authentication data
            let descriptor = FetchDescriptor<AuthenticationModel>()
            let existingData = try context.fetch(descriptor)
            existingData.forEach { context.delete($0) }
            
            // Save new authentication data
            let authData = AuthenticationModel(
                cookies: "",
                visitorData: youtubeService.model.visitorData,
                userInfo: userInfo
            )
            context.insert(authData)
            
            try context.save()
        } catch {
            authError = error.localizedDescription
        }
    }
    
    func fetchUserInfo() async {
        guard !youtubeService.cookies.isEmpty else {
            return
        }
        
        isLoading = true
        
        if youtubeService.model.visitorData.isEmpty {
            await youtubeService.getVisitorData()
            
            if youtubeService.model.visitorData.isEmpty {
                isLoading = false
                return
            }
        }
        
        do {
            let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
            let localeComponents = locale.components(separatedBy: "-")
            let languageCode = localeComponents[0]
            let countryCode = localeComponents.count > 1 ? localeComponents[1] : "US"
            
            youtubeService.model.selectedLocale = "\(languageCode)-\(countryCode)"
            
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
                    self.userInfo = YouTubeUserInfo(
                        name: accountName,
                        picture: pictureURL?.absoluteString ?? ""
                    )
                }
            } else {
                await MainActor.run {
                    self.userInfo = nil
                    self.isAuthenticated = false
                    self.authError = "Not authenticated. Please sign in again."
                }
            }
        } catch {
            await MainActor.run {
                self.userInfo = nil
                self.isAuthenticated = false
                self.authError = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    func handleSignIn(cookies: String) async {
        isLoading = true
        
        youtubeService.cookies = cookies
        youtubeService.alwaysUseCookies = true
        debugLogCookies(cookies, reason: "handleSignIn")
        
        guard hasAuthCookies(cookies) else {
            self.isAuthenticated = false
            self.userInfo = nil
            self.authError = "Authentication cookies missing. Please sign in again."
            isLoading = false
            return
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        
        await youtubeService.getVisitorData()
        
        if youtubeService.model.visitorData.isEmpty {
            isLoading = false
            
            return
        }
        
        self.isAuthenticated = true
        
        for attempt in 1...3 {
            await fetchUserInfo()
            
            if userInfo != nil {
                saveAuthenticationData()
                break
            }
            
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second between retries
            }
        }
        
        if userInfo == nil {
            self.isAuthenticated = false
        }
        
        isLoading = false
    }


    private func hasAuthCookies(_ cookies: String) -> Bool {
        let hasSAPISID = containsCookie(named: "SAPISID", in: cookies)
        let hasPAPISID = containsCookie(named: "__Secure-1PAPISID", in: cookies) || containsCookie(named: "__Secure-3PAPISID", in: cookies)
        let hasPSID = containsCookie(named: "__Secure-1PSID", in: cookies) || containsCookie(named: "__Secure-3PSID", in: cookies)
        return hasSAPISID && hasPAPISID && hasPSID
    }

    private func containsCookie(named name: String, in cookies: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "(^|;\\s*)\(escaped)="
        return cookies.range(of: pattern, options: .regularExpression) != nil
    }

    private func debugLogCookies(_ cookies: String, reason: String) {
        #if DEBUG
        guard !cookies.isEmpty else { return }
        print("=== YOUTUBE DEBUG COOKIES BEGIN [\(reason)] ===")
        print(cookies)
        print("=== YOUTUBE DEBUG COOKIES END ===")
        #endif
    }
    
    func signOut() {
        isLoading = true
        
        self.isAuthenticated = false
        self.userInfo = nil
        self.authError = nil
        
        youtubeService.reset()
        YouTubePlaylistService.shared.clearData()
        VideoManager.shared.clearPlaylistData()
        
        // Clear SwiftData
        if let context = modelContext {
            do {
                let descriptor = FetchDescriptor<AuthenticationModel>()
                let existingData = try context.fetch(descriptor)
                existingData.forEach { context.delete($0) }
                try context.save()
            } catch {
                authError = error.localizedDescription
            }
        }
        
        // Call platform-specific cleanup through delegate
        platformDelegate?.performPlatformSpecificSignOut()
        
        isLoading = false
    }
} 
