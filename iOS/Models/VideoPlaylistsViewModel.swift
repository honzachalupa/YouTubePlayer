import SwiftUI
import YouTubeKit

@MainActor
class VideoPlaylistsViewModel: ObservableObject {
    @Published var playlistStates: [(playlist: YTPlaylist, isVideoPresentInside: Bool)] = []
    
    private let video: YTVideo
    private let videoManager: VideoManager
    
    init(video: YTVideo, videoManager: VideoManager) {
        self.video = video
        self.videoManager = videoManager
        
        Task {
            await fetchPlaylistStates()
        }
    }
    
    func fetchPlaylistStates() async {
        playlistStates = await videoManager.getPlaylistStates(for: video)
    }
    
    func addToPlaylist(_ playlist: YTPlaylist) async {
        await videoManager.addToPlaylist(playlist)
        await fetchPlaylistStates()
    }
    
    func removeFromPlaylist(_ playlist: YTPlaylist) async {
        await videoManager.removeFromPlaylist(playlist)
        await fetchPlaylistStates()
    }
} 