import SwiftUI

@main
struct YouTubePOCApp: App {
    @StateObject private var videoManager = VideoManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoManager)
        }
    }
}
