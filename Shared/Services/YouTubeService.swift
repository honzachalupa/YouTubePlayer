import Foundation
import YouTubeKit
import SwiftUI
import CryptoKit
import Combine

@MainActor
final class YouTubeService: ObservableObject {
    static let shared = YouTubeService()
    
    @Published var model = YouTubeModel()
    
    @Published var cookies: String {
        didSet {
            model.cookies = cookies
            model.alwaysUseCookies = !cookies.isEmpty
            
            UserDefaults.standard.set(cookies, forKey: "ytm_cookies")
            UserDefaults.standard.set(!cookies.isEmpty, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var alwaysUseCookies: Bool {
        didSet {
            model.alwaysUseCookies = alwaysUseCookies
            
            UserDefaults.standard.set(alwaysUseCookies, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var accessToken: String?
    
    private init() {
        self.model = YouTubeModel()
        self.cookies = UserDefaults.standard.string(forKey: "ytm_cookies") ?? ""
        self.alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        
        model.cookies = self.cookies
        model.alwaysUseCookies = self.alwaysUseCookies
        model.selectedLocale = Bundle.main.preferredLocalizations.first ?? "en"
        
        // Load cached visitor data
        if let visitorData = UserDefaults.standard.string(forKey: "ytm_visitor_data") {
            model.visitorData = visitorData
        }
        
        setup()
    }
    
    func setup() {
        model.selectedLocale = Bundle.main.preferredLocalizations.first ?? "en"
        configureNativePlaybackHeaders()
        
        if let savedCookies = UserDefaults.standard.string(forKey: "ytm_cookies") {
            cookies = savedCookies
            alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        } else {
            print("YouTubeService: No saved cookies found during setup")
        }
    }

    private func configureNativePlaybackHeaders() {
        let languageCode = model.selectedLocaleLanguageCode.isEmpty ? "en" : model.selectedLocaleLanguageCode
        let countryCode = NativePlaybackSupport.resolvedCountryCode(
            selectedLocaleCountryCode: model.selectedLocaleCountryCode,
            languageCode: languageCode,
            fallbackRegionCode: Locale.current.region?.identifier ?? "US"
        )

        model.replaceHeaders(
            withHeaders: NativePlaybackSupport.makeVideoInfosHeaders(
                languageCode: languageCode,
                countryCode: countryCode
            ),
            headersType: .videoInfos
        )
    }
    
    func reset() {
        print("YouTubeService: Starting reset...")
        
        cookies = ""
        alwaysUseCookies = false
        model.visitorData = ""
        
        // Clear all stored data
        UserDefaults.standard.removeObject(forKey: "ytm_cookies")
        UserDefaults.standard.removeObject(forKey: "ytm_always_use_cookies")
        UserDefaults.standard.removeObject(forKey: "youtube_access_token")
        UserDefaults.standard.removeObject(forKey: "youtube_user_info")
        UserDefaults.standard.removeObject(forKey: "ytm_visitor_data")
        UserDefaults.standard.synchronize()
    }
    
    func getVisitorData() async {
        // If we have cached visitor data and it's not empty, use it
        if !model.visitorData.isEmpty {
            return
        }
        
        do {
            let response = try await HomeScreenResponse.sendThrowingRequest(
                youtubeModel: model,
                data: [:],
                useCookies: true
            )
            
            if let visitorData = response.visitorData {
                model.visitorData = visitorData
                // Cache the visitor data
                UserDefaults.standard.set(visitorData, forKey: "ytm_visitor_data")
            } else {
                print("YouTubeService: Couldn't get visitorData, request may fail.")
            }
        } catch {
            print("YouTubeService: Error getting visitor data:", error.localizedDescription)
        }
    }
    
    func generateSAPISIDHASH(forCookies cookies: String, time: Int? = nil) -> String? {
        guard let SAPISID = cookies.ytkFirstGroupMatch(for: "SAPISID=([^\\s|;]*)") else {
            if cookies.contains("OAUTH_TOKEN=") {
                guard let token = cookies.ytkFirstGroupMatch(for: "OAUTH_TOKEN=([^\\s|;]*)") else {
                    return nil
                }
                
                let sapisidValue = String(token.prefix(40))
                let currentTime = time ?? Int(Date().timeIntervalSince1970)
                let hashInput = "\(currentTime) \(sapisidValue) https://www.youtube.com"
                let inputData = Data(hashInput.utf8)
                let hashed = Insecure.SHA1.hash(data: inputData)
                let hashString = hashed.map { String(format: "%02hhx", $0) }.joined()
                
                return "SAPISIDHASH \(currentTime)_\(hashString)"
            }
            return nil
        }
        
        let currentTime = time ?? Int(Date().timeIntervalSince1970)
        let hashInput = "\(currentTime) \(SAPISID) https://www.youtube.com"
        let inputData = Data(hashInput.utf8)
        let hashed = Insecure.SHA1.hash(data: inputData)
        let hashString = hashed.map { String(format: "%02hhx", $0) }.joined()
        
        return "SAPISIDHASH \(currentTime)_\(hashString)"
    }
} 
