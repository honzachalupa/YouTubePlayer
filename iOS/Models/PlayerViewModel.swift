import SwiftUI
import YouTubeKit
import AVKit

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var error: String?
    
    private var playerTimeObserver: Any?
    private let authService: YouTubeAuthService
    private let youtubeService: YouTubeService
    
    init() {
        self.authService = .shared
        self.youtubeService = .shared
        configureAudioSession()
    }
    
    @MainActor
    deinit {
        if let observer = playerTimeObserver, let currentPlayer = player {
            currentPlayer.removeTimeObserver(observer)
        }
    }
    
    func loadVideo(video: YTVideo) {
        isLoading = true
        error = nil
        
        Task {
            do {
                await getVisitorData()
                let streamingInfos = try await video.fetchStreamingInfosThrowing(youtubeModel: youtubeService.model)
                
                guard let streamingURL = streamingInfos.streamingURL else {
                    error = "Failed to get video streaming URL"
                    isLoading = false
                    return
                }
                
                let newPlayer = AVPlayer(url: streamingURL)
                setupPlayerObservation(for: newPlayer)
                self.player = newPlayer
                self.player?.play()
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
    }
    
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
            // Handle time updates if needed
            _ = self  // Silence the 'never read' warning
        }
    }
    
    private func getVisitorData() async {
        if youtubeService.model.visitorData.isEmpty {
            if let visitorData = try? await SearchResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [.query: "homefwhfjoifj"]
            ).visitorData {
                youtubeService.model.visitorData = visitorData
            } else {
                print("Couldn't get visitorData, request may fail.")
            }
        }
    }
}
