import SwiftUI
import AVKit
import YouTubeKit
import MediaPlayer
import Combine
import SwiftData

@MainActor
class VideoManager: ObservableObject {
    static let shared = VideoManager()

    struct NextVideoPrompt {
        let video: YTVideo
        let remainingSeconds: Int
    }

    private struct StreamingPlaybackSelection {
        let url: URL
        let preferredPeakBitRate: Double?
        let preferredMaximumResolution: CGSize?
    }

    struct PlaybackQueueContext {
        enum Source {
            case recommended
            case playlist(title: String)
        }

        let source: Source
        let videos: [YTVideo]

        func containsVideo(withID videoID: String) -> Bool {
            videos.contains { $0.videoId == videoID }
        }

        func followingVideos(after currentVideoID: String) -> [YTVideo] {
            guard let currentIndex = videos.firstIndex(where: { $0.videoId == currentVideoID }) else {
                return videos
            }

            return Array(videos.dropFirst(currentIndex + 1))
        }

        func nextVideo(after currentVideoID: String) -> YTVideo? {
            followingVideos(after: currentVideoID).first
        }

    }
    
    @Published var selectedVideo: YTVideo?
    @Published var isVideoSheetPresented = false
    @Published private(set) var player: AVQueuePlayer?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var likeStatus: YTLikeStatus = .nothing
    @Published var availablePlaylists: [(playlist: YTPlaylist, isVideoPresentInside: Bool)] = []
    @Published var temporaryPlaylistStates: [String: [(playlist: YTPlaylist, isVideoPresentInside: Bool)]] = [:]
    @Published private(set) var playbackQueueContext: PlaybackQueueContext?
    @Published private(set) var nextVideoPrompt: NextVideoPrompt?
    
    var shouldShowAccessory: Bool {
        guard let title = selectedVideo?.title?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !title.isEmpty
    }
    
    private var playerTimeObserver: Any?
    private var playbackDidEndObserver: NSObjectProtocol?
    private var playbackFailedObserver: NSObjectProtocol?
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var currentPlayer: AVQueuePlayer?
    private var nowPlayingSession: MPNowPlayingSession?
    private let authService: YouTubeAuthService
    private let playlistService = YouTubePlaylistService.shared
    private let youtubeService = YouTubeService.shared
    private var modelContext: ModelContext?
    private var thumbnailImage: UIImage?
    private var isCleanedUp = false
    private var currentVideoLoadID: UUID?
    private var dismissedNextVideoPromptKey: String?
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

