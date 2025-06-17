import SwiftUI
import AVKit
import YouTubeKit
import MediaPlayer

@MainActor
class PlayerManager: ObservableObject {
    @Published var selectedVideo: YTVideo?
    @Published var isVideoSheetPresented = false
    @Published private(set) var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var likeStatus: YTLikeStatus = .nothing
    @Published var availablePlaylists: [(playlist: YTPlaylist, isVideoPresentInside: Bool)] = []
    @Published var temporaryPlaylistStates: [String: [(playlist: YTPlaylist, isVideoPresentInside: Bool)]] = [:]
    
    private var playerTimeObserver: Any?
    private let authService: YouTubeAuthService
    private let playlistService = YouTubePlaylistService.shared
    private var thumbnailImage: UIImage?
    
    init() {
        self.authService = .shared
        
        // Configure audio session first
        configureAudioSession()
        
        // Then set up remote controls
        setupRemoteTransportControls()
        
        // Begin receiving remote control events
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
        // Get the shared command center
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Remove any existing handlers
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        
        // Enable commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        
        // Add handler for play command
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
        
        // Add handler for pause command
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
        
        // Add handler for skip forward command
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
        
        // Add handler for skip backward command
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
        
        // Set the title and artist
        nowPlayingInfo[MPMediaItemPropertyTitle] = video.title ?? "Unknown Title"
        nowPlayingInfo[MPMediaItemPropertyArtist] = video.channel?.name ?? "Unknown Channel"
        
        // Set playback info if player exists
        if let player = player {
            // Duration
            if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            }
            
            // Current time
            let currentTime = player.currentTime().seconds
            if !currentTime.isNaN {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            }
            
            // Playback rate
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
            
            // Default playback rate
            nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        }
        
