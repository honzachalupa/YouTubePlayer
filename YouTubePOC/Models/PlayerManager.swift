import SwiftUI
import AVKit
import YouTubeKit

@MainActor
class PlayerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedVideo: YTVideo?
    @Published var isVideoSheetPresented = false
    @Published private(set) var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var isFullscreen = false
    @Published var likeStatus: YTLikeStatus = .nothing
    @Published var availablePlaylists: [(playlist: YTPlaylist, isVideoPresentInside: Bool)] = []
    
    // MARK: - Private Properties
    private var playerTimeObserver: Any?
    private let authService: YouTubeAuthService
    
    // MARK: - Initialization
    init() {
        self.authService = .shared
        configureAudioSession()
    }
    
    // MARK: - Public Methods
    func selectVideo(_ video: YTVideo) {
        // Only update if it's a different video
        if selectedVideo?.videoId != video.videoId {
            cleanup()
            selectedVideo = video
        }
        isVideoSheetPresented = true
        loadVideo(video)
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
        // If it's the same video and we already have a player, just play it
        if let currentVideo = selectedVideo, currentVideo.videoId == video.videoId, let existingPlayer = player {
            // Only play if not already playing
            if !isPlaying {
                existingPlayer.play()
                isPlaying = true
            }
            return
        }
        
        // Clean up previous player
        cleanup()
        
        // Update selected video
        selectedVideo = video
        isLoading = true
        error = nil
        
        Task {
            do {
                // Ensure we have fresh visitor data and authentication
                await getVisitorData()
                
                // First get the streaming URL and set up the player
                let streamingInfos = try await video.fetchStreamingInfosThrowing(youtubeModel: YTM.model)
                
                guard let streamingURL = streamingInfos.streamingURL else {
                    error = "Failed to get video streaming URL"
                    isLoading = false
                    return
                }
                
                let newPlayer = AVPlayer(url: streamingURL)
                setupPlayerObservation(for: newPlayer)
                self.player = newPlayer
                self.player?.play()
                self.isPlaying = true
                self.isLoading = false
                
                // Then fetch additional info in the background
                Task {
                    do {
                        // Fetch more info to get like status
                        let moreInfos = try await video.fetchMoreInfosThrowing(youtubeModel: YTM.model)
                        if let status = moreInfos.authenticatedInfos?.likeStatus {
                            likeStatus = status
                        }
                        
                        // Fetch available playlists
                        let playlistsResponse = try await video.fetchAllPossibleHostPlaylistsThrowing(youtubeModel: YTM.model)
                        availablePlaylists = playlistsResponse.playlistsAndStatus
                    } catch {
                        // Don't show errors for additional info - it's not critical
                        print("Failed to fetch additional info: \(error.localizedDescription)")
                    }
                }
                
            } catch let error as ResponseExtractionError {
                if error.stepDescription.contains("Login is required") {
                    // Check if we're actually authenticated
                    if authService.isAuthenticated {
                        self.error = "Failed to load video: Authentication error. Please try signing out and signing in again."
                    } else {
                        self.error = "Authentication required. Please sign in."
                    }
                } else {
                    self.error = "Failed to load video: \(error.localizedDescription)"
                }
                self.isLoading = false
                
            } catch {
                self.error = "Failed to load video: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func cleanup() {
        player?.pause()
        if let observer = playerTimeObserver, let player = player {
            player.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        player = nil
        isPlaying = false
    }
    
    func toggleFullscreen() {
        withAnimation {
            isFullscreen.toggle()
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
    
    func addToPlaylist(_ playlist: YTPlaylist) {
        guard let video = selectedVideo else { return }
        
        Task {
            do {
                await getVisitorData()
                
                let response = try await AddVideoToPlaylistResponse.sendThrowingRequest(
                    youtubeModel: YTM.model,
                    data: [
                        .movingVideoId: video.videoId,
                        .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId
                    ],
                    useCookies: true
                )
                
                if response.isDisconnected {
                    error = "Failed to add video to playlist: Not authenticated"
                } else if !response.success {
                    error = "Failed to add video to playlist"
                } else {
                    // Update playlists status
                    let playlistsResponse = try await video.fetchAllPossibleHostPlaylistsThrowing(youtubeModel: YTM.model)
                    availablePlaylists = playlistsResponse.playlistsAndStatus
                }
            } catch {
                self.error = "Failed to add video to playlist: \(error.localizedDescription)"
            }
        }
    }
    
    func removeFromPlaylist(_ playlist: YTPlaylist) {
        guard let video = selectedVideo else { return }
        
        Task {
            do {
                await getVisitorData()
                
                let response = try await RemoveVideoByIdFromPlaylistResponse.sendThrowingRequest(
                    youtubeModel: YTM.model,
                    data: [
                        .movingVideoId: video.videoId,
                        .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId
                    ],
                    useCookies: true
                )
                
                if response.isDisconnected {
                    error = "Failed to remove video from playlist: Not authenticated"
                } else if !response.success {
                    error = "Failed to remove video from playlist"
                } else {
                    // Update playlists status
                    let playlistsResponse = try await video.fetchAllPossibleHostPlaylistsThrowing(youtubeModel: YTM.model)
                    availablePlaylists = playlistsResponse.playlistsAndStatus
                }
            } catch {
                self.error = "Failed to remove video from playlist: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupPlayerObservation(for player: AVPlayer) {
        // Remove previous observer if any
        if let observer = playerTimeObserver, let oldPlayer = self.player {
            oldPlayer.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        
        // Add new observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                let isCurrentlyPlaying = player.rate > 0 && player.error == nil
                if self.isPlaying != isCurrentlyPlaying {
                    self.isPlaying = isCurrentlyPlaying
                }
            }
        }
    }
    
    private func getVisitorData() async {
        if YTM.model.visitorData.isEmpty {
            if let visitorData = try? await SearchResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [.query: "homefwhfjoifj"]
            ).visitorData {
                YTM.model.visitorData = visitorData
            } else {
                print("Couldn't get visitorData, request may fail.")
            }
        }
    }
}
