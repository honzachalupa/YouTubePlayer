import SwiftUI
import YouTubeKit

struct RecommendedVideosView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let youtubeService = YouTubeService.shared
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil
    @State private var hasLoadedOnce = false
    @State private var foregroundRefreshID = 0

    func fetchVideos(forceRefresh: Bool = false) async {
        if !forceRefresh, videos.isEmpty, let cachedVideos = youtubeService.cachedRecommendedVideosFeed() {
            withAnimation {
                fetchError = nil
                videos = cachedVideos
            }
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
    
    var body: some View {
        VideosGridView(videos: videos, error: fetchError) {
            await fetchVideos()
            hasLoadedOnce = true
        }
        .task(id: foregroundRefreshID) {
            guard foregroundRefreshID > 0 else { return }
            await fetchVideos(forceRefresh: true)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, hasLoadedOnce else { return }
            foregroundRefreshID += 1
        }
        #if os(iOS)
        .navigationTitle("Recommended")
        #endif
    }
}

#Preview {
    RecommendedVideosView()
}
