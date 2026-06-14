import SwiftUI
import SwiftData

@main
struct YouTubeApp: App {
    @StateObject private var videoManager = VideoManager.shared
    
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                AuthenticationModel.self,
                PlaybackPositionModel.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            container = try ModelContainer(
                for: schema,
                configurations: modelConfiguration
            )
            
            // Set up YouTubeAuthService with ModelContext
            let context = container.mainContext
            YouTubeAuthService.shared.setModelContext(context)
            VideoManager.shared.setModelContext(context)
            
            // Set up platform-specific functionality
            YouTubeAuthService.shared.setupPlatformSpecific()
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoManager)
        }
        .modelContainer(container)
    }
}