        // Set the artwork if we have it
        if let thumbnailImage = thumbnailImage {
            let artwork = MPMediaItemArtwork(boundsSize: thumbnailImage.size) { size in
                return thumbnailImage
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // Update the now playing info
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
        // Remove previous observer if any
        if let observer = playerTimeObserver {
            player.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        
        // Add new observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateNowPlayingInfo()
            }
        }
        
        // Observe player status changes
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
        // Stop playback
        player?.pause()
        
        // Remove time observer
        if let observer = playerTimeObserver, let player = player {
            player.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Clear player and thumbnail
        player = nil
        thumbnailImage = nil
        isPlaying = false
        
        // Clear now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func getPlaylistStates(for video: YTVideo) async -> [(playlist: YTPlaylist, isVideoPresentInside: Bool)] {
        // If this is the selected video, use the main availablePlaylists
        if video.videoId == selectedVideo?.videoId {
            return availablePlaylists
        }
        
        // If we have temporary states for this video, use those
        if let states = temporaryPlaylistStates[video.videoId] {
            return states
        }
        
        // Otherwise fetch playlists for this specific video
        do {
            let response = try await video.fetchAllPossibleHostPlaylistsThrowing(youtubeModel: YTM.model)
            temporaryPlaylistStates[video.videoId] = response.playlistsAndStatus
            return response.playlistsAndStatus
        } catch {
            print("Failed to fetch playlists for video:", error.localizedDescription)
            return []
        }
    }
    
    func selectVideo(_ video: YTVideo) {
        // Only update if it's a different video
        if selectedVideo?.videoId != video.videoId {
            cleanup()
            selectedVideo = video
        }
        isVideoSheetPresented = true
        loadVideo(video)
        Task {
            await fetchPlaylists(for: video)
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    @MainActor
    func loadVideo(_ video: YTVideo) {
        print("Starting to load video:", video.videoId)
        
        // If it's the same video and we already have a player, just play it
        if let currentVideo = selectedVideo, currentVideo.videoId == video.videoId, let existingPlayer = player {
            print("Same video already loaded, just playing")
            // Only play if not already playing
            if !isPlaying {
                existingPlayer.play()
                isPlaying = true
                updateNowPlayingInfo()
            }
            return
        }
        
        // Clean up previous player
        cleanup()
        
        // Update selected video
        selectedVideo = video
        isLoading = true
        error = nil
        
        // Load thumbnail for lock screen controls
        if let thumbnailURLString = video.thumbnails.last?.url.absoluteString,
           let thumbnailURL = URL(string: thumbnailURLString) {
            Task {
                await loadThumbnailImage(from: thumbnailURL)
            }
        }
        
        // Get visitor data if needed
        Task {
            do {
                print("Getting visitor data...")
                if YTM.model.visitorData.isEmpty {
                    if let visitorData = try? await SearchResponse.sendThrowingRequest(
                        youtubeModel: YTM.model,
                        data: [.query: "homefwhfjoifj"],
                        useCookies: true
                    ).visitorData {
                        YTM.model.visitorData = visitorData
                        print("Using new visitor data")
                    } else {
                        print("Couldn't get visitorData")
                    }
                } else {
                    print("Using existing visitor data")
                }
                
                // First get more info about the video
                print("Getting video info...")
                let _ = try await video.fetchMoreInfosThrowing(youtubeModel: YTM.model, useCookies: true)
                
                // Now get the streaming URL (with cookies disabled as per library requirement)
                print("Fetching streaming info...")
                let streamingInfos = try await video.fetchStreamingInfosThrowing(youtubeModel: YTM.model, useCookies: false)
                
                guard let streamingURL = streamingInfos.streamingURL else {
                    error = "Failed to get video streaming URL"
                    isLoading = false
                    return
                }
                
                // Create and configure player
                let playerItem = AVPlayerItem(url: streamingURL)
                let newPlayer = AVPlayer(playerItem: playerItem)
                
                // Enable background playback
                newPlayer.preventsDisplaySleepDuringVideoPlayback = false
                newPlayer.allowsExternalPlayback = true
                
                // Set up audio session again to ensure it's active
                configureAudioSession()
                
                player = newPlayer
                setupPlayerObservation(for: newPlayer)
                
                // Start playback
                player?.play()
                isPlaying = true
                isLoading = false
                
                // Update now playing info
                updateNowPlayingInfo()
                
            } catch {
                self.error = "Error loading video: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func toggleLike() {
        Task {
            do {
                switch likeStatus {
                    case .nothing:
                        try await selectedVideo?.likeVideoThrowing(youtubeModel: YTM.model)
                        likeStatus = .liked
                    case .liked:
                        try await selectedVideo?.removeLikeFromVideoThrowing(youtubeModel: YTM.model)
                        likeStatus = .nothing
                    case .disliked:
                        try await selectedVideo?.likeVideoThrowing(youtubeModel: YTM.model)
                        likeStatus = .liked
                }
            } catch {
                self.error = "Failed to update like status: \(error.localizedDescription)"
            }
        }
    }
    
    func toggleDislike() {
        Task {
            do {
                switch likeStatus {
                    case .nothing:
                        try await selectedVideo?.dislikeVideoThrowing(youtubeModel: YTM.model)
                        likeStatus = .disliked
                    case .liked:
                        try await selectedVideo?.dislikeVideoThrowing(youtubeModel: YTM.model)
                        likeStatus = .disliked
                    case .disliked:
                        try await selectedVideo?.removeLikeFromVideoThrowing(youtubeModel: YTM.model)
                        likeStatus = .nothing
                }
            } catch {
                self.error = "Failed to update like status: \(error.localizedDescription)"
            }
        }
    }
    
    private func fetchPlaylists(for video: YTVideo) async {
        do {
            let response = try await video.fetchAllPossibleHostPlaylistsThrowing(youtubeModel: YTM.model)
            
            withAnimation {
                availablePlaylists = response.playlistsAndStatus.map { item in
                    (playlist: item.playlist, isVideoPresentInside: item.isVideoPresentInside)
                }
            }
        } catch {
            print("Failed to fetch playlists:", error.localizedDescription)
            withAnimation {
                availablePlaylists = []
            }
        }
    }
    
    func addToPlaylist(_ video: YTVideo, _ playlist: YTPlaylist) {
        Task {
            do {
                let response = try await AddVideoToPlaylistResponse.sendThrowingRequest(
                    youtubeModel: YTM.model,
                    data: [
                        .movingVideoId: video.videoId,
                        .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId
                    ]
                )
                
                if response.success {
                    await fetchPlaylists(for: video)
                } else {
                    error = "Failed to add video to playlist"
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    func removeFromPlaylist(_ video: YTVideo, _ playlist: YTPlaylist) {
        Task {
            do {
                let response = try await RemoveVideoByIdFromPlaylistResponse.sendThrowingRequest(
                    youtubeModel: YTM.model,
                    data: [
                        .movingVideoId: video.videoId,
                        .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId
                    ],
                    useCookies: true
                )
                
                if response.success {
                    await fetchPlaylists(for: video)
                } else {
                    error = "Failed to remove video from playlist"
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
