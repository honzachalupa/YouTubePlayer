import SwiftUI
import YouTubeKit

struct VideosListView: View {
    @StateObject public var viewModel: VideoListViewModel
    public let navigationTitle: String
    
    @State private var selectedVideo: YTVideo? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isFetching && viewModel.videos.isEmpty {
                    ProgressView()
                        .controlSize(.large)
                } else if let error = viewModel.error {
                    ContentUnavailableView(error, systemImage: "exclamationmark.triangle.fill")
                } else if viewModel.videos.isEmpty {
                    ContentUnavailableView("No videos found", systemImage: "play.slash.fill")
                } else {
                    List(viewModel.videos, id: \.videoId, selection: $selectedVideo) { video in
                        if let thumbnailURL = video.thumbnails.first?.url {
                            Section {
                                NavigationLink(value: video) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        AsyncImage(url: thumbnailURL) { phase in
                                            Group {
                                                if let image = phase.image {
                                                    image.resizable()
                                                        // TODO: Replace the negative paddings with somethiing more elegant
                                                        .padding(.top, -15)
                                                        .padding(.horizontal, -20)
                                                        .padding(.trailing, -22)
                                                        .padding(.bottom, 5)
                                                } else if phase.error != nil {
                                                    Color.gray
                                                } else {
                                                    ProgressView()
                                                }
                                            }
                                            .aspectRatio(16/10, contentMode: .fit)
                                        }
                                        
                                        if let channel = video.channel {
                                            ChannelInfoView(channel: channel)
                                        }
                                        
                                        Text(video.title ?? "")
                                            .font(.headline)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedVideo) { video in
                VideoView(video: video)
                    .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountLinkView()
                }
            }
            .navigationTitle(navigationTitle)
        }
        .task {
            if viewModel.videos.isEmpty {
                await viewModel.fetchVideos()
            }
        }
    }
}

#Preview {
    let sampleVideo = YTVideo(
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
    
    return VideosListView(viewModel: VideoListViewModel(staticVideos: [sampleVideo, sampleVideo, sampleVideo]), navigationTitle: "Videos")
}
