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
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = video.title ?? "Unknown Title"
        nowPlayingInfo[MPMediaItemPropertyArtist] = video.channel?.name ?? "Unknown Channel"
        
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
    
    func getPlaylistStates(for video: YTVideo) async -> [(playlist: YTPlaylist, isVideoPresentInside: Bool)] {
        if video.videoId == selectedVideo?.videoId {
            return availablePlaylists
        }
        
        if let states = temporaryPlaylistStates[video.videoId] {
            return states
        }
        
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
        if let currentVideo = selectedVideo, currentVideo.videoId == video.videoId, let existingPlayer = player {
            if !isPlaying {
                existingPlayer.play()
                isPlaying = true
                updateNowPlayingInfo()
            }
            
            return
        }
        
        cleanup()
        selectedVideo = video
        isLoading = true
        error = nil
        
        if let thumbnailURLString = video.thumbnails.last?.url.absoluteString,
           let thumbnailURL = URL(string: thumbnailURLString) {
            Task {
                await loadThumbnailImage(from: thumbnailURL)
            }
        }
        
        Task {
            do {
                if YTM.model.visitorData.isEmpty {
                    if let visitorData = try? await SearchResponse.sendThrowingRequest(
                        youtubeModel: YTM.model,
                        data: [.query: "homefwhfjoifj"],
                        useCookies: true
                    ).visitorData {
                        YTM.model.visitorData = visitorData
                    }
                }
                
                let _ = try await video.fetchMoreInfosThrowing(youtubeModel: YTM.model, useCookies: true)
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
