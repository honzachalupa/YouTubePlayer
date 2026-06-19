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
        static let persistedVideoDetailsTTL: TimeInterval = 48 * 60 * 60
        static let videoDetailsLimit = 25
        static let recommendedVideosTTL: TimeInterval = 5 * 60
        static let persistedVideoDetailsStorageKey = "ytm_persisted_video_details_v1"
    }

    struct CachedVideoDetails {
        let response: MoreVideoInfosResponse
        let description: String?
        let recommendedVideos: [YTVideo]
    }

    struct PersistedVideoDetails {
        let description: String?
        let recommendedVideos: [YTVideo]
    }

    private struct PersistedCacheEntry<Value: Codable>: Codable {
        let value: Value
        let expirationDate: Date
        var lastAccessDate: Date
    }

    private struct PersistedVideoDetailsValue: Codable {
        let description: String?
        let recommendedVideos: [PersistedYTVideo]
    }

    private struct PersistedYTThumbnail: Codable {
        let url: String

        init?(thumbnail: YTThumbnail) {
            url = thumbnail.url.absoluteString
        }

        var model: YTThumbnail? {
            guard let url = URL(string: url) else { return nil }
            return YTThumbnail(url: url)
        }
    }

    private struct PersistedYTLittleChannelInfos: Codable {
        let channelId: String
        let name: String?
        let thumbnails: [PersistedYTThumbnail]

        init(channel: YTLittleChannelInfos) {
            channelId = channel.channelId
            name = channel.name
            thumbnails = channel.thumbnails.compactMap(PersistedYTThumbnail.init)
        }

        var model: YTLittleChannelInfos {
            YTLittleChannelInfos(
                channelId: channelId,
                name: name ?? "",
                thumbnails: thumbnails.compactMap(\.model)
            )
        }
    }

    private struct PersistedYTVideo: Codable {
        let videoId: String
        let title: String?
        let viewCount: String?
        let timePosted: String?
        let timeLength: String?
        let thumbnails: [PersistedYTThumbnail]
        let channel: PersistedYTLittleChannelInfos?

        init(video: YTVideo) {
            videoId = video.videoId
            title = video.title
            viewCount = video.viewCount
            timePosted = video.timePosted
            timeLength = video.timeLength
            thumbnails = video.thumbnails.compactMap(PersistedYTThumbnail.init)
            channel = video.channel.map(PersistedYTLittleChannelInfos.init)
        }

        var model: YTVideo {
            YTVideo(
                videoId: videoId,
                title: title,
                channel: channel?.model,
                viewCount: viewCount,
                timePosted: timePosted,
                timeLength: timeLength,
                thumbnails: thumbnails.compactMap(\.model)
            )
        }
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
    private var persistedVideoDetailsByID: [String: PersistedCacheEntry<PersistedVideoDetailsValue>] = [:]

    func reloadStoredCookies() {
        let storedCookies = Self.storedCookies()
        guard cookies != storedCookies else { return }
        cookies = storedCookies
        alwaysUseCookies = !storedCookies.isEmpty
    }

    private static func storedCookies() -> String {
        #if DEBUG && os(tvOS)
        if let debugCookies = debugTVOSCookies() {
            return debugCookies
        }
        #endif

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

    #if DEBUG && os(tvOS)
    private static func debugTVOSCookies() -> String? {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectRootURL = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let cookiesURL = projectRootURL.appendingPathComponent("DebugTVOSCookies.txt")

        guard let cookies = try? String(contentsOf: cookiesURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !cookies.isEmpty else {
            return nil
        }

        return cookies
    }
    #endif
    
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

        loadPersistedVideoDetailsCache()
        
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
        UserDefaults.standard.removeObject(forKey: CacheConfiguration.persistedVideoDetailsStorageKey)
        UserDefaults.standard.synchronize()
        cachedVideoDetailsByID.removeAll()
        cachedRecommendedVideos = nil
        persistedVideoDetailsByID.removeAll()
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
        cachePersistedVideoDetails(
            description: description,
            recommendedVideos: recommendedVideos,
            for: videoID
        )
    }

    func cachedPersistedDetails(for videoID: String) -> PersistedVideoDetails? {
        evictExpiredPersistedVideoDetails()

        guard var entry = persistedVideoDetailsByID[videoID] else { return nil }

        entry.lastAccessDate = Date()
        persistedVideoDetailsByID[videoID] = entry
        savePersistedVideoDetailsCache()

        return PersistedVideoDetails(
            description: entry.value.description,
            recommendedVideos: entry.value.recommendedVideos.map(\.model)
        )
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

    private func loadPersistedVideoDetailsCache() {
        guard let data = UserDefaults.standard.data(forKey: CacheConfiguration.persistedVideoDetailsStorageKey) else {
            persistedVideoDetailsByID = [:]
            return
        }

        do {
            persistedVideoDetailsByID = try JSONDecoder().decode(
                [String: PersistedCacheEntry<PersistedVideoDetailsValue>].self,
                from: data
            )
            evictExpiredPersistedVideoDetails()
        } catch {
            persistedVideoDetailsByID = [:]
            UserDefaults.standard.removeObject(forKey: CacheConfiguration.persistedVideoDetailsStorageKey)
        }
    }

    private func savePersistedVideoDetailsCache() {
        do {
            let data = try JSONEncoder().encode(persistedVideoDetailsByID)
            UserDefaults.standard.set(data, forKey: CacheConfiguration.persistedVideoDetailsStorageKey)
        } catch {
            print("YouTubeService: Failed to persist video details cache:", error)
        }
    }

    private func cachePersistedVideoDetails(
        description: String?,
        recommendedVideos: [YTVideo],
        for videoID: String
    ) {
        evictExpiredPersistedVideoDetails()
        let now = Date()
        persistedVideoDetailsByID[videoID] = PersistedCacheEntry(
            value: PersistedVideoDetailsValue(
                description: description,
                recommendedVideos: recommendedVideos.map(PersistedYTVideo.init)
            ),
            expirationDate: now.addingTimeInterval(CacheConfiguration.persistedVideoDetailsTTL),
            lastAccessDate: now
        )
        trimPersistedVideoDetailsCacheIfNeeded()
        savePersistedVideoDetailsCache()
    }

    private func evictExpiredPersistedVideoDetails() {
        let now = Date()
        let originalCount = persistedVideoDetailsByID.count
        persistedVideoDetailsByID = persistedVideoDetailsByID.filter { $0.value.expirationDate > now }
        if persistedVideoDetailsByID.count != originalCount {
            savePersistedVideoDetailsCache()
        }
    }

    private func trimPersistedVideoDetailsCacheIfNeeded() {
        let overflowCount = persistedVideoDetailsByID.count - CacheConfiguration.videoDetailsLimit
        guard overflowCount > 0 else { return }

        let oldestVideoIDs = persistedVideoDetailsByID
            .sorted { $0.value.lastAccessDate < $1.value.lastAccessDate }
            .prefix(overflowCount)
            .map(\.key)

        oldestVideoIDs.forEach { persistedVideoDetailsByID.removeValue(forKey: $0) }
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
