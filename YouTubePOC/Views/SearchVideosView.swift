import SwiftUI
import YouTubeKit

struct SearchVideosView: View {
    private var YTM = YouTubeModel()
    @State private var query: String = "WWDC 2025 SwiftUI"
    @State private var videos: [YTVideo] = []
    
    func fetchVideosSearch() async {
        videos.removeAll()
        
        Task {
            do {
                let response = try await SearchResponse.sendThrowingRequest(youtubeModel: YTM, data: [.query: query])
                var newVideos: [YTVideo] = []
                
                for result in response.results {
                    if let video = result as? YTVideo {
                        newVideos.append(video)
                    }
                }
                
                await MainActor.run {
                    self.videos = newVideos
                }
            } catch {
                print("Failed to get a response: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    TextField("Search", text: $query)
                    
                    Button {
                        Task { await fetchVideosSearch() }
                    } label: {
                        Text("Search")
                    }
                }
            }
            .frame(height: 65)
            .navigationTitle("Search")
            
            VideosListView(videos: videos)
        }
        .task {
            await fetchVideosSearch()
        }
    }
}

#Preview {
    SearchVideosView()
}
