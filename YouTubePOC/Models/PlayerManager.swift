import SwiftUI
import AVKit
import MediaPlayer

@MainActor
class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    @Published var selectedVideo: YouTubeVideo?
    @Published var isVideoSheetPresented = false
    @Published private(set) var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var likeStatus: String = "none"
    @Published var availablePlaylists: [(playlist: YouTubePlaylist, isVideoPresentInside: Bool)] = []
    @Published var temporaryPlaylistStates: [String: [(playlist: YouTubePlaylist, isVideoPresentInside: Bool)]] = [:]
    
    private var playerTimeObserver: Any?
    private let authService: YouTubeAuthService
    private let playlistService = YouTubePlaylistService.shared
    private var thumbnailImage: UIImage?
    
    func clearPlaylistData() {
        availablePlaylists = []
        temporaryPlaylistStates = [:]
    }
    
    init() {
        self.authService = .shared
        
        configureAudioSession()
        setupRemoteTransportControls()
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    nonisolated deinit {
        Task { @MainActor in
            UIApplication.shared.endReceivingRemoteControlEvents()
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session:", error)
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        
        commandCenter.playCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                if let player = self.player {
                    player.play()
                    self.isPlaying = true
                    self.updateNowPlayingInfo()
                }
            }
            
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                if let player = self.player {
                    player.pause()
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                }
            }
            
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                if let player = self.player {
                    let currentTime = player.currentTime()
                    player.seek(to: CMTimeAdd(currentTime, CMTime(seconds: 15, preferredTimescale: 1)))
                    self.updateNowPlayingInfo()
                }
            }
            
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                if let player = self.player {
                    let currentTime = player.currentTime()
                    player.seek(to: CMTimeSubtract(currentTime, CMTime(seconds: 15, preferredTimescale: 1)))
                    self.updateNowPlayingInfo()
                }
            }
            
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let video = selectedVideo else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = video.snippet.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = video.snippet.channelTitle
        
        if let player = player {
            if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            }
            
            let currentTime = player.currentTime().seconds
            if !currentTime.isNaN {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            }
            
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
            nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        }
        
        if let thumbnailImage = thumbnailImage {
            let artwork = MPMediaItemArtwork(boundsSize: thumbnailImage.size) { size in
                return thumbnailImage
            }
            
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func loadThumbnailImage(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            thumbnailImage = UIImage(data: data)
            await MainActor.run {
                updateNowPlayingInfo()
            }
        } catch {
            print("Failed to load thumbnail image:", error)
        }
    }
    
    private func setupPlayerObservation(for player: AVPlayer) {
        if let observer = playerTimeObserver {
            player.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.updateNowPlayingInfo()
            }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    @objc private func playerItemDidPlayToEndTime() {
        Task { @MainActor in
            isPlaying = false
            updateNowPlayingInfo()
        }
    }
    
    func cleanup() {
        player?.pause()
        
        if let observer = playerTimeObserver, let player = player {
            player.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        
        player = nil
        thumbnailImage = nil
        isPlaying = false
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func getPlaylistStates(for video: YouTubeVideo) async -> [(playlist: YouTubePlaylist, isVideoPresentInside: Bool)] {
        if video.id == selectedVideo?.id {
            return availablePlaylists
        }
        
        if let states = temporaryPlaylistStates[video.id] {
            return states
        }
        
        do {
            let playlists = try await playlistService.fetchPlaylists()
            var states: [(playlist: YouTubePlaylist, isVideoPresentInside: Bool)] = []
            
            for playlist in playlists {
                let items = try await playlistService.fetchPlaylistItems(playlistId: playlist.id)
                let isPresent = items.contains { $0.snippet.resourceId.videoId == video.id }
                states.append((playlist: playlist, isVideoPresentInside: isPresent))
            }
            
            temporaryPlaylistStates[video.id] = states
            return states
        } catch {
            print("Failed to fetch playlists for video:", error.localizedDescription)
            return []
        }
    }
    
    func addToPlaylist(_ video: YouTubeVideo, _ playlist: YouTubePlaylist) {
        Task {
            do {
                _ = try await playlistService.addVideoToPlaylist(playlistId: playlist.id, videoId: video.id)
                
                // Update playlist states
                let states = await getPlaylistStates(for: video)
                if video.id == selectedVideo?.id {
                    availablePlaylists = states
                }
                temporaryPlaylistStates[video.id] = states
            } catch {
                print("Failed to add video to playlist:", error.localizedDescription)
            }
        }
    }
    
    func removeFromPlaylist(_ video: YouTubeVideo, _ playlist: YouTubePlaylist) {
        Task {
            do {
                if let itemId = try await playlistService.getPlaylistItemId(playlistId: playlist.id, videoId: video.id) {
                    try await playlistService.removeVideoFromPlaylist(itemId: itemId)
                    
                    // Update playlist states
                    let states = await getPlaylistStates(for: video)
                    if video.id == selectedVideo?.id {
                        availablePlaylists = states
                    }
                    temporaryPlaylistStates[video.id] = states
                }
            } catch {
                print("Failed to remove video from playlist:", error.localizedDescription)
            }
        }
    }
    
    func selectVideo(_ video: YouTubeVideo) {
        if selectedVideo?.id != video.id {
            cleanup()
            selectedVideo = video
        }
        
        isVideoSheetPresented = true
        loadVideo(video)
        
        Task {
            if let thumbnailUrl = URL(string: video.snippet.thumbnails.maxres?.url ?? 
                                    video.snippet.thumbnails.standard?.url ??
                                    video.snippet.thumbnails.high?.url ??
                                    video.snippet.thumbnails.medium?.url ??
                                    video.snippet.thumbnails.default?.url ?? "") {
                await loadThumbnailImage(from: thumbnailUrl)
            }
            
            availablePlaylists = await getPlaylistStates(for: video)
        }
    }
    
    func loadVideo(_ video: YouTubeVideo) {
        isLoading = true
        error = nil
        
        Task {
            guard let videoURL = URL(string: "https://www.youtube.com/watch?v=\(video.id)") else {
                error = "Invalid video URL"
                isLoading = false
                return
            }
            
            let player = AVPlayer(url: videoURL)
            self.player = player
            setupPlayerObservation(for: player)
            
            player.play()
            isPlaying = true
            
            updateNowPlayingInfo()
            isLoading = false
        }
    }
    
    func togglePlayPause() {
        if let player = player {
            if isPlaying {
                player.pause()
            } else {
                player.play()
            }
            isPlaying.toggle()
            updateNowPlayingInfo()
        }
    }
    
    func toggleFullScreen() {
        // This will be handled by the view
    }
    
    func toggleControls() {
        // This will be handled by the view
    }
    
    func toggleLike() {
        switch likeStatus {
            case "liked":
                likeStatus = "none"
            case "disliked":
                likeStatus = "liked"
            default:
                likeStatus = "liked"
        }
    }
    
    func toggleDislike() {
        switch likeStatus {
            case "liked":
                likeStatus = "disliked"
            case "disliked":
                likeStatus = "none"
            default:
                likeStatus = "disliked"
        }
    }
}
