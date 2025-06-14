import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            
            Tab("Subscriptions", systemImage: "play.house.fill") {
                SubscriptionsVideosView()
            }
            
            Tab("Recommended", systemImage: "play.square.stack.fill") {
                RecommendedVideosView()
            }
            
            /* Tab("Trending", systemImage: "play.house.fill") {
                TrendingVideosView()
            } */
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchVideosView()
            }
        }
        .tabViewBottomAccessory {
            AccessoryControlsView()
                .padding(.leading, 1)
                .padding(.trailing, 15)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    ContentView()
}
