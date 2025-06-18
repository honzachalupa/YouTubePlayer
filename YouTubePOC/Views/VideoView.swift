import SwiftUI
import AVKit

struct VideoView: View {
    @StateObject private var videoService = YouTubeVideoService.shared
    var video: YouTubeVideo
    
    var body: some View {
        NavigationStack {
            VStack {
                VideoPlayerView(video: video)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text(video.snippet.title)
                        .font(.title)
                    
                    NavigationLink(value: video.snippet.channelId) {
                        HStack {
                            AsyncImage(url: URL(string: video.snippet.thumbnails.default?.url ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
                            
                            Text(video.snippet.channelTitle)
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.foreground)
                    
                    Text("Posted: \(formatDate(video.snippet.publishedAt)), views: \(formatCount(video.statistics?.viewCount ?? "0"))")
                        .font(.caption)
                    
                    HStack {
                        ControlGroup {
                            Button {
                                // TODO: Like video
                            } label: {
                                Label("Like", systemImage: "hand.thumbsup.fill")
                            }
                            .buttonStyle(.glass)
                            
                            Button {
                                // TODO: Dislike video
                            } label: {
                                Label("Dislike", systemImage: "hand.thumbsdown.fill")
                            }
                            .buttonStyle(.glass)
                        }
                        
                        Button {
                            // TODO: Save video
                        } label: {
                            Label("Save", systemImage: "bookmark.fill")
                        }
                        .buttonStyle(.glass)
                        
                        Button {
                            // TODO: Share video
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up.fill")
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationDestination(for: String.self) { channelId in
                ChannelView(channelId: channelId)
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years) years ago"
        } else if let months = components.month, months > 0 {
            return "\(months) months ago"
        } else if let days = components.day, days > 0 {
            return "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
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
    VideoView(video: YouTubeVideo(
        id: "cETgTtu6atM",
        snippet: .init(
            publishedAt: "2024-03-15T10:00:00Z",
            channelId: "UC9M3-PXEcXzwZGEWY46VNTw",
            title: "WWDC25: What's new in SwiftUI",
            description: "A preview of the new SwiftUI features announced at WWDC25",
            thumbnails: .init(
                default: .init(
                    url: "https://i.ytimg.com/vi/cETgTtu6atM/default.jpg",
                    width: 120,
                    height: 90
                ),
                medium: .init(
                    url: "https://i.ytimg.com/vi/cETgTtu6atM/mqdefault.jpg",
                    width: 320,
                    height: 180
                ),
                high: .init(
                    url: "https://i.ytimg.com/vi/cETgTtu6atM/hqdefault.jpg",
                    width: 480,
                    height: 360
                ),
                standard: nil,
                maxres: nil
            ),
            channelTitle: "MacRumors",
            tags: ["WWDC25", "SwiftUI", "iOS"],
            categoryId: "28",
            liveBroadcastContent: "none"
        ),
        contentDetails: .init(
            duration: "PT6M31S",
            dimension: "2d",
            definition: "hd",
            caption: "false",
            licensedContent: true,
            projection: "rectangular"
        ),
        statistics: .init(
            viewCount: "64000",
            likeCount: "1200",
            favoriteCount: "0",
            commentCount: "150"
        )
    ))
}
