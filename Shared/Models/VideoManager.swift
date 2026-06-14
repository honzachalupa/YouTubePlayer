import SwiftUI
import AVKit
import YouTubeKit
import MediaPlayer
import Combine
import SwiftData

@MainActor
class VideoManager: ObservableObject {
    static let shared = VideoManager()
    
    @Published var selectedVideo: YTVideo?
    @Published var isVideoSheetPresented = false
    @Published private(set) var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var likeStatus: YTLikeStatus = .nothing
    @Published var availablePlaylists: [(playlist: YTPlaylist, isVideoPresentInside: Bool)] = []
    @Published var temporaryPlaylistStates: [String: [(playlist: YTPlaylist, isVideoPresentInside: Bool)]] = [:]
    
    var shouldShowAccessory: Bool {
        guard let title = selectedVideo?.title?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !title.isEmpty
    }
    
    private var playerTimeObserver: Any?
    private var currentPlayer: AVPlayer?
    private let authService: YouTubeAuthService
    private let playlistService = YouTubePlaylistService.shared
    private let youtubeService = YouTubeService.shared
    private var modelContext: ModelContext?
    private var thumbnailImage: UIImage?
    private var isCleanedUp = false
    private var lastPlaybackPositionSave = Date.distantPast
    private let maximumStoredPlaybackPositions = 200
    
    func clearPlaylistData() {
        availablePlaylists = []
        temporaryPlaylistStates = [:]
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }
    
