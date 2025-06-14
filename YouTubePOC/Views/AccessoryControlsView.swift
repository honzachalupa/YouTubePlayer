import SwiftUI
import YouTubeKit

struct AccessoryControlsView: View {
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
    
    var body: some View {
        HStack {
            if let thumbnailUrl = video.channel?.thumbnails.first?.url {
                AsyncImage(url: thumbnailUrl) { phase in
                    Group {
                        if let image = phase.image {
                            image.resizable()
                        } else {
                            Color.gray
                        }
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40)
                    .clipShape(Circle())
                }
            }
            
            Text(video.title ?? "")
                .font(.callout)
                .fontWeight(.bold)
                .lineLimit(1)
            
            Group {
                if false {
                    Button { } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                } else {
                    Button { } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                }
            }
            .padding(.leading, 5)
        }
    }
}

#Preview {
    AccessoryControlsView()
}
