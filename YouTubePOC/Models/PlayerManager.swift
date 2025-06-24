import SwiftUI
import AVKit
import YouTubeKit
import MediaPlayer

@MainActor
class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
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
    private var currentPlayer: AVPlayer?
    private let authService: YouTubeAuthService
    private let playlistService = YouTubePlaylistService.shared
    private let youtubeService = YouTubeService.shared
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
            if let observer = playerTimeObserver, let player = currentPlayer {
                player.removeTimeObserver(observer)
            }
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
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                self.player?.play()
                self.isPlaying = true
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                self.player?.pause()
                self.isPlaying = false
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            
            Task { @MainActor in
                if self.isPlaying {
                    self.player?.pause()
                    self.isPlaying = false
                } else {
                    self.player?.play()
                    self.isPlaying = true
                }
            }
            return .success
        }
        
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            
            Task { @MainActor in
                if let currentTime = self.player?.currentTime() {
                    let newTime = CMTimeSubtract(currentTime, CMTime(seconds: skipEvent.interval, preferredTimescale: 1))
                    self.player?.seek(to: newTime)
                }
            }
            return .success
        }
        
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            
            Task { @MainActor in
                if let currentTime = self.player?.currentTime() {
                    let newTime = CMTimeAdd(currentTime, CMTime(seconds: skipEvent.interval, preferredTimescale: 1))
                    self.player?.seek(to: newTime)
                }
            }
            return .success
        }
    }
    
    private func setupPlayerObservation(for player: AVPlayer) {
        // Remove any existing time observer from the current player
        if let observer = playerTimeObserver, let oldPlayer = currentPlayer {
            oldPlayer.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        
        // Store the new player as current
        currentPlayer = player
        
        // Add new time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Update now playing info
                if let currentItem = player.currentItem {
                    var nowPlayingInfo = [String: Any]()
                    
                    // Title
                    if let title = self.selectedVideo?.title {
                        nowPlayingInfo[MPMediaItemPropertyTitle] = title
                    }
                    
                    // Artist (channel name)
                    if let channelName = self.selectedVideo?.channel?.name {
                        nowPlayingInfo[MPMediaItemPropertyArtist] = channelName
                    }
                    
                    // Duration
                    let duration = currentItem.duration
                    if !duration.isIndefinite {
                        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration.seconds
                    }
                    
                    // Current playback time
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
                    
                    // Playback rate
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
                    
                    // Artwork
                    if let thumbnailImage = self.thumbnailImage {
                        let artwork = MPMediaItemArtwork(boundsSize: thumbnailImage.size) { _ in
                            return thumbnailImage
                        }
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    }
                    
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }
    
    func loadVideo(_ video: YTVideo) async {
        isLoading = true
        error = nil
        
        do {
            // First ensure we have visitor data
            if youtubeService.model.visitorData.isEmpty {
                let homeResponse = try await HomeScreenResponse.sendThrowingRequest(
                    youtubeModel: youtubeService.model,
                    data: [:],
                    useCookies: true
                )
                
                if let visitorData = homeResponse.visitorData {
                    youtubeService.model.visitorData = visitorData
                }
            }
            
            // Get video info and streaming URL
            _ = try await video.fetchMoreInfosThrowing(
                youtubeModel: youtubeService.model,
                useCookies: true
            )
            
            let streamingInfos = try await video.fetchStreamingInfosThrowing(
                youtubeModel: youtubeService.model,
                useCookies: false
            )
            
            guard let streamingURL = streamingInfos.streamingURL else {
                error = "Failed to get video streaming URL"
                isLoading = false
                return
            }
            
            // Load thumbnail for now playing info
            if let thumbnailURL = video.thumbnails.first?.url {
                if let data = try? await URLSession.shared.data(from: thumbnailURL).0 {
                    thumbnailImage = UIImage(data: data)
                }
            }
            
            // Create and configure player
            let newPlayer = AVPlayer(url: streamingURL)
            setupPlayerObservation(for: newPlayer)
            
            // Update state
            withAnimation {
                selectedVideo = video
                player = newPlayer
                isPlaying = true
                // Like status will be fetched separately
                likeStatus = .nothing
            }
            
            // Start playback
            newPlayer.play()
            
            // Load playlists state
            await loadPlaylistStates()
            
        } catch let error as ResponseExtractionError {
            self.error = error.stepDescription.contains("Login is required") ?
                "Authentication required. Please sign in." :
                "Failed to load video: \(error.localizedDescription)"
        } catch {
            self.error = "Failed to load video: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadPlaylistStates() async {
        guard let video = selectedVideo else { return }
        
        do {
            let response = try await video.fetchAllPossibleHostPlaylistsThrowing(
                youtubeModel: youtubeService.model
            )
            
            withAnimation {
                availablePlaylists = response.playlistsAndStatus
            }
        } catch {
            print("Error loading playlist states:", error)
        }
    }
    
    func addToPlaylist(_ playlist: YTPlaylist) async {
        guard let video = selectedVideo else { return }
        
        do {
            let response = try await AddVideoToPlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [
                    .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId,
                    .movingVideoId: video.videoId
                ],
                useCookies: true
            )
            
            if response.success {
                await loadPlaylistStates()
            }
        } catch {
            print("Error adding video to playlist:", error)
        }
    }
    
    func removeFromPlaylist(_ playlist: YTPlaylist) async {
        guard let video = selectedVideo else { return }
        
        do {
            let response = try await RemoveVideoFromPlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [
                    .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId,
                    .movingVideoId: video.videoId
                ],
                useCookies: true
            )
            
            if response.success {
                await loadPlaylistStates()
            }
        } catch {
            print("Error removing video from playlist:", error)
        }
    }
    
    func likeVideo() async {
        guard let video = selectedVideo else { return }
        
        do {
            switch likeStatus {
                case .nothing:
                    try await video.likeVideoThrowing(youtubeModel: youtubeService.model)
                    likeStatus = .liked
                    
                case .liked:
                    try await video.removeLikeFromVideoThrowing(youtubeModel: youtubeService.model)
                    likeStatus = .nothing
                    
                case .disliked:
                    try await video.likeVideoThrowing(youtubeModel: youtubeService.model)
                    likeStatus = .liked
            }
        } catch {
            print("Error liking video:", error)
        }
    }
    
    func dislikeVideo() async {
        guard let video = selectedVideo else { return }
        
        do {
            switch likeStatus {
                case .nothing:
                    try await video.dislikeVideoThrowing(youtubeModel: youtubeService.model)
                    likeStatus = .disliked
                    
                case .liked:
                    try await video.dislikeVideoThrowing(youtubeModel: youtubeService.model)
                    likeStatus = .disliked
                    
                case .disliked:
                    try await video.removeLikeFromVideoThrowing(youtubeModel: youtubeService.model)
                    likeStatus = .nothing
            }
        } catch {
            print("Error disliking video:", error)
        }
    }
    
    func getPlaylistStates(for video: YTVideo) async -> [(playlist: YTPlaylist, isVideoPresentInside: Bool)] {
        do {
            let response = try await video.fetchAllPossibleHostPlaylistsThrowing(
                youtubeModel: youtubeService.model
            )
            
            return response.playlistsAndStatus
        } catch {
            print("Error getting playlist states:", error)
            return []
        }
    }
    
    func selectVideo(_ video: YTVideo) {
        Task {
            await loadVideo(video)
            isVideoSheetPresented = true
        }
    }
}
