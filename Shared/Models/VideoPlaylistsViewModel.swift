import SwiftUI
import YouTubeKit
import Combine

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
        await videoManager.addVideo(video, to: playlist)
        await fetchPlaylistStates()
    }
    
    func removeFromPlaylist(_ playlist: YTPlaylist) async {
        await videoManager.removeVideo(video, from: playlist)
        await fetchPlaylistStates()
    }
} 
