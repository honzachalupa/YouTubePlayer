import SwiftUI
import YouTubeKit

@main
struct YouTubePOCApp: App {
    @StateObject private var youtubeService = YTM.shared
    
    init() {
        // YTM setup is handled by YouTubeAuthService based on login state.
        // No manual cookie insertion is needed here anymore.
        YTM.setup()
        
        print("App launched.")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(youtubeService)
        }
    }
}
