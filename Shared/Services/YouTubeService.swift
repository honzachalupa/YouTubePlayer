import Foundation
import YouTubeKit
import SwiftUI
import CryptoKit
import Combine

@MainActor
final class YouTubeService: ObservableObject {
    static let shared = YouTubeService()

    private struct CacheEntry<Value> {
        let value: Value
        let expirationDate: Date
        var lastAccessDate: Date
    }

    private enum CacheConfiguration {
        static let videoDetailsTTL: TimeInterval = 10 * 60
        static let videoDetailsLimit = 25
        static let recommendedVideosTTL: TimeInterval = 5 * 60
    }

    struct CachedVideoDetails {
        let response: MoreVideoInfosResponse
        let description: String?
        let recommendedVideos: [YTVideo]
    }
    
    @Published var model = YouTubeModel()
    
    @Published var cookies: String {
        didSet {
            model.cookies = cookies
            model.alwaysUseCookies = !cookies.isEmpty
            
            if cookies.isEmpty {
                YouTubeKeychainService.delete(.cookies)
                Task {
                    await YouTubeCloudAuthStore.delete()
                }
            } else {
                YouTubeKeychainService.set(cookies, for: .cookies)
                let cookiesToSync = cookies
                Task {
                    await YouTubeCloudAuthStore.save(cookies: cookiesToSync)
                }
            }
            UserDefaults.standard.removeObject(forKey: "ytm_cookies")
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
    private var cachedVideoDetailsByID: [String: CacheEntry<CachedVideoDetails>] = [:]
    private var cachedRecommendedVideos: CacheEntry<[YTVideo]>?

    func reloadStoredCookies() {
        let storedCookies = Self.storedCookies()
        guard cookies != storedCookies else { return }
        cookies = storedCookies
        alwaysUseCookies = !storedCookies.isEmpty
    }

    private static func storedCookies() -> String {
        if let keychainCookies = YouTubeKeychainService.string(for: .cookies), !keychainCookies.isEmpty {
            UserDefaults.standard.removeObject(forKey: "ytm_cookies")
            return keychainCookies
        }

        let legacyCookies = UserDefaults.standard.string(forKey: "ytm_cookies") ?? ""
        if !legacyCookies.isEmpty {
            YouTubeKeychainService.set(legacyCookies, for: .cookies)
            UserDefaults.standard.removeObject(forKey: "ytm_cookies")
        }

        return legacyCookies
    }
    
    private init() {
        self.model = YouTubeModel()
        let storedCookies = Self.storedCookies()
        self.cookies = storedCookies
        self.alwaysUseCookies = !storedCookies.isEmpty
        
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
        alwaysUseCookies = !cookies.isEmpty
        UserDefaults.standard.removeObject(forKey: "ytm_cookies")
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
        YouTubeKeychainService.delete(.cookies)
        
        // Clear all stored data
        UserDefaults.standard.removeObject(forKey: "ytm_cookies")
        UserDefaults.standard.removeObject(forKey: "ytm_always_use_cookies")
        UserDefaults.standard.removeObject(forKey: "youtube_access_token")
        UserDefaults.standard.removeObject(forKey: "youtube_user_info")
        UserDefaults.standard.removeObject(forKey: "ytm_visitor_data")
        UserDefaults.standard.synchronize()
        cachedVideoDetailsByID.removeAll()
        cachedRecommendedVideos = nil
    }

    func cachedDetails(for videoID: String) -> CachedVideoDetails? {
        guard var entry = cachedVideoDetailsByID[videoID] else { return nil }

        guard entry.expirationDate > Date() else {
            cachedVideoDetailsByID.removeValue(forKey: videoID)
            return nil
        }

        entry.lastAccessDate = Date()
        cachedVideoDetailsByID[videoID] = entry
        return entry.value
    }

    func cacheVideoDetails(
        response: MoreVideoInfosResponse,
        description: String?,
        recommendedVideos: [YTVideo],
        for videoID: String
    ) {
        evictExpiredVideoDetails()
        let now = Date()
        cachedVideoDetailsByID[videoID] = CacheEntry(
            value: CachedVideoDetails(
                response: response,
                description: description,
                recommendedVideos: recommendedVideos
            ),
            expirationDate: now.addingTimeInterval(CacheConfiguration.videoDetailsTTL),
            lastAccessDate: now
        )
        trimVideoDetailsCacheIfNeeded()
    }

    func cachedRecommendedVideosFeed() -> [YTVideo]? {
        guard var entry = cachedRecommendedVideos else { return nil }

        guard entry.expirationDate > Date() else {
            cachedRecommendedVideos = nil
            return nil
        }

        entry.lastAccessDate = Date()
        cachedRecommendedVideos = entry
        return entry.value
    }

    func cacheRecommendedVideosFeed(_ videos: [YTVideo]) {
        let now = Date()
        cachedRecommendedVideos = CacheEntry(
            value: videos,
            expirationDate: now.addingTimeInterval(CacheConfiguration.recommendedVideosTTL),
            lastAccessDate: now
        )
    }

    private func evictExpiredVideoDetails() {
        let now = Date()
        cachedVideoDetailsByID = cachedVideoDetailsByID.filter { $0.value.expirationDate > now }
    }

    private func trimVideoDetailsCacheIfNeeded() {
        let overflowCount = cachedVideoDetailsByID.count - CacheConfiguration.videoDetailsLimit
        guard overflowCount > 0 else { return }

        let oldestVideoIDs = cachedVideoDetailsByID
            .sorted { $0.value.lastAccessDate < $1.value.lastAccessDate }
            .prefix(overflowCount)
            .map(\.key)

        oldestVideoIDs.forEach { cachedVideoDetailsByID.removeValue(forKey: $0) }
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
            // Visitor data is opportunistic; callers handle empty visitorData when it is required.
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
