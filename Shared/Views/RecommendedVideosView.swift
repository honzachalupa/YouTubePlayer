import SwiftUI
import YouTubeKit

struct RecommendedVideosView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let youtubeService = YouTubeService.shared
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil
    @State private var hasLoadedOnce = false
    @State private var foregroundRefreshToken = UUID()

    @discardableResult
    private func showCachedVideosIfNeeded() -> Bool {
        guard videos.isEmpty, let cachedVideos = youtubeService.cachedRecommendedVideosFeed() else {
            return false
        }

        withAnimation {
            fetchError = nil
            videos = cachedVideos
        }

        return true
    }

    func fetchVideos(forceRefresh: Bool = false) async {
        if !forceRefresh, showCachedVideosIfNeeded() {
            return
        }

        do {
            // First ensure we have visitor data
            await youtubeService.getVisitorData()
            
            // Set proper locale format (language_COUNTRY)
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            youtubeService.model.selectedLocale = locale
            
            // Create request data
            let data: [HeadersList.AddQueryInfo.ContentTypes: String] = [
                .visitorData: youtubeService.model.visitorData
            ]
            
            let response = try await HomeScreenResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: data,
                useCookies: true
            )

            youtubeService.cacheRecommendedVideosFeed(response.results)
            
            withAnimation {
                fetchError = nil
                videos = response.results
            }
        } catch {
            withAnimation {
                if let cachedVideos = youtubeService.cachedRecommendedVideosFeed() {
                    fetchError = nil
                    videos = cachedVideos
                } else {
                    fetchError = error
                    videos = []
                }
            }
        }
    }

    private func showCachedThenRefreshVideos() async {
        showCachedVideosIfNeeded()
        await fetchVideos(forceRefresh: true)
    }
    
    var body: some View {
        VideosGridView(videos: videos, error: fetchError) {
            await showCachedThenRefreshVideos()
            hasLoadedOnce = true
        }
        .task(id: foregroundRefreshToken) {
            guard hasLoadedOnce else { return }
            await fetchVideos(forceRefresh: true)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, hasLoadedOnce else { return }
            foregroundRefreshToken = UUID()
        }
        #if os(iOS)
        .navigationTitle("Recommended")
        #endif
    }
}

#Preview {
    RecommendedVideosView()
}
