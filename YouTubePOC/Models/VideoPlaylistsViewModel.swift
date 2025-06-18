import SwiftUI

@MainActor
class VideoPlaylistsViewModel: ObservableObject {
    @Published var playlistStates: [(playlist: YouTubePlaylist, isVideoPresentInside: Bool)] = []
    
    private let video: YouTubeVideo
    private var playerManager: PlayerManager
    
    init(video: YouTubeVideo, playerManager: PlayerManager) {
        self.video = video
        self.playerManager = playerManager
        
        Task {
            await fetchPlaylistStates()
        }
    }
    
    func updatePlayerManager(_ newPlayerManager: PlayerManager) {
        if self.playerManager !== newPlayerManager {
            self.playerManager = newPlayerManager
            Task {
                await fetchPlaylistStates()
            }
        }
    }
    
    func fetchPlaylistStates() async {
        playlistStates = await playerManager.getPlaylistStates(for: video)
    }
    
    func addToPlaylist(_ playlist: YouTubePlaylist) {
        playerManager.addToPlaylist(video, playlist)
        Task {
            await fetchPlaylistStates()
        }
    }
    
    func removeFromPlaylist(_ playlist: YouTubePlaylist) {
        playerManager.removeFromPlaylist(video, playlist)
        Task {
            await fetchPlaylistStates()
        }
    }
} 