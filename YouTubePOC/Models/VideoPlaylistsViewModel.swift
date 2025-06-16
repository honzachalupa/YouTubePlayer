import SwiftUI
import YouTubeKit

@MainActor
class VideoPlaylistsViewModel: ObservableObject {
    @Published var playlistStates: [(playlist: YTPlaylist, isVideoPresentInside: Bool)] = []
    
    private let video: YTVideo
    private var playerManager: PlayerManager
    
    init(video: YTVideo, playerManager: PlayerManager) {
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
    
    func addToPlaylist(_ playlist: YTPlaylist) {
        playerManager.addToPlaylist(video, playlist)
        Task {
            await fetchPlaylistStates()
        }
    }
    
    func removeFromPlaylist(_ playlist: YTPlaylist) {
        playerManager.removeFromPlaylist(video, playlist)
        Task {
            await fetchPlaylistStates()
        }
    }
} 