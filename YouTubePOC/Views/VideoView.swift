import SwiftUI
import YouTubeKit

struct VideoView: View {
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    var video: YTVideo
    
    var body: some View {
        NavigationStack {
            VStack {
                VideoPlayerView(video: video)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text(video.title ?? "")
                        .font(.title)
                    
                    if let channel = video.channel {
                        NavigationLink(value: channel) {
                            ChannelInfoView(channel: channel)
                        }
                        .foregroundStyle(.foreground)
                    }
                    
                    Text("Posted: \(video.timePosted ?? ""), views count: \(video.viewCount ?? "")")
                        .font(.caption)
                    
                    HStack {
                        ControlGroup {
                            Button {
                                Task {
                                    await video.likeVideo(youtubeModel: YTM.model)
                                }
                            } label: {
                                Label("Like", systemImage: "hand.thumbsup")
                            }
                            
                            Button {
                                Task {
                                    await video.dislikeVideo(youtubeModel: YTM.model)
                                }
                            } label: {
                                Label("Disike", systemImage: "hand.thumbsdown")
                            }
                        }
                        
                        Button { } label: {
                            Label("Share", systemImage: "arrowshape.turn.up.right.fill")
                        }
                        
                        Button { } label: {
                            Label("Save", systemImage: "square.and.arrow.down.fill")
                        }
                    }
                }
                .padding(15)
                
                Spacer()
            }
            .navigationDestination(for: YTLittleChannelInfos.self) { channel in
                ChannelView(channel: channel)
            }
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
    
    VStack {}
        .sheet(isPresented: .constant(true)) {
            VideoView(video: video)
        }
    .environmentObject(YTM.shared)
}
