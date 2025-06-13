import SwiftUI
import YouTubeKit

struct ChannelView: View {
    var YTM = YouTubeModel()
    let channel: YTLittleChannelInfos
    
    @State private var isLoading: Bool = false
    
    /* func fetchChannelInfo() {
        isLoading = true
        
        Task {
            do {
                await self.getVisitorData()
                let response = try await ChannelInfosResponse.sendThrowingRequest(youtubeModel: YTM, data: [.browseId: channel.channelId])
                
                
                await MainActor.run {
                    self.avatarURL = response.avatarThumbnails.first!.url
                }
            } catch {
                print("Error loading video: \(error)")

                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func getVisitorData() async {
        if YTM.visitorData.isEmpty {
            if let visitorData = try? await SearchResponse.sendThrowingRequest(youtubeModel: YTM, data: [.query: "homefwhfjoifj"]).visitorData {
                YTM.visitorData = visitorData
            } else {
                print("Couldn't get visitorData, request may fail.")
            }
        }
    } */
    
    var body: some View {
        HStack(spacing: 10) {
            if let thumbnailUrl = channel.thumbnails.first?.url {
                AsyncImage(url: thumbnailUrl) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40)
                            .clipShape(Circle())
                    } else if phase.error != nil {
                        Color.gray
                    } else {
                        ProgressView()
                    }
                }
            }
                
            Text(channel.name ?? "")
                .font(.subheadline)
        }
        .onAppear {
            // fetchChannelInfo()
        }
        .onChange(of: channel) {
            // fetchChannelInfo()
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
    
    ChannelView(channel: channel)
}
