import SwiftUI
import YouTubeKit

struct ChannelInfoView: View {
    let channel: YTLittleChannelInfos
    
    var body: some View {
        HStack(spacing: 10) {
            if let thumbnailUrl = channel.thumbnails.first?.url {
                AsyncImage(url: thumbnailUrl) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30)
                            .clipShape(Circle())
                    } else if phase.error != nil {
                        Color.gray
                    } else {
                        ProgressView()
                    }
                }
            }
                
            Text(channel.name ?? "")
                .foregroundStyle(.foreground)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let channel = YTLittleChannelInfos(
        channelId: "UCtcmk_u_kqeibnHqxTSNitg",
        name: "Channel Name",
        thumbnails: [
            YTThumbnail(url: URL(string: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s68-c-k-c0x00ffffff-no-rj")!)
        ]
    )
    
    ChannelInfoView(channel: channel)
}
