import SwiftUI
import AVKit

struct VideoPlayerView: View {
    public let video: YouTubeVideo
    
    @ObservedObject private var messageService = MessageService.shared
    @EnvironmentObject private var playerManager: PlayerManager
    
    private struct CustomVideoPlayer: UIViewControllerRepresentable {
        let player: AVPlayer
        
        func makeUIViewController(context: Context) -> AVPlayerViewController {
            let controller = AVPlayerViewController()
            controller.player = player
            controller.allowsPictureInPicturePlayback = true
            return controller
        }
        
        func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) { }
    }
    
    var body: some View {
        Group {
            if playerManager.isLoading && playerManager.selectedVideo?.id == video.id {
                if let thumbnailURL = URL(string: video.snippet.thumbnails.maxres?.url ?? 
                                        video.snippet.thumbnails.standard?.url ??
                                        video.snippet.thumbnails.high?.url ??
                                        video.snippet.thumbnails.medium?.url ??
                                        video.snippet.thumbnails.default?.url ?? "") {
                    AsyncImage(url: thumbnailURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .overlay {
                                    Color.black.opacity(0.3)
                                    ProgressView()
                                        .controlSize(.large)
                                }
                        } else {
                            Color.gray.opacity(0.2)
                                .overlay {
                                    ProgressView()
                                        .controlSize(.large)
                                }
                        }
                    }
                } else {
                    Color.gray.opacity(0.2)
                        .overlay {
                            ProgressView()
                                .controlSize(.large)
                        }
                }
            } else if let player = playerManager.player {
                CustomVideoPlayer(player: player)
                    .onAppear {
                        // Only play if not already playing
                        if !playerManager.isPlaying {
                            player.play()
                            playerManager.isPlaying = true
                        }
                    }
                    .onDisappear {
                        // Don't stop playback when view disappears to support background playback
                        if !playerManager.isPlaying {
                            player.pause()
                        }
                    }
            } else {
                Color.gray.opacity(0.2)
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                    }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .onAppear {
            // Only load the video if it's different from the currently selected one
            if playerManager.selectedVideo?.id != video.id {
                playerManager.selectVideo(video)
            } else if !playerManager.isPlaying {
                // If it's the same video but not playing, ensure it plays
                playerManager.player?.play()
                playerManager.isPlaying = true
            }
        }
        .onChange(of: video) {
            // Only load if it's a different video
            if playerManager.selectedVideo?.id != video.id {
                playerManager.selectVideo(video)
            }
        }
        .onChange(of: playerManager.error) {
            if let errorMessage = playerManager.error {
                messageService.show(message: errorMessage, type: .error)
            }
        }
    }
}

#Preview {
    VideoPlayerView(video: YouTubeVideo(
        id: "cETgTtu6atM",
        snippet: .init(
            publishedAt: "2024-03-15T10:00:00Z",
            channelId: "UC9M3-PXEcXzwZGEWY46VNTw",
            title: "WWDC25: What's new in SwiftUI",
            description: "A preview of the new SwiftUI features announced at WWDC25",
            thumbnails: .init(
                default: .init(
                    url: "https://i.ytimg.com/vi/cETgTtu6atM/default.jpg",
                    width: 120,
                    height: 90
                ),
                medium: .init(
                    url: "https://i.ytimg.com/vi/cETgTtu6atM/mqdefault.jpg",
                    width: 320,
                    height: 180
                ),
                high: .init(
                    url: "https://i.ytimg.com/vi/cETgTtu6atM/hqdefault.jpg",
                    width: 480,
                    height: 360
                ),
                standard: nil,
                maxres: nil
            ),
            channelTitle: "MacRumors",
            tags: ["WWDC25", "SwiftUI", "iOS"],
            categoryId: "28",
            liveBroadcastContent: "none"
        ),
        contentDetails: nil,
        statistics: nil
    ))
    .environmentObject(PlayerManager())
}
