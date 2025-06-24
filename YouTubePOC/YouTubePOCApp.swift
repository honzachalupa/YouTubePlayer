import SwiftUI

@main
struct YouTubePOCApp: App {
    @StateObject private var playerManager = PlayerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerManager)
        }
    }
}
