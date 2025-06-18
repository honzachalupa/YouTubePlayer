import SwiftUI

struct ChannelView: View {
    public var channel: YouTubeChannel
    
    var body: some View {
        HStack(spacing: 10) {
            if let thumbnailUrl = channel.snippet.thumbnails.default?.url {
                AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40)
                            .clipShape(Circle())
                    } else {
                        Color.gray
                    }
                }
            }
                
            Text(channel.snippet.title)
                .font(.subheadline)
        }
    }
}

#Preview {
    let channel = YouTubeChannel(
        id: "UCtcmk_u_kqeibnHqxTSNitg",
        snippet: .init(
            title: "Channel Name",
            description: "",
            thumbnails: .init(
                default: .init(
                    url: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s68-c-k-c0x00ffffff-no-rj",
                    width: 68,
                    height: 68
                ),
                medium: nil,
                high: nil,
                standard: nil,
                maxres: nil
            ),
            customUrl: nil
        ),
        statistics: nil
    )
    
    ChannelView(channel: channel)
}
