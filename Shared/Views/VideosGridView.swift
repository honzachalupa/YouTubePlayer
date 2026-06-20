import SwiftUI
import YouTubeKit

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollViewContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct VideosGridView: View {
    public var videos: [YTVideo]
    public var error: Error?
    public var fetchVideos: () async -> Void
    public var loadMoreIfNeeded: ((YTVideo) -> Void)?
    public var isLoadingMore: Bool = false
    public var autoFillRetryKey: Int?
    public var playbackQueueContextProvider: ((YTVideo) -> VideoManager.PlaybackQueueContext?)?
    
    @ObservedObject private var messageService = MessageService.shared
    @State private var selectedVideo: YTVideo? = nil
    @State private var isLoading: Bool = true
    @State private var isRefreshing: Bool = false
    @State private var scrollViewportWidth: CGFloat = 0
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 0
    @State private var lastAutoFillAttemptVideoCount: Int = -1
    
    func fetch() async {
        if !isRefreshing {
            isLoading = true
        }
        
        await fetchVideos()
        
        isLoading = false
        isRefreshing = false
    }
    
    func getColumns(for width: CGFloat) -> [GridItem] {
        if width > 1500 {
            return [GridItem(
                .adaptive(minimum: 500, maximum: 1200),
                spacing: 20,
                alignment: .top
            )]
        } else {
            return [GridItem(
                .adaptive(minimum: 320, maximum: 1200),
                spacing: 20,
                alignment: .top
            )]
        }
    }
    
    private func updateScrollViewportSize(_ size: CGSize) {
        scrollViewportWidth = size.width
        scrollViewportHeight = size.height
        triggerLoadMoreIfViewportNotFilled()
    }
    
    private func triggerLoadMoreIfViewportNotFilled() {
        guard let loadMoreIfNeeded, let lastVideo = videos.last else { return }
        guard !videos.isEmpty else { return }
        guard scrollViewportHeight > 0, scrollContentHeight > 0 else { return }
        
        // Only auto-attempt once per visible item count to avoid repeated loops when there is no more data.
        guard lastAutoFillAttemptVideoCount != videos.count else { return }
        
        let threshold: CGFloat = 24
        guard scrollContentHeight <= scrollViewportHeight + threshold else { return }
        
        lastAutoFillAttemptVideoCount = videos.count
        loadMoreIfNeeded(lastVideo)
    }
    
    var body: some View {
        Group {
            if isLoading && !isRefreshing && videos.isEmpty {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            } else if videos.isEmpty {
                Spacer()
                ContentUnavailableView("No videos found", systemImage: "play.slash.fill")
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVGrid(columns: getColumns(for: scrollViewportWidth), spacing: 20) {
                            ForEach(videos, id: \.videoId) { video in
                                VideoGridItemView(
                                    video: video,
                                    playbackQueueContextProvider: playbackQueueContextProvider
                                )
                                .onAppear {
                                    if let lastVideo = videos.last, video.videoId == lastVideo.videoId {
                                        print("Last video appeared, triggering load more")
                                        loadMoreIfNeeded?(video)
                                    }
                                }
                            }
                        }
                        
                        // Footer sentinel handles large viewports where content does not become scrollable.
                        if let lastVideo = videos.last, loadMoreIfNeeded != nil {
                            Color.clear
                                .frame(height: 1)
                                .id("load-more-sentinel-\(videos.count)")
                                .onAppear {
                                    loadMoreIfNeeded?(lastVideo)
                                }
                        }

                        if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.regular)
                                Spacer()
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        }
                    }
                    .padding()
                    .background {
                        GeometryReader { contentProxy in
                            Color.clear
                                .preference(
                                    key: ScrollViewContentHeightPreferenceKey.self,
                                    value: contentProxy.size.height
                                )
                        }
                    }
                }
                .background {
                    GeometryReader { viewportProxy in
                        Color.clear
                            .onAppear {
                                updateScrollViewportSize(viewportProxy.size)
                            }
                            .onChange(of: viewportProxy.size) {
                                updateScrollViewportSize(viewportProxy.size)
                            }
                    }
                }
                .animation(.easeInOut, value: videos)
                .onChange(of: videos.count) {
                    if videos.isEmpty {
                        lastAutoFillAttemptVideoCount = -1
                    }
                    triggerLoadMoreIfViewportNotFilled()
                }
                .onChange(of: autoFillRetryKey) {
                    lastAutoFillAttemptVideoCount = -1
                    triggerLoadMoreIfViewportNotFilled()
                }
                .onPreferenceChange(ScrollViewContentHeightPreferenceKey.self) { value in
                    scrollContentHeight = value
                    triggerLoadMoreIfViewportNotFilled()
                }
                .refreshable {
                    isRefreshing = true
                    await fetch()
                }
            }
        }
        .task { await fetch() }
        .onChange(of: error?.localizedDescription) {
            if let error {
                messageService.show(message: error.localizedDescription, type: .error)
            }
        }
    }
}

