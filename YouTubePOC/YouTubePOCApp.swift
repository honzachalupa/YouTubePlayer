import SwiftUI
import YouTubeKit

@main
struct YouTubePOCApp: App {
    @StateObject private var youtubeService = YTM.shared
    @StateObject private var playerManager = PlayerManager()
    
    init() {
        YTM.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(youtubeService)
                .environmentObject(playerManager)
        }
    }
}
