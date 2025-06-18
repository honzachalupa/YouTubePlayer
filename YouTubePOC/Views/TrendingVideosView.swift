import SwiftUI

struct TrendingVideosView: View {
    @StateObject private var videoService = YouTubeVideoService.shared
    
    var body: some View {
        VideosGridView(
            videos: videoService.videos,
            title: "Trending",
            isLoading: videoService.isLoading,
            onLoadMore: {
                await videoService.fetchTrendingVideos()
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
    TrendingVideosView()
}
