import SwiftUI
import YouTubeKit

private enum SubscriptionsVideosCacheConfig {
    // Set to false to disable persisted subscriptions videos cache during testing.
    static let isEnabled = false
    static let storageKey = "subscriptions_videos_cache_v1"
}

private enum SubscriptionsVideosPagingConfig {
    // Number of videos shown initially and appended for each infinite-scroll batch.
    static let pageSize = 16
}

private struct CachedSubscriptionsVideos: Codable {
    let videos: [CachedYTVideo]
}

private struct CachedYTThumbnail: Codable {
    let url: String
    
    init?(thumbnail: YTThumbnail) {
        self.url = thumbnail.url.absoluteString
    }
    
    var model: YTThumbnail? {
        guard let url = URL(string: url) else { return nil }
        return YTThumbnail(url: url)
    }
}

private struct CachedYTLittleChannelInfos: Codable {
    let channelId: String
    let name: String?
    let thumbnails: [CachedYTThumbnail]
    
    init(channel: YTLittleChannelInfos) {
        self.channelId = channel.channelId
        self.name = channel.name
        self.thumbnails = channel.thumbnails.compactMap(CachedYTThumbnail.init)
    }
    
    var model: YTLittleChannelInfos {
        YTLittleChannelInfos(
            channelId: channelId,
            name: name ?? "",
            thumbnails: thumbnails.compactMap(\.model)
        )
    }
}

private struct CachedYTVideo: Codable {
    let videoId: String
    let title: String?
    let viewCount: String?
    let timePosted: String?
    let timeLength: String?
    let thumbnails: [CachedYTThumbnail]
    let channel: CachedYTLittleChannelInfos?
    
    init(video: YTVideo) {
        self.videoId = video.videoId
        self.title = video.title
        self.viewCount = video.viewCount
        self.timePosted = video.timePosted
        self.timeLength = video.timeLength
        self.thumbnails = video.thumbnails.compactMap(CachedYTThumbnail.init)
        self.channel = video.channel.map(CachedYTLittleChannelInfos.init)
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

private enum SubscriptionsVideosCache {
    static func loadVideos() -> [YTVideo] {
        guard SubscriptionsVideosCacheConfig.isEnabled,
              let data = UserDefaults.standard.data(forKey: SubscriptionsVideosCacheConfig.storageKey)
        else {
            return []
        }
        
        do {
            return try JSONDecoder()
                .decode(CachedSubscriptionsVideos.self, from: data)
                .videos
                .map(\.model)
        } catch {
            print("Subscriptions cache decode failed: \(error)")
            return []
        }
    }
    
    static func save(_ videos: [YTVideo]) {
        guard SubscriptionsVideosCacheConfig.isEnabled else { return }
        
        do {
            let payload = CachedSubscriptionsVideos(videos: videos.map(CachedYTVideo.init))
            let data = try JSONEncoder().encode(payload)
            UserDefaults.standard.set(data, forKey: SubscriptionsVideosCacheConfig.storageKey)
        } catch {
            print("Subscriptions cache encode failed: \(error)")
        }
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: SubscriptionsVideosCacheConfig.storageKey)
    }
}

struct SubscriptionsVideosView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let youtubeService = YouTubeService.shared
    private let authService = YouTubeAuthService.shared
    @State private var allVideos: [YTVideo]
    @State private var videos: [YTVideo]
    @State private var fetchError: Error? = nil
    @State private var isLoadingMoreVisibleItems = false
    @State private var hasLoadedOnce = false
    @State private var foregroundRefreshToken = UUID()
    
    init() {
        let cachedVideos = SubscriptionsVideosCache.loadVideos()
        _allVideos = State(initialValue: cachedVideos)
        _videos = State(initialValue: Array(cachedVideos.prefix(SubscriptionsVideosPagingConfig.pageSize)))
    }
    
    private func setPagedVideos(_ source: [YTVideo]) {
        allVideos = source
        videos = Array(source.prefix(SubscriptionsVideosPagingConfig.pageSize))
    }
    
    private func loadMoreIfNeeded(currentVideo: YTVideo) {
        guard !isLoadingMoreVisibleItems else { return }
        guard let lastVisible = videos.last,
              lastVisible.videoId == currentVideo.videoId
        else {
            return
        }
        
        guard videos.count < allVideos.count else { return }
        
        isLoadingMoreVisibleItems = true
        let startIndex = videos.count
        let nextEndIndex = min(startIndex + SubscriptionsVideosPagingConfig.pageSize, allVideos.count)
        
        Task { @MainActor in
            await Task.yield()
            videos.append(contentsOf: allVideos[startIndex..<nextEndIndex])
            isLoadingMoreVisibleItems = false
        }
    }
    
    private func isRegularVideo(_ video: YTVideo) -> Bool {
        guard let timeLength = video.timeLength?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !timeLength.isEmpty
        else {
            return false
        }
        
        if timeLength == "live" {
            return true
        }
        
        return timeLength.contains(":")
    }

    func fetchVideos() async {
        guard authService.isAuthenticated else {
            withAnimation {
                fetchError = NSError(
                    domain: "YouTubeAuth",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please sign in."]
                )
                allVideos = []
                videos = []
                isLoadingMoreVisibleItems = false
            }
            if SubscriptionsVideosCacheConfig.isEnabled {
                SubscriptionsVideosCache.clear()
            }
            return
        }
        do {
            fetchError = nil

            // First ensure we have visitor data
            await youtubeService.getVisitorData()
            
            // Set proper locale format (language_COUNTRY)
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            youtubeService.model.selectedLocale = locale
            
            // Create request data
            let data: [HeadersList.AddQueryInfo.ContentTypes: String] = [
                .visitorData: youtubeService.model.visitorData
            ]
            
            let response = try await AccountSubscriptionsFeedResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: data,
                useCookies: true
            )
            
            guard !response.isDisconnected else {
                withAnimation {
                    fetchError = NSError(
                        domain: "YouTubeAuth",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please sign in."]
                    )
                    allVideos = []
                    videos = []
                    isLoadingMoreVisibleItems = false
                }
                return
            }
            
            var seenIds = Set<String>()
            let feedVideos = response.results.compactMap { video -> YTVideo? in
                guard !video.videoId.isEmpty, !seenIds.contains(video.videoId) else { return nil }
                seenIds.insert(video.videoId)

                guard isRegularVideo(video) else { return nil }
                return video
            }
            
            withAnimation {
                setPagedVideos(feedVideos)
            }
            SubscriptionsVideosCache.save(feedVideos)
        } catch {
            withAnimation {
                fetchError = error
                if videos.isEmpty {
                    setPagedVideos(SubscriptionsVideosCache.loadVideos())
                }
            }
        }
    }
    
    var body: some View {
        VideosGridView(videos: videos, error: fetchError, fetchVideos: {
            await fetchVideos()
            hasLoadedOnce = true
        }, loadMoreIfNeeded: { video in
            loadMoreIfNeeded(currentVideo: video)
        }, isLoadingMore: isLoadingMoreVisibleItems)
        .task(id: foregroundRefreshToken) {
            guard hasLoadedOnce else { return }
            await fetchVideos()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, hasLoadedOnce else { return }
            foregroundRefreshToken = UUID()
        }
        // Recreate grid when backing dataset size changes so viewport auto-fill can retry.
        .id("subscriptions-grid-\(allVideos.count)")
        #if os(iOS)
        .navigationTitle("Subscriptions")
        #endif
    }
}

#Preview {
    SubscriptionsVideosView()
}
