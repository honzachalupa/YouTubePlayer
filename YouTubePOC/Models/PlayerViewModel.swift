import AVFoundation
import YouTubeKit

@MainActor
final class PlayerViewModel: ObservableObject, @unchecked Sendable {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var error: String?
    private let authService: YouTubeAuthService
    
    init() {
        // Since we're on the main actor, we can safely access shared
        self.authService = YouTubeAuthService.shared
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func loadVideo(video: YTVideo) {
        isLoading = true
        error = nil
        
        Task { [weak self] in
            guard let self = self else {
                print("Failed to get self")
                return
            }
            
            do {
                await self.getVisitorData()
                let streamingInfos = try await video.fetchStreamingInfosThrowing(youtubeModel: YTM.model)
                
                guard let streamingURL = streamingInfos.streamingURL else {
                    print("Failed to get streaming URL")

                    await MainActor.run {
                        self.error = "Failed to get video streaming URL"
                        self.isLoading = false
                    }

                    return
                }
                
                await MainActor.run {
                    self.player = AVPlayer(url: streamingURL)
                    self.player?.play()
                    self.isLoading = false
                }
            } catch let error as ResponseExtractionError {
                print("Error loading video: \(error)")

                await MainActor.run {
                    if error.stepDescription.contains("Login is required") {
                        self.error = "Authentication required. Please make sure you have provided valid cookies in the app settings."
                    } else {
                        self.error = "Failed to load video: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
            } catch {
                print("Error loading video: \(error)")

                await MainActor.run {
                    self.error = "Failed to load video: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getVisitorData() async {
        if YTM.model.visitorData.isEmpty {
            if let visitorData = try? await SearchResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [.query: "homefwhfjoifj"]).visitorData {
                YTM.model.visitorData = visitorData
            } else {
                print("Couldn't get visitorData, request may fail.")
            }
        }
    }
    
    func cleanup() {
        player?.pause()
        player = nil
    }
}
