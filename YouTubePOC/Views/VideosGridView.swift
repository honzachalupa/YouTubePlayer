import SwiftUI

struct VideosGridView: View {
    let videos: [YouTubeVideo]
    let title: String
    let isLoading: Bool
    let onLoadMore: (() async -> Void)?
    
    @State private var selectedVideo: YouTubeVideo?
    @State private var showVideoPlayer = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(videos) { video in
                    Button {
                        selectedVideo = video
                        showVideoPlayer = true
                    } label: {
                        VideoThumbnailView(video: video)
                    }
                    .buttonStyle(.plain)
                }
                
                if isLoading {
                    Section {
                        ForEach(0..<6) { _ in
                            VideoThumbnailPlaceholder()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .sheet(isPresented: $showVideoPlayer) {
            if let video = selectedVideo {
                VideoView(video: video)
            }
        }
        .task {
            await onLoadMore?()
        }
    }
}

struct VideoThumbnailView: View {
    let video: YouTubeVideo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: video.bestThumbnail)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
            }
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(8)
            
            // Title
            Text(video.snippet.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Channel name
            Text(video.snippet.channelTitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // View count and date
            HStack {
                if let viewCount = video.statistics?.viewCount {
                    Text("\(formatCount(viewCount)) views")
                }
                Text("•")
                Text(formatDate(video.snippet.publishedAt))
            }
            .font(.caption2)
            .foregroundColor(.secondary)
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y ago"
        } else if let months = components.month, months > 0 {
            return "\(months)mo ago"
        } else if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

struct VideoThumbnailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .foregroundColor(.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(8)
            
            Rectangle()
                .foregroundColor(.gray.opacity(0.3))
                .frame(height: 16)
                .cornerRadius(4)
            
            Rectangle()
                .foregroundColor(.gray.opacity(0.3))
                .frame(height: 16)
                .cornerRadius(4)
                .frame(maxWidth: .infinity * 0.7)
            
            HStack {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(height: 12)
                    .cornerRadius(4)
                    .frame(maxWidth: .infinity * 0.4)
                
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(height: 12)
                    .cornerRadius(4)
                    .frame(maxWidth: .infinity * 0.4)
            }
        }
        .redacted(reason: .placeholder)
    }
}

#Preview {
    let video = YouTubeVideo(
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
            commentCount: "156"
        )
    )
    
    return VideosGridView(videos: [video, video, video], title: "Videos", isLoading: false, onLoadMore: { Task.init { } })
}

