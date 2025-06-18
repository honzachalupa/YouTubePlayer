import Foundation

@MainActor
class VideoListViewModel: ObservableObject {
    @Published var videos: [YouTubeVideo] = []
    @Published var error: String?
    @Published var isFetching = false

    // A closure that performs the actual network request and returns the videos.
    private let videoFetcher: () async throws -> [YouTubeVideo]

    init(videoFetcher: @escaping () async throws -> [YouTubeVideo]) {
        self.videoFetcher = videoFetcher
    }
    
    // Convenience initializer for SwiftUI Previews with static data
    convenience init(staticVideos: [YouTubeVideo]) {
        self.init(videoFetcher: { return staticVideos })
        self.videos = staticVideos
    }

    func fetchVideos() async {
        isFetching = true
        error = nil
        // videos.removeAll() // Keep existing videos while loading more? For now, we clear them.
        
        do {
            let fetchedVideos = try await videoFetcher()
            videos = fetchedVideos
            if videos.isEmpty {
                error = "No videos available. Please try again later."
            }
        } catch {
            self.error = error.localizedDescription
            print("Failed to fetch videos: \(error)")
        }
        
        isFetching = false
    }
} 