import SwiftUI
import YouTubeKit
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    public let video: YTVideo
    var isFullscreen = false
    var relatedVideos: [YTVideo] = []
    var relatedTitle: String = String(localized: "Recommended")
    var relatedSelectionContext: VideoManager.PlaybackQueueContext? = nil
    var videoDescription: String? = nil
    
    @ObservedObject private var messageService = MessageService.shared
    @EnvironmentObject private var videoManager: VideoManager
    
    private struct CustomVideoPlayer: UIViewControllerRepresentable {
        let video: YTVideo
        let player: AVQueuePlayer
        let relatedVideos: [YTVideo]
        let relatedTitle: String
        let relatedSelectionContext: VideoManager.PlaybackQueueContext?
        let videoDescription: String?
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

            #if os(tvOS)
            configureTVOSPlayer(uiViewController, coordinator: context.coordinator)
            #endif
        }

        static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
            coordinator.hostingController?.view.removeFromSuperview()
            coordinator.hostingController = nil
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

        #if os(tvOS)
        private func configureTVOSPlayer(_ controller: AVPlayerViewController, coordinator: Coordinator) {
            controller.transportBarIncludesTitleView = true
            controller.playbackControlsIncludeInfoViews = true
            controller.player?.currentItem?.externalMetadata = makeTVOSMetadata()
            updateTVOSInfoViewControllers(for: controller, coordinator: coordinator)
        }

        private func updateTVOSInfoViewControllers(for controller: AVPlayerViewController, coordinator: Coordinator) {
            guard !relatedVideos.isEmpty else {
                coordinator.relatedInfoHostingController = nil
                coordinator.relatedInfoControllerKey = nil
                if !controller.customInfoViewControllers.isEmpty {
                    controller.customInfoViewControllers = []
                }
                return
            }

            let relatedView = AnyView(
                TVOSRelatedVideosInfoView(
                    videos: relatedVideos,
                    playbackQueueContext: relatedSelectionContext
                )
                .environmentObject(videoManager)
            )

            let relatedControllerKey = makeRelatedInfoControllerKey()

            if let hostingController = coordinator.relatedInfoHostingController {
                hostingController.rootView = relatedView
                hostingController.title = relatedTitle

                if coordinator.relatedInfoControllerKey != relatedControllerKey {
                    coordinator.relatedInfoControllerKey = relatedControllerKey
                    controller.customInfoViewControllers = [hostingController]
                } else if controller.customInfoViewControllers.first !== hostingController {
                    controller.customInfoViewControllers = [hostingController]
                }
            } else {
                let hostingController = UIHostingController(rootView: relatedView)
                hostingController.title = relatedTitle
                hostingController.view.backgroundColor = UIColor(white: 0.08, alpha: 1)
                hostingController.preferredContentSize = CGSize(width: 1320, height: 340)

                coordinator.relatedInfoHostingController = hostingController
                coordinator.relatedInfoControllerKey = relatedControllerKey
                controller.customInfoViewControllers = [hostingController]
            }
        }

        private func makeRelatedInfoControllerKey() -> String {
            let videoIDs = relatedVideos.map(\.videoId).joined(separator: "|")
            let queueSource: String

            switch relatedSelectionContext?.source {
            case .recommended:
                queueSource = "recommended"
            case .playlist(let title):
                queueSource = "playlist:\(title)"
            case nil:
                queueSource = "none"
            }

            return "\(relatedTitle)#\(queueSource)#\(videoIDs)"
        }

        private func makeTVOSMetadata() -> [AVMetadataItem] {
            var items: [AVMetadataItem] = []

            if let title = video.title, !title.isEmpty {
                items.append(makeMetadataItem(identifier: .commonIdentifierTitle, value: title))
            }

            let subtitle = [video.channel?.name, metadataLine]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")

            if !subtitle.isEmpty {
                items.append(makeMetadataItem(identifier: .iTunesMetadataTrackSubTitle, value: subtitle))
            }

            if let videoDescription, !videoDescription.isEmpty {
                items.append(makeMetadataItem(identifier: .commonIdentifierDescription, value: videoDescription))
            }

            return items
        }

        private var metadataLine: String? {
            let components = [video.viewCount, video.timePosted]
                .compactMap { $0 }
                .filter { !$0.isEmpty }

            guard !components.isEmpty else { return nil }
            return components.joined(separator: " • ")
        }

        private func makeMetadataItem(identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
            let item = AVMutableMetadataItem()
            item.identifier = identifier
            item.value = value as NSString
            item.extendedLanguageTag = "und"
            return item.copy() as! AVMetadataItem
        }
        #endif

        final class Coordinator {
            var hostingController: UIHostingController<AnyView>?
            var relatedInfoHostingController: UIHostingController<AnyView>?
            var relatedInfoControllerKey: String?
        }
    }
    
    var body: some View {
        playerContent
            .modifier(VideoPlayerLayoutModifier(isFullscreen: isFullscreen))
            .modifier(PlaybackIdleTimerModifier(isPlaying: videoManager.isPlaying))
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
                CustomVideoPlayer(
                    video: video,
                    player: player,
                    relatedVideos: relatedVideos,
                    relatedTitle: relatedTitle,
                    relatedSelectionContext: relatedSelectionContext,
                    videoDescription: videoDescription,
                    videoManager: videoManager
                )
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

private struct PlaybackIdleTimerModifier: ViewModifier {
    let isPlaying: Bool

    #if os(iOS)
    @State private var requestID = UUID()
    @State private var isVisible = false
    #endif

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onAppear {
                isVisible = true
                updateIdleTimer()
            }
            .onDisappear {
                isVisible = false
                PlaybackIdleTimer.release(requestID)
            }
            .onChange(of: isPlaying) {
                updateIdleTimer()
            }
        #else
        content
        #endif
    }

    #if os(iOS)
    private func updateIdleTimer() {
        if isVisible && isPlaying {
            PlaybackIdleTimer.retain(requestID)
        } else {
            PlaybackIdleTimer.release(requestID)
        }
    }
    #endif
}

