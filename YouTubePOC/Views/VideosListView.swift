import SwiftUI
import YouTubeKit

struct VideosListView: View {
    public var videos: [YTVideo]
    public var error: Error?
    public var fetchVideos: () async -> Void
    
    @EnvironmentObject private var playerManager: PlayerManager
    @State private var selectedVideo: YTVideo? = nil
    @State private var isLoading: Bool = false

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
                List(videos, id: \.videoId, selection: $selectedVideo) { video in
                    if let thumbnailURL = video.thumbnails.first?.url {
                        Section {
                            NavigationLink(value: video) {
                                VStack(alignment: .leading, spacing: 12) {
                                    AsyncImage(url: thumbnailURL) { phase in
                                        Group {
                                            if let image = phase.image {
                                                image.resizable()
                                            } else {
                                                Color.gray.opacity(0.2)
                                                    .overlay {
                                                        ProgressView()
                                                    }
                                            }
                                        }
                                        .aspectRatio(16/9, contentMode: .fit)
                                        // TODO: Replace the negative paddings with somethiing more elegant
                                        .padding(.top, -15)
                                        .padding(.horizontal, -20)
                                        .padding(.trailing, -22)
                                    }
                                    
                                    VideoInfoView(video: video)
                                }
                            }
                            .onTapGesture {
                                playerManager.selectVideo(video)
                            }
                        }
                    }
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
    
    VideosListView(videos: [video, video, video], error: nil) {}
        .environmentObject(PlayerManager())
}

