import SwiftUI
import YouTubeKit

struct RecommendedVideosView: View {
    private let youtubeService = YouTubeService.shared
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil

    func fetchVideos() async {
        if videos.isEmpty, let cachedVideos = youtubeService.cachedRecommendedVideosFeed() {
            withAnimation {
                fetchError = nil
                videos = cachedVideos
            }
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
    
    var body: some View {
        VideosGridView(videos: videos, error: fetchError) {
            await fetchVideos()
        }
        #if os(iOS)
        .navigationTitle("Recommended")
        #endif
    }
}

#Preview {
    RecommendedVideosView()
}
