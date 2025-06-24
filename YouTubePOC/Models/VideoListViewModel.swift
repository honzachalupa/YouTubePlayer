import Foundation
import YouTubeKit
import SwiftUI

@MainActor
class VideoListViewModel: ObservableObject {
    @Published var videos: [YTVideo] = []
    @Published var error: String?
    @Published var isFetching = false
    @Published var hasMoreVideos = true

    // A closure that performs the actual network request and returns the videos and continuation token.
    private let videoFetcher: (String?) async throws -> (videos: [YTVideo], continuation: String?)
    private var currentContinuation: String?

    init(videoFetcher: @escaping (String?) async throws -> (videos: [YTVideo], continuation: String?)) {
        self.videoFetcher = videoFetcher
    }
    
    // Convenience initializer for SwiftUI Previews with static data
    convenience init(staticVideos: [YTVideo]) {
        self.init(videoFetcher: { _ in return (videos: staticVideos, continuation: nil) })
        self.videos = staticVideos
        self.hasMoreVideos = false
    }

    func fetchVideos(loadMore: Bool = false) async {
        guard !isFetching else { return }
        
        isFetching = true
        error = nil
        
        // Clear videos only if this is not a "load more" operation
        if !loadMore {
            videos.removeAll()
            currentContinuation = nil
        }
        
        do {
            let result = try await videoFetcher(currentContinuation)
            
            withAnimation {
                if loadMore {
                    videos.append(contentsOf: result.videos)
                } else {
                    videos = result.videos
                }
                
                currentContinuation = result.continuation
                hasMoreVideos = result.continuation != nil
                
                if videos.isEmpty && !loadMore {
                    error = "No videos available. Please try again later."
                }
            }
        } catch {
            self.error = error.localizedDescription
            print("Failed to fetch videos: \(error)")
        }
        
        isFetching = false
    }
    
    func loadMoreIfNeeded(currentVideo video: YTVideo) {
        print("[VideoListViewModel] loadMoreIfNeeded")
        
        guard let lastVideo = videos.last,
              lastVideo.videoId == video.videoId,
              hasMoreVideos,
              !isFetching else {
            return
        }
        
        Task {
            print("[VideoListViewModel] loadMoreIfNeeded - fetchVideos")
            await fetchVideos(loadMore: true)
        }
    }
} 