#if os(iOS)
@MainActor
private enum PlaybackIdleTimer {
    private static var activeRequestIDs: Set<UUID> = []

    static func retain(_ id: UUID) {
        activeRequestIDs.insert(id)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func release(_ id: UUID) {
        activeRequestIDs.remove(id)
        UIApplication.shared.isIdleTimerDisabled = !activeRequestIDs.isEmpty
    }
}
#endif

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
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: promptCornerRadius, style: .continuous))
        .modifier(NextVideoPromptDismissGesture(videoManager: videoManager))
    }
}

#if os(tvOS)
private struct TVOSRelatedVideosInfoView: View {
    let videos: [YTVideo]
    let playbackQueueContext: VideoManager.PlaybackQueueContext?

    @EnvironmentObject private var videoManager: VideoManager

    var body: some View {
        ZStack {
            Color(white: 0.08)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(videos, id: \.videoId) { video in
                        Button {
                            videoManager.selectVideo(video, playbackQueueContext: playbackQueueContext)
                        } label: {
                            TVOSRelatedVideoCard(video: video)
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
            .scrollClipDisabled()
            .buttonStyle(.card)
        }
    }
}

private struct TVOSRelatedVideoCard: View {
    let video: YTVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                if let thumbnailURL = video.thumbnails.last?.url {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }

                if let timeLength = video.timeLength {
                    Text(timeLength)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(12)
                }
            }
            .frame(width: 340, height: 192)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title ?? "")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(video.channel?.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                let metadata = [video.viewCount, video.timePosted]
                    .compactMap { $0 }
                    .joined(separator: " • ")

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 340, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
#endif

private struct NextVideoPromptDismissGesture: ViewModifier {
    let videoManager: VideoManager

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
        #else
        content.gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let translation = value.translation
                    guard abs(translation.width) > 44 || abs(translation.height) > 44 else { return }
                    videoManager.dismissNextVideoPrompt()
                }
        )
        #endif
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

#Preview("NextVideoPromptOverlay") {
    let videoManager = VideoManager()
    let nextVideo = YTVideo(
        videoId: "preview-next-video",
        title: "Claude FM 🎵 music for thinking and building",
        channel: YTLittleChannelInfos(
            channelId: "preview-channel",
            name: "OpenAI"
        )
    )

    videoManager.debugSetNextVideoPrompt(
        .init(video: nextVideo, remainingSeconds: 3)
    )

    return NextVideoPromptOverlay()
        .environmentObject(videoManager)
}
