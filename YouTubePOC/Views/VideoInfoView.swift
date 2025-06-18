import SwiftUI

enum MainLabel {
    case videoTitle, channelName
}

struct VideoInfoView: View {
    let video: YouTubeVideo
    let mainLabel: MainLabel
    
    var body: some View {
        HStack(spacing: 10) {
            if let thumbnailUrl = URL(string: video.snippet.thumbnails.default?.url ?? "") {
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
                    .clipShape(Circle())
                }
            }
                
            VStack(alignment: .leading, spacing: 5) {
                Group {
                    switch mainLabel {
                        case .videoTitle: Text(video.snippet.title)
                        case .channelName: Text(video.snippet.channelTitle)
                    }
                }
                .fontWeight(.medium)
                .lineLimit(2)
                
                let info = ([
                    mainLabel == .channelName ? nil : video.snippet.channelTitle,
                    video.statistics?.viewCount.map { "\($0) views" },
                    formatPublishedDate(video.snippet.publishedAt)
                ]
                .compactMap { $0 })
                .joined(separator: " • ")
                    
                Text(info)
                    .font(.caption)
                    .opacity(0.5)
            }
        }
    }
    
    private func formatPublishedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years) year\(years == 1 ? "" : "s") ago"
        } else if let months = components.month, months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") ago"
        } else if let days = components.day, days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}

#Preview("Variant: videoTitle") {
    let video = YouTubeVideo(
        id: "cETgTtu6atM",
        snippet: YouTubeVideo.VideoSnippet(
            publishedAt: "2024-03-10T12:00:00Z",
            channelId: "UC9M7-jzdU8CVrQo1JwmIdWA",
            title: "WWDC25: What's new in SwiftUI",
            description: "A preview of the new SwiftUI features announced at WWDC25",
            thumbnails: YouTubeThumbnails(
                default: YouTubeThumbnail(
                    url: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s68-c-k-c0x00ffffff-no-rj",
                    width: 120,
                    height: 90
                ),
                medium: nil,
                high: nil,
                standard: nil,
                maxres: nil
            ),
            channelTitle: "MacRumors",
            tags: ["WWDC25", "SwiftUI", "iOS"],
            categoryId: "28",
            liveBroadcastContent: "none"
        ),
        contentDetails: YouTubeVideo.ContentDetails(
            duration: "PT6M31S",
            dimension: "2d",
            definition: "hd",
            caption: "false",
            licensedContent: true,
            projection: "rectangular"
        ),
        statistics: YouTubeVideo.Statistics(
            viewCount: "64000",
            likeCount: "1200",
            favoriteCount: "0",
            commentCount: "150"
        )
    )
    
    VideoInfoView(video: video, mainLabel: .videoTitle)
}

#Preview("Variant: channelName") {
    let video = YouTubeVideo(
        id: "cETgTtu6atM",
        snippet: YouTubeVideo.VideoSnippet(
            publishedAt: "2024-03-10T12:00:00Z",
            channelId: "UC9M7-jzdU8CVrQo1JwmIdWA",
            title: "WWDC25: What's new in SwiftUI",
            description: "A preview of the new SwiftUI features announced at WWDC25",
            thumbnails: YouTubeThumbnails(
                default: YouTubeThumbnail(
                    url: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s68-c-k-c0x00ffffff-no-rj",
                    width: 120,
                    height: 90
                ),
                medium: nil,
                high: nil,
                standard: nil,
                maxres: nil
            ),
            channelTitle: "MacRumors",
            tags: ["WWDC25", "SwiftUI", "iOS"],
            categoryId: "28",
            liveBroadcastContent: "none"
        ),
        contentDetails: YouTubeVideo.ContentDetails(
            duration: "PT6M31S",
            dimension: "2d",
            definition: "hd",
            caption: "false",
            licensedContent: true,
            projection: "rectangular"
        ),
        statistics: YouTubeVideo.Statistics(
            viewCount: "64000",
            likeCount: "1200",
            favoriteCount: "0",
            commentCount: "150"
        )
    )
    
    VideoInfoView(video: video, mainLabel: .channelName)
}
