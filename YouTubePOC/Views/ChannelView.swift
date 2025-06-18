import SwiftUI

struct ChannelView: View {
    @StateObject private var videoService = YouTubeVideoService.shared
    let channelId: String
    @State private var channel: YouTubeChannel?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        Group {
            if let channel = channel {
                VStack {
                    HStack(spacing: 10) {
                        if let thumbnailUrl = channel.snippet.thumbnails.default?.url {
                            AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                }
                            }
                        }
                            
                        VStack(alignment: .leading) {
                            Text(channel.snippet.title)
                                .font(.title2)
                            
                            if let subscriberCount = channel.statistics?.subscriberCount {
                                Text("\(formatCount(subscriberCount)) subscribers")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    
                    if !channel.snippet.description.isEmpty {
                        Text(channel.snippet.description)
                            .font(.body)
                            .padding()
                    }
                    
                    Spacer()
                }
            } else if isLoading {
                ProgressView()
            } else if let error = error {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await fetchChannel()
        }
    }
    
    private func fetchChannel() async {
        isLoading = true
        error = nil
        
        do {
            // TODO: Replace with actual API call once implemented
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
            
            if channelId.isEmpty {
                throw NSError(domain: "YouTubePOC", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid channel ID"])
            }
            
            // Simulated channel data
            channel = YouTubeChannel(
                id: channelId,
                snippet: .init(
                    title: "Channel Name",
                    description: "Channel description goes here...",
                    thumbnails: .init(
                        default: .init(
                            url: "https://yt3.ggpht.com/default.jpg",
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
                statistics: .init(
                    viewCount: "1000000",
                    subscriberCount: "100000",
                    videoCount: "500"
                )
            )
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func formatCount(_ count: String) -> String {
        guard let number = Double(count) else { return "0" }
        
        switch number {
        case 0..<1000:
            return String(format: "%.0f", number)
        case 1000..<1_000_000:
            return String(format: "%.1fK", number / 1000)
        case 1_000_000..<1_000_000_000:
            return String(format: "%.1fM", number / 1_000_000)
        default:
            return String(format: "%.1fB", number / 1_000_000_000)
        }
    }
}

#Preview {
    ChannelView(channelId: "UCtcmk_u_kqeibnHqxTSNitg")
}
