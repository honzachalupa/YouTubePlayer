import SwiftUI
import YouTubeKit

struct HomeVideosView: View {
    private var YTM = YouTubeModel()
    @State private var videos: [YTVideo] = []
    
    func fetchVideos() async {
        videos.removeAll()
        
        Task {
            HomeScreenResponse.sendNonThrowingRequest(youtubeModel: YTM, data: [:], result: { result in
                switch result {
                    case .success(let response):
                        var newVideos: [YTVideo] = []
                        var seenIds = Set<String>()
                        
                        print("response.results", response.results)
                        
                        for video in response.results {
                            if !seenIds.contains(video.videoId) {
                                seenIds.insert(video.videoId)
                                newVideos.append(video)
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
                .navigationTitle("Subscriptions")
        }
        .task {
            await fetchVideos()
        }
    }
}

#Preview {
    HomeVideosView()
}
