import SwiftUI

struct RecommendedVideosView: View {
    @StateObject private var videoService = YouTubeVideoService.shared
    
    var body: some View {
        VideosGridView(
            videos: videoService.videos,
            title: "Recommended",
            isLoading: videoService.isLoading,
            onLoadMore: {
                await videoService.fetchTrendingVideos() // For now, we'll show trending videos as recommendations
            }
        )
        .alert("Error", isPresented: .constant(videoService.error != nil)) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(videoService.error ?? "Unknown error")
        }
    }
}

#Preview {
    RecommendedVideosView()
}
