import SwiftUI
import YouTubeKit

struct SubscriptionsVideosView: View {
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil

    func fetchVideos() async {
        do {
            // First ensure we have visitor data
            await YTM.shared.getVisitorData()
            
            // Set proper locale format (language_COUNTRY)
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            YTM.model.selectedLocale = locale
            
            // Create request data
            let data: [HeadersList.AddQueryInfo.ContentTypes: String] = [
                .visitorData: YTM.model.visitorData
            ]
            
            let response = try await AccountSubscriptionsFeedResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: data,
                useCookies: true
            )
            
            withAnimation {
                // Filter out shorts
                videos = response.results.filter {
                    $0.channel?.thumbnails != nil
                }
            }
        } catch {
            print("Failed to fetch subscription videos: \(error)")
            withAnimation {
                fetchError = error
                videos = []
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VideosGridView(videos: videos, error: fetchError) {
                await fetchVideos()
            }
            .toolbar {
                AccountToolbarItem()
            }
            .navigationTitle("Subscriptions")
        }
    }
}

#Preview {
    SubscriptionsVideosView()
}
