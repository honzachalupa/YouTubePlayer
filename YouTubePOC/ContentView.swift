import SwiftUI

struct ContentView: View {    
    var body: some View {
        TabView {
            Tab("Home", systemImage: "play.house.fill") {
                HomeVideosView()
            }
            
            Tab("Subscriptions", systemImage: "play.square.stack.fill") {
                SubscriptionsVideosView()
            }
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchVideosView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    ContentView()
}
