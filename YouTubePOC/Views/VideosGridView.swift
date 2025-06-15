import SwiftUI
import YouTubeKit

struct VideosGridView: View {
    public var videos: [YTVideo]
    public var error: Error?
    public var fetchVideos: () async -> Void
    
    @EnvironmentObject private var playerManager: PlayerManager
    @State private var selectedVideo: YTVideo? = nil
    @State private var isLoading: Bool = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 600, maximum: 1200), spacing: 20)
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
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(videos, id: \.videoId) { video in
                            VideoRowView(video: video)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playerManager.selectVideo(video)
                                }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await fetch()
                }
            }
        }
        .task {
            await fetch()
        }
    }
}

struct VideoRowView: View {
    let video: YTVideo
    
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title ?? "")
                    .font(.headline)
                    .lineLimit(2)
                
                if let channel = video.channel {
                    Text(channel.name ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(video.viewCount ?? "")
                    Text("•")
                    Text(video.timePosted ?? "")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(.regularMaterial)
        .cornerRadius(20)
    }
}

#Preview {
    let video = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What's new in SwiftUI | Apple",
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

