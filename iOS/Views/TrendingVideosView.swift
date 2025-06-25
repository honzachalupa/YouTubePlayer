import SwiftUI
import YouTubeKit

struct TrendingVideosView: View {
    /* @StateObject private var viewModel = VideoListViewModel(videoFetcher: {
        let response = try await TrendingVideosResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [:])
        
        // The trending response has a specific structure we need to handle.
        var newVideos: [YTVideo] = []
        var seenIds = Set<String>()

        if let currentIdentifier = response.currentContentIdentifier,
           let categoryVideos = response.categoriesContentsStore[currentIdentifier] {
            for video in categoryVideos {
                if !seenIds.contains(video.videoId) {
                    seenIds.insert(video.videoId)
                    newVideos.append(video)
                }
            }
        } else {
            // Fallback if the primary category isn't found
            for (_, videos) in response.categoriesContentsStore {
                for video in videos {
                    if !seenIds.contains(video.videoId) {
                        seenIds.insert(video.videoId)
                        newVideos.append(video)
                    }
                }
                if !newVideos.isEmpty {
                    break
                }
            }
        }
        return newVideos
    })

    var body: some View {
        VideosGridView(viewModel: viewModel, navigationTitle: "Trending")
    } */
    
    var body: some View {
        Text("TrendingVideosView")
    }
}

#Preview {
    TrendingVideosView()
}
