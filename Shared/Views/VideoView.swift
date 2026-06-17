import SwiftUI
import YouTubeKit

struct VideoView: View {
    public let video: YTVideo
    private let detailTopAnchorID = "video-detail-top"
    
    private let youtubeService = YouTubeService.shared
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var videoManager: VideoManager
    @StateObject private var messageService = MessageService.shared
    @State private var description: String? = nil
    @State private var recommendedVideos: [YTVideo] = []
    @State private var moreInfosResponse: MoreVideoInfosResponse?
    @State private var isLoadingMoreRecommended = false
    @State private var isVideoActionsToolbarHidden = false
    @State private var videoDetailsSectionHeight: CGFloat = 0
    #if os(iOS)
    @State private var isLandscapeFullscreenPresented = false
    #endif

    private enum DetailQueueSection {
        case recommended(videos: [YTVideo])
        case playlist(title: String, videos: [YTVideo])
    }

    init(video: YTVideo) {
        self.video = video

        if let cachedDetails = YouTubeService.shared.cachedDetails(for: video.videoId) {
            _description = State(initialValue: cachedDetails.description)
            _recommendedVideos = State(initialValue: cachedDetails.recommendedVideos)
            _moreInfosResponse = State(initialValue: cachedDetails.response)
        } else if let persistedDetails = YouTubeService.shared.cachedPersistedDetails(for: video.videoId) {
            _description = State(initialValue: persistedDetails.description)
            _recommendedVideos = State(initialValue: persistedDetails.recommendedVideos)
            _moreInfosResponse = State(initialValue: nil)
        }
    }
    
    private var currentVideo: YTVideo {
        videoManager.selectedVideo ?? video
    }

    private var detailQueueSection: DetailQueueSection? {
        if let playbackQueueContext = videoManager.playbackQueueContext {
            let followingVideos = playbackQueueContext.followingVideos(after: currentVideo.videoId)

            switch playbackQueueContext.source {
            case .recommended:
                if !followingVideos.isEmpty {
                    return .recommended(videos: followingVideos)
                }
            case .playlist(let title):
                if !followingVideos.isEmpty {
                    return .playlist(title: title, videos: followingVideos)
                }
            }
        }

        if !recommendedVideos.isEmpty {
            return .recommended(videos: recommendedVideos)
        }

        return nil
    }

    private var detailQueueContextForSelection: VideoManager.PlaybackQueueContext? {
        if videoManager.isUsingPlaylistQueue(for: currentVideo.videoId) {
            return videoManager.playbackQueueContext
        }

        return VideoManager.PlaybackQueueContext(
            source: .recommended,
            videos: [currentVideo] + recommendedVideos
        )
    }

    #if os(iOS)
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private func updateLandscapeFullscreen(for orientation: UIDeviceOrientation) {
        guard isPhone else { return }

        switch orientation {
        case .landscapeLeft, .landscapeRight:
            isLandscapeFullscreenPresented = true
        case .portrait:
            isLandscapeFullscreenPresented = false
        case .portraitUpsideDown, .faceUp, .faceDown, .unknown:
            break
        @unknown default:
            break
        }
    }
    #endif

    func fetchDetails(for video: YTVideo) async {
        do {
            await youtubeService.getVisitorData()
            
            let response = try await video.fetchMoreInfosThrowing(
                youtubeModel: youtubeService.model
            )
            
            guard currentVideo.videoId == video.videoId else { return }

            let resolvedDescription = response.videoDescription?.map { part in
                part.text ?? ""
            }.joined()
            let resolvedRecommendedVideos = response.recommendedVideos.compactMap { $0 as? YTVideo }

            youtubeService.cacheVideoDetails(
                response: response,
                description: resolvedDescription,
                recommendedVideos: resolvedRecommendedVideos,
                for: video.videoId
            )
            videoManager.setRecommendedQueue(currentVideo: video, recommendedVideos: resolvedRecommendedVideos)
            
            withAnimation {
                moreInfosResponse = response
                description = resolvedDescription
                recommendedVideos = resolvedRecommendedVideos
            }
        } catch {
            messageService.show(message: error.localizedDescription, type: .error)
        }
    }

    private func loadMoreRecommendedIfNeeded(current video: YTVideo) {
        guard let lastVideo = recommendedVideos.last,
              video.videoId == lastVideo.videoId,
              !isLoadingMoreRecommended else {
            return
        }

        Task { await fetchMoreRecommendedVideos() }
    }

