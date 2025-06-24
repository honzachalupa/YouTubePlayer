import SwiftUI

@main
struct YouTubePOCApp: App {
    @StateObject private var youtubeService = YouTubeService.shared
    @StateObject private var playerManager = PlayerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(youtubeService)
                .environmentObject(playerManager)
        }
    }
}
