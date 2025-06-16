import SwiftUI
import YouTubeKit

struct RecommendedVideosView: View {
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil

    func fetchVideos() async {
        do {
            let response = try await HomeScreenResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [:]
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
}
