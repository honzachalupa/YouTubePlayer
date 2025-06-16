import SwiftUI
import YouTubeKit

struct VideosGridView: View {
    public var videos: [YTVideo]
    public var error: Error?
    public var fetchVideos: () async -> Void
    
    @State private var selectedVideo: YTVideo? = nil
    @State private var isLoading: Bool = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 600, maximum: 1200), spacing: 20, alignment: .top)
    ]
    
    func fetch() async {
        isLoading = true
        await fetchVideos()
        isLoading = false
    }
    
    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                ProgressView()
                    .controlSize(.large)
            } else if let error = error {
                ContentUnavailableView(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
            } else if videos.isEmpty {
                ContentUnavailableView("No videos found", systemImage: "play.slash.fill")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(videos, id: \.videoId) { video in
                            VideoGridItemView(video: video)
                        }
                    }
                    .padding()
                    .animation(.easeInOut, value: videos)
                }
                .refreshable {
                    await fetch()
                }
            }
        }
        .task { await fetch() }
    }
}

struct VideoGridItemView: View {
    public let video: YTVideo
    
    @EnvironmentObject private var playerManager: PlayerManager
    @StateObject private var playlistsViewModel: VideoPlaylistsViewModel
    
    init(video: YTVideo) {
        self.video = video
        self._playlistsViewModel = StateObject(wrappedValue: VideoPlaylistsViewModel(video: video, playerManager: PlayerManager()))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if let thumbnailURL = video.thumbnails.last?.url {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fit)
                }
            }
            
            VideoInfoView(video: video, mainLabel: .videoTitle)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            Spacer()
        }
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10)
        .onTapGesture {
            playerManager.selectVideo(video)
        }
        .contextMenu {
            Section("Add to playlist") {
                AddRemoveVideoPlaylistListView(video: video)
            }
        }
        .onAppear {
            playlistsViewModel.updatePlayerManager(playerManager)
        }
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
    
    VideosGridView(videos: [video, video, video], fetchVideos: { Task.init { } })
        .environmentObject(PlayerManager())
}

