import SwiftUI
import YouTubeKit

@MainActor
class VideoPlaylistsViewModel: ObservableObject {
    @Published var playlistStates: [(playlist: YTPlaylist, isVideoPresentInside: Bool)] = []
    
    private let video: YTVideo
    private let playerManager: PlayerManager
    
    init(video: YTVideo, playerManager: PlayerManager) {
        self.video = video
        self.playerManager = playerManager
        
        Task {
            await fetchPlaylistStates()
        }
    }
    
    func fetchPlaylistStates() async {
        playlistStates = await playerManager.getPlaylistStates(for: video)
    }
    
    func addToPlaylist(_ playlist: YTPlaylist) async {
        await playerManager.addToPlaylist(playlist)
        await fetchPlaylistStates()
    }
    
    func removeFromPlaylist(_ playlist: YTPlaylist) async {
        await playerManager.removeFromPlaylist(playlist)
        await fetchPlaylistStates()
    }
} 