        #if os(iOS)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif
    }
    
    @MainActor
    private func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        saveCurrentPlaybackPosition(force: true)

        removePlayerObservers()
        currentPlayer = nil
        nowPlayingSession = nil
        #if os(iOS)
        UIApplication.shared.endReceivingRemoteControlEvents()
        #endif
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
    
    private func setupRemoteTransportControls(for commandCenter: MPRemoteCommandCenter) {
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
            guard let self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }

            Task { @MainActor in
                guard let currentTime = self.player?.currentTime() else { return }
                let newTime = CMTimeSubtract(
                    currentTime,
                    CMTime(seconds: skipEvent.interval, preferredTimescale: 1)
                )
                self.player?.seek(to: newTime) { _ in
                }
            }
            return .success
        }

        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }

            Task { @MainActor in
                guard let currentTime = self.player?.currentTime() else { return }
                let newTime = CMTimeAdd(
                    currentTime,
                    CMTime(seconds: skipEvent.interval, preferredTimescale: 1)
                )
                self.player?.seek(to: newTime) { _ in
                }
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            Task { @MainActor in
                let newTime = CMTime(seconds: positionEvent.positionTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                self.player?.seek(to: newTime) { _ in
                }
            }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.preferredIntervals = [10]
    }

    private func configureNowPlayingSession(for player: AVQueuePlayer) {
        let session = MPNowPlayingSession(players: [player])
        session.automaticallyPublishesNowPlayingInfo = true
        setupRemoteTransportControls(for: session.remoteCommandCenter)
        nowPlayingSession = session
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
        if let durationSeconds, durationSeconds > 0 {
            let completedThreshold = durationSeconds - min(5, durationSeconds * 0.05)
            if currentSeconds >= completedThreshold {
                if let position = playbackPosition(for: videoId) {
                    modelContext.delete(position)
                }
                do {
                    try modelContext.save()
                    lastPlaybackPositionSave = now
                } catch {
                    print("Error clearing completed playback position:", error)
                }
                return
            }
        }

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

    private func removePlayerObservers() {
        if let observer = playerTimeObserver, let oldPlayer = currentPlayer {
            oldPlayer.removeTimeObserver(observer)
            playerTimeObserver = nil
        }

        if let observer = playbackDidEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackDidEndObserver = nil
        }

        if let observer = playbackFailedObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackFailedObserver = nil
        }

        playerItemStatusObservation = nil
    }

    private func stopCurrentPlayerForReplacement(savePosition: Bool = true) {
        if savePosition {
            saveCurrentPlaybackPosition(force: true)
        }

        removePlayerObservers()

        let oldPlayer = player ?? currentPlayer
        oldPlayer?.pause()
        oldPlayer?.replaceCurrentItem(with: nil)

        player = nil
        currentPlayer = nil
        isPlaying = false
        nextVideoPrompt = nil
        dismissedNextVideoPromptKey = nil
        nowPlayingSession = nil
    }

    func stopPlayback(savePosition: Bool = true) {
        stopCurrentPlayerForReplacement(savePosition: savePosition)
    }

    private func setupPlayerObservation(for player: AVQueuePlayer) {
        removePlayerObservers()
        
        // Store the new player as current
        currentPlayer = player
        observePlaybackDidEnd(for: player.currentItem)
        observePlaybackFailure(for: player.currentItem)
        
        // Add new time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let currentItem = player.currentItem {
                    let duration = currentItem.duration
                    self.updateNextVideoPrompt(elapsedTime: time, duration: duration)
                }

                self.saveCurrentPlaybackPosition()
            }
        }
    }

    private func updateNextVideoPrompt(elapsedTime: CMTime, duration: CMTime) {
        guard duration.isNumeric,
              elapsedTime.isNumeric,
              let currentVideoID = selectedVideo?.videoId,
              let queue = playbackQueueContext,
              let nextVideo = queue.nextVideo(after: currentVideoID) else {
            nextVideoPrompt = nil
            return
        }

        let promptKey = nextVideoPromptKey(currentVideoID: currentVideoID, nextVideoID: nextVideo.videoId)
        guard dismissedNextVideoPromptKey != promptKey else {
            nextVideoPrompt = nil
            return
        }

        let remainingSeconds = duration.seconds - elapsedTime.seconds
        guard remainingSeconds.isFinite,
              remainingSeconds > 0,
              remainingSeconds <= 20 else {
            nextVideoPrompt = nil
            return
        }

        nextVideoPrompt = NextVideoPrompt(
            video: nextVideo,
            remainingSeconds: max(0, Int(ceil(remainingSeconds)))
        )
    }

    func dismissNextVideoPrompt() {
        if let currentVideoID = selectedVideo?.videoId,
           let nextVideoID = nextVideoPrompt?.video.videoId {
            dismissedNextVideoPromptKey = nextVideoPromptKey(currentVideoID: currentVideoID, nextVideoID: nextVideoID)
        }

        nextVideoPrompt = nil
    }

    func playPromptedNextVideo() {
        guard let currentVideoID = selectedVideo?.videoId,
              let queue = playbackQueueContext,
              let nextVideo = queue.nextVideo(after: currentVideoID) else {
            return
        }

        selectVideo(nextVideo, playbackQueueContext: queue)
    }

    #if DEBUG
    func debugSetNextVideoPrompt(_ prompt: NextVideoPrompt?) {
        nextVideoPrompt = prompt
    }
    #endif

    private func nextVideoPromptKey(currentVideoID: String, nextVideoID: String) -> String {
        "\(currentVideoID)->\(nextVideoID)"
    }

    private func observePlaybackDidEnd(for item: AVPlayerItem?) {
        guard let item else { return }

        playbackDidEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playNextVideoIfAvailable()
            }
        }
    }

    private func observePlaybackFailure(for item: AVPlayerItem?) {
        guard let item else { return }

        playbackFailedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                let notificationError = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
                self?.handlePlaybackFailure(for: item, fallbackError: notificationError)
            }
        }

        playerItemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            guard observedItem.status == .failed else { return }

            Task { @MainActor in
                self?.handlePlaybackFailure(for: observedItem, fallbackError: observedItem.error as NSError?)
            }
        }
    }

    private func handlePlaybackFailure(for item: AVPlayerItem, fallbackError: NSError?) {
        let resolvedError = (item.error as NSError?) ?? fallbackError
        let errorDescription = resolvedError?.localizedDescription ?? "Unknown playback failure"
        let failureReason = resolvedError?.localizedFailureReason ?? ""
        let recoverySuggestion = resolvedError?.localizedRecoverySuggestion ?? ""
        let combinedDetails = [failureReason, recoverySuggestion]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let message = combinedDetails.isEmpty
            ? "Playback failed: \(errorDescription)"
            : "Playback failed: \(errorDescription). \(combinedDetails)"

        if error != message {
            error = message
        }

        isPlaying = false

        print("Playback failure:", [
            "videoId": selectedVideo?.videoId ?? "unknown",
            "status": item.status.rawValue,
            "error": resolvedError?.description ?? "nil",
            "accessLogEvents": item.accessLog()?.events.count ?? 0,
            "errorLogEvents": item.errorLog()?.events.count ?? 0
        ])
    }

    private func playNextVideoIfAvailable() {
        saveCurrentPlaybackPosition(force: true)
        isPlaying = false

        guard let currentVideoID = selectedVideo?.videoId,
              let queue = playbackQueueContext,
              let nextVideo = queue.nextVideo(after: currentVideoID) else {
            return
        }

        selectVideo(nextVideo, playbackQueueContext: queue)
    }

    private func deduplicatedQueueVideos(_ videos: [YTVideo]) -> [YTVideo] {
        var seenVideoIDs = Set<String>()

        return videos.filter { video in
            guard !video.videoId.isEmpty, !seenVideoIDs.contains(video.videoId) else {
                return false
            }

            seenVideoIDs.insert(video.videoId)
            return true
        }
    }

    func setRecommendedQueue(currentVideo: YTVideo, recommendedVideos: [YTVideo]) {
        guard !isUsingPlaylistQueue(for: currentVideo.videoId) else { return }

        playbackQueueContext = PlaybackQueueContext(
            source: .recommended,
            videos: deduplicatedQueueVideos([currentVideo] + recommendedVideos)
        )
    }

    func setPlaylistQueue(title: String, videos: [YTVideo]) {
        playbackQueueContext = PlaybackQueueContext(
            source: .playlist(title: title),
            videos: deduplicatedQueueVideos(videos)
        )
    }

    func setPlaybackQueueContext(_ playbackQueueContext: PlaybackQueueContext?) {
        self.playbackQueueContext = playbackQueueContext
    }

    func isUsingPlaylistQueue(for videoID: String) -> Bool {
        guard let playbackQueueContext,
              case .playlist = playbackQueueContext.source else {
            return false
        }

        return playbackQueueContext.containsVideo(withID: videoID)
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

    private func beginVideoLoad() -> UUID {
        let loadID = UUID()
        currentVideoLoadID = loadID
        return loadID
    }

    private func isCurrentVideoLoad(_ loadID: UUID) -> Bool {
        currentVideoLoadID == loadID
    }

    private func finishVideoLoad(_ loadID: UUID) {
        guard isCurrentVideoLoad(loadID) else { return }
        currentVideoLoadID = nil
        isLoading = false
    }

    private func mergedPlaylistStates(
        fetchedStates: [(playlist: YTPlaylist, isVideoPresentInside: Bool)],
        for videoID: String
    ) -> [(playlist: YTPlaylist, isVideoPresentInside: Bool)] {
        guard let temporaryStates = temporaryPlaylistStates[videoID], !temporaryStates.isEmpty else {
            return fetchedStates
        }

        let temporaryLookup = Dictionary(
            uniqueKeysWithValues: temporaryStates.map { ($0.playlist.playlistId, $0.isVideoPresentInside) }
        )

        return fetchedStates.map { item in
            if let override = temporaryLookup[item.playlist.playlistId] {
                return (playlist: item.playlist, isVideoPresentInside: override)
            }
            return item
        }
    }

    private func updateTemporaryPlaylistState(
        for videoID: String,
        playlistID: String,
        isPresent: Bool
    ) {
        var states = temporaryPlaylistStates[videoID] ?? []

        if let index = states.firstIndex(where: { $0.playlist.playlistId == playlistID }) {
            states[index] = (playlist: states[index].playlist, isVideoPresentInside: isPresent)
        } else if let playlist = availablePlaylists.first(where: { $0.playlist.playlistId == playlistID })?.playlist {
            states.append((playlist: playlist, isVideoPresentInside: isPresent))
        }

        temporaryPlaylistStates[videoID] = states

        if selectedVideo?.videoId == videoID {
            availablePlaylists = mergedPlaylistStates(fetchedStates: availablePlaylists, for: videoID)
        }
    }

    private func playbackHTTPHeaderFields() -> [String: String] {
        var headers = [
            "User-Agent": NativePlaybackSupport.androidUserAgent,
            "Referer": "https://www.youtube.com/",
            "Origin": "https://www.youtube.com"
        ]

        if !youtubeService.model.cookies.isEmpty {
            headers["Cookie"] = youtubeService.model.cookies
        }

        return headers
    }

    private func makePlaybackAsset(for streamingURL: URL) -> AVURLAsset {
        AVURLAsset(
            url: streamingURL,
            options: [
                "AVURLAssetHTTPHeaderFieldsKey": playbackHTTPHeaderFields()
            ]
        )
    }

    private func createMetadataItem(
        identifier: AVMetadataIdentifier,
        value: String
    ) -> AVMetadataItem? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = trimmedValue as NSString
        item.extendedLanguageTag = "und"
        return item.copy() as? AVMetadataItem
    }

    private func createArtworkMetadataItem(from image: UIImage?) -> AVMetadataItem? {
        guard let image,
              let imageData = image.pngData() else {
            return nil
        }

        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierArtwork
        item.value = imageData as NSData
        item.dataType = kCMMetadataBaseDataType_PNG as String
        item.extendedLanguageTag = "und"
        return item.copy() as? AVMetadataItem
    }

    private func makeNowPlayingInfo(for video: YTVideo) -> [String: Any] {
        var info = [String: Any]()

        if let title = video.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            info[MPMediaItemPropertyTitle] = title
        }

        if let subtitle = video.channel?.name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !subtitle.isEmpty {
            info[MPMediaItemPropertyArtist] = subtitle
        }

        if let image = thumbnailImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        return info
    }

    private func makeExternalMetadata(for video: YTVideo) -> [AVMetadataItem] {
        let descriptionText =
            youtubeService.cachedDetails(for: video.videoId)?.description ??
            youtubeService.cachedPersistedDetails(for: video.videoId)?.description

        return [
            createMetadataItem(
                identifier: .commonIdentifierTitle,
                value: video.title ?? ""
            ),
            createMetadataItem(
                identifier: .iTunesMetadataTrackSubTitle,
                value: video.channel?.name ?? ""
            ),
            createMetadataItem(
                identifier: .commonIdentifierDescription,
                value: descriptionText ?? ""
            ),
            createArtworkMetadataItem(from: thumbnailImage)
        ]
        .compactMap { $0 }
    }

    private func makePlayer(
        for video: YTVideo,
        for streamingURL: URL,
        preferredPeakBitRate: Double? = nil,
        preferredMaximumResolution: CGSize? = nil
    ) -> AVQueuePlayer {
        let playerItem = AVPlayerItem(asset: makePlaybackAsset(for: streamingURL))
        playerItem.externalMetadata = makeExternalMetadata(for: video)
        #if os(iOS)
        playerItem.nowPlayingInfo = makeNowPlayingInfo(for: video)
        #endif
        playerItem.preferredPeakBitRate = preferredPeakBitRate ?? 0
        playerItem.preferredMaximumResolution = preferredMaximumResolution ?? .zero
        playerItem.preferredForwardBufferDuration = 30
        let player = AVQueuePlayer(items: [playerItem])
        player.actionAtItemEnd = .pause
        return player
    }

    private func validatedStreamingSelection(from streamingURL: URL) async -> StreamingPlaybackSelection {
        guard NativePlaybackSupport.isLikelyHLSPlaylistURL(streamingURL) else {
            return StreamingPlaybackSelection(url: streamingURL, preferredPeakBitRate: nil, preferredMaximumResolution: nil)
        }

        do {
            var request = URLRequest(url: streamingURL)
            request.setValue(NativePlaybackSupport.androidUserAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            let playlist = String(decoding: data, as: UTF8.self)

            guard playlist.contains("#EXTM3U") else {
                return StreamingPlaybackSelection(url: streamingURL, preferredPeakBitRate: nil, preferredMaximumResolution: nil)
            }

            guard playlist.contains("#EXT-X-STREAM-INF") else {
                return StreamingPlaybackSelection(url: streamingURL, preferredPeakBitRate: nil, preferredMaximumResolution: nil)
            }

            guard let variant = NativePlaybackSupport.highestQualityHLSVariant(
                from: playlist,
                masterURL: streamingURL
            ) else {
                return StreamingPlaybackSelection(url: streamingURL, preferredPeakBitRate: nil, preferredMaximumResolution: nil)
            }

            return StreamingPlaybackSelection(
                url: streamingURL,
                preferredPeakBitRate: Double(variant.bandwidth),
                preferredMaximumResolution: CGSize(width: variant.width, height: variant.height)
            )
        } catch {
            return StreamingPlaybackSelection(url: streamingURL, preferredPeakBitRate: nil, preferredMaximumResolution: nil)
        }
    }

    private func preferredStreamingURL(from streamingInfos: VideoInfosResponse) -> URL? {
        #if os(tvOS)
        if let primaryMuxedURL = NativePlaybackSupport.preferredMuxedStreamingURL(from: streamingInfos.defaultFormats) {
            return primaryMuxedURL
        }

        return streamingInfos.streamingURL
        #else
        if let hlsURL = streamingInfos.streamingURL {
            return hlsURL
        }

        return NativePlaybackSupport.preferredMuxedStreamingURL(from: streamingInfos.defaultFormats)
        #endif
    }

    private func preferredFallbackStreamingURL(from response: VideoInfosWithDownloadFormatsResponse) -> URL? {
        #if os(tvOS)
        if let fallbackMuxedURL = NativePlaybackSupport.preferredMuxedStreamingURL(from: response.defaultFormats) {
            return fallbackMuxedURL
        }

        return response.videoInfos.streamingURL
        #else
        if let hlsURL = response.videoInfos.streamingURL {
            return hlsURL
        }

        return NativePlaybackSupport.preferredMuxedStreamingURL(from: response.defaultFormats)
        #endif
    }

    func loadVideo(_ video: YTVideo) async {
        let loadID = beginVideoLoad()
        stopCurrentPlayerForReplacement()
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
            
            var streamingURL: URL?
            var primaryPlaybackError: Error?

            do {
                let streamingInfos = try await video.fetchStreamingInfosThrowing(
                    youtubeModel: youtubeService.model,
                    useCookies: nil
                )

                if let preferredURL = preferredStreamingURL(from: streamingInfos) {
                    streamingURL = preferredURL
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

                    if let fallbackURL = preferredFallbackStreamingURL(from: downloadFormatsResponse) {
                        streamingURL = fallbackURL
                    } else {
                        if let primaryPlaybackError {
                            throw primaryPlaybackError
                        }

                        throw PlaybackResolverError.noNativePlayableStream
                    }
                } catch {
                    if let primaryPlaybackError {
                        throw primaryPlaybackError
                    } else {
                        throw error
                    }
                }
            }
            
            guard isCurrentVideoLoad(loadID) else { return }

            // Load thumbnail for now playing info
            var loadedThumbnailImage: UIImage?
            if let thumbnailURL = video.thumbnails.first?.url {
                if let data = try? await URLSession.shared.data(from: thumbnailURL).0 {
                    loadedThumbnailImage = UIImage(data: data)
                }
            }
            
            guard isCurrentVideoLoad(loadID) else { return }

            guard let streamingURL else {
                throw PlaybackResolverError.noNativePlayableStream
            }

            let playbackSelection = await validatedStreamingSelection(from: streamingURL)

            guard isCurrentVideoLoad(loadID) else { return }

            let newPlayer = makePlayer(
                for: video,
                for: playbackSelection.url,
                preferredPeakBitRate: playbackSelection.preferredPeakBitRate,
                preferredMaximumResolution: playbackSelection.preferredMaximumResolution
            )
            if let savedTime = savedPlaybackTime(for: video.videoId) {
                await newPlayer.seek(to: savedTime)
            }

            guard isCurrentVideoLoad(loadID) else {
                newPlayer.pause()
                return
            }

            thumbnailImage = loadedThumbnailImage
            newPlayer.currentItem?.externalMetadata = makeExternalMetadata(for: video)
            #if os(iOS)
            newPlayer.currentItem?.nowPlayingInfo = makeNowPlayingInfo(for: video)
            configureNowPlayingSession(for: newPlayer)
            #endif
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
            #if os(iOS)
            _ = await nowPlayingSession?.becomeActiveIfPossible()
            #endif
            finishVideoLoad(loadID)
            
            // Load playlists state
            await loadPlaylistStates(for: video.videoId)
            
        } catch let error as ResponseExtractionError {
            guard isCurrentVideoLoad(loadID) else { return }
            self.error = error.stepDescription.contains("Login is required") ?
                "Authentication required. Please sign in." :
                "Failed to load video: \(error.localizedDescription)"
        } catch let error as NetworkError {
            guard isCurrentVideoLoad(loadID) else { return }
            if error.message.isEmpty {
                self.error = "Failed to load video: Network error \(error.code)."
            } else {
                self.error = "Failed to load video: \(error.message) (code \(error.code))"
            }
        } catch let error as VideoInfosWithDownloadFormatsResponse.ResponseError {
            guard isCurrentVideoLoad(loadID) else { return }
            self.error = "Playable fallback stream parsing failed at \(String(describing: error.step)): \(error.reason)"
        } catch {
            guard isCurrentVideoLoad(loadID) else { return }
            self.error = "Failed to load video: \(error.localizedDescription)"
        }
        
        finishVideoLoad(loadID)
    }
    
    func loadPlaylistStates(for expectedVideoId: String? = nil) async {
        guard let video = selectedVideo else { return }
        let requestedVideoId = expectedVideoId ?? video.videoId
        
        do {
            let response = try await video.fetchAllPossibleHostPlaylistsThrowing(
                youtubeModel: youtubeService.model
            )
            
            guard selectedVideo?.videoId == requestedVideoId else { return }

            withAnimation {
                availablePlaylists = mergedPlaylistStates(
                    fetchedStates: response.playlistsAndStatus,
                    for: requestedVideoId
                )
            }
        } catch {
            guard selectedVideo?.videoId == requestedVideoId else { return }
            print("Error loading playlist states:", error)
        }
    }
    
    func addToPlaylist(_ playlist: YTPlaylist) async {
        guard let video = selectedVideo else { return }
        await addVideo(video, to: playlist)
    }

    func addVideo(_ video: YTVideo, to playlist: YTPlaylist) async {
        
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
                updateTemporaryPlaylistState(
                    for: video.videoId,
                    playlistID: playlist.playlistId,
                    isPresent: true
                )
                if selectedVideo?.videoId == video.videoId {
                    await loadPlaylistStates(for: video.videoId)
                }
            }
        } catch {
            print("Error adding video to playlist:", error)
        }
    }
    
    func removeFromPlaylist(_ playlist: YTPlaylist) async {
        guard let video = selectedVideo else { return }
        await removeVideo(video, from: playlist)
    }

    func removeVideo(_ video: YTVideo, from playlist: YTPlaylist) async {
        
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
                updateTemporaryPlaylistState(
                    for: video.videoId,
                    playlistID: playlist.playlistId,
                    isPresent: false
                )
                if selectedVideo?.videoId == video.videoId {
                    await loadPlaylistStates(for: video.videoId)
                }
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
        if let temporaryStates = temporaryPlaylistStates[video.videoId], !temporaryStates.isEmpty {
            return temporaryStates
        }

        do {
            let response = try await video.fetchAllPossibleHostPlaylistsThrowing(
                youtubeModel: youtubeService.model
            )
            
            return mergedPlaylistStates(
                fetchedStates: response.playlistsAndStatus,
                for: video.videoId
            )
        } catch {
            print("Error getting playlist states:", error)
            return []
        }
    }
    
    func selectVideo(_ video: YTVideo, playbackQueueContext: PlaybackQueueContext? = nil) {
        if selectedVideo?.videoId == video.videoId, player != nil {
            self.playbackQueueContext = playbackQueueContext
            error = nil
            isLoading = false
            isVideoSheetPresented = true
            return
        }

        stopCurrentPlayerForReplacement()
        self.playbackQueueContext = playbackQueueContext
        selectedVideo = video
        error = nil
        isLoading = true
        isVideoSheetPresented = true

        Task {
            await loadVideo(video)
        }
    }
}
