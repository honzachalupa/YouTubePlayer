import SwiftUI

@main
struct YouTubeApp: App {
    @StateObject private var videoManager = VideoManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoManager)
        }
    }
}
