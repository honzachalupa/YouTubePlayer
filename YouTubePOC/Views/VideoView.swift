import SwiftUI
import YouTubeKit

struct VideoView: View {
    private let YTM = YouTubeModel()
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
                    }
                    
                    Text("Posted: \(video.timePosted ?? ""), views count: \(video.viewCount ?? "")")
                        .font(.caption)
                    
                    HStack {
                        ControlGroup {
                            Button {
                                Task {
                                    await video.likeVideo(youtubeModel: YTM)
                                }
                            } label: {
                                Label("Like", systemImage: "hand.thumbsup.fill")
                            }
                            .buttonStyle(.glass)
                            
                            Button {
                                Task {
                                    await video.dislikeVideo(youtubeModel: YTM)
                                }
                            } label: {
                                Label("Dislike", systemImage: "hand.thumbsdown.fill")
                            }
                            .buttonStyle(.glass)
                        }
                        
                        Button { } label: {
                            Label("Save", systemImage: "bookmark.fill")
                        }
                        .buttonStyle(.glass)
                        
                        Button { } label: {
                            Label("Share", systemImage: "square.and.arrow.up.fill")
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationDestination(for: YTLittleChannelInfos.self) { channel in
                ChannelView(channel: channel)
            }
        }
    }
}

#Preview {
    let sampleVideo = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What’s new in SwiftUI | Apple",
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
    
    VideoView(video: sampleVideo)
}
