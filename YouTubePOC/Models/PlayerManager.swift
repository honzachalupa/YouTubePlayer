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
                await getVisitorData()
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
                
            } catch let error as ResponseExtractionError {
                self.error = error.stepDescription.contains("Login is required") ?
                    "Authentication required. Please sign in." :
                    "Failed to load video: \(error.localizedDescription)"
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
