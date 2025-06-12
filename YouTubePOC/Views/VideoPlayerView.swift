import SwiftUI
import AVKit
import YouTubeKit

@MainActor final class PlayerViewModel: ObservableObject, @unchecked Sendable {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    private let YTM = YouTubeModel()
    
    func loadVideo(video: YTVideo) {
        isLoading = true
        
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
                        self.isLoading = false
                    }

                    return
                }
                
                await MainActor.run {
                    self.player = AVPlayer(url: streamingURL)
                    self.player?.play()
                    self.isLoading = false
                }
            } catch {
                print("Error loading video: \(error)")

                await MainActor.run {
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
    @StateObject private var playerModel = PlayerViewModel()
    @State private var isFullscreen: Bool = false
    
    let video: YTVideo
    
    var body: some View {
        VStack {
            if playerModel.isLoading {
                ProgressView()
            } else {
                if !isFullscreen {
                    VideoPlayer(player: playerModel.player)
                        .aspectRatio(16/9, contentMode: .fit)
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
    }
}

#Preview {
    let sampleVideo = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What’s new in SwiftUI | Apple",
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
