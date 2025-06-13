import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "play.house.fill") {
                TrendingVideosView()
            }
            
            Tab("Subscriptions", systemImage: "play.square.stack.fill") {
                HomeVideosView()
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
