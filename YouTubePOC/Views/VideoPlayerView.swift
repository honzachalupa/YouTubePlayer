import SwiftUI
import AVKit
import YouTubeKit
import UIKit
import AVFoundation

@MainActor final class PlayerViewModel: ObservableObject, @unchecked Sendable {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var error: String?
    private let YTM = YouTubeModel()
    private let authService: YouTubeAuthService
    
    init(authService: YouTubeAuthService) {
        self.authService = authService
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
                let streamingInfos = try await video.fetchStreamingInfosThrowing(youtubeModel: self.YTM)
                
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
                        if !self.authService.isAuthenticated {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                self.authService.signIn(from: window)
                            } else {
                                self.error = "Could not present authentication window"
                            }
                        } else {
                            self.error = "Authentication failed. Please try signing in again."
                        }
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
        if YTM.visitorData.isEmpty {
            if let visitorData = try? await SearchResponse.sendThrowingRequest(youtubeModel: YTM, data: [.query: "homefwhfjoifj"]).visitorData {
                YTM.visitorData = visitorData
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

struct VideoPlayerView: View {
    @StateObject private var authService = YouTubeAuthService()
    @StateObject private var playerModel: PlayerViewModel
    @State private var isFullscreen: Bool = false
    
    let video: YTVideo
    
    init(video: YTVideo) {
        self.video = video
        _playerModel = StateObject(wrappedValue: PlayerViewModel(authService: YouTubeAuthService()))
    }
    
    var body: some View {
        VStack {
            if playerModel.isLoading {
                ProgressView()
            } else if let error = playerModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                if !isFullscreen {
                    VideoPlayer(player: playerModel.player)
                        .aspectRatio(16/9, contentMode: .fit)
                }
            }
            
            Button("Sign In") {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    print("Attempting to sign in")
                    authService.signIn(from: window)
                } else {
                    print("Window or windowScene is nil")
                }
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            VideoPlayer(player: playerModel.player)
                .ignoresSafeArea()
                .gesture(DragGesture(minimumDistance: 20, coordinateSpace: .global).onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    if abs(horizontalAmount) > abs(verticalAmount) {
                        print(horizontalAmount < 0 ? "left swipe" : "right swipe")
                    } else {
                        print(verticalAmount < 0 ? "up swipe" : "down swipe")
                        
                        if verticalAmount > 0 {
                            isFullscreen = false
                        }
                    }
                })
        }
        .onAppear {
            playerModel.loadVideo(video: video)
        }
        .onDisappear {
            playerModel.cleanup()
        }
        .onRotate { orientation in
            isFullscreen = orientation != .landscapeLeft || orientation != .landscapeRight
        }
        .onChange(of: authService.isAuthenticated) {
            if authService.isAuthenticated {
                playerModel.loadVideo(video: video)
            }
        }
    }
}

#Preview {
    let sampleVideo = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What's new in SwiftUI | Apple",
        channel: YTLittleChannelInfos(
            channelId: "",
            name: "MacRumors"
        ),
        viewCount: "64K views",
        timeLength: "6:31",
        thumbnails: [
            YTThumbnail(
                url: URL(string: "https://i.ytimg.com/vi/cETgTtu6atM/hq720.jpg?sqp=-oaymwEjCOgCEMoBSFryq4qpAxUIARUAAAAAGAElAADIQj0AgKJDeAE=&rs=AOn4CLCewFWvccdDn7llqNJmmFRGHeOCIQ")!
            )
        ]
    )
    
    VideoPlayerView(video: sampleVideo)
}