    private func fetchMoreRecommendedVideos() async {
        guard var response = moreInfosResponse,
              response.recommendedVideosContinuationToken != nil else {
            return
        }

        let requestedVideoId = currentVideo.videoId
        isLoadingMoreRecommended = true
        defer { isLoadingMoreRecommended = false }

        do {
            let continuation = try await response.getRecommendedVideosContinationThrowing(
                youtubeModel: youtubeService.model
            )
            guard currentVideo.videoId == requestedVideoId else { return }

            response.mergeRecommendedVideosContination(continuation)
            let newVideos = continuation.results.compactMap { $0 as? YTVideo }

            withAnimation {
                moreInfosResponse = response
                recommendedVideos.append(contentsOf: newVideos)
            }

            youtubeService.cacheVideoDetails(
                response: response,
                description: description,
                recommendedVideos: recommendedVideos,
                for: requestedVideoId
            )
            
            videoManager.setRecommendedQueue(currentVideo: currentVideo, recommendedVideos: recommendedVideos)
        } catch {
            guard currentVideo.videoId == requestedVideoId else { return }
            print("Error loading more recommended videos:", error)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                #if os(iOS)
                if !isLandscapeFullscreenPresented {
                    VideoPlayerView(video: currentVideo)
                        .id(currentVideo.videoId)
                }
                #else
                VideoPlayerView(video: currentVideo)
                    .id(currentVideo.videoId)
                #endif
            
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading) {
                            videoDetailsSection

                            if let detailQueueSection {
                                queueSection(detailQueueSection)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onScrollGeometryChange(
                        for: CGFloat.self,
                        of: { geometry in
                            geometry.contentOffset.y + geometry.contentInsets.top
                        },
                        action: { _, offset in
                            guard detailQueueSection != nil else {
                                withAnimation {
                                    isVideoActionsToolbarHidden = false
                                }
                                return
                            }

                            let shouldHideToolbar = offset >= videoDetailsSectionHeight
                            guard shouldHideToolbar != isVideoActionsToolbarHidden else { return }

                            withAnimation {
                                isVideoActionsToolbarHidden = shouldHideToolbar
                            }
                        }
                    )
                    .onChange(of: detailQueueSection == nil) { _, isQueueMissing in
                        if isQueueMissing {
                            withAnimation {
                                isVideoActionsToolbarHidden = false
                            }
                        }
                    }
                    .onChange(of: currentVideo.videoId) {
                        proxy.scrollTo(detailTopAnchorID, anchor: .top)
                        isVideoActionsToolbarHidden = false
                    }
                }
            }
            .navigationDestination(for: YTLittleChannelInfos.self) { channelInfo in
                ChannelView(channelInfo: channelInfo)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                
                VideoActionsToolbarView(video: currentVideo)
            }
            .toolbarVisibility(isVideoActionsToolbarHidden ? .hidden : .visible, for: .bottomBar)
        }
        .task(id: currentVideo.videoId) {
            if let cachedDetails = youtubeService.cachedDetails(for: currentVideo.videoId) {
                description = cachedDetails.description
                recommendedVideos = cachedDetails.recommendedVideos
                moreInfosResponse = cachedDetails.response
                videoManager.setRecommendedQueue(currentVideo: currentVideo, recommendedVideos: cachedDetails.recommendedVideos)
            } else if let persistedDetails = youtubeService.cachedPersistedDetails(for: currentVideo.videoId) {
                description = persistedDetails.description
                recommendedVideos = persistedDetails.recommendedVideos
                moreInfosResponse = nil
                videoManager.setRecommendedQueue(currentVideo: currentVideo, recommendedVideos: persistedDetails.recommendedVideos)
                await fetchDetails(for: currentVideo)
            } else {
                description = nil
                recommendedVideos = []
                moreInfosResponse = nil
                await fetchDetails(for: currentVideo)
            }
        }
        .onAppear {
            isVideoActionsToolbarHidden = false
            #if os(iOS)
            updateLandscapeFullscreen(for: UIDevice.current.orientation)
            #endif
        }
        .onDisappear {
            isVideoActionsToolbarHidden = false
        }
        #if os(iOS)
        .onRotate { orientation in
            updateLandscapeFullscreen(for: orientation)
        }
        .fullScreenCover(isPresented: $isLandscapeFullscreenPresented) {
            ZStack {
                Color.black.ignoresSafeArea()
                VideoPlayerView(video: currentVideo, isFullscreen: true)
                    .environmentObject(videoManager)
            }
            .ignoresSafeArea()
            .onRotate { orientation in
                updateLandscapeFullscreen(for: orientation)
            }
        }
        #endif
    }

    private var videoDetailsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(currentVideo.title ?? "")
                .font(.title)
            
            if let channelInfo = currentVideo.channel {
                NavigationLink(value: channelInfo) {
                    VideoInfoView(video: currentVideo, mainLabel: .channelName)
                }
                .foregroundStyle(.foreground)
            }
            
            if let description {
                Text(.init(description))
            }
        }
        .background(alignment: .topLeading) {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        videoDetailsSectionHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        videoDetailsSectionHeight = newHeight
                    }
            }
        }
    }

    private func queueSection(_ section: DetailQueueSection) -> some View {
        let sectionTitle: String
        let sectionVideos: [YTVideo]
        let showsLoadMore: Bool

        switch section {
        case .recommended(let videos):
            sectionTitle = "Recommended"
            sectionVideos = videos
            showsLoadMore = true
        case .playlist(let title, let videos):
            sectionTitle = title
            sectionVideos = videos
            showsLoadMore = false
        }

        return VStack(alignment: .leading, spacing: 10) {
            Divider()
            
            Text(sectionTitle)
                .font(.headline)

            LazyVStack(spacing: 10) {
                ForEach(sectionVideos, id: \.videoId) { video in
                    RelatedVideoRow(
                        video: video,
                        playbackQueueContext: detailQueueContextForSelection
                    )
                        .onAppear {
                            if showsLoadMore {
                                loadMoreRecommendedIfNeeded(current: video)
                            }
                        }
                }

                if showsLoadMore && isLoadingMoreRecommended {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct RelatedVideoRow: View {
    let video: YTVideo
    let playbackQueueContext: VideoManager.PlaybackQueueContext?

    @EnvironmentObject private var videoManager: VideoManager

    var body: some View {
        Button {
            videoManager.selectVideo(video, playbackQueueContext: playbackQueueContext)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

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
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                            .padding(5)
                    }
                }
                .frame(width: 150, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(video.channel?.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    let metadata = [video.viewCount, video.timePosted]
                        .compactMap { $0 }
                        .joined(separator: " • ")

                    if !metadata.isEmpty {
                        Text(metadata)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VideoView(video: YTVideo(videoId: "dQw4w9WgXcQ"))
        .environmentObject(VideoManager())
}
