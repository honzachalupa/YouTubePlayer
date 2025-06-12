import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Trending", systemImage: "play.house.fill") {
                TrendingVideosView()
            }
            
            Tab("Subscriptions", systemImage: "play.square.stack.fill") {
                TrendingVideosView()
            }
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchVideosView()
            }
        }
    }
}

#Preview {
    ContentView()
}
