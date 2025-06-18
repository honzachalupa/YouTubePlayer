import SwiftUI

@main
struct YouTubePOCApp: App {
    @StateObject private var authService = YouTubeAuthService.shared
    @StateObject private var videoService = YouTubeVideoService.shared
    @StateObject private var playerManager = PlayerManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(videoService)
                .environmentObject(playerManager)
        }
    }
}
