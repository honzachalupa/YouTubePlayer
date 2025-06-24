import SwiftUI
import YouTubeKit

struct RecommendedVideosView: View {
    @EnvironmentObject private var youtubeService: YouTubeService
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil

    func fetchVideos() async {
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
            
            withAnimation {
                videos = response.results
            }
        } catch {
            withAnimation {
                fetchError = error
                videos = []
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VideosGridView(videos: videos, error: fetchError) {
                await fetchVideos()
            }
            .toolbar {
                AccountToolbarItem()
            }
            .navigationTitle("Recommended")
        }
    }
}

#Preview {
    RecommendedVideosView()
        .environmentObject(YouTubeService.shared)
}
