import SwiftUI
import YouTubeKit
import AVKit

struct VideoPlayerView: View {
    public let video: YTVideo
    var isFullscreen = false
    
    @ObservedObject private var messageService = MessageService.shared
    @EnvironmentObject private var videoManager: VideoManager
    
    private struct CustomVideoPlayer: UIViewControllerRepresentable {
        let player: AVPlayer
        @ObservedObject var videoManager: VideoManager
        
        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIViewController(context: Context) -> AVPlayerViewController {
            let controller = AVPlayerViewController()
            controller.player = player
            controller.allowsPictureInPicturePlayback = true
            installOverlay(in: controller, context: context)
            return controller
        }
        
        func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
            if uiViewController.player !== player {
                uiViewController.player = player
            }

            context.coordinator.hostingController?.rootView = AnyView(
                NextVideoPromptOverlay()
                    .environmentObject(videoManager)
            )
        }

        static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
            coordinator.hostingController?.view.removeFromSuperview()
            coordinator.hostingController = nil
            uiViewController.player = nil
        }

        private func installOverlay(in controller: AVPlayerViewController, context: Context) {
            guard let overlayView = controller.contentOverlayView else { return }

            let hostingController = UIHostingController(
                rootView: AnyView(
                    NextVideoPromptOverlay()
                        .environmentObject(videoManager)
                )
            )
            hostingController.view.backgroundColor = .clear
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false

            overlayView.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: overlayView.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor)
            ])

            context.coordinator.hostingController = hostingController
        }

        final class Coordinator {
            var hostingController: UIHostingController<AnyView>?
        }
    }
    
    var body: some View {
        playerContent
            .modifier(VideoPlayerLayoutModifier(isFullscreen: isFullscreen))
            .task {
                if videoManager.selectedVideo?.videoId != video.videoId {
                    await videoManager.loadVideo(video)
                } else if let player = videoManager.player, !videoManager.isPlaying {
                    player.play()
                    videoManager.isPlaying = true
                }
            }
            .onChange(of: video) {
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

    private var playerContent: some View {
        Group {
            if videoManager.isLoading {
                if let thumbnailURL = video.thumbnails.last?.url {
                    AsyncImage(url: thumbnailURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .overlay {
                                    Color.black
                                        .opacity(0.3)
                                    
                                    ProgressView()
                                        .controlSize(.large)
                                }
                        } else {
                            Color.gray
                                .opacity(0.2)
                                .overlay {
                                    ProgressView()
                                        .controlSize(.large)
                                }
                        }
                    }
                } else {
                    Color.gray
                        .opacity(0.2)
                        .overlay {
                            ProgressView()
                                .controlSize(.large)
                        }
                }
            } else if let player = videoManager.player {
                CustomVideoPlayer(player: player, videoManager: videoManager)
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
            } else if let errorMessage = videoManager.error, !errorMessage.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        
                    Text("Failed to load video")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                Color.gray.opacity(0.2)
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                    }
            }
        }
    }
}

private struct NextVideoPromptOverlay: View {
    @EnvironmentObject private var videoManager: VideoManager

    private let promptCornerRadius: CGFloat = 34

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .allowsHitTesting(false)

            if let prompt = videoManager.nextVideoPrompt {
                promptCard(prompt)
                    .frame(width: 320)
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: videoManager.nextVideoPrompt?.remainingSeconds)
    }

    private func promptCard(_ prompt: VideoManager.NextVideoPrompt) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Next video in \(prompt.remainingSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(prompt.video.title ?? "Next video")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                videoManager.playPromptedNextVideo()
            } label: {
                Label("Play", systemImage: "forward.fill")
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: promptCornerRadius))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let translation = value.translation
                    guard abs(translation.width) > 44 || abs(translation.height) > 44 else { return }
                    videoManager.dismissNextVideoPrompt()
                }
        )
    }
}

private struct NextVideoPromptGlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct VideoPlayerLayoutModifier: ViewModifier {
    let isFullscreen: Bool

    func body(content: Content) -> some View {
        if isFullscreen {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        } else {
            content
                .aspectRatio(16/9, contentMode: .fit)
                .backgroundExtensionEffect()
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
