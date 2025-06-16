import SwiftUI
import YouTubeKit
import AVKit

struct VideoPlayerView: View {
    public let video: YTVideo
    
    @EnvironmentObject private var playerManager: PlayerManager
    @State private var isFullscreen: Bool = false
    
    @ViewBuilder
    func FullScreenButton() -> some View {
        Button {
            isFullscreen.toggle()
        } label: {
            if isFullscreen {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            } else {
                Label("Enter fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        }
        .buttonStyle(.glass)
        .padding()
    }
    
    var body: some View {
        Group {
            if playerManager.isLoading && playerManager.selectedVideo?.videoId == video.videoId {
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
            } else if let error = playerManager.error, playerManager.selectedVideo?.videoId == video.videoId {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle.fill")
            } else if let player = playerManager.player {
                ZStack(alignment: .top) {
                    VideoPlayer(player: player)
                        .onAppear {
                            // Only play if not already playing
                            if !playerManager.isPlaying {
                                player.play()
                                playerManager.isPlaying = true
                            }
                        }
                    
                    FullScreenButton()
                }
                .fullScreenCover(isPresented: $isFullscreen) {
                    ZStack(alignment: .top) {
                        VideoPlayer(player: player)
                        
                        FullScreenButton()
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
            if playerManager.selectedVideo?.videoId != video.videoId {
                playerManager.loadVideo(video)
            } else if !playerManager.isPlaying {
                // If it's the same video but not playing, ensure it plays
                playerManager.player?.play()
                playerManager.isPlaying = true
            }
        }
        .onChange(of: video) {
            // Only load if it's a different video
            if playerManager.selectedVideo?.videoId != video.videoId {
                playerManager.loadVideo(video)
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
