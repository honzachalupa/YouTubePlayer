import SwiftUI
import YouTubeKit

struct HistoryVideosView: View {
    private let youtubeService = YouTubeService.shared
    private let authService = YouTubeAuthService.shared
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil

    func fetchVideos() async {
        guard authService.isAuthenticated else {
            withAnimation {
                fetchError = NSError(
                    domain: "YouTubeAuth",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please sign in."]
                )
                videos = []
            }
            return
        }
        do {
            // First ensure we have visitor data
            await youtubeService.getVisitorData()
            
            // Set proper locale format (language_COUNTRY)
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            youtubeService.model.selectedLocale = locale
            
            // Create request data
            let data: [HeadersList.AddQueryInfo.ContentTypes: String] = [
                .visitorData: youtubeService.model.visitorData
            ]
            
            let response = try await HistoryResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: data,
                useCookies: true
            )
            
            var allVideos: [YTVideo] = []
            for block in response.results {
                for content in block.contentsArray {
                    if let videoWithToken = content as? HistoryResponse.HistoryBlock.VideoWithToken {
                        allVideos.append(videoWithToken.video)
                    } else if let shortsBlock = content as? HistoryResponse.HistoryBlock.ShortsBlock {
                        allVideos.append(contentsOf: shortsBlock.shorts)
                    }
                }
            }
            
            withAnimation {
                videos = allVideos
            }
        } catch {
            withAnimation {
                fetchError = error
                videos = []
            }
        }
    }
    
    var body: some View {
        VideosGridView(videos: videos, error: fetchError) {
            await fetchVideos()
        }
        #if os(iOS)
        .navigationTitle("History")
        #endif
    }
}

#Preview {
    HistoryVideosView()
}
