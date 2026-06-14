import SwiftUI
import SwiftData

@main
struct YouTube_tvOSApp: App {
    let container: ModelContainer
    @StateObject private var videoManager = VideoManager()
    
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
            videoManager.setModelContext(context)
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
