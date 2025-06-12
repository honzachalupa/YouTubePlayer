import SwiftUI
import YouTubeKit

struct TrendingVideosView: View {
    private var YTM = YouTubeModel()
    @State private var videos: [YTVideo] = []
    
    func fetchVideos() async {
        videos.removeAll()
        
        Task {
            TrendingVideosResponse.sendNonThrowingRequest(youtubeModel: YTM, data: [:], result: { result in
                switch result {
                    case .success(let response):
                        var newVideos: [YTVideo] = []
                        var seenIds = Set<String>()
                        
                        if let currentIdentifier = response.currentContentIdentifier,
                           let videos = response.categoriesContentsStore[currentIdentifier] {
                            for video in videos {
                                if !seenIds.contains(video.videoId) {
                                    seenIds.insert(video.videoId)
                                    newVideos.append(video)
                                }
                            }
                        }
                        
                        Task { @MainActor in
                            videos = newVideos
                        }
                    case .failure(let error):
                        print(error)
                }
            })
        }
    }
    
    var body: some View {
        NavigationStack {
            VideosListView(videos: videos)
                .navigationTitle("Trending")
        }
        .task {
            await fetchVideos()
        }
    }
}

#Preview {
    TrendingVideosView()
}
