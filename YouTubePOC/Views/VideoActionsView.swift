import SwiftUI

struct VideoActionsView: View {
    public let video: YouTubeVideo
    
    @EnvironmentObject private var playerManager: PlayerManager
    
    private var likeButton: some View {
        Button {
            playerManager.toggleLike()
        } label: {
            Label("Like", systemImage: playerManager.likeStatus == "liked" ? "hand.thumbsup.fill" : "hand.thumbsup")
        }
        .tint(playerManager.likeStatus == "liked" ? .green : .none)
        .symbolEffect(.bounce, value: playerManager.likeStatus == "liked")
    }
    
    private var dislikeButton: some View {
        Button {
            playerManager.toggleDislike()
        } label: {
            Image(systemName: playerManager.likeStatus == "disliked" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
        }
        .tint(playerManager.likeStatus == "disliked" ? .red : .none)
        .symbolEffect(.bounce, value: playerManager.likeStatus == "disliked")
    }
    
    private var shareButton: some View {
        ShareLink(item: "https://www.youtube.com/watch?v=\(video.id)") {
            Label("Share", systemImage: "arrowshape.turn.up.right.fill")
        }
    }
    
    private var saveButton: some View {
        Menu {
            AddRemoveVideoPlaylistListView(video: video)
        } label: {
            Label("Save", systemImage: "square.and.arrow.down.fill")
        }
        .menuStyle(.button)
        .foregroundStyle(.primary)
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .glassEffect(.regular.interactive())
    }
    
    var body: some View {
        HStack {
            Group {
                likeButton
                dislikeButton
                shareButton
                saveButton
            }
            .buttonStyle(.glass)
        }
    }
}

#Preview {
    let video = YouTubeVideo(
        id: "cETgTtu6atM",
        snippet: .init(
            publishedAt: "",
            channelId: "",
            title: "WWDC25: What's new in SwiftUI",
            description: "",
            thumbnails: .init(
                default: .init(
                    url: "https://i.ytimg.com/vi/cETgTtu6atM/hq720.jpg",
                    width: 720,
                    height: 404
                ),
                medium: nil,
                high: nil,
                standard: nil,
                maxres: nil
            ),
            channelTitle: "MacRumors",
            tags: nil,
            categoryId: "",
            liveBroadcastContent: ""
        ),
        contentDetails: nil,
        statistics: .init(
            viewCount: "64K",
            likeCount: nil,
            favoriteCount: nil,
            commentCount: nil
        )
    )
    
    VideoActionsView(video: video)
        .padding()
        .environmentObject(PlayerManager())
}
