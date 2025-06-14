import SwiftUI
import YouTubeKit

struct VideoInfoView: View {
    let video: YTVideo
    
    var body: some View {
        HStack(spacing: 10) {
            if let thumbnailUrl = video.channel?.thumbnails.first?.url {
                AsyncImage(url: thumbnailUrl) { phase in
                    Group {
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
                
            VStack(alignment: .leading, spacing: 5) {
                Text(video.title ?? "")
                    .fontWeight(.medium)
                
                let info = (
                    [video.channel?.name, video.viewCount, video.timePosted]
                        .filter { $0 != nil } as! [String])
                        .joined(separator: " • ")
                    
                Text(info)
                    .font(.caption)
                    .opacity(0.5)
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
    
    VideoInfoView(video: video)
}
