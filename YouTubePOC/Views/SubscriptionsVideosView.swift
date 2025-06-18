import SwiftUI

struct SubscriptionsVideosView: View {
    @StateObject private var videoService = YouTubeVideoService.shared
    @StateObject private var authService = YouTubeAuthService.shared
    
    var body: some View {
        Group {
            if authService.accessToken == nil {
                ContentUnavailableView {
                    Label("Sign in required", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Sign in to view your subscriptions")
                } actions: {
                    Button("Sign in") {
                        Task {
                            await authService.signIn()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VideosGridView(
                    videos: videoService.videos,
                    title: "Subscriptions",
                    isLoading: videoService.isLoading,
                    onLoadMore: {
                        await videoService.fetchSubscriptionVideos()
                    }
                )
                .alert(
                    "Error",
                    isPresented: .constant(videoService.error != nil),
                    actions: {
                        Button("OK", role: .cancel) { }
                    },
                    message: {
                        Text(videoService.error ?? "Unknown error")
                    }
                )
            }
        }
    }
}

#Preview {
    SubscriptionsVideosView()
}