    init() {
        self.authService = .shared
        
        configureAudioSession()
        setupRemoteTransportControls()
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    @MainActor
    private func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        saveCurrentPlaybackPosition(force: true)
        
        if let observer = playerTimeObserver, let player = currentPlayer {
            player.removeTimeObserver(observer)
            playerTimeObserver = nil
            currentPlayer = nil
        }
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
    private nonisolated func configureAudioSession() {
        Task.detached(priority: .utility) {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
            } catch {
                print("Failed to configure audio session:", error)
            }
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
    
    private func playbackPosition(for videoId: String) -> PlaybackPositionModel? {
        guard let modelContext else { return nil }

        var descriptor = FetchDescriptor<PlaybackPositionModel>(
            predicate: #Predicate { $0.videoId == videoId }
        )
        descriptor.fetchLimit = 1

        return try? modelContext.fetch(descriptor).first
    }

    private func prunePlaybackPositionsIfNeeded() {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<PlaybackPositionModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        guard let positions = try? modelContext.fetch(descriptor),
              positions.count > maximumStoredPlaybackPositions else {
            return
        }

        for position in positions.dropFirst(maximumStoredPlaybackPositions) {
            modelContext.delete(position)
        }
    }

    private func savedPlaybackTime(for videoId: String) -> CMTime? {
        guard let position = playbackPosition(for: videoId), position.positionSeconds >= 3 else {
            return nil
        }

        return CMTime(seconds: position.positionSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    }

    func saveCurrentPlaybackPosition(force: Bool = false) {
        guard let modelContext,
              let videoId = selectedVideo?.videoId,
              let player,
              let currentItem = player.currentItem else {
            return
        }

        let currentSeconds = player.currentTime().seconds
        guard currentSeconds.isFinite, currentSeconds >= 0 else { return }

        let now = Date()
        guard force || now.timeIntervalSince(lastPlaybackPositionSave) >= 5 else { return }

        let durationSeconds = currentItem.duration.seconds.isFinite ? currentItem.duration.seconds : nil
        let position = playbackPosition(for: videoId) ?? PlaybackPositionModel(videoId: videoId, positionSeconds: 0)
        position.positionSeconds = currentSeconds
        position.durationSeconds = durationSeconds
        position.updatedAt = now

        if position.modelContext == nil {
            modelContext.insert(position)
        }

        prunePlaybackPositionsIfNeeded()

        do {
            try modelContext.save()
            lastPlaybackPositionSave = now
        } catch {
            print("Error saving playback position:", error)
        }
    }

    private func setupPlayerObservation(for player: AVPlayer) {
        // Remove any existing time observer from the current player
        if let observer = playerTimeObserver, let oldPlayer = currentPlayer {
            saveCurrentPlaybackPosition(force: true)
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

                self.saveCurrentPlaybackPosition()
            }
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            saveCurrentPlaybackPosition(force: true)
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }

    enum PlaybackResolverError: LocalizedError {
        case noNativePlayableStream

        var errorDescription: String? {
            switch self {
            case .noNativePlayableStream:
                return "No native HLS or muxed MP4 stream was returned for this video."
            }
        }
    }

    private func nativeWatchPageStreamingURL(for video: YTVideo) async throws -> URL? {
        var components = URLComponents(string: "https://www.youtube.com/watch")
        components?.queryItems = [
            URLQueryItem(name: "v", value: video.videoId),
            URLQueryItem(name: "bpctr", value: "9999999999"),
            URLQueryItem(name: "has_verified", value: "1")
        ]

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("\(youtubeService.model.selectedLocale);q=0.9", forHTTPHeaderField: "Accept-Language")

        if !youtubeService.model.cookies.isEmpty {
            request.setValue(youtubeService.model.cookies, forHTTPHeaderField: "Cookie")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(decoding: data, as: UTF8.self)

        guard let playerResponseJSON = NativePlaybackSupport.extractInitialPlayerResponseJSON(from: html) else {
            return nil
        }

        let playerResponse = try VideoInfosResponse.decodeJSON(json: JSON(parseJSON: playerResponseJSON))
        return NativePlaybackSupport.streamingURL(from: playerResponse)
    }
    
    func loadVideo(_ video: YTVideo) async {
        isLoading = true
        error = nil
        
        do {
            // Ensure a fresh visitorData token before player requests.
            if youtubeService.model.visitorData.isEmpty {
                let searchResponse = try await SearchResponse.sendThrowingRequest(
                    youtubeModel: youtubeService.model,
                    data: [.query: "home"],
                    useCookies: false
                )
                
                if let visitorData = searchResponse.visitorData {
                    youtubeService.model.visitorData = visitorData
                    UserDefaults.standard.set(visitorData, forKey: "ytm_visitor_data")
                }
            }
            
            let streamingURL: URL
            var primaryPlaybackError: Error?

            do {
                let streamingInfos = try await video.fetchStreamingInfosThrowing(
                    youtubeModel: youtubeService.model,
                    useCookies: nil
                )

                if let hlsURL = streamingInfos.streamingURL {
                    streamingURL = hlsURL
                } else if let directMuxedURL = NativePlaybackSupport.preferredMuxedStreamingURL(from: streamingInfos.defaultFormats) {
                    streamingURL = directMuxedURL
                } else {
                    throw PlaybackResolverError.noNativePlayableStream
                }
            } catch {
                primaryPlaybackError = error

                do {
                    let downloadFormatsResponse = try await video.fetchStreamingInfosWithDownloadFormatsThrowing(
                        youtubeModel: youtubeService.model,
                        useCookies: nil
                    )

                    guard let fallbackURL = NativePlaybackSupport.fallbackStreamingURL(from: downloadFormatsResponse) else {
                        if let primaryPlaybackError {
                            throw primaryPlaybackError
                        }

                        throw PlaybackResolverError.noNativePlayableStream
                    }

                    streamingURL = fallbackURL
                } catch let fallbackError {
                    if let watchPageURL = try? await nativeWatchPageStreamingURL(for: video) {
                        streamingURL = watchPageURL
                    } else if let primaryPlaybackError {
                        throw primaryPlaybackError
                    } else {
                        throw fallbackError
                    }
                }
            }
            
            // Load thumbnail for now playing info
            if let thumbnailURL = video.thumbnails.first?.url {
                if let data = try? await URLSession.shared.data(from: thumbnailURL).0 {
                    thumbnailImage = UIImage(data: data)
                }
            }
            
            // Create and configure player
            let newPlayer = AVPlayer(url: streamingURL)
            if let savedTime = savedPlaybackTime(for: video.videoId) {
                await newPlayer.seek(to: savedTime)
            }
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
        } catch let error as NetworkError {
            if error.message.isEmpty {
                self.error = "Failed to load video: Network error \(error.code)."
            } else {
                self.error = "Failed to load video: \(error.message) (code \(error.code))"
            }
        } catch let error as VideoInfosWithDownloadFormatsResponse.ResponseError {
            self.error = "Playable fallback stream parsing failed at \(String(describing: error.step)): \(error.reason)"
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
            let response = try await RemoveVideoByIdFromPlaylistResponse.sendThrowingRequest(
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
        saveCurrentPlaybackPosition(force: true)
        selectedVideo = video
        error = nil
        isLoading = true
        isPlaying = false
        player?.pause()
        player = nil
        isVideoSheetPresented = true

        Task {
            await loadVideo(video)
        }
    }
}
