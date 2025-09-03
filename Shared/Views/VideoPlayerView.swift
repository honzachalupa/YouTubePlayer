import SwiftUI
import YouTubeKit
import AVKit

struct VideoPlayerView: View {
    public let video: YTVideo
    
    @ObservedObject private var messageService = MessageService.shared
    @EnvironmentObject private var videoManager: VideoManager
    
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
            if videoManager.isLoading {
                if let thumbnailURL = video.thumbnails.last?.url {
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
            } else if let player = videoManager.player {
                CustomVideoPlayer(player: player)
                    .onAppear {
                        // Only play if not already playing
                        if !videoManager.isPlaying {
                            player.play()
                            videoManager.isPlaying = true
                        }
                    }
                    .onDisappear {
                        // Don't stop playback when view disappears to support background playback
                        if !videoManager.isPlaying {
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
        .ignoresSafeArea()
        .task {
            // Only load the video if it's different from the currently selected one
            if videoManager.selectedVideo?.videoId != video.videoId {
                await videoManager.loadVideo(video)
            } else if !videoManager.isPlaying {
                // If it's the same video but not playing, ensure it plays
                videoManager.player?.play()
                videoManager.isPlaying = true
            }
        }
        .onChange(of: video) {
            // Only load if it's a different video
            if videoManager.selectedVideo?.videoId != video.videoId {
                Task { await videoManager.loadVideo(video) }
            }
        }
        .onChange(of: videoManager.error) {
            if let errorMessage = videoManager.error {
                messageService.show(message: errorMessage, type: .error)
            }
        }
    }
}

#Preview {
    let video = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What's new in SwiftUI",
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
    
    VideoPlayerView(video: video)
}
