import SwiftUI
import YouTubeKit

@main
struct YouTubePOCApp: App {
    @StateObject private var youtubeService = YTM.shared
    @StateObject private var videoStateManager = VideoStateManager()
    
    init() {
        YTM.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(youtubeService)
                .environmentObject(videoStateManager)
        }
    }
}
