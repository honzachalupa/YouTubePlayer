import SwiftUI
import SwiftData

@main
struct YouTube_tvOSApp: App {
    let container: ModelContainer
    @StateObject private var videoManager = VideoManager.shared
    
    init() {
        let schema = Schema([
            AuthenticationModel.self,
            PlaybackPositionModel.self
        ])

        do {
            container = try Self.makeModelContainer(schema: schema, isStoredInMemoryOnly: false)
        } catch {
            print("Failed to create persistent ModelContainer, falling back to in-memory store: \(error.localizedDescription)")
            do {
                container = try Self.makeModelContainer(schema: schema, isStoredInMemoryOnly: true)
            } catch {
                fatalError("Failed to create fallback ModelContainer: \(error.localizedDescription)")
            }
        }
        
        // Set up YouTubeAuthService with ModelContext
        let context = container.mainContext
        YouTubeAuthService.shared.setModelContext(context)
        VideoManager.shared.setModelContext(context)
    }

    private static func makeModelContainer(schema: Schema, isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: schema,
            configurations: modelConfiguration
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoManager)
        }
        .modelContainer(container)
    }
}
