import SwiftUI
import YouTubeKit

extension YTVideo: @retroactive Identifiable {
    public var id: String { self.videoId }
}

struct VideosListView: View {
    var videos: [YTVideo]
    @State private var selectedVideo: YTVideo? = nil
    
    var body: some View {
        List(videos, id: \.videoId, selection: $selectedVideo) { video in
            if let thumbnailURL = video.thumbnails.first?.url {
                Section {
                    NavigationLink(value: video) {
                        VStack(alignment: .leading, spacing: 5) {
                            AsyncImage(url: thumbnailURL) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding(.top, -15) // TODO: Solve using some cleaner way
                                        .padding(.horizontal, -20)
                                        .padding(.trailing, -22)
                                        .padding(.bottom, 5)
                                } else if phase.error != nil {
                                    Color.gray
                                } else {
                                    ProgressView()
                                }
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
        .sheet(item: $selectedVideo) { video in
            VideoView(video: video)
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    let sampleVideo = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What’s new in SwiftUI | Apple",
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
    
    VideosListView(videos: [sampleVideo, sampleVideo, sampleVideo])
}