struct VideoGridItemView: View {
    public let video: YTVideo
    public var playbackQueueContextProvider: ((YTVideo) -> VideoManager.PlaybackQueueContext?)?
    public var onSelect: ((YTVideo) -> Void)?
    public var navigationValue: VideoSheetRoute?
    public var channelThumbnailURL: URL?
    
    @EnvironmentObject private var videoManager: VideoManager
    @FocusState private var isFocused: Bool
    
    init(
        video: YTVideo,
        playbackQueueContextProvider: ((YTVideo) -> VideoManager.PlaybackQueueContext?)? = nil,
        onSelect: ((YTVideo) -> Void)? = nil,
        navigationValue: VideoSheetRoute? = nil,
        channelThumbnailURL: URL? = nil
    ) {
        self.video = video
        self.playbackQueueContextProvider = playbackQueueContextProvider
        self.onSelect = onSelect
        self.navigationValue = navigationValue
        self.channelThumbnailURL = channelThumbnailURL
    }
    
    var body: some View {
        itemContent
            .contextMenu {
                Section("Add to playlist") {
                    AddRemoveVideoPlaylistListView(video: video)
                        .id(video.videoId)
                }
            }
    }
    
    @ViewBuilder
    private var itemContent: some View {
        #if os(tvOS)
        NavigationLink {
            VideoView(video: video)
                .task {
                    videoManager.setPlaybackQueueContext(playbackQueueContextProvider?(video))
                    await videoManager.loadVideo(video)
                }
                .onAppear {
                    print("NavigationLink appeared")
                }
        } label: {
            VideoContent(video: video, channelThumbnailURL: channelThumbnailURL)
        }
        .buttonStyle(.card)
        .focused($isFocused)
        #else
        if let navigationValue {
            NavigationLink(value: navigationValue) {
                VideoContent(video: video, channelThumbnailURL: channelThumbnailURL)
            }
            .buttonStyle(.plain)
        } else {
            VideoContent(video: video, channelThumbnailURL: channelThumbnailURL)
                .onTapGesture {
                    if let onSelect {
                        onSelect(video)
                    } else {
                        videoManager.selectVideo(
                            video,
                            playbackQueueContext: playbackQueueContextProvider?(video)
                        )
                    }
                }
        }
        #endif
    }
}

private struct VideoContent: View {
    let video: YTVideo
    let channelThumbnailURL: URL?

    @EnvironmentObject private var videoManager: VideoManager
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                if let thumbnailURL = video.thumbnails.last?.url {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } placeholder: {
                        Color.clear
                    }
                }

                VStack {
                    Spacer()

                    HStack(spacing: 5) {
                        Spacer()

                        Group {
                            if videoManager.hasOpenedDetail(for: video) {
                                Image(systemName: "eye.fill")
                                    .frame(width: 13, height: 13)
                                    .background(.thinMaterial, in: .circle)
                            }

                            if let timeLength = video.timeLength, !timeLength.isEmpty {
                                Text(timeLength)
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .frame(height: 13)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: .capsule)
                    }
                }
                .padding(5)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)
            .clipped()
            
            VideoInfoView(video: video, mainLabel: .videoTitle, channelThumbnailURL: channelThumbnailURL)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 5)

            Spacer()
        }
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10)
    }
}

#Preview {
    let video = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What's new in SwiftUI",
        channel: YTLittleChannelInfos(
            channelId: "",
            name: "MacRumors",
            thumbnails: [
                YTThumbnail(url: URL(string: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s68-c-k-c0x00ffffff-no-rj")!)
            ]
        ),
        viewCount: "64K views",
        timeLength: "6:31",
        thumbnails: [
            YTThumbnail(
                url: URL(string: "https://i.ytimg.com/vi/cETgTtu6atM/hq720.jpg?sqp=-oaymwEjCOgCEMoBSFryq4qpAxUIARUAAAAAGAElAADIQj0AgKJDeAE=&rs=AOn4CLCewFWvccdDn7llqNJmmFRGHeOCIQ")!
            )
        ]
    )
    
    VideosGridView(videos: [video, video, video], fetchVideos: { Task.init { } }, loadMoreIfNeeded: { _ in })
        .environmentObject(VideoManager())
}